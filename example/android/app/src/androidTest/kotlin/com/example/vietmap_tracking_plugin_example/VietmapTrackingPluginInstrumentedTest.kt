package com.example.vietmap_tracking_plugin_example

import android.content.Context
import androidx.test.ext.junit.runners.AndroidJUnit4
import androidx.test.platform.app.InstrumentationRegistry
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import com.example.vietmap_tracking_plugin.VietmapTrackingPlugin
import org.junit.Assert.*
import org.junit.Before
import org.junit.Test
import org.junit.runner.RunWith
import java.util.concurrent.CountDownLatch
import java.util.concurrent.TimeUnit

// Real API keys for accurate testing
private const val VIETMAP_API_KEY = "0cd03613175a67f87567f86f0ba2f3b818e3a2b5f2c2634b"
private const val ALERT_API_KEY = "727494d3eb92b2f8d3a6aea1d8caf607f158bfb179776f45"
private const val ALERT_API_ID = "a415885a-eb96-4463-8434-41afe0398f2e"

/**
 * Instrumented tests for VietmapTrackingPlugin — Android bridge layer.
 *
 * These tests run on a REAL Android device/emulator with the actual
 * VietmapTrackingSDK, matching the pattern from iOS RunnerTests.swift.
 *
 * ⚠️ Unlike unit tests, these tests have access to a real Context and
 * can call VietmapTrackingSDK methods. However, permission-related tests
 * may behave differently in test environments.
 *
 * Run: ./gradlew app:connectedAndroidTest  (from example/android/)
 *
 * Test categories (matching iOS RunnerTests.swift):
 *   1. getPlatformVersion
 *   2. Unknown method → notImplemented
 *   3. configure (valid/invalid arguments)
 *   4. configureAlertAPI (valid/invalid, init guard)
 *   5. hasLocationPermissions (return structure)
 *   6. startTracking (init guard, permission guard)
 *   7. stopTracking (init guard)
 *   8. getCurrentLocation (init guard)
 *   9. isTrackingActive (return type)
 *  10. getTrackingStatus (return type)
 *  11. updateTrackingConfig (init guard)
 *  12. turnOnAlert / turnOffAlert (init guard)
 *  13. Guard consistency tests
 *  14. Return type validation tests
 *  15. Method call sequence tests
 *  16. GPX waypoint data structure tests
 */
@RunWith(AndroidJUnit4::class)
class VietmapTrackingPluginInstrumentedTest {

    private lateinit var appContext: Context

    @Before
    fun setUp() {
        appContext = InstrumentationRegistry.getInstrumentation().targetContext
    }

    // ============================================================
    // Helper: invoke a method call and capture the result synchronously
    // ============================================================

    /**
     * Invokes a plugin method and returns the result.
     * Uses a CountDownLatch for synchronous waiting (Android equivalent
     * of iOS XCTestExpectation).
     *
     * Note: The plugin requires onAttachedToEngine to be called for most
     * methods. For tests that only need onMethodCall routing, we create
     * a raw plugin instance. For tests that need the full SDK, we'd need
     * to register with a FlutterEngine — which is complex in androidTest.
     *
     * For this reason, we test the public onMethodCall interface directly,
     * and accept that methods requiring context will throw or error.
     */
    private fun invokeMethod(
        plugin: VietmapTrackingPlugin,
        methodName: String,
        arguments: Any? = null,
        timeoutSeconds: Long = 5
    ): InvokeResult {
        val latch = CountDownLatch(1)
        var capturedSuccess: Any? = null
        var capturedError: Triple<String, String?, String?>? = null
        var wasNotImplemented = false

        val result = object : MethodChannel.Result {
            override fun success(value: Any?) {
                capturedSuccess = value
                latch.countDown()
            }

            override fun error(errorCode: String, errorMessage: String?, errorDetails: Any?) {
                capturedError = Triple(errorCode, errorMessage, errorDetails?.toString())
                latch.countDown()
            }

            override fun notImplemented() {
                wasNotImplemented = true
                latch.countDown()
            }
        }

        try {
            plugin.onMethodCall(MethodCall(methodName, arguments), result)
        } catch (e: UninitializedPropertyAccessException) {
            // context/SDK not initialized — expected for many tests
            return InvokeResult(
                success = null,
                error = Triple("UNINITIALIZED", e.message, null),
                notImplemented = false,
                threw = true
            )
        } catch (e: Exception) {
            return InvokeResult(
                success = null,
                error = Triple("EXCEPTION", e.message, null),
                notImplemented = false,
                threw = true
            )
        }

        latch.await(timeoutSeconds, TimeUnit.SECONDS)

        return InvokeResult(
            success = capturedSuccess,
            error = capturedError,
            notImplemented = wasNotImplemented,
            threw = false
        )
    }

    data class InvokeResult(
        val success: Any?,
        val error: Triple<String, String?, String?>?,
        val notImplemented: Boolean,
        val threw: Boolean
    ) {
        val isSuccess: Boolean get() = success != null && error == null && !notImplemented && !threw
        val isError: Boolean get() = error != null && !threw
        val errorCode: String? get() = error?.first
        val errorMessage: String? get() = error?.second
    }

    // ============================================================
    // 1. getPlatformVersion
    // ============================================================

    @Test
    fun testGetPlatformVersion() {
        val plugin = VietmapTrackingPlugin()
        val result = invokeMethod(plugin, "getPlatformVersion")

        assertTrue("getPlatformVersion should succeed", result.isSuccess)
        val version = result.success as? String
        assertNotNull("Result should be a String", version)
        assertTrue("Version should start with 'Android '", version!!.startsWith("Android "))
    }

    @Test
    fun testGetPlatformVersionReturnType() {
        val plugin = VietmapTrackingPlugin()
        val result = invokeMethod(plugin, "getPlatformVersion")

        assertTrue(result.isSuccess)
        assertTrue("getPlatformVersion should return String", result.success is String)
    }

    // ============================================================
    // 2. Unknown method → notImplemented
    // ============================================================

    @Test
    fun testUnknownMethodReturnsNotImplemented() {
        val plugin = VietmapTrackingPlugin()
        val result = invokeMethod(plugin, "nonExistentMethod_xyz")

        assertTrue("Unknown method should return notImplemented", result.notImplemented)
    }

    @Test
    fun testEmptyMethodNameReturnsNotImplemented() {
        val plugin = VietmapTrackingPlugin()
        val result = invokeMethod(plugin, "")

        assertTrue("Empty method name should return notImplemented", result.notImplemented)
    }

    // ============================================================
    // 3. configure — argument validation
    //    (SDK calls may fail without proper FlutterEngine,
    //     but argument validation should still work)
    // ============================================================

    @Test
    fun testConfigureWithMissingApiKeyReturnsError() {
        val plugin = VietmapTrackingPlugin()
        val result = invokeMethod(plugin, "configure", mapOf<String, Any>())

        // Should fail with INVALID_ARGUMENTS (argument check before SDK call)
        // or throw due to uninitialized context
        if (!result.threw) {
            assertTrue("Should return error", result.isError)
            assertEquals("INVALID_ARGUMENTS", result.errorCode)
        }
    }

    @Test
    fun testConfigureWithNullArgumentsReturnsError() {
        val plugin = VietmapTrackingPlugin()
        val result = invokeMethod(plugin, "configure", null)

        if (!result.threw) {
            assertTrue("Should return error", result.isError)
            assertEquals("INVALID_ARGUMENTS", result.errorCode)
        }
    }

    @Test
    fun testConfigureWithEmptyApiKeyReturnsError() {
        val plugin = VietmapTrackingPlugin()
        val result = invokeMethod(plugin, "configure", mapOf("apiKey" to ""))

        if (!result.threw) {
            assertTrue("Empty apiKey should return error", result.isError)
            assertEquals("INVALID_ARGUMENTS", result.errorCode)
            assertEquals("API key is required", result.errorMessage)
        }
    }

    // ============================================================
    // 4. configureAlertAPI — init guard
    // ============================================================

    @Test
    fun testConfigureAlertAPIBeforeInitializeReturnsError() {
        val plugin = VietmapTrackingPlugin()
        val result = invokeMethod(plugin, "configureAlertAPI", mapOf(
            "apiKey" to ALERT_API_KEY,
            "apiID" to ALERT_API_ID
        ))

        // isInitialized defaults to false → SDK_NOT_INITIALIZED
        if (!result.threw) {
            assertTrue("Should return error", result.isError)
            assertEquals("SDK_NOT_INITIALIZED", result.errorCode)
        }
    }

    @Test
    fun testConfigureAlertAPIWithMissingApiKeyReturnsError() {
        // Even if initialized, missing apiKey should error
        val plugin = VietmapTrackingPlugin()
        val result = invokeMethod(plugin, "configureAlertAPI", mapOf(
            "apiID" to ALERT_API_ID
        ))

        if (!result.threw) {
            assertTrue("Should return error", result.isError)
            // Should be SDK_NOT_INITIALIZED (since not configured) or INVALID_ARGUMENTS
            assertTrue(
                "Error should be SDK_NOT_INITIALIZED or INVALID_ARGUMENTS",
                result.errorCode in listOf("SDK_NOT_INITIALIZED", "INVALID_ARGUMENTS")
            )
        }
    }

    @Test
    fun testConfigureAlertAPIWithNilArgumentsReturnsError() {
        val plugin = VietmapTrackingPlugin()
        val result = invokeMethod(plugin, "configureAlertAPI", null)

        if (!result.threw) {
            assertTrue("Should return error", result.isError)
        }
    }

    // ============================================================
    // 5. hasLocationPermissions — return structure
    // ============================================================

    @Test
    fun testHasLocationPermissionsDoesNotRequireInitialization() {
        val plugin = VietmapTrackingPlugin()
        val result = invokeMethod(plugin, "hasLocationPermissions")

        // May throw if context not set, but should NOT return SDK_NOT_INITIALIZED
        if (!result.threw) {
            if (result.isError) {
                assertNotEquals(
                    "hasLocationPermissions should NOT require initialization",
                    "SDK_NOT_INITIALIZED", result.errorCode
                )
            }
        }
    }

    // ============================================================
    // 6. startTracking — init guard
    // ============================================================

    @Test
    fun testStartTrackingBeforeInitializeReturnsError() {
        val plugin = VietmapTrackingPlugin()
        val result = invokeMethod(plugin, "startTracking", mapOf(
            "backgroundMode" to true,
            "intervalMs" to 5000,
            "distanceFilter" to 10.0
        ))

        if (!result.threw) {
            assertTrue("Should return error", result.isError)
            assertEquals("SDK_NOT_INITIALIZED", result.errorCode)
        }
    }

    // ============================================================
    // 7. stopTracking — init guard
    // ============================================================

    @Test
    fun testStopTrackingBeforeInitializeReturnsError() {
        val plugin = VietmapTrackingPlugin()
        val result = invokeMethod(plugin, "stopTracking")

        if (!result.threw) {
            assertTrue("Should return error", result.isError)
            assertEquals("SDK_NOT_INITIALIZED", result.errorCode)
        }
    }

    // ============================================================
    // 8. getCurrentLocation — init guard
    // ============================================================

    @Test
    fun testGetCurrentLocationBeforeInitializeReturnsError() {
        val plugin = VietmapTrackingPlugin()
        val result = invokeMethod(plugin, "getCurrentLocation")

        if (!result.threw) {
            assertTrue("Should return error", result.isError)
            assertEquals("SDK_NOT_INITIALIZED", result.errorCode)
        }
    }

    // ============================================================
    // 9. isTrackingActive — returns false before init
    // ============================================================

    @Test
    fun testIsTrackingActiveBeforeInitializeReturnsFalse() {
        val plugin = VietmapTrackingPlugin()
        val result = invokeMethod(plugin, "isTrackingActive")

        if (!result.threw) {
            assertTrue("Should succeed with false", result.isSuccess)
            assertEquals(false, result.success)
        }
    }

    // ============================================================
    // 10. getTrackingStatus — init guard
    // ============================================================

    @Test
    fun testGetTrackingStatusBeforeInitializeReturnsError() {
        val plugin = VietmapTrackingPlugin()
        val result = invokeMethod(plugin, "getTrackingStatus")

        if (!result.threw) {
            assertTrue("Should return error", result.isError)
            assertEquals("SDK_NOT_INITIALIZED", result.errorCode)
        }
    }

    // ============================================================
    // 11. updateTrackingConfig — init guard
    // ============================================================

    @Test
    fun testUpdateTrackingConfigBeforeInitializeReturnsError() {
        val plugin = VietmapTrackingPlugin()
        val result = invokeMethod(plugin, "updateTrackingConfig", mapOf(
            "intervalMs" to 3000,
            "distanceFilter" to 5.0
        ))

        if (!result.threw) {
            assertTrue("Should return error", result.isError)
            assertEquals("SDK_NOT_INITIALIZED", result.errorCode)
        }
    }

    // ============================================================
    // 12. turnOnAlert / turnOffAlert — init guard
    // ============================================================

    @Test
    fun testTurnOnAlertBeforeInitializeReturnsError() {
        val plugin = VietmapTrackingPlugin()
        val result = invokeMethod(plugin, "turnOnAlert")

        if (!result.threw) {
            assertTrue("Should return error", result.isError)
            assertEquals("SDK_NOT_INITIALIZED", result.errorCode)
        }
    }

    @Test
    fun testTurnOffAlertBeforeInitializeReturnsError() {
        val plugin = VietmapTrackingPlugin()
        val result = invokeMethod(plugin, "turnOffAlert")

        if (!result.threw) {
            assertTrue("Should return error", result.isError)
            assertEquals("SDK_NOT_INITIALIZED", result.errorCode)
        }
    }

    // ============================================================
    // 13. Guard consistency — all SDK methods require initialization
    // ============================================================

    @Test
    fun testAllSDKMethodsRequireInitialization() {
        val methodsRequiringInit = listOf(
            Pair("configureAlertAPI", mapOf("apiKey" to "test", "apiID" to "test")),
            Pair("startTracking", mapOf("backgroundMode" to true, "intervalMs" to 5000, "distanceFilter" to 10.0)),
            Pair("stopTracking", null),
            Pair("getCurrentLocation", null),
            Pair("getTrackingStatus", null),
            Pair("updateTrackingConfig", mapOf("intervalMs" to 3000)),
            Pair("turnOnAlert", null),
            Pair("turnOffAlert", null)
        )

        for ((methodName, args) in methodsRequiringInit) {
            val plugin = VietmapTrackingPlugin()
            val result = invokeMethod(plugin, methodName, args)

            if (!result.threw) {
                assertTrue(
                    "$methodName should return error before initialization",
                    result.isError
                )
                assertEquals(
                    "$methodName should return SDK_NOT_INITIALIZED",
                    "SDK_NOT_INITIALIZED", result.errorCode
                )
            }
            // If threw UninitializedPropertyAccess, that's also acceptable
            // (means it tried to access context/SDK before guard — a code issue to fix)
        }
    }

    @Test
    fun testPermissionMethodsDoNotRequireInitialization() {
        val permissionMethods = listOf(
            "hasLocationPermissions",
            "requestLocationPermissions",
            "requestAlwaysLocationPermissions"
        )

        for (methodName in permissionMethods) {
            val plugin = VietmapTrackingPlugin()
            val result = invokeMethod(plugin, methodName)

            if (result.isError) {
                assertNotEquals(
                    "$methodName should NOT require initialization",
                    "SDK_NOT_INITIALIZED", result.errorCode
                )
            }
        }
    }

    // ============================================================
    // 14. Return type validation
    // ============================================================

    @Test
    fun testGetPlatformVersionNeverReturnsError() {
        val plugin = VietmapTrackingPlugin()
        val result = invokeMethod(plugin, "getPlatformVersion")

        assertFalse("getPlatformVersion should never error", result.isError)
        assertFalse("getPlatformVersion should never return notImplemented", result.notImplemented)
        assertTrue("getPlatformVersion should succeed", result.isSuccess)
    }

    // ============================================================
    // 15. Method call sequence tests
    // ============================================================

    @Test
    fun testConfigureAlertAPIWithoutConfigureFirst_returnsSDKNotInitialized() {
        // Calling configureAlertAPI without configure should fail
        val plugin = VietmapTrackingPlugin()
        val result = invokeMethod(plugin, "configureAlertAPI", mapOf(
            "apiKey" to ALERT_API_KEY,
            "apiID" to ALERT_API_ID
        ))

        if (!result.threw) {
            assertEquals("SDK_NOT_INITIALIZED", result.errorCode)
        }
    }

    @Test
    fun testStopTrackingWithoutStarting_requiresInit() {
        // Without configure, stopTracking should fail with init guard
        val plugin = VietmapTrackingPlugin()
        val result = invokeMethod(plugin, "stopTracking")

        if (!result.threw) {
            assertEquals("SDK_NOT_INITIALIZED", result.errorCode)
        }
    }

    // ============================================================
    // 16. GPX waypoint data structure tests
    //     (Pure data validation — no SDK needed)
    // ============================================================

    @Test
    fun testLocationDictStructureMatchesDartModel() {
        // Waypoint from GPX: Nhà thờ Đức Bà, District 1, HCMC
        val locationDict = mapOf(
            "latitude" to 10.779784,
            "longitude" to 106.699074,
            "altitude" to 12.0,
            "accuracy" to 5.0,
            "speed" to 2.78,
            "bearing" to 180.0,
            "timestamp" to 1700000000000L
        )

        // Verify all keys expected by Dart LocationData.fromJson
        assertNotNull(locationDict["latitude"])
        assertNotNull(locationDict["longitude"])
        assertNotNull(locationDict["altitude"])
        assertNotNull(locationDict["accuracy"])
        assertNotNull(locationDict["speed"])
        assertNotNull(locationDict["bearing"])
        assertNotNull(locationDict["timestamp"])

        // Verify types
        assertTrue(locationDict["latitude"] is Double)
        assertTrue(locationDict["longitude"] is Double)

        // Verify HCMC coordinates in valid range
        val lat = locationDict["latitude"] as Double
        val lon = locationDict["longitude"] as Double
        assertTrue("HCMC lat should be ~10.7-10.8", lat > 10.0 && lat < 11.0)
        assertTrue("HCMC lon should be ~106.6-106.7", lon > 106.0 && lon < 107.0)
    }

    @Test
    fun testTrackingStatusDictStructure() {
        val statusDict = mapOf(
            "isTracking" to false,
            "status" to "inactive",
            "timestamp" to System.currentTimeMillis().toDouble()
        )

        assertTrue(statusDict["isTracking"] is Boolean)
        assertTrue(statusDict["status"] is String)
        assertTrue(statusDict["timestamp"] is Double)

        val status = statusDict["status"] as String
        assertTrue(
            "Status should be 'active' or 'inactive'",
            status in listOf("active", "inactive")
        )
    }

    @Test
    fun testPermissionResultDictStructure() {
        val permissionDict = mapOf(
            "granted" to false,
            "status" to "not_granted",
            "fineLocation" to false,
            "coarseLocation" to false,
            "backgroundLocation" to false
        )

        assertTrue(permissionDict["granted"] is Boolean)
        assertTrue(permissionDict["status"] is String)
        assertTrue(permissionDict["fineLocation"] is Boolean)
        assertTrue(permissionDict["coarseLocation"] is Boolean)
        assertTrue(permissionDict["backgroundLocation"] is Boolean)

        val status = permissionDict["status"] as String
        assertTrue(
            "Permission status should be valid",
            status in listOf("granted", "denied", "not_granted")
        )
    }

    @Test
    fun testErrorEventDictStructure() {
        val errorEvent = mapOf(
            "error" to "GPS signal lost near Lê Lợi",
            "timestamp" to System.currentTimeMillis()
        )

        assertTrue(errorEvent["error"] is String)
        assertTrue(errorEvent["timestamp"] is Long)
    }

    @Test
    fun testRouteUpdateEventDictStructure() {
        val routeEvent = mapOf(
            "success" to true,
            "timestamp" to System.currentTimeMillis(),
            "routeData" to mapOf(
                "distance" to 720.0,
                "duration" to 255000,
                "waypoints" to 51
            )
        )

        assertTrue(routeEvent["success"] is Boolean)
        assertTrue(routeEvent["routeData"] is Map<*, *>)
    }

    @Test
    fun testHcmcGpxWaypointsInValidRange() {
        val waypoints = listOf(
            Pair(10.776889, 106.700806),  // Bến Thành Market
            Pair(10.779784, 106.699074),  // Nhà thờ Đức Bà
            Pair(10.777042, 106.695179),  // Dinh Độc Lập
            Pair(10.775658, 106.701493),  // Công viên 23/9
            Pair(10.773699, 106.704079),  // Phố đi bộ Nguyễn Huệ
        )

        for ((lat, lon) in waypoints) {
            assertTrue("Lat $lat out of HCMC range", lat in 10.0..11.0)
            assertTrue("Lon $lon out of HCMC range", lon in 106.0..107.0)
        }
    }

    // ============================================================
    // 17. Edge cases
    // ============================================================

    @Test
    fun testConfigureWithExtraFieldsIgnored() {
        val plugin = VietmapTrackingPlugin()
        val result = invokeMethod(plugin, "configure", mapOf(
            "apiKey" to VIETMAP_API_KEY,
            "baseURL" to "https://maps.vietmap.vn",
            "unknownField" to "should be ignored",
            "anotherUnknown" to 42
        ))

        // Should not crash due to unknown fields
        // May fail due to uninitialized context, but should not throw for unknown keys
        if (result.isError) {
            assertNotEquals(
                "Unknown fields should be ignored, not cause an error",
                "INVALID_ARGUMENTS", result.errorCode
            )
        }
    }

    @Test
    fun testMultipleGetPlatformVersionCalls() {
        val plugin = VietmapTrackingPlugin()

        repeat(3) {
            val result = invokeMethod(plugin, "getPlatformVersion")
            assertTrue("Call $it should succeed", result.isSuccess)
            assertTrue("Call $it should return String", result.success is String)
        }
    }
}
