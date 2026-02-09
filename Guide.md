# Hướng dẫn sử dụng `@vietmap/rn_vietmap_tracking_plugin`

> Package React Native cho theo dõi GPS nền với tích hợp VietmapTrackingSDK, hỗ trợ cảnh báo tốc độ và giám sát tuyến đường.

---

## 📦 Cài đặt

```bash
npm install @vietmap/rn_vietmap_tracking_plugin
```

### Cấu hình iOS

Thêm quyền vào `ios/YourProject/Info.plist`:

```xml
<key>NSLocationWhenInUseUsageDescription</key>
<string>Ứng dụng cần quyền vị trí để theo dõi GPS khi đang sử dụng.</string>
<key>NSLocationAlwaysAndWhenInUseUsageDescription</key>
<string>Ứng dụng cần quyền vị trí liên tục để theo dõi GPS ngay cả khi chạy nền.</string>
<key>NSLocationAlwaysUsageDescription</key>
<string>Ứng dụng cần quyền vị trí nền để cung cấp theo dõi GPS liên tục.</string>

<key>UIBackgroundModes</key>
<array>
    <string>location</string>
    <string>background-processing</string>
    <string>background-fetch</string>
</array>

<key>BGTaskSchedulerPermittedIdentifiers</key>
<array>
    <string>com.vietmaptrackingsdk.location-sync</string>
    <string>com.vietmaptrackingsdk.background-location</string>
</array>
```

### Cấu hình Android

Thêm quyền vào `android/app/src/main/AndroidManifest.xml`:

```xml
<uses-permission android:name="android.permission.INTERNET" />
<uses-permission android:name="android.permission.ACCESS_FINE_LOCATION" />
<uses-permission android:name="android.permission.ACCESS_COARSE_LOCATION" />
<uses-permission android:name="android.permission.ACCESS_BACKGROUND_LOCATION" />
<uses-permission android:name="android.permission.FOREGROUND_SERVICE" />
<uses-permission android:name="android.permission.FOREGROUND_SERVICE_LOCATION" />
<uses-permission android:name="android.permission.WAKE_LOCK" />
```

---

## 🏗️ Kiến trúc Native SDK

### SDK Dependencies

| Platform | SDK | Version | Source |
|---|---|---|---|
| iOS | `VietmapTrackingSDK` | 1.1.6 | CocoaPods (xcframework binary) |
| Android | `vietmap-tracking-sdk-android` | 1.1.6 | JitPack (`com.github.vietmap-company`) |

### Kiến trúc lớp (Layer Architecture)

```
┌─────────────────────────────────────────────────────────┐
│  Application Layer (React Native / Flutter)             │
│  - Giao diện người dùng                                 │
│  - Business logic                                       │
├─────────────────────────────────────────────────────────┤
│  Bridge Layer (RN: TurboModule / Flutter: MethodChannel)│
│  - RnVietmapTrackingPlugin.swift (iOS)                  │
│  - RnVietmapTrackingPluginModule.kt (Android)           │
│  - Chuyển đổi kiểu dữ liệu native ↔ cross-platform    │
│  - Forward events từ SDK lên application                │
├─────────────────────────────────────────────────────────┤
│  Native SDK Layer                                       │
│  - VietmapTrackingManager (iOS singleton: .shared)      │
│  - VietmapTrackingSDK (Android: getInstance(context))   │
│  - CLLocationManager (iOS) / FusedLocationProvider (And)│
│  - Foreground Service (Android only)                    │
│  - BGTaskScheduler (iOS)                                │
│  - AVSpeechSynthesizer (iOS speech alert)               │
└─────────────────────────────────────────────────────────┘
```

---

## 📋 Tổng hợp Native Methods — iOS (Swift) & Android (Kotlin)

### Quy ước ký hiệu

| Ký hiệu | Ý nghĩa |
|---|---|
| ✅ | Đã implement trong bridge |
| ⚠️ | Có trong native SDK nhưng CHƯA implement trong bridge |
| 🔵 | Chỉ có trên iOS |
| 🟢 | Chỉ có trên Android |
| 🔶 | Có trên cả 2 platform nhưng API khác nhau |

---

### 1. Nhóm hàm Cấu hình (Configuration)

#### `configure(apiKey, baseURL?)`  ✅ iOS ✅ Android

**Nhiệm vụ:** Khởi tạo và cấu hình VietmapTrackingSDK với API key. **Phải gọi trước khi sử dụng bất kỳ hàm tracking nào.**

| | iOS (Swift) | Android (Kotlin) |
|---|---|---|
| **Native class** | `VietmapTrackingManager.shared` | `VietmapTrackingSDK.getInstance(context)` |
| **Initialization** | `trackingManager.configure(apiKey:)` | `vietmapSDK.initialize(apiKey)` hoặc `vietmapSDK.initialize(apiKey, baseURL)` |
| **baseURL** | `trackingManager.configure(baseURL:)` (gọi riêng) | Truyền tham số thứ 2 trong `initialize()` |
| **Auto upload** | `trackingManager.setAutoUpload(enabled: true)` | Không gọi rõ ràng |
| **Return** | `resolver(true)` qua Promise | `promise.resolve(true)` qua Promise |

**Native iOS — tất cả overload của `configure`:**
```swift
// VietmapTrackingManager public methods:
func configure(apiKey: String)
func configure(baseURL: String)
func configure(apiVersion: String)               // ⚠️ CHƯA expose qua bridge
func configure(apiKey: String, baseURL: String, autoUpload: Bool = true)  // ⚠️ overload đầy đủ
func initialize(apiKey: String, baseURL: String)  // ⚠️ CHƯA expose qua bridge
```

**Native Android:**
```kotlin
vietmapSDK.initialize(apiKey: String)
vietmapSDK.initialize(apiKey: String, baseURL: String)
```

> ⚠️ **Lưu ý cho Flutter:** iOS có thêm `configure(apiVersion:)` và `initialize(apiKey:baseURL:)` chưa được bridge expose. Cân nhắc thêm vào Flutter SDK.

---

#### `configureAlertAPI(apiKey, apiID)`  ✅ iOS ✅ Android

**Nhiệm vụ:** Cấu hình Alert API để sử dụng tính năng giám sát và cảnh báo tốc độ.

| | iOS (Swift) | Android (Kotlin) |
|---|---|---|
| **Native call** | `trackingManager.configureAlertAPI(apiKey:, apiID:)` | `vietmapSDK.configureAlertAPI(apiKey, apiID)` |
| **Default URL (iOS)** | `"https://drive-api.vietmap.vn/fleetwork/api/Alert/v2/mpp"` | Không rõ (binary) |

**Native iOS full signature:**
```swift
func configureAlertAPI(apiKey: String, apiID: String, url: String = "https://drive-api.vietmap.vn/fleetwork/api/Alert/v2/mpp")
```

> ⚠️ **Lưu ý cho Flutter:** iOS có tham số `url` tùy chọn (mặc định có sẵn). Cân nhắc expose cho Flutter.

---

### 2. Nhóm hàm Quyền truy cập (Permissions)

#### `requestLocationPermissions()`  ✅ iOS ✅ Android

| | iOS (Swift) | Android (Kotlin) |
|---|---|---|
| **Native call** | `trackingManager.requestLocationPermissions(completion:)` | `ActivityCompat.requestPermissions()` |
| **Return type** | `PermissionResult` (bridge tự tạo dict từ status string) | `PermissionResult` (bridge tự tạo từ grant results) |
| **Async pattern** | Callback `(String) -> Void` | `PermissionListener.onRequestPermissionsResult()` |

**Return structure (cả 2 platform):**
```typescript
interface PermissionResult {
  granted: boolean;
  status: 'granted' | 'denied' | 'not_granted';
  fineLocation: boolean;
  coarseLocation: boolean;
  backgroundLocation: boolean;
}
```

**Android xử lý chi tiết hơn iOS:**
- Kiểm tra từng quyền riêng: `ACCESS_FINE_LOCATION`, `ACCESS_COARSE_LOCATION`, `ACCESS_BACKGROUND_LOCATION`
- Tự động yêu cầu background location cho Android 10+ (API 29+)
- Gửi event `onPermissionChanged` kèm `type: "location"` hoặc `type: "background_location"`

**iOS đơn giản hơn:**
- Delegate cho SDK xử lý: `trackingManager.requestLocationPermissions(completion:)`
- Bridge convert status string → `PermissionResult` dict
- `backgroundLocation` mặc định = `granted` nếu location granted (iOS quản lý khác)

---

#### `hasLocationPermissions()`  ✅ iOS ✅ Android

| | iOS (Swift) | Android (Kotlin) |
|---|---|---|
| **Native call** | `trackingManager.hasLocationPermissions() -> Bool` | `ContextCompat.checkSelfPermission()` |
| **Return** | `PermissionResult` dict | `PermissionResult` dict |

---

#### `requestAlwaysLocationPermissions()`  ✅ iOS ✅ Android

| | iOS (Swift) | Android (Kotlin) |
|---|---|---|
| **Return type** | `Promise<string>`: `"granted"` / `"when_in_use"` / `"denied"` | `Promise<string>`: `"granted"` / `"denied"` |
| **iOS implementation** | Bridge tự quản lý `CLLocationManager` + `requestAlwaysAuthorization()` + delay 2s kiểm tra | — |
| **Android implementation** | — | Kiểm tra `ACCESS_BACKGROUND_LOCATION` riêng cho API 29+ |

> ⚠️ **Khác biệt quan trọng:**
> - iOS: Bridge tạo `CLLocationManager()` riêng (không dùng SDK), check `authorizationStatus` sau 2s delay
> - Android: Gọi `ActivityCompat.requestPermissions()`, xử lý 2 bước (basic → background)
> - iOS trả thêm `"when_in_use"`, Android chỉ `"granted"` / `"denied"`

---

### 3. Nhóm hàm Theo dõi vị trí (Tracking)

#### `startTracking(backgroundMode, intervalMs, distanceFilter, notificationTitle?, notificationMessage?)`  ✅ iOS ✅ Android

| | iOS (Swift) | Android (Kotlin) |
|---|---|---|
| **Native call** | `trackingManager.startTracking(enhancedBackgroundMode:, intervalMs:, distanceFilter:, completion:)` | `vietmapSDK.setTrackingConfig(config)` + `vietmapSDK.startTracking()` |
| **Notification params** | ❌ Không sử dụng (iOS không cần foreground service notification) | ✅ `vietmapSDK.setNotificationTitle()` + `setNotificationText()` |
| **Async pattern** | Callback `(Bool, String?) -> Void` | Đồng bộ (resolve ngay) |
| **Guard check** | `isInitialized` — reject nếu false | `isInitialized` — resolve(false) nếu false |

**iOS có thêm overload CHƯA dùng trong bridge:**
```swift
// Overload với forceUpdateBackground:
func startTracking(backgroundMode: Bool, intervalMs: Int, forceUpdateBackground: Bool, 
                   distanceFilter: Double, completion: @escaping (Bool, String?) -> Void)

// Enhanced tracking (iOS 14.0+):
@available(iOS 14.0, *)
func startEnhancedTracking(highAccuracyMode: Bool = false, 
                           completion: @escaping (Bool, String?) -> Void)
```

**Android config qua `TrackingConfig`:**
```kotlin
val trackingConfig = TrackingConfig().apply {
    updateInterval = intervalMs.toLong()
    minDistanceFilter = distanceFilter ?: 10.0
    enableBackgroundMode = backgroundMode
}
vietmapSDK.setTrackingConfig(trackingConfig)
vietmapSDK.startTracking()
```

**TrackingConfig fields (từ iOS swiftinterface):**
```swift
public struct TrackingConfig {
    public var updateInterval: TimeInterval
    public var minDistanceFilter: Double
    public var enableSpeedAlerts: Bool        // ⚠️ CHƯA expose qua bridge
    public var speedThreshold: Double         // ⚠️ CHƯA expose qua bridge
    public var accuracy: String               // ⚠️ CHƯA expose qua bridge
    public var enableBackgroundMode: Bool
    public var distanceFilter: Double
}
```

> ⚠️ **Lưu ý cho Flutter:** Có `enableSpeedAlerts`, `speedThreshold`, `accuracy` trong native config nhưng chưa expose qua RN bridge. Cân nhắc thêm vào Flutter.

---

#### `stopTracking()`  ✅ iOS ✅ Android

| | iOS (Swift) | Android (Kotlin) |
|---|---|---|
| **Native call** | `trackingManager.stopTracking(completion:)` | `vietmapSDK.stopTracking()` |
| **Async pattern** | Callback `(Bool, String?) -> Void` | Đồng bộ (resolve ngay) |

> ⚠️ **QUAN TRỌNG:** Tracking **KHÔNG BAO GIỜ tự dừng**. Phải gọi `stopTracking()` thủ công. Xem chi tiết trong `TESTING_GUIDE.md` mục 4.

---

#### `getCurrentLocation()`  ✅ iOS 🔶 Android

| | iOS (Swift) | Android (Kotlin) |
|---|---|---|
| **Native call** | `trackingManager.getCurrentLocation() -> NSDictionary?` | ⚠️ Trả dummy data (latitude/longitude = 0.0) |
| **Return** | Location dict thực từ SDK | Hardcoded empty location map |

> ⚠️ **Android hiện trả dummy data!** Comment trong code: `"Since VietmapTrackingSDK might not have getCurrentLocation method"`. Cần fix cho Flutter.

---

#### `isTrackingActive()`  ✅ iOS ✅ Android

| | iOS (Swift) | Android (Kotlin) |
|---|---|---|
| **Native call** | `trackingManager.isTrackingActive() -> Bool` | `vietmapSDK.isTracking() -> Boolean` |
| **Return** | `Promise<boolean>` | `Promise<boolean>` |

---

#### `getTrackingStatus()`  ✅ iOS ✅ Android

| | iOS (Swift) | Android (Kotlin) |
|---|---|---|
| **Native call** | `trackingManager.getTrackingStatus() -> NSDictionary` | Bridge tự tạo dict từ `vietmapSDK.isTracking()` |
| **Return** | Status dict từ SDK (chi tiết) | `{isTracking, status, timestamp}` (đơn giản hơn) |

---

#### `updateTrackingConfig(config)`  ✅ iOS ✅ Android

| | iOS (Swift) | Android (Kotlin) |
|---|---|---|
| **Native call** | ⚠️ Chỉ lưu config reference, **KHÔNG thực sự update SDK** | `vietmapSDK.setTrackingConfig(config)` — update thực sự |
| **Hoạt động khi tracking active** | Không (comment: "SDK handles this internally") | Có |

> ⚠️ **Khác biệt lớn:** iOS bridge chỉ lưu config local, Android thực sự gọi SDK update.

---

### 4. Nhóm hàm Cảnh báo tốc độ (Speed Alert)

#### `turnOnAlert()`  ✅ iOS ✅ Android

| | iOS (Swift) | Android (Kotlin) |
|---|---|---|
| **Native call** | `trackingManager.turnOnAlert(completion:)` | `vietmapSDK.startAlert() -> Boolean` |
| **Async pattern** | Callback `(Bool) -> Void` | Đồng bộ |

---

#### `turnOffAlert()`  ✅ iOS ✅ Android

| | iOS (Swift) | Android (Kotlin) |
|---|---|---|
| **Native call** | `trackingManager.turnOffAlert(completion:)` | `vietmapSDK.stopAlert() -> Boolean` |
| **Async pattern** | Callback `(Bool) -> Void` | Đồng bộ |

---

### 5. Event Listeners (Sự kiện từ Native → Application)

#### Cách forward events

**iOS:** Dùng `RCTEventEmitter.sendEvent(withName:body:)`, setup callbacks trên `VietmapTrackingManager`:
```swift
trackingManager.onLocationUpdate = { [weak self] locationDict in
    self?.sendEvent(withName: "onLocationUpdate", body: locationDict as? [String: Any])
}
```

**Android:** Dùng `RCTDeviceEventEmitter.emit()`:
```kotlin
reactApplicationContext
    .getJSModule(DeviceEventManagerModule.RCTDeviceEventEmitter::class.java)
    .emit(eventName, params)
```

#### Danh sách events

| Event Name | iOS Callback | Android | Payload |
|---|---|---|---|
| `onLocationUpdate` | `trackingManager.onLocationUpdate: ((NSDictionary) -> Void)?` | ⚠️ **Chưa setup** trong bridge Android | `LocationData` dict |
| `onTrackingStatusChanged` | `trackingManager.onTrackingStatusChanged: ((NSDictionary) -> Void)?` | ⚠️ **Chưa setup** trong bridge Android | `TrackingStatus` dict |
| `onLocationError` | `trackingManager.onError: ((String) -> Void)?` | ⚠️ **Chưa setup** trong bridge Android | `{error, timestamp}` |
| `onPermissionChanged` | `trackingManager.onPermissionChanged: ((String) -> Void)?` | ✅ Gửi thủ công khi permission result | `{status, timestamp}` (iOS) / `{granted, type}` (Android) |
| `onRouteUpdate` | `trackingManager.onRouteUpdate: ((Bool, NSDictionary?) -> Void)?` | ⚠️ **Chưa setup** trong bridge Android | `{success, routeData, timestamp}` |

> ⚠️ **PHÁT HIỆN QUAN TRỌNG cho Flutter:** Android bridge **KHÔNG setup event callbacks** cho location/tracking/error/route! Chỉ iOS bridge có `setupSDKCallbacks()`. Android chỉ gửi `onPermissionChanged` thủ công. Đây là lỗi thiếu sót cần fix.

---

### 6. Hàm có trong Native SDK nhưng CHƯA expose qua Bridge

Các hàm sau tồn tại trong native `VietmapTrackingManager` (iOS) / `VietmapTrackingSDK` (Android) nhưng **CHƯA** được RN bridge implement:

#### 6.1 Vehicle Configuration ⚠️ Chưa bridge

**iOS Native (VietmapTrackingManager):**
```swift
func setVehicleId(_ vehicleId: String)
func setDriverId(_ driverId: String?)
func getVehicleId() -> String
func getDriverId() -> String?
func configureVehicleWithType(vehicleId: String, vehicleType: VMVehicleType, seats: Int, weight: Double)
func configureVehicle(vehicleId: String, vehicleType: Int, seats: Int, weight: Double, maxProvision: Int)
func getVehicleConfiguration() -> NSDictionary
```

**VMVehicleType enum (iOS):**
```swift
@objc public enum VMVehicleType: Int {
    case car = 1
    case taxi = 2
    case bus = 3
    case coach = 4
    case truck = 5
    case trailer = 6
    case cycle = 7
    case bike = 8
    case pedestrian = 9
    case semiTrailer = 10
}
```

---

#### 6.2 External Location Input ⚠️ Chưa bridge

**iOS Native:**
```swift
func processExternalLocation(latitude: Double, longitude: Double, speed: Double, heading: Double)
func processExternalLocation(_ location: CLLocation)
func getCurrentLocationMode() -> VMLocationMode  // .gpsCallback hoặc .externalInput
```

**VMLocationMode enum (iOS):**
```swift
@objc public enum VMLocationMode: Int {
    case gpsCallback = 0     // Dùng GPS nội bộ
    case externalInput = 1   // Nhận location từ bên ngoài
}
```

---

#### 6.3 Speed Alert Processing with Vehicle ⚠️ Chưa bridge

**iOS Native:**
```swift
func processLocationWithVehicleType(
    latitude: Double, longitude: Double, speed: Double, heading: Double,
    vehicleId: String = "1", vehicleType: VMVehicleType = .car, 
    seats: Int = 5, weights: Double = 1500.0
)

func processLocationWithVehicleParams(
    latitude: Double, longitude: Double, speed: Double, heading: Double,
    vehicleId: String = "1", vehicleType: Int = 1, 
    seats: Int = 5, weights: Double = 1500.0
)

func processSpeedAlertUsingCPP(
    location: CLLocation, vehicleId: String, vehicleType: Int, 
    seats: Int, weights: Double
)
```

---

#### 6.4 Cache Management ⚠️ Chưa bridge (iOS), có partial (Android)

**iOS Native:**
```swift
func getCachedLocationsCount() -> Int
func uploadCachedLocationsManually(completion: @escaping (Bool, String?) -> Void)
func clearCachedLocations()
```

**Android (partial — chỉ clearCachedLocations trong bridge, nhưng chưa gọi SDK thực tế):**
```kotlin
// Bridge có hàm clearCachedLocations nhưng body là TODO:
fun clearCachedLocations(promise: Promise) {
    // TODO: Add actual clearCache method when available in API
    promise.resolve(true)
}
```

---

#### 6.5 Network & Health Status ⚠️ Chưa bridge

**iOS Native:**
```swift
func isNetworkConnected() -> Bool
func getTrackingHealthStatus() -> NSDictionary
```

> Lưu ý: `getTrackingHealthStatus()` có trong iOS bridge nhưng **không được export trong TurboModule spec** (`NativeRnVietmapTrackingPlugin.ts`), nên không gọi được từ JS.

---

#### 6.6 App Lifecycle ⚠️ Chưa bridge

**iOS Native:**
```swift
func onAppBackground()
func onAppForeground()
```

> Quan trọng cho background tracking. RN bridge không gọi 2 hàm này. Flutter nên gọi khi `AppLifecycleState` thay đổi.

---

#### 6.7 Tracking Status & Configuration ⚠️ Chưa bridge

**iOS Native:**
```swift
func setTrackingStatus(_ status: String)
func setAutoUpload(enabled: Bool)     // Gọi trong configure nhưng không expose riêng
func isSpeedAlertCurrentlyActive() -> Bool
```

---

#### 6.8 Enhanced Tracking (iOS 14.0+) ⚠️ Chưa bridge

**iOS Native:**
```swift
@available(iOS 14.0, *)
func startEnhancedTracking(highAccuracyMode: Bool = false, completion: @escaping (Bool, String?) -> Void)

@available(iOS 14.0, *)
func getEnhancedLocationStatus() -> NSDictionary

func requestFullLocationAccuracy()
```

---

#### 6.9 EnhancedLocationManager (iOS class riêng) ⚠️ Chưa bridge

Đây là class iOS riêng biệt (không phải VietmapTrackingManager), cung cấp location tracking nâng cao:

```swift
public class EnhancedLocationManager: NSObject {
    var onLocationUpdate: ((CLLocation, String, String) -> Void)?
    var onLocationError: ((String) -> Void)?
    var onAuthorizationChanged: ((CLAuthorizationStatus) -> Void)?

    @available(iOS 14.0, *)
    func startTracking(highAccuracyMode: Bool = false)
    func stopTracking()
    @available(iOS 14.0, *)
    func requestLocationPermissions()
    func isTracking() -> Bool
    func getLastKnownLocation() -> CLLocation?
    @available(iOS 14.0, *)
    func getLocationServicesStatus() -> String
    func requestFullAccuracy()
    func setCustomAccuracy(_ accuracy: CLLocationAccuracy, distanceFilter: CLLocationDistance)
    @available(iOS 14.0, *)
    func enableBackgroundLocationUpdates(_ enable: Bool)
}
```

---

#### 6.10 Route Data Structures ⚠️ Chưa bridge

**iOS structs (từ swiftinterface):**
```swift
public struct VMLocation {
    public let latitude: Double
    public let longitude: Double
    public let altitude: Double
    public let accuracy: Double
    public let speed: Double
    public let bearing: Double
    public let timestamp: TimeInterval
}

public struct RouteData {
    public var routeId: String
    public var totalDistance: Double
    public var estimatedTime: Double
    public var waypoints: [VMLocation]
    public var speedLimits: [Double]
}

public struct AlertConfig {
    public var speedAlertEnabled: Bool
    public var voiceAlertsEnabled: Bool
    public var alertThreshold: Double
    public var speedThreshold: Double
    public var language: String
}

public struct VMGeoPoint {
    public let latitude: Double
    public let longitude: Double
}

public struct VMRouteProgress {
    public var currentLinkIndex: Int
    public var segmentProgress: Double
    public var totalRouteProgress: Double
    public var snappedPosition: VMGeoPoint
    public var distanceToRoute: Double
}

public struct VMSnapResult {
    public var distance: Double
    public var progress: Double
    public var snappedPoint: VMGeoPoint
}
```

---

#### 6.11 TurboModule Spec có nhưng chưa implement đầy đủ

Các hàm sau nằm trong `NativeRnVietmapTrackingPluginSpec.java` (Android codegen) nhưng **chưa implement đúng**:

| Hàm trong Spec | iOS | Android |
|---|---|---|
| `processRouteData(routeJson)` | ❌ Không có | ❌ Không implement |
| `getCurrentRouteInfo()` | ❌ Không có | ❌ Không implement |
| `findNearestAlert(lat, lon)` | ❌ Không có | ✅ Có nhưng trả dummy data |
| `checkSpeedViolation(currentSpeed)` | ❌ Không có | ❌ Không implement |

> ⚠️ **Lưu ý:** Các hàm route/alert processing giờ được SDK native xử lý nội bộ, không cần gọi từ application.

---

### 7. Foreground Service (Android only) 🟢

Android sử dụng `LocationTrackingService` (Foreground Service) để duy trì tracking trong background:

```kotlin
class LocationTrackingService : Service() {
    // START_STICKY — OS sẽ cố restart service nếu bị kill
    override fun onStartCommand(...): Int = START_STICKY

    // Notification channel: "location_tracking_channel", IMPORTANCE_LOW
    // Notification: ongoing, icon ic_menu_mylocation
    // foregroundServiceType="location" trong AndroidManifest
}
```

**Lưu ý cho Flutter:**
- Cần tạo tương tự `LocationTrackingService` extends `Service`
- Đăng ký trong `AndroidManifest.xml` với `android:foregroundServiceType="location"`
- Notification channel bắt buộc cho Android 8.0+ (API 26+)
- `notificationTitle` và `notificationMessage` chỉ có tác dụng trên Android

---

### 8. Cleanup & Lifecycle

#### iOS `deinit`:
```swift
deinit {
    // CHỈ xóa callbacks, KHÔNG gọi stopTracking()
    trackingManager.onLocationUpdate = nil
    trackingManager.onTrackingStatusChanged = nil
    trackingManager.onError = nil
    trackingManager.onPermissionChanged = nil
    trackingManager.onRouteUpdate = nil
}
```

#### Android `invalidate()`:
```kotlin
override fun invalidate() {
    // GỌI stopTracking() — an toàn hơn iOS
    if (isInitialized) {
        vietmapSDK.stopTracking()
    }
}
```

> ⚠️ **Khác biệt quan trọng cho Flutter:**
> - iOS `deinit` **KHÔNG** dừng tracking → có thể gây zombie tracking
> - Android `invalidate()` **CÓ** dừng tracking → an toàn hơn
> - Flutter plugin nên gọi `stopTracking()` trong `dispose()` trên CẢ HAI platform

---

## 📊 Bảng tổng hợp tất cả hàm cho Flutter SDK

### Hàm bắt buộc implement (đã có trong RN bridge)

| # | Hàm | iOS Native | Android Native | Async |
|---|---|---|---|---|
| 1 | `configure(apiKey, baseURL?)` | `configure(apiKey:)` + `configure(baseURL:)` + `setAutoUpload(true)` | `initialize(apiKey)` / `initialize(apiKey, baseURL)` | Yes |
| 2 | `configureAlertAPI(apiKey, apiID)` | `configureAlertAPI(apiKey:apiID:)` | `configureAlertAPI(apiKey, apiID)` | Yes |
| 3 | `requestLocationPermissions()` | `requestLocationPermissions(completion:)` | `ActivityCompat.requestPermissions()` | Yes |
| 4 | `hasLocationPermissions()` | `hasLocationPermissions() -> Bool` | `ContextCompat.checkSelfPermission()` | Yes |
| 5 | `requestAlwaysLocationPermissions()` | `CLLocationManager().requestAlwaysAuthorization()` | `requestPermissions(BACKGROUND_LOCATION)` | Yes |
| 6 | `startTracking(config)` | `startTracking(enhancedBackgroundMode:intervalMs:distanceFilter:completion:)` | `setTrackingConfig(config)` + `startTracking()` | Yes |
| 7 | `stopTracking()` | `stopTracking(completion:)` | `stopTracking()` | Yes |
| 8 | `getCurrentLocation()` | `getCurrentLocation() -> NSDictionary?` | ⚠️ Cần implement thật (RN trả dummy) | Yes |
| 9 | `isTrackingActive()` | `isTrackingActive() -> Bool` | `isTracking() -> Boolean` | Yes |
| 10 | `getTrackingStatus()` | `getTrackingStatus() -> NSDictionary` | `isTracking()` → tạo dict | Yes |
| 11 | `updateTrackingConfig(config)` | Lưu local (không update SDK) | `setTrackingConfig(config)` | Yes |
| 12 | `turnOnAlert()` | `turnOnAlert(completion:)` | `startAlert() -> Boolean` | Yes |
| 13 | `turnOffAlert()` | `turnOffAlert(completion:)` | `stopAlert() -> Boolean` | Yes |

### Hàm nên thêm mới cho Flutter (có trong native SDK, chưa bridge)

| # | Hàm | iOS Native | Android Native | Ghi chú |
|---|---|---|---|---|
| 14 | `setVehicleId(vehicleId)` | `setVehicleId(_:)` | Cần kiểm tra | Cần cho fleet tracking |
| 15 | `setDriverId(driverId)` | `setDriverId(_:)` | Cần kiểm tra | Cần cho fleet tracking |
| 16 | `getVehicleId()` | `getVehicleId() -> String` | Cần kiểm tra | |
| 17 | `getDriverId()` | `getDriverId() -> String?` | Cần kiểm tra | |
| 18 | `configureVehicle(...)` | `configureVehicle(vehicleId:vehicleType:seats:weight:maxProvision:)` | Cần kiểm tra | Cấu hình phương tiện |
| 19 | `getVehicleConfiguration()` | `getVehicleConfiguration() -> NSDictionary` | Cần kiểm tra | |
| 20 | `processExternalLocation(lat,lon,speed,heading)` | `processExternalLocation(...)` | Cần kiểm tra | Nhận GPS từ nguồn ngoài |
| 21 | `getCurrentLocationMode()` | `getCurrentLocationMode() -> VMLocationMode` | Cần kiểm tra | GPS callback vs external |
| 22 | `isSpeedAlertCurrentlyActive()` | `isSpeedAlertCurrentlyActive() -> Bool` | Cần kiểm tra | |
| 23 | `getCachedLocationsCount()` | `getCachedLocationsCount() -> Int` | Cần kiểm tra | |
| 24 | `uploadCachedLocationsManually()` | `uploadCachedLocationsManually(completion:)` | Cần kiểm tra | |
| 25 | `clearCachedLocations()` | `clearCachedLocations()` | Cần kiểm tra | |
| 26 | `isNetworkConnected()` | `isNetworkConnected() -> Bool` | Cần kiểm tra | |
| 27 | `getTrackingHealthStatus()` | `getTrackingHealthStatus() -> NSDictionary` | Cần kiểm tra | |
| 28 | `onAppBackground()` | `onAppBackground()` | Cần kiểm tra | Gọi khi app vào background |
| 29 | `onAppForeground()` | `onAppForeground()` | Cần kiểm tra | Gọi khi app quay lại |
| 30 | `setAutoUpload(enabled)` | `setAutoUpload(enabled:)` | Cần kiểm tra | |
| 31 | `startEnhancedTracking(highAccuracy)` | `startEnhancedTracking(highAccuracyMode:completion:)` | N/A | iOS 14.0+ only |
| 32 | `getEnhancedLocationStatus()` | `getEnhancedLocationStatus() -> NSDictionary` | N/A | iOS 14.0+ only |
| 33 | `requestFullLocationAccuracy()` | `requestFullLocationAccuracy()` | N/A | iOS only |
| 34 | `setTrackingStatus(status)` | `setTrackingStatus(_:)` | Cần kiểm tra | |

### Events cần implement cho Flutter

| # | Event Name | iOS Source | Android Source | Payload |
|---|---|---|---|---|
| 1 | `onLocationUpdate` | `trackingManager.onLocationUpdate` | ⚠️ Cần setup | `{latitude, longitude, altitude, accuracy, speed, bearing, timestamp}` |
| 2 | `onTrackingStatusChanged` | `trackingManager.onTrackingStatusChanged` | ⚠️ Cần setup | `{isTracking, status, timestamp, ...}` |
| 3 | `onLocationError` | `trackingManager.onError` | ⚠️ Cần setup | `{error, timestamp}` |
| 4 | `onPermissionChanged` | `trackingManager.onPermissionChanged` | Manual emit | `{status, timestamp}` |
| 5 | `onRouteUpdate` | `trackingManager.onRouteUpdate` | ⚠️ Cần setup | `{success, routeData, timestamp}` |

---

## 🚀 Ví dụ sử dụng đầy đủ (RN — tham khảo cho Flutter)

```ts
import {
  configure,
  configureAlertAPI,
  startLocationTracking,
  stopLocationTracking,
  addLocationUpdateListener,
  addTrackingStatusListener,
  turnOnAlert,
  turnOffAlert,
  TrackingPresets,
  TrackingSession,
  LocationUtils,
} from '@vietmap/rn_vietmap_tracking_plugin';

// 1. Khởi tạo SDK
await configure('YOUR_API_KEY');
await configureAlertAPI('ALERT_API_KEY', 'ALERT_API_ID');

// 2. Tạo phiên theo dõi
const session = new TrackingSession();
session.start();

// 3. Lắng nghe sự kiện
const locationListener = addLocationUpdateListener((location) => {
  session.addLocation(location.latitude, location.longitude, location.timestamp);
  const speedKmh = LocationUtils.mpsToKmh(location.speed);
  console.log(`Vị trí: ${location.latitude}, ${location.longitude} | Tốc độ: ${speedKmh} km/h`);
});

const statusListener = addTrackingStatusListener((status) => {
  console.log('Tracking:', status.isTracking);
});

// 4. Bắt đầu tracking (dùng preset hoặc config tùy chỉnh)
await startLocationTracking(TrackingPresets.NAVIGATION);

// 5. Bật cảnh báo tốc độ
await turnOnAlert();

// ... Sử dụng ứng dụng ...

// 6. Dừng tracking (BẮT BUỘC — SDK không tự dừng)
await turnOffAlert();
await stopLocationTracking();

// 7. Lấy thống kê và dọn dẹp
const stats = session.getStats();
console.log(`Tổng quãng đường: ${stats.distance} m`);
console.log(`Thời gian: ${stats.duration} ms`);

session.clear();
locationListener.remove();
statusListener.remove();
```

---

## 🦋 Ghi chú cho Flutter SDK

### Khác biệt kiến trúc RN vs Flutter

| Khía cạnh | React Native | Flutter |
|---|---|---|
| Bridge pattern | TurboModule (Codegen) | MethodChannel / EventChannel |
| Event streaming | `NativeEventEmitter` + `RCTEventEmitter` | `EventChannel` + `StreamSubscription` |
| iOS singleton | `VietmapTrackingManager.shared` | Giống — dùng `shared` |
| Android singleton | `VietmapTrackingSDK.getInstance(context)` | Giống — dùng `getInstance()` |
| Cleanup | `deinit` (iOS) / `invalidate()` (Android) | `dispose()` — nên gọi `stopTracking()` |
| Background | `UIBackgroundModes` + `LocationTrackingService` | Tương tự + cần `flutter_background_service` hoặc tự viết |

### Lỗi trong RN bridge cần sửa khi viết Flutter

1. **Android không setup event callbacks** — `onLocationUpdate`, `onTrackingStatusChanged`, `onError`, `onRouteUpdate` không được forward lên JS. Flutter phải setup đầy đủ.
2. **Android `getCurrentLocation()` trả dummy data** — Cần gọi API thật từ SDK.
3. **iOS `updateTrackingConfig` không update SDK thật** — Chỉ lưu local. Flutter nên gọi SDK thực sự.
4. **iOS `deinit` không gọi `stopTracking()`** — Flutter `dispose()` PHẢI gọi `stopTracking()` trên cả 2 platform.
5. **iOS bridge tạo `CLLocationManager()` riêng cho `requestAlwaysLocationPermissions`** — Nên dùng SDK method nếu có.

### Hàm ưu tiên implement cho Flutter

**Ưu tiên cao (core features):**
- `configure`, `configureAlertAPI`
- `startTracking`, `stopTracking`
- `getCurrentLocation`, `isTrackingActive`, `getTrackingStatus`
- `turnOnAlert`, `turnOffAlert`
- 5 event streams (location, status, error, permission, route)
- Permission methods (3 hàm)

**Ưu tiên trung bình (fleet management):**
- `setVehicleId`, `setDriverId`, `configureVehicle`
- `onAppBackground`, `onAppForeground`
- Cache management (count, upload, clear)

**Ưu tiên thấp (nâng cao):**
- `processExternalLocation` (external GPS input)
- `startEnhancedTracking` (iOS 14+ only)
- `EnhancedLocationManager` (iOS separate class)
- Route processing và snap-to-road
