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
    // Fix: Convert num to int safely (handle both int and double from native)
    final durationValue = json['trackingDuration'];
    final duration = durationValue is int 
      ? durationValue 
      : (durationValue is double ? durationValue.toInt() : 0);
    
    final lastUpdateValue = json['lastLocationUpdate'];
    final lastUpdate = lastUpdateValue is int
      ? lastUpdateValue
      : (lastUpdateValue is double ? lastUpdateValue.toInt() : null);
    
    return TrackingStatus(
      isTracking: json['isTracking'] as bool? ?? false,
      lastLocationUpdate: lastUpdate,
      trackingDuration: duration,
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
