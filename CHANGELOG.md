# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

---

## [Unreleased]

### Added

- **Flutter wrapper API** — Added `VietmapTrackingPlugin` for `configureTracking`, `configureAlertAPI`, `configureZoneNetworkV2`, `resetZoneNetworkV2`, `startAlert`, `stopAlert`, and the new event streams.
- **Auth mode toggle** — Example app/provider can now switch tracking auth between header and query parameter via a single code flag.
- **Unit tests** — Added deterministic tests for the method channel routing and the new wrapper config methods.
- **GPS payload contract v1.2** — Updated `LocationData` model to support new SDK payload format:
  - `time` field (Unix milliseconds) instead of `timestamp`
  - `lat`/`lng` rounded to 12 decimal places for higher precision
  - `speed` converted to `int` and clamped to 0–32767 (m/s)
  - `metaData` optional JSON object support
  - Full backward compatibility with old payload format during read
- **SDK migration guide** — Comprehensive documentation in `SDK_CONTRACT_UPDATE.md` covering payload contract changes, Flutter implementation steps, auth mode usage, network inspection tips, and troubleshooting.

### Changed

- **LocationData serialization** — `toJson()` now outputs GPS payload following new SDK contract (v1.2+) with `time`, int `speed`, and 12dp `lat`/`lng`.
- **LocationData deserialization** — `fromJson()` accepts both old keys (`timestamp`, `latitude`, `longitude`, `bearing`) and new keys (`time`, `lat`, `lng`, `heading`) for backward compatibility.
- **SLC example integration** — Temporarily disabled the iOS SLC demo/configuration path until the upgraded SDK exposes the final API.

### Fixed

- **Test stability** — Removed `flutter_dotenv` dependency from unit-test key constants so tests can run without local `.env` files.
- **Speed serialization** — Speed values now correctly converted to integer (0–32767) instead of float to match native SDK contract.
- **Coordinate precision** — Latitude/longitude now rounded to 12 decimal places (~1.1mm precision) for consistency with SDK expectations.

## [1.0.0] - 2026-02-27

### Added

- **Native SDK Integration** — Direct bridge to VietmapTrackingSDK via platform channels (MethodChannel + EventChannel) on both iOS and Android. No third-party location wrappers.
- **iOS Bridge** (`VietmapTrackingPlugin.swift`) — Full implementation of all plugin methods: `configure`, `configureAlertAPI`, `requestLocationPermissions`, `hasLocationPermissions`, `requestAlwaysLocationPermissions`, `startTracking`, `stopTracking`, `getCurrentLocation`, `isTrackingActive`, `getTrackingStatus`, `updateTrackingConfig`, `turnOnAlert`, `turnOffAlert`.
- **Android Bridge** (`VietmapTrackingPlugin.kt`) — Full implementation matching iOS feature parity, including EventChannel support for location updates and tracking status, and the two-step background permission flow for Android 10+.
- **EventChannel Streams** — `onLocationUpdate` (`Stream<LocationData>`) and `onTrackingStatusChanged` (`Stream<TrackingStatus>`) for real-time event delivery from native SDK to Dart.
- **Speed Alert System** — `turnOnAlert()` and `turnOffAlert()` methods bridging to native SDK alert functionality. Requires separate Alert API credentials via `configureAlertAPI()`.
- **Tracking Presets** — `TrackingPresets.navigation()`, `TrackingPresets.fitness()`, `TrackingPresets.general()`, `TrackingPresets.batterySaver()` with pre-tuned parameters.
- **Permission Management** — Unified `PermissionResult` model with detailed fields: `granted`, `status`, `fineLocation`, `coarseLocation`, `backgroundLocation`.
- **Location Utilities** — `LocationUtils` class with Haversine distance calculation, speed conversion, coordinate formatting, and radius checking.
- **Dart Unit Tests** — 89 tests covering method channel routing, model serialization/deserialization, and platform interface contract.
- **iOS XCTests** — Comprehensive test suite in `RunnerTests.swift` covering all bridge methods, error handling, and data structure validation.
- **Android JVM Unit Tests** — `VietmapTrackingPluginTest.kt` with tests for method routing, argument validation, guard checks, and data structure validation.
- **Android Instrumented Tests** — `VietmapTrackingPluginInstrumentedTest.kt` for testing with real SDK on device/emulator.

### Architecture

```
Flutter App (Dart)
  └── VietmapTrackingController (singleton)
        └── VietmapTrackingPlatform (platform interface)
              └── MethodChannelVietmapTracking
                    ├── MethodChannel: vietmap_tracking_plugin
                    ├── EventChannel: /location_updates
                    └── EventChannel: /tracking_status
                          ├── iOS: VietmapTrackingPlugin.swift → VietmapTrackingSDK 1.1.6
                          └── Android: VietmapTrackingPlugin.kt → VietmapTrackingSDK 1.2.2
```

### Platform Support

- **iOS**: 11.0+ (VietmapTrackingSDK via CocoaPods xcframework)
- **Android**: API 21+ (VietmapTrackingSDK via JitPack)
- **Flutter**: 3.3.0+
- **Dart**: 3.8.0+

### Dependencies

- `plugin_platform_interface: ^2.0.2`
- `background_location_2: ^0.16.3`
- `connectivity_plus: ^6.1.4`
- `flutter_background_service: ^5.1.0`
- `flutter_local_notifications: ^19.3.0`
- `geolocator: ^14.0.1`
- `http: ^1.1.0`
- `shared_preferences: ^2.5.3`

### Notes

- `updateTrackingConfig()` internally performs `stopTracking()` followed by `startTracking(newConfig)`. This resets the tracking session. See README for details.
- Android background location permission follows the two-step flow required by Android 10+: foreground permission first, then background permission in a separate request.

---

## [1.0.0-alpha.1] - 2024-12-19

### Added

- Initial alpha release with basic plugin structure.
- Background location tracking via third-party packages.
- HTTP API integration with retry logic and offline caching.
- Basic permission management.
- Example application.