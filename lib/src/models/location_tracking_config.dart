/// Configuration for location tracking
class LocationTrackingConfig {
  /// Interval between location updates in milliseconds. Optional, SDK default used if null.
  final int? intervalMs;

  /// Minimum distance between location updates in meters. Optional, SDK default used if null.
  final double? distanceFilter;

  /// Desired accuracy level: 'high', 'medium', or 'low'. Optional.
  final LocationAccuracy? accuracy;

  /// Whether to continue tracking in background
  final bool backgroundMode;

  /// Custom notification title for foreground service (Android)
  final String? notificationTitle;

  /// Custom notification message for foreground service (Android)
  final String? notificationMessage;

  /// User ID for tracking identification (mapped to driverId in native SDKs)
  final String? userId;

  /// Vehicle ID for tracking identification. Optional.
  final String? vehicleId;

  /// API endpoint for sending tracking data
  final String? apiEndpoint;

  /// Whether to allow mock/fake locations. If true (default), fake GPS passes through.
  /// Set to false and call [VietmapTrackingController.setFakeGpsPolicy] to enable detection.
  final bool allowMockLocation;

  /// Whether to derive speed from Haversine distance/time when the OS omits speed
  /// (e.g. network/fused fixes on Xiaomi/MIUI report speed = 0 / -1). Default true.
  /// Set to false to always report the raw OS speed.
  final bool enableSpeedFallback;

  const LocationTrackingConfig({
    this.intervalMs,
    this.distanceFilter,
    this.accuracy,
    this.backgroundMode = true,
    this.notificationTitle,
    this.notificationMessage,
    this.userId,
    this.vehicleId,
    this.apiEndpoint,
    this.allowMockLocation = true,
    this.enableSpeedFallback = true,
  });

  /// Convert to JSON for platform channel
  Map<String, dynamic> toJson() => {
    'intervalMs': intervalMs,
    'distanceFilter': distanceFilter,
    'accuracy': accuracy?.value,
    'backgroundMode': backgroundMode,
    'notificationTitle': notificationTitle,
    'notificationMessage': notificationMessage,
    'userId': userId,
    'vehicleId': vehicleId,
    'apiEndpoint': apiEndpoint,
    'allowMockLocation': allowMockLocation,
    'enableSpeedFallback': enableSpeedFallback,
  };

  /// Create from JSON
  factory LocationTrackingConfig.fromJson(Map<String, dynamic> json) {
    return LocationTrackingConfig(
      intervalMs: json['intervalMs'] as int?,
      distanceFilter: (json['distanceFilter'] as num?)?.toDouble(),
      accuracy: json['accuracy'] != null ? LocationAccuracy.fromString(json['accuracy'] as String) : null,
      backgroundMode: json['backgroundMode'] as bool? ?? true,
      notificationTitle: json['notificationTitle'] as String?,
      notificationMessage: json['notificationMessage'] as String?,
      userId: json['userId'] as String?,
      vehicleId: json['vehicleId'] as String?,
      apiEndpoint: json['apiEndpoint'] as String?,
      allowMockLocation: json['allowMockLocation'] as bool? ?? true,
      enableSpeedFallback: json['enableSpeedFallback'] as bool? ?? true,
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
    String? userId,
    String? vehicleId,
    String? apiEndpoint,
    bool? allowMockLocation,
    bool? enableSpeedFallback,
  }) {
    return LocationTrackingConfig(
      intervalMs: intervalMs ?? this.intervalMs,
      distanceFilter: distanceFilter ?? this.distanceFilter,
      accuracy: accuracy ?? this.accuracy,
      backgroundMode: backgroundMode ?? this.backgroundMode,
      notificationTitle: notificationTitle ?? this.notificationTitle,
      notificationMessage: notificationMessage ?? this.notificationMessage,
      userId: userId ?? this.userId,
      vehicleId: vehicleId ?? this.vehicleId,
      apiEndpoint: apiEndpoint ?? this.apiEndpoint,
      allowMockLocation: allowMockLocation ?? this.allowMockLocation,
      enableSpeedFallback: enableSpeedFallback ?? this.enableSpeedFallback,
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
