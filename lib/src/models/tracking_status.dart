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
      isTracking: json['isTracking'] as bool? ?? false,
      lastLocationUpdate: (json['lastLocationUpdate'] as num?)?.toInt(),
      trackingDuration: (json['trackingDuration'] as num?)?.toInt() ?? 0,
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
