package com.example.vietmap_tracking_plugin

import android.Manifest
import android.app.Activity
import android.content.Context
import android.content.SharedPreferences
import android.content.pm.PackageManager
import android.os.Build
import androidx.core.app.ActivityCompat
import androidx.core.content.ContextCompat
import io.flutter.embedding.engine.plugins.FlutterPlugin
import io.flutter.embedding.engine.plugins.activity.ActivityAware
import io.flutter.embedding.engine.plugins.activity.ActivityPluginBinding
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import io.flutter.plugin.common.MethodChannel.MethodCallHandler
import io.flutter.plugin.common.MethodChannel.Result
import io.flutter.plugin.common.PluginRegistry
import com.vietmap.trackingsdk.VietmapTrackingSDK
import com.vietmap.trackingsdk.TrackingConfig
import com.vietmap.trackingsdk.VMLocation
import com.google.gson.Gson

/** VietmapTrackingPlugin - Integrated with VietmapTrackingSDK */
class VietmapTrackingPlugin: FlutterPlugin, MethodCallHandler, ActivityAware,
    PluginRegistry.RequestPermissionsResultListener {
  /// The MethodChannel that will the communication between Flutter and native Android
  ///
  /// This local reference serves to register the plugin with the Flutter Engine and unregister it
  /// when the Flutter Engine is detached from the Activity
  private lateinit var channel : MethodChannel
  private lateinit var context: Context
  private lateinit var preferences: SharedPreferences
  
  // VietmapTrackingSDK instance
  private lateinit var vietmapSDK: VietmapTrackingSDK
  private val gson = Gson()
  private var isInitialized: Boolean = false
  private var activity: Activity? = null
  private var pendingPermissionResult: Result? = null
  
  companion object {
    private const val PREFS_NAME = "vietmap_tracking_prefs"
    private const val KEY_API_KEY = "api_key"
    private const val KEY_ENDPOINT = "endpoint"
    private const val KEY_IS_INITIALIZED = "is_initialized"
    private const val PERMISSION_REQUEST_CODE = 1001
    private const val BACKGROUND_PERMISSION_REQUEST_CODE = 1002
  }

  override fun onAttachedToEngine(flutterPluginBinding: FlutterPlugin.FlutterPluginBinding) {
    channel = MethodChannel(flutterPluginBinding.binaryMessenger, "vietmap_tracking_plugin")
    channel.setMethodCallHandler(this)
    context = flutterPluginBinding.applicationContext
    preferences = context.getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE)
    
    // Initialize VietmapTrackingSDK instance
    try {
      vietmapSDK = VietmapTrackingSDK.getInstance(context)
    } catch (e: Exception) {
      isInitialized = false
    }
  }

  override fun onMethodCall(call: MethodCall, result: Result) {
    when (call.method) {
      "getPlatformVersion" -> {
        result.success("Android ${android.os.Build.VERSION.RELEASE}")
      }
      "initialize" -> {
        handleInitialize(call, result)
      }
      "configure" -> {
        handleConfigure(call, result)
      }
      "configureAlertAPI" -> {
        handleConfigureAlertAPI(call, result)
      }
      "setApiKey" -> {
        handleSetApiKey(call, result)
      }
      "setEndpoint" -> {
        handleSetEndpoint(call, result)
      }
      "getConfiguration" -> {
        handleGetConfiguration(result)
      }
      "isInitialized" -> {
        result.success(preferences.getBoolean(KEY_IS_INITIALIZED, false))
      }
      "requestLocationPermissions" -> {
        handleRequestLocationPermissions(result)
      }
      "hasLocationPermissions" -> {
        handleHasLocationPermissions(result)
      }
      "startTracking" -> {
        handleStartTracking(call, result)
      }
      "stopTracking" -> {
        handleStopTracking(result)
      }
      "isTrackingActive" -> {
        handleIsTrackingActive(result)
      }
      else -> {
        result.notImplemented()
      }
    }
  }
  
  private fun handleInitialize(call: MethodCall, result: Result) {
    try {
      val apiKey = call.argument<String>("apiKey")
      val endpoint = call.argument<String>("endpoint")
      val additionalConfig = call.argument<Map<String, Any>>("additionalConfig")
      
      if (apiKey == null || endpoint == null) {
        result.error("INVALID_ARGUMENTS", "apiKey and endpoint are required", null)
        return
      }
      
      preferences.edit()
        .putString(KEY_API_KEY, apiKey)
        .putString(KEY_ENDPOINT, endpoint)
        .putBoolean(KEY_IS_INITIALIZED, true)
        .apply()
      
      result.success(null)
    } catch (e: Exception) {
      result.error("INITIALIZATION_ERROR", e.message, null)
    }
  }
  
  private fun handleSetApiKey(call: MethodCall, result: Result) {
    try {
      val apiKey = call.argument<String>("apiKey")
      if (apiKey == null) {
        result.error("INVALID_ARGUMENTS", "apiKey is required", null)
        return
      }
      
      preferences.edit()
        .putString(KEY_API_KEY, apiKey)
        .apply()
      
      result.success(null)
    } catch (e: Exception) {
      result.error("SET_API_KEY_ERROR", e.message, null)
    }
  }
  
  private fun handleSetEndpoint(call: MethodCall, result: Result) {
    try {
      val endpoint = call.argument<String>("endpoint")
      if (endpoint == null) {
        result.error("INVALID_ARGUMENTS", "endpoint is required", null)
        return
      }
      
      preferences.edit()
        .putString(KEY_ENDPOINT, endpoint)
        .apply()
      
      result.success(null)
    } catch (e: Exception) {
      result.error("SET_ENDPOINT_ERROR", e.message, null)
    }
  }
  
  private fun handleGetConfiguration(result: Result) {
    try {
      val apiKey = preferences.getString(KEY_API_KEY, null)
      val endpoint = preferences.getString(KEY_ENDPOINT, null)
      val isInitialized = preferences.getBoolean(KEY_IS_INITIALIZED, false)
      
      if (!isInitialized || apiKey == null || endpoint == null) {
        result.success(null)
        return
      }
      
      val config = mapOf(
        "apiKey" to apiKey,
        "endpoint" to endpoint,
        "isInitialized" to isInitialized
      )
      
      result.success(config)
    } catch (e: Exception) {
      result.error("GET_CONFIG_ERROR", e.message, null)
    }
  }
  
  private fun handleConfigure(call: MethodCall, result: Result) {
    try {
      val apiKey = call.argument<String>("apiKey")
      val baseURL = call.argument<String>("baseURL")
      
      if (apiKey == null || apiKey.isEmpty()) {
        result.error("INVALID_API_KEY", "API key is required", null)
        return
      }
      
      // Initialize VietmapTrackingSDK with API key (React Native pattern)
      if (baseURL != null && baseURL.isNotEmpty()) {
        vietmapSDK.initialize(apiKey, baseURL)
      } else {
        vietmapSDK.initialize(apiKey)
      }
      
      isInitialized = true
      
      preferences.edit()
        .putString(KEY_API_KEY, apiKey)
        .putString(KEY_ENDPOINT, baseURL ?: "")
        .putBoolean(KEY_IS_INITIALIZED, true)
        .apply()
      
      result.success(true)
      
    } catch (e: Exception) {
      isInitialized = false
      result.error("CONFIGURE_FAILED", "Failed to configure VietmapTrackingSDK: ${e.message}", null)
    }
  }
  
  private fun handleConfigureAlertAPI(call: MethodCall, result: Result) {
    if (!isInitialized) {
      result.error("SDK_NOT_INITIALIZED", "VietmapTrackingSDK not initialized", null)
      return
    }
    
    try {
      val apiKey = call.argument<String>("apiKey")
      val apiID = call.argument<String>("apiID")
      
      if (apiKey == null || apiID == null) {
        result.error("INVALID_PARAMS", "API key and API ID are required", null)
        return
      }
      
      vietmapSDK.configureAlertAPI(apiKey, apiID)
      result.success(true)
      
    } catch (e: Exception) {
      result.error("ALERT_CONFIG_FAILED", "Failed to configure Alert API: ${e.message}", null)
    }
  }
  
  private fun handleRequestLocationPermissions(result: Result) {
    val currentActivity = activity
    if (currentActivity == null) {
      result.error("NO_ACTIVITY", "No activity available", null)
      return
    }
    
    if (hasLocationPermission()) {
      val permissionResult = mapOf(
        "granted" to true,
        "status" to "granted"
      )
      result.success(permissionResult)
      return
    }
    
    pendingPermissionResult = result
    
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
  
  private fun handleHasLocationPermissions(result: Result) {
    val fineLocation = ContextCompat.checkSelfPermission(
      context,
      Manifest.permission.ACCESS_FINE_LOCATION
    ) == PackageManager.PERMISSION_GRANTED
    
    val coarseLocation = ContextCompat.checkSelfPermission(
      context,
      Manifest.permission.ACCESS_COARSE_LOCATION
    ) == PackageManager.PERMISSION_GRANTED
    
    val granted = fineLocation && coarseLocation
    
    val permissionResult = mapOf(
      "granted" to granted,
      "status" to if (granted) "granted" else "not_granted"
    )
    
    result.success(permissionResult)
  }
  
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
      val config = call.arguments as? Map<*, *>
      if (config == null) {
        result.error("INVALID_CONFIG", "Invalid tracking configuration", null)
        return
      }
      
      val intervalMs = (config["intervalMs"] as? Number)?.toLong() ?: 20000L
      val distanceFilter = (config["distanceFilter"] as? Number)?.toDouble() ?: 10.0
      val backgroundMode = config["backgroundMode"] as? Boolean ?: true
      val notificationTitle = config["notificationTitle"] as? String
      val notificationMessage = config["notificationMessage"] as? String
      
      // Set notification if provided (React Native pattern)
      if (!notificationTitle.isNullOrEmpty()) {
        vietmapSDK.setNotificationTitle(notificationTitle)
      }
      if (!notificationMessage.isNullOrEmpty()) {
        vietmapSDK.setNotificationText(notificationMessage)
      }
      
      // Configure tracking settings (React Native pattern)
      val trackingConfig = TrackingConfig().apply {
        updateInterval = intervalMs
        minDistanceFilter = distanceFilter
        enableBackgroundMode = backgroundMode
      }
      vietmapSDK.setTrackingConfig(trackingConfig)
      
      // Start tracking (no parameters, config set separately)
      vietmapSDK.startTracking()
      
      result.success(true)
      
    } catch (e: Exception) {
      result.error("START_TRACKING_FAILED", "Failed to start tracking: ${e.message}", null)
    }
  }
  
  private fun handleStopTracking(result: Result) {
    if (!isInitialized) {
      result.error("SDK_NOT_INITIALIZED", "VietmapTrackingSDK not initialized", null)
      return
    }
    
    try {
      vietmapSDK.stopTracking()
      result.success(true)
    } catch (e: Exception) {
      result.error("STOP_TRACKING_FAILED", "Failed to stop tracking: ${e.message}", null)
    }
  }
  
  private fun handleIsTrackingActive(result: Result) {
    try {
      val isTracking = vietmapSDK.isTracking()
      result.success(isTracking)
    } catch (e: Exception) {
      result.success(false)
    }
  }
  
  private fun hasLocationPermission(): Boolean {
    val fineLocation = ContextCompat.checkSelfPermission(
      context,
      Manifest.permission.ACCESS_FINE_LOCATION
    ) == PackageManager.PERMISSION_GRANTED
    
    val coarseLocation = ContextCompat.checkSelfPermission(
      context,
      Manifest.permission.ACCESS_COARSE_LOCATION
    ) == PackageManager.PERMISSION_GRANTED
    
    return fineLocation && coarseLocation
  }
  
  override fun onRequestPermissionsResult(
    requestCode: Int,
    permissions: Array<out String>,
    grantResults: IntArray
  ): Boolean {
    when (requestCode) {
      PERMISSION_REQUEST_CODE -> {
        handlePermissionResult(permissions, grantResults)
        return true
      }
    }
    return false
  }
  
  private fun handlePermissionResult(permissions: Array<out String>, grantResults: IntArray) {
    val result = pendingPermissionResult ?: return
    pendingPermissionResult = null
    
    var fineLocationGranted = false
    var coarseLocationGranted = false
    
    for (i in permissions.indices) {
      when (permissions[i]) {
        Manifest.permission.ACCESS_FINE_LOCATION -> {
          fineLocationGranted = grantResults[i] == PackageManager.PERMISSION_GRANTED
        }
        Manifest.permission.ACCESS_COARSE_LOCATION -> {
          coarseLocationGranted = grantResults[i] == PackageManager.PERMISSION_GRANTED
        }
      }
    }
    
    val granted = fineLocationGranted && coarseLocationGranted
    
    val permissionResult = mapOf(
      "granted" to granted,
      "status" to if (granted) "granted" else "denied"
    )
    
    result.success(permissionResult)
  }
  
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

  override fun onDetachedFromEngine(binding: FlutterPlugin.FlutterPluginBinding) {
    channel.setMethodCallHandler(null)
  }
}
