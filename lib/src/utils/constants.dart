/// Plugin constants
class VietmapTrackingConstants {
  // Default configuration values
  static const int defaultIntervalMs = 5000;
  static const double defaultDistanceFilter = 10.0;
  static const String defaultAccuracy = 'high';
  static const bool defaultBackgroundMode = true;

  // Permission status strings
  static const String permissionGranted = 'granted';
  static const String permissionDenied = 'denied';
  static const String permissionNotGranted = 'not_granted';

  // Event names (matching native implementations)
  static const String eventLocationUpdate = 'onLocationUpdate';
  static const String eventTrackingStatusChanged = 'onTrackingStatusChanged';
  static const String eventLocationError = 'onLocationError';
  static const String eventPermissionChanged = 'onPermissionChanged';
  static const String eventRouteUpdate = 'onRouteUpdate';

  // Error codes
  static const String errorNotInitialized = 'SDK_NOT_INITIALIZED';
  static const String errorPermissionDenied = 'PERMISSION_DENIED';
  static const String errorLocationUnavailable = 'LOCATION_UNAVAILABLE';
  static const String errorInvalidConfig = 'INVALID_CONFIG';
}
