// Vietmap Tracking Plugin - GPS Location Tracking with VietmapTrackingSDK

// Export models
export 'src/models/location_tracking_config.dart';
export 'src/models/location_data.dart';
export 'src/models/tracking_status.dart';
export 'src/models/permission_result.dart';
export 'src/models/gps_location.dart';
export 'src/models/route_data.dart';
export 'src/models/tracking_presets.dart';
export 'src/models/fake_gps_event.dart';
export 'src/models/tracking_interrupted_event.dart';

// Export platform interface
export 'src/platform/vietmap_tracking_platform_interface.dart';

// Export utils
export 'src/utils/location_utils.dart';
export 'src/utils/constants.dart';

// Export main controller
export 'src/vietmap_tracking_controller.dart';

// Export Smart Battery Optimization
export 'src/services/smart_battery_manager.dart';

// Legacy exports for backward compatibility
export 'src/tracking_core.dart';
export 'src/tracking_location/tracking_service.dart';
