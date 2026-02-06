/// Configuration for location tracking
class LocationTrackingConfig {
  /// Interval between location updates in milliseconds
  final int intervalMs;

  /// Minimum distance between location updates in meters
  final double distanceFilter;

  /// Desired accuracy level: 'high', 'medium', or 'low'
  final LocationAccuracy accuracy;

  /// Whether to continue tracking in background
  final bool backgroundMode;

  /// Custom notification title for foreground service (Android)
  final String? notificationTitle;

  /// Custom notification message for foreground service (Android)
  final String? notificationMessage;

  const LocationTrackingConfig({
    required this.intervalMs,
    required this.distanceFilter,
    required this.accuracy,
    required this.backgroundMode,
    this.notificationTitle,
    this.notificationMessage,
  });

  /// Convert to JSON for platform channel
  Map<String, dynamic> toJson() => {
    'intervalMs': intervalMs,
    'distanceFilter': distanceFilter,
    'accuracy': accuracy.value,
    'backgroundMode': backgroundMode,
    'notificationTitle': notificationTitle,
    'notificationMessage': notificationMessage,
  };

  /// Create from JSON
  factory LocationTrackingConfig.fromJson(Map<String, dynamic> json) {
    return LocationTrackingConfig(
      intervalMs: json['intervalMs'] as int,
      distanceFilter: (json['distanceFilter'] as num).toDouble(),
      accuracy: LocationAccuracy.fromString(json['accuracy'] as String),
      backgroundMode: json['backgroundMode'] as bool,
      notificationTitle: json['notificationTitle'] as String?,
      notificationMessage: json['notificationMessage'] as String?,
    );
  }

  /// Create a copy with optional parameter changes
  LocationTrackingConfig copyWith({
    int? intervalMs,
    double? distanceFilter,
    LocationAccuracy? accuracy,
    bool? backgroundMode,
    String? notificationTitle,
    String? notificationMessage,
  }) {
    return LocationTrackingConfig(
      intervalMs: intervalMs ?? this.intervalMs,
      distanceFilter: distanceFilter ?? this.distanceFilter,
      accuracy: accuracy ?? this.accuracy,
      backgroundMode: backgroundMode ?? this.backgroundMode,
      notificationTitle: notificationTitle ?? this.notificationTitle,
      notificationMessage: notificationMessage ?? this.notificationMessage,
    );
  }
}

/// GPS accuracy levels
enum LocationAccuracy {
  high('high'),
  medium('medium'),
  low('low');

  final String value;

  const LocationAccuracy(this.value);

  static LocationAccuracy fromString(String value) {
    return LocationAccuracy.values.firstWhere(
      (e) => e.value == value,
      orElse: () => LocationAccuracy.high,
    );
  }
}
