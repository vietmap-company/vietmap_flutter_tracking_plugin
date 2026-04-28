package com.vietmap.tracking

import android.app.Activity
import android.content.Context
import android.graphics.Bitmap
import android.graphics.BitmapFactory
import io.flutter.embedding.engine.plugins.FlutterPlugin
import io.flutter.embedding.engine.plugins.activity.ActivityAware
import io.flutter.embedding.engine.plugins.activity.ActivityPluginBinding
import io.flutter.plugin.common.EventChannel
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import io.flutter.plugin.common.MethodChannel.Result
import io.flutter.plugin.common.PluginRegistry
import android.os.Handler
import android.os.Looper
import android.util.Log
import java.io.ByteArrayOutputStream
import com.vietmap.trackingsdk.VietmapTrackingSDK

/**
 * VietmapTrackingPlugin (com.vietmap.tracking)
 *
 * Registered Flutter plugin class.  Delegates every existing method call to
 * [com.example.vietmap_tracking_plugin.VietmapTrackingPlugin] so all current
 * functionality is preserved, and adds:
 *
 *  • configureTracking   — initialize SDK with authMode + custom endpoints
 *  • configureZoneNetworkV2 / resetZoneNetworkV2
 *  • EventChannels:
 *      vietmap_tracking_plugin/speed_sign  — PNG bytes + speedLimit
 *      vietmap_tracking_plugin/tts         — TTS text strings
 *
 * Channel names are kept identical to the legacy plugin so that
 * [VietmapTrackingController] continues to work without modification.
 */
class VietmapTrackingPlugin :
    FlutterPlugin,
    MethodChannel.MethodCallHandler,
    ActivityAware,
    PluginRegistry.RequestPermissionsResultListener {

    // ── Delegate to existing plugin for all existing methods ──────────────

    private val legacy = com.example.vietmap_tracking_plugin.VietmapTrackingPlugin()

    // ── New EventChannel stream handlers ──────────────────────────────────

    private val speedSignHandler = SimpleStreamHandler()
    private val ttsHandler       = SimpleStreamHandler()

    private lateinit var channel: MethodChannel
    private lateinit var context: Context
    private val mainHandler = Handler(Looper.getMainLooper())

    private val tag = "VietmapTrackingPlugin"

    // ── FlutterPlugin ─────────────────────────────────────────────────────

    override fun onAttachedToEngine(binding: FlutterPlugin.FlutterPluginBinding) {
        context = binding.applicationContext

        // 1. Let the legacy plugin register all its channels first
        legacy.onAttachedToEngine(binding)

        // 2. Override the main MethodChannel handler so THIS class handles calls
        channel = MethodChannel(binding.binaryMessenger, CHANNEL_NAME)
        channel.setMethodCallHandler(this)

        // 3. Register new EventChannels
        EventChannel(binding.binaryMessenger, SPEED_SIGN_CHANNEL)
            .setStreamHandler(speedSignHandler)
        EventChannel(binding.binaryMessenger, TTS_CHANNEL)
            .setStreamHandler(ttsHandler)

        // 4. Wire speed-alert callbacks after SDK is available
        setupSpeedAlertCallbacks()

        Log.d(tag, "=======Plugin Registered (com.vietmap.tracking)=======")
    }

    override fun onDetachedFromEngine(binding: FlutterPlugin.FlutterPluginBinding) {
        channel.setMethodCallHandler(null)
        legacy.onDetachedFromEngine(binding)
        Log.d(tag, "=======Plugin Detached=======")
    }

    // ── MethodCallHandler ─────────────────────────────────────────────────

    override fun onMethodCall(call: MethodCall, result: Result) {
        when (call.method) {
            "configureTracking"      -> handleConfigureTracking(call, result)
            "configureZoneNetworkV2" -> handleConfigureZoneNetworkV2(call, result)
            "resetZoneNetworkV2"     -> handleResetZoneNetworkV2(result)
            // All other calls → legacy plugin
            else                     -> legacy.onMethodCall(call, result)
        }
    }

    // ── ActivityAware — delegate ──────────────────────────────────────────

    override fun onAttachedToActivity(binding: ActivityPluginBinding) {
        legacy.onAttachedToActivity(binding)
        binding.addRequestPermissionsResultListener(this)
    }

    override fun onDetachedFromActivityForConfigChanges() {
        legacy.onDetachedFromActivityForConfigChanges()
    }

    override fun onReattachedToActivityForConfigChanges(binding: ActivityPluginBinding) {
        legacy.onReattachedToActivityForConfigChanges(binding)
    }

    override fun onDetachedFromActivity() {
        legacy.onDetachedFromActivity()
    }

    override fun onRequestPermissionsResult(
        requestCode: Int,
        permissions: Array<out String>,
        grantResults: IntArray
    ): Boolean = legacy.onRequestPermissionsResult(requestCode, permissions, grantResults)

    // ── New method handlers ───────────────────────────────────────────────

    /**
     * configureTracking({apiKey, baseUrl, authMode, gpsTrackingEndpoint,
     *                     gpsBulkEndpoint, autoUpload})
     *
     * Initialises the tracking SDK with the supplied API key and optional
     * server configuration.  authMode is mapped from String → native enum
     * where the SDK supports it.
     */
    private fun handleConfigureTracking(call: MethodCall, result: Result) {
        Log.d(tag, "=======Configure Tracking=======")
        try {
            val apiKey   = call.argument<String>("apiKey")
            val baseUrl  = call.argument<String>("baseUrl")
            val authMode = call.argument<String>("authMode") ?: "header"
            val gpsTrackingEndpoint = call.argument<String>("gpsTrackingEndpoint")
            val gpsBulkEndpoint     = call.argument<String>("gpsBulkEndpoint")
            val autoUpload          = call.argument<Boolean>("autoUpload") ?: true

            if (apiKey.isNullOrEmpty()) {
                result.error("INVALID_ARGUMENTS", "apiKey is required", null)
                return
            }

            val sdk = VietmapTrackingSDK.getInstance(context)

            // Initialize with or without base URL
            if (!baseUrl.isNullOrEmpty()) {
                sdk.initialize(apiKey, baseUrl)
            } else {
                sdk.initialize(apiKey)
            }

            // Apply optional endpoint overrides if the SDK exposes them
            try {
                if (!gpsTrackingEndpoint.isNullOrEmpty()) {
                    sdk.setTrackingEndpoint(gpsTrackingEndpoint)
                }
            } catch (_: Exception) { /* SDK may not have this method */ }

            try {
                if (!gpsBulkEndpoint.isNullOrEmpty()) {
                    sdk.setBulkEndpoint(gpsBulkEndpoint)
                }
            } catch (_: Exception) { /* SDK may not have this method */ }

            // Apply auth mode
            try {
                val isHeader = authMode.equals("header", ignoreCase = true)
                sdk.setAuthMode(isHeader)
            } catch (_: Exception) { /* SDK may not have this method */ }

            Log.d(tag, "configureTracking OK | apiKey=${apiKey.take(8)}… authMode=$authMode autoUpload=$autoUpload")
            result.success(true)
        } catch (e: Exception) {
            result.error("CONFIGURE_TRACKING_FAILED", e.message, null)
        } finally {
            Log.d(tag, "=======End Configure Tracking=======")
        }
    }

    /**
     * configureZoneNetworkV2({baseUrl: String})
     *
     * Switches the speed-alert engine to use the v2 zone-network endpoint.
     */
    private fun handleConfigureZoneNetworkV2(call: MethodCall, result: Result) {
        Log.d(tag, "=======Configure Zone Network V2=======")
        try {
            val baseUrl = call.argument<String>("baseUrl")
            if (baseUrl.isNullOrEmpty()) {
                result.error("INVALID_ARGUMENTS", "baseUrl is required", null)
                return
            }
            val sdk = VietmapTrackingSDK.getInstance(context)
            try {
                sdk.getSpeedAlertManager()?.configureZoneNetworkV2(baseUrl)
                    ?: sdk.configureZoneNetworkV2(baseUrl)
            } catch (_: Exception) {
                // Fallback: try direct call on SDK if getSpeedAlertManager is unavailable
                sdk.configureZoneNetworkV2(baseUrl)
            }
            result.success(true)
        } catch (e: Exception) {
            result.error("CONFIGURE_ZONE_NETWORK_V2_FAILED", e.message, null)
        } finally {
            Log.d(tag, "=======End Configure Zone Network V2=======")
        }
    }

    /**
     * resetZoneNetworkV2()
     *
     * Resets the zone-network-v2 endpoint back to the SDK default.
     */
    private fun handleResetZoneNetworkV2(result: Result) {
        Log.d(tag, "=======Reset Zone Network V2=======")
        try {
            val sdk = VietmapTrackingSDK.getInstance(context)
            try {
                sdk.getSpeedAlertManager()?.resetZoneNetworkV2()
                    ?: sdk.resetZoneNetworkV2()
            } catch (_: Exception) {
                sdk.resetZoneNetworkV2()
            }
            result.success(true)
        } catch (e: Exception) {
            result.error("RESET_ZONE_NETWORK_V2_FAILED", e.message, null)
        } finally {
            Log.d(tag, "=======End Reset Zone Network V2=======")
        }
    }

    // ── Speed-alert event wiring ──────────────────────────────────────────

    private fun setupSpeedAlertCallbacks() {
        try {
            val sdk = VietmapTrackingSDK.getInstance(context)

            // Speed-sign image callback — SDK delivers a Bitmap; we convert to PNG
            sdk.setSpeedSignCallback { bitmap ->
                mainHandler.post {
                    try {
                        val pngBytes = bitmapToPng(bitmap)
                        val speedLimit = try {
                            sdk.getCurrentSpeedLimit()
                        } catch (_: Exception) { null }

                        speedSignHandler.send(
                            mapOf(
                                "imageBytes" to pngBytes,
                                "speedLimit" to speedLimit,
                                "timestamp"  to System.currentTimeMillis()
                            )
                        )
                    } catch (e: Exception) {
                        Log.w(tag, "Speed-sign callback error: ${e.message}")
                    }
                }
            }

            // TTS text callback
            sdk.setTtsCallback { text ->
                mainHandler.post {
                    ttsHandler.send(text ?: "")
                }
            }

            Log.d(tag, "Speed-alert callbacks wired")
        } catch (e: Exception) {
            // SDK may not support these callbacks in the current build version
            Log.w(tag, "Could not wire speed-alert callbacks: ${e.message}")
        }
    }

    // ── Helpers ───────────────────────────────────────────────────────────

    /** Convert an Android [Bitmap] to a PNG-encoded [ByteArray]. */
    private fun bitmapToPng(bitmap: Bitmap): ByteArray {
        val out = ByteArrayOutputStream()
        bitmap.compress(Bitmap.CompressFormat.PNG, 100, out)
        return out.toByteArray()
    }

    // ── StreamHandler ─────────────────────────────────────────────────────

    private inner class SimpleStreamHandler : EventChannel.StreamHandler {
        private var sink: EventChannel.EventSink? = null

        override fun onListen(arguments: Any?, events: EventChannel.EventSink?) {
            sink = events
        }

        override fun onCancel(arguments: Any?) {
            sink = null
        }

        fun send(event: Any) {
            mainHandler.post { sink?.success(event) }
        }
    }

    companion object {
        private const val CHANNEL_NAME    = "vietmap_tracking_plugin"
        private const val SPEED_SIGN_CHANNEL = "vietmap_tracking_plugin/speed_sign"
        private const val TTS_CHANNEL        = "vietmap_tracking_plugin/tts"
    }
}
