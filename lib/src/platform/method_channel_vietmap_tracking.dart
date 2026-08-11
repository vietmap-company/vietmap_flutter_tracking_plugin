import 'dart:async';
import 'package:flutter/services.dart';
import 'vietmap_tracking_platform_interface.dart';
import '../models/location_tracking_config.dart';
import '../models/location_data.dart';
import '../models/tracking_status.dart';
import '../models/permission_result.dart';
import '../models/fake_gps_event.dart';
import '../models/tracking_interrupted_event.dart';

class MethodChannelVietmapTracking extends VietmapTrackingPlatform {
  static const MethodChannel _channel = MethodChannel(
    'vietmap_tracking_plugin',
  );

  static const EventChannel _locationUpdateChannel = EventChannel(
    'vietmap_tracking_plugin/location_updates',
  );

  static const EventChannel _trackingStatusChannel = EventChannel(
    'vietmap_tracking_plugin/tracking_status',
  );

  // Broadcast controller for native→Dart fake GPS events.
  // Native sends via channel.invokeMethod("onFakeGPSDetected", payload).
  static final _fakeGpsController = StreamController<FakeGpsEvent>.broadcast();

  // Broadcast controller for native→Dart tracking-interrupted events.
  // Native sends via channel.invokeMethod("onTrackingInterrupted", payload).
  static final _trackingInterruptedController =
      StreamController<TrackingInterruptedEvent>.broadcast();

  // Set up MethodChannel handler for native→Dart calls (e.g. onFakeGPSDetected).
  // Must be called once; subsequent calls override the previous handler.
  static void _ensureMethodCallHandler() {
    _channel.setMethodCallHandler((call) async {
      if (call.method == 'onFakeGPSDetected') {
        if (!_fakeGpsController.isClosed) {
          _fakeGpsController.add(
            FakeGpsEvent.fromMap(call.arguments as Map<Object?, Object?>),
          );
        }
      } else if (call.method == 'onTrackingInterrupted') {
        if (!_trackingInterruptedController.isClosed) {
          _trackingInterruptedController.add(
            TrackingInterruptedEvent.fromMap(
              call.arguments as Map<Object?, Object?>,
            ),
          );
        }
      }
    });
  }

  // Install handler once at class load time.
  static final _handlerInstalled = () {
    _ensureMethodCallHandler();
    return true;
  }();

  // ── Configuration ────────────────────────────────────────────

  @override
  Future<bool> configure(String apiKey, String? baseURL) async {
    try {
      final args = {'apiKey': apiKey, 'baseURL': baseURL};
      final result = await _channel.invokeMethod<bool>('configure', args);
      return result ?? false;
    } on PlatformException catch (e) {
      throw Exception('Failed to configure: ${e.message}');
    }
  }

  @override
  Future<void> initializeTracking(String apiKey, String? baseURL) async {
    // PlatformException with code INVALID_API_KEY propagates as-is to caller.
    // Passing null lets the native SDK use its own default baseURL.
    await _channel.invokeMethod<void>('initializeTracking', {
      'trackingApiKey': apiKey,
      if (baseURL != null && baseURL.isNotEmpty) 'trackingBaseUrl': baseURL,
    });
  }

  @override
  Future<void> setMetadata(Map<String, dynamic> metadata) async {
    try {
      await _channel.invokeMethod<void>('setMetadata', {'metadata': metadata});
    } on PlatformException catch (e) {
      throw Exception('Failed to setMetadata: ${e.message}');
    }
  }

  @override
  Future<void> setPackages(List<String> packages) async {
    try {
      await _channel.invokeMethod<void>('setPackages', {'packages': packages});
    } on PlatformException catch (e) {
      throw Exception('Failed to setPackages: ${e.message}');
    }
  }

  @override
  Future<void> setAppSignature(String signature) async {
    try {
      await _channel.invokeMethod<void>('setAppSignature', {'signature': signature});
    } on PlatformException catch (e) {
      throw Exception('Failed to setAppSignature: ${e.message}');
    }
  }

  @override
  Future<bool> configureAlertAPI(String apiKey, String apiID) async {
    try {
      final args = {'apiKey': apiKey, 'apiID': apiID};
      final result = await _channel.invokeMethod<bool>(
        'configureAlertAPI',
        args,
      );
      return result ?? false;
    } on PlatformException catch (e) {
      throw Exception('Failed to configure Alert API: ${e.message}');
    }
  }

  @override
  Future<bool> setAutoUpload(bool enabled) async {
    try {
      final args = {'enabled': enabled};
      final result = await _channel.invokeMethod<bool>('setAutoUpload', args);
      return result ?? false;
    } on PlatformException catch (e) {
      throw Exception('Failed to setAutoUpload: ${e.message}');
    }
  }

  @override
  Future<bool> setSmartBatteryConfig({
    required bool enabled,
    required String preset,
  }) async {
    try {
      final result = await _channel.invokeMethod<bool>(
        'setSmartBatteryConfig',
        {'enabled': enabled, 'preset': preset},
      );
      return result ?? false;
    } on PlatformException catch (e) {
      throw Exception('Failed to setSmartBatteryConfig: ${e.message}');
    }
  }

  // ── Identifiers ──────────────────────────────────────────────

  @override
  Future<bool> setVehicleId(String vehicleId) async {
    try {
      final args = {'vehicleId': vehicleId};
      final result = await _channel.invokeMethod<bool>('setVehicleId', args);
      return result ?? false;
    } on PlatformException catch (e) {
      throw Exception('Failed to setVehicleId: ${e.message}');
    }
  }

  @override
  Future<bool> setDriverId(String driverId) async {
    try {
      final args = {'driverId': driverId};
      final result = await _channel.invokeMethod<bool>('setDriverId', args);
      return result ?? false;
    } on PlatformException catch (e) {
      throw Exception('Failed to setDriverId: ${e.message}');
    }
  }

  @override
  Future<String?> getVehicleId() async {
    try {
      return await _channel.invokeMethod<String>('getVehicleId');
    } on PlatformException catch (e) {
      throw Exception('Failed to getVehicleId: ${e.message}');
    }
  }

  @override
  Future<String?> getDriverId() async {
    try {
      return await _channel.invokeMethod<String>('getDriverId');
    } on PlatformException catch (e) {
      throw Exception('Failed to getDriverId: ${e.message}');
    }
  }

  // ── Permissions ───────────────────────────────────────────────

  @override
  Future<PermissionResult> requestLocationPermissions() async {
    try {
      final result = await _channel.invokeMethod<Map<Object?, Object?>>(
        'requestLocationPermissions',
      );
      if (result == null) {
        throw Exception('Null result from requestLocationPermissions');
      }
      return PermissionResult.fromJson(Map<String, dynamic>.from(result));
    } on PlatformException catch (e) {
      throw Exception('Failed to request permissions: ${e.message}');
    }
  }

  @override
  Future<PermissionResult> hasLocationPermissions() async {
    try {
      final result = await _channel.invokeMethod<Map<Object?, Object?>>(
        'hasLocationPermissions',
      );
      if (result == null) {
        throw Exception('Null result from hasLocationPermissions');
      }
      return PermissionResult.fromJson(Map<String, dynamic>.from(result));
    } on PlatformException catch (e) {
      throw Exception('Failed to check permissions: ${e.message}');
    }
  }

  @override
  Future<String> requestAlwaysLocationPermissions() async {
    try {
      final result = await _channel.invokeMethod<String>(
        'requestAlwaysLocationPermissions',
      );
      return result ?? 'denied';
    } on PlatformException catch (e) {
      throw Exception('Failed to request always permissions: ${e.message}');
    }
  }

  // ── Tracking ──────────────────────────────────────────────────

  @override
  Future<bool> startTracking(LocationTrackingConfig config) async {
    try {
      final args = config.toJson();
      final result = await _channel.invokeMethod<bool>('startTracking', args);
      return result ?? false;
    } on PlatformException catch (e) {
      throw Exception('Failed to start tracking: ${e.message}');
    }
  }

  @override
  Future<bool> stopTracking() async {
    try {
      final result = await _channel.invokeMethod<bool>('stopTracking');
      return result ?? false;
    } on PlatformException catch (e) {
      throw Exception('Failed to stop tracking: ${e.message}');
    }
  }

  @override
  Future<LocationData> getCurrentLocation() async {
    try {
      final result = await _channel.invokeMethod<Map<Object?, Object?>>(
        'getCurrentLocation',
      );
      if (result == null) {
        throw Exception('Null result from getCurrentLocation');
      }
      final data = Map<String, dynamic>.from(result);
      return LocationData.fromJson(data);
    } on PlatformException catch (e) {
      throw Exception('Failed to get current location: ${e.message}');
    } catch (e) {
      throw Exception('Error parsing location data: $e');
    }
  }

  @override
  Future<bool> isTrackingActive() async {
    try {
      final result = await _channel.invokeMethod<bool>('isTrackingActive');
      return result ?? false;
    } on PlatformException catch (e) {
      throw Exception('Failed to check tracking status: ${e.message}');
    }
  }

  @override
  Future<TrackingStatus> getTrackingStatus() async {
    try {
      final result = await _channel.invokeMethod<Map<Object?, Object?>>(
        'getTrackingStatus',
      );
      if (result == null) {
        throw Exception('Null result from getTrackingStatus');
      }
      return TrackingStatus.fromJson(Map<String, dynamic>.from(result));
    } on PlatformException catch (e) {
      throw Exception('Failed to get tracking status: ${e.message}');
    }
  }

  @override
  Future<bool> updateTrackingConfig(LocationTrackingConfig config) async {
    try {
      final args = config.toJson();
      final result = await _channel.invokeMethod<bool>(
        'updateTrackingConfig',
        args,
      );
      return result ?? false;
    } on PlatformException catch (e) {
      throw Exception('Failed to update tracking config: ${e.message}');
    }
  }

  @override
  Future<Map<String, dynamic>> getTrackingHealthStatus() async {
    try {
      final result = await _channel.invokeMethod<Map<Object?, Object?>>(
        'getTrackingHealthStatus',
      );
      if (result == null) {
        throw Exception('Null result from getTrackingHealthStatus');
      }
      return Map<String, dynamic>.from(result);
    } on PlatformException catch (e) {
      throw Exception('Failed to get tracking health status: ${e.message}');
    }
  }

  @override
  Future<String> getTrackingHistory({
    required String userId,
    int? fromTime,
    int? toTime,
    int pageNumber = 1,
    int pageSize = 100,
    bool sortDescending = false,
  }) async {
    try {
      final result = await _channel.invokeMethod<String>('getTrackingHistory', {
        'userId': userId,
        if (fromTime != null) 'fromTime': fromTime,
        if (toTime != null) 'toTime': toTime,
        'pageNumber': pageNumber,
        'pageSize': pageSize,
        'sortDescending': sortDescending,
      });
      if (result == null) {
        throw Exception('Null result from getTrackingHistory');
      }
      return result;
    } on PlatformException catch (e) {
      throw Exception('Failed to getTrackingHistory: ${e.message}');
    }
  }

  // ── Alert ─────────────────────────────────────────────────────

  @override
  Future<bool> turnOnAlert() async {
    try {
      final result = await _channel.invokeMethod<bool>('turnOnAlert');
      return result ?? false;
    } on PlatformException catch (e) {
      throw Exception('Failed to turn on alert: ${e.message}');
    }
  }

  @override
  Future<bool> turnOffAlert() async {
    try {
      final result = await _channel.invokeMethod<bool>('turnOffAlert');
      return result ?? false;
    } on PlatformException catch (e) {
      throw Exception('Failed to turn off alert: ${e.message}');
    }
  }

  @override
  Future<bool> isSpeedAlertActive() async {
    try {
      final result = await _channel.invokeMethod<bool>('isSpeedAlertActive');
      return result ?? false;
    } on PlatformException catch (e) {
      throw Exception('Failed to check alert status: ${e.message}');
    }
  }

  @override
  Future<bool> configureVehicle({
    required String vehicleId,
    required int vehicleType,
    required int seats,
    required double weight,
    int? maxProvision,
  }) async {
    try {
      final args = {
        'vehicleId': vehicleId,
        'vehicleType': vehicleType,
        'seats': seats,
        'weight': weight,
        if (maxProvision != null) 'maxProvision': maxProvision,
      };
      final result = await _channel.invokeMethod<bool>(
        'configureVehicle',
        args,
      );
      return result ?? false;
    } on PlatformException catch (e) {
      throw Exception('Failed to configureVehicle: ${e.message}');
    }
  }

  // ── External GPS injection ────────────────────────────────────

  @override
  Future<bool> processExternalLocation({
    required double lat,
    required double lng,
    required double speed,
    required double heading,
    double? accuracy,
    double? altitude,
    int? timestamp,
  }) async {
    try {
      final args = {
        'lat': lat,
        'lng': lng,
        'speed': speed,
        'heading': heading,
        if (accuracy != null) 'accuracy': accuracy,
        if (altitude != null) 'altitude': altitude,
        'timestamp': timestamp ?? DateTime.now().millisecondsSinceEpoch,
      };
      final result = await _channel.invokeMethod<bool>(
        'processExternalLocation',
        args,
      );
      return result ?? false;
    } on PlatformException catch (e) {
      throw Exception('Failed to processExternalLocation: ${e.message}');
    }
  }

  // ── Cache & Network ───────────────────────────────────────────

  @override
  Future<bool> isNetworkConnected() async {
    try {
      final result = await _channel.invokeMethod<bool>('isNetworkConnected');
      return result ?? false;
    } on PlatformException catch (e) {
      throw Exception('Failed to check network: ${e.message}');
    }
  }

  @override
  Future<int> getCachedLocationsCount() async {
    try {
      final result = await _channel.invokeMethod<int>(
        'getCachedLocationsCount',
      );
      return result ?? 0;
    } on PlatformException catch (e) {
      throw Exception('Failed to getCachedLocationsCount: ${e.message}');
    }
  }

  @override
  Future<bool> uploadCachedLocationsManually() async {
    try {
      final result = await _channel.invokeMethod<bool>(
        'uploadCachedLocationsManually',
      );
      return result ?? false;
    } on PlatformException catch (e) {
      throw Exception('Failed to uploadCachedLocationsManually: ${e.message}');
    }
  }

  @override
  Future<bool> clearCachedLocations() async {
    try {
      final result = await _channel.invokeMethod<bool>('clearCachedLocations');
      return result ?? false;
    } on PlatformException catch (e) {
      throw Exception('Failed to clearCachedLocations: ${e.message}');
    }
  }

  @override
  Future<bool> configureCacheLimits({
    int maxRecords = 0,
    int maxDbSizeBytes = 0,
    int batchSize = 0,
  }) async {
    try {
      final args = {
        'maxRecords': maxRecords,
        'maxDbSizeBytes': maxDbSizeBytes,
        'batchSize': batchSize,
      };
      final result = await _channel.invokeMethod<bool>(
        'configureCacheLimits',
        args,
      );
      return result ?? false;
    } on PlatformException catch (e) {
      throw Exception('Failed to configureCacheLimits: ${e.message}');
    }
  }

  @override
  Future<int> getDatabaseSizeBytes() async {
    try {
      final result = await _channel.invokeMethod<int>('getDatabaseSizeBytes');
      return result ?? 0;
    } on PlatformException catch (e) {
      throw Exception('Failed to getDatabaseSizeBytes: ${e.message}');
    }
  }

  // ── App Lifecycle ─────────────────────────────────────────────

  @override
  Future<void> onAppBackground() async {
    try {
      await _channel.invokeMethod<void>('onAppBackground');
    } on PlatformException catch (e) {
      throw Exception('Failed to notify onAppBackground: ${e.message}');
    }
  }

  @override
  Future<void> onAppForeground() async {
    try {
      await _channel.invokeMethod<void>('onAppForeground');
    } on PlatformException catch (e) {
      throw Exception('Failed to notify onAppForeground: ${e.message}');
    }
  }

  // ── Event streams ─────────────────────────────────────────────

  @override
  Stream<LocationData> get onLocationUpdate {
    return _locationUpdateChannel.receiveBroadcastStream().map((event) {
      try {
        final data = Map<String, dynamic>.from(event as Map);
        return LocationData.fromJson(data);
      } catch (e) {
        rethrow;
      }
    });
  }

  @override
  Stream<TrackingStatus> get onTrackingStatusChanged {
    return _trackingStatusChannel.receiveBroadcastStream().map((event) {
      try {
        final data = Map<String, dynamic>.from(event as Map);
        final status = TrackingStatus.fromJson(data);
        return status;
      } catch (e) {
        rethrow;
      }
    });
  }

  // ── Fake GPS ──────────────────────────────────────────────

  @override
  Future<void> setFakeGpsPolicy(String policy) async {
    // Ignore unused static field warning — it triggers handler installation.
    assert(_handlerInstalled);
    try {
      await _channel.invokeMethod<void>('setFakeGPSPolicy', {'policy': policy});
    } on PlatformException catch (e) {
      throw Exception('Failed to setFakeGpsPolicy: ${e.message}');
    }
  }

  @override
  Future<void> setFakeGpsNotificationConfig({
    required String title,
    required String message,
  }) async {
    try {
      await _channel.invokeMethod<void>(
        'setFakeGpsNotificationConfig',
        {'title': title, 'message': message},
      );
    } on PlatformException catch (e) {
      throw Exception('Failed to setFakeGpsNotificationConfig: ${e.message}');
    }
  }

  @override
  Stream<FakeGpsEvent> get onFakeGpsDetected => _fakeGpsController.stream;

  // ── Tracking interrupted ──────────────────────────────────

  @override
  Future<void> setTrackingInterruptedNotificationEnabled(bool enabled) async {
    // Ignore unused static field warning — it triggers handler installation.
    assert(_handlerInstalled);
    try {
      await _channel.invokeMethod<void>(
        'setTrackingInterruptedNotificationEnabled',
        {'enabled': enabled},
      );
    } on PlatformException catch (e) {
      throw Exception(
        'Failed to setTrackingInterruptedNotificationEnabled: ${e.message}',
      );
    }
  }

  @override
  Future<void> setTrackingInterruptedNotificationConfig({
    required String title,
    required String message,
  }) async {
    try {
      await _channel.invokeMethod<void>(
        'setTrackingInterruptedNotificationConfig',
        {'title': title, 'message': message},
      );
    } on PlatformException catch (e) {
      throw Exception(
        'Failed to setTrackingInterruptedNotificationConfig: ${e.message}',
      );
    }
  }

  @override
  Stream<TrackingInterruptedEvent> get onTrackingInterrupted =>
      _trackingInterruptedController.stream;
}
