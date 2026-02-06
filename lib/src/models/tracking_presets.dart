import 'location_tracking_config.dart';

/// Pre-configured tracking presets for common use cases
class TrackingPresets {
  /// Navigation mode - High accuracy, frequent updates
  static LocationTrackingConfig navigation({
    String? notificationTitle,
    String? notificationMessage,
  }) {
    return LocationTrackingConfig(
      intervalMs: 3000,
      distanceFilter: 5.0,
      accuracy: LocationAccuracy.high,
      backgroundMode: true,
      notificationTitle: notificationTitle ?? 'Navigation Active',
      notificationMessage: notificationMessage ?? 'Tracking your route',
    );
  }

  /// Fitness mode - Balanced accuracy and battery
  static LocationTrackingConfig fitness({
    String? notificationTitle,
    String? notificationMessage,
  }) {
    return LocationTrackingConfig(
      intervalMs: 5000,
      distanceFilter: 10.0,
      accuracy: LocationAccuracy.high,
      backgroundMode: true,
      notificationTitle: notificationTitle ?? 'Fitness Tracking',
      notificationMessage: notificationMessage ?? 'Recording your activity',
    );
  }

  /// General tracking - Medium accuracy, standard updates
  static LocationTrackingConfig general({
    String? notificationTitle,
    String? notificationMessage,
  }) {
    return LocationTrackingConfig(
      intervalMs: 10000,
      distanceFilter: 15.0,
      accuracy: LocationAccuracy.medium,
      backgroundMode: true,
      notificationTitle: notificationTitle ?? 'Location Tracking',
      notificationMessage: notificationMessage ?? 'Tracking your location',
    );
  }

  /// Battery saver - Lower accuracy, less frequent updates
  static LocationTrackingConfig batterySaver({
    String? notificationTitle,
    String? notificationMessage,
  }) {
    return LocationTrackingConfig(
      intervalMs: 30000,
      distanceFilter: 50.0,
      accuracy: LocationAccuracy.low,
      backgroundMode: true,
      notificationTitle: notificationTitle ?? 'Location Tracking',
      notificationMessage: notificationMessage ?? 'Battery saver mode',
    );
  }
}
