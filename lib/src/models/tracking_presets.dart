import 'location_tracking_config.dart';

/// Pre-configured tracking presets for common use cases.
///
/// ## Tracking modes
///
/// All presets use **interval-based** tracking by default (`distanceFilter` is
/// `null`). The native SDK fires a location update every [intervalMs]
/// milliseconds, regardless of how far the device has moved.
///
/// To switch to **distance-based** tracking use the `*Distance` variants. The
/// SDK fires a location update only after the device has moved at least
/// [distanceFilter] metres, regardless of elapsed time.
///
/// ### Android
/// - Interval mode → `FusedLocationProviderClient` with
///   `LocationRequest.setInterval(intervalMs)` and no displacement filter.
/// - Distance mode → same client with
///   `LocationRequest.setSmallestDisplacement(distanceFilter)` and a large
///   interval ceiling (60 s) so the OS batches correctly.
///
/// ### iOS
/// - Interval mode → `CLLocationManager` fires `didUpdateLocations`; the
///   bridge timestamps each fix and skips ones that arrive too soon
///   (< intervalMs since the last accepted fix).
/// - Distance mode → `CLLocationManager.distanceFilter` is set to
///   [distanceFilter]; `desiredAccuracy` is tuned per preset.
class TrackingPresets {
  // ── Interval-based presets (default) ────────────────────────────────────

  /// High-accuracy, timer-driven updates every 3 seconds.
  /// Suitable for turn-by-turn navigation and real-time vehicle tracking.
  static LocationTrackingConfig navigation({
    String? notificationTitle,
    String? notificationMessage,
  }) {
    return LocationTrackingConfig(
      intervalMs: 5000,
      distanceFilter: null,
      accuracy: LocationAccuracy.high,
      backgroundMode: true,
      notificationTitle: notificationTitle ?? 'Navigation Active',
      notificationMessage: notificationMessage ?? 'Tracking your route',
    );
  }

  /// Balanced accuracy, timer-driven updates every 5 seconds.
  /// Suitable for outdoor fitness activities (running, cycling).
  static LocationTrackingConfig fitness({
    String? notificationTitle,
    String? notificationMessage,
  }) {
    return LocationTrackingConfig(
      intervalMs: 10000,
      distanceFilter: null,
      accuracy: LocationAccuracy.high,
      backgroundMode: true,
      notificationTitle: notificationTitle ?? 'Fitness Tracking',
      notificationMessage: notificationMessage ?? 'Recording your activity',
    );
  }

  /// Medium accuracy, timer-driven updates every 10 seconds.
  /// Good default for most fleet or delivery tracking scenarios.
  static LocationTrackingConfig general({
    String? notificationTitle,
    String? notificationMessage,
  }) {
    return LocationTrackingConfig(
      intervalMs: 30000,
      distanceFilter: null,
      accuracy: LocationAccuracy.medium,
      backgroundMode: true,
      notificationTitle: notificationTitle ?? 'Location Tracking',
      notificationMessage: notificationMessage ?? 'Tracking your location',
    );
  }

  /// Low accuracy, timer-driven updates every 5 minutes.
  /// Minimises battery consumption; suitable for slow-moving assets.
  static LocationTrackingConfig batterySaver({
    String? notificationTitle,
    String? notificationMessage,
  }) {
    return LocationTrackingConfig(
      intervalMs: 300000,
      distanceFilter: null,
      accuracy: LocationAccuracy.low,
      backgroundMode: true,
      notificationTitle: notificationTitle ?? 'Location Tracking',
      notificationMessage: notificationMessage ?? 'Battery saver mode',
    );
  }

  // ── Distance-based presets ───────────────────────────────────────────────

  /// Updates only after the device has moved at least 5 metres.
  /// Use when you need dense point clouds along a route regardless of speed.
  static LocationTrackingConfig navigationDistance({
    String? notificationTitle,
    String? notificationMessage,
  }) {
    return LocationTrackingConfig(
      intervalMs: null,
      distanceFilter: 5.0,
      accuracy: LocationAccuracy.high,
      backgroundMode: true,
      notificationTitle: notificationTitle ?? 'Navigation Active',
      notificationMessage: notificationMessage ?? 'Tracking your route',
    );
  }

  /// Updates only after the device has moved at least 10 metres.
  static LocationTrackingConfig fitnessDistance({
    String? notificationTitle,
    String? notificationMessage,
  }) {
    return LocationTrackingConfig(
      intervalMs: null,
      distanceFilter: 10.0,
      accuracy: LocationAccuracy.high,
      backgroundMode: true,
      notificationTitle: notificationTitle ?? 'Fitness Tracking',
      notificationMessage: notificationMessage ?? 'Recording your activity',
    );
  }

  /// Updates only after the device has moved at least 30 metres.
  static LocationTrackingConfig generalDistance({
    String? notificationTitle,
    String? notificationMessage,
  }) {
    return LocationTrackingConfig(
      intervalMs: null,
      distanceFilter: 30.0,
      accuracy: LocationAccuracy.medium,
      backgroundMode: true,
      notificationTitle: notificationTitle ?? 'Location Tracking',
      notificationMessage: notificationMessage ?? 'Tracking your location',
    );
  }

  /// Updates only after the device has moved at least 100 metres.
  /// Best battery conservation for slow or parked assets.
  static LocationTrackingConfig batterySaverDistance({
    String? notificationTitle,
    String? notificationMessage,
  }) {
    return LocationTrackingConfig(
      intervalMs: null,
      distanceFilter: 100.0,
      accuracy: LocationAccuracy.low,
      backgroundMode: true,
      notificationTitle: notificationTitle ?? 'Location Tracking',
      notificationMessage: notificationMessage ?? 'Battery saver mode',
    );
  }
}
