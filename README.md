# vietmap_tracking_plugin

[![pub package](https://img.shields.io/pub/v/vietmap_tracking_plugin.svg)](https://pub.dev/packages/vietmap_tracking_plugin)
[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](https://opensource.org/licenses/MIT)
[![Platform](https://img.shields.io/badge/platform-android%20%7C%20ios-blue.svg)](https://pub.dev/packages/vietmap_tracking_plugin)

A Flutter plugin for GPS location tracking powered by **VietmapTrackingSDK**. Supports real-time background tracking, speed alerts, offline cache with auto-sync, fake GPS detection, and smart battery optimization. Built on native platform channels (MethodChannel + EventChannel) — no third-party location wrappers.

> **Contact Vietmap** to obtain an API key before integrating: [maps.info@vietmap.vn](mailto:maps.info@vietmap.vn)

---

## Table of Contents

- [Features](#features)
- [Requirements](#requirements)
- [Installation](#installation)
- [Android Setup](#android-setup)
- [iOS Setup](#ios-setup)
- [Quick Start](#quick-start)
- [Tracking Modes & Presets](#tracking-modes--presets)
- [Fake GPS Detection](#fake-gps-detection)
- [Speed Alert System](#speed-alert-system)
- [Offline Cache & Sync](#offline-cache--sync)
- [Smart Battery Optimization](#smart-battery-optimization)
- [API Reference](#api-reference)
- [Data Models](#data-models)
- [Utility Functions](#utility-functions)
- [Architecture](#architecture)
- [Troubleshooting](#troubleshooting)

---

## Features

| Feature | Description |
|---------|-------------|
| Background GPS | Foreground service (Android) / background location mode (iOS) |
| API Key Validation | `initializeTracking` validates server-side — throws `INVALID_API_KEY` on failure |
| Metadata Attachment | `setMetadata` stamps every GPS record with arbitrary key-value pairs |
| Speed Alerts | Real-time speed monitoring via configurable Alert API |
| Offline Cache | SQLite cache with auto-upload when network recovers |
| Fake GPS Detection | Native detection with 4 configurable response policies; SDK issues its own notification even when app is killed |
| Smart Battery | Auto-adjusts tracking precision based on battery level and movement |
| Tracking Presets | Navigation / Fitness / General / BatterySaver — interval and distance variants |
| Location Utilities | Haversine distance, speed conversion, geofence check |

---

## Requirements

| | Minimum |
|---|---|
| Flutter | 3.3.0+ |
| Dart | 3.8.0+ |
| iOS | 15.0+ |
| Android | API 21 (Android 5.0+) |

**Native SDKs**

| Platform | SDK | Version |
|----------|-----|---------|
| iOS | VietmapTrackingSDK (CocoaPods) | 1.4.3 |
| Android | com.github.vietmap-company:vietmap-tracking-sdk-android | 1.4.4 |

---

## Installation

```yaml
dependencies:
  vietmap_tracking_plugin: ^1.0.7
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
<!-- Required for showing notifications on Android 13+ -->
<uses-permission android:name="android.permission.POST_NOTIFICATIONS" />
<!-- Required to reschedule notifications after device reboot -->
<uses-permission android:name="android.permission.RECEIVE_BOOT_COMPLETED" />
```

> **Android 10+ (API 29+):** `ACCESS_BACKGROUND_LOCATION` must be requested **after** foreground location is granted. The plugin handles this two-step flow automatically.

### 2. Foreground Service Notification receivers (`<application>` block)

Required for `flutter_local_notifications` runtime permission requests:

```xml
<receiver android:exported="false"
    android:name="com.dexterous.flutterlocalnotifications.ScheduledNotificationReceiver" />
<receiver android:exported="false"
    android:name="com.dexterous.flutterlocalnotifications.ScheduledNotificationBootReceiver">
    <intent-filter>
        <action android:name="android.intent.action.BOOT_COMPLETED"/>
        <action android:name="android.intent.action.MY_PACKAGE_REPLACED"/>
        <action android:name="android.intent.action.QUICKBOOT_POWERON" />
        <action android:name="com.htc.intent.action.QUICKBOOT_POWERON"/>
    </intent-filter>
</receiver>
<receiver android:exported="false"
    android:name="com.dexterous.flutterlocalnotifications.ActionBroadcastReceiver" />
```

### 3. Maven repository (`android/build.gradle`)

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

### 2. Background Modes (`ios/Runner/Info.plist`)

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

### 4. Foreground Notifications (`ios/Runner/AppDelegate.swift`)

By default iOS suppresses notification banners when the app is in the foreground. Two changes are required:

1. Set `UNUserNotificationCenter.current().delegate = self` **before** `GeneratedPluginRegistrant.register(with: self)`.
2. Override `userNotificationCenter(_:willPresent:)` and call `completionHandler([.banner, .sound, .badge])` directly — **do not call `super`**.


### 5. CocoaPods

```ruby
# ios/Podfile
platform :ios, '15.0'
```

```bash
cd ios && pod install
```

> **First install:** run `pod install --repo-update` to ensure `VietmapTrackingSDK` resolves from the latest spec repo.

---

## Quick Start

### 1. Initialize the plugin (once, before `runApp`)


### 2. Configure the SDK

```dart
import 'package:flutter/services.dart';
import 'package:vietmap_tracking_plugin/vietmap_tracking_plugin.dart';

final controller = VietmapTrackingController.instance;

Future<void> initSdk() async {
  try {
    // Validates API key server-side — throws INVALID_API_KEY if rejected
    await controller.initializeTracking(
      'YOUR_API_KEY',
      baseURL: 'https://live.fleetwork.vn/api/v1', // optional
    );
    // Register lifecycle observer for background/foreground transitions
    controller.registerLifecycleObserver();
  } on PlatformException catch (e) {
    if (e.code == 'INVALID_API_KEY') {
      print('Invalid API key: ${e.message}');
    }
  }
}
```

### 3. Request Permissions

```dart
// Step 1 — foreground location
final result = await controller.requestLocationPermissions();
if (!result.granted) return;

// Step 2 — background location (Android 10+ requires separate prompt)
await controller.requestAlwaysLocationPermissions();

// Step 3 — notification permission (Android 13+ / iOS)
// Android
await Permission.notification.request();
// iOS
await FlutterLocalNotificationsPlugin()
    .resolvePlatformSpecificImplementation<IOSFlutterLocalNotificationsPlugin>()
    ?.requestPermissions(alert: true, sound: true, badge: false);
```

### 4. Start Tracking

> **`userId` is required** — GPS records are keyed to this value server-side. Omitting it will cause records to be unattributed.

```dart
await controller.startTracking(
  LocationTrackingConfig(
    userId: 'user-123',            // required
    intervalMs: 30000,             // 30 s interval
    accuracy: LocationAccuracy.high,
    backgroundMode: true,
    notificationTitle: 'GPS Tracking Active',
    notificationMessage: 'Your location is being recorded',
  ),
);

// Or use a preset:
await controller.startTracking(
  TrackingPresets.general().copyWith(userId: 'user-123'),
);
```

### 5. Listen for Updates

```dart
controller.onLocationUpdate.listen((LocationData loc) {
  print('${loc.latitude}, ${loc.longitude} @ ${loc.speed} m/s');
});

controller.onTrackingStatusChanged.listen((TrackingStatus s) {
  print('Tracking: ${s.isTracking}');
});

controller.onFakeGpsDetected.listen((FakeGpsEvent ev) {
  print('Fake GPS at ${ev.lat}, ${ev.lng}');
});
```

### 6. Stop Tracking

```dart
await controller.stopTracking();
controller.unregisterLifecycleObserver();
```

---

## Tracking Modes & Presets

`LocationTrackingConfig` supports two mutually exclusive tracking strategies. Pass **only one** of `intervalMs` or `distanceFilter`; set the other to `null`.

| Mode | `intervalMs` | `distanceFilter` | Behaviour |
|------|-------------|------------------|-----------|
| **Interval (timer-driven)** | `> 0` | `null` | Update every N milliseconds regardless of movement |
| **Distance** | `null` | `> 0` | Update only after the device has moved M metres |

### Pre-built Presets

#### Interval-based

```dart
TrackingPresets.navigation()    //  5 s  — real-time vehicle / turn-by-turn
TrackingPresets.fitness()       // 10 s  — outdoor activities
TrackingPresets.general()       // 30 s  — balanced fleet tracking (default)
TrackingPresets.batterySaver()  // 10 min — parked or low-battery assets
```

#### Distance-based

```dart
TrackingPresets.navigationDistance()    // every   5 m
TrackingPresets.fitnessDistance()       // every  10 m
TrackingPresets.generalDistance()       // every  30 m
TrackingPresets.batterySaverDistance()  // every 100 m
```

Always attach `userId` via `copyWith`:

```dart
await controller.startTracking(
  TrackingPresets.general().copyWith(userId: 'user-123'),
);
```

---

## Fake GPS Detection

The native SDK detects mock/spoofed locations independently. Even when the app is killed, the SDK issues its own notification via the Android `VietmapTracking` notification channel (no dependency on `flutter_local_notifications`).

### Configure the notification content

```dart
await controller.setFakeGpsNotificationConfig(
  title: 'Fake GPS Detected',
  message: 'Please disable mock locations to ensure accurate tracking.',
);
```

> Call this after `initializeTracking`. The config is persisted by the SDK for the lifetime of the process (including background/killed scenarios on Android).

### Set a policy

```dart
await controller.setFakeGpsPolicy(FakeGpsPolicy.warn);

controller.onFakeGpsDetected.listen((FakeGpsEvent ev) {
  print('Fake GPS: lat=${ev.lat}, lng=${ev.lng}, reason=${ev.reason}');
});
```

| Policy | Behaviour |
|--------|-----------|
| `skip` | Emit event only — no notification, no stop. **Default.** |
| `warn` | SDK issues a native notification (debounced 30 s per window) |
| `stopTracking` | Auto-stop tracking on first detection |
| `logToServer` | Upload record with `is_fake=1` + `X-Fake-GPS: true` header |

### Enable detection

Fake GPS detection is disabled by default (`allowMockLocation: true`). To enable it:

```dart
await controller.startTracking(
  TrackingPresets.general().copyWith(
    userId: 'user-123',
    allowMockLocation: false, // enables native fake GPS checks
  ),
);
await controller.setFakeGpsPolicy(FakeGpsPolicy.warn);
```

### iOS note

On iOS the app icon always appears as the notification icon. The `reason` field in `FakeGpsEvent` can be `"simulatedBySoftware"` or `"producedByAccessory"`.

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
// Disable auto-upload to take manual control
await controller.setAutoUpload(false);

final pending = await controller.getCachedLocationsCount();
final sizeBytes = await controller.getDatabaseSizeBytes();

// Configure limits
await controller.configureCacheLimits(
  maxRecords: 5000,
  maxDbSizeBytes: 50 * 1024 * 1024, // 50 MB
  batchSize: 50,
);

// Upload and clear
await controller.uploadCachedLocationsManually();
await controller.clearCachedLocations();
```

---

## Smart Battery Optimization

Smart Battery is **automatically started** with `startTracking()` and **stopped** with `stopTracking()`. No manual enable/disable needed.

```dart
// Set preferred profile for moving sessions (default: general)
controller.setSmartBatteryPreferredProfile(SmartBatteryProfile.navigation);

// Listen for profile changes
controller.onSmartBatteryProfileChanged.listen((profile) {
  print('Battery profile: $profile');
});
```

| Profile | Interval | Use case |
|---------|----------|----------|
| `navigation` | 5 s | Turn-by-turn, high accuracy |
| `general` | 30 s | Standard fleet tracking |
| `batterySaver` | 10 min | Low battery / parked |

The manager switches profiles automatically:
- Battery < 15% + not charging → `batterySaver`
- Vehicle stationary ≥ 60 s → `general`
- Vehicle cornering (heading delta > 15°) → `navigation`
- Otherwise → `preferredMovingProfile` (default: `general`)

### Custom config and Smart Battery

Smart Battery is always active during tracking and will silently override the native tracking interval whenever a profile transition occurs (low battery, stationary, cornering). When using a standard preset this is the intended behaviour. When using a custom `LocationTrackingConfig` with non-preset values, you must register a `customGeneralConfigOverride` callback **before** calling `startTracking()` to prevent Smart Battery from replacing your config with a native preset.

```dart
// Register before startTracking — tells Smart Battery to re-apply your config
// instead of switching to a native preset on any profile transition.
SmartBatteryManager.instance.customGeneralConfigOverride = () async {
  await controller.updateTrackingConfig(myCustomConfig);
};

await controller.startTracking(myCustomConfig);
```

Clear the override when stopping to avoid it persisting across sessions:

```dart
await controller.stopTracking();
SmartBatteryManager.instance.customGeneralConfigOverride = null;
```

> **Note:** The callback is invoked for every profile transition — including `batterySaver` and `navigation` — so Smart Battery continues to detect and report profile changes via `onSmartBatteryProfileChanged`, but the actual tracking interval is always governed by your config.

---

## API Reference

### Initialization

| Method | Description |
|--------|-------------|
| `initializeTracking(apiKey, {baseURL})` | Validates key server-side. Throws `INVALID_API_KEY` on failure. |
| `setMetadata(Map)` | Stamps every GPS record with arbitrary key-value pairs. |
| `configureAlertAPI(apiKey, apiID)` | Configures speed alert credentials. |
| `setFakeGpsNotificationConfig({title, message})` | Customises SDK native fake GPS notification. |
| `registerLifecycleObserver()` | Enables automatic background/foreground SDK transitions. |

### Tracking Control

| Method | Returns | Description |
|--------|---------|-------------|
| `startTracking(config)` | `bool` | Start GPS tracking. `userId` in config is required. |
| `stopTracking()` | `bool` | Stop tracking; SDK may flush pending records. |
| `isTrackingActive()` | `bool` | Whether tracking is currently running. |
| `getCurrentLocation()` | `LocationData?` | Most recent known location. `null` if no fix yet. |
| `getTrackingStatus()` | `TrackingStatus` | Live status snapshot. |
| `updateTrackingConfig(config)` | `bool` | Apply new config to running session. See platform note. |
| `getTrackingHealthStatus()` | `Map` | Diagnostic snapshot: network, cache, SDK flags. |

> **`updateTrackingConfig` — iOS caveat:** iOS performs `stop → start` internally. Side-effects: brief location gap, `trackingDuration` resets, status stream emits `false → true`.

### Permissions

```dart
await controller.requestLocationPermissions();          // → PermissionResult
await controller.hasLocationPermissions();              // → PermissionResult
await controller.requestAlwaysLocationPermissions();   // → String status
```

### Fake GPS

```dart
await controller.setFakeGpsPolicy(String policy);
await controller.setFakeGpsNotificationConfig({required String title, required String message});
controller.onFakeGpsDetected  // → Stream<FakeGpsEvent>
```

### Event Streams

```dart
controller.onLocationUpdate           // Stream<LocationData>
controller.onTrackingStatusChanged    // Stream<TrackingStatus>
controller.onFakeGpsDetected          // Stream<FakeGpsEvent>
controller.onSmartBatteryProfileChanged // Stream<SmartBatteryProfile>
```

### Cache & Sync

```dart
await controller.setAutoUpload(bool);
await controller.isNetworkConnected();               // → bool
await controller.getCachedLocationsCount();          // → int
await controller.getDatabaseSizeBytes();             // → int
await controller.uploadCachedLocationsManually();
await controller.clearCachedLocations();
await controller.configureCacheLimits(
  maxRecords: int,
  maxDbSizeBytes: int,
  batchSize: int,
);
```

### History

```dart
final List<GpsLocation> history = await controller.getTrackingHistory(
  userId: 'user-123',
  fromTimestamp: DateTime(2026, 5, 1).millisecondsSinceEpoch, // optional
  toTimestamp: DateTime(2026, 5, 12).millisecondsSinceEpoch,  // optional
  pageNumber: 1,
  pageSize: 50,
  sortDescending: true,
);
```

---

## Data Models

### `LocationTrackingConfig`

| Field | Type | Default | Description |
|-------|------|---------|-------------|
| **`userId`** | `String?` | `null` | **Required.** GPS records are keyed to this value. |
| `vehicleId` | `String?` | `null` | Optional vehicle identifier. |
| `intervalMs` | `int?` | `null` | Timer mode: update every N ms. |
| `distanceFilter` | `double?` | `null` | Distance mode: update after M metres. |
| `accuracy` | `LocationAccuracy` | `high` | `high` / `medium` / `low` |
| `backgroundMode` | `bool` | `true` | Continue tracking in background. |
| `notificationTitle` | `String?` | — | Android foreground service notification title. |
| `notificationMessage` | `String?` | — | Android foreground service notification body. |
| `allowMockLocation` | `bool` | `true` | `false` to enable native fake GPS detection. |

### `LocationData`

```
latitude, longitude  — degrees (double)
altitude             — metres above sea level
accuracy             — horizontal accuracy in metres
speed                — m/s
bearing              — heading 0–360° (0 = North)
timestamp            — Unix milliseconds
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

### `FakeGpsEvent`

```
lat, lng             — spoofed coordinate
timestamp            — Unix seconds
isFirstDetection     — bool (first in 30s debounce window)
reason               — iOS only: "simulatedBySoftware" | "producedByAccessory"
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
// Haversine distance (metres)
LocationUtils.calculateDistance(lat1, lng1, lat2, lng2);
LocationUtils.distanceBetween(location1, location2);

// Coordinate formatting
LocationUtils.formatCoordinates(21.0285, 105.8542);
// → "21.028500° N, 105.854200° E"

// Speed conversion
LocationUtils.metersPerSecondToKmh(25.0);  // → 90.0
LocationUtils.kmhToMetersPerSecond(90.0);  // → 25.0

// Geofence check
LocationUtils.isWithinRadius(location, targetLat, targetLng, radiusMetres);
```

---

## Architecture

```
┌──────────────────────────────────────────────────┐
│                   Flutter App                    │
│          VietmapTrackingController               │
│          SmartBatteryManager                     │
├──────────────────────────────────────────────────┤
│           Platform Interface (Dart)              │
│    MethodChannel: vietmap_tracking_plugin        │
│    EventChannel:  /location_updates              │
│    EventChannel:  /tracking_status               │
│    EventChannel:  /fake_gps                      │
├──────────────────────┬───────────────────────────┤
│   iOS Native Bridge  │  Android Native Bridge    │
│   Swift              │  Kotlin                   │
├──────────────────────┼───────────────────────────┤
│  VietmapTrackingSDK  │  vietmap-tracking-sdk     │
│  1.4.5 (CocoaPods)   │  1.4.4 (JitPack)          │
└──────────────────────┴───────────────────────────┘
```

---

## Troubleshooting

### Android

**Background tracking stops unexpectedly**
- Declare `FOREGROUND_SERVICE` + `FOREGROUND_SERVICE_LOCATION` in `AndroidManifest.xml`.
- Whitelist the app from battery optimisation in device settings.
- On Xiaomi / Huawei / Samsung, manually allow background activity in system settings.

**Fake GPS notification doesn't appear**
- Ensure `POST_NOTIFICATIONS` is in the manifest and granted at runtime (Android 13+).
- On MIUI: Settings → Apps → [App] → Notifications → enable "Floating notifications".

**Gradle build fails — SDK not found**
- Confirm `maven { url 'https://jitpack.io' }` is inside `allprojects { repositories { ... } }`.

### iOS

**Location stops updating in background**
- `UIBackgroundModes` must contain `location`.
- User must have granted "Always" permission.
- `backgroundMode: true` must be set in `LocationTrackingConfig`.

**Notification banner not showing while app is in foreground**
- Verify `UNUserNotificationCenter.current().delegate = self` is set **before** `GeneratedPluginRegistrant.register`.
- `willPresent` override must call `completionHandler([.banner, .sound, .badge])` — do **not** call `super`.

**`pod install` fails**
- Run `pod repo update` then `pod install`.
- `Podfile` must specify `platform :ios, '15.0'` or higher.

**`FileSystemException: Failed to decode data using encoding 'utf-8'`**
- Occurs when project is on a non-APFS volume (e.g. ExFAT). Add this to `ios/Podfile`:

```ruby
post_install do |installer|
  Dir.glob(File.join(installer.sandbox.root, '**', '._*')).each { |f| FileUtils.rm_f(f) }
end
```

---

## Testing

```bash
# Dart unit tests
flutter test

# Android JVM unit tests
cd example/android && ./gradlew :vietmap_tracking_plugin:testDebugUnitTest

# Flutter integration tests (requires device/emulator)
cd example && flutter test integration_test/

# iOS unit tests
cd example/ios
xcodebuild test \
  -workspace Runner.xcworkspace \
  -scheme Runner \
  -destination 'platform=iOS Simulator,name=iPhone 16'
```

---

## Documentation

- [Changelog](./CHANGELOG.md)
- [Testing Guide](./TESTING_GUIDE.md)

## Contributing

Contributions are welcome — please submit a pull request with a clear description of the change.

## License

MIT — see [LICENSE](LICENSE).

