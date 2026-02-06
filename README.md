# Vietmap Tracking Plugin

A comprehensive Flutter plugin for GPS location tracking with VietmapTrackingSDK integration, featuring advanced background support and speed alerts.

[![pub package](https://img.shields.io/pub/v/vietmap_tracking_plugin.svg)](https://pub.dev/packages/vietmap_tracking_plugin)
[![License](https://img.shields.io/badge/License-MIT-blue.svg)](https://opensource.org/licenses/MIT)

## Features

- 🎯 **GPS Location Tracking** - Continuous location tracking with configurable accuracy
- 📡 **VietmapTrackingSDK Integration** - Native SDK integration for iOS and Android
- 🔋 **Background Tracking** - Continue tracking even when app is in background
- ⚡ **Speed Alert System** - Real-time speed monitoring
- 🎨 **Pre-configured Presets** - Navigation, Fitness, General, and Battery Saver modes
- 📍 **Permission Handling** - Automatic location permission management
- 📊 **Event Streams** - Real-time location and tracking status updates
- 💾 **Session Management** - Track session statistics and history
- 🔌 **Cross-Platform** - Works on both iOS (11.0+) and Android (API 21+)

## Installation

Add this to your package's `pubspec.yaml` file:

```yaml
dependencies:
  vietmap_tracking_plugin: ^1.0.0
```

Then run:

```bash
flutter pub get
```

## Platform Setup

### Android

Add the following permissions to your `AndroidManifest.xml`:

```xml
<manifest xmlns:android="http://schemas.android.com/apk/res/android">
    <uses-permission android:name="android.permission.INTERNET" />
    <uses-permission android:name="android.permission.ACCESS_FINE_LOCATION" />
    <uses-permission android:name="android.permission.ACCESS_COARSE_LOCATION" />
    <uses-permission android:name="android.permission.ACCESS_BACKGROUND_LOCATION" />
    <uses-permission android:name="android.permission.FOREGROUND_SERVICE" />
    <uses-permission android:name="android.permission.FOREGROUND_SERVICE_LOCATION" />
</manifest>
```

### iOS

Add the following keys to your `Info.plist`:

```xml
<key>NSLocationWhenInUseUsageDescription</key>
<string>This app needs access to location when in use.</string>
<key>NSLocationAlwaysAndWhenInUseUsageDescription</key>
<string>This app needs access to location for background tracking.</string>
<key>NSLocationAlwaysUsageDescription</key>
<string>This app needs access to location for background tracking.</string>
<key>UIBackgroundModes</key>
<array>
    <string>location</string>
</array>
```

## Quick Start

### 1. Initialize the SDK

```dart
import 'package:vietmap_tracking_plugin/vietmap_tracking_plugin.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  final controller = VietmapTrackingController.instance;
  
  // Configure with your API key
  await controller.configure(
    'YOUR_API_KEY',
    baseURL: 'https://api.vietmap.vn',
  );
  
  runApp(MyApp());
}
```

### 2. Start Tracking

```dart
// Use a pre-configured preset
final config = TrackingPresets.navigation();

// Or create custom configuration
final config = LocationTrackingConfig(
  intervalMs: 5000,
  distanceFilter: 10.0,
  accuracy: LocationAccuracy.high,
  backgroundMode: true,
  notificationTitle: 'Tracking Active',
  notificationMessage: 'Your location is being tracked',
);

// Start tracking
await controller.startTracking(config);
```

### 3. Listen to Location Updates

```dart
controller.onLocationUpdate.listen((LocationData location) {
  print('Lat: ${location.latitude}, Lng: ${location.longitude}');
  print('Speed: ${location.speed} m/s');
  print('Accuracy: ${location.accuracy} meters');
});
```

### 4. Listen to Tracking Status

```dart
controller.onTrackingStatusChanged.listen((TrackingStatus status) {
  print('Is Tracking: ${status.isTracking}');
  print('Duration: ${status.duration}');
});
```

### 5. Stop Tracking

```dart
await controller.stopTracking();
```

## API Reference

### VietmapTrackingController

Main controller for managing tracking operations.

#### Configuration

```dart
// Configure SDK
Future<bool> configure(String apiKey, {String? baseURL})

// Configure Alert API for speed monitoring
Future<bool> configureAlertAPI(String apiKey, String apiID)
```

#### Permission Management

```dart
// Request location permissions
Future<PermissionResult> requestLocationPermissions()

// Check if permissions are granted
Future<PermissionResult> hasLocationPermissions()

// Request always (background) permissions
Future<String> requestAlwaysLocationPermissions()
```

#### Tracking Operations

```dart
// Start tracking with configuration
Future<bool> startTracking(LocationTrackingConfig config)

// Stop tracking
Future<bool> stopTracking()

// Get current location (one-time fetch)
Future<LocationData> getCurrentLocation()

// Check if tracking is active
Future<bool> isTrackingActive()

// Get detailed tracking status
Future<TrackingStatus> getTrackingStatus()

// Update configuration while tracking
Future<bool> updateTrackingConfig(LocationTrackingConfig config)
```

#### Event Streams

```dart
// Location update stream
Stream<LocationData> onLocationUpdate

// Tracking status stream
Stream<TrackingStatus> onTrackingStatusChanged
```

### Models

#### LocationTrackingConfig

Configuration for location tracking:

```dart
LocationTrackingConfig({
  required int intervalMs,           // Update interval in milliseconds
  required double distanceFilter,    // Minimum distance in meters
  required LocationAccuracy accuracy, // GPS accuracy level
  required bool backgroundMode,       // Enable background tracking
  String? notificationTitle,          // Android notification title
  String? notificationMessage,        // Android notification message
})
```

#### LocationData

GPS location data:

```dart
LocationData({
  required double latitude,
  required double longitude,
  required double altitude,
  required double accuracy,
  required double speed,
  required double bearing,
  required int timestamp,
})
```

#### TrackingStatus

Tracking session status:

```dart
TrackingStatus({
  required bool isTracking,
  int? lastLocationUpdate,
  required int trackingDuration,
})
```

#### PermissionResult

Location permission status:

```dart
PermissionResult({
  required bool granted,
  required PermissionStatus status,
  required bool fineLocation,
  required bool coarseLocation,
  required bool backgroundLocation,
})
```

### Pre-configured Presets

#### Navigation Mode
High accuracy, frequent updates (3s interval, 5m distance filter):
```dart
final config = TrackingPresets.navigation();
```

#### Fitness Mode
Balanced accuracy and battery (5s interval, 10m distance filter):
```dart
final config = TrackingPresets.fitness();
```

#### General Tracking
Medium accuracy, standard updates (10s interval, 15m distance filter):
```dart
final config = TrackingPresets.general();
```

#### Battery Saver
Lower accuracy, less frequent (30s interval, 50m distance filter):
```dart
final config = TrackingPresets.batterySaver();
```

### Utility Functions

#### LocationUtils

```dart
// Calculate distance between coordinates (Haversine formula)
double calculateDistance(double lat1, double lon1, double lat2, double lon2)

// Calculate distance between LocationData objects
double distanceBetween(LocationData loc1, LocationData loc2)

// Convert speed units
double metersPerSecondToKmh(double metersPerSecond)
double kmhToMetersPerSecond(double kmh)

// Format coordinates
String formatCoordinates(double latitude, double longitude)

// Check if location is within radius
bool isWithinRadius(LocationData location, double targetLat, double targetLon, double radiusMeters)
```

## Example App

See the [example](example/) directory for a complete working example.

```dart
import 'package:flutter/material.dart';
import 'package:vietmap_tracking_plugin/vietmap_tracking_plugin.dart';

void main() => runApp(MyApp());

class MyApp extends StatefulWidget {
  @override
  _MyAppState createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  final controller = VietmapTrackingController.instance;
  LocationData? currentLocation;
  
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
  }
  
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      home: Scaffold(
        appBar: AppBar(title: Text('Vietmap Tracking')),
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text('Latitude: ${currentLocation?.latitude ?? "N/A"}'),
              Text('Longitude: ${currentLocation?.longitude ?? "N/A"}'),
              ElevatedButton(
                onPressed: () async {
                  final config = TrackingPresets.navigation();
                  await controller.startTracking(config);
                },
                child: Text('Start Tracking'),
              ),
              ElevatedButton(
                onPressed: () => controller.stopTracking(),
                child: Text('Stop Tracking'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
```

## Advanced Usage

### Custom Tracking Configuration

```dart
final customConfig = LocationTrackingConfig(
  intervalMs: 2000,           // Update every 2 seconds
  distanceFilter: 5.0,        // Minimum 5 meters movement
  accuracy: LocationAccuracy.high,
  backgroundMode: true,
  notificationTitle: 'Delivery Tracking',
  notificationMessage: 'Tracking your delivery route',
);

await controller.startTracking(customConfig);
```

### Update Configuration During Tracking

```dart
// Start with battery saver
await controller.startTracking(TrackingPresets.batterySaver());

// Switch to navigation mode
await controller.updateTrackingConfig(TrackingPresets.navigation());
```

### Handle Permissions Explicitly

```dart
// Check current permissions
final permissionResult = await controller.hasLocationPermissions();

if (!permissionResult.granted) {
  // Request permissions
  final result = await controller.requestLocationPermissions();
  
  if (!result.granted) {
    // Show error to user
    print('Location permission denied');
    return;
  }
}

// Request background permission for iOS
if (Platform.isIOS) {
  final alwaysPermission = await controller.requestAlwaysLocationPermissions();
  print('Always permission: $alwaysPermission');
}
```

### Track Distance Traveled

```dart
final List<LocationData> locations = [];
double totalDistance = 0.0;

controller.onLocationUpdate.listen((location) {
  if (locations.isNotEmpty) {
    final distance = LocationUtils.distanceBetween(
      locations.last,
      location,
    );
    totalDistance += distance;
  }
  locations.add(location);
  
  print('Total distance: ${totalDistance / 1000} km');
});
```

## Troubleshooting

### Android

**Issue**: Background tracking stops after some time
- Ensure `FOREGROUND_SERVICE` and `FOREGROUND_SERVICE_LOCATION` permissions are declared
- Add battery optimization exemption for your app

**Issue**: Location permission denied
- Check that all required permissions are in `AndroidManifest.xml`
- For Android 10+, ensure `ACCESS_BACKGROUND_LOCATION` is declared

### iOS

**Issue**: Location updates stop in background
- Ensure `UIBackgroundModes` includes `location` in `Info.plist`
- Request "Always" location permission

**Issue**: Permission dialog not showing
- Make sure all required keys are in `Info.plist`
- Check that you're calling permission requests from main thread

## Contributing

Contributions are welcome! Please feel free to submit a Pull Request.

## License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.

## Support

For issues, questions, or feature requests, please file an issue on [GitHub](https://github.com/vietmap-company/vietmap_tracking_plugin/issues).

## Related Projects

- [VietmapTrackingSDK iOS](https://github.com/vietmap-company/vietmap-tracking-sdk-ios)
- [VietmapTrackingSDK Android](https://github.com/vietmap-company/vietmap-tracking-sdk-android)

## Changelog

See [CHANGELOG.md](CHANGELOG.md) for version history and updates.
