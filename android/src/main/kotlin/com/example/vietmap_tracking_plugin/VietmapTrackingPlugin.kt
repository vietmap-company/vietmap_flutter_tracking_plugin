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

    // Permission handling
    private var pendingPermissionResult: Result? = null
    private var pendingAlwaysPermissionResult: Result? = null

    // Main thread handler for dispatching results
    private val mainHandler = Handler(Looper.getMainLooper())

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

    override fun onDetachedFromEngine(binding: FlutterPlugin.FlutterPluginBinding) {
        channel.setMethodCallHandler(null)
        // Clean up SDK callbacks (Flutter EventChannel sinks will be invalid after detach)
        if (isInitialized) {
            clearSDKCallbacks()
            // NOTE: Do NOT call vietmapSDK.stopTracking() here!
            // When backgroundMode is enabled, the SDK's Foreground Service
            // (START_STICKY) must continue running independently even after
            // the Flutter engine is destroyed (app killed / task swiped).
            // The OS will re-create the service automatically.
            // Tracking should only stop when explicitly called via stopTracking().
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
        // Remove old callbacks if any
        clearSDKCallbacks()

        // onLocationUpdate → location EventChannel
        locationCallback = VietmapTrackingSDK.LocationUpdateCallback { location ->
            lastLocationTimestamp = System.currentTimeMillis()
            mainHandler.post {
                val locationData = mapOf(
                    "latitude" to location.latitude,
                    "longitude" to location.longitude,
                    "accuracy" to location.accuracy,
                    "speed" to location.speed,
                    "bearing" to location.bearing,
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
    }

    private fun clearSDKCallbacks() {
        try {
            locationCallback?.let { vietmapSDK.removeLocationCallback(it) }
            statusCallback?.let { vietmapSDK.removeStatusCallback(it) }
            locationCallback = null
            statusCallback = null
        } catch (_: Exception) {
        }
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
            "updateTrackingConfig" -> handleUpdateTrackingConfig(call, result)

            // Alert
            "turnOnAlert" -> handleTurnOnAlert(result)
            "turnOffAlert" -> handleTurnOffAlert(result)

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

    /**
     * configureAlertAPI(apiKey, apiID)
     *
     */
    private fun handleConfigureAlertAPI(call: MethodCall, result: Result) {
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
            
            // NEW: Extract tracking identifiers
            val deviceId = args?.get("deviceId") as? String
            val userId = args?.get("userId") as? String
            val vehicleId = args?.get("vehicleId") as? String
            val apiEndpoint = args?.get("apiEndpoint") as? String
            
            // Store in instance properties for use in location callbacks
            this.deviceId = deviceId
            this.userId = userId
            this.vehicleId = vehicleId

            Log.d("VietmapTrackingPlugin", "════════════════════════════════════")
            Log.d("VietmapTrackingPlugin", "🔧 START TRACKING REQUEST")
            Log.d("VietmapTrackingPlugin", "════════════════════════════════════")
            Log.d("VietmapTrackingPlugin", "📋 Identifiers:")
            Log.d("VietmapTrackingPlugin", "   - Device ID: $deviceId")
            Log.d("VietmapTrackingPlugin", "   - User ID: $userId")
            Log.d("VietmapTrackingPlugin", "   - Vehicle ID: $vehicleId")
            Log.d("VietmapTrackingPlugin", "⚙️  Configuration:")
            Log.d("VietmapTrackingPlugin", "   - API Endpoint: $apiEndpoint")
            Log.d("VietmapTrackingPlugin", "   - Interval: ${intervalMs}ms")
            Log.d("VietmapTrackingPlugin", "   - Distance Filter: ${distanceFilter}m")
            Log.d("VietmapTrackingPlugin", "   - Background Mode: $backgroundMode")
            Log.d("VietmapTrackingPlugin", "🔔 Notification:")
            Log.d("VietmapTrackingPlugin", "   - Title: $notificationTitle")
            Log.d("VietmapTrackingPlugin", "   - Message: $notificationMessage")

            // Set dynamic metadata if provided 
            if (!vehicleId.isNullOrEmpty()) {
                Log.d("VietmapTrackingPlugin", "📍 Setting vehicleId: $vehicleId")
                vietmapSDK.setVehicleId(vehicleId)
            }

            // Set notification parameters if provided 
            if (!notificationTitle.isNullOrEmpty()) {
                Log.d("VietmapTrackingPlugin", "🔔 Setting notification title: $notificationTitle")
                vietmapSDK.setNotificationTitle(notificationTitle)
            }
            if (!notificationMessage.isNullOrEmpty()) {
                Log.d("VietmapTrackingPlugin", "🔔 Setting notification text: $notificationMessage")
                vietmapSDK.setNotificationText(notificationMessage)
            }

            // Configure tracking settings 
            val trackingConfig = TrackingConfig().apply {
                updateInterval = intervalMs
                minDistanceFilter = distanceFilter
                enableBackgroundMode = backgroundMode
            }
            Log.d("VietmapTrackingPlugin", "⚙️ Applying TrackingConfig: interval=$intervalMs, distance=$distanceFilter")
            vietmapSDK.setTrackingConfig(trackingConfig)

            // Start tracking
            Log.d("VietmapTrackingPlugin", "🚀 Starting tracking with SDK v1.3.1+")
            Log.d("VietmapTrackingPlugin", "   📍 Endpoint: https://tracking.fleetwork.vn/api/v1/gps-tracking")
            Log.d("VietmapTrackingPlugin", "   🔑 API Key: ${apiKey?.take(10)}... (masked)")
            Log.d("VietmapTrackingPlugin", "   📋 Device/User/Vehicle IDs configured: $deviceId / $userId / $vehicleId")
            
            vietmapSDK.startTracking()
            trackingStartTime = System.currentTimeMillis()
            Log.d("VietmapTrackingPlugin", "✅ startTracking() returned successfully")
            
            result.success(true)

        } catch (e: Exception) {
            Log.e("VietmapTrackingPlugin", "❌ Error starting tracking: ${e.message}", e)
            result.success(false)
        }
    }

    /**
     * stopTracking() → bool
     *
     */
    private fun handleStopTracking(result: Result) {
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

    /**
     * getCurrentLocation() → LocationData map
     *
     * Matches iOS: trackingManager.getCurrentLocation() -> NSDictionary?
     *
     * Uses VietmapTrackingSDK.getLastLocation() to return the most recent known location.
     */
    private fun handleGetCurrentLocation(result: Result) {
        if (!isInitialized) {
            result.error("SDK_NOT_INITIALIZED", "VietmapTrackingSDK not initialized", null)
            return
        }

        try {
            val location: VMLocation? = vietmapSDK.getLastLocation();
            if (location != null) {
                val locationMap = mapOf(
                    "latitude" to location.latitude,
                    "longitude" to location.longitude,
                    "accuracy" to location.accuracy,
                    "speed" to location.speed,
                    "bearing" to location.bearing,
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

    /**
     * updateTrackingConfig(config) → bool
     *
     */
    private fun handleUpdateTrackingConfig(call: MethodCall, result: Result) {
        if (!isInitialized) {
            result.error("SDK_NOT_INITIALIZED", "VietmapTrackingSDK not initialized", null)
            return
        }

        try {
            val args = call.arguments as? Map<*, *>

            val trackingConfig = TrackingConfig().apply {
                val interval = (args?.get("intervalMs") as? Number)?.toLong()
                if (interval != null) updateInterval = interval

                val distance = (args?.get("distanceFilter") as? Number)?.toDouble()
                if (distance != null) minDistanceFilter = distance

                val background = args?.get("backgroundMode") as? Boolean
                if (background != null) enableBackgroundMode = background
            }

            vietmapSDK.setTrackingConfig(trackingConfig)
            result.success(true)

        } catch (e: Exception) {
            result.error(
                "CONFIG_UPDATE_ERROR",
                "Failed to update tracking config: ${e.message}",
                null
            )
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

    /**
     * turnOffAlert() → bool
     *
     */
    private fun handleTurnOffAlert(result: Result) {
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
