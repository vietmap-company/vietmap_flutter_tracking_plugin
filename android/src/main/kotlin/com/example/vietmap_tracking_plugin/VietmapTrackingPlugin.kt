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
import com.vietmap.trackingsdk.VietmapTrackingSDK
import com.vietmap.trackingsdk.TrackingConfig

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

    // EventChannel stream handlers
    private val locationStreamHandler = StreamHandler()
    private val trackingStatusStreamHandler = StreamHandler()

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
        } catch (e: Exception) {
            isInitialized = false
        }
    }

    override fun onDetachedFromEngine(binding: FlutterPlugin.FlutterPluginBinding) {
        channel.setMethodCallHandler(null)
        // Clean up SDK resources
        if (isInitialized) {
            clearSDKCallbacks()
            try {
                vietmapSDK.stopTracking()
            } catch (_: Exception) {
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
        // onLocationUpdate → location EventChannel
        vietmapSDK.onLocationUpdate = { locationData ->
            mainHandler.post {
                if (locationData is Map<*, *>) {
                    locationStreamHandler.send(locationData)
                }
            }
        }

        // onTrackingStatusChanged → tracking status EventChannel
        vietmapSDK.onTrackingStatusChanged = { statusData ->
            mainHandler.post {
                if (statusData is Map<*, *>) {
                    trackingStatusStreamHandler.send(statusData)
                }
            }
        }

        // onError → send as error event on location channel
        vietmapSDK.onError = { errorMessage ->
            mainHandler.post {
                locationStreamHandler.send(
                    mapOf(
                        "error" to errorMessage,
                        "timestamp" to System.currentTimeMillis()
                    )
                )
            }
        }

        // onPermissionChanged → send on tracking status channel
        vietmapSDK.onPermissionChanged = { status ->
            mainHandler.post {
                trackingStatusStreamHandler.send(
                    mapOf(
                        "permissionStatus" to status,
                        "timestamp" to System.currentTimeMillis()
                    )
                )
            }
        }

        // onRouteUpdate → send on tracking status channel
        vietmapSDK.onRouteUpdate = { success, routeData ->
            mainHandler.post {
                val event = mutableMapOf<String, Any>(
                    "success" to success,
                    "timestamp" to System.currentTimeMillis()
                )
                if (routeData is Map<*, *>) {
                    event["routeData"] = routeData
                }
                trackingStatusStreamHandler.send(event)
            }
        }
    }

    private fun clearSDKCallbacks() {
        try {
            vietmapSDK.onLocationUpdate = null
            vietmapSDK.onTrackingStatusChanged = null
            vietmapSDK.onError = null
            vietmapSDK.onPermissionChanged = null
            vietmapSDK.onRouteUpdate = null
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
     * Matches RN: configure(apiKey, baseURL?, promise)
     * Matches iOS: configure(_ call, result)
     */
    private fun handleConfigure(call: MethodCall, result: Result) {
        try {
            val apiKey = call.argument<String>("apiKey")
            val baseURL = call.argument<String>("baseURL")

            if (apiKey.isNullOrEmpty()) {
                result.error("INVALID_ARGUMENTS", "API key is required", null)
                return
            }

            // Initialize VietmapTrackingSDK with API key (RN pattern)
            if (!baseURL.isNullOrEmpty()) {
                vietmapSDK.initialize(apiKey, baseURL)
            } else {
                vietmapSDK.initialize(apiKey)
            }

            isInitialized = true

            // Setup SDK event callbacks after initialization (iOS pattern)
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
     * Matches RN: configureAlertAPI(apiKey, apiID, promise)
     * Matches iOS: configureAlertAPI(_ call, result)
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
     * Matches RN: requestLocationPermissions(promise)
     * Returns: { granted, status, fineLocation, coarseLocation, backgroundLocation }
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

        // Request permissions (RN pattern: request basic + background together)
        val permissions = mutableListOf(
            Manifest.permission.ACCESS_FINE_LOCATION,
            Manifest.permission.ACCESS_COARSE_LOCATION
        )

        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
            permissions.add(Manifest.permission.ACCESS_BACKGROUND_LOCATION)
        }

        ActivityCompat.requestPermissions(
            currentActivity,
            permissions.toTypedArray(),
            PERMISSION_REQUEST_CODE
        )
    }

    /**
     * hasLocationPermissions() → PermissionResult
     *
     * Matches RN: hasLocationPermissions(promise)
     * Returns: { granted, status, fineLocation, coarseLocation, backgroundLocation }
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
     * Matches RN: requestAlwaysLocationPermissions(promise)
     * Android-specific: 2-step process — basic permissions first, then background
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
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q && !hasBackground) {
            pendingAlwaysPermissionResult = result

            ActivityCompat.requestPermissions(
                currentActivity,
                arrayOf(Manifest.permission.ACCESS_BACKGROUND_LOCATION),
                BACKGROUND_PERMISSION_REQUEST_CODE
            )
            return
        }

        // All permissions granted
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
     * Matches RN: startTracking(backgroundMode, intervalMs, distanceFilter,
     *                           notificationTitle?, notificationMessage?, promise)
     * Matches iOS: startTracking(_ call, result)
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

            // Set notification parameters if provided (RN pattern)
            if (!notificationTitle.isNullOrEmpty()) {
                vietmapSDK.setNotificationTitle(notificationTitle)
            }
            if (!notificationMessage.isNullOrEmpty()) {
                vietmapSDK.setNotificationText(notificationMessage)
            }

            // Configure tracking settings (RN pattern)
            val trackingConfig = TrackingConfig().apply {
                updateInterval = intervalMs
                minDistanceFilter = distanceFilter
                enableBackgroundMode = backgroundMode
            }
            vietmapSDK.setTrackingConfig(trackingConfig)

            // Start tracking
            vietmapSDK.startTracking()
            result.success(true)

        } catch (e: Exception) {
            result.success(false)
        }
    }

    /**
     * stopTracking() → bool
     *
     * Matches RN: stopTracking(promise)
     * Matches iOS: stopTracking(result)
     */
    private fun handleStopTracking(result: Result) {
        if (!isInitialized) {
            result.error("SDK_NOT_INITIALIZED", "VietmapTrackingSDK not initialized", null)
            return
        }

        try {
            vietmapSDK.stopTracking()
            result.success(true)
        } catch (e: Exception) {
            result.success(false)
        }
    }

    /**
     * getCurrentLocation() → LocationData map
     *
     * Matches iOS: trackingManager.getCurrentLocation() -> NSDictionary?
     *
     * NOTE from Guide.md: "Android hiện trả dummy data!"
     * The RN bridge returns hardcoded 0.0 values because VietmapTrackingSDK
     * Android may not have getCurrentLocation(). We follow the same pattern.
     */
    private fun handleGetCurrentLocation(result: Result) {
        if (!isInitialized) {
            result.error("SDK_NOT_INITIALIZED", "VietmapTrackingSDK not initialized", null)
            return
        }

        try {
            val locationMap = mapOf(
                "latitude" to 0.0,
                "longitude" to 0.0,
                "accuracy" to 0.0,
                "altitude" to 0.0,
                "bearing" to 0.0,
                "speed" to 0.0,
                "timestamp" to System.currentTimeMillis()
            )
            result.success(locationMap)
        } catch (e: Exception) {
            result.error("LOCATION_UNAVAILABLE", "Unable to get current location: ${e.message}", null)
        }
    }

    /**
     * isTrackingActive() → bool
     *
     * Matches RN: isTrackingActive(promise)
     * Matches iOS: trackingManager.isTrackingActive()
     */
    private fun handleIsTrackingActive(result: Result) {
        if (!isInitialized) {
            result.success(false)
            return
        }

        try {
            val isActive = vietmapSDK.isTracking()
            result.success(isActive)
        } catch (e: Exception) {
            result.success(false)
        }
    }

    /**
     * getTrackingStatus() → TrackingStatus map
     *
     * Matches RN: getTrackingStatus(promise)
     * Matches iOS: trackingManager.getTrackingStatus() -> NSDictionary
     *
     * NOTE from Guide.md: "Android bridge tự tạo dict từ vietmapSDK.isTracking()"
     */
    private fun handleGetTrackingStatus(result: Result) {
        if (!isInitialized) {
            result.error("SDK_NOT_INITIALIZED", "VietmapTrackingSDK not initialized", null)
            return
        }

        try {
            val isActive = vietmapSDK.isTracking()

            val status = mapOf(
                "isTracking" to isActive,
                "status" to if (isActive) "active" else "inactive",
                "timestamp" to System.currentTimeMillis().toDouble()
            )

            result.success(status)
        } catch (e: Exception) {
            result.error("STATUS_ERROR", "Failed to get tracking status: ${e.message}", null)
        }
    }

    /**
     * updateTrackingConfig(config) → bool
     *
     * Matches RN: updateTrackingConfig(config, promise)
     *
     * NOTE from Guide.md: "Android thực sự gọi SDK update"
     * (unlike iOS which only saves locally)
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
     * Matches RN: vietmapSDK.startAlert() → Boolean (synchronous)
     * Matches iOS: trackingManager.turnOnAlert { success in ... } (async)
     */
    private fun handleTurnOnAlert(result: Result) {
        if (!isInitialized) {
            result.error("SDK_NOT_INITIALIZED", "VietmapTrackingSDK not initialized", null)
            return
        }

        try {
            val success = vietmapSDK.startAlert()
            result.success(success)
        } catch (e: Exception) {
            result.success(false)
        }
    }

    /**
     * turnOffAlert() → bool
     *
     * Matches RN: vietmapSDK.stopAlert() → Boolean (synchronous)
     * Matches iOS: trackingManager.turnOffAlert { success in ... } (async)
     */
    private fun handleTurnOffAlert(result: Result) {
        if (!isInitialized) {
            result.error("SDK_NOT_INITIALIZED", "VietmapTrackingSDK not initialized", null)
            return
        }

        try {
            val success = vietmapSDK.stopAlert()
            result.success(success)
        } catch (e: Exception) {
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
 * Matches the iOS LocationStreamHandler / TrackingStatusStreamHandler pattern.
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
