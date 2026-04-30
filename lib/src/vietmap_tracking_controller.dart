import 'dart:async';
import 'dart:convert';
import 'package:flutter/widgets.dart';
import 'models/location_tracking_config.dart';
import 'models/location_data.dart';
import 'models/tracking_status.dart';
import 'models/permission_result.dart';
import 'models/fake_gps_event.dart';
import 'models/gps_location.dart';
import 'platform/vietmap_tracking_platform_interface.dart';
import 'services/smart_battery_manager.dart';

/// Main controller for Vietmap Tracking Plugin
class VietmapTrackingController with WidgetsBindingObserver {
  VietmapTrackingController._();

  static final VietmapTrackingController instance =
      VietmapTrackingController._();

  final _platform = VietmapTrackingPlatform.instance;

  void _logSection(String section, {bool end = false}) {
    debugPrint('=======${end ? 'End ' : ''}$section=======');
  }

  // Configuration state
  bool _isConfigured = false;
  bool get isConfigured => _isConfigured;

  // ── App Lifecycle observer ────────────────────────────────────

  /// Call once after configure() to enable automatic background/foreground
  /// notifications to the native SDK.
  void registerLifecycleObserver() {
    _logSection('Register Lifecycle Observer');
    WidgetsBinding.instance.addObserver(this);
    _logSection('Register Lifecycle Observer', end: true);
  }

  void unregisterLifecycleObserver() {
    _logSection('Unregister Lifecycle Observer');
    WidgetsBinding.instance.removeObserver(this);
    _logSection('Unregister Lifecycle Observer', end: true);
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    final section = state == AppLifecycleState.resumed
        ? 'Lifecycle: App Foreground'
        : 'Lifecycle: App Background';

    if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.detached) {
      _logSection(section);
      _platform.onAppBackground();
      _logSection(section, end: true);
    } else if (state == AppLifecycleState.resumed) {
      _logSection(section);
      _platform.onAppForeground();
      _logSection(section, end: true);
    }
  }

  // ── Configuration ─────────────────────────────────────────────

  /// Configure VietmapTrackingSDK with API key
  ///
  /// Must be called before using any tracking features.
  ///
  /// [apiKey] - API key for VietmapTrackingSDK
  /// [baseURL] - Optional base URL for the API
  ///
  /// Returns [true] if configuration was successful
  Future<bool> configure(String apiKey, {String? baseURL}) async {
    _logSection('Configure SDK');
    try {
      debugPrint(
        'API key: ${apiKey.isEmpty ? 'empty' : 'provided'} | baseURL: ${baseURL ?? 'default'}',
      );
      final result = await _platform.configure(apiKey, baseURL);
      _isConfigured = result;
      return result;
    } catch (e) {
      debugPrint('Failed to configure VietmapTrackingSDK: $e');
      return false;
    } finally {
      _logSection('Configure SDK', end: true);
    }
  }

  /// Configure Alert API for speed monitoring
  Future<bool> configureAlertAPI(String apiKey, String apiID) async {
    if (!_isConfigured) {
      throw Exception(
        'VietmapTrackingSDK not configured. Call configure() first.',
      );
    }
    _logSection('Configure Alert API');
    try {
      debugPrint('Alert API id: $apiID');
      return await _platform.configureAlertAPI(apiKey, apiID);
    } catch (e) {
      debugPrint('Failed to configure Alert API: $e');
      return false;
    } finally {
      _logSection('Configure Alert API', end: true);
    }
  }

  /// Enable or disable automatic upload of cached locations.
  Future<bool> setAutoUpload(bool enabled) async {
    _requireConfigured();
    _logSection('Configure Auto Upload');
    try {
      debugPrint('Auto upload enabled: $enabled');
      return await _platform.setAutoUpload(enabled);
    } catch (e) {
      debugPrint('Failed to setAutoUpload: $e');
      return false;
    } finally {
      _logSection('Configure Auto Upload', end: true);
    }
  }

  // ── Smart Battery Optimization ────────────────────────────────

  /// Smart Battery Optimization **tự động bật** khi [startTracking] thành công
  /// và **tự động tắt** khi [stopTracking] được gọi. Không cần enable/disable thủ công.
  ///
  /// **Khi bật:**
  /// - **iOS**: CoreLocation dùng `.automotiveNavigation` activity type — OS tự điều chỉnh
  ///   tần suất GPS theo vận tốc và góc cua; tự tạm dừng GPS khi xe đỗ lâu.
  /// - **Android**: `TrackingConfig` được cập nhật theo [preferredMovingProfile] và
  ///   tự chuyển sang `batterySaver` khi pin < 15% hoặc `general` khi xe đứng yên.
  /// - **Dart layer**: [SmartBatteryManager] giám sát pin + speed GPS để tự đổi preset.

  /// Đặt profile ưu tiên khi xe đang di chuyển và pin bình thường.
  ///
  /// Có thể gọi bất kỳ lúc nào — thay đổi có hiệu lực ngay lập tức nếu SmartBattery
  /// đang chạy, hoặc được áp dụng khi [startTracking] tiếp theo được gọi.
  ///
  /// [SmartBatteryProfile.general] (mặc định): cân bằng pin và độ chính xác (10s / 15m).
  /// [SmartBatteryProfile.navigation]: chính xác nhất (3s / 5m), tốn pin hơn.
  void setSmartBatteryPreferredProfile(SmartBatteryProfile profile) {
    SmartBatteryManager.instance.setPreferredMovingProfile(profile);
  }

  /// **Deprecated**: Smart Battery tự động bật cùng [startTracking].
  /// Dùng [setSmartBatteryPreferredProfile] để đổi profile ưu tiên.
  @Deprecated('Smart Battery is now auto-started with startTracking(). Use setSmartBatteryPreferredProfile() to change the preferred profile.')
  Future<void> enableSmartBatteryOptimization({
    SmartBatteryProfile preferredMovingProfile = SmartBatteryProfile.general,
  }) async {
    _requireConfigured();
    await SmartBatteryManager.instance.enable(
      preferredMoving: preferredMovingProfile,
    );
  }

  /// **Deprecated**: Smart Battery tự động tắt cùng [stopTracking].
  @Deprecated('Smart Battery is now auto-stopped with stopTracking().')
  void disableSmartBatteryOptimization() {
    SmartBatteryManager.instance.disable();
  }

  /// Truyền speed (m/s) và heading (°) từ mỗi GPS update vào SmartBatteryManager
  /// để phát hiện xe đứng yên và góc cua (cornering → navigation).
  ///
  /// ```dart
  /// controller.onLocationUpdate.listen((loc) {
  ///   controller.feedLocationToSmartBattery(
  ///     loc.speed ?? 0.0,
  ///     heading: loc.heading,
  ///   );
  /// });
  /// ```
  void feedLocationToSmartBattery(double speedMs, {double? heading}) {
    SmartBatteryManager.instance.onLocationUpdate(speedMs, heading: heading);
  }

  /// Truyền speed (m/s) từ mỗi GPS update vào SmartBatteryManager để phát hiện
  /// xe đứng yên. Gọi trong callback `onLocationUpdate`.
  ///
  /// **Deprecated**: Dùng [feedLocationToSmartBattery] để truyền cả heading,
  /// giúp phát hiện góc cua và tự switch sang `navigation`.
  @Deprecated('Use feedLocationToSmartBattery(speed, heading: heading) instead')
  void feedLocationSpeedToSmartBattery(double speedMs) {
    SmartBatteryManager.instance.onLocationUpdate(speedMs);
  }

  /// Stream thông báo mỗi lần Smart Battery thay đổi profile.
  Stream<SmartBatteryProfile> get onSmartBatteryProfileChanged =>
      SmartBatteryManager.instance.onProfileChanged;

  /// Profile hiện tại đang được Smart Battery Manager áp dụng.
  SmartBatteryProfile get currentSmartBatteryProfile =>
      SmartBatteryManager.instance.currentProfile;

  // ── Identifiers ──────────────────────────────────────────────

  /// Set vehicle ID directly (without restarting tracking).
  Future<bool> setVehicleId(String vehicleId) async {
    _requireConfigured();
    try {
      return await _platform.setVehicleId(vehicleId);
    } catch (e) {
      debugPrint('Failed to setVehicleId: $e');
      return false;
    }
  }

  /// Set driver ID directly.
  Future<bool> setDriverId(String driverId) async {
    _requireConfigured();
    try {
      return await _platform.setDriverId(driverId);
    } catch (e) {
      debugPrint('Failed to setDriverId: $e');
      return false;
    }
  }

  /// Get current vehicle ID (iOS only; returns null on Android).
  Future<String?> getVehicleId() async {
    _requireConfigured();
    try {
      return await _platform.getVehicleId();
    } catch (e) {
      debugPrint('Failed to getVehicleId: $e');
      return null;
    }
  }

  /// Get current driver ID (iOS only; returns null on Android).
  Future<String?> getDriverId() async {
    _requireConfigured();
    try {
      return await _platform.getDriverId();
    } catch (e) {
      debugPrint('Failed to getDriverId: $e');
      return null;
    }
  }

  // ── Permissions ───────────────────────────────────────────────

  Future<PermissionResult> requestLocationPermissions() async {
    try {
      return await _platform.requestLocationPermissions();
    } catch (e) {
      debugPrint('Failed to request location permissions: $e');
      rethrow;
    }
  }

  Future<PermissionResult> hasLocationPermissions() async {
    try {
      return await _platform.hasLocationPermissions();
    } catch (e) {
      debugPrint('Failed to check location permissions: $e');
      rethrow;
    }
  }

  Future<String> requestAlwaysLocationPermissions() async {
    try {
      return await _platform.requestAlwaysLocationPermissions();
    } catch (e) {
      debugPrint('Failed to request always permissions: $e');
      return 'denied';
    }
  }

  // ── Tracking ──────────────────────────────────────────────────

  Future<bool> startTracking(LocationTrackingConfig config) async {
    _requireConfigured();
    _logSection('Start Tracking SDK');
    try {
      debugPrint(
        'intervalMs=${config.intervalMs} distanceFilter=${config.distanceFilter} backgroundMode=${config.backgroundMode}',
      );
      final hasPermissions = await hasLocationPermissions();
      if (!hasPermissions.granted) {
        final requestResult = await requestLocationPermissions();
        if (!requestResult.granted) {
          throw Exception('Location permissions not granted');
        }
      }
      final result = await _platform.startTracking(config);
      if (result) {
        // Auto-enable Smart Battery — always active during tracking
        await SmartBatteryManager.instance.enable(
          preferredMoving: SmartBatteryManager.instance.preferredMovingProfile,
        );
      }
      return result;
    } catch (e) {
      debugPrint('Failed to start tracking: $e');
      rethrow;
    } finally {
      _logSection('Start Tracking SDK', end: true);
    }
  }

  Future<bool> stopTracking() async {
    _logSection('Stop Tracking SDK');
    try {
      SmartBatteryManager.instance.disable();
      return await _platform.stopTracking();
    } catch (e) {
      debugPrint('Failed to stop tracking: $e');
      return false;
    } finally {
      _logSection('Stop Tracking SDK', end: true);
    }
  }

  Future<LocationData> getCurrentLocation() async {
    _requireConfigured();
    try {
      return await _platform.getCurrentLocation();
    } catch (e) {
      debugPrint('Failed to get current location: $e');
      rethrow;
    }
  }

  Future<bool> isTrackingActive() async {
    try {
      return await _platform.isTrackingActive();
    } catch (e) {
      debugPrint('Failed to check tracking status: $e');
      return false;
    }
  }

  Future<TrackingStatus> getTrackingStatus() async {
    try {
      return await _platform.getTrackingStatus();
    } catch (e) {
      debugPrint('Failed to get tracking status: $e');
      rethrow;
    }
  }

  Future<bool> updateTrackingConfig(LocationTrackingConfig config) async {
    _logSection('Update Tracking Config');
    try {
      debugPrint(
        'intervalMs=${config.intervalMs} distanceFilter=${config.distanceFilter} backgroundMode=${config.backgroundMode}',
      );
      return await _platform.updateTrackingConfig(config);
    } catch (e) {
      debugPrint('Failed to update tracking config: $e');
      return false;
    } finally {
      _logSection('Update Tracking Config', end: true);
    }
  }

  Future<Map<String, dynamic>> getTrackingHealthStatus() async {
    _requireConfigured();
    try {
      return await _platform.getTrackingHealthStatus();
    } catch (e) {
      debugPrint('Failed to get tracking health status: $e');
      rethrow;
    }
  }

  Future<List<GpsLocation>> getTrackingHistory({
    required String userId,
    required int fromTimestamp,
    required int toTimestamp,
    int pageNumber = 1,
    int pageSize = 100,
    String sortBy = 'timestamp',
    bool sortDescending = false,
  }) async {
    _requireConfigured();
    _logSection('Get Tracking History');
    try {
      debugPrint(
        'userId=$userId from=$fromTimestamp to=$toTimestamp page=$pageNumber size=$pageSize sortBy=$sortBy sortDescending=$sortDescending',
      );
      final rawJson = await _platform.getTrackingHistory(
        userId: userId,
        fromTime: fromTimestamp,
        toTime: toTimestamp,
        pageNumber: pageNumber,
        pageSize: pageSize,
        sortBy: sortBy,
        sortDescending: sortDescending,
      );

      final locations = _parseTrackingHistory(rawJson);
      debugPrint('Parsed tracking history points: ${locations.length}');
      return locations;
    } catch (e) {
      debugPrint('Failed to getTrackingHistory: $e');
      rethrow;
    } finally {
      _logSection('Get Tracking History', end: true);
    }
  }

  // ── Alert ─────────────────────────────────────────────────────

  Future<bool> turnOnAlert() async {
    try {
      return await _platform.turnOnAlert();
    } catch (e) {
      debugPrint('Failed to turn on alert: $e');
      return false;
    }
  }

  Future<bool> turnOffAlert() async {
    try {
      return await _platform.turnOffAlert();
    } catch (e) {
      debugPrint('Failed to turn off alert: $e');
      return false;
    }
  }

  /// Check whether speed alert is currently active.
  Future<bool> isSpeedAlertActive() async {
    try {
      return await _platform.isSpeedAlertActive();
    } catch (e) {
      debugPrint('Failed to check speed alert status: $e');
      return false;
    }
  }

  /// Configure vehicle parameters for speed-zone calculations.
  Future<bool> configureVehicle({
    required String vehicleId,
    required int vehicleType,
    required int seats,
    required double weight,
    int? maxProvision,
  }) async {
    _requireConfigured();
    try {
      return await _platform.configureVehicle(
        vehicleId: vehicleId,
        vehicleType: vehicleType,
        seats: seats,
        weight: weight,
        maxProvision: maxProvision,
      );
    } catch (e) {
      debugPrint('Failed to configureVehicle: $e');
      return false;
    }
  }

  // ── External GPS injection ────────────────────────────────────

  /// Inject an external GPS fix into the SDK (e.g. from a hardware GPS device).
  Future<bool> processExternalLocation({
    required double lat,
    required double lng,
    required double speed,
    required double heading,
    double? accuracy,
    double? altitude,
    int? timestamp,
  }) async {
    _requireConfigured();
    try {
      return await _platform.processExternalLocation(
        lat: lat,
        lng: lng,
        speed: speed,
        heading: heading,
        accuracy: accuracy,
        altitude: altitude,
        timestamp: timestamp,
      );
    } catch (e) {
      debugPrint('Failed to processExternalLocation: $e');
      return false;
    }
  }

  // ── Cache & Network ───────────────────────────────────────────

  /// Check if device has active internet connectivity.
  Future<bool> isNetworkConnected() async {
    try {
      return await _platform.isNetworkConnected();
    } catch (e) {
      debugPrint('Failed to check network: $e');
      return false;
    }
  }

  /// Get number of location records waiting to be uploaded.
  Future<int> getCachedLocationsCount() async {
    try {
      return await _platform.getCachedLocationsCount();
    } catch (e) {
      debugPrint('Failed to getCachedLocationsCount: $e');
      return 0;
    }
  }

  /// Manually trigger upload of all cached location records.
  Future<bool> uploadCachedLocationsManually() async {
    try {
      return await _platform.uploadCachedLocationsManually();
    } catch (e) {
      debugPrint('Failed to uploadCachedLocationsManually: $e');
      return false;
    }
  }

  /// Delete all cached location records from local storage.
  Future<bool> clearCachedLocations() async {
    try {
      return await _platform.clearCachedLocations();
    } catch (e) {
      debugPrint('Failed to clearCachedLocations: $e');
      return false;
    }
  }

  /// Configure SQLite cache limits.
  ///
  /// Call **before** [startTracking] for best results.
  /// Pass `0` for any parameter to keep the SDK default value.
  ///
  /// Defaults: [maxRecords] = 5000 (Android) / 10000 (iOS),
  ///           [maxDbSizeBytes] = 52428800 (50 MB),
  ///           [batchSize] = 50.
  Future<bool> configureCacheLimits({
    int maxRecords = 0,
    int maxDbSizeBytes = 0,
    int batchSize = 0,
  }) async {
    try {
      return await _platform.configureCacheLimits(
        maxRecords: maxRecords,
        maxDbSizeBytes: maxDbSizeBytes,
        batchSize: batchSize,
      );
    } catch (e) {
      debugPrint('Failed to configureCacheLimits: $e');
      return false;
    }
  }

  /// Get current SQLite database file size in bytes.
  Future<int> getDatabaseSizeBytes() async {
    try {
      return await _platform.getDatabaseSizeBytes();
    } catch (e) {
      debugPrint('Failed to getDatabaseSizeBytes: $e');
      return 0;
    }
  }

  // ── Event streams ─────────────────────────────────────────────

  Stream<LocationData> get onLocationUpdate => _platform.onLocationUpdate;

  Stream<TrackingStatus> get onTrackingStatusChanged =>
      _platform.onTrackingStatusChanged;

  /// Stream of fake GPS detection events.
  /// Native debounces at 30s. Listen to this after calling [setFakeGpsPolicy].
  Stream<FakeGpsEvent> get onFakeGpsDetected => _platform.onFakeGpsDetected;

  /// Set the policy for handling detected fake GPS locations.
  ///
  /// Call once after [configure] — before [startTracking].
  /// [policy] must be one of [FakeGpsPolicy] constants:
  /// - [FakeGpsPolicy.skip] (default): detect only; no warning/stop/upload
  /// - [FakeGpsPolicy.warn]: show local notification (debounced 30s)
  /// - [FakeGpsPolicy.stopTracking]: stop tracking on first detection
  /// - [FakeGpsPolicy.logToServer]: save to DB + upload with `X-Fake-GPS: true`
  Future<void> setFakeGpsPolicy(String policy) async {
    assert(
      FakeGpsPolicy.values.contains(policy),
      'Invalid policy: $policy. Use a FakeGpsPolicy constant.',
    );
    try {
      await _platform.setFakeGpsPolicy(policy);
    } catch (e) {
      debugPrint('Failed to setFakeGpsPolicy: $e');
    }
  }

  // ── Helpers ───────────────────────────────────────────────────

  List<GpsLocation> _parseTrackingHistory(String rawJson) {
    if (rawJson.trim().isEmpty) {
      return const [];
    }

    final decoded = jsonDecode(rawJson);
    final pointMaps = _extractHistoryPointMaps(decoded);

    return pointMaps
        .map(_toGpsLocation)
        .whereType<GpsLocation>()
        .toList(growable: false);
  }

  List<Map<String, dynamic>> _extractHistoryPointMaps(dynamic node) {
    if (node is List) {
      return node
          .whereType<Map>()
          .map((item) => Map<String, dynamic>.from(item))
          .toList(growable: false);
    }

    if (node is! Map) {
      return const [];
    }

    final map = Map<String, dynamic>.from(node);
    const listKeys = [
      'data',
      'Data',
      'items',
      'Items',
      'records',
      'Records',
      'locations',
      'Locations',
      'history',
      'History',
      'result',
      'Result',
    ];

    for (final key in listKeys) {
      final value = map[key];
      if (value is List) {
        return value
            .whereType<Map>()
            .map((item) => Map<String, dynamic>.from(item))
            .toList(growable: false);
      }
      if (value is Map) {
        final nested = _extractHistoryPointMaps(value);
        if (nested.isNotEmpty) {
          return nested;
        }
      }
    }

    return _looksLikeLocationMap(map) ? [map] : const [];
  }

  bool _looksLikeLocationMap(Map<String, dynamic> map) {
    final lat = _readDouble(map, const ['latitude', 'Latitude', 'lat', 'Lat']);
    final lng = _readDouble(
      map,
      const ['longitude', 'Longitude', 'lng', 'Lng', 'lon', 'Lon'],
    );
    return lat != null && lng != null;
  }

  GpsLocation? _toGpsLocation(Map<String, dynamic> map) {
    final lat = _readDouble(map, const ['latitude', 'Latitude', 'lat', 'Lat']);
    final lng = _readDouble(
      map,
      const ['longitude', 'Longitude', 'lng', 'Lng', 'lon', 'Lon'],
    );

    if (lat == null || lng == null) {
      return null;
    }

    final timestampMs = _readTimestampMillis(
      map,
      const [
        'timestamp',
        'Timestamp',
        'time',
        'Time',
        'createdAt',
        'CreatedAt',
        'recordedAt',
        'RecordedAt',
      ],
    );

    return GpsLocation(
      latitude: lat,
      longitude: lng,
      altitude: _readDouble(map, const ['altitude', 'Altitude']),
      accuracy: _readDouble(map, const ['accuracy', 'Accuracy']),
      speed: _readDouble(map, const ['speed', 'Speed']),
      heading: _readDouble(
        map,
        const ['heading', 'Heading', 'bearing', 'Bearing'],
      ),
      timestamp: timestampMs == null
          ? null
          : DateTime.fromMillisecondsSinceEpoch(timestampMs),
      displayAddress: _readString(
        map,
        const ['displayAddress', 'DisplayAddress', 'address', 'Address'],
      ),
      metadata: map,
    );
  }

  double? _readDouble(Map<String, dynamic> map, List<String> keys) {
    for (final key in keys) {
      final value = map[key];
      if (value is num) {
        return value.toDouble();
      }
      if (value is String) {
        final parsed = double.tryParse(value);
        if (parsed != null) {
          return parsed;
        }
      }
    }
    return null;
  }

  String? _readString(Map<String, dynamic> map, List<String> keys) {
    for (final key in keys) {
      final value = map[key];
      if (value is String && value.isNotEmpty) {
        return value;
      }
    }
    return null;
  }

  int? _readTimestampMillis(Map<String, dynamic> map, List<String> keys) {
    for (final key in keys) {
      final value = map[key];
      if (value == null) {
        continue;
      }

      if (value is num) {
        final raw = value.toInt();
        return raw < 1000000000000 ? raw * 1000 : raw;
      }

      if (value is String) {
        final numeric = int.tryParse(value);
        if (numeric != null) {
          return numeric < 1000000000000 ? numeric * 1000 : numeric;
        }
        final date = DateTime.tryParse(value);
        if (date != null) {
          return date.millisecondsSinceEpoch;
        }
      }
    }
    return null;
  }

  void _requireConfigured() {
    if (!_isConfigured) {
      throw Exception(
        'VietmapTrackingSDK not configured. Call configure() first.',
      );
    }
  }
}
