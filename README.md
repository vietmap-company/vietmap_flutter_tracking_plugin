# vietmap_tracking_plugin

[![pub package](https://img.shields.io/pub/v/vietmap_tracking_plugin.svg)](https://pub.dev/packages/vietmap_tracking_plugin)
[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](https://opensource.org/licenses/MIT)

A Flutter plugin for GPS location tracking with VietmapTrackingSDK integration, featuring background tracking support, speed alerts, and route monitoring. Built with platform channels (MethodChannel + EventChannel) bridging directly to native SDKs on both iOS and Android.

## Key Features

- **Background GPS Tracking** — Continuous location tracking with native VietmapTrackingSDK integration via foreground service (Android) and background location mode (iOS).
- **VietmapTrackingSDK Integration** — Direct native SDK bridge on both platforms. No third-party location wrappers.
- **Speed Alert System** — Real-time speed monitoring with configurable Alert API credentials.
- **Offline Tracking & Cache Sync** — Automatically stores GPS points in local SQLite while offline and uploads in batches when network is available.
- **Fake GPS Detection** — Native fake-location detection with configurable policies: skip, warn, stop tracking, or log to server.
- **Cross-Platform** — Native implementations for both Android (API 21+) and iOS (11.0+).
- **High Accuracy** — Configurable precision levels (`high`, `medium`, `low`) for different use cases.
- **Battery Management** — Optimized tracking presets for balancing accuracy and power consumption.
- **Permission Handling** — Unified API for location permission management, including the two-step background permission flow on Android 10+.
- **Real-time Event Streams** — `Stream<LocationData>` and `Stream<TrackingStatus>` for reactive UI updates.
- **Tracking Presets** — Pre-configured profiles for Navigation, Fitness, General, and Battery Saver modes.
- **Location Utilities** — Built-in distance calculations (Haversine), speed conversions, and coordinate formatting.
- **Session Management** — Tracking session statistics including duration and status monitoring.

## Requirements

| Dependency | Minimum Version |
|------------|----------------|
| Flutter    | 3.3.0+         |
| Dart       | 3.8.0+         |
| iOS        | 11.0 (iOS 13+ recommended for enhanced background tasks) |
| Android    | API Level 21 (Android 5.0) |
| Google Play Services | Required (Android) |
| Core Location Framework | Required (iOS) |

### Native SDK Versions

| Platform | SDK | Version |
|----------|-----|---------|
| iOS      | VietmapTrackingSDK (CocoaPods) | 1.3.5 |
| Android  | vietmap-tracking-sdk-android (JitPack) | 1.3.7 |

## Installation

```yaml
dependencies:
  vietmap_tracking_plugin: ^1.0.0
```

```bash
flutter pub get
```

### iOS Setup

#### Basic Configuration

Add the following permissions to your `ios/Runner/Info.plist`:

```xml
<key>NSLocationWhenInUseUsageDescription</key>
<string>This app needs location access to track your GPS location when using the app.</string>
<key>NSLocationAlwaysAndWhenInUseUsageDescription</key>
<string>This app needs continuous location access to track your GPS location even when the app is in the background. This enables features like route tracking, delivery monitoring, and location-based services.</string>
<key>NSLocationAlwaysUsageDescription</key>
<string>This app needs background location access to provide continuous GPS tracking when the app is not actively in use.</string>
```

#### Background Modes Configuration

Add background capabilities for enhanced tracking:

```xml
<key>UIBackgroundModes</key>
<array>
    <string>location</string>
    <string>background-processing</string>
    <string>background-fetch</string>
</array>
```

#### Background Task Identifiers (iOS 13+)

For advanced background processing capabilities:

```xml
<key>BGTaskSchedulerPermittedIdentifiers</key>
<array>
    <string>com.vietmaptrackingsdk.location-sync</string>
    <string>com.vietmaptrackingsdk.background-location</string>
</array>
```

### Android Setup

#### Permissions

Add the following permissions to your `android/app/src/main/AndroidManifest.xml`:

```xml
<uses-permission android:name="android.permission.INTERNET" />
<uses-permission android:name="android.permission.ACCESS_FINE_LOCATION" />
<uses-permission android:name="android.permission.ACCESS_COARSE_LOCATION" />
<uses-permission android:name="android.permission.ACCESS_BACKGROUND_LOCATION" />
<uses-permission android:name="android.permission.FOREGROUND_SERVICE" />
<uses-permission android:name="android.permission.FOREGROUND_SERVICE_LOCATION" />
```

**Note:** On Android 10+ (API 29+), `ACCESS_BACKGROUND_LOCATION` must be requested separately after the user grants foreground location permission. The plugin handles this two-step flow via `requestLocationPermissions()` followed by `requestAlwaysLocationPermissions()`.

## Quick Start

### Initial Configuration

Before using any tracking features, configure the VietmapTrackingSDK:

```dart
import 'package:vietmap_tracking_plugin/vietmap_tracking_plugin.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  final controller = VietmapTrackingController.instance;

  // Configure VietmapTrackingSDK with your API key
  final success = await controller.configure('YOUR_VIETMAP_API_KEY');

  // Optional: Configure Alert API for speed monitoring
  await controller.configureAlertAPI('YOUR_ALERT_API_KEY', 'YOUR_ALERT_API_ID');

  runApp(MyApp());
}
```

### Basic Location Tracking

```dart
final controller = VietmapTrackingController.instance;

// Start tracking with custom configuration
Future<void> startLocationTracking() async {
  try {
    final config = LocationTrackingConfig(
      intervalMs: 5000,
      distanceFilter: 10.0,
      accuracy: LocationAccuracy.high,
      backgroundMode: true,
      notificationTitle: 'GPS Tracking Active',
      notificationMessage: 'Your location is being tracked',
    );

    final result = await controller.startTracking(config);
    print('Tracking started: $result');
  } catch (error) {
    print('Failed to start tracking: $error');
  }
}

// Listen for location updates
void setupListeners() {
  controller.onLocationUpdate.listen((LocationData location) {
    print('New location: ${location.latitude}, ${location.longitude}');
    print('Accuracy: ${location.accuracy}m, Speed: ${location.speed} m/s');
  });

  controller.onTrackingStatusChanged.listen((TrackingStatus status) {
    print('Tracking status: ${status.isTracking}');
  });
}

// Stop tracking
Future<void> stopLocationTracking() async {
  try {
    final result = await controller.stopTracking();
    print('Tracking stopped: $result');
  } catch (error) {
    print('Failed to stop tracking: $error');
  }
}
```

### Speed Alert System

```dart
// Enable speed monitoring
Future<void> enableSpeedAlerts() async {
  try {
    final success = await controller.turnOnAlert();
    if (success) {
      print('Speed alerts enabled');
    }
  } catch (error) {
    print('Failed to enable speed alerts: $error');
  }
}

// Disable speed monitoring
Future<void> disableSpeedAlerts() async {
  try {
    final success = await controller.turnOffAlert();
    if (success) {
      print('Speed alerts disabled');
    }
  } catch (error) {
    print('Failed to disable speed alerts: $error');
  }
}
```

### Tracking Modes: Interval vs Distance

The plugin forwards both `intervalMs` and `distanceFilter` to the native SDK. Use the mode that matches your product behavior:

| Mode | `intervalMs` | `distanceFilter` | Typical use case |
|------|--------------|------------------|------------------|
| Interval-based | `> 0` | `0` | Send updates on a fixed timer, even if the device barely moves. |
| Distance-based | `0` | `> 0` | Send updates only after the device moves a minimum distance. |
| Hybrid preset | `> 0` | `> 0` | Use tuned defaults from `TrackingPresets` for balanced tracking. |

For a strict timer-only setup, set `distanceFilter: 0.0`. For a strict movement-only setup, set `intervalMs: 0`.

```dart
// Interval-based tracking: update every 5 seconds regardless of movement.
final intervalConfig = LocationTrackingConfig(
  intervalMs: 5000,
  distanceFilter: 0.0,
  accuracy: LocationAccuracy.high,
  backgroundMode: true,
);

// Distance-based tracking: update only after moving 50 meters.
final distanceConfig = LocationTrackingConfig(
  intervalMs: 0,
  distanceFilter: 50.0,
  accuracy: LocationAccuracy.high,
  backgroundMode: true,
);

// Hybrid preset: the SDK uses tuned interval + distance defaults.
final hybridConfig = TrackingPresets.navigation();
```

### Offline Tracking and Manual Cache Sync

```dart
final controller = VietmapTrackingController.instance;

// Optional: disable auto upload and control sync manually
await controller.setAutoUpload(false);

// Check offline cache size
final pending = await controller.getCachedLocationsCount();
print('Pending cached locations: $pending');

// Configure SQLite cache limits (optional)
await controller.configureCacheLimits(
  maxRecords: 5000,
  maxDbSizeBytes: 50 * 1024 * 1024, // 50 MB
  batchSize: 50,
);

// Trigger manual upload when needed
final uploaded = await controller.uploadCachedLocationsManually();
print('Manual cache upload: $uploaded');

// Optional: clear cache
await controller.clearCachedLocations();
```

### Fake GPS Detection

Fake GPS detection is available by default, but the SDK stays in the `skip`
policy unless you change it. In `skip` mode, the SDK only emits detection
events for app logic; it does not warn, stop tracking, or upload fake records.
To activate a response policy manually, call `setFakeGpsPolicy(...)` before
`startTracking()`.

```dart
final controller = VietmapTrackingController.instance;

// Manual activation: choose a policy other than skip
await controller.setFakeGpsPolicy(FakeGpsPolicy.warn);

controller.onFakeGpsDetected.listen((event) {
  print('Fake GPS detected at ${event.lat}, ${event.lng}');
  print('isFirstDetection: ${event.isFirstDetection}');
});
```

## Configuration Options

### LocationTrackingConfig

```dart
LocationTrackingConfig({
  /// Interval between location updates in milliseconds.
  /// Set to 0 to prefer distance-based updates.
  required int intervalMs,

  /// Minimum distance between location updates in meters.
  /// Set to 0 to prefer interval-based updates.
  required double distanceFilter,

  /// Desired accuracy level: high, medium, low
  required LocationAccuracy accuracy,

  /// Whether to continue tracking in background
  required bool backgroundMode,

  /// Custom notification title for foreground service (Android)
  String? notificationTitle,

  /// Custom notification message for foreground service (Android)
  String? notificationMessage,
})
```

### Tracking Presets

Pre-configured tracking modes available as factory methods.
These are hybrid defaults that tune both interval and distance for common use cases:

```dart
// High accuracy for turn-by-turn navigation (3s interval, 5m filter)
TrackingPresets.navigation()

// Optimized for fitness and outdoor activities (5s interval, 10m filter)
TrackingPresets.fitness()

// Balanced accuracy and battery usage (10s interval, 15m filter)
TrackingPresets.general()

// Maximum battery conservation (30s interval, 50m filter)
TrackingPresets.batterySaver()
```

| Preset | Interval | Distance Filter | Accuracy | Background |
|--------|----------|----------------|----------|------------|
| `navigation()` | 3000 ms | 5.0 m | high | true |
| `fitness()` | 5000 ms | 10.0 m | high | true |
| `general()` | 10000 ms | 15.0 m | medium | true |
| `batterySaver()` | 30000 ms | 50.0 m | low | true |

Each preset accepts optional `notificationTitle` and `notificationMessage` parameters:

```dart
final config = TrackingPresets.navigation(
  notificationTitle: 'Navigation Active',
  notificationMessage: 'Tracking your route',
);
await controller.startTracking(config);
```

### Custom Configuration Examples

```dart
// High precision navigation tracking
final navigationConfig = LocationTrackingConfig(
  intervalMs: 1000,
  distanceFilter: 5.0,
  accuracy: LocationAccuracy.high,
  backgroundMode: true,
  notificationTitle: 'Navigation Active',
  notificationMessage: 'Tracking your route',
);

// Battery optimized tracking
final batteryConfig = LocationTrackingConfig(
  intervalMs: 60000,
  distanceFilter: 100.0,
  accuracy: LocationAccuracy.medium,
  backgroundMode: true,
  notificationTitle: 'Background Tracking',
  notificationMessage: 'Tracking with battery optimization',
);

// Fitness tracking
final fitnessConfig = LocationTrackingConfig(
  intervalMs: 5000,
  distanceFilter: 10.0,
  accuracy: LocationAccuracy.high,
  backgroundMode: true,
  notificationTitle: 'Fitness Tracking',
  notificationMessage: 'Recording your workout',
);
```

## API Reference

### Core Configuration Methods

#### `configure(String apiKey, {String? baseURL})`

Initialize VietmapTrackingSDK with API key and optional base URL. Must be called before any other tracking method.

```dart
final success = await controller.configure('YOUR_VIETMAP_API_KEY');
// or with custom base URL
final success = await controller.configure(
  'YOUR_VIETMAP_API_KEY',
  baseURL: 'https://custom-api.vietmap.vn',
);
```

#### `configureAlertAPI(String apiKey, String apiID)`

Configure Alert API for speed monitoring features. Requires `configure()` to be called first.

```dart
await controller.configureAlertAPI('YOUR_ALERT_API_KEY', 'YOUR_ALERT_API_ID');
```

### Tracking Control Methods

#### `startTracking(LocationTrackingConfig config)`

Start GPS tracking with the specified configuration. Automatically requests permissions if not already granted.

```dart
final config = TrackingPresets.navigation();
final result = await controller.startTracking(config);
```

#### `stopTracking()`

Stop the active tracking session and release all resources.

```dart
final result = await controller.stopTracking();
```

#### `getCurrentLocation()`

Fetch the current device location immediately (one-time, not continuous).

```dart
final location = await controller.getCurrentLocation();
print('${location.latitude}, ${location.longitude}');
```

#### `getTrackingStatus()`

Get detailed tracking session status information.

```dart
final status = await controller.getTrackingStatus();
print('Is tracking: ${status.isTracking}');
print('Duration: ${status.duration}');
```

#### `isTrackingActive()`

Check whether location tracking is currently running.

```dart
final active = await controller.isTrackingActive();
```

#### `updateTrackingConfig(LocationTrackingConfig config)`

Update tracking configuration while tracking is active.

> **Important:** See the [critical note on `updateTrackingConfig` behavior](#important-note-updatetrackingconfig-behavior) below.

```dart
final newConfig = TrackingPresets.navigation();
final success = await controller.updateTrackingConfig(newConfig);
```

### Permission Management

#### `requestLocationPermissions()`

Request foreground location permissions from the user.

```dart
final result = await controller.requestLocationPermissions();
print('Granted: ${result.granted}');
print('Fine location: ${result.fineLocation}');
print('Background: ${result.backgroundLocation}');
```

#### `hasLocationPermissions()`

Check current location permission status without prompting the user.

```dart
final result = await controller.hasLocationPermissions();
print('Status: ${result.status}'); // granted | denied | not_granted
```

#### `requestAlwaysLocationPermissions()`

Request background ("Always") location permission. Required for background tracking.

```dart
final status = await controller.requestAlwaysLocationPermissions();
// Returns: 'granted', 'denied', etc.
```

### Event Streams

#### `onLocationUpdate`

Subscribe to real-time location updates while tracking is active.

```dart
controller.onLocationUpdate.listen((LocationData location) {
  print('Lat: ${location.latitude}, Lng: ${location.longitude}');
  print('Speed: ${location.speed} m/s');
});
```

#### `onTrackingStatusChanged`

Subscribe to tracking status changes.

```dart
controller.onTrackingStatusChanged.listen((TrackingStatus status) {
  print('Tracking: ${status.isTracking}');
  print('Duration: ${status.duration}');
});
```

### Speed Alert Methods

#### `turnOnAlert()`

Enable speed monitoring. Requires `configureAlertAPI()` to be called first.

```dart
final success = await controller.turnOnAlert();
```

#### `turnOffAlert()`

Disable speed monitoring.

```dart
final success = await controller.turnOffAlert();
```

### Offline Cache & Sync Methods

#### `setAutoUpload(bool enabled)`

Enable/disable automatic background upload of cached locations.

```dart
await controller.setAutoUpload(true);
```

#### `getCachedLocationsCount()`

Returns number of cached GPS points waiting for upload.

```dart
final pending = await controller.getCachedLocationsCount();
```

#### `uploadCachedLocationsManually()`

Manually uploads cached GPS points.

```dart
final ok = await controller.uploadCachedLocationsManually();
```

#### `clearCachedLocations()`

Deletes all cached GPS points from local SQLite.

```dart
await controller.clearCachedLocations();
```

#### `configureCacheLimits({maxRecords, maxDbSizeBytes, batchSize})`

Configures SQLite cache capacity and upload batch size.

```dart
await controller.configureCacheLimits(
  maxRecords: 5000,
  maxDbSizeBytes: 50 * 1024 * 1024,
  batchSize: 50,
);
```

### Fake GPS Methods

#### `setFakeGpsPolicy(String policy)`

Sets the fake GPS response policy before tracking starts.

This is the manual activation method for the feature.

- `FakeGpsPolicy.skip` (default): detect only, but do not warn/stop/upload
- `FakeGpsPolicy.warn`: trigger warning notification (native debounce 30s)
- `FakeGpsPolicy.stopTracking`: stop tracking on first detection
- `FakeGpsPolicy.logToServer`: mark fake record and upload with `X-Fake-GPS: true`

```dart
await controller.setFakeGpsPolicy(FakeGpsPolicy.logToServer);
```

#### `onFakeGpsDetected`

Stream of `FakeGpsEvent` emitted by native SDK.

```dart
controller.onFakeGpsDetected.listen((event) {
  print(event);
});
```

---

### Important Note: `updateTrackingConfig` Behavior

The `updateTrackingConfig` method does **not** apply configuration changes incrementally. Internally, the method executes the following sequence:

```
updateTrackingConfig(newConfig)
  Step 1: stopTracking()            → Terminate the current session, remove existing configuration
  Step 2: startTracking(newConfig)  → Apply the new configuration, start a new tracking session
```

**Implications:**

- **Location gap** — There will be a brief interruption in location updates during the stop/start transition.
- **Session reset** — The `trackingDuration` in `TrackingStatus` resets to zero because a new session is created.
- **In-flight callbacks** — Location callbacks from the previous session may still fire during the transition window.
- **Status events** — The `onTrackingStatusChanged` stream will emit a stopped event (`isTracking: false`) followed by a started event (`isTracking: true`).

**Recommendation:** If your application requires session continuity (e.g., preserving cumulative duration or distance metrics), manage the stop/start cycle manually and maintain session state at the application layer rather than relying on `updateTrackingConfig`.

---

## Data Models

### LocationData

Represents a single GPS fix. Emitted by `onLocationUpdate` and returned by `getCurrentLocation()`.

```dart
LocationData({
  required double latitude,    // Latitude in degrees (-90 to 90)
  required double longitude,   // Longitude in degrees (-180 to 180)
  required double altitude,    // Altitude in meters above sea level
  required double accuracy,    // Horizontal accuracy in meters
  required double speed,       // Speed in meters per second
  required double bearing,     // Heading in degrees (0-360, 0 = North)
  required int timestamp,      // Unix timestamp in milliseconds
})
```

Convenience property: `dateTime` returns a `DateTime` instance from the timestamp.

### TrackingStatus

Represents the current state of a tracking session.

```dart
TrackingStatus({
  required bool isTracking,        // Whether tracking is active
  int? lastLocationUpdate,         // Timestamp of last GPS fix (ms)
  required int trackingDuration,   // Session duration in milliseconds
})
```

Convenience properties:

- `lastUpdateTime` — Returns `DateTime?` from `lastLocationUpdate`.
- `duration` — Returns `Duration` from `trackingDuration`.

### PermissionResult

Result of a permission check or request.

```dart
PermissionResult({
  required bool granted,               // Overall permission status
  required PermissionStatus status,    // Enum: granted, denied, notGranted
  required bool fineLocation,          // Fine (GPS) permission
  required bool coarseLocation,        // Coarse (network) permission
  required bool backgroundLocation,    // Background location permission
})
```

## Utility Functions

### Distance Calculation

```dart
// Distance between two coordinate pairs (Haversine formula, returns meters)
double distance = LocationUtils.calculateDistance(
  21.0285, 105.8542,   // Hanoi
  10.8231, 106.6297,   // Ho Chi Minh City
);
print('Distance: ${distance} meters');

// Distance between two LocationData objects
double distance = LocationUtils.distanceBetween(location1, location2);
```

### Coordinate Formatting

```dart
String formatted = LocationUtils.formatCoordinates(21.0285, 105.8542);
// "21.028500° N, 105.854200° E"
```

### Speed Conversion

```dart
double kmh = LocationUtils.metersPerSecondToKmh(25.0);   // 90.0
double ms  = LocationUtils.kmhToMetersPerSecond(90.0);    // 25.0
```

### Radius Check

```dart
bool isNearby = LocationUtils.isWithinRadius(
  currentLocation,
  21.0285,     // target latitude
  105.8542,    // target longitude
  100.0,       // radius in meters
);
```

## Use Cases and Examples

### Navigation Applications

```dart
// High-accuracy tracking for turn-by-turn navigation
await controller.startTracking(TrackingPresets.navigation());

// Or with custom high-precision configuration
final navigationConfig = LocationTrackingConfig(
  intervalMs: 1000,
  distanceFilter: 5.0,
  accuracy: LocationAccuracy.high,
  backgroundMode: true,
  notificationTitle: 'Navigation Active',
  notificationMessage: 'Tracking your route',
);
await controller.startTracking(navigationConfig);
```

### Fitness Tracking

```dart
// Optimized for outdoor activities and sports
await controller.startTracking(TrackingPresets.fitness());

// Track distance in real-time
final List<LocationData> locations = [];
double totalDistance = 0.0;

controller.onLocationUpdate.listen((location) {
  if (locations.isNotEmpty) {
    totalDistance += LocationUtils.distanceBetween(locations.last, location);
  }
  locations.add(location);

  final km = (totalDistance / 1000).toStringAsFixed(2);
  final speedKmh = LocationUtils.metersPerSecondToKmh(location.speed);
  print('Distance: $km km | Speed: ${speedKmh.toStringAsFixed(1)} km/h');
});
```

### Delivery Services

```dart
// Custom configuration for delivery tracking
final deliveryConfig = LocationTrackingConfig(
  intervalMs: 30000,
  distanceFilter: 50.0,
  accuracy: LocationAccuracy.high,
  backgroundMode: true,
  notificationTitle: 'Delivery Tracking',
  notificationMessage: 'Tracking delivery route',
);

await controller.startTracking(deliveryConfig);

// Monitor delivery progress
controller.onTrackingStatusChanged.listen((status) {
  if (status.isTracking) {
    updateDeliveryStatus('In Transit');
  }
});
```

### Fleet Management

```dart
// Battery optimized for long-term fleet tracking
await controller.startTracking(TrackingPresets.batterySaver());

// Geofence monitoring
final depotLat = 21.0285;
final depotLon = 105.8542;
final geofenceRadius = 100.0; // meters

controller.onLocationUpdate.listen((location) {
  final isInDepot = LocationUtils.isWithinRadius(
    location, depotLat, depotLon, geofenceRadius,
  );

  if (isInDepot) {
    print('Vehicle returned to depot');
  }
});
```

### Complete Example Application

See the [example](example/) directory for a full working application.

```dart
import 'package:flutter/material.dart';
import 'package:vietmap_tracking_plugin/vietmap_tracking_plugin.dart';

void main() => runApp(const MyApp());

class MyApp extends StatefulWidget {
  const MyApp({super.key});

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  final controller = VietmapTrackingController.instance;
  LocationData? currentLocation;
  bool isTracking = false;

  @override
  void initState() {
    super.initState();
    _initialize();
    _setupListeners();
  }

  Future<void> _initialize() async {
    await controller.configure('YOUR_API_KEY');
  }

  void _setupListeners() {
    controller.onLocationUpdate.listen((location) {
      setState(() => currentLocation = location);
    });

    controller.onTrackingStatusChanged.listen((status) {
      setState(() => isTracking = status.isTracking);
    });
  }

  Future<void> _startTracking() async {
    final config = TrackingPresets.navigation();
    await controller.startTracking(config);
  }

  Future<void> _stopTracking() async {
    await controller.stopTracking();
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      home: Scaffold(
        appBar: AppBar(title: const Text('Vietmap Tracking')),
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text('Status: ${isTracking ? "Tracking" : "Idle"}'),
              const SizedBox(height: 8),
              Text('Latitude: ${currentLocation?.latitude ?? "N/A"}'),
              Text('Longitude: ${currentLocation?.longitude ?? "N/A"}'),
              Text('Speed: ${currentLocation?.speed.toStringAsFixed(1) ?? "N/A"} m/s'),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: isTracking ? null : _startTracking,
                child: const Text('Start Tracking'),
              ),
              ElevatedButton(
                onPressed: isTracking ? _stopTracking : null,
                child: const Text('Stop Tracking'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
```

## Testing

### Dart Unit Tests

Run the Dart-side unit tests (method channel mocks, model serialization):

```bash
flutter test
```

### Android Unit Tests (JVM)

Run the Android bridge layer tests. These are pure JVM tests that do not require a device or emulator:

```bash
cd example/android
./gradlew :vietmap_tracking_plugin:testDebugUnitTest
```

Test source: `android/src/test/kotlin/com/example/vietmap_tracking_plugin/VietmapTrackingPluginTest.kt`

### Android Instrumented Tests

Run tests on a connected Android device or emulator with the actual native SDK:

```bash
cd example/android
./gradlew app:connectedAndroidTest
```

Test source: `example/android/app/src/androidTest/`

### iOS Unit Tests (XCTest)

Run the iOS bridge layer tests via Xcode or the command line:

```bash
cd example/ios
xcodebuild test \
  -workspace Runner.xcworkspace \
  -scheme Runner \
  -destination 'platform=iOS Simulator,name=iPhone 16' \
  -only-testing RunnerTests
```

Test source: `example/ios/RunnerTests/RunnerTests.swift`

### Flutter Integration Tests

```bash
cd example
flutter test integration_test/
```

### Running the Example Application

```bash
# Navigate to example directory
cd example

# Install dependencies
flutter pub get

# iOS
flutter run -d ios

# Android
flutter run -d android
```

## Troubleshooting

### Android

**Background tracking stops after a period of time**

- Verify that `FOREGROUND_SERVICE` and `FOREGROUND_SERVICE_LOCATION` permissions are declared in `AndroidManifest.xml`.
- Add your app to the battery optimization exemption list in device settings.
- Some manufacturers (Xiaomi, Huawei, Samsung) have aggressive battery management policies. Users may need to manually allow background activity for the application.

**Location permission denied or system dialog not appearing**

- Confirm all required permissions are declared in `AndroidManifest.xml`.
- On Android 10+ (API 29+), `ACCESS_BACKGROUND_LOCATION` cannot be requested simultaneously with foreground permissions. Call `requestLocationPermissions()` first, then `requestAlwaysLocationPermissions()` in a separate step.
- If the user has previously denied the permission with "Don't ask again", the system dialog will not appear. Direct the user to the application settings screen.

**Gradle build fails with SDK not found**

- Ensure `maven { url 'https://jitpack.io' }` is present in the `allprojects.repositories` block of the plugin's `build.gradle`.

### iOS

**Location updates stop in background**

- Verify `UIBackgroundModes` includes `location` in `Info.plist`.
- Ensure the user has granted "Always" location permission via `requestAlwaysLocationPermissions()`.
- Confirm that `backgroundMode: true` is set in your `LocationTrackingConfig`.

**Permission dialog does not appear**

- Confirm all three `NSLocation*` keys are present in `Info.plist` with non-empty description strings.
- Do not request permissions before the application UI has fully loaded.
- Ensure there are no duplicate `NSLocationWhenInUseUsageDescription` entries — a duplicate with an empty value will override the valid one, causing iOS to deny the permission request.

**Pod install fails**

- Run `pod repo update` followed by `pod install`.
- Ensure your `Podfile` specifies `platform :ios, '11.0'` or higher.

## Architecture

```
┌──────────────────────────────────────────────────┐
│                   Flutter App                     │
│          VietmapTrackingController                │
├──────────────────────────────────────────────────┤
│            Platform Interface (Dart)              │
│     MethodChannel: vietmap_tracking_plugin         │
│     EventChannel: /location_updates               │
│     EventChannel: /tracking_status                │
├───────────────────────┬──────────────────────────┤
│    iOS Native Bridge  │  Android Native Bridge    │
│  VietmapTrackingPlugin │ VietmapTrackingPlugin     │
│        (Swift)        │        (Kotlin)           │
├───────────────────────┼──────────────────────────┤
│  VietmapTrackingSDK   │  VietmapTrackingSDK       │
│  iOS 1.3.4 CocoaPods  │  Android 1.3.4 JitPack   │
└───────────────────────┴──────────────────────────┘
```

## Documentation

- [Changelog](./CHANGELOG.md) — Version history and release notes
- [Testing Guide](./TESTING_GUIDE.md) — Detailed testing instructions for iOS Simulator

## Contributing

Contributions are welcome. Please submit a Pull Request with a clear description of the changes.

### Development Setup

1. Clone the repository.
2. Install dependencies: `flutter pub get`
3. Navigate to example: `cd example && flutter pub get`
4. Run the example app: `flutter run`

## License

This project is licensed under the MIT License. See the [LICENSE](LICENSE) file for details.

## Related Projects

- [VietmapTrackingSDK iOS](https://github.com/vietmap-company/vietmap-tracking-sdk-ios)
- [VietmapTrackingSDK Android](https://github.com/vietmap-company/vietmap-tracking-sdk-android)

## Support

For issues, questions, or feature requests, please file an issue on [GitHub](https://github.com/vietmap-company/vietmap_tracking_plugin/issues).