/// Represents GPS location data
class LocationData {
  final double latitude;
  final double longitude;
  final double altitude;
  final double accuracy;
  final double speed;
  final double heading;
  final int timestamp;
  final Map<String, dynamic>? metaData;

  const LocationData({
    required this.latitude,
    required this.longitude,
    required this.altitude,
    required this.accuracy,
    required this.speed,
    required this.heading,
    required this.timestamp,
    this.metaData,
  });

  /// Create from JSON received from platform channel.
  /// Accepts both SDK-new keys (`lat`/`lng`/`time`) and legacy keys (`latitude`/`longitude`/`timestamp`).
  factory LocationData.fromJson(Map<String, dynamic> json) {
    final timeMs = (json['time'] as num?)?.toInt() ?? 
                   (json['timestamp'] as num?)?.toInt() ?? 
                   DateTime.now().millisecondsSinceEpoch;
    
    return LocationData(
      latitude: (json['lat'] as num?)?.toDouble()
             ?? (json['latitude'] as num?)?.toDouble()
             ?? 0.0,
      longitude: (json['lng'] as num?)?.toDouble()
              ?? (json['longitude'] as num?)?.toDouble()
              ?? 0.0,
      altitude: (json['altitude'] as num?)?.toDouble() ?? 0.0,
      accuracy: (json['accuracy'] as num?)?.toDouble() ?? 0.0,
      speed: (json['speed'] as num?)?.toDouble() ?? 0.0,
      heading: (json['heading'] as num?)?.toDouble()
        ?? (json['bearing'] as num?)?.toDouble()
        ?? 0.0,
      timestamp: timeMs,
      metaData: json['metaData'] is Map ? Map<String, dynamic>.from(json['metaData'] as Map) : null,
    );
  }

  /// Convert to JSON following new SDK contract.
  /// - time: Unix milliseconds (replaces timestamp)
  /// - lat/lng: rounded to 12 decimal places
  /// - speed: converted to int, clamped to 0..32767
  /// - metaData: JSON object (if present)
  /// Note: accuracy, altitude, status excluded from API payload (backend doesn't use them)
  Map<String, dynamic> toJson() => {
    'lat': _roundDouble(latitude, 12),
    'lng': _roundDouble(longitude, 12),
    'speed': _clampSpeed(speed),
    'heading': heading,
    'time': timestamp,
    if (metaData != null) 'metaData': metaData,
  };

  /// Round double to N decimal places.
  static double _roundDouble(double value, int decimals) {
    final factor10 = _pow10(decimals);
    return (value * factor10).round() / factor10;
  }

  static int _pow10(int n) {
    int result = 1;
    for (int i = 0; i < n; i++) {
      result *= 10;
    }
    return result;
  }

  /// Convert speed (m/s) to int, clamped to 0..32767.
  static int _clampSpeed(double speedMs) {
    final speedInt = speedMs.toInt();
    return speedInt < 0 ? 0 : (speedInt > 32767 ? 32767 : speedInt);
  }

  /// Get DateTime from timestamp
  DateTime get dateTime => DateTime.fromMillisecondsSinceEpoch(timestamp);

  @override
  String toString() {
    return 'LocationData(lat: $latitude, lng: $longitude, accuracy: $accuracy, speed: $speed, time: $timestamp)';
  }
}
