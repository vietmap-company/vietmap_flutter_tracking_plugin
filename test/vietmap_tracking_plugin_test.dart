import 'package:flutter_test/flutter_test.dart';
import 'package:vietmap_tracking_plugin/vietmap_tracking_plugin.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('LocationTrackingConfig', () {
    test('should serialize to JSON correctly', () {
      final config = LocationTrackingConfig(
        intervalMs: 5000,
        distanceFilter: 10.0,
        accuracy: LocationAccuracy.high,
        backgroundMode: true,
        notificationTitle: 'Test',
        notificationMessage: 'Testing',
      );

      final json = config.toJson();

      expect(json['intervalMs'], 5000);
      expect(json['distanceFilter'], 10.0);
      expect(json['accuracy'], 'high');
      expect(json['backgroundMode'], true);
      expect(json['notificationTitle'], 'Test');
      expect(json['notificationMessage'], 'Testing');
    });

    test('should deserialize from JSON correctly', () {
      final json = {
        'intervalMs': 3000,
        'distanceFilter': 15.0,
        'accuracy': 'medium',
        'backgroundMode': false,
        'notificationTitle': 'Nav',
        'notificationMessage': 'Navigating',
      };

      final config = LocationTrackingConfig.fromJson(json);

      expect(config.intervalMs, 3000);
      expect(config.distanceFilter, 15.0);
      expect(config.accuracy, LocationAccuracy.medium);
      expect(config.backgroundMode, false);
      expect(config.notificationTitle, 'Nav');
      expect(config.notificationMessage, 'Navigating');
    });

    test('should create copy with changes', () {
      final original = LocationTrackingConfig(
        intervalMs: 5000,
        distanceFilter: 10.0,
        accuracy: LocationAccuracy.high,
        backgroundMode: true,
      );

      final copy = original.copyWith(
        intervalMs: 3000,
        accuracy: LocationAccuracy.low,
      );

      expect(copy.intervalMs, 3000);
      expect(copy.distanceFilter, 10.0);
      expect(copy.accuracy, LocationAccuracy.low);
      expect(copy.backgroundMode, true);
    });
  });

  group('LocationData', () {
    test('should serialize to JSON correctly (new contract)', () {
      final locationData = LocationData(
        latitude: 21.028511,
        longitude: 105.804817,
        altitude: 10.0,
        accuracy: 5.0,
        speed: 2.567,
        heading: 90.0,
        timestamp: 1234567890,
        metaData: {'source': 'gps', 'confidence': 0.95},
      );

      final json = locationData.toJson();

      expect(json['lat'], closeTo(21.028511, 1e-12));
      expect(json['lng'], closeTo(105.804817, 1e-12));
      expect(json['speed'], isA<int>());
      expect(json['speed'], 2);
      expect(json['heading'], 90.0);
      expect(json['time'], 1234567890);
      expect(json.containsKey('timestamp'), false);
      expect(json['metaData'], {'source': 'gps', 'confidence': 0.95});
      
      // Verify accuracy and altitude are NOT included in API payload
      expect(json.containsKey('accuracy'), false);
      expect(json.containsKey('altitude'), false);
      expect(json.containsKey('status'), false);
    });

    test('should deserialize from new contract JSON', () {
      final json = {
        'lat': 21.028511,
        'lng': 105.804817,
        'altitude': 10.0,
        'accuracy': 5.0,
        'speed': 2,
        'heading': 90.0,
        'time': 1234567890,
        'metaData': {'source': 'gps'},
      };

      final locationData = LocationData.fromJson(json);

      expect(locationData.latitude, 21.028511);
      expect(locationData.longitude, 105.804817);
      expect(locationData.altitude, 10.0);
      expect(locationData.accuracy, 5.0);
      expect(locationData.speed, 2.0);
      expect(locationData.heading, 90.0);
      expect(locationData.timestamp, 1234567890);
      expect(locationData.metaData, {'source': 'gps'});
    });

    test('should deserialize from legacy JSON (backward compatible)', () {
      final json = {
        'latitude': 21.028511,
        'longitude': 105.804817,
        'altitude': 10.0,
        'accuracy': 5.0,
        'speed': 2.5,
        'bearing': 90.0,
        'timestamp': 1234567890,
      };

      final locationData = LocationData.fromJson(json);

      expect(locationData.latitude, 21.028511);
      expect(locationData.longitude, 105.804817);
      expect(locationData.heading, 90.0);
      expect(locationData.timestamp, 1234567890);
    });

    test('should convert timestamp to DateTime', () {
      final locationData = LocationData(
        latitude: 21.028511,
        longitude: 105.804817,
        altitude: 10.0,
        accuracy: 5.0,
        speed: 2.5,
        heading: 90.0,
        timestamp: 1234567890000,
      );

      expect(locationData.dateTime.millisecondsSinceEpoch, 1234567890000);
    });

    test('should clamp speed to 0..32767 range', () {
      final highSpeed = LocationData(
        latitude: 10.0,
        longitude: 106.0,
        altitude: 0.0,
        accuracy: 5.0,
        speed: 50000.0,
        heading: 0.0,
        timestamp: 0,
      );

      final json = highSpeed.toJson();
      expect(json['speed'], 32767);

      final negativeSpeed = LocationData(
        latitude: 10.0,
        longitude: 106.0,
        altitude: 0.0,
        accuracy: 5.0,
        speed: -5.0,
        heading: 0.0,
        timestamp: 0,
      );

      final json2 = negativeSpeed.toJson();
      expect(json2['speed'], 0);
    });

    test('should round lat/lng to 12 decimal places', () {
      final locationData = LocationData(
        latitude: 10.77191234567890,
        longitude: 106.70109876543210,
        altitude: 0.0,
        accuracy: 5.0,
        speed: 10.0,
        heading: 0.0,
        timestamp: 0,
      );

      final json = locationData.toJson();

      expect(json['lat'], closeTo(10.771912345679, 1e-12));
      expect(json['lng'], closeTo(106.701098765432, 1e-12));
    });
  });

  group('TrackingStatus', () {
    test('should serialize and deserialize correctly', () {
      final status = TrackingStatus(
        isTracking: true,
        lastLocationUpdate: 1234567890000,
        trackingDuration: 60000,
      );

      final json = status.toJson();
      final restored = TrackingStatus.fromJson(json);

      expect(restored.isTracking, true);
      expect(restored.lastLocationUpdate, 1234567890000);
      expect(restored.trackingDuration, 60000);
    });

    test('should calculate duration correctly', () {
      final status = TrackingStatus(
        isTracking: true,
        lastLocationUpdate: null,
        trackingDuration: 120000,
      );

      expect(status.duration.inSeconds, 120);
      expect(status.lastUpdateTime, null);
    });
  });

  group('PermissionResult', () {
    test('should serialize and deserialize correctly', () {
      final result = PermissionResult(
        granted: true,
        status: PermissionStatus.granted,
        fineLocation: true,
        coarseLocation: true,
        backgroundLocation: false,
      );

      final json = result.toJson();
      final restored = PermissionResult.fromJson(json);

      expect(restored.granted, true);
      expect(restored.status, PermissionStatus.granted);
      expect(restored.fineLocation, true);
      expect(restored.coarseLocation, true);
      expect(restored.backgroundLocation, false);
    });
  });

  group('LocationUtils', () {
    test('should calculate distance correctly', () {
      // Distance between Hanoi and Ho Chi Minh City (approximate)
      final distance = LocationUtils.calculateDistance(
        21.028511,
        105.804817, // Hanoi
        10.762622,
        106.660172, // Ho Chi Minh
      );

      // Expected distance is approximately 1,150 km = 1,150,000 meters
      expect(distance, greaterThan(1100000));
      expect(distance, lessThan(1200000));
    });

    test('should calculate distance between LocationData objects', () {
      final loc1 = LocationData(
        latitude: 21.028511,
        longitude: 105.804817,
        altitude: 0,
        accuracy: 0,
        speed: 0,
        heading: 0,
        timestamp: 0,
      );

      final loc2 = LocationData(
        latitude: 21.038511,
        longitude: 105.814817,
        altitude: 0,
        accuracy: 0,
        speed: 0,
        heading: 0,
        timestamp: 0,
      );

      final distance = LocationUtils.distanceBetween(loc1, loc2);
      expect(distance, greaterThan(0));
    });

    test('should convert speed units correctly', () {
      expect(LocationUtils.metersPerSecondToKmh(10), 36.0);
      expect(LocationUtils.kmhToMetersPerSecond(36), 10.0);
    });

    test('should format coordinates correctly', () {
      final formatted = LocationUtils.formatCoordinates(21.028511, 105.804817);
      expect(formatted, contains('21.028511'));
      expect(formatted, contains('105.804817'));
      expect(formatted, contains('N'));
      expect(formatted, contains('E'));
    });

    test('should check radius correctly', () {
      final location = LocationData(
        latitude: 21.028511,
        longitude: 105.804817,
        altitude: 0,
        accuracy: 0,
        speed: 0,
        heading: 0,
        timestamp: 0,
      );

      // Within 1km radius
      expect(LocationUtils.isWithinRadius(location, 21.03, 105.81, 1000), true);

      // Outside 10m radius
      expect(
        LocationUtils.isWithinRadius(location, 21.029, 105.806, 10),
        false,
      );
    });
  });

  group('TrackingPresets', () {
    test('navigation preset should have correct values', () {
      final config = TrackingPresets.navigation();
      expect(config.intervalMs, 5000);
      expect(config.distanceFilter, isNull);
      expect(config.accuracy, LocationAccuracy.high);
      expect(config.backgroundMode, true);
    });

    test('fitness preset should have correct values', () {
      final config = TrackingPresets.fitness();
      expect(config.intervalMs, 10000);
      expect(config.distanceFilter, isNull);
      expect(config.accuracy, LocationAccuracy.high);
      expect(config.backgroundMode, true);
    });

    test('general preset should have correct values', () {
      final config = TrackingPresets.general();
      expect(config.intervalMs, 30000);
      expect(config.distanceFilter, isNull);
      expect(config.accuracy, LocationAccuracy.medium);
      expect(config.backgroundMode, true);
    });

    test('battery saver preset should have correct values', () {
      final config = TrackingPresets.batterySaver();
      expect(config.intervalMs, 300000);
      expect(config.distanceFilter, isNull);
      expect(config.accuracy, LocationAccuracy.low);
      expect(config.backgroundMode, true);
    });

    test('distance presets respect the 25m SDK floor and increase monotonically',
        () {
      expect(TrackingPresets.navigationDistance().distanceFilter, 25.0);
      expect(TrackingPresets.fitnessDistance().distanceFilter, 50.0);
      expect(TrackingPresets.generalDistance().distanceFilter, 70.0);
      expect(TrackingPresets.batterySaverDistance().distanceFilter, 120.0);
      // Distance mode leaves the timer disabled.
      expect(TrackingPresets.navigationDistance().intervalMs, isNull);
    });

    test('presets should accept custom notification text', () {
      final config = TrackingPresets.navigation(
        notificationTitle: 'Custom Title',
        notificationMessage: 'Custom Message',
      );
      expect(config.notificationTitle, 'Custom Title');
      expect(config.notificationMessage, 'Custom Message');
    });
  });

  group('LocationAccuracy', () {
    test('should convert from string correctly', () {
      expect(LocationAccuracy.fromString('high'), LocationAccuracy.high);
      expect(LocationAccuracy.fromString('medium'), LocationAccuracy.medium);
      expect(LocationAccuracy.fromString('low'), LocationAccuracy.low);
      expect(LocationAccuracy.fromString('invalid'), LocationAccuracy.high);
    });

    test('should have correct values', () {
      expect(LocationAccuracy.high.value, 'high');
      expect(LocationAccuracy.medium.value, 'medium');
      expect(LocationAccuracy.low.value, 'low');
    });
  });

  group('PermissionStatus', () {
    test('should convert from string correctly', () {
      expect(PermissionStatus.fromString('granted'), PermissionStatus.granted);
      expect(PermissionStatus.fromString('denied'), PermissionStatus.denied);
      expect(
        PermissionStatus.fromString('not_granted'),
        PermissionStatus.notGranted,
      );
      expect(
        PermissionStatus.fromString('invalid'),
        PermissionStatus.notGranted,
      );
    });
  });
}
