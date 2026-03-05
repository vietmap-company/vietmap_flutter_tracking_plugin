/// Represents GPS location data
class LocationData {
  final double latitude;
  final double longitude;
  final double altitude;
  final double accuracy;
  final double speed;
  final double bearing;
  final int timestamp;

  const LocationData({
    required this.latitude,
    required this.longitude,
    required this.altitude,
    required this.accuracy,
    required this.speed,
    required this.bearing,
    required this.timestamp,
  });

  /// Create from JSON received from platform channel
  factory LocationData.fromJson(Map<String, dynamic> json) {
    return LocationData(
      latitude: (json['latitude'] as num).toDouble(),
      longitude: (json['longitude'] as num).toDouble(),
      altitude: (json['altitude'] as num).toDouble(),
      accuracy: (json['accuracy'] as num).toDouble(),
      speed: (json['speed'] as num).toDouble(),
      bearing: (json['bearing'] as num).toDouble(),
      timestamp: json['timestamp'] as int,
    );
  }

  /// Convert to JSON
  Map<String, dynamic> toJson() => {
    'latitude': latitude,
    'longitude': longitude,
    'altitude': altitude,
    'accuracy': accuracy,
    'speed': speed,
    'bearing': bearing,
    'timestamp': timestamp,
  };

  /// Get DateTime from timestamp
  DateTime get dateTime => DateTime.fromMillisecondsSinceEpoch(timestamp);

  @override
  String toString() {
    return 'LocationData(lat: $latitude, lng: $longitude, accuracy: $accuracy, speed: $speed)';
  }
}
