# vietmap_tracking_plugin

[![pub package](https://img.shields.io/pub/v/vietmap_tracking_plugin.svg)](https://pub.dev/packages/vietmap_tracking_plugin)
[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](https://opensource.org/licenses/MIT)

A Flutter plugin for GPS location tracking with VietmapTrackingSDK integration. Supports background tracking, speed alerts, offline cache/sync, and fake GPS detection. Built on native platform channels (MethodChannel + EventChannel) — no third-party location wrappers.

---

## Installation

```yaml
dependencies:
  vietmap_tracking_plugin: ^1.0.6
```

```bash
flutter pub get
```

---

## Android Setup

### 1. Permissions (`android/app/src/main/AndroidManifest.xml`)

```xml
<uses-permission android:name="android.permission.INTERNET" />
<uses-permission android:name="android.permission.ACCESS_FINE_LOCATION" />
<uses-permission android:name="android.permission.ACCESS_COARSE_LOCATION" />
<uses-permission android:name="android.permission.ACCESS_BACKGROUND_LOCATION" />
<uses-permission android:name="android.permission.FOREGROUND_SERVICE" />
<uses-permission android:name="android.permission.FOREGROUND_SERVICE_LOCATION" />
```

> On Android 10+ (API 29+) `ACCESS_BACKGROUND_LOCATION` must be requested separately **after** foreground permission is granted. The plugin handles this two-step flow via `requestLocationPermissions()` → `requestAlwaysLocationPermissions()`.

### 2. SDK Repository (`android/build.gradle`)

```groovy
allprojects {
    repositories {
        maven { url 'https://jitpack.io' }
    }
}
```

---

## iOS Setup

### 1. Location Usage Descriptions (`ios/Runner/Info.plist`)

```xml
<key>NSLocationWhenInUseUsageDescription</key>
<string>This app needs location access to track your GPS position.</string>
<key>NSLocationAlwaysAndWhenInUseUsageDescription</key>
<string>This app needs background location access for continuous GPS tracking.</string>
<key>NSLocationAlwaysUsageDescription</key>
<string>This app needs background location access for continuous GPS tracking.</string>
```

### 2. Background Modes

```xml
<key>UIBackgroundModes</key>
<array>
    <string>location</string>
    <string>background-processing</string>
    <string>background-fetch</string>
</array>
```

### 3. Background Task Identifiers (iOS 15+)

```xml
<key>BGTaskSchedulerPermittedIdentifiers</key>
<array>
    <string>com.vietmaptrackingsdk.location-sync</string>
    <string>com.vietmaptrackingsdk.background-location</string>
</array>
```

### 4. CocoaPods (`ios/Podfile`)

```ruby
platform :ios, '15.0'
```

```bash
cd ios && pod install
```

> **Note:** On first install run `pod install --repo-update` to ensure `VietmapTrackingSDK` is resolved from the latest spec repo.

---

## Quick Start

### 1. Initialize the SDK

Call `initializeTracking` once at app startup — before any other SDK method. It validates the API key server-side.

```dart
import 'package:flutter/services.dart';
import 'package:vietmap_tracking_plugin/vietmap_tracking_plugin.dart';

final controller = VietmapTrackingController.instance;

Future<void> initSdk() async {
  try {
    await controller.initializeTracking(
      'your-api-key', // Contact Vietmap to get an API key
      baseURL: 'https://live.fleetwork.vn/api/v1', // optional
    );

    // Attach metadata to every GPS upload — optional, call before startTracking
    await controller.setMetadata({
      'userId': 'user-123',
      'appVersion': '1.0.0',
    });

    // Configure speed alert API — optional
    await controller.configureAlertAPI('your-alert-api-key', 'your-alert-api-id');
  } on PlatformException catch (e) {
    if (e.code == 'INVALID_API_KEY') {
      print('Invalid API key: \${e.message}');
    } else {
      rethrow;
    }
  }
}
```

### 2. Request Permissions

> **Warning (Android 10+):** Always complete Step 1 and verify `result.granted` before calling `requestAlwaysLocationPermissions`. Skipping Step 1 will silently fail on Android 10+.

```dart
final result = await controller.requestLocationPermissions();
if (!result.granted) return;

// Android 10+ — request background permission in a separate step
await controller.requestAlwaysLocationPermissions();
```

### 3. Start Tracking

```dart
await controller.startTracking(
  LocationTrackingConfig(
    intervalMs: 30000,
    accuracy: LocationAccuracy.high,
    backgroundMode: true,
    notificationTitle: 'GPS Tracking Active',
    notificationMessage: 'Your location is being recorded',
  ),
);
```

Or use a preset:

```dart
await controller.startTracking(TrackingPresets.navigation());
```

> **Important:** To pass identifiers (e.g. `userId`, `vehicleId`) with a preset, use `copyWith()`. Do **not** use `setDriverId()` / `setVehicleId()` for initial setup — those methods update identifiers during an already-active tracking session.

### 4. Listen for Updates

```dart
controller.onLocationUpdate.listen((LocationData loc) {
  print('\${loc.latitude}, \${loc.longitude} @ \${loc.speed} m/s');
});

controller.onTrackingStatusChanged.listen((TrackingStatus status) {
  print('Tracking: \${status.isTracking}');
});
```

### 5. Stop Tracking

```dart
await controller.stopTracking();
```

---

## Simplified API

For simpler use cases, `VietmapTrackingPlugin.instance` exposes a lighter surface:

```dart
import 'package:vietmap_tracking_plugin/vietmap_tracking.dart';

final plugin = VietmapTrackingPlugin.instance;

await plugin.initializeTracking(
  trackingApiKey: 'your-api-key',
  trackingBaseUrl: 'https://live.fleetwork.vn/api/v1', // optional
);

await plugin.startTracking(backgroundMode: true, intervalMs: 5000, userId: 'user-123');
await plugin.stopTracking();

plugin.onSpeedSignChanged.listen((SpeedSignEvent ev) => print('Limit: \${ev.speedLimit} km/h'));
plugin.onTtsText.listen((String text) => print('TTS: \$text'));
```

---

## Key Features

| Feature | Description |
|---------|-------------|
| Background GPS | Foreground service (Android) / background location mode (iOS) |
| API Key Validation | `initializeTracking` validates server-side; throws `INVALID_API_KEY` on failure |
| Metadata Attachment | `setMetadata` stamps every GPS record with arbitrary key-value pairs |
| Speed Alerts | Real-time speed monitoring via configurable Alert API |
| Offline Cache | SQLite cache with auto-upload when network recovers |
| Fake GPS Detection | Native detection with 4 configurable response policies |
| Smart Battery | Auto-adjusts tracking precision based on battery and movement |
| Tracking Presets | Navigation / Fitness / General / BatterySaver out of the box |
| Location Utilities | Haversine distance, speed conversion, geofence check |

---

## Requirements

| | Minimum |
|---|---|
| Flutter | 3.3.0+ |
| Dart | 3.8.0+ |
| iOS | 15.0+ |
| Android | API 21 (Android 5.0) |

**Native SDKs**

| Platform | SDK | Version |
|----------|-----|---------|
| iOS | VietmapTrackingSDK (CocoaPods) | 1.3.10 |
| Android | vietmap-tracking-sdk-android | 1.3.9 |

---

## Tracking Modes

`LocationTrackingConfig` supports two mutually exclusive tracking strategies.
Pass **only one** of `intervalMs` or `distanceFilter`; set the other to `null`.

| Mode | `intervalMs` | `distanceFilter` | Behaviour |
|------|-------------|------------------|-----------|
| **Interval (default)** | `> 0` | `null` | Location update every N milliseconds regardless of movement |
| **Distance** | `null` | `> 0` | Location update only after the device has moved M metres |

> Setting both to a non-null value is supported but not recommended — the SDK
> fires on whichever condition is satisfied first, which can produce uneven
> data density and unexpected battery usage.

### Platform implementation details

**Android**
- *Interval mode* — `FusedLocationProviderClient` is configured with
  `LocationRequest.setInterval(intervalMs)`. No displacement filter is applied.
- *Distance mode* — `LocationRequest.setSmallestDisplacement(distanceFilter)`
  is set and `intervalMs` is omitted (SDK default ceiling applies).

**iOS**
- *Interval mode* — `CLLocationManager` calls `didUpdateLocations`; the bridge
  timestamps every fix and discards ones that arrive sooner than `intervalMs`
  since the last accepted fix. `distanceFilter` is set to
  `kCLDistanceFilterNone`.
- *Distance mode* — `CLLocationManager.distanceFilter` is set to
  `distanceFilter` metres. The bridge accepts every callback the OS delivers.

### Tracking Presets

Presets are grouped into **interval-based** (default) and **distance-based**
variants. Choose the variant that matches your use case.

#### Interval-based (timer-driven)

```dart
TrackingPresets.navigation()    // 3 s — high accuracy, real-time vehicle tracking
TrackingPresets.fitness()       // 5 s — outdoor activities
TrackingPresets.general()       // 10 s — balanced fleet/delivery tracking
TrackingPresets.batterySaver()  // 30 s — slow or parked assets
```

#### Distance-based (movement-driven)

```dart
TrackingPresets.navigationDistance()   // every 5 m  — dense route points
TrackingPresets.fitnessDistance()      // every 10 m — outdoor activities
TrackingPresets.generalDistance()      // every 30 m — general tracking
TrackingPresets.batterySaverDistance() // every 100 m — maximum conservation
```

To attach user identifiers to a preset, use `copyWith()`:

```dart
await controller.startTracking(
  TrackingPresets.general().copyWith(userId: 'user-123'),
);
```

---

## Speed Alert System

```dart
// Call after initializeTracking
await controller.configureAlertAPI('your-alert-api-key', 'your-alert-api-id');

await controller.turnOnAlert();
await controller.turnOffAlert();
```

---

## Offline Cache & Sync

```dart
await controller.setAutoUpload(false); // take manual control

final pending = await controller.getCachedLocationsCount();

await controller.configureCacheLimits(
  maxRecords: 5000,
  maxDbSizeBytes: 50 * 1024 * 1024, // 50 MB
  batchSize: 50,
);

await controller.uploadCachedLocationsManually();
await controller.clearCachedLocations();
```

---

## Fake GPS Detection

Default policy is `skip` (detect and emit event only, no other action).

```dart
await controller.setFakeGpsPolicy(FakeGpsPolicy.warn);

controller.onFakeGpsDetected.listen((FakeGpsEvent ev) {
  print('Fake GPS at \${ev.lat}, \${ev.lng}');
});
```

| Policy | Behaviour |
|--------|-----------|
| `skip` | Emit event only — no warning, no stop |
| `warn` | Native notification (debounced 30 s) |
| `stopTracking` | Auto-stop tracking on first detection |
| `logToServer` | Upload with `is_fake=1` + `X-Fake-GPS: true` |

---

## API Reference

### Initialization

#### `initializeTracking(String apiKey, {String? baseURL})`

Validates the API key server-side and initialises the SDK. Throws `PlatformException(code: 'INVALID_API_KEY')` if rejected.

```dart
await controller.initializeTracking('your-api-key'); // Contact Vietmap for a key
```

#### `setMetadata(Map<String, dynamic> metadata)`

Attaches metadata to every GPS record uploaded. Call after `initializeTracking`, before `startTracking`.

```dart
await controller.setMetadata({'userId': 'u-123', 'vehicleId': 'v-001'});
```

> Metadata is merged into the `metadata` field of every GPS record server-side. Keys are arbitrary strings; values must be JSON-serialisable.

#### `configureAlertAPI(String apiKey, String apiID)`

Configures Alert API credentials for speed monitoring.

```dart
await controller.configureAlertAPI('key', 'id');
```

---

### Tracking Control

```dart
await controller.startTracking(config);          // start
await controller.stopTracking();                  // stop
final loc    = await controller.getCurrentLocation();
final status = await controller.getTrackingStatus();
final active = await controller.isTrackingActive();
await controller.updateTrackingConfig(newConfig); // ⚠ see note below
```

#### ⚠ `updateTrackingConfig` Behaviour

Internally performs `stopTracking()` → `startTracking(newConfig)`. Side-effects:

- Brief gap in location updates during transition
- `trackingDuration` resets to zero (new session)
- Status stream emits `isTracking: false` then `isTracking: true`

If session continuity matters, manage stop/start manually.

---

### Permissions

```dart
final r = await controller.requestLocationPermissions();
// r.granted, r.fineLocation, r.backgroundLocation

final r = await controller.hasLocationPermissions();
// r.status: 'granted' | 'denied' | 'not_granted'

await controller.requestAlwaysLocationPermissions();
```

---

### Event Streams

```dart
controller.onLocationUpdate.listen((LocationData loc) { ... });
controller.onTrackingStatusChanged.listen((TrackingStatus s) { ... });
controller.onFakeGpsDetected.listen((FakeGpsEvent ev) { ... });
```

---

### Speed Alert

```dart
await controller.turnOnAlert();
await controller.turnOffAlert();
```

---

### Cache & Sync

```dart
await controller.setAutoUpload(bool);
final n = await controller.getCachedLocationsCount();
await controller.uploadCachedLocationsManually();
await controller.clearCachedLocations();
await controller.configureCacheLimits(maxRecords: 5000, maxDbSizeBytes: 52428800, batchSize: 50);
```

---

## Configuration Reference

### `LocationTrackingConfig`

| Field | Type | Default | Description |
|-------|------|---------|-------------|
| `intervalMs` | `int?` | `null` | Update interval in ms; `null` = SDK default |
| `distanceFilter` | `double?` | `null` | Min distance in metres; `null` = SDK default |
| `accuracy` | `LocationAccuracy` | `high` | `high` / `medium` / `low` |
| `backgroundMode` | `bool` | `true` | Continue tracking when app is in background |
| `notificationTitle` | `String?` | — | Android foreground service title |
| `notificationMessage` | `String?` | — | Android foreground service body |
| `allowMockLocation` | `bool` | `false` | Allow fake/mock GPS input |

---

## Data Models

### `LocationData`

```
latitude, longitude  — degrees
altitude             — metres above sea level
accuracy             — horizontal accuracy in metres
speed                — m/s
bearing              — heading 0–360° (0 = North)
timestamp            — Unix ms
dateTime             — convenience DateTime getter
```

### `TrackingStatus`

```
isTracking           — bool
lastLocationUpdate   — Unix ms (nullable)
trackingDuration     — ms
lastUpdateTime       — DateTime? (convenience)
duration             — Duration (convenience)
```

### `PermissionResult`

```
granted              — bool
status               — 'granted' | 'denied' | 'notGranted'
fineLocation         — bool
coarseLocation       — bool
backgroundLocation   — bool
```

---

## Utility Functions

```dart
// Haversine distance between two coordinate pairs (metres)
LocationUtils.calculateDistance(lat1, lng1, lat2, lng2);
LocationUtils.distanceBetween(location1, location2);

// Formatting
LocationUtils.formatCoordinates(21.0285, 105.8542);
// → "21.028500° N, 105.854200° E"

// Speed conversion
LocationUtils.metersPerSecondToKmh(25.0); // → 90.0
LocationUtils.kmhToMetersPerSecond(90.0); // → 25.0

// Geofence check
LocationUtils.isWithinRadius(location, targetLat, targetLng, radiusMetres);
```

---

## Complete Minimal Example

```dart
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:vietmap_tracking_plugin/vietmap_tracking_plugin.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const MyApp());
}

class MyApp extends StatefulWidget {
  const MyApp({super.key});
  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  final _ctrl = VietmapTrackingController.instance;
  LocationData? _loc;
  bool _tracking = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _init();
  }

  Future<void> _init() async {
    try {
      await _ctrl.initializeTracking(
        'your-api-key', // Contact Vietmap to get an API key
      );
      _ctrl.onLocationUpdate.listen((l) => setState(() => _loc = l));
      _ctrl.onTrackingStatusChanged.listen((s) => setState(() => _tracking = s.isTracking));
    } on PlatformException catch (e) {
      setState(() => _error = e.message);
    }
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      home: Scaffold(
        appBar: AppBar(title: const Text('Vietmap Tracking')),
        body: Center(
          child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
            if (_error != null)
              Text('Error: \$_error', style: const TextStyle(color: Colors.red)),
            Text('Status: \${_tracking ? "Tracking" : "Idle"}'),
            Text('Lat: \${_loc?.latitude ?? "—"}'),
            Text('Lng: \${_loc?.longitude ?? "—"}'),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: _tracking ? null : () => _ctrl.startTracking(TrackingPresets.navigation()),
              child: const Text('Start'),
            ),
            ElevatedButton(
              onPressed: _tracking ? _ctrl.stopTracking : null,
              child: const Text('Stop'),
            ),
          ]),
        ),
      ),
    );
  }
}
```

See the [example](example/) directory for a full working app with all features.

---

## Testing

```bash
# Dart unit tests
flutter test

# Android JVM unit tests
cd example/android && ./gradlew :vietmap_tracking_plugin:testDebugUnitTest

# Android instrumented tests (requires device/emulator)
cd example/android && ./gradlew app:connectedAndroidTest

# iOS unit tests
cd example/ios
xcodebuild test \
  -workspace Runner.xcworkspace \
  -scheme Runner \
  -destination 'platform=iOS Simulator,name=iPhone 16' \
  -only-testing RunnerTests

# Flutter integration tests
cd example && flutter test integration_test/
```

---

## Troubleshooting

### Android

**Background tracking stops unexpectedly**
- Add `FOREGROUND_SERVICE` + `FOREGROUND_SERVICE_LOCATION` to `AndroidManifest.xml`.
- Whitelist the app from battery optimisation in device settings.
- On Xiaomi / Huawei / Samsung, manually allow background activity in system settings.

**Permission dialog does not appear**
- All required permissions must be declared in `AndroidManifest.xml`.
- On Android 10+, call `requestLocationPermissions()` first, then `requestAlwaysLocationPermissions()` separately.
- If the user selected "Don't ask again", redirect them to app settings.

**Gradle build fails — SDK not found**
- Ensure `maven { url 'https://jitpack.io' }` is inside `allprojects { repositories { ... } }`.

### iOS

**Location stops updating in background**
- `UIBackgroundModes` must contain `location` in `Info.plist`.
- User must have granted "Always" permission.
- `backgroundMode: true` must be set in `LocationTrackingConfig`.

**Permission dialog does not appear**
- All three `NSLocation*` keys must be present with non-empty strings.
- Duplicate keys with empty values silently override valid ones — check for duplicates.
- Do not request permissions before the first frame is rendered.

**pod install fails**
- Run `pod repo update` then `pod install`.
- `Podfile` must specify `platform :ios, '15.0'` or higher.

**`FileSystemException: Failed to decode data using encoding 'utf-8'`**
- Occurs when the project lives on a non-APFS volume (e.g. ExFAT). macOS creates `._*` resource-fork files that CocoaPods reads as text.
- Add this inside your `post_install` block in `ios/Podfile`:
```ruby
Dir.glob(File.join(installer.sandbox.root, '**', '._*')).each { |f| FileUtils.rm_f(f) }
```

---

## Architecture

```
┌──────────────────────────────────────────────┐
│                 Flutter App                  │
│         VietmapTrackingController            │
├──────────────────────────────────────────────┤
│          Platform Interface (Dart)           │
│   MethodChannel: vietmap_tracking_plugin     │
│   EventChannel:  /location_updates          │
│   EventChannel:  /tracking_status           │
├─────────────────────┬────────────────────────┤
│  iOS Native Bridge  │ Android Native Bridge  │
│   (Swift)           │  (Kotlin)              │
├─────────────────────┼────────────────────────┤
│ VietmapTrackingSDK  │ VietmapTrackingSDK     │
│ 1.3.5 (CocoaPods)   │ 1.3.7                  │
└─────────────────────┴────────────────────────┘
```

---

## Documentation

- [Changelog](./CHANGELOG.md)
- [Testing Guide](./TESTING_GUIDE.md)

## Contributing

Contributions are welcome — please submit a pull request with a clear description of the change.

## License

MIT — see [LICENSE](LICENSE).
