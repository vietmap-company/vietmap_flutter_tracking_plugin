import 'dart:async';

import 'package:flutter/services.dart';

import 'src/models.dart';

export 'src/models.dart';

/// Simple, focused Flutter API that wraps **both** native SDKs:
/// - `VietmapTrackingSDK` — GPS tracking, history, cache management.
/// - `VietmapAlertBridge` / `VietmapSpeedAlertManager` — speed-sign images,
///   TTS alerts, and zone-network-v2 configuration.
///
/// For the full feature set (permissions, smart-battery, external GPS, etc.)
/// keep using [VietmapTrackingController] from
/// `package:vietmap_tracking_plugin/vietmap_tracking_plugin.dart`.
class VietmapTrackingPlugin {
  VietmapTrackingPlugin._();
  static final VietmapTrackingPlugin instance = VietmapTrackingPlugin._();

  // ── Channels ──────────────────────────────────────────────────────────────

  static const _kChannel      = 'vietmap_tracking_plugin';
  static const _kLocation     = 'vietmap_tracking_plugin/location_updates';
  static const _kStatus       = 'vietmap_tracking_plugin/tracking_status';
  static const _kSpeedSign    = 'vietmap_tracking_plugin/speed_sign';
  static const _kTts          = 'vietmap_tracking_plugin/tts';

  static const _method        = MethodChannel(_kChannel);
  static const _locationCh    = EventChannel(_kLocation);
  static const _statusCh      = EventChannel(_kStatus);
  static const _speedSignCh   = EventChannel(_kSpeedSign);
  static const _ttsCh         = EventChannel(_kTts);

  // ── Streams (lazy, broadcast) ─────────────────────────────────────────────

  Stream<LocationUpdateEvent>? _locationStream;
  Stream<TrackingStatusEvent>? _statusStream;
  Stream<SpeedSignEvent>?      _speedSignStream;
  Stream<String>?              _ttsStream;

  /// Real-time GPS points forwarded from the native SDK pipeline.
  Stream<LocationUpdateEvent> get onLocationUpdate {
    _locationStream ??= _locationCh
        .receiveBroadcastStream()
        .map((e) => LocationUpdateEvent.fromMap(Map<Object?, Object?>.from(e as Map)))
        .asBroadcastStream();
    return _locationStream!;
  }

  /// Tracking-start / tracking-stop / permission / error status events.
  Stream<TrackingStatusEvent> get onTrackingStatus {
    _statusStream ??= _statusCh
        .receiveBroadcastStream()
        .map((e) => TrackingStatusEvent.fromMap(Map<Object?, Object?>.from(e as Map)))
        .asBroadcastStream();
    return _statusStream!;
  }

  /// Speed-sign images (PNG bytes) and limit values from the native alert SDK.
  Stream<SpeedSignEvent> get onSpeedSignChanged {
    _speedSignStream ??= _speedSignCh
        .receiveBroadcastStream()
        .map((e) => SpeedSignEvent.fromMap(Map<Object?, Object?>.from(e as Map)))
        .asBroadcastStream();
    return _speedSignStream!;
  }

  /// TTS (text-to-speech) strings emitted by the native speed-alert engine.
  Stream<String> get onTtsText {
    _ttsStream ??= _ttsCh
        .receiveBroadcastStream()
        .map((e) => e as String)
        .asBroadcastStream();
    return _ttsStream!;
  }

  // ── Configuration ─────────────────────────────────────────────────────────

  /// Validate the tracking API key against the server and initialize the SDK.
  ///
  /// Calls GET {trackingBaseUrl}/gps-tracking/users with the API key.
  /// Throws [PlatformException] with code "INVALID_API_KEY" if the key is
  /// rejected. On success the SDK is initialized automatically.
  ///
  /// Must be called before [startTracking]. Can be called independently of
  /// [configureTracking].
  Future<void> initializeTracking({
    required String trackingApiKey,
    String trackingBaseUrl = 'https://live.fleetwork.vn/api/v1',
  }) async {
    await _method.invokeMethod<void>('initializeTracking', {
      'trackingApiKey': trackingApiKey,
      'trackingBaseUrl': trackingBaseUrl,
    });
  }

  /// Attach arbitrary metadata to every GPS post under the "metadata" key.
  ///
  /// Call before [startTracking]. Can be updated at any time during tracking.
  ///
  /// Example:
  /// ```dart
  /// await VietmapTrackingPlugin.instance.setMetadata({
  ///   'tripId': 'TRIP_001',
  ///   'driverName': 'Nguyen Van A',
  /// });
  /// ```
  Future<void> setMetadata(Map<String, dynamic> metadata) async {
    try {
      await _method.invokeMethod<void>('setMetadata', {'metadata': metadata});
    } on PlatformException {
      rethrow;
    }
  }

  /// Attach package codes to every GPS post as the top-level "packages" field.
  ///
  /// Optional field — pass an empty list to leave "packages" out of the payload.
  /// Can be called before or during tracking; the list is captured per GPS point
  /// at the moment it is recorded, so points already cached offline keep the
  /// packages they were captured with.
  ///
  /// Example:
  /// ```dart
  /// await VietmapTrackingPlugin.instance.setPackages(['#10001', '#10002']);
  /// ```
  Future<void> setPackages(List<String> packages) async {
    try {
      await _method.invokeMethod<void>('setPackages', {'packages': packages});
    } on PlatformException {
      rethrow;
    }
  }

  /// Set custom app signature to be sent as X-App-Signature header when fetching configuration.
  Future<void> setAppSignature(String signature) async {
    try {
      await _method.invokeMethod<void>('setAppSignature', {'signature': signature});
    } on PlatformException {
      rethrow;
    }
  }

  /// Configure the tracking SDK.
  ///
  /// Must be called before any other method.
  ///
  /// - [apiKey] Your Vietmap API key.
  /// - [baseUrl] Override the default tracking server base URL.
  /// - [authMode] How credentials are sent (`header` or `queryParam`).
  /// - [gpsTrackingEndpoint] Relative path for single-point uploads.
  /// - [gpsBulkEndpoint] Relative path for batch uploads.
  /// - [autoUpload] Whether the SDK should auto-upload cached points.
  Future<bool> configureTracking({
    required String apiKey,
    String  baseUrl              = 'https://tracking.vietmap.vn',
    AuthMode authMode            = AuthMode.header,
    String  gpsTrackingEndpoint  = '/gps-tracking',
    String  gpsBulkEndpoint      = '/gps-tracking/bulk',
    bool    autoUpload           = true,
  }) async {
    try {
      final result = await _method.invokeMethod<bool>('configureTracking', {
        'apiKey':               apiKey,
        'baseUrl':              baseUrl,
        'authMode':             authMode.name,
        'gpsTrackingEndpoint':  gpsTrackingEndpoint,
        'gpsBulkEndpoint':      gpsBulkEndpoint,
        'autoUpload':           autoUpload,
      });
      return result ?? false;
    } on PlatformException {
      rethrow;
    }
  }

  /// Configure the speed-alert API.
  ///
  /// Call **after** [configureTracking].
  ///
  /// - [apiKey] Speed-alert API key.
  /// - [apiID]  Speed-alert API identifier.
  /// - [url]    Override the default alert endpoint.
  Future<bool> configureAlertAPI({
    required String apiKey,
    required String apiID,
    String url = 'https://drive-api.vietmap.vn/fleetwork/api/Alert/v2/mpp',
  }) async {
    try {
      final result = await _method.invokeMethod<bool>('configureAlertAPI', {
        'apiKey': apiKey,
        'apiID':  apiID,
        'url':    url,
      });
      return result ?? false;
    } on PlatformException {
      rethrow;
    }
  }

  /// Switch to the zone-network-v2 endpoint for speed-limit data lookups.
  ///
  /// - [baseUrl] Base URL of the v2 zone-network service.
  Future<bool> configureZoneNetworkV2(String baseUrl) async {
    try {
      final result = await _method.invokeMethod<bool>(
        'configureZoneNetworkV2',
        {'baseUrl': baseUrl},
      );
      return result ?? false;
    } on PlatformException {
      rethrow;
    }
  }

  /// Reset zone-network-v2 configuration back to the SDK default.
  Future<bool> resetZoneNetworkV2() async {
    try {
      final result =
          await _method.invokeMethod<bool>('resetZoneNetworkV2');
      return result ?? false;
    } on PlatformException {
      rethrow;
    }
  }

  // ── Vehicle ───────────────────────────────────────────────────────────────

  /// Configure vehicle metadata used in speed-alert zone lookups.
  ///
  /// - [vehicleId] Unique vehicle identifier.
  /// - [vehicleType] One of the [VehicleType] constants.
  /// - [seats] Number of passenger seats.
  /// - [weight] Vehicle weight in kg.
  /// - [maxProvision] Optional maximum provision value.
  Future<bool> configureVehicle({
    required String vehicleId,
    int vehicleType  = VehicleType.car,
    int seats        = 5,
    double weight    = 1500.0,
    int maxProvision = 0,
  }) async {
    try {
      final result = await _method.invokeMethod<bool>('configureVehicle', {
        'vehicleId':    vehicleId,
        'vehicleType':  vehicleType,
        'seats':        seats,
        'weight':       weight,
        'maxProvision': maxProvision,
      });
      return result ?? false;
    } on PlatformException {
      rethrow;
    }
  }

  // ── Alert ─────────────────────────────────────────────────────────────────

  /// Start speed-alert monitoring.
  ///
  /// Emits events on [onSpeedSignChanged] and [onTtsText] while active.
  Future<bool> startAlert() async {
    try {
      final result = await _method.invokeMethod<bool>('turnOnAlert');
      return result ?? false;
    } on PlatformException {
      rethrow;
    }
  }

  /// Stop speed-alert monitoring.
  Future<bool> stopAlert() async {
    try {
      final result = await _method.invokeMethod<bool>('turnOffAlert');
      return result ?? false;
    } on PlatformException {
      rethrow;
    }
  }

  /// Returns `true` if speed-alert monitoring is currently active.
  Future<bool> isAlertActive() async {
    try {
      final result = await _method.invokeMethod<bool>('isSpeedAlertActive');
      return result ?? false;
    } on PlatformException {
      rethrow;
    }
  }

  // ── Tracking ──────────────────────────────────────────────────────────────

  /// Start GPS tracking.
  ///
  /// - [backgroundMode] Keep tracking when app is in background.
  /// - [intervalMs] Minimum time between GPS captures (ms). Pass `0` for
  ///   distance-only mode.
  /// - [distanceFilter] Minimum displacement between GPS captures (m). Pass
  ///   `0` for timer-only mode.
  /// - [userId] Driver / user identifier attached to every GPS record.
  /// - [vehicleId] Vehicle identifier attached to every GPS record.
  Future<bool> startTracking({
    bool   backgroundMode  = true,
    int    intervalMs      = 5000,
    double distanceFilter  = 0.0,
    String? userId,
    String? vehicleId,
    String? notificationTitle,
    String? notificationMessage,
  }) async {
    try {
      final result = await _method.invokeMethod<bool>('startTracking', {
        'backgroundMode':      backgroundMode,
        'intervalMs':          intervalMs,
        'distanceFilter':      distanceFilter,
        if (userId   != null) 'userId':              userId,
        if (vehicleId != null) 'vehicleId':          vehicleId,
        if (notificationTitle   != null) 'notificationTitle':   notificationTitle,
        if (notificationMessage != null) 'notificationMessage': notificationMessage,
      });
      return result ?? false;
    } on PlatformException {
      rethrow;
    }
  }

  /// Stop GPS tracking.
  Future<bool> stopTracking() async {
    try {
      final result = await _method.invokeMethod<bool>('stopTracking');
      return result ?? false;
    } on PlatformException {
      rethrow;
    }
  }

  /// Returns `true` if GPS tracking is currently running.
  Future<bool> isTrackingActive() async {
    try {
      final result = await _method.invokeMethod<bool>('isTrackingActive');
      return result ?? false;
    } on PlatformException {
      rethrow;
    }
  }

  // ── External GPS ──────────────────────────────────────────────────────────

  /// Feed an externally sourced GPS fix into the tracking pipeline.
  ///
  /// Use this when receiving location data from an external hardware GPS
  /// receiver (Bluetooth OBD, serial GPS, etc.).
  Future<bool> processLocation({
    required double lat,
    required double lng,
    required double speed,
    required double heading,
    double accuracy  = 0.0,
    double altitude  = 0.0,
    int?   timestamp,
  }) async {
    try {
      final result = await _method.invokeMethod<bool>(
        'processExternalLocation',
        {
          'lat':       lat,
          'lng':       lng,
          'speed':     speed,
          'heading':   heading,
          'accuracy':  accuracy,
          'altitude':  altitude,
          'timestamp': timestamp ?? DateTime.now().millisecondsSinceEpoch,
        },
      );
      return result ?? false;
    } on PlatformException {
      rethrow;
    }
  }}
