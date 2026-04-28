import 'dart:typed_data';

// ---------------------------------------------------------------------------
// AuthMode
// ---------------------------------------------------------------------------

/// How API credentials are sent with every tracking request.
enum AuthMode {
  /// Credentials are sent as HTTP headers (e.g. `Authorization: Bearer …`).
  header,

  /// Credentials are appended to the request URL as query parameters.
  queryParam,
}

// ---------------------------------------------------------------------------
// VehicleType constants
// ---------------------------------------------------------------------------

/// Integer constants that match the `VMVehicleType` enum in the native SDK.
abstract final class VehicleType {
  static const int car        = 1;
  static const int taxi       = 2;
  static const int bus        = 3;
  static const int coach      = 4;
  static const int truck      = 5;
  static const int trailer    = 6;
  static const int cycle      = 7;
  static const int bike       = 8;
  static const int pedestrian = 9;
  static const int semiTrailer = 10;
}

// ---------------------------------------------------------------------------
// SpeedSignEvent
// ---------------------------------------------------------------------------

/// A speed-sign event pushed by the native SDK when a speed-limit zone is
/// entered or the current speed-limit changes.
///
/// [imageBytes] carries a PNG-encoded bitmap (Android converts from BMP;
/// iOS converts from raw BGRA bytes) of the sign image, or `null` when the
/// native layer could not produce an image.
///
/// [speedLimit] is the numeric speed limit in km/h, or `null` when unavailable.
class SpeedSignEvent {
  final Uint8List? imageBytes;
  final int?       speedLimit;
  final String?    signType;
  final int        timestamp;

  const SpeedSignEvent({
    this.imageBytes,
    this.speedLimit,
    this.signType,
    required this.timestamp,
  });

  factory SpeedSignEvent.fromMap(Map<Object?, Object?> map) {
    Uint8List? bytes;
    final raw = map['imageBytes'];
    if (raw is Uint8List) {
      bytes = raw;
    } else if (raw is List) {
      bytes = Uint8List.fromList(raw.cast<int>());
    }
    return SpeedSignEvent(
      imageBytes: bytes,
      speedLimit: (map['speedLimit'] as num?)?.toInt(),
      signType:   map['signType']  as String?,
      timestamp:  (map['timestamp'] as num?)?.toInt() ??
                  DateTime.now().millisecondsSinceEpoch,
    );
  }

  @override
  String toString() =>
      'SpeedSignEvent(speedLimit=$speedLimit, signType=$signType, '
      'hasImage=${imageBytes != null}, ts=$timestamp)';
}

// ---------------------------------------------------------------------------
// LocationUpdateEvent
// ---------------------------------------------------------------------------

/// A location point forwarded from the native SDK's GPS pipeline.
class LocationUpdateEvent {
  final double latitude;
  final double longitude;
  final double altitude;
  final double accuracy;
  final double speed;    // m/s
  final double heading;  // 0–360°, 0 = North
  final int    timestamp; // Unix ms

  const LocationUpdateEvent({
    required this.latitude,
    required this.longitude,
    this.altitude = 0.0,
    this.accuracy = 0.0,
    this.speed    = 0.0,
    this.heading  = 0.0,
    required this.timestamp,
  });

  factory LocationUpdateEvent.fromMap(Map<Object?, Object?> map) {
    double readDouble(String k1, [String? k2]) =>
        ((map[k1] ?? (k2 != null ? map[k2] : null)) as num?)?.toDouble() ?? 0.0;

    return LocationUpdateEvent(
      latitude:  readDouble('latitude',  'lat'),
      longitude: readDouble('longitude', 'lng'),
      altitude:  readDouble('altitude'),
      accuracy:  readDouble('accuracy'),
      speed:     readDouble('speed'),
      heading:   readDouble('heading',  'bearing'),
      timestamp: (map['timestamp'] as num?)?.toInt() ??
                 DateTime.now().millisecondsSinceEpoch,
    );
  }

  DateTime get dateTime =>
      DateTime.fromMillisecondsSinceEpoch(timestamp);

  @override
  String toString() =>
      'LocationUpdateEvent(lat=$latitude, lng=$longitude, speed=$speed, '
      'heading=$heading, ts=$timestamp)';
}

// ---------------------------------------------------------------------------
// TrackingStatusEvent
// ---------------------------------------------------------------------------

/// A status notification from the SDK, emitted when tracking starts/stops,
/// when a permission changes, or when an error occurs.
class TrackingStatusEvent {
  final bool   isTracking;
  final String status;
  final String? message;
  final int    timestamp;

  const TrackingStatusEvent({
    required this.isTracking,
    this.status   = 'unknown',
    this.message,
    required this.timestamp,
  });

  factory TrackingStatusEvent.fromMap(Map<Object?, Object?> map) {
    final isTracking = map['isTracking'] as bool? ?? false;
    return TrackingStatusEvent(
      isTracking: isTracking,
      status:     map['status']  as String? ?? (isTracking ? 'tracking' : 'stopped'),
      message:    map['message'] as String?,
      timestamp:  (map['timestamp'] as num?)?.toInt() ??
                  DateTime.now().millisecondsSinceEpoch,
    );
  }

  @override
  String toString() =>
      'TrackingStatusEvent(isTracking=$isTracking, status=$status, '
      'message=$message, ts=$timestamp)';
}
