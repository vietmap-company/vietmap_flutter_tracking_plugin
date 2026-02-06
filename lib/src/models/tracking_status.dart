/// Tracking status information
class TrackingStatus {
  final bool isTracking;
  final int? lastLocationUpdate;
  final int trackingDuration;

  const TrackingStatus({
    required this.isTracking,
    this.lastLocationUpdate,
    required this.trackingDuration,
  });

  factory TrackingStatus.fromJson(Map<String, dynamic> json) {
    return TrackingStatus(
      isTracking: json['isTracking'] as bool,
      lastLocationUpdate: json['lastLocationUpdate'] as int?,
      trackingDuration: json['trackingDuration'] as int,
    );
  }

  Map<String, dynamic> toJson() => {
    'isTracking': isTracking,
    'lastLocationUpdate': lastLocationUpdate,
    'trackingDuration': trackingDuration,
  };

  DateTime? get lastUpdateTime => lastLocationUpdate != null
      ? DateTime.fromMillisecondsSinceEpoch(lastLocationUpdate!)
      : null;

  Duration get duration => Duration(milliseconds: trackingDuration);
}
