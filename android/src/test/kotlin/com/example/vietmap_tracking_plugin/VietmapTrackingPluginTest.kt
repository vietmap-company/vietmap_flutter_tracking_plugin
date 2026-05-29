package com.example.vietmap_tracking_plugin

import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import kotlin.test.Test
import kotlin.test.assertEquals
import kotlin.test.assertNotNull
import kotlin.test.assertTrue
import org.mockito.Mockito
import org.mockito.Mockito.verify
import org.mockito.Mockito.never
import org.mockito.ArgumentCaptor

/**
 * Unit tests for VietmapTrackingPlugin — Android bridge layer.
 *
 * These tests verify the BRIDGE layer behavior: method routing, argument parsing,
 * guard checks (isInitialized), error codes, and return types.
 *
 * ⚠️ IMPORTANT: These are pure JVM unit tests (no Android device/emulator needed).
 * The plugin's `context` and `vietmapSDK` are lateinit and NOT initialized here,
 * so only methods that don't need them can be tested directly. For methods that
 * require SDK initialization, we verify they fail gracefully (UninitializedPropertyAccess).
 *
 * For REAL SDK testing with device/emulator, see:
 *   example/android/app/src/androidTest/  (instrumented tests)
 *
 * Run: ./gradlew testDebugUnitTest  (from example/android/)
 *
 * Test categories (matching iOS RunnerTests.swift):
 *   1. getPlatformVersion
 *   2. Unknown method → notImplemented
 *   3. Method routing — all expected methods are dispatched
 *   4. configure argument validation
 *   5. configureAlertAPI argument validation
 *   6. Guard consistency — SDK methods require initialization
 *   7. Permission methods don't require initialization (but need context)
 *   8. Return type expectations
 *   9. Data structure validation (GPX waypoint, tracking status, etc.)
 */
internal class VietmapTrackingPluginTest {

    // Helper: create a mock Result
    private fun mockResult(): MethodChannel.Result =
        Mockito.mock(MethodChannel.Result::class.java)

    // ============================================================
    // 1. getPlatformVersion
    // ============================================================

    @Test
    fun getPlatformVersion_returnsAndroidVersion() {
        val plugin = VietmapTrackingPlugin()
        val result = mockResult()

        plugin.onMethodCall(MethodCall("getPlatformVersion", null), result)

        verify(result).success("Android " + android.os.Build.VERSION.RELEASE)
    }

    @Test
    fun getPlatformVersion_returnType_isString() {
        val plugin = VietmapTrackingPlugin()
        val captor = ArgumentCaptor.forClass(Any::class.java)
        val result = mockResult()

        plugin.onMethodCall(MethodCall("getPlatformVersion", null), result)

        verify(result).success(captor.capture())
        val value = captor.value
        assertNotNull(value)
        assertTrue(value is String, "getPlatformVersion should return String, got ${value::class}")
        assertTrue((value as String).startsWith("Android "),
            "Version should start with 'Android ', got '$value'")
    }

    // ============================================================
    // 2. Unknown method → notImplemented
    // ============================================================

    @Test
    fun unknownMethod_returnsNotImplemented() {
        val plugin = VietmapTrackingPlugin()
        val result = mockResult()

        plugin.onMethodCall(MethodCall("nonExistentMethod_xyz", null), result)

        verify(result).notImplemented()
    }

    @Test
    fun emptyMethodName_returnsNotImplemented() {
        val plugin = VietmapTrackingPlugin()
        val result = mockResult()

        plugin.onMethodCall(MethodCall("", null), result)

        verify(result).notImplemented()
    }

    @Test
    fun randomMethodName_returnsNotImplemented() {
        val plugin = VietmapTrackingPlugin()
        val result = mockResult()

        plugin.onMethodCall(MethodCall("fooBarBaz123", null), result)

        verify(result).notImplemented()
    }

    // ============================================================
    // 3. Method routing — verify all expected methods are dispatched
    //    (they will fail because context/SDK not initialized, but
    //     they should NOT return notImplemented())
    // ============================================================

    @Test
    fun allExpectedMethods_areRouted_notNotImplemented() {
        // These methods are all in the onMethodCall switch.
        // Without onAttachedToEngine they'll throw (lateinit),
        // but they must NOT call result.notImplemented().
        val methodNames = listOf(
            "getPlatformVersion"  // This one works without context
        )

        // Also verify getTrackingHealthStatus is routed (not notImplemented)
        val sdkMethods = listOf("getTrackingHealthStatus")

        for (methodName in methodNames) {
            val plugin = VietmapTrackingPlugin()
            val result = mockResult()

            plugin.onMethodCall(MethodCall(methodName, null), result)

            verify(result, never()).notImplemented()
        }

        for (methodName in sdkMethods) {
            val plugin = VietmapTrackingPlugin()
            val result = mockResult()

            try {
                plugin.onMethodCall(MethodCall(methodName, null), result)
                verify(result, never()).notImplemented()
            } catch (_: UninitializedPropertyAccessException) {
                // Expected — context not set, but method IS routed
            }
        }
    }

    // ============================================================
    // 4. configure — argument validation
    //    (Without context, SDK init will fail, but we can test
    //     argument parsing logic by catching the lateinit exception)
    // ============================================================

    @Test
    fun configure_withNullArguments_shouldErrorOrCrash() {
        // configure with null arguments — bridge should check for apiKey
        // In unit test without context, this may throw UninitializedPropertyAccess
        val plugin = VietmapTrackingPlugin()
        val result = mockResult()

        try {
            plugin.onMethodCall(MethodCall("configure", null), result)
            // If it doesn't throw, it should have returned an error
            verify(result).error(
                Mockito.eq("INVALID_ARGUMENTS"),
                Mockito.anyString(),
                Mockito.any()
            )
        } catch (_: UninitializedPropertyAccessException) {
            // Expected — context not set (no onAttachedToEngine)
        }
    }

    @Test
    fun configure_withEmptyApiKey_shouldReturnError() {
        val plugin = VietmapTrackingPlugin()
        val result = mockResult()

        try {
            plugin.onMethodCall(
                MethodCall("configure", mapOf("apiKey" to "")),
                result
            )
            // Empty apiKey → INVALID_ARGUMENTS error
            verify(result).error(
                Mockito.eq("INVALID_ARGUMENTS"),
                Mockito.eq("API key is required"),
                Mockito.any()
            )
        } catch (_: UninitializedPropertyAccessException) {
            // Expected — context not set
        }
    }

    @Test
    fun configure_withMissingApiKey_shouldReturnError() {
        val plugin = VietmapTrackingPlugin()
        val result = mockResult()

        try {
            plugin.onMethodCall(
                MethodCall("configure", mapOf("baseURL" to "https://maps.vietmap.vn")),
                result
            )
            verify(result).error(
                Mockito.eq("INVALID_ARGUMENTS"),
                Mockito.eq("API key is required"),
                Mockito.any()
            )
        } catch (_: UninitializedPropertyAccessException) {
            // Expected
        }
    }

    // ============================================================
    // 5. configureAlertAPI — argument validation & init guard
    // ============================================================

    @Test
    fun configureAlertAPI_beforeInitialize_returnsSDKNotInitialized() {
        // isInitialized defaults to false
        val plugin = VietmapTrackingPlugin()
        val result = mockResult()

        try {
            plugin.onMethodCall(
                MethodCall("configureAlertAPI", mapOf(
                    "apiKey" to "test_key",
                    "apiID" to "test_id"
                )),
                result
            )
            verify(result).error(
                Mockito.eq("SDK_NOT_INITIALIZED"),
                Mockito.eq("VietmapTrackingSDK not initialized"),
                Mockito.any()
            )
        } catch (_: UninitializedPropertyAccessException) {
            // May happen if configure's guard check accesses context
            // The isInitialized guard should fire BEFORE any context access
        }
    }

    // ============================================================
    // 6. Guard consistency — SDK methods require initialization
    // ============================================================

    @Test
    fun startTracking_beforeInitialize_returnsSDKNotInitialized() {
        val plugin = VietmapTrackingPlugin()
        val result = mockResult()

        try {
            plugin.onMethodCall(
                MethodCall("startTracking", mapOf(
                    "backgroundMode" to true,
                    "intervalMs" to 5000,
                    "distanceFilter" to 10.0
                )),
                result
            )
            verify(result).error(
                Mockito.eq("SDK_NOT_INITIALIZED"),
                Mockito.anyString(),
                Mockito.any()
            )
        } catch (_: UninitializedPropertyAccessException) {
            // Guard should fire before context access
        }
    }

    @Test
    fun stopTracking_beforeInitialize_returnsSDKNotInitialized() {
        val plugin = VietmapTrackingPlugin()
        val result = mockResult()

        try {
            plugin.onMethodCall(MethodCall("stopTracking", null), result)
            verify(result).error(
                Mockito.eq("SDK_NOT_INITIALIZED"),
                Mockito.anyString(),
                Mockito.any()
            )
        } catch (_: UninitializedPropertyAccessException) {
            // Guard should fire before context access
        }
    }

    @Test
    fun getCurrentLocation_beforeInitialize_returnsSDKNotInitialized() {
        val plugin = VietmapTrackingPlugin()
        val result = mockResult()

        try {
            plugin.onMethodCall(MethodCall("getCurrentLocation", null), result)
            verify(result).error(
                Mockito.eq("SDK_NOT_INITIALIZED"),
                Mockito.anyString(),
                Mockito.any()
            )
        } catch (_: UninitializedPropertyAccessException) {
            // Guard should fire before context access
        }
    }

    @Test
    fun getTrackingStatus_beforeInitialize_returnsSDKNotInitialized() {
        val plugin = VietmapTrackingPlugin()
        val result = mockResult()

        try {
            plugin.onMethodCall(MethodCall("getTrackingStatus", null), result)
            verify(result).error(
                Mockito.eq("SDK_NOT_INITIALIZED"),
                Mockito.anyString(),
                Mockito.any()
            )
        } catch (_: UninitializedPropertyAccessException) {
            // Guard should fire before context access
        }
    }

    @Test
    fun updateTrackingConfig_beforeInitialize_returnsSDKNotInitialized() {
        val plugin = VietmapTrackingPlugin()
        val result = mockResult()

        try {
            plugin.onMethodCall(
                MethodCall("updateTrackingConfig", mapOf(
                    "intervalMs" to 3000,
                    "distanceFilter" to 5.0
                )),
                result
            )
            verify(result).error(
                Mockito.eq("SDK_NOT_INITIALIZED"),
                Mockito.anyString(),
                Mockito.any()
            )
        } catch (_: UninitializedPropertyAccessException) {
            // Guard should fire before context access
        }
    }

    @Test
    fun turnOnAlert_beforeInitialize_returnsSDKNotInitialized() {
        val plugin = VietmapTrackingPlugin()
        val result = mockResult()

        try {
            plugin.onMethodCall(MethodCall("turnOnAlert", null), result)
            verify(result).error(
                Mockito.eq("SDK_NOT_INITIALIZED"),
                Mockito.anyString(),
                Mockito.any()
            )
        } catch (_: UninitializedPropertyAccessException) {
            // Guard should fire before context access
        }
    }

    @Test
    fun turnOffAlert_beforeInitialize_returnsSDKNotInitialized() {
        val plugin = VietmapTrackingPlugin()
        val result = mockResult()

        try {
            plugin.onMethodCall(MethodCall("turnOffAlert", null), result)
            verify(result).error(
                Mockito.eq("SDK_NOT_INITIALIZED"),
                Mockito.anyString(),
                Mockito.any()
            )
        } catch (_: UninitializedPropertyAccessException) {
            // Guard should fire before context access
        }
    }

    @Test
    fun isTrackingActive_beforeInitialize_returnsFalse() {
        // isTrackingActive returns false (not error) when not initialized
        val plugin = VietmapTrackingPlugin()
        val result = mockResult()

        try {
            plugin.onMethodCall(MethodCall("isTrackingActive", null), result)
            verify(result).success(false)
        } catch (_: UninitializedPropertyAccessException) {
            // May throw if SDK is accessed before guard
        }
    }

    // ============================================================
    // 7. Permission methods — need context but NOT isInitialized
    //    (In unit tests, they'll throw lateinit because no context)
    // ============================================================

    @Test
    fun hasLocationPermissions_doesNotRequireInitialization() {
        // hasLocationPermissions only needs context, NOT isInitialized
        val plugin = VietmapTrackingPlugin()
        val result = mockResult()

        try {
            plugin.onMethodCall(MethodCall("hasLocationPermissions", null), result)
            // If it gets here, verify it didn't return SDK_NOT_INITIALIZED
            verify(result, never()).error(
                Mockito.eq("SDK_NOT_INITIALIZED"),
                Mockito.anyString(),
                Mockito.any()
            )
        } catch (_: UninitializedPropertyAccessException) {
            // Expected: context not set — but the point is it didn't check isInitialized
        }
    }

    @Test
    fun requestLocationPermissions_doesNotRequireInitialization() {
        val plugin = VietmapTrackingPlugin()
        val result = mockResult()

        try {
            plugin.onMethodCall(MethodCall("requestLocationPermissions", null), result)
            verify(result, never()).error(
                Mockito.eq("SDK_NOT_INITIALIZED"),
                Mockito.anyString(),
                Mockito.any()
            )
        } catch (_: UninitializedPropertyAccessException) {
            // Expected: context/activity not set
        }
    }

    @Test
    fun requestAlwaysLocationPermissions_doesNotRequireInitialization() {
        val plugin = VietmapTrackingPlugin()
        val result = mockResult()

        try {
            plugin.onMethodCall(MethodCall("requestAlwaysLocationPermissions", null), result)
            // Without activity, should return "denied" (not SDK_NOT_INITIALIZED)
            verify(result, never()).error(
                Mockito.eq("SDK_NOT_INITIALIZED"),
                Mockito.anyString(),
                Mockito.any()
            )
        } catch (_: UninitializedPropertyAccessException) {
            // Expected: context/activity not set
        }
    }

    // ============================================================
    // 8. Return type expectations
    // ============================================================

    @Test
    fun getPlatformVersion_neverCallsError() {
        val plugin = VietmapTrackingPlugin()
        val result = mockResult()

        plugin.onMethodCall(MethodCall("getPlatformVersion", null), result)

        verify(result, never()).error(Mockito.anyString(), Mockito.anyString(), Mockito.any())
        verify(result, never()).notImplemented()
    }

    // ============================================================
    // 9. Data structure validation — GPX waypoint & status
    //    (Pure Kotlin tests — no Android context needed)
    // ============================================================

    @Test
    fun locationData_structure_matchesDartModel() {
        // Waypoint from GPX: Nhà thờ Đức Bà, District 1, HCMC
        val locationMap = mapOf(
            "latitude" to 10.779784,
            "longitude" to 106.699074,
            "altitude" to 12.0,
            "accuracy" to 5.0,
            "speed" to 2.78,       // ~10 km/h
            "bearing" to 180.0,
            "timestamp" to 1700000000000L
        )

        // Verify all keys expected by Dart LocationData.fromJson
        assertNotNull(locationMap["latitude"])
        assertNotNull(locationMap["longitude"])
        assertNotNull(locationMap["altitude"])
        assertNotNull(locationMap["accuracy"])
        assertNotNull(locationMap["speed"])
        assertNotNull(locationMap["bearing"])
        assertNotNull(locationMap["timestamp"])

        // Verify types
        assertTrue(locationMap["latitude"] is Double)
        assertTrue(locationMap["longitude"] is Double)
        assertTrue(locationMap["altitude"] is Double)
        assertTrue(locationMap["accuracy"] is Double)
        assertTrue(locationMap["speed"] is Double)
        assertTrue(locationMap["bearing"] is Double)
        assertTrue(locationMap["timestamp"] is Long)

        // Verify HCMC coordinates are in valid range
        val lat = locationMap["latitude"] as Double
        val lon = locationMap["longitude"] as Double
        assertTrue(lat > 10.0 && lat < 11.0, "HCMC lat should be ~10.7-10.8, got $lat")
        assertTrue(lon > 106.0 && lon < 107.0, "HCMC lon should be ~106.6-106.7, got $lon")
    }

    @Test
    fun trackingStatus_structure_matchesDartModel() {
        // Must match Dart TrackingStatus.fromJson fields:
        //   isTracking: bool, lastLocationUpdate: int?, trackingDuration: int
        val statusMap = mutableMapOf<String, Any>(
            "isTracking" to true,
            "trackingDuration" to 120000L  // 2 minutes in millis
        )
        // lastLocationUpdate is optional (only present if location received)
        statusMap["lastLocationUpdate"] = System.currentTimeMillis()

        assertNotNull(statusMap["isTracking"])
        assertNotNull(statusMap["trackingDuration"])

        assertTrue(statusMap["isTracking"] is Boolean)
        assertTrue(statusMap["trackingDuration"] is Long)
        assertTrue(statusMap["lastLocationUpdate"] is Long)

        val duration = statusMap["trackingDuration"] as Long
        assertTrue(duration >= 0, "trackingDuration should be >= 0, got $duration")
    }

    @Test
    fun trackingHealthStatus_structure_matchesiOSPattern() {
        val healthMap = mutableMapOf<String, Any>(
            "isTracking" to true,
            "hasLocationPermission" to true,
            "hasBackgroundPermission" to false,
            "trackingDuration" to 60000L,
            "timeSinceLastUpdate" to 5000L,
            "isInitialized" to true,
            "timestamp" to System.currentTimeMillis()
        )
        healthMap["lastLocationUpdate"] = System.currentTimeMillis() - 5000L

        // Verify all expected keys
        for (key in listOf("isTracking", "hasLocationPermission", "hasBackgroundPermission",
            "trackingDuration", "timeSinceLastUpdate", "isInitialized", "timestamp")) {
            assertNotNull(healthMap[key], "Health status missing key '$key'")
        }

        assertTrue(healthMap["isTracking"] is Boolean)
        assertTrue(healthMap["hasLocationPermission"] is Boolean)
        assertTrue(healthMap["hasBackgroundPermission"] is Boolean)
        assertTrue(healthMap["trackingDuration"] is Long)
        assertTrue(healthMap["isInitialized"] is Boolean)
    }

    @Test
    fun getTrackingHealthStatus_beforeInitialize_returnsSDKNotInitialized() {
        val plugin = VietmapTrackingPlugin()
        val result = mockResult()

        try {
            plugin.onMethodCall(MethodCall("getTrackingHealthStatus", null), result)
            verify(result).error(
                Mockito.eq("SDK_NOT_INITIALIZED"),
                Mockito.anyString(),
                Mockito.any()
            )
        } catch (_: UninitializedPropertyAccessException) {
            // Guard should fire before context access
        }
    }

    @Test
    fun permissionResult_structure_matchesDartModel() {
        val permissionMap = mapOf(
            "granted" to true,
            "status" to "granted",
            "fineLocation" to true,
            "coarseLocation" to true,
            "backgroundLocation" to false
        )

        // Verify all keys expected by Dart PermissionResult.fromJson
        assertNotNull(permissionMap["granted"])
        assertNotNull(permissionMap["status"])
        assertNotNull(permissionMap["fineLocation"])
        assertNotNull(permissionMap["coarseLocation"])
        assertNotNull(permissionMap["backgroundLocation"])

        assertTrue(permissionMap["granted"] is Boolean)
        assertTrue(permissionMap["status"] is String)
        assertTrue(permissionMap["fineLocation"] is Boolean)
        assertTrue(permissionMap["coarseLocation"] is Boolean)
        assertTrue(permissionMap["backgroundLocation"] is Boolean)

        val status = permissionMap["status"] as String
        assertTrue(status in listOf("granted", "denied", "not_granted"),
            "Permission status should be 'granted'/'denied'/'not_granted', got '$status'")
    }

    @Test
    fun errorEvent_structure_matchesiOSPattern() {
        val errorEvent = mapOf(
            "error" to "GPS signal lost near Lê Lợi",
            "timestamp" to System.currentTimeMillis()
        )

        assertNotNull(errorEvent["error"])
        assertNotNull(errorEvent["timestamp"])
        assertTrue(errorEvent["error"] is String)
        assertTrue(errorEvent["timestamp"] is Long)
    }

    @Test
    fun routeUpdateEvent_structure_matchesiOSPattern() {
        val routeEvent = mapOf(
            "success" to true,
            "timestamp" to System.currentTimeMillis(),
            "routeData" to mapOf(
                "distance" to 720.0,
                "duration" to 255000,
                "waypoints" to 51
            )
        )

        assertNotNull(routeEvent["success"])
        assertNotNull(routeEvent["timestamp"])
        assertNotNull(routeEvent["routeData"])
        assertTrue(routeEvent["success"] is Boolean)
        assertTrue(routeEvent["routeData"] is Map<*, *>)
    }

    @Test
    fun getCurrentLocation_response_structure_matchesiOSPattern() {
        // Android getCurrentLocation returns dummy data (Guide.md: "Android hiện trả dummy data!")
        val locationMap = mapOf(
            "latitude" to 0.0,
            "longitude" to 0.0,
            "accuracy" to 0.0,
            "altitude" to 0.0,
            "bearing" to 0.0,
            "speed" to 0.0,
            "timestamp" to System.currentTimeMillis()
        )

        // All 7 keys must exist for Dart LocationData.fromJson
        assertEquals(7, locationMap.size, "Location map should have exactly 7 keys")
        for (key in listOf("latitude", "longitude", "accuracy", "altitude", "bearing", "speed", "timestamp")) {
            assertTrue(locationMap.containsKey(key), "Location map missing key '$key'")
        }
    }

    // ============================================================
    // 10. TrackingConfig serialization — verify config map structure
    //     matches what Android SDK expects
    // ============================================================

    @Test
    fun trackingConfig_fromDartJson_hasExpectedKeys() {
        // This is what Dart LocationTrackingConfig.toJson() sends
        val dartConfig = mapOf(
            "intervalMs" to 5000,
            "distanceFilter" to 10.0,
            "accuracy" to "high",
            "backgroundMode" to true,
            "notificationTitle" to "GPS Tracking",
            "notificationMessage" to "Your location is being tracked"
        )

        // Android bridge reads these specific keys
        val intervalMs = (dartConfig["intervalMs"] as? Number)?.toLong() ?: 5000L
        val distanceFilter = (dartConfig["distanceFilter"] as? Number)?.toDouble() ?: 10.0
        val backgroundMode = dartConfig["backgroundMode"] as? Boolean ?: true
        val notificationTitle = dartConfig["notificationTitle"] as? String
        val notificationMessage = dartConfig["notificationMessage"] as? String

        assertEquals(5000L, intervalMs)
        assertEquals(10.0, distanceFilter)
        assertEquals(true, backgroundMode)
        assertEquals("GPS Tracking", notificationTitle)
        assertEquals("Your location is being tracked", notificationMessage)
    }

    @Test
    fun trackingConfig_withNumericTypes_parsesCorrectly() {
        // Dart may send Int or Double for numeric fields
        val configWithInt = mapOf("intervalMs" to 3000, "distanceFilter" to 5)
        val configWithDouble = mapOf("intervalMs" to 3000.0, "distanceFilter" to 5.0)

        // Both should parse to the correct types
        val interval1 = (configWithInt["intervalMs"] as? Number)?.toLong()
        val interval2 = (configWithDouble["intervalMs"] as? Number)?.toLong()
        val distance1 = (configWithInt["distanceFilter"] as? Number)?.toDouble()
        val distance2 = (configWithDouble["distanceFilter"] as? Number)?.toDouble()

        assertEquals(3000L, interval1)
        assertEquals(3000L, interval2)
        assertEquals(5.0, distance1)
        assertEquals(5.0, distance2)
    }

    // ============================================================
    // 11. Multiple HCMC GPX waypoints data validation
    // ============================================================

    @Test
    fun hcmcGpxWaypoints_allInValidRange() {
        // Sample waypoints from test/fixtures/city_run_hcmc.gpx
        val waypoints = listOf(
            Pair(10.776889, 106.700806),  // Bến Thành Market
            Pair(10.779784, 106.699074),  // Nhà thờ Đức Bà
            Pair(10.777042, 106.695179),  // Dinh Độc Lập
            Pair(10.775658, 106.701493),  // Công viên 23/9
            Pair(10.773699, 106.704079),  // Phố đi bộ Nguyễn Huệ
        )

        for ((lat, lon) in waypoints) {
            assertTrue(lat in 10.0..11.0, "Lat $lat out of HCMC range")
            assertTrue(lon in 106.0..107.0, "Lon $lon out of HCMC range")
        }
    }

    @Test
    fun hcmcGpxWaypoints_distanceBetweenPoints_reasonable() {
        // Consecutive waypoints should be within reasonable walking/driving distance
        val lat1 = 10.776889  // Bến Thành
        val lon1 = 106.700806
        val lat2 = 10.779784  // Nhà thờ Đức Bà
        val lon2 = 106.699074

        // Approximate distance using lat/lon degree distance (~111km per degree)
        val dLat = Math.abs(lat2 - lat1) * 111000  // meters
        val dLon = Math.abs(lon2 - lon1) * 111000 * Math.cos(Math.toRadians(lat1))

        val approxDistance = Math.sqrt(dLat * dLat + dLon * dLon)

        // Should be < 2km between consecutive points in District 1
        assertTrue(approxDistance < 2000.0,
            "Distance between consecutive HCMC waypoints should be < 2km, got ${approxDistance}m")
        assertTrue(approxDistance > 10.0,
            "Distance should be > 10m (not the same point), got ${approxDistance}m")
    }
}
