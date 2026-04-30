/// Model for fake GPS detection events emitted by native SDK.
///
/// Native debounces at 30s — at most one event per 30-second window.
/// [isFirstDetection] = true indicates the first detection in the current window.
class FakeGpsEvent {
  /// Latitude of the detected fake location.
  final double lat;

  /// Longitude of the detected fake location.
  final double lng;

  /// Unix epoch in seconds.
  final double timestamp;

  /// True if this is the first detection in the current 30-second debounce window.
  final bool isFirstDetection;

  /// iOS only: "simulatedBySoftware" | "producedByAccessory".
  /// Always null on Android.
  final String? reason;

  const FakeGpsEvent({
    required this.lat,
    required this.lng,
    required this.timestamp,
    required this.isFirstDetection,
    this.reason,
  });

  factory FakeGpsEvent.fromMap(Map<Object?, Object?> map) {
    return FakeGpsEvent(
      lat: (map['lat'] as num?)?.toDouble() ?? 0.0,
      lng: (map['lng'] as num?)?.toDouble() ?? 0.0,
      timestamp: (map['timestamp'] as num?)?.toDouble() ??
          (DateTime.now().millisecondsSinceEpoch / 1000.0),
      isFirstDetection: (map['isFirstDetection'] as bool?) ?? true,
      reason: map['reason'] as String?,
    );
  }

  @override
  String toString() =>
      'FakeGpsEvent(lat=$lat, lng=$lng, isFirst=$isFirstDetection, reason=$reason)';
}

/// Policy constants for [VietmapTrackingController.setFakeGpsPolicy].
class FakeGpsPolicy {
  FakeGpsPolicy._();

  /// Detect fake GPS, but do not warn/stop/upload. **Default.**
  static const String skip = 'skip';

  /// Display a local notification warning the user (debounced 30s by native).
  ///
  /// Android: requires `POST_NOTIFICATIONS` permission on API 33+.
  /// iOS: requires `UNUserNotificationCenter.requestAuthorization()` beforehand.
  static const String warn = 'warn';

  /// Stop tracking immediately when fake GPS is first detected.
  static const String stopTracking = 'stopTracking';

  /// Save the location to the DB with `is_fake=1` and upload with header
  /// `X-Fake-GPS: true`. Native deduplicates: only writes if >60s or >5m
  /// from the previous fake record.
  static const String logToServer = 'logToServer';

  static const List<String> values = [skip, warn, stopTracking, logToServer];
}
