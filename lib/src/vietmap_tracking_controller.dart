import 'dart:async';
import 'models/location_tracking_config.dart';
import 'models/location_data.dart';
import 'models/tracking_status.dart';
import 'models/permission_result.dart';
import 'platform/vietmap_tracking_platform_interface.dart';

/// Main controller for Vietmap Tracking Plugin
class VietmapTrackingController {
  VietmapTrackingController._();

  static final VietmapTrackingController instance =
      VietmapTrackingController._();

  final _platform = VietmapTrackingPlatform.instance;

  // Configuration state
  bool _isConfigured = false;
  bool get isConfigured => _isConfigured;

  /// Configure VietmapTrackingSDK with API key
  ///
  /// Must be called before using any tracking features.
  ///
  /// [apiKey] - API key for VietmapTrackingSDK
  /// [baseURL] - Optional base URL for the API
  ///
  /// Returns [true] if configuration was successful
  Future<bool> configure(String apiKey, {String? baseURL}) async {
    try {
      final result = await _platform.configure(apiKey, baseURL);
      _isConfigured = result;
      return result;
    } catch (e) {
      print('Failed to configure VietmapTrackingSDK: $e');
      return false;
    }
  }

  /// Configure Alert API for speed monitoring
  ///
  /// [apiKey] - API key for Alert API
  /// [apiID] - API ID for Alert API
  ///
  /// Returns [true] if configuration was successful
  Future<bool> configureAlertAPI(String apiKey, String apiID) async {
    if (!_isConfigured) {
      throw Exception(
        'VietmapTrackingSDK not configured. Call configure() first.',
      );
    }

    try {
      return await _platform.configureAlertAPI(apiKey, apiID);
    } catch (e) {
      print('Failed to configure Alert API: $e');
      return false;
    }
  }

  /// Request location permissions from the user
  ///
  /// Returns [PermissionResult] with detailed permission status
  Future<PermissionResult> requestLocationPermissions() async {
    try {
      return await _platform.requestLocationPermissions();
    } catch (e) {
      print('Failed to request location permissions: $e');
      rethrow;
    }
  }

  /// Check if location permissions are granted
  ///
  /// Returns [PermissionResult] with current permission status
  Future<PermissionResult> hasLocationPermissions() async {
    try {
      return await _platform.hasLocationPermissions();
    } catch (e) {
      print('Failed to check location permissions: $e');
      rethrow;
    }
  }

  /// Request "Always" location permissions (required for background tracking)
  ///
  /// Returns permission status string: 'granted', 'denied', etc.
  Future<String> requestAlwaysLocationPermissions() async {
    try {
      return await _platform.requestAlwaysLocationPermissions();
    } catch (e) {
      print('Failed to request always permissions: $e');
      return 'denied';
    }
  }

  /// Start GPS location tracking with specified configuration
  ///
  /// Automatically requests permissions if not granted.
  ///
  /// [config] - Configuration for location tracking
  ///
  /// Returns [true] if tracking started successfully
  Future<bool> startTracking(LocationTrackingConfig config) async {
    if (!_isConfigured) {
      throw Exception(
        'VietmapTrackingSDK not configured. Call configure() first.',
      );
    }

    try {
      // Check and request permissions
      final hasPermissions = await hasLocationPermissions();
      if (!hasPermissions.granted) {
        final requestResult = await requestLocationPermissions();
        if (!requestResult.granted) {
          throw Exception('Location permissions not granted');
        }
      }

      return await _platform.startTracking(config);
    } catch (e) {
      print('Failed to start tracking: $e');
      rethrow;
    }
  }

  /// Stop GPS location tracking
  ///
  /// Returns [true] if tracking stopped successfully
  Future<bool> stopTracking() async {
    try {
      return await _platform.stopTracking();
    } catch (e) {
      print('Failed to stop tracking: $e');
      return false;
    }
  }

  /// Get current location immediately (one-time fetch)
  ///
  /// Returns [LocationData] with current GPS coordinates
  Future<LocationData> getCurrentLocation() async {
    if (!_isConfigured) {
      throw Exception(
        'VietmapTrackingSDK not configured. Call configure() first.',
      );
    }

    try {
      return await _platform.getCurrentLocation();
    } catch (e) {
      print('Failed to get current location: $e');
      rethrow;
    }
  }

  /// Check if location tracking is currently active
  ///
  /// Returns [true] if tracking is active
  Future<bool> isTrackingActive() async {
    try {
      return await _platform.isTrackingActive();
    } catch (e) {
      print('Failed to check tracking status: $e');
      return false;
    }
  }

  /// Get detailed tracking status information
  ///
  /// Returns [TrackingStatus] with detailed status info
  Future<TrackingStatus> getTrackingStatus() async {
    try {
      return await _platform.getTrackingStatus();
    } catch (e) {
      print('Failed to get tracking status: $e');
      rethrow;
    }
  }

  /// Update tracking configuration while tracking is active
  ///
  /// [config] - New configuration to apply
  ///
  /// Returns [true] if update was successful
  Future<bool> updateTrackingConfig(LocationTrackingConfig config) async {
    try {
      return await _platform.updateTrackingConfig(config);
    } catch (e) {
      print('Failed to update tracking config: $e');
      return false;
    }
  }

  /// Stream of location updates
  ///
  /// Subscribe to receive real-time location updates while tracking
  Stream<LocationData> get onLocationUpdate => _platform.onLocationUpdate;

  /// Stream of tracking status changes
  ///
  /// Subscribe to receive tracking status updates
  Stream<TrackingStatus> get onTrackingStatusChanged =>
      _platform.onTrackingStatusChanged;
}
