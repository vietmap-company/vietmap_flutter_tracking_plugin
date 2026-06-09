import 'package:plugin_platform_interface/plugin_platform_interface.dart';
import '../models/location_tracking_config.dart';
import '../models/location_data.dart';
import '../models/tracking_status.dart';
import '../models/permission_result.dart';
import '../models/fake_gps_event.dart';
import 'method_channel_vietmap_tracking.dart';

abstract class VietmapTrackingPlatform extends PlatformInterface {
  VietmapTrackingPlatform() : super(token: _token);

  static final Object _token = Object();
  static VietmapTrackingPlatform _instance = MethodChannelVietmapTracking();

  static VietmapTrackingPlatform get instance => _instance;

  static set instance(VietmapTrackingPlatform instance) {
    PlatformInterface.verifyToken(instance, _token);
    _instance = instance;
  }

  // ── Configuration ────────────────────────────────────────────
  Future<bool> configure(String apiKey, String? baseURL);

  /// Validate the tracking API key by calling GET {baseURL}/gps-tracking/users.
  /// Throws [PlatformException] with code "INVALID_API_KEY" if the key is rejected.
  /// On success the SDK is also initialized with the provided credentials.
  Future<void> initializeTracking(String apiKey, String? baseURL);

  /// Attach arbitrary metadata to every GPS post sent by the tracking SDK.
  /// The [metadata] map is merged into the "metadata" field of each GPS payload.
  Future<void> setMetadata(Map<String, dynamic> metadata);

  Future<bool> configureAlertAPI(String apiKey, String apiID);
  Future<bool> setAutoUpload(bool enabled);

  /// Cấu hình Smart Battery Optimization trên native layer.
  /// [enabled] true → bật tối ưu (iOS: automotiveNavigation; Android: áp TrackingConfig preset).
  /// [preset] "navigation" | "general" | "batterySaver"
  Future<bool> setSmartBatteryConfig({
    required bool enabled,
    required String preset,
  });

  // ── Identifiers ──────────────────────────────────────────────
  Future<bool> setVehicleId(String vehicleId);
  Future<bool> setDriverId(String driverId);
  Future<String?> getVehicleId();
  Future<String?> getDriverId();

  // ── Permissions ───────────────────────────────────────────────
  Future<PermissionResult> requestLocationPermissions();
  Future<PermissionResult> hasLocationPermissions();
  Future<String> requestAlwaysLocationPermissions();

  // ── Tracking ──────────────────────────────────────────────────
  Future<bool> startTracking(LocationTrackingConfig config);
  Future<bool> stopTracking();
  Future<LocationData> getCurrentLocation();
  Future<bool> isTrackingActive();
  Future<TrackingStatus> getTrackingStatus();
  Future<bool> updateTrackingConfig(LocationTrackingConfig config);
  Future<Map<String, dynamic>> getTrackingHealthStatus();
  Future<String> getTrackingHistory({
    required String userId,
    int? fromTime,
    int? toTime,
    int pageNumber = 1,
    int pageSize = 100,
    bool sortDescending = false,
  });

  // ── Alert ─────────────────────────────────────────────────────
  Future<bool> turnOnAlert();
  Future<bool> turnOffAlert();
  Future<bool> isSpeedAlertActive();
  Future<bool> configureVehicle({
    required String vehicleId,
    required int vehicleType,
    required int seats,
    required double weight,
    int? maxProvision,
  });

  // ── External GPS injection ────────────────────────────────────
  Future<bool> processExternalLocation({
    required double lat,
    required double lng,
    required double speed,
    required double heading,
    double? accuracy,
    double? altitude,
    int? timestamp,
  });

  // ── Cache & Network ───────────────────────────────────────────
  Future<bool> isNetworkConnected();
  Future<int> getCachedLocationsCount();
  Future<bool> uploadCachedLocationsManually();
  Future<bool> clearCachedLocations();

  /// Configure SQLite cache limits.
  /// Pass 0 for any parameter to keep its current default.
  Future<bool> configureCacheLimits({
    int maxRecords,
    int maxDbSizeBytes,
    int batchSize,
  });

  /// Get current SQLite database file size in bytes.
  Future<int> getDatabaseSizeBytes();

  // ── App Lifecycle ─────────────────────────────────────────────
  Future<void> onAppBackground();
  Future<void> onAppForeground();

  // ── Fake GPS ──────────────────────────────────────────────────

  /// Set the policy for handling detected fake GPS locations.
  /// [policy] must be one of the values in [FakeGpsPolicy].
  Future<void> setFakeGpsPolicy(String policy);

  /// Customise the title and body of the fake-GPS local notification (shown when policy is "warn").
  Future<void> setFakeGpsNotificationConfig({
    required String title,
    required String message,
  });

  // ── Event streams ─────────────────────────────────────────────────────────────
  Stream<LocationData> get onLocationUpdate;
  Stream<TrackingStatus> get onTrackingStatusChanged;

  /// Stream of fake GPS detection events from native SDK.
  /// Native debounces at 30s — at most 1 event per 30-second window.
  Stream<FakeGpsEvent> get onFakeGpsDetected;
}
