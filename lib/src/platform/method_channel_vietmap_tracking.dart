import 'package:flutter/services.dart';
import 'vietmap_tracking_platform_interface.dart';
import '../models/location_tracking_config.dart';
import '../models/location_data.dart';
import '../models/tracking_status.dart';
import '../models/permission_result.dart';

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

  @override
  Future<bool> configure(String apiKey, String? baseURL) async {
    try {
      final result = await _channel.invokeMethod<bool>('configure', {
        'apiKey': apiKey,
        'baseURL': baseURL,
      });
      return result ?? false;
    } on PlatformException catch (e) {
      throw Exception('Failed to configure: ${e.message}');
    }
  }

  @override
  Future<bool> configureAlertAPI(String apiKey, String apiID) async {
    try {
      final result = await _channel.invokeMethod<bool>('configureAlertAPI', {
        'apiKey': apiKey,
        'apiID': apiID,
      });
      return result ?? false;
    } on PlatformException catch (e) {
      throw Exception('Failed to configure Alert API: ${e.message}');
    }
  }

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

  @override
  Future<bool> startTracking(LocationTrackingConfig config) async {
    try {
      final result = await _channel.invokeMethod<bool>(
        'startTracking',
        config.toJson(),
      );
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
      return LocationData.fromJson(Map<String, dynamic>.from(result));
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
      final result = await _channel.invokeMethod<bool>(
        'updateTrackingConfig',
        config.toJson(),
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
}
