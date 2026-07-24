# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

---

## [1.1.2] - 2026-07-24

### Added

- **Tracking-interrupted events** — a new `onTrackingInterrupted` stream reports when background tracking stops producing GPS while a session is still active, and again when it recovers. Each event is a `TrackingInterruptedEvent` carrying `reason`, `recovered`, `isInBackground` and `secondsSinceLastFix`. The `reason` is SDK-owned and matches one of the `TrackingInterruptedReason` constants: `locationUnavailable`, `providerDisabled`, `paused`, `authDowngraded`, `authDenied`, `locationServicesOff`, `permissionRevoked`, `staleNoUpdates`. Use it to prompt the user to re-activate tracking (stop + start), since the OS will not resume on its own.
- **Interrupted-notification controls** — `setTrackingInterruptedNotificationEnabled(bool)` toggles the local notification the native SDK shows on interruption, and `setTrackingInterruptedNotificationConfig(title:, message:)` customises its text. The `onTrackingInterrupted` stream keeps firing even when the notification is disabled.

### Fixed

- **iOS never delivered tracking-interrupted events** — the native SDK emitted them, but the iOS plugin never bound the SDK's `onTrackingInterrupted` callback and did not handle the two notification-config method calls, so the events were dropped before reaching Dart and the notification toggle silently did nothing. The events surfaced on Android only. The iOS bridge is now wired, matching the Android behaviour and payload.
- **Stale preset unit tests** — the `TrackingPresets` tests asserted values from a much older preset design and had been failing; they now assert the shipped values.

### Changed

- **Distance presets respread to respect the SDK's 25 m floor** — the native SDK clamps `distanceFilter` up to a 25 m minimum, which silently collapsed `navigationDistance` (5 m) and `fitnessDistance` (10 m) into the same effective 25 m. The set is now `navigationDistance` 25 m, `fitnessDistance` 50 m, `generalDistance` 70 m (was 30 m) and `batterySaverDistance` 120 m (was 100 m) — every step is distinct and matches what the SDK actually applies.
- **`batterySaver()` interval lowered from 10 minutes to 5 minutes** — the gap to `general()` (30 s) was too wide to be a useful next step.
- **Native SDK update** — Upgraded the iOS native dependency to `1.5.0` and the Android native tracking SDK dependency to `1.5.1`.

---

## [1.1.1] - 2026-06-29

### Added

- **Speed fallback for devices that report no/zero speed** — On some devices (notably Xiaomi/MIUI under aggressive battery management) GPS fixes arrive without a valid speed, or with `speed = 0` while the vehicle is clearly moving, so the server recorded `0`. The native SDK now **derives the speed** from the Haversine distance to the previous fix over the elapsed time when the OS speed is missing or implausibly low versus the actual movement. It is validated against fix accuracy and time gap and passed through a sliding-window outlier clamp so a single GPS jump cannot produce a spike; a valid hardware speed is always trusted and truly stationary fixes stay `0`. Enabled by default — toggle with `LocationTrackingConfig(enableSpeedFallback: false)` to keep the raw OS speed. Each uploaded record is tagged under `metadata.speedSource`: `gps` (hardware), `derived` (computed, OS gave none), `corrected` (OS speed ~0 while moving → computed), or `unknown` (no speed and could not be derived).

### Changed

- **Native SDK update** — Upgraded the Android native tracking SDK dependency to `1.4.9` and the iOS native dependency to `1.4.8`.

---

## [1.1.0] - 2026-06-22

### Fixed

- **Crash on Android 10/11/12 (`NoSuchMethodError: readAllBytes`)** — The native tracking SDK read HTTP responses with `InputStream.readAllBytes()`, an API only available from Android 13 (API 33). On Android 10–12 (API 29–32) this threw a fatal `java.lang.NoSuchMethodError` when the SDK read response bodies — e.g. while fetching `app-config` during initialization and while calling `getTrackingHistory()`. Replaced with an API-level-compatible byte reader, restoring support for Android 10 and above.

### Changed

- **Native SDK update** — Upgraded the Android native tracking SDK dependency to `1.4.8`.

---

## [1.0.9] - 2026-06-20

### Changed

- **`getCurrentLocation()` now resolves an on-demand fix** — the method no longer depends on an active tracking session. It actively obtains the current device location (working even before `startTracking()`), falling back through in-memory cache → system last-known → a fresh active fix. Returns a meaningful error (`LOCATION_PERMISSION_DENIED`, `LOCATION_DISABLED`, `LOCATION_TIMEOUT`) instead of a generic "no location available" when a fix cannot be obtained.
- **Native SDK update** — Upgraded the Android native tracking SDK dependency to `1.4.7`.

---

## [1.0.8] - 2026-06-09

### Added

- **`setAppSignature(signature)`** — New API to set a custom application signature token. This signature is sent via the `X-App-Signature` HTTP header when dynamically retrieving configuration from the backend.

### Changed

- **Firebase SDK Removal** — Completely removed Firebase dependencies (`firebase_core`, `firebase_remote_config`) and options initialization from the tracking plugin controller and the example app. Configuration, including SSL pinning certificate hashes, is now resolved and cached dynamically by native HTTP requests.
- **Native SDK updates** — Upgraded the Android native tracking SDK dependency to `1.4.6` and the iOS native dependency to `1.4.7`.
- **Dynamic configuration resolution** — Added domain normalization mapping in the native SDK layer for `app-config` retrieval when standard base URLs are supplied.

### Fixed

- **iOS bridging cleanup** — Cleaned up redundant local parameter checking and helper variables in `VietmapTrackingPlugin.swift` for cleaner Swift optional type integration.

## [1.0.7] - 2026-05-12

### Added

- **`setFakeGpsNotificationConfig(title, message)`** — New SDK-level API to customise the title and body of the native fake GPS notification. The notification is issued directly by the native SDK (fires even when the app is killed) and is now configurable at runtime without re-initialising the SDK.

### Changed

- **Native SDK update** — Android upgraded to `vietmap-tracking-sdk-android:1.4.4`; iOS upgraded to `VietmapTrackingSDK 1.4.3`.
- **Fake GPS notification** — Removed duplicate notification: previously both `flutter_local_notifications` and the native SDK fired separate alerts on fake GPS detection. The SDK's own native notification is now the single source of truth. `flutter_local_notifications` is retained only for runtime permission requests.
- **`SmartBatteryManager.disable()`** — Now resets the internal moving/still profile back to idle so the next `enable()` call starts from a clean state.

### Fixed

- **`TrackingPresets` doc comments** — Interval descriptions now accurately reflect the actual `intervalMs` values: `navigation` = 5 s, `fitness` = 10 s, `general` = 30 s, `batterySaver` = 10 min.


---

## [1.0.6] - 2026-05-04

### Changed

- **Default tracking config** — Default mode now uses `TrackingPresets.general()` (10s interval / 15m distance) for consistent and predictable behaviour across devices.
- **Fake GPS UI** — Policy controls and Allow Mock toggle are disabled when using default config mode to prevent accidental misconfiguration.
- **iOS minimum deployment target** — Updated to iOS 15.0 to align with VietmapTrackingSDK requirements.

---

## [1.0.5] - 2026-05-02

### Changed

- **Fake GPS checking** — Added support for detecting and validating fake GPS usage during tracking flows.

---

## [1.0.4] - 2026-05-02

### Changed

- **Battery optimization** — Further optimized tracking behavior to reduce power consumption on devices while maintaining stable location updates.

---

## [1.0.3] - 2026-04-30

### Changed

- **Battery optimization** — Improved battery efficiency by optimizing GPS tracking intervals and reducing background wakeups.

### Fixed

- **Bug fixes** — Various stability improvements and bug fixes.

---

## [1.0.2] - 2026-04-28

### Added

- **Flutter wrapper API** — Added `VietmapTrackingPlugin` for `configureTracking`, `configureAlertAPI`, `configureZoneNetworkV2`, `resetZoneNetworkV2`, `startAlert`, `stopAlert`, and the new event streams.
- **Auth mode toggle** — Example app/provider can now switch tracking auth between header and query parameter via a single code flag.
- **Unit tests** — Added deterministic tests for the method channel routing and the new wrapper config methods.
- **GPS payload contract v1.2** — Updated `LocationData` model to support new SDK payload format.

### Changed

- **LocationData serialization** — `toJson()` now outputs GPS payload following new SDK contract (v1.2+) with `time`, int `speed`, and 12dp `lat`/`lng`.
- **LocationData deserialization** — `fromJson()` accepts both old keys (`timestamp`, `latitude`, `longitude`, `bearing`) and new keys (`time`, `lat`, `lng`, `heading`) for backward compatibility.

### Fixed

- **Test stability** — Removed `flutter_dotenv` dependency from unit-test key constants so tests can run without local `.env` files.
- **Speed serialization** — Speed values now correctly converted to integer (0–32767) instead of float to match native SDK contract.
- **Coordinate precision** — Latitude/longitude now rounded to 12 decimal places (~1.1mm precision) for consistency with SDK expectations.

---

## [1.0.1] - 2026-04-24

### Change

- Improve battery efficiency for devices by optimizing background tracking intervals and reducing wakeups.
- Reduce unnecessary location requests when tracking is idle or paused.
- Add offline tracking support to queue location events when the network is unavailable.
- Retry queued uploads automatically when connectivity is restored.
- Improve tracking stability when switching between foreground and background.

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