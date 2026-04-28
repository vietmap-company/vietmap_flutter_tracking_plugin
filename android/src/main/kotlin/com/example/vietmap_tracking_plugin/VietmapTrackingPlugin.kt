package com.example.vietmap_tracking_plugin

import android.Manifest
import android.app.Activity
import android.content.Context
import android.content.pm.PackageManager
import android.os.Build
import android.os.Handler
import android.os.Looper
import androidx.core.app.ActivityCompat
import androidx.core.content.ContextCompat
import io.flutter.embedding.engine.plugins.FlutterPlugin
import io.flutter.embedding.engine.plugins.activity.ActivityAware
import io.flutter.embedding.engine.plugins.activity.ActivityPluginBinding
import io.flutter.plugin.common.EventChannel
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import io.flutter.plugin.common.MethodChannel.MethodCallHandler
import io.flutter.plugin.common.MethodChannel.Result
import io.flutter.plugin.common.PluginRegistry
import android.net.ConnectivityManager
import android.net.Network
import android.net.NetworkCapabilities
import android.net.NetworkRequest
import android.util.Log
import com.vietmap.trackingsdk.VietmapTrackingSDK
import com.vietmap.trackingsdk.TrackingConfig
import com.vietmap.trackingsdk.VMLocation
import com.vietmap.trackingsdk.VietmapTrackingManager

/**
 * VietmapTrackingPlugin - Flutter bridge for VietmapTrackingSDK (Android)
 *
 * Architecture follows the same pattern as the React Native bridge
 * (RnVietmapTrackingPluginModule.kt) and the iOS Flutter bridge
 * (VietmapTrackingPlugin.swift).
 *
 * Layer Architecture:
 * ┌─────────────────────────────────────────────────┐
 * │  Flutter Application Layer (Dart)               │
 * ├─────────────────────────────────────────────────┤
 * │  Bridge Layer (this file — MethodChannel)       │
 * │  - Type conversion: native ↔ Dart               │
 * │  - Forward events from SDK → Flutter            │
 * ├─────────────────────────────────────────────────┤
 * │  Native SDK Layer                               │
 * │  - VietmapTrackingSDK.getInstance(context)      │
 * │  - FusedLocationProvider (Android)              │
 * │  - Foreground Service                           │
 * └─────────────────────────────────────────────────┘
 */
class VietmapTrackingPlugin : FlutterPlugin, MethodCallHandler, ActivityAware,
    PluginRegistry.RequestPermissionsResultListener {

    // MARK: - Properties
    private lateinit var channel: MethodChannel
    private lateinit var context: Context
    private var activity: Activity? = null

    // VietmapTrackingSDK Integration
    private lateinit var vietmapSDK: VietmapTrackingSDK
    private var isInitialized: Boolean = false
    
    // Store configuration for manual POST if needed
    private var apiKey: String? = null
    private var baseURL: String? = null
    private var deviceId: String? = null
    private var userId: String? = null
    private var vehicleId: String? = null

    // Tracking state for duration/last update (matching iOS SDK behavior)
    private var trackingStartTime: Long = 0L
    private var lastLocationTimestamp: Long = 0L

    // EventChannel stream handlers
    private val locationStreamHandler = StreamHandler()
    private val trackingStatusStreamHandler = StreamHandler()

    // SDK callback references (stored so we can remove them later)
    private var locationCallback: VietmapTrackingSDK.LocationUpdateCallback? = null
    private var statusCallback: VietmapTrackingSDK.TrackingStatusCallback? = null
    private var fakeGpsCallback: VietmapTrackingSDK.FakeGPSCallback? = null

    // Sync Logger: network monitor
    private var networkCallback: ConnectivityManager.NetworkCallback? = null

    // Smart Battery Optimization
    // Khi bật: apply TrackingConfig phù hợp theo preset (navigation/general/batterySaver)
    // Android Activity Recognition Transition API báo STILL → switch sang profile tiết kiệm
    private var smartBatteryEnabled: Boolean = false
    private var smartBatteryPreset: String = "general"

    // Permission handling
    private var pendingPermissionResult: Result? = null
    private var pendingAlwaysPermissionResult: Result? = null

    // Main thread handler for dispatching results
    private val mainHandler = Handler(Looper.getMainLooper())

    private fun logSection(section: String, end: Boolean = false) {
        val prefix = if (end) "End " else ""
        Log.d("VietmapTrackingPlugin", "=======${prefix}${section}=======")
    }

    private inline fun withSection(section: String, block: () -> Unit) {
        logSection(section)
        try {
            block()
        } finally {
            logSection(section, end = true)
        }
    }

    companion object {
        private const val CHANNEL_NAME = "vietmap_tracking_plugin"
        private const val LOCATION_UPDATE_CHANNEL = "vietmap_tracking_plugin/location_updates"
        private const val TRACKING_STATUS_CHANNEL = "vietmap_tracking_plugin/tracking_status"
        private const val PERMISSION_REQUEST_CODE = 1001
        private const val BACKGROUND_PERMISSION_REQUEST_CODE = 1002
    }

    // ============================================================
    // MARK: - Plugin Registration
    // ============================================================

    override fun onAttachedToEngine(binding: FlutterPlugin.FlutterPluginBinding) {
        withSection("Plugin Registration") {
            context = binding.applicationContext

            // MethodChannel
            channel = MethodChannel(binding.binaryMessenger, CHANNEL_NAME)
            channel.setMethodCallHandler(this)

            // EventChannels (matching iOS pattern)
            val locationEventChannel = EventChannel(binding.binaryMessenger, LOCATION_UPDATE_CHANNEL)
            locationEventChannel.setStreamHandler(locationStreamHandler)

            val trackingStatusEventChannel = EventChannel(binding.binaryMessenger, TRACKING_STATUS_CHANNEL)
            trackingStatusEventChannel.setStreamHandler(trackingStatusStreamHandler)

            // Initialize VietmapTrackingSDK instance (not configured until configure() is called)
            try {
                vietmapSDK = VietmapTrackingSDK.getInstance(context)
            } catch (_: Exception) {
                isInitialized = false
            }
        }
    }

    override fun onDetachedFromEngine(binding: FlutterPlugin.FlutterPluginBinding) {
        withSection("Plugin Detach") {
            channel.setMethodCallHandler(null)
            // Clean up SDK callbacks (Flutter EventChannel sinks will be invalid after detach)
            if (isInitialized) {
                clearSDKCallbacks()
                teardownSyncLogger()
                // NOTE: Do NOT call vietmapSDK.stopTracking() here!
                // When backgroundMode is enabled, the SDK's Foreground Service
                // (START_STICKY) must continue running independently even after
                // the Flutter engine is destroyed (app killed / task swiped).
                // The OS will re-create the service automatically.
                // Tracking should only stop when explicitly called via stopTracking().
            }
        }
    }

    // ============================================================
    // MARK: - SDK Event Callbacks Setup
    // ============================================================

    /**
     * Setup SDK callbacks to forward events to Flutter via EventChannels.
     *
     * Matches the iOS pattern in VietmapTrackingPlugin.swift:setupSDKCallbacks()
     * and fills the gap noted in Guide.md:
     * "Android bridge KHÔNG setup event callbacks cho location/tracking/error/route"
     */
    private fun setupSDKCallbacks() {
        withSection("Setup SDK Callbacks") {
            // Remove old callbacks if any
            clearSDKCallbacks()

            // onLocationUpdate → location EventChannel
            locationCallback = VietmapTrackingSDK.LocationUpdateCallback { location ->
                lastLocationTimestamp = System.currentTimeMillis()

                // SDK tự quản lý pipeline: capture → SQLite → POST/retry
                // Plugin chỉ log diagnostics và forward event lên Flutter
                try {
                    val cached = vietmapSDK.getCachedLocationsCount()
                    val isOnline = vietmapSDK.isNetworkAvailable()
                    if (!isOnline) {
                        Log.d("VietmapSync", "💾 OFFLINE → SDK queued | pending=$cached")
                    } else if (cached > 0) {
                        Log.d("VietmapSync", "⏫ SDK uploading | pending=$cached")
                    }
                } catch (_: Exception) {}

                mainHandler.post {
                    val locationData = mapOf(
                        "lat" to location.lat,
                        "lng" to location.lng,
                        "accuracy" to location.accuracy,
                        "speed" to location.speed,
                        "heading" to location.bearing,
                        "timestamp" to location.timestamp
                    )
                    locationStreamHandler.send(locationData)
                }
            }
            vietmapSDK.addLocationCallback(locationCallback!!)

            // onTrackingStatusChanged → tracking status EventChannel
            statusCallback = VietmapTrackingSDK.TrackingStatusCallback { isTracking, message ->
                mainHandler.post {
                    val statusData = mapOf(
                        "isTracking" to isTracking,
                        "message" to message,
                        "timestamp" to System.currentTimeMillis()
                    )
                    trackingStatusStreamHandler.send(statusData)
                }
            }
            vietmapSDK.addStatusCallback(statusCallback!!)

            // Fake GPS detection — native debounces at 30s
            // Fires before shouldProcessLocation() — detected even if point would be skipped
            fakeGpsCallback = VietmapTrackingSDK.FakeGPSCallback { lat, lng ->
                mainHandler.post {
                    val payload = mapOf(
                        "lat" to lat,
                        "lng" to lng,
                        "timestamp" to System.currentTimeMillis().toDouble() / 1000.0,
                        "isFirstDetection" to true
                        // Note: Android SDK does not provide a "reason" field
                    )
                    channel.invokeMethod("onFakeGPSDetected", payload)
                }
            }
            vietmapSDK.addFakeGPSCallback(fakeGpsCallback!!)
        }
    }

    private fun clearSDKCallbacks() {
        try {
            locationCallback?.let { vietmapSDK.removeLocationCallback(it) }
            statusCallback?.let { vietmapSDK.removeStatusCallback(it) }
            fakeGpsCallback?.let { vietmapSDK.removeFakeGPSCallback(it) }
            locationCallback = null
            statusCallback = null
            fakeGpsCallback = null
        } catch (_: Exception) {
        }
    }

    // ── Network Monitor: kick uploadCachedLocationsManually() khi network restored ──
    // Tránh chờ timer 30s của SDK bằng cách trigger upload ngay khi có mạng trở lại.
    private fun setupSyncLoggerRetention() {
        val tag = "VietmapSync"
        try {
            val cm = context.getSystemService(Context.CONNECTIVITY_SERVICE) as ConnectivityManager
            val request = NetworkRequest.Builder()
                .addCapability(NetworkCapabilities.NET_CAPABILITY_INTERNET)
                .build()

            networkCallback = object : ConnectivityManager.NetworkCallback() {
                override fun onAvailable(network: Network) {
                    try {
                        val cached = vietmapSDK.getCachedLocationsCount()
                        Log.i(tag, "🟢 Network RESTORED | pendingRecords=$cached")
                        if (cached > 0) {
                            Log.i(tag, "⏫ Triggering SDK uploadCachedLocationsManually ($cached records)...")
                            vietmapSDK.uploadCachedLocationsManually()
                            // Log kết quả sau 3s
                            mainHandler.postDelayed({
                                try {
                                    val remaining = vietmapSDK.getCachedLocationsCount()
                                    Log.i(tag, "✅ After manual upload | remaining=$remaining")
                                } catch (_: Exception) {}
                            }, 3000L)
                        }
                    } catch (e: Exception) {
                        Log.i(tag, "🟢 Network RESTORED (cache check failed: ${e.message})")
                    }
                }

                override fun onLost(network: Network) {
                    try {
                        val cached = vietmapSDK.getCachedLocationsCount()
                        Log.w(tag, "🔴 Network LOST | cachedSoFar=$cached")
                    } catch (_: Exception) {
                        Log.w(tag, "🔴 Network LOST")
                    }
                }
            }
            cm.registerNetworkCallback(request, networkCallback!!)
            Log.d(tag, "✅ Network monitor registered")
        } catch (e: Exception) {
            Log.w(tag, "⚠️ Could not setup network monitor: ${e.message}")
        }
    }

    private fun teardownSyncLogger() {
        try {
            networkCallback?.let {
                val cm = context.getSystemService(Context.CONNECTIVITY_SERVICE) as ConnectivityManager
                cm.unregisterNetworkCallback(it)
            }
            networkCallback = null
        } catch (_: Exception) {}
    }

    // ============================================================
    // MARK: - MethodChannel Dispatcher
    // ============================================================

    override fun onMethodCall(call: MethodCall, result: Result) {
        when (call.method) {
            // Configuration
            "configure" -> handleConfigure(call, result)
            "configureAlertAPI" -> handleConfigureAlertAPI(call, result)

            // Permissions
            "requestLocationPermissions" -> handleRequestLocationPermissions(result)
            "hasLocationPermissions" -> handleHasLocationPermissions(result)
            "requestAlwaysLocationPermissions" -> handleRequestAlwaysLocationPermissions(result)

            // Tracking
            "startTracking" -> handleStartTracking(call, result)
            "stopTracking" -> handleStopTracking(result)
            "getCurrentLocation" -> handleGetCurrentLocation(result)
            "isTrackingActive" -> handleIsTrackingActive(result)
            "getTrackingStatus" -> handleGetTrackingStatus(result)
            "getTrackingHealthStatus" -> handleGetTrackingHealthStatus(result)
            "getTrackingHistory" -> handleGetTrackingHistory(call, result)
            "updateTrackingConfig" -> handleUpdateTrackingConfig(call, result)

            // Alert
            "turnOnAlert" -> handleTurnOnAlert(result)
            "turnOffAlert" -> handleTurnOffAlert(result)
            "isSpeedAlertActive" -> handleIsSpeedAlertActive(result)
            "configureVehicle" -> handleConfigureVehicle(call, result)

            // Identifiers
            "setVehicleId" -> handleSetVehicleId(call, result)
            "setDriverId" -> handleSetDriverId(call, result)
            "getVehicleId" -> handleGetVehicleId(result)
            "getDriverId" -> handleGetDriverId(result)

            // Auto upload
            "setAutoUpload" -> handleSetAutoUpload(call, result)

            // Smart Battery
            "setSmartBatteryConfig" -> handleSetSmartBatteryConfig(call, result)

            // External GPS
            "processExternalLocation" -> handleProcessExternalLocation(call, result)

            // Cache & Network
            "isNetworkConnected" -> handleIsNetworkConnected(result)
            "getCachedLocationsCount" -> handleGetCachedLocationsCount(result)
            "uploadCachedLocationsManually" -> handleUploadCachedLocationsManually(result)
            "clearCachedLocations" -> handleClearCachedLocations(result)
            "configureCacheLimits" -> handleConfigureCacheLimits(call, result)
            "getDatabaseSizeBytes" -> handleGetDatabaseSizeBytes(result)

            // Lifecycle
            "onAppBackground" -> handleOnAppBackground(result)
            "onAppForeground" -> handleOnAppForeground(result)

            // Fake GPS
            "setFakeGPSPolicy" -> handleSetFakeGPSPolicy(call, result)

            // Platform info
            "getPlatformVersion" -> result.success("Android ${Build.VERSION.RELEASE}")

            else -> result.notImplemented()
        }
    }

    // ============================================================
    // MARK: - Configuration Methods
    // ============================================================

    /**
     * configure(apiKey, baseURL?)
     *
     */
    private fun handleConfigure(call: MethodCall, result: Result) {
        withSection("Configure SDK") {
            try {
                val apiKey = call.argument<String>("apiKey")
                val baseURL = call.argument<String>("baseURL")

                if (apiKey.isNullOrEmpty()) {
                    result.error("INVALID_ARGUMENTS", "API key is required", null)
                    return
                }

                // Store configuration
                this.apiKey = apiKey
                this.baseURL = baseURL


                // Initialize VietmapTrackingSDK with API key 
                if (!baseURL.isNullOrEmpty()) {
                    vietmapSDK.initialize(apiKey, baseURL)
                } else {
                    vietmapSDK.initialize(apiKey)
                }

                isInitialized = true

                // Setup SDK event callbacks after initialization 
                setupSDKCallbacks()

                // ── Sync Logger: setup retention callback via reflection ──
                setupSyncLoggerRetention()

                result.success(true)

            } catch (e: Exception) {
                isInitialized = false
                result.error(
                    "CONFIGURE_FAILED",
                    "Failed to configure VietmapTrackingSDK: ${e.message}",
                    null
                )
            }
        }
    }

    /**
     * configureAlertAPI(apiKey, apiID)
     *
     */
    private fun handleConfigureAlertAPI(call: MethodCall, result: Result) {
        withSection("Configure Alert API") {
            if (!isInitialized) {
                result.error("SDK_NOT_INITIALIZED", "VietmapTrackingSDK not initialized", null)
                return
            }

            try {
                val apiKey = call.argument<String>("apiKey")
                val apiID = call.argument<String>("apiID")

                if (apiKey.isNullOrEmpty() || apiID.isNullOrEmpty()) {
                    result.error("INVALID_ARGUMENTS", "Alert API key and ID are required", null)
                    return
                }

                vietmapSDK.configureAlertAPI(apiKey, apiID)
                result.success(true)

            } catch (e: Exception) {
                result.error(
                    "ALERT_CONFIG_FAILED",
                    "Failed to configure Alert API: ${e.message}",
                    null
                )
            }
        }
    }

    // ============================================================
    // MARK: - Permission Methods
    // ============================================================

    /** Helper: check if basic location permissions are granted */
    private fun hasLocationPermission(): Boolean {
        val fineLocation = ContextCompat.checkSelfPermission(
            context, Manifest.permission.ACCESS_FINE_LOCATION
        ) == PackageManager.PERMISSION_GRANTED

        val coarseLocation = ContextCompat.checkSelfPermission(
            context, Manifest.permission.ACCESS_COARSE_LOCATION
        ) == PackageManager.PERMISSION_GRANTED

        return fineLocation && coarseLocation
    }

    /** Helper: check if background location permission is granted */
    private fun hasBackgroundLocationPermission(): Boolean {
        return if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
            ContextCompat.checkSelfPermission(
                context, Manifest.permission.ACCESS_BACKGROUND_LOCATION
            ) == PackageManager.PERMISSION_GRANTED
        } else {
            true // Automatically granted on Android < 10
        }
    }

    /**
     * requestLocationPermissions() → PermissionResult
     *
     */
    private fun handleRequestLocationPermissions(result: Result) {
        withSection("Request Location Permissions") {
            val currentActivity = activity
            if (currentActivity == null) {
                result.error("NO_ACTIVITY", "No activity available for permission request", null)
                return
            }

            // Already have permissions
            if (hasLocationPermission()) {
                val backgroundGranted = hasBackgroundLocationPermission()
                result.success(
                    mapOf(
                        "granted" to true,
                        "status" to "granted",
                        "fineLocation" to true,
                        "coarseLocation" to true,
                        "backgroundLocation" to backgroundGranted
                    )
                )
                return
            }

            // Store pending result
            pendingPermissionResult = result

            // Request basic location permissions only.
            // On Android 11+ (API 30), ACCESS_BACKGROUND_LOCATION must NOT be
            // requested together with foreground permissions — Android will
            // silently ignore the entire request if combined. Background
            // permission should be requested separately via
            // requestAlwaysLocationPermissions() after foreground is granted.
            val permissions = arrayOf(
                Manifest.permission.ACCESS_FINE_LOCATION,
                Manifest.permission.ACCESS_COARSE_LOCATION
            )

            ActivityCompat.requestPermissions(
                currentActivity,
                permissions,
                PERMISSION_REQUEST_CODE
            )
        }
    }

    /**
     * hasLocationPermissions() → PermissionResult
     *
     */
    private fun handleHasLocationPermissions(result: Result) {
        val fineLocation = ContextCompat.checkSelfPermission(
            context, Manifest.permission.ACCESS_FINE_LOCATION
        ) == PackageManager.PERMISSION_GRANTED

        val coarseLocation = ContextCompat.checkSelfPermission(
            context, Manifest.permission.ACCESS_COARSE_LOCATION
        ) == PackageManager.PERMISSION_GRANTED

        val backgroundLocation = hasBackgroundLocationPermission()
        val granted = fineLocation && coarseLocation

        result.success(
            mapOf(
                "granted" to granted,
                "status" to if (granted) "granted" else "not_granted",
                "fineLocation" to fineLocation,
                "coarseLocation" to coarseLocation,
                "backgroundLocation" to backgroundLocation
            )
        )
    }

    /**
     * requestAlwaysLocationPermissions() → String ("granted"/"denied"/"when_in_use")
     *
     */
    private fun handleRequestAlwaysLocationPermissions(result: Result) {
        withSection("Request Always Location Permissions") {
            val currentActivity = activity
            if (currentActivity == null) {
                result.success("denied")
                return
            }

            val hasFineLocation = ContextCompat.checkSelfPermission(
                context, Manifest.permission.ACCESS_FINE_LOCATION
            ) == PackageManager.PERMISSION_GRANTED

            val hasCoarseLocation = ContextCompat.checkSelfPermission(
                context, Manifest.permission.ACCESS_COARSE_LOCATION
            ) == PackageManager.PERMISSION_GRANTED

            val hasBackground = hasBackgroundLocationPermission()

            // Already have all permissions
            if (hasFineLocation && hasCoarseLocation && hasBackground) {
                result.success("granted")
                return
            }

            // Need basic permissions first
            if (!hasFineLocation || !hasCoarseLocation) {
                pendingAlwaysPermissionResult = result

                val permissionsToRequest = mutableListOf<String>()
                if (!hasFineLocation) {
                    permissionsToRequest.add(Manifest.permission.ACCESS_FINE_LOCATION)
                }
                if (!hasCoarseLocation) {
                    permissionsToRequest.add(Manifest.permission.ACCESS_COARSE_LOCATION)
                }

                ActivityCompat.requestPermissions(
                    currentActivity,
                    permissionsToRequest.toTypedArray(),
                    PERMISSION_REQUEST_CODE
                )
                return
            }

            // Basic permissions granted, need background (Android 10+)
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
                pendingAlwaysPermissionResult = result

                ActivityCompat.requestPermissions(
                    currentActivity,
                    arrayOf(Manifest.permission.ACCESS_BACKGROUND_LOCATION),
                    BACKGROUND_PERMISSION_REQUEST_CODE
                )
                return
            }

            // All permissions granted (pre-Android 10, background is implicit)
            result.success("granted")
        }
    }

    // ============================================================
    // MARK: - Permission Result Handling
    // ============================================================

    override fun onRequestPermissionsResult(
        requestCode: Int,
        permissions: Array<out String>,
        grantResults: IntArray
    ): Boolean {
        when (requestCode) {
            PERMISSION_REQUEST_CODE -> {
                handleLocationPermissionResult(permissions, grantResults)
                return true
            }
            BACKGROUND_PERMISSION_REQUEST_CODE -> {
                handleBackgroundPermissionResult(permissions, grantResults)
                return true
            }
        }
        return false
    }

    private fun handleLocationPermissionResult(
        permissions: Array<out String>,
        grantResults: IntArray
    ) {
        // Determine which flow this is for
        val isAlwaysFlow = pendingAlwaysPermissionResult != null

        var fineLocationGranted = false
        var coarseLocationGranted = false
        var backgroundLocationGranted = hasBackgroundLocationPermission()

        for (i in permissions.indices) {
            when (permissions[i]) {
                Manifest.permission.ACCESS_FINE_LOCATION -> {
                    fineLocationGranted = grantResults[i] == PackageManager.PERMISSION_GRANTED
                }
                Manifest.permission.ACCESS_COARSE_LOCATION -> {
                    coarseLocationGranted = grantResults[i] == PackageManager.PERMISSION_GRANTED
                }
                Manifest.permission.ACCESS_BACKGROUND_LOCATION -> {
                    backgroundLocationGranted = grantResults[i] == PackageManager.PERMISSION_GRANTED
                }
            }
        }

        val allBasicGranted = fineLocationGranted && coarseLocationGranted

        if (isAlwaysFlow) {
            val result = pendingAlwaysPermissionResult ?: return

            if (allBasicGranted) {
                // Basic granted, now check if we need background permission
                if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q && !hasBackgroundLocationPermission()) {
                    val currentActivity = activity
                    if (currentActivity != null) {
                        // Request background permission as second step (RN pattern)
                        ActivityCompat.requestPermissions(
                            currentActivity,
                            arrayOf(Manifest.permission.ACCESS_BACKGROUND_LOCATION),
                            BACKGROUND_PERMISSION_REQUEST_CODE
                        )
                        // Don't resolve yet — wait for background result
                        return
                    } else {
                        pendingAlwaysPermissionResult = null
                        result.success("denied")
                    }
                } else {
                    pendingAlwaysPermissionResult = null
                    result.success("granted")
                }
            } else {
                pendingAlwaysPermissionResult = null
                result.success("denied")
            }
        } else {
            // Regular requestLocationPermissions flow
            val result = pendingPermissionResult ?: return
            pendingPermissionResult = null

            result.success(
                mapOf(
                    "granted" to allBasicGranted,
                    "status" to if (allBasicGranted) "granted" else "denied",
                    "fineLocation" to fineLocationGranted,
                    "coarseLocation" to coarseLocationGranted,
                    "backgroundLocation" to backgroundLocationGranted
                )
            )
        }
    }

    private fun handleBackgroundPermissionResult(
        permissions: Array<out String>,
        grantResults: IntArray
    ) {
        val result = pendingAlwaysPermissionResult ?: return
        pendingAlwaysPermissionResult = null

        var backgroundGranted = false
        for (i in permissions.indices) {
            if (permissions[i] == Manifest.permission.ACCESS_BACKGROUND_LOCATION) {
                backgroundGranted = grantResults[i] == PackageManager.PERMISSION_GRANTED
                break
            }
        }

        result.success(if (backgroundGranted) "granted" else "denied")
    }

    // ============================================================
    // MARK: - Tracking Methods
    // ============================================================

    /**
     * startTracking(config) → bool
     *
     */
    private fun handleStartTracking(call: MethodCall, result: Result) {
        withSection("Start Tracking SDK") {
            if (!isInitialized) {
                result.error("SDK_NOT_INITIALIZED", "VietmapTrackingSDK not initialized", null)
                return
            }

            if (!hasLocationPermission()) {
                result.error("PERMISSION_DENIED", "Location permission not granted", null)
                return
            }

            try {
                val args = call.arguments as? Map<*, *>

                val intervalMs = (args?.get("intervalMs") as? Number)?.toLong() ?: 5000L
                val distanceFilter = (args?.get("distanceFilter") as? Number)?.toDouble() ?: 10.0
                val backgroundMode = args?.get("backgroundMode") as? Boolean ?: true
                val notificationTitle = args?.get("notificationTitle") as? String
                val notificationMessage = args?.get("notificationMessage") as? String

                val deviceId = args?.get("deviceId") as? String
                val userId = args?.get("userId") as? String
                val vehicleId = args?.get("vehicleId") as? String

                // Store in instance properties
                this.deviceId = deviceId
                this.userId = userId
                this.vehicleId = vehicleId

                Log.d("VietmapTrackingPlugin", "🚀 startTracking | interval=${intervalMs}ms distance=${distanceFilter}m bg=$backgroundMode")
                Log.d("VietmapTrackingPlugin", "🆔 device=$deviceId user=$userId vehicle=$vehicleId")

                // Set metadata — must happen before startTracking()
                if (!vehicleId.isNullOrEmpty()) vietmapSDK.setVehicleId(vehicleId)
                if (!notificationTitle.isNullOrEmpty()) vietmapSDK.setNotificationTitle(notificationTitle)
                if (!notificationMessage.isNullOrEmpty()) vietmapSDK.setNotificationText(notificationMessage)

                // ── Khởi động Foreground Service trên main thread ngay lập tức ──
                // Android yêu cầu startForeground() được gọi trong vòng 5s sau
                // startForegroundService(). KHÔNG gọi setTrackingConfig() ở đây.
                //
                // setEnhancedBackgroundMode(true) phải được gọi TRƯỚC startTracking():
                //   - Khi isTracking=false → chỉ set field, KHÔNG gọi startBackgroundService()
                //   - startTracking() kiểm tra field này → tự gọi startBackgroundService() 1 lần
                // Nếu gọi setEnhancedBackgroundMode(true) SAU startTracking() (isTracking=true)
                //   → gọi startBackgroundService() lần 2 → reset window 5s → crash!
                if (backgroundMode) {
                    vietmapSDK.setEnhancedBackgroundMode(true)
                }
                vietmapSDK.startTracking()
                trackingStartTime = System.currentTimeMillis()
                Log.d("VietmapTrackingPlugin", "✅ startTracking() dispatched — config sẽ được apply bởi SmartBatteryManager sau 6s")

                result.success(true)

            } catch (e: Exception) {
                Log.e("VietmapTrackingPlugin", "❌ Error starting tracking: ${e.message}", e)
                result.success(false)
            }
        }
    }

    /**
     * stopTracking() → bool
     *
     */
    private fun handleStopTracking(result: Result) {
        withSection("Stop Tracking SDK") {
            if (!isInitialized) {
                result.error("SDK_NOT_INITIALIZED", "VietmapTrackingSDK not initialized", null)
                return
            }

            try {
                vietmapSDK.stopTracking()
                trackingStartTime = 0L
                lastLocationTimestamp = 0L
                result.success(true)
            } catch (_: Exception) {
                result.success(false)
            }
        }
    }

    /**
     * getCurrentLocation() → LocationData map
     *
     * Matches iOS: trackingManager.getCurrentLocation() -> NSDictionary?
     *
     * Uses VietmapTrackingSDK.getLastLocation() to return the most recent known location.
     */
    private fun handleGetCurrentLocation(result: Result) {
        withSection("Get Current Location") {
            if (!isInitialized) {
                result.error("SDK_NOT_INITIALIZED", "VietmapTrackingSDK not initialized", null)
                return
            }

            try {
                val location: VMLocation? = vietmapSDK.getLastLocation();
                if (location != null) {
                    val locationMap = mapOf(
                        "lat" to location.lat,
                        "lng" to location.lng,
                        "accuracy" to location.accuracy,
                        "speed" to location.speed,
                        "heading" to location.bearing,
                        "timestamp" to location.timestamp
                    )
                    result.success(locationMap)
                } else {
                    result.error("LOCATION_UNAVAILABLE", "No location available yet", null)
                }
            } catch (e: Exception) {
                result.error("LOCATION_UNAVAILABLE", "Unable to get current location: ${e.message}", null)
            }
        }
    }

    /**
     * isTrackingActive() → bool
     *
     */
    private fun handleIsTrackingActive(result: Result) {
        if (!isInitialized) {
            result.success(false)
            return
        }

        try {
            val isActive = vietmapSDK.isTracking()
            result.success(isActive)
        } catch (_: Exception) {
            result.success(false)
        }
    }

    /**
     * getTrackingStatus() → TrackingStatus map
     *
     */
    private fun handleGetTrackingStatus(result: Result) {
        if (!isInitialized) {
            result.error("SDK_NOT_INITIALIZED", "VietmapTrackingSDK not initialized", null)
            return
        }

        try {
            val isActive = vietmapSDK.isTracking()
            val now = System.currentTimeMillis()

            val duration = if (isActive && trackingStartTime > 0L) {
                (now - trackingStartTime)
            } else {
                0L
            }

            val status = mutableMapOf<String, Any>(
                "isTracking" to isActive,
                "trackingDuration" to duration
            )

            if (lastLocationTimestamp > 0L) {
                status["lastLocationUpdate"] = lastLocationTimestamp
            }

            result.success(status)
        } catch (e: Exception) {
            result.error("STATUS_ERROR", "Failed to get tracking status: ${e.message}", null)
        }
    }

    /**
     * getTrackingHealthStatus() → Map
     *
     * Matches iOS: trackingManager.getTrackingHealthStatus()
     * Returns health diagnostics about the tracking system.
     */
    private fun handleGetTrackingHealthStatus(result: Result) {
        if (!isInitialized) {
            result.error("SDK_NOT_INITIALIZED", "VietmapTrackingSDK not initialized", null)
            return
        }

        try {
            val isActive = vietmapSDK.isTracking()
            val now = System.currentTimeMillis()
            val hasPermission = hasLocationPermission()
            val hasBackgroundPermission = hasBackgroundLocationPermission()

            val duration = if (isActive && trackingStartTime > 0L) {
                (now - trackingStartTime)
            } else {
                0L
            }

            val timeSinceLastUpdate = if (lastLocationTimestamp > 0L) {
                (now - lastLocationTimestamp)
            } else {
                -1L  // No location received yet
            }

            val healthStatus = mutableMapOf<String, Any>(
                "isTracking" to isActive,
                "hasLocationPermission" to hasPermission,
                "hasBackgroundPermission" to hasBackgroundPermission,
                "trackingDuration" to duration,
                "timeSinceLastUpdate" to timeSinceLastUpdate,
                "isInitialized" to isInitialized,
                "timestamp" to now
            )

            if (lastLocationTimestamp > 0L) {
                healthStatus["lastLocationUpdate"] = lastLocationTimestamp
            }

            result.success(healthStatus)
        } catch (e: Exception) {
            result.error(
                "HEALTH_STATUS_ERROR",
                "Failed to get tracking health status: ${e.message}",
                null
            )
        }
    }

    private fun handleGetTrackingHistory(call: MethodCall, result: Result) {
        withSection("Get Tracking History") {
            if (!isInitialized) {
                result.error("SDK_NOT_INITIALIZED", "VietmapTrackingSDK not initialized", null)
                return
            }

            try {
                val args = call.arguments as? Map<*, *> ?: emptyMap<Any, Any>()
                val userId = (args["userId"] as? String)?.trim().orEmpty()
                val fromTime = (args["fromTime"] as? Number)?.toLong() ?: 0L
                val toTime = (args["toTime"] as? Number)?.toLong() ?: 0L
                val pageNumber = (args["pageNumber"] as? Number)?.toInt() ?: 1
                val pageSize = (args["pageSize"] as? Number)?.toInt() ?: 100
                val sortBy = (args["sortBy"] as? String)?.trim().orEmpty().ifEmpty { "timestamp" }
                val sortDescending = args["sortDescending"] as? Boolean ?: false

                if (userId.isEmpty()) {
                    result.error("INVALID_ARGUMENTS", "userId is required", null)
                    return
                }

                if (fromTime <= 0L || toTime <= 0L || fromTime > toTime) {
                    result.error("INVALID_ARGUMENTS", "fromTime/toTime are invalid", null)
                    return
                }

                Log.d(
                    "VietmapTrackingPlugin",
                    "📜 getTrackingHistory | userId=$userId from=$fromTime to=$toTime page=$pageNumber size=$pageSize sortBy=$sortBy desc=$sortDescending"
                )

                vietmapSDK.getHistory(
                    userId,
                    fromTime,
                    toTime,
                    pageNumber,
                    pageSize,
                    sortBy,
                    sortDescending,
                    object : VietmapTrackingSDK.HistoryCallback {
                        override fun onHistorySuccess(historyJson: String) {
                            mainHandler.post {
                                result.success(historyJson)
                            }
                        }

                        override fun onHistoryError(errorCode: String, message: String) {
                            mainHandler.post {
                                result.error(
                                    "GET_TRACKING_HISTORY_FAILED",
                                    "[$errorCode] $message",
                                    mapOf("code" to errorCode, "message" to message)
                                )
                            }
                        }
                    }
                )
            } catch (e: Exception) {
                result.error(
                    "GET_TRACKING_HISTORY_ERROR",
                    "Failed to get tracking history: ${e.message}",
                    null
                )
            }
        }
    }

    /**
     * updateTrackingConfig(config) → bool
     *
     */
    private fun handleUpdateTrackingConfig(call: MethodCall, result: Result) {
        withSection("Update Tracking Config") {
            if (!isInitialized) {
                result.error("SDK_NOT_INITIALIZED", "VietmapTrackingSDK not initialized", null)
                return
            }

            try {
                val args = call.arguments as? Map<*, *>
                val intervalMs = (args?.get("intervalMs") as? Number)?.toLong() ?: 5000L
                val distanceFilter = (args?.get("distanceFilter") as? Number)?.toDouble() ?: 10.0

                // Use safe reflection-based update to avoid SDK's setDistanceFilter()
                // which internally does stopTracking()+startTracking() and restarts
                // the Foreground Service, causing ForegroundServiceDidNotStartInTimeException.
                safeUpdateTrackingConfig(intervalMs, distanceFilter)

                // Handle explicit background mode disable request from user
                val userBgArg = args?.get("backgroundMode") as? Boolean
                if (userBgArg == false) {
                    vietmapSDK.setEnhancedBackgroundMode(false)
                    Log.d("VietmapTrackingPlugin", "🔕 Background mode explicitly disabled by user")
                }

                result.success(true)

            } catch (e: Exception) {
                result.error(
                    "CONFIG_UPDATE_ERROR",
                    "Failed to update tracking config: ${e.message}",
                    null
                )
            }
        }
    }

    // ============================================================
    // MARK: - Alert Methods
    // ============================================================

    /**
     * turnOnAlert() → bool
     *
     */
    private fun handleTurnOnAlert(result: Result) {
        withSection("Turn On Alert") {
            if (!isInitialized) {
                result.error("SDK_NOT_INITIALIZED", "VietmapTrackingSDK not initialized", null)
                return
            }

            try {
                val success = vietmapSDK.startAlert()
                result.success(success)
            } catch (_: Exception) {
                result.success(false)
            }
        }
    }

    /**
     * turnOffAlert() → bool
     *
     */
    private fun handleTurnOffAlert(result: Result) {
        withSection("Turn Off Alert") {
            if (!isInitialized) {
                result.error("SDK_NOT_INITIALIZED", "VietmapTrackingSDK not initialized", null)
                return
            }

            try {
                val success = vietmapSDK.stopAlert()
                result.success(success)
            } catch (_: Exception) {
                result.success(false)
            }
        }
    }

    // ============================================================
    // MARK: - Alert Extended Methods
    // ============================================================

    private fun handleIsSpeedAlertActive(result: Result) {
        withSection("Check Speed Alert State") {
            if (!isInitialized) { result.success(false); return }
            try { result.success(vietmapSDK.isAlertActive()) }
            catch (_: Exception) { result.success(false) }
        }
    }

    private fun handleConfigureVehicle(call: MethodCall, result: Result) {
        withSection("Configure Vehicle") {
            if (!isInitialized) {
                result.error("SDK_NOT_INITIALIZED", "VietmapTrackingSDK not initialized", null); return
            }
            try {
                val args = call.arguments as? Map<*, *>
                val vId = args?.get("vehicleId") as? String ?: ""
                val vType = (args?.get("vehicleType") as? Number)?.toInt() ?: 0
                val seats = (args?.get("seats") as? Number)?.toInt() ?: 0
                val weight = (args?.get("weight") as? Number)?.toDouble() ?: 0.0
                val maxProv = (args?.get("maxProvision") as? Number)?.toInt() ?: 0
                // SDK 1.0.4: configureVehicle(vehicleId: String, vehicleType: int, seats: int, weight: double, maxProvision: int)
                vietmapSDK.configureVehicle(vId, vType, seats, weight, maxProv)
                result.success(true)
            } catch (e: Exception) { result.error("CONFIGURE_VEHICLE_ERROR", e.message, null) }
        }
    }

    // ============================================================
    // MARK: - Identifier Methods
    // ============================================================

    private fun handleSetVehicleId(call: MethodCall, result: Result) {
        if (!isInitialized) {
            result.error("SDK_NOT_INITIALIZED", "VietmapTrackingSDK not initialized", null); return
        }
        try {
            val id = call.argument<String>("vehicleId") ?: ""
            this.vehicleId = id
            vietmapSDK.setVehicleId(id)
            result.success(true)
        } catch (e: Exception) { result.error("SET_VEHICLE_ID_ERROR", e.message, null) }
    }

    private fun handleSetDriverId(call: MethodCall, result: Result) {
        if (!isInitialized) {
            result.error("SDK_NOT_INITIALIZED", "VietmapTrackingSDK not initialized", null); return
        }
        try {
            val id = call.argument<String>("driverId") ?: ""
            this.userId = id
            vietmapSDK.setDriverId(id)
            result.success(true)
        } catch (e: Exception) { result.error("SET_DRIVER_ID_ERROR", e.message, null) }
    }

    /** Android SDK does not expose a getter — return the locally cached value. */
    private fun handleGetVehicleId(result: Result) { result.success(vehicleId) }
    private fun handleGetDriverId(result: Result) { result.success(userId) }

    // ============================================================
    // MARK: - Smart Battery Config
    // ============================================================

    /**
     * setSmartBatteryConfig(enabled: bool, preset: String)
     *
     * Bật/tắt tối ưu pin thông minh trên Android.
     * - enabled=true → áp dụng TrackingConfig phù hợp với preset ngay lập tức
     *   (SmartBatteryManager trên Dart cũng gọi khi phát hiện pin thấp / xe dừng)
     * - preset: "navigation" | "general" | "batterySaver"
     *   Ánh xạ trực tiếp vào TrackingConfig: interval, distance filter
     */
    private fun handleSetSmartBatteryConfig(call: MethodCall, result: Result) {
        if (!isInitialized) {
            result.error("SDK_NOT_INITIALIZED", "VietmapTrackingSDK not initialized", null); return
        }
        try {
            val args = call.arguments as? Map<*, *>
            val enabled = args?.get("enabled") as? Boolean ?: false
            val preset = args?.get("preset") as? String ?: "general"
            smartBatteryEnabled = enabled
            smartBatteryPreset = preset

            val tag = "VietmapBattery"
            Log.i(tag, "🔋 setSmartBatteryConfig | enabled=$enabled preset=$preset")

            // Use safeUpdateTrackingConfig (reflection) to avoid SDK's setDistanceFilter()
            // which internally does stopTracking()+startTracking() and restarts the
            // Foreground Service → ForegroundServiceDidNotStartInTimeException crash.
            // No 6s guard needed — safeUpdateTrackingConfig never restarts the service.
            if (enabled && vietmapSDK.isTracking()) {
                when (preset) {
                    "navigation" -> {
                        safeUpdateTrackingConfig(3000L, 5.0)
                        Log.i(tag, "🚗 Preset=navigation | interval=3s distance=5m")
                    }
                    "batterySaver" -> {
                        safeUpdateTrackingConfig(30000L, 50.0)
                        Log.i(tag, "🔋 Preset=batterySaver | interval=30s distance=50m")
                    }
                    else -> {
                        safeUpdateTrackingConfig(10000L, 15.0)
                        Log.i(tag, "⚙️ Preset=general | interval=10s distance=15m")
                    }
                }
                Log.i(tag, "✅ TrackingConfig applied for preset=$preset")
            } else if (!enabled && vietmapSDK.isTracking()) {
                safeUpdateTrackingConfig(5000L, 10.0)
                Log.i(tag, "✅ SmartBattery disabled → restored default config")
            }

            result.success(true)
        } catch (e: Exception) {
            Log.e("VietmapBattery", "❌ setSmartBatteryConfig error: ${e.message}")
            result.error("SMART_BATTERY_ERROR", e.message, null)
        }
    }

    // ============================================================
    // MARK: - Auto Upload
    // ============================================================

    private fun handleSetAutoUpload(call: MethodCall, result: Result) {
        // Android SDK 1.0.4 does not expose a setAutoUpload method.
        // Tracking uploads happen automatically when data is sent to the server.
        // We acknowledge the call gracefully so cross-platform code remains compatible.
        result.success(true)
    }

    // ============================================================
    // MARK: - External GPS Injection
    // ============================================================

    private fun handleProcessExternalLocation(call: MethodCall, result: Result) {
        if (!isInitialized) {
            result.error("SDK_NOT_INITIALIZED", "VietmapTrackingSDK not initialized", null); return
        }
        try {
            val args = call.arguments as? Map<*, *>
            val lat = (args?.get("lat") as? Number)?.toDouble() ?: 0.0
            val lng = (args?.get("lng") as? Number)?.toDouble() ?: 0.0
            val speed = (args?.get("speed") as? Number)?.toDouble() ?: 0.0
            val heading = (args?.get("heading") as? Number)?.toDouble() ?: 0.0
            // SDK 1.0.4: processLocationWithVehicleParams(lat, lng, speed, heading)
            vietmapSDK.processLocationWithVehicleParams(lat, lng, speed, heading)
            result.success(true)
        } catch (e: Exception) {
            result.error("EXTERNAL_LOCATION_ERROR", e.message, null)
        }
    }

    // ============================================================
    // MARK: - Cache & Network Methods
    // ============================================================

    private fun handleIsNetworkConnected(result: Result) {
        if (!isInitialized) { result.success(false); return }
        try { result.success(vietmapSDK.isNetworkAvailable()) }
        catch (_: Exception) { result.success(false) }
    }

    private fun handleGetCachedLocationsCount(result: Result) {
        if (!isInitialized) { result.success(0); return }
        try { result.success(vietmapSDK.getCachedLocationsCount()) }
        catch (_: Exception) { result.success(0) }
    }

    private fun handleUploadCachedLocationsManually(result: Result) {
        if (!isInitialized) {
            result.error("SDK_NOT_INITIALIZED", "VietmapTrackingSDK not initialized", null); return
        }
        try { vietmapSDK.uploadCachedLocationsManually(); result.success(true) }
        catch (e: Exception) { result.error("UPLOAD_CACHE_ERROR", e.message, null) }
    }

    private fun handleClearCachedLocations(result: Result) {
        if (!isInitialized) {
            result.error("SDK_NOT_INITIALIZED", "VietmapTrackingSDK not initialized", null); return
        }
        try { vietmapSDK.clearCachedLocations(); result.success(true) }
        catch (e: Exception) { result.error("CLEAR_CACHE_ERROR", e.message, null) }
    }

    private fun handleConfigureCacheLimits(call: MethodCall, result: Result) {
        if (!isInitialized) {
            result.error("SDK_NOT_INITIALIZED", "VietmapTrackingSDK not initialized", null); return
        }
        try {
            val args = call.arguments as? Map<*, *>
            val maxRecords = (args?.get("maxRecords") as? Number)?.toInt() ?: 0
            val maxDbSizeBytes = (args?.get("maxDbSizeBytes") as? Number)?.toLong() ?: 0L
            val batchSize = (args?.get("batchSize") as? Number)?.toInt() ?: 0

            // VietmapTrackingSDK does not expose configureLimits directly.
            // Access it via the trackingManager's cacheManager field using reflection.
            val sdkClass = vietmapSDK.javaClass
            val tmField = sdkClass.getDeclaredField("trackingManager").also { it.isAccessible = true }
            val trackingManager = tmField.get(vietmapSDK)
            val cmField = trackingManager.javaClass.getDeclaredField("cacheManager").also { it.isAccessible = true }
            val cacheManager = cmField.get(trackingManager)

            val configureMethod = cacheManager.javaClass.getMethod(
                "configureLimits", Int::class.java, Long::class.java, Int::class.java
            )
            // Use SDK defaults for zero values
            val finalMaxRecords = if (maxRecords > 0) maxRecords else 5000
            val finalMaxDbSize = if (maxDbSizeBytes > 0L) maxDbSizeBytes else 52_428_800L // 50 MB
            val finalBatchSize = if (batchSize > 0) batchSize else 50
            configureMethod.invoke(cacheManager, finalMaxRecords, finalMaxDbSize, finalBatchSize)
            result.success(true)
        } catch (e: Exception) {
            result.error("CONFIGURE_CACHE_ERROR", "configureCacheLimits failed: ${e.message}", null)
        }
    }

    private fun handleGetDatabaseSizeBytes(result: Result) {
        if (!isInitialized) { result.success(0L); return }
        try {
            val sdkClass = vietmapSDK.javaClass
            val tmField = sdkClass.getDeclaredField("trackingManager").also { it.isAccessible = true }
            val trackingManager = tmField.get(vietmapSDK)
            val cmField = trackingManager.javaClass.getDeclaredField("cacheManager").also { it.isAccessible = true }
            val cacheManager = cmField.get(trackingManager)
            val sizeMethod = cacheManager.javaClass.getMethod("getDatabaseSizeBytes")
            val size = sizeMethod.invoke(cacheManager) as? Long ?: 0L
            result.success(size)
        } catch (e: Exception) {
            result.success(0L)
        }
    }

    // ============================================================
    // MARK: - Safe Config Update (bypass SDK's stop+start cycle)
    // ============================================================

    /**
     * Update tracking interval and distance filter WITHOUT restarting the
     * Foreground Service.
     *
     * SDK's `setTrackingConfig()` internally calls:
     *   1. `setTrackingInterval()`  — safe (re-registers FusedLocation only)
     *   2. `setDistanceFilter()`    — UNSAFE: does stopTracking()+startTracking()
     *      which destroys then re-creates the Foreground Service, causing
     *      ForegroundServiceDidNotStartInTimeException on fast config changes.
     *   3. `setEnhancedBackgroundMode()` — UNSAFE when isTracking=true:
     *      calls startBackgroundService() again → double startForegroundService().
     *
     * This helper uses reflection to:
     *   - Call `setTrackingInterval()` (safe, public method)
     *   - Set `distanceFilter` field directly + call `updateLocationRequest()`
     *     to apply the new distance WITHOUT stop+start
     *   - Leave `enhancedBackgroundMode` untouched (already set at startTracking)
     */
    private fun safeUpdateTrackingConfig(intervalMs: Long, distanceFilter: Double) {
        val tag = "VietmapTrackingPlugin"
        try {
            // Get the trackingManager from SDK
            val sdkClass = vietmapSDK.javaClass
            val tmField = sdkClass.getDeclaredField("trackingManager")
            tmField.isAccessible = true
            val trackingManager = tmField.get(vietmapSDK)
                ?: throw IllegalStateException("trackingManager is null")

            // 1. setTrackingInterval() — public, safe (no stop+start)
            val setIntervalMethod = trackingManager.javaClass.getMethod(
                "setTrackingInterval", Long::class.java
            )
            setIntervalMethod.invoke(trackingManager, intervalMs)

            // 2. Set distanceFilter field directly + updateLocationRequest()
            //    This avoids setDistanceFilter() which does stop+start when isTracking=true
            val dfField = trackingManager.javaClass.getDeclaredField("distanceFilter")
            dfField.isAccessible = true
            dfField.setFloat(trackingManager, distanceFilter.toFloat())

            val updateMethod = trackingManager.javaClass.getDeclaredMethod("updateLocationRequest")
            updateMethod.isAccessible = true
            updateMethod.invoke(trackingManager)

            // 3. DO NOT touch enhancedBackgroundMode — it's already set at startTracking()
            //    and must not be changed mid-tracking to avoid startBackgroundService() calls.

            Log.d(tag, "✅ safeUpdateTrackingConfig | interval=${intervalMs}ms distance=${distanceFilter}m")
        } catch (e: Exception) {
            // Fallback: if reflection fails (SDK updated, fields renamed, etc.),
            // log a warning. Do NOT fall back to setTrackingConfig() as that would crash.
            Log.e(tag, "❌ safeUpdateTrackingConfig reflection failed: ${e.message}", e)
        }
    }

    // ============================================================
    // MARK: - App Lifecycle Forwarding
    // ============================================================

    private fun handleOnAppBackground(result: Result) {
        try { if (isInitialized) vietmapSDK.onAppBackground(); result.success(null) }
        catch (_: Exception) { result.success(null) }
    }

    private fun handleOnAppForeground(result: Result) {
        try { if (isInitialized) vietmapSDK.onAppForeground(); result.success(null) }
        catch (_: Exception) { result.success(null) }
    }

    // ============================================================
    // MARK: - Fake GPS Policy
    // ============================================================

    /**
     * setFakeGPSPolicy(policy: String)
     * Valid values: "skip" (default) | "warn" | "stopTracking" | "logToServer"
     * Delegates to VietmapTrackingSDK.setFakeGPSPolicy() which validates internally.
     */
    private fun handleSetFakeGPSPolicy(call: MethodCall, result: Result) {
        try {
            val policy = call.argument<String>("policy") ?: "skip"
            Log.d("VietmapTracking", "⚙️ setFakeGPSPolicy: $policy")
            vietmapSDK.setFakeGPSPolicy(policy)
            result.success(null)
        } catch (e: Exception) {
            result.error("FAKE_GPS_POLICY_ERROR", e.message, null)
        }
    }

    // ============================================================
    // MARK: - ActivityAware Lifecycle
    // ============================================================

    override fun onAttachedToActivity(binding: ActivityPluginBinding) {
        activity = binding.activity
        binding.addRequestPermissionsResultListener(this)
    }

    override fun onDetachedFromActivityForConfigChanges() {
        activity = null
    }

    override fun onReattachedToActivityForConfigChanges(binding: ActivityPluginBinding) {
        activity = binding.activity
        binding.addRequestPermissionsResultListener(this)
    }

    override fun onDetachedFromActivity() {
        activity = null
    }
}

// ============================================================
// MARK: - EventChannel Stream Handler
// ============================================================

/**
 * Generic stream handler for EventChannels.
 */
private class StreamHandler : EventChannel.StreamHandler {
    private var eventSink: EventChannel.EventSink? = null

    override fun onListen(arguments: Any?, events: EventChannel.EventSink?) {
        eventSink = events
    }

    override fun onCancel(arguments: Any?) {
        eventSink = null
    }

    fun send(event: Any) {
        eventSink?.success(event)
    }
}
