import 'package:plugin_platform_interface/plugin_platform_interface.dart';
import '../models/location_tracking_config.dart';
import '../models/location_data.dart';
import '../models/tracking_status.dart';
import '../models/permission_result.dart';
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

  // Configuration methods
  Future<bool> configure(String apiKey, String? baseURL);
  Future<bool> configureAlertAPI(String apiKey, String apiID);

  // Permission methods
  Future<PermissionResult> requestLocationPermissions();
  Future<PermissionResult> hasLocationPermissions();
  Future<String> requestAlwaysLocationPermissions();

  // Tracking methods
  Future<bool> startTracking(LocationTrackingConfig config);
  Future<bool> stopTracking();
  Future<LocationData> getCurrentLocation();
  Future<bool> isTrackingActive();
  Future<TrackingStatus> getTrackingStatus();
  Future<bool> updateTrackingConfig(LocationTrackingConfig config);
  Future<Map<String, dynamic>> getTrackingHealthStatus();

  // Alert methods
  Future<bool> turnOnAlert();
  Future<bool> turnOffAlert();
  // Event streams
  Stream<LocationData> get onLocationUpdate;
  Stream<TrackingStatus> get onTrackingStatusChanged;
}
