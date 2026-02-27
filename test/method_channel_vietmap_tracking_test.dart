import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vietmap_tracking_plugin/src/platform/method_channel_vietmap_tracking.dart';
import 'package:vietmap_tracking_plugin/vietmap_tracking_plugin.dart';

// Real API keys for accurate testing
const kVietmapApiKey = '0cd03613175a67f87567f86f0ba2f3b818e3a2b5f2c2634b';
const kAlertApiKey = '727494d3eb92b2f8d3a6aea1d8caf607f158bfb179776f45';
const kAlertApiId = 'a415885a-eb96-4463-8434-41afe0398f2e';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late MethodChannelVietmapTracking platform;

  // Store the mock handler so we can change it per test
  late Future<Object?>? Function(MethodCall call) mockHandler;

  setUp(() {
    platform = MethodChannelVietmapTracking();

    // Default mock handler — override in individual tests
    mockHandler = (MethodCall call) async => null;

    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
      const MethodChannel('vietmap_tracking_plugin'),
      (MethodCall call) => mockHandler(call),
    );
  });

  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
      const MethodChannel('vietmap_tracking_plugin'),
      null,
    );
  });

  // ============================================================
  // MARK: - configure
  // ============================================================

  group('configure', () {
    test('should invoke method with correct arguments', () async {
      String? capturedMethod;
      Map<Object?, Object?>? capturedArgs;

      mockHandler = (MethodCall call) async {
        capturedMethod = call.method;
        capturedArgs = call.arguments as Map<Object?, Object?>;
        return true;
      };

      await platform.configure(kVietmapApiKey, 'https://maps.vietmap.vn');

      expect(capturedMethod, 'configure');
      expect(capturedArgs!['apiKey'], kVietmapApiKey);
      expect(capturedArgs!['baseURL'], 'https://maps.vietmap.vn');
    });

    test('should pass null baseURL when not provided', () async {
      Map<Object?, Object?>? capturedArgs;

      mockHandler = (MethodCall call) async {
        capturedArgs = call.arguments as Map<Object?, Object?>;
        return true;
      };

      await platform.configure(kVietmapApiKey, null);

      expect(capturedArgs!['apiKey'], kVietmapApiKey);
      expect(capturedArgs!['baseURL'], isNull);
    });

    test('should return true on success', () async {
      mockHandler = (MethodCall call) async => true;

      final result = await platform.configure(kVietmapApiKey, null);
      expect(result, true);
    });

    test('should return false when native returns null', () async {
      mockHandler = (MethodCall call) async => null;

      final result = await platform.configure(kVietmapApiKey, null);
      expect(result, false);
    });

    test('should throw on PlatformException', () async {
      mockHandler = (MethodCall call) async {
        throw PlatformException(
          code: 'INVALID_ARGUMENTS',
          message: 'API key is required',
        );
      };

      expect(
        () => platform.configure('', null),
        throwsA(isA<Exception>()),
      );
    });
  });

  // ============================================================
  // MARK: - configureAlertAPI
  // ============================================================

  group('configureAlertAPI', () {
    test('should invoke method with apiKey and apiID', () async {
      String? capturedMethod;
      Map<Object?, Object?>? capturedArgs;

      mockHandler = (MethodCall call) async {
        capturedMethod = call.method;
        capturedArgs = call.arguments as Map<Object?, Object?>;
        return true;
      };

      await platform.configureAlertAPI(kAlertApiKey, kAlertApiId);

      expect(capturedMethod, 'configureAlertAPI');
      expect(capturedArgs!['apiKey'], kAlertApiKey);
      expect(capturedArgs!['apiID'], kAlertApiId);
    });

    test('should return true on success', () async {
      mockHandler = (MethodCall call) async => true;

      final result = await platform.configureAlertAPI(kAlertApiKey, kAlertApiId);
      expect(result, true);
    });

    test('should throw on SDK_NOT_INITIALIZED', () async {
      mockHandler = (MethodCall call) async {
        throw PlatformException(
          code: 'SDK_NOT_INITIALIZED',
          message: 'VietmapTrackingSDK not initialized',
        );
      };

      expect(
        () => platform.configureAlertAPI(kAlertApiKey, kAlertApiId),
        throwsA(isA<Exception>()),
      );
    });
  });

  // ============================================================
  // MARK: - requestLocationPermissions
  // ============================================================

  group('requestLocationPermissions', () {
    test('should return PermissionResult with granted=true', () async {
      mockHandler = (MethodCall call) async => {
            'granted': true,
            'status': 'granted',
            'fineLocation': true,
            'coarseLocation': true,
            'backgroundLocation': false,
          };

      final result = await platform.requestLocationPermissions();

      expect(result, isA<PermissionResult>());
      expect(result.granted, true);
      expect(result.status, PermissionStatus.granted);
      expect(result.fineLocation, true);
      expect(result.coarseLocation, true);
      expect(result.backgroundLocation, false);
    });

    test('should return PermissionResult with denied status', () async {
      mockHandler = (MethodCall call) async => {
            'granted': false,
            'status': 'denied',
            'fineLocation': false,
            'coarseLocation': false,
            'backgroundLocation': false,
          };

      final result = await platform.requestLocationPermissions();

      expect(result.granted, false);
      expect(result.status, PermissionStatus.denied);
    });

    test('should throw on null result', () async {
      mockHandler = (MethodCall call) async => null;

      expect(
        () => platform.requestLocationPermissions(),
        throwsA(isA<Exception>()),
      );
    });

    test('should throw on PlatformException', () async {
      mockHandler = (MethodCall call) async {
        throw PlatformException(
          code: 'PERMISSION_ERROR',
          message: 'Failed to request',
        );
      };

      expect(
        () => platform.requestLocationPermissions(),
        throwsA(isA<Exception>()),
      );
    });
  });

  // ============================================================
  // MARK: - hasLocationPermissions
  // ============================================================

  group('hasLocationPermissions', () {
    test('should return PermissionResult from native dict', () async {
      mockHandler = (MethodCall call) async => {
            'granted': true,
            'status': 'granted',
            'fineLocation': true,
            'coarseLocation': true,
            'backgroundLocation': true,
          };

      final result = await platform.hasLocationPermissions();

      expect(result, isA<PermissionResult>());
      expect(result.granted, true);
      expect(result.backgroundLocation, true);
    });

    test('should handle not_granted status', () async {
      mockHandler = (MethodCall call) async => {
            'granted': false,
            'status': 'not_granted',
            'fineLocation': false,
            'coarseLocation': false,
            'backgroundLocation': false,
          };

      final result = await platform.hasLocationPermissions();

      expect(result.granted, false);
      expect(result.status, PermissionStatus.notGranted);
    });

    test('should handle missing optional fields with defaults', () async {
      mockHandler = (MethodCall call) async => {
            'granted': true,
            'status': 'granted',
            // fineLocation, coarseLocation, backgroundLocation missing
          };

      final result = await platform.hasLocationPermissions();

      expect(result.granted, true);
      expect(result.fineLocation, false); // default from PermissionResult.fromJson
      expect(result.coarseLocation, false);
      expect(result.backgroundLocation, false);
    });
  });

  // ============================================================
  // MARK: - requestAlwaysLocationPermissions
  // ============================================================

  group('requestAlwaysLocationPermissions', () {
    test('should return "granted" string', () async {
      mockHandler = (MethodCall call) async => 'granted';

      final result = await platform.requestAlwaysLocationPermissions();
      expect(result, 'granted');
    });

    test('should return "when_in_use" string', () async {
      mockHandler = (MethodCall call) async => 'when_in_use';

      final result = await platform.requestAlwaysLocationPermissions();
      expect(result, 'when_in_use');
    });

    test('should return "denied" string', () async {
      mockHandler = (MethodCall call) async => 'denied';

      final result = await platform.requestAlwaysLocationPermissions();
      expect(result, 'denied');
    });

    test('should default to "denied" on null result', () async {
      mockHandler = (MethodCall call) async => null;

      final result = await platform.requestAlwaysLocationPermissions();
      expect(result, 'denied');
    });
  });

  // ============================================================
  // MARK: - startTracking
  // ============================================================

  group('startTracking', () {
    test('should send config.toJson() as arguments', () async {
      Map<Object?, Object?>? capturedArgs;

      mockHandler = (MethodCall call) async {
        capturedArgs = call.arguments as Map<Object?, Object?>;
        return true;
      };

      final config = LocationTrackingConfig(
        intervalMs: 5000,
        distanceFilter: 10.0,
        accuracy: LocationAccuracy.high,
        backgroundMode: true,
        notificationTitle: 'Tracking HCMC',
        notificationMessage: 'Running in District 1',
      );

      await platform.startTracking(config);

      expect(capturedArgs!['intervalMs'], 5000);
      expect(capturedArgs!['distanceFilter'], 10.0);
      expect(capturedArgs!['accuracy'], 'high');
      expect(capturedArgs!['backgroundMode'], true);
      expect(capturedArgs!['notificationTitle'], 'Tracking HCMC');
      expect(capturedArgs!['notificationMessage'], 'Running in District 1');
    });

    test('should return true on success', () async {
      mockHandler = (MethodCall call) async => true;

      final config = TrackingPresets.navigation();
      final result = await platform.startTracking(config);
      expect(result, true);
    });

    test('should return false on failure', () async {
      mockHandler = (MethodCall call) async => false;

      final config = TrackingPresets.general();
      final result = await platform.startTracking(config);
      expect(result, false);
    });

    test('should return false on null', () async {
      mockHandler = (MethodCall call) async => null;

      final config = TrackingPresets.batterySaver();
      final result = await platform.startTracking(config);
      expect(result, false);
    });

    test('should throw on PERMISSION_DENIED', () async {
      mockHandler = (MethodCall call) async {
        throw PlatformException(
          code: 'PERMISSION_DENIED',
          message: 'Location permission not granted',
        );
      };

      expect(
        () => platform.startTracking(TrackingPresets.fitness()),
        throwsA(isA<Exception>()),
      );
    });

    test('should throw on SDK_NOT_INITIALIZED', () async {
      mockHandler = (MethodCall call) async {
        throw PlatformException(
          code: 'SDK_NOT_INITIALIZED',
          message: 'VietmapTrackingSDK not initialized',
        );
      };

      expect(
        () => platform.startTracking(TrackingPresets.navigation()),
        throwsA(isA<Exception>()),
      );
    });

    test('should use fitness preset config', () async {
      Map<Object?, Object?>? capturedArgs;

      mockHandler = (MethodCall call) async {
        capturedArgs = call.arguments as Map<Object?, Object?>;
        return true;
      };

      await platform.startTracking(TrackingPresets.fitness());

      expect(capturedArgs!['intervalMs'], 5000);
      expect(capturedArgs!['distanceFilter'], 10.0);
      expect(capturedArgs!['accuracy'], 'high');
      expect(capturedArgs!['backgroundMode'], true);
    });

    test('should use battery saver preset config', () async {
      Map<Object?, Object?>? capturedArgs;

      mockHandler = (MethodCall call) async {
        capturedArgs = call.arguments as Map<Object?, Object?>;
        return true;
      };

      await platform.startTracking(TrackingPresets.batterySaver());

      expect(capturedArgs!['intervalMs'], 30000);
      expect(capturedArgs!['distanceFilter'], 50.0);
      expect(capturedArgs!['accuracy'], 'low');
    });
  });

  // ============================================================
  // MARK: - stopTracking
  // ============================================================

  group('stopTracking', () {
    test('should invoke stopTracking method', () async {
      String? capturedMethod;

      mockHandler = (MethodCall call) async {
        capturedMethod = call.method;
        return true;
      };

      await platform.stopTracking();
      expect(capturedMethod, 'stopTracking');
    });

    test('should return true on success', () async {
      mockHandler = (MethodCall call) async => true;

      final result = await platform.stopTracking();
      expect(result, true);
    });

    test('should return false on null', () async {
      mockHandler = (MethodCall call) async => null;

      final result = await platform.stopTracking();
      expect(result, false);
    });

    test('should throw on SDK_NOT_INITIALIZED', () async {
      mockHandler = (MethodCall call) async {
        throw PlatformException(
          code: 'SDK_NOT_INITIALIZED',
          message: 'VietmapTrackingSDK not initialized',
        );
      };

      expect(
        () => platform.stopTracking(),
        throwsA(isA<Exception>()),
      );
    });
  });

  // ============================================================
  // MARK: - getCurrentLocation
  // ============================================================

  group('getCurrentLocation', () {
    test('should return LocationData from HCMC coordinates', () async {
      // Waypoint: Nhà thờ Đức Bà, District 1, HCMC
      mockHandler = (MethodCall call) async => {
            'latitude': 10.779784,
            'longitude': 106.699074,
            'altitude': 12.0,
            'accuracy': 5.0,
            'speed': 2.78,
            'bearing': 180.0,
            'timestamp': 1700000000000,
          };

      final result = await platform.getCurrentLocation();

      expect(result, isA<LocationData>());
      expect(result.latitude, 10.779784);
      expect(result.longitude, 106.699074);
      expect(result.altitude, 12.0);
      expect(result.accuracy, 5.0);
      expect(result.speed, 2.78);
      expect(result.bearing, 180.0);
      expect(result.timestamp, 1700000000000);
    });

    test('should parse Dinh Độc Lập waypoint', () async {
      // GPX waypoint: Dinh Độc Lập area
      mockHandler = (MethodCall call) async => {
            'latitude': 10.777167,
            'longitude': 106.695639,
            'altitude': 11.0,
            'accuracy': 4.0,
            'speed': 2.78,
            'bearing': 240.0,
            'timestamp': 1700000075000,
          };

      final result = await platform.getCurrentLocation();

      expect(result.latitude, closeTo(10.777, 0.001));
      expect(result.longitude, closeTo(106.696, 0.001));
    });

    test('should parse Nguyễn Huệ walking street waypoint', () async {
      // GPX waypoint: Nguyễn Huệ pedestrian street
      mockHandler = (MethodCall call) async => {
            'latitude': 10.773944,
            'longitude': 106.703583,
            'altitude': 9.0,
            'accuracy': 3.0,
            'speed': 2.78,
            'bearing': 135.0,
            'timestamp': 1700000170000,
          };

      final result = await platform.getCurrentLocation();

      expect(result.latitude, closeTo(10.774, 0.001));
      expect(result.longitude, closeTo(106.704, 0.001));
      expect(result.speed, closeTo(2.78, 0.01));
    });

    test('should throw on null result', () async {
      mockHandler = (MethodCall call) async => null;

      expect(
        () => platform.getCurrentLocation(),
        throwsA(isA<Exception>()),
      );
    });

    test('should throw on LOCATION_UNAVAILABLE', () async {
      mockHandler = (MethodCall call) async {
        throw PlatformException(
          code: 'LOCATION_UNAVAILABLE',
          message: 'Unable to get current location',
        );
      };

      expect(
        () => platform.getCurrentLocation(),
        throwsA(isA<Exception>()),
      );
    });

    test('should convert timestamp to DateTime correctly', () async {
      mockHandler = (MethodCall call) async => {
            'latitude': 10.779784,
            'longitude': 106.699074,
            'altitude': 12.0,
            'accuracy': 5.0,
            'speed': 0.0,
            'bearing': 0.0,
            'timestamp': 1700000000000,
          };

      final result = await platform.getCurrentLocation();
      final dateTime = result.dateTime;

      expect(dateTime.year, 2023);
      expect(dateTime.millisecondsSinceEpoch, 1700000000000);
    });
  });

  // ============================================================
  // MARK: - isTrackingActive
  // ============================================================

  group('isTrackingActive', () {
    test('should return false when not tracking', () async {
      mockHandler = (MethodCall call) async => false;

      final result = await platform.isTrackingActive();
      expect(result, false);
    });

    test('should return true when tracking', () async {
      mockHandler = (MethodCall call) async => true;

      final result = await platform.isTrackingActive();
      expect(result, true);
    });

    test('should return false on null', () async {
      mockHandler = (MethodCall call) async => null;

      final result = await platform.isTrackingActive();
      expect(result, false);
    });
  });

  // ============================================================
  // MARK: - getTrackingStatus
  // ============================================================

  group('getTrackingStatus', () {
    test('should return TrackingStatus model', () async {
      mockHandler = (MethodCall call) async => {
            'isTracking': true,
            'lastLocationUpdate': 1700000255000,
            'trackingDuration': 255000,
          };

      final result = await platform.getTrackingStatus();

      expect(result, isA<TrackingStatus>());
      expect(result.isTracking, true);
      expect(result.lastLocationUpdate, 1700000255000);
      expect(result.trackingDuration, 255000);
    });

    test('should compute duration from trackingDuration', () async {
      mockHandler = (MethodCall call) async => {
            'isTracking': true,
            'lastLocationUpdate': null,
            'trackingDuration': 120000, // 2 minutes
          };

      final result = await platform.getTrackingStatus();
      expect(result.duration.inSeconds, 120);
      expect(result.duration.inMinutes, 2);
    });

    test('should handle null lastLocationUpdate', () async {
      mockHandler = (MethodCall call) async => {
            'isTracking': false,
            'lastLocationUpdate': null,
            'trackingDuration': 0,
          };

      final result = await platform.getTrackingStatus();
      expect(result.lastUpdateTime, isNull);
      expect(result.isTracking, false);
    });

    test('should throw on null result', () async {
      mockHandler = (MethodCall call) async => null;

      expect(
        () => platform.getTrackingStatus(),
        throwsA(isA<Exception>()),
      );
    });
  });

  // ============================================================
  // MARK: - updateTrackingConfig
  // ============================================================

  group('updateTrackingConfig', () {
    test('should send config as arguments', () async {
      Map<Object?, Object?>? capturedArgs;

      mockHandler = (MethodCall call) async {
        capturedArgs = call.arguments as Map<Object?, Object?>;
        return true;
      };

      final config = LocationTrackingConfig(
        intervalMs: 3000,
        distanceFilter: 5.0,
        accuracy: LocationAccuracy.medium,
        backgroundMode: false,
      );

      await platform.updateTrackingConfig(config);

      expect(capturedArgs!['intervalMs'], 3000);
      expect(capturedArgs!['distanceFilter'], 5.0);
      expect(capturedArgs!['accuracy'], 'medium');
      expect(capturedArgs!['backgroundMode'], false);
    });

    test('should return true (iOS no-op)', () async {
      mockHandler = (MethodCall call) async => true;

      final config = TrackingPresets.general();
      final result = await platform.updateTrackingConfig(config);
      expect(result, true);
    });

    test('should throw on SDK_NOT_INITIALIZED', () async {
      mockHandler = (MethodCall call) async {
        throw PlatformException(
          code: 'SDK_NOT_INITIALIZED',
          message: 'VietmapTrackingSDK not initialized',
        );
      };

      expect(
        () => platform.updateTrackingConfig(TrackingPresets.general()),
        throwsA(isA<Exception>()),
      );
    });
  });

  // ============================================================
  // MARK: - GPX Waypoint-based Location Tests
  // ============================================================

  group('GPX HCMC Route Tests', () {
    /// Simulate a sequence of location updates along the HCMC route
    /// and verify LocationData parses each one correctly.
    test('should parse all GPX waypoints along District 1 route', () async {
      // Selected waypoints from city_run_hcmc.gpx
      final waypoints = [
        // Nhà thờ Đức Bà (start)
        {
          'lat': 10.779784,
          'lon': 106.699074,
          'name': 'Notre Dame Cathedral'
        },
        // Lê Duẩn
        {'lat': 10.779278, 'lon': 106.698167, 'name': 'Le Duan Boulevard'},
        // Dinh Độc Lập
        {
          'lat': 10.777167,
          'lon': 106.695639,
          'name': 'Independence Palace'
        },
        // Nguyễn Huệ
        {
          'lat': 10.773944,
          'lon': 106.703583,
          'name': 'Nguyen Hue Walking St'
        },
        // Đồng Khởi
        {'lat': 10.777250, 'lon': 106.702917, 'name': 'Dong Khoi Street'},
        // Back to start
        {'lat': 10.779750, 'lon': 106.699139, 'name': 'Return to Cathedral'},
      ];

      for (final wp in waypoints) {
        mockHandler = (MethodCall call) async => {
              'latitude': wp['lat'],
              'longitude': wp['lon'],
              'altitude': 10.0,
              'accuracy': 5.0,
              'speed': 2.78,
              'bearing': 0.0,
              'timestamp': 1700000000000,
            };

        final location = await platform.getCurrentLocation();

        expect(location.latitude, wp['lat'],
            reason: 'Latitude mismatch at ${wp['name']}');
        expect(location.longitude, wp['lon'],
            reason: 'Longitude mismatch at ${wp['name']}');

        // All HCMC District 1 coordinates should be in valid range
        expect(location.latitude, greaterThan(10.77),
            reason: '${wp['name']} lat too low');
        expect(location.latitude, lessThan(10.79),
            reason: '${wp['name']} lat too high');
        expect(location.longitude, greaterThan(106.69),
            reason: '${wp['name']} lon too low');
        expect(location.longitude, lessThan(106.71),
            reason: '${wp['name']} lon too high');
      }
    });

    test('should calculate distance between GPX waypoints', () {
      // Use LocationUtils to verify distance calculation between waypoints
      final start = LocationData(
        latitude: 10.779784,
        longitude: 106.699074, // Nhà thờ Đức Bà
        altitude: 12.0,
        accuracy: 5.0,
        speed: 2.78,
        bearing: 180.0,
        timestamp: 1700000000000,
      );

      final palace = LocationData(
        latitude: 10.777167,
        longitude: 106.695639, // Dinh Độc Lập
        altitude: 11.0,
        accuracy: 4.0,
        speed: 2.78,
        bearing: 240.0,
        timestamp: 1700000075000,
      );

      final distance = LocationUtils.distanceBetween(start, palace);
      // Nhà thờ Đức Bà → Dinh Độc Lập ≈ 450m
      expect(distance, greaterThan(300),
          reason: 'Cathedral to Palace should be >300m');
      expect(distance, lessThan(700),
          reason: 'Cathedral to Palace should be <700m');
    });

    test('should validate speed conversion for HCMC route', () {
      // GPX route speed ~10 km/h = ~2.78 m/s
      final speedMs = 2.78;
      final speedKmh = LocationUtils.metersPerSecondToKmh(speedMs);

      expect(speedKmh, closeTo(10.0, 0.1),
          reason: '2.78 m/s should be ~10 km/h');

      // Reverse conversion
      final backToMs = LocationUtils.kmhToMetersPerSecond(10.0);
      expect(backToMs, closeTo(2.78, 0.01));
    });

    test('should verify waypoint is within District 1 radius', () {
      // Center of District 1: ~10.776, 106.700
      final location = LocationData(
        latitude: 10.773944, // Nguyễn Huệ
        longitude: 106.703583,
        altitude: 9.0,
        accuracy: 3.0,
        speed: 2.78,
        bearing: 135.0,
        timestamp: 1700000170000,
      );

      // All GPX waypoints should be within 1km of District 1 center
      final isInDistrict1 = LocationUtils.isWithinRadius(
        location,
        10.776, // center lat
        106.700, // center lon
        1500, // 1.5 km radius
      );
      expect(isInDistrict1, true,
          reason: 'Nguyen Hue should be within 1.5km of District 1 center');
    });

    test('should format HCMC coordinates correctly', () {
      final formatted = LocationUtils.formatCoordinates(10.779784, 106.699074);
      expect(formatted, contains('N'), reason: 'HCMC is in Northern hemisphere');
      expect(formatted, contains('E'), reason: 'HCMC is in Eastern hemisphere');
      expect(formatted, contains('10.779784'));
      expect(formatted, contains('106.699074'));
    });
  });

  // ============================================================
  // MARK: - Method Name Verification
  // ============================================================

  group('Method Name Verification', () {
    /// Verify that every method calls the correct MethodChannel method name
    /// (must match the iOS handle switch cases exactly)
    test('all method names match iOS bridge', () async {
      final invokedMethods = <String>[];

      mockHandler = (MethodCall call) async {
        invokedMethods.add(call.method);
        // Return appropriate types for each method
        switch (call.method) {
          case 'configure':
          case 'configureAlertAPI':
          case 'startTracking':
          case 'stopTracking':
          case 'updateTrackingConfig':
          case 'isTrackingActive':
            return true;
          case 'requestLocationPermissions':
          case 'hasLocationPermissions':
            return {
              'granted': true,
              'status': 'granted',
              'fineLocation': true,
              'coarseLocation': true,
              'backgroundLocation': false,
            };
          case 'requestAlwaysLocationPermissions':
            return 'granted';
          case 'getCurrentLocation':
            return {
              'latitude': 10.779784,
              'longitude': 106.699074,
              'altitude': 12.0,
              'accuracy': 5.0,
              'speed': 0.0,
              'bearing': 0.0,
              'timestamp': 1700000000000,
            };
          case 'getTrackingStatus':
            return {
              'isTracking': false,
              'lastLocationUpdate': null,
              'trackingDuration': 0,
            };
          default:
            return null;
        }
      };

      // Call every method
      await platform.configure(kVietmapApiKey, null);
      await platform.configureAlertAPI(kAlertApiKey, kAlertApiId);
      await platform.requestLocationPermissions();
      await platform.hasLocationPermissions();
      await platform.requestAlwaysLocationPermissions();
      await platform.startTracking(TrackingPresets.navigation());
      await platform.stopTracking();
      await platform.getCurrentLocation();
      await platform.isTrackingActive();
      await platform.getTrackingStatus();
      await platform.updateTrackingConfig(TrackingPresets.general());

      // Verify all method names match iOS switch cases
      expect(invokedMethods, [
        'configure',
        'configureAlertAPI',
        'requestLocationPermissions',
        'hasLocationPermissions',
        'requestAlwaysLocationPermissions',
        'startTracking',
        'stopTracking',
        'getCurrentLocation',
        'isTrackingActive',
        'getTrackingStatus',
        'updateTrackingConfig',
      ]);
    });
  });

  // ============================================================
  // MARK: - Config Serialization Round-trip
  // ============================================================

  group('Config Serialization Round-trip', () {
    test('LocationTrackingConfig toJson matches iOS argument parsing', () {
      final config = LocationTrackingConfig(
        intervalMs: 5000,
        distanceFilter: 10.0,
        accuracy: LocationAccuracy.high,
        backgroundMode: true,
        notificationTitle: 'VietMap',
        notificationMessage: 'Tracking location in HCMC',
      );

      final json = config.toJson();

      // These keys must match what iOS startTracking reads from call.arguments
      expect(json.containsKey('intervalMs'), true);
      expect(json.containsKey('distanceFilter'), true);
      expect(json.containsKey('accuracy'), true);
      expect(json.containsKey('backgroundMode'), true);
      expect(json.containsKey('notificationTitle'), true);
      expect(json.containsKey('notificationMessage'), true);

      // Type checks matching iOS guard parsing
      expect(json['intervalMs'], isA<int>());
      expect(json['distanceFilter'], isA<double>());
      expect(json['accuracy'], isA<String>());
      expect(json['backgroundMode'], isA<bool>());
    });

    test('all preset configs serialize correctly', () {
      final presets = [
        TrackingPresets.navigation(),
        TrackingPresets.fitness(),
        TrackingPresets.general(),
        TrackingPresets.batterySaver(),
      ];

      for (final config in presets) {
        final json = config.toJson();
        // Every preset must produce valid JSON that iOS can parse
        expect(json['intervalMs'], isA<int>());
        expect(json['distanceFilter'], isA<double>());
        expect(json['accuracy'], isA<String>());
        expect(json['backgroundMode'], isA<bool>());
        expect(json['intervalMs'], greaterThan(0));
        expect(json['distanceFilter'], greaterThan(0.0));
      }
    });
  });

  // ============================================================
  // MARK: - turnOnAlert
  // ============================================================

  group('turnOnAlert', () {
    test('should invoke turnOnAlert method', () async {
      String? capturedMethod;

      mockHandler = (MethodCall call) async {
        capturedMethod = call.method;
        return true;
      };

      await platform.turnOnAlert();
      expect(capturedMethod, 'turnOnAlert');
    });

    test('should return true on success', () async {
      mockHandler = (MethodCall call) async => true;

      final result = await platform.turnOnAlert();
      expect(result, true);
    });

    test('should return false on null', () async {
      mockHandler = (MethodCall call) async => null;

      final result = await platform.turnOnAlert();
      expect(result, false);
    });

    test('should return false on failure', () async {
      mockHandler = (MethodCall call) async => false;

      final result = await platform.turnOnAlert();
      expect(result, false);
    });

    test('should throw on SDK_NOT_INITIALIZED', () async {
      mockHandler = (MethodCall call) async {
        throw PlatformException(
          code: 'SDK_NOT_INITIALIZED',
          message: 'VietmapTrackingSDK not initialized',
        );
      };

      expect(
        () => platform.turnOnAlert(),
        throwsA(isA<Exception>()),
      );
    });

    test('should throw on ALERT_NOT_CONFIGURED', () async {
      mockHandler = (MethodCall call) async {
        throw PlatformException(
          code: 'ALERT_NOT_CONFIGURED',
          message: 'Alert API not configured. Call configureAlertAPI first.',
        );
      };

      expect(
        () => platform.turnOnAlert(),
        throwsA(isA<Exception>()),
      );
    });
  });

  // ============================================================
  // MARK: - turnOffAlert
  // ============================================================

  group('turnOffAlert', () {
    test('should invoke turnOffAlert method', () async {
      String? capturedMethod;

      mockHandler = (MethodCall call) async {
        capturedMethod = call.method;
        return true;
      };

      await platform.turnOffAlert();
      expect(capturedMethod, 'turnOffAlert');
    });

    test('should return true on success', () async {
      mockHandler = (MethodCall call) async => true;

      final result = await platform.turnOffAlert();
      expect(result, true);
    });

    test('should return false on null', () async {
      mockHandler = (MethodCall call) async => null;

      final result = await platform.turnOffAlert();
      expect(result, false);
    });

    test('should return false on failure', () async {
      mockHandler = (MethodCall call) async => false;

      final result = await platform.turnOffAlert();
      expect(result, false);
    });

    test('should throw on SDK_NOT_INITIALIZED', () async {
      mockHandler = (MethodCall call) async {
        throw PlatformException(
          code: 'SDK_NOT_INITIALIZED',
          message: 'VietmapTrackingSDK not initialized',
        );
      };

      expect(
        () => platform.turnOffAlert(),
        throwsA(isA<Exception>()),
      );
    });

    test('should throw on ALERT_NOT_CONFIGURED', () async {
      mockHandler = (MethodCall call) async {
        throw PlatformException(
          code: 'ALERT_NOT_CONFIGURED',
          message: 'Alert API not configured. Call configureAlertAPI first.',
        );
      };

      expect(
        () => platform.turnOffAlert(),
        throwsA(isA<Exception>()),
      );
    });
  });
}
