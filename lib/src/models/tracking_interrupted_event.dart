/// Model for tracking-interrupted events emitted by the native SDK.
///
/// Fired when background tracking is interrupted (GPS stops pushing / location
/// unavailable / provider off / permission downgraded) or recovers, while
/// tracking is active. Use it to prompt the user to re-activate tracking
/// (stop + start). The payload is an SDK-owned contract: the app CAN configure
/// the local-notification title/body, but CANNOT configure this channel message.
class TrackingInterruptedEvent {
  /// SDK-owned reason. One of [TrackingInterruptedReason].
  final String reason;

  /// True when location became available again (interruption cleared).
  final bool recovered;

  /// Whether the app was in background when the event fired.
  final bool isInBackground;

  /// Seconds since the last raw GPS fix (-1 if unknown).
  final int secondsSinceLastFix;

  const TrackingInterruptedEvent({
    required this.reason,
    required this.recovered,
    required this.isInBackground,
    required this.secondsSinceLastFix,
  });

  factory TrackingInterruptedEvent.fromMap(Map<Object?, Object?> map) {
    return TrackingInterruptedEvent(
      reason: (map['reason'] as String?) ?? 'unknown',
      recovered: (map['recovered'] as bool?) ?? false,
      isInBackground: (map['isInBackground'] as bool?) ?? false,
      secondsSinceLastFix: (map['secondsSinceLastFix'] as num?)?.toInt() ?? -1,
    );
  }

  @override
  String toString() =>
      'TrackingInterruptedEvent(reason=$reason, recovered=$recovered, '
      'isInBackground=$isInBackground, secondsSinceLastFix=$secondsSinceLastFix)';
}

/// SDK-owned reason constants carried by [TrackingInterruptedEvent.reason].
/// These are fixed by the SDK and cannot be configured by the app.
class TrackingInterruptedReason {
  TrackingInterruptedReason._();

  /// Location became unavailable (FusedLocationProvider `onLocationAvailability(false)`
  /// on Android; equivalent conditions on iOS).
  static const String locationUnavailable = 'locationUnavailable';

  /// The GPS/location provider was turned off.
  static const String providerDisabled = 'providerDisabled';

  /// iOS: the OS paused location updates (deemed stationary).
  static const String paused = 'paused';

  /// iOS: location permission downgraded Always → When-In-Use.
  static const String authDowngraded = 'authDowngraded';

  /// iOS: location permission denied/restricted.
  static const String authDenied = 'authDenied';

  /// Location services turned off entirely.
  static const String locationServicesOff = 'locationServicesOff';

  /// Location permission revoked (Android).
  static const String permissionRevoked = 'permissionRevoked';

  /// Backstop: no raw GPS fix for a while while tracking in background.
  static const String staleNoUpdates = 'staleNoUpdates';
}
