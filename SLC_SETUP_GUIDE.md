# 📡 SLC (Significant Location Changes) — Setup & Debugging Guide

## Mục lục

1. [Tổng quan SLC](#1-tổng-quan-slc)
2. [Sơ đồ Workflow 4 giai đoạn](#2-sơ-đồ-workflow-4-giai-đoạn)
3. [Yêu cầu hệ thống](#3-yêu-cầu-hệ-thống)
4. [Setup từng bước](#4-setup-từng-bước)
5. [Cách hoạt động trong code](#5-cách-hoạt-động-trong-code)
6. [Debug & Verify](#6-debug--verify)
7. [Giới hạn & Lưu ý](#7-giới-hạn--lưu-ý)
8. [So sánh SLC vs Standard Location Updates](#8-so-sánh-slc-vs-standard-location-updates)
9. [FAQ](#9-faq)

---

## 1. Tổng quan SLC

**Significant Location Changes (SLC)** là một API của Apple (`CLLocationManager.startMonitoringSignificantLocationChanges()`) cho phép iOS **đánh thức ứng dụng** ngay cả khi đã bị **force-kill** bởi người dùng.

### Cách hoạt động:
- SLC dựa trên **cell tower handover** (chuyển đổi trạm phát sóng), **không dùng GPS liên tục**
- Khi thiết bị di chuyển **≥ 500m** hoặc thay đổi cell tower → iOS gửi sự kiện location
- Nếu app đã bị kill → iOS **khởi chạy lại app ngầm** (background launch) với key `UIApplication.LaunchOptionsKey.location`
- App có khoảng **~10 giây** để xử lý (gửi GPS lên server) trước khi bị iOS suspend lại

### Tại sao cần SLC?
- `startUpdatingLocation()` chỉ hoạt động khi app đang foreground/background, **không hoạt động sau force-kill**
- Foreground Service (như Android) **không tồn tại trên iOS**
- SLC là **cách duy nhất hợp lệ** (Apple-approved) để nhận location sau force-kill

---

## 2. Sơ đồ Workflow 4 giai đoạn

```
┌─────────────────────────────────────────────────────────────────────┐
│  GIAI ĐOẠN 1: App Foreground / Background (Active)                  │
├─────────────────────────────────────────────────────────────────────┤
│                                                                     │
│  Flutter/Dart ──► MethodChannel ──► Native SDK Core                │
│       │               │                    │                        │
│       │               │     ┌──────────────┼──────────────┐        │
│       │               │     │              │              │        │
│       │          Lưu config  │   startMonitoringSLC()     │        │
│       │          vào         │   startUpdatingLocation()  │        │
│       │          UserDefaults│              │              │        │
│       │               │     │              ▼              │        │
│       │               │     │     CLLocationManager       │        │
│       │               │     │              │              │        │
│       │               │     │    didUpdateLocations()     │        │
│       │               │     │              │              │        │
│       │         ◄─────┘     │              │              │        │
│       │   Gửi event         │              ▼              │        │
│       │   qua EventChannel  │      Gửi GPS định kỳ ──────┼──► Server
│       ▼                     │                             │        │
│  Cập nhật UI               └──────────────────────────────┘        │
└─────────────────────────────────────────────────────────────────────┘

┌─────────────────────────────────────────────────────────────────────┐
│  GIAI ĐOẠN 2: User Force-Kills App                                  │
├─────────────────────────────────────────────────────────────────────┤
│                                                                     │
│  ❌ Flutter/Dart Engine → CHẾT                                      │
│  ❌ Native Process → TERMINATED                                     │
│  ❌ startUpdatingLocation() → HUỶ BỎ                               │
│                                                                     │
│  ✅ NHƯNG: SLC registration vẫn được iOS GHI NHỚ                   │
│  ✅ VÀ: Config đã được lưu trong UserDefaults (persist)             │
│                                                                     │
└─────────────────────────────────────────────────────────────────────┘

┌─────────────────────────────────────────────────────────────────────┐
│  GIAI ĐOẠN 3: iOS Wake-up ngầm & Gửi GPS                           │
├─────────────────────────────────────────────────────────────────────┤
│                                                                     │
│  Trigger: User di chuyển ≥ 500m HOẶC cell tower thay đổi           │
│                                                                     │
│  iOS System ──► Khởi chạy app ngầm                                  │
│       │              │                                              │
│       │     AppDelegate.didFinishLaunchingWithOptions                │
│       │     launchOptions[.location] == true                        │
│       │              │                                              │
│       │     Đọc config từ UserDefaults (KHÔNG CẦN Flutter)          │
│       │              │                                              │
│       │     Khởi tạo CLLocationManager                              │
│       │     startMonitoringSLC() (đăng ký lại)                      │
│       │              │                                              │
│       │     didUpdateLocations() → Lấy toạ độ mới                  │
│       │              │                                              │
│       │     Gửi GPS qua Background URLSession ──────────────► Server│
│       │              │                                              │
│       │     ⏱️ ~10 giây sau: iOS SUSPEND app lại                   │
│       │     (Background URLSession vẫn tiếp tục upload)             │
│                                                                     │
└─────────────────────────────────────────────────────────────────────┘

┌─────────────────────────────────────────────────────────────────────┐
│  GIAI ĐOẠN 4: User mở lại App (Re-engagement)                      │
├─────────────────────────────────────────────────────────────────────┤
│                                                                     │
│  App khởi động → Flutter engine init                                │
│       │                                                             │
│       │     Chuyển SDK về chế độ Foreground                         │
│       │     resumeTracking() với startUpdatingLocation()            │
│       │     SLC vẫn chạy song song                                  │
│       │                                                             │
│       ▼                                                             │
│  UI hiển thị bình thường + có thể xem SLC logs                     │
│                                                                     │
└─────────────────────────────────────────────────────────────────────┘
```

---

## 3. Yêu cầu hệ thống

### Xcode Project Settings

| Setting | Giá trị | Vị trí |
|---------|---------|--------|
| **Background Modes** | ✅ Location updates | Target → Signing & Capabilities |
| **NSLocationAlwaysAndWhenInUseUsageDescription** | Mô tả lý do | Info.plist |
| **NSLocationWhenInUseUsageDescription** | Mô tả lý do | Info.plist |
| **NSLocationAlwaysUsageDescription** | Mô tả lý do | Info.plist |
| **UIBackgroundModes** | `location` | Info.plist |

### Permissions

| Permission | Bắt buộc? | Lý do |
|-----------|-----------|-------|
| **Always** location authorization | ✅ BẮT BUỘC | SLC chỉ hoạt động sau kill khi có "Always" |
| **When In Use** | ⚠️ Không đủ | SLC sẽ hoạt động khi app foreground/background nhưng KHÔNG hoạt động sau force-kill |

### iOS Version
- **Minimum**: iOS 12.0
- **Recommended**: iOS 14.0+ (có `authorizationStatus` instance property)

---

## 4. Setup từng bước

### Bước 1: Thêm Background Modes trong Xcode

1. Mở `Runner.xcworkspace` trong Xcode
2. Chọn Target **Runner** → Tab **Signing & Capabilities**
3. Click **+ Capability** → Tìm **Background Modes**
4. Tick ✅ **Location updates**

### Bước 2: Thêm permission strings vào Info.plist

```xml
<!-- Info.plist -->
<key>NSLocationAlwaysAndWhenInUseUsageDescription</key>
<string>This app needs location access to track your position for navigation and delivery services.</string>
<key>NSLocationWhenInUseUsageDescription</key>
<string>This app needs location access to track your position for navigation and delivery services.</string>
<key>NSLocationAlwaysUsageDescription</key>
<string>This app needs location access to track your position in the background for delivery tracking.</string>

<key>UIBackgroundModes</key>
<array>
    <string>location</string>
</array>
```

### Bước 3: Request "Always" authorization trong app

```dart
// Trong Flutter/Dart
await controller.requestLocationPermissions();     // Bước 1: "When In Use"
await controller.requestAlwaysLocationPermissions(); // Bước 2: Upgrade → "Always"
```

> ⚠️ **Quan trọng**: iOS yêu cầu phải request "When In Use" trước, sau đó mới request "Always". Không thể nhảy thẳng lên "Always".

### Bước 4: Gọi startSLC từ Dart

```dart
// Trong Flutter/Dart (iOS only)
const slcChannel = MethodChannel('vietmap_tracking_plugin/slc');

await slcChannel.invokeMethod('startSLC', {
  'apiKey': 'your_api_key_here',
  'deviceId': 'unique_device_id',
  'vehicleId': 'vehicle_001',
  'userId': 'user_001',
  'apiEndpoint': 'https://dev.fleetwork.vn/api/v1/gps-tracking',
});
```

### Bước 5: Verify

Xem [Mục 6: Debug & Verify](#6-debug--verify)

---

## 5. Cách hoạt động trong code

### AppDelegate.swift — Entry point

```swift
override func application(
  _ application: UIApplication,
  didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
) -> Bool {

  // ★ KEY CHECK: Was this launch triggered by SLC?
  let launchedByLocation = launchOptions?[.location] != nil

  if launchedByLocation {
    // App was killed, now re-launched by iOS
    // Flutter engine is NOT alive yet → handle natively
    slcManager.handleSLCWakeUp()
  }

  // ... rest of Flutter setup
}
```

### SLCBackgroundLocationManager — Core logic

| Method | Giai đoạn | Mô tả |
|--------|-----------|-------|
| `startSLC(config:)` | 1 | Lưu config → UserDefaults, bắt đầu SLC monitoring |
| `handleSLCWakeUp()` | 3 | Đọc config từ UserDefaults, khởi tạo lại CLLocationManager |
| `didUpdateLocations()` | 1, 3 | Nhận location → build payload → gửi server |
| `sendToServer()` | 1, 3 | Dùng background URLSession để upload GPS |
| `stopSLC()` | 4 | Dừng SLC, xoá config khỏi UserDefaults |

### SLCConfig — Persisted configuration

```swift
struct SLCConfig: Codable {
  let apiKey: String
  let deviceId: String
  let vehicleId: String?
  let userId: String?
  let apiEndpoint: String
}
```

Config được lưu vào `UserDefaults` bằng `JSONEncoder`. Khi app bị kill và được iOS khởi chạy lại, config được đọc lại từ `UserDefaults` — **không cần Flutter engine**.

### Background URLSession — Gửi GPS

```swift
let config = URLSessionConfiguration.background(withIdentifier: "com.vietmap.slc.background.upload")
config.isDiscretionary = false          // Gửi ngay, không chờ
config.sessionSendsLaunchEvents = true  // Re-launch app nếu cần
config.allowsCellularAccess = true      // Cho phép dùng 4G/5G
```

> ✅ **Tại sao dùng background URLSession?**
> Sau khi iOS wake up app qua SLC, app chỉ có ~10 giây trước khi bị suspend lại. Background URLSession chạy trong process riêng của hệ thống, nên upload vẫn tiếp tục ngay cả khi app bị suspend.

---

## 6. Debug & Verify

### 6.1. Verify SLC đã đăng ký thành công

Trong Xcode Console, tìm log:

```
[SLC] ✅ SLC monitoring started (Always auth)
[SLC] 📡 SLC registration complete. Config: deviceId=flutter_example_device
```

Nếu thấy:
```
[SLC] ⚠️ SLC started but needs Always authorization for post-kill wake-up
```
→ User chưa cấp "Always" permission. SLC sẽ hoạt động khi app foreground/background nhưng **KHÔNG** sau force-kill.

### 6.2. Verify app được đánh thức sau force-kill

#### Phương pháp 1: Xcode Console (thiết bị thật)

1. Build & Run app trên thiết bị thật (KHÔNG phải Simulator)
2. Bấm "Start SLC" trong app
3. **Detach** debugger trong Xcode: Product → Detach
4. Force-kill app (vuốt lên từ App Switcher)
5. **Attach lại** debugger: Debug → Attach to Process → chọn app
6. Di chuyển ≥ 500m hoặc đợi cell tower thay đổi
7. Xcode Console sẽ hiện:

```
[SLC] 🟢 App re-launched by Significant Location Change
[SLC] 🔄 SLC wake-up: restoring config from UserDefaults
[SLC] 📡 SLC monitoring re-registered after wake-up
[SLC] 📍 SLC location: 10.762622,106.660172 speed=-1.0 accuracy=65.0
[SLC] 📤 Uploading GPS to https://dev.fleetwork.vn/api/v1/gps-tracking via background URLSession
```

#### Phương pháp 2: macOS Console.app

1. Mở **Console.app** trên macOS (`/Applications/Utilities/Console.app`)
2. Chọn thiết bị iPhone/iPad trong sidebar
3. Trong ô tìm kiếm, nhập: `[SLC]`
4. Force-kill app và di chuyển
5. Logs sẽ xuất hiện trong Console.app ngay cả khi Xcode không attach

#### Phương pháp 3: Kiểm tra từ phía Server

```bash
# Kiểm tra GPS tracking API đã nhận data chưa
curl -X 'GET' 'https://dev.fleetwork.vn/api/v1/gps-tracking?deviceId=flutter_example_device' \
  -H 'accept: application/json'
```

Nếu server nhận được record với `"status": "slc_background"` → xác nhận SLC đang hoạt động sau force-kill.

#### Phương pháp 4: SLC Logs trong app

1. Mở lại app sau khi SLC đã wake-up
2. Bấm **"Refresh SLC Logs"**
3. Xem log console có hiện các dòng với `📍 SLC location` và `📤 Uploading GPS`

#### Phương pháp 5: UserDefaults (post-mortem)

Logs gần nhất (50 dòng) được lưu trong `UserDefaults` key `vietmap_slc_logs`. Có thể đọc qua:

```swift
// Trong debug code hoặc Xcode lldb console:
po UserDefaults.standard.array(forKey: "vietmap_slc_logs")
```

### 6.3. Simulate SLC trên Simulator

> ⚠️ **SLC không hoạt động 100% trên Simulator cho giai đoạn force-kill**. Tuy nhiên, bạn có thể test giai đoạn 1 (app active):

1. Xcode → Debug → Simulate Location → chọn vị trí khác
2. Hoặc: Features → Location → Custom Location → thay đổi toạ độ

Để test force-kill thực sự, **phải dùng thiết bị thật**.

### 6.4. Debug Checklist

| # | Kiểm tra | Cách verify | ✅/❌ |
|---|---------|-------------|------|
| 1 | Info.plist có `UIBackgroundModes: location` | Mở Info.plist | |
| 2 | Info.plist có `NSLocationAlwaysAndWhenInUseUsageDescription` | Mở Info.plist | |
| 3 | User đã cấp "Always" permission | Settings → Privacy → Location | |
| 4 | SLC log: "SLC monitoring started (Always auth)" | Xcode Console | |
| 5 | SLC log: "App re-launched by Significant Location Change" | Console.app | |
| 6 | Server nhận GPS với status="slc_background" | API check | |
| 7 | Test trên thiết bị thật (KHÔNG phải Simulator) | Hardware | |

---

## 7. Giới hạn & Lưu ý

### Tần suất cập nhật
- SLC **KHÔNG** gửi GPS mỗi 5 giây như `startUpdatingLocation()`
- SLC gửi khi **di chuyển ≥ 500m** hoặc **cell tower thay đổi**
- Trên thực tế: khoảng **mỗi 5-15 phút** khi đang di chuyển trong thành phố
- Khi đứng yên: **KHÔNG có sự kiện nào**

### Độ chính xác
- SLC dựa trên cell tower → độ chính xác khoảng **100-500m** (không phải GPS chính xác 5m)
- Phù hợp cho: fleet tracking, delivery tracking, logistics
- KHÔNG phù hợp cho: fitness tracking, navigation turn-by-turn

### Thời gian xử lý
- Sau khi iOS wake-up app, bạn có **~10 giây** trước khi bị suspend
- **BẮT BUỘC** dùng `URLSession` background, KHÔNG dùng `URLSession.shared` (sẽ bị cancel khi suspend)

### Battery Impact
- SLC tiêu tốn **rất ít pin** (Apple gọi là "significant-change" — không dùng GPS chip)
- Chấp nhận được cho ứng dụng chạy 24/7

### Khi nào SLC KHÔNG hoạt động
1. ❌ User chỉ cấp "When In Use" permission (PHẢI có "Always")
2. ❌ User bật Airplane Mode
3. ❌ Thiết bị không di chuyển (đứng yên hoàn toàn)
4. ❌ iOS Low Power Mode có thể giảm tần suất
5. ❌ User tắt Location Services toàn bộ trong Settings

---

## 8. So sánh SLC vs Standard Location Updates

| Tiêu chí | `startUpdatingLocation()` | `startMonitoringSignificantLocationChanges()` |
|-----------|--------------------------|----------------------------------------------|
| **Tần suất** | Liên tục (theo interval) | Khi di chuyển ≥500m |
| **Độ chính xác** | GPS (5-15m) | Cell tower (100-500m) |
| **Pin** | Cao | Rất thấp |
| **Foreground** | ✅ | ✅ |
| **Background** | ✅ (cần capability) | ✅ |
| **Sau force-kill** | ❌ | ✅ (cần Always auth) |
| **Thời gian xử lý** | Không giới hạn | ~10 giây |
| **Use case** | Navigation, fitness | Fleet tracking, logistics |

### Kết hợp cả hai (khuyến nghị)

```
┌─────────────────────────────────────────────────┐
│  App Active (Foreground/Background)              │
│  → startUpdatingLocation() (GPS chính xác)      │
│  → SLC chạy song song (fallback)                │
├─────────────────────────────────────────────────┤
│  App Force-Killed                                │
│  → startUpdatingLocation() ❌ CHẾT              │
│  → SLC ✅ vẫn hoạt động → gửi GPS đến server   │
├─────────────────────────────────────────────────┤
│  App Re-opened                                   │
│  → Quay lại startUpdatingLocation()              │
│  → SLC vẫn chạy song song                       │
└─────────────────────────────────────────────────┘
```

---

## 9. FAQ

### Q: SLC có cần đăng ký lại mỗi khi app khởi chạy không?
**A**: Có. Sau khi iOS wake-up app, bạn **phải gọi lại** `startMonitoringSignificantLocationChanges()` trong `didFinishLaunchingWithOptions` để iOS tiếp tục gửi sự kiện cho lần di chuyển tiếp theo.

### Q: Nếu user không di chuyển sau force-kill, SLC có gửi GPS không?
**A**: Không. SLC chỉ trigger khi có significant location change (≥500m hoặc cell tower change). Nếu user đứng yên, không có sự kiện nào.

### Q: SLC có hoạt động trên Simulator không?
**A**: Một phần. Simulator có thể simulate location changes, nhưng **không thể test force-kill + wake-up** trên Simulator. Phải dùng thiết bị thật.

### Q: Tại sao payload gửi `"status": "slc_background"`?
**A**: Để phân biệt GPS data đến từ SLC background wake-up vs real-time tracking. Server có thể dùng field này để biết chất lượng dữ liệu (SLC có accuracy thấp hơn).

### Q: Tôi có thể dùng `URLSession.shared` thay vì background URLSession không?
**A**: **KHÔNG.** Sau SLC wake-up, iOS cho app ~10 giây rồi suspend. `URLSession.shared` sẽ bị cancel. Background URLSession chạy trong daemon process riêng, tiếp tục upload ngay cả khi app bị suspend.

### Q: SLC có hoạt động khi thiết bị khởi động lại (reboot) không?
**A**: Có, nếu user đã từng cấp "Always" permission và SLC đã được đăng ký trước khi reboot. iOS sẽ tự động wake-up app khi có significant location change sau reboot.

---

## Tài liệu tham khảo

- [Apple: startMonitoringSignificantLocationChanges()](https://developer.apple.com/documentation/corelocation/cllocationmanager/startmonitoringsignificantlocationchanges())
- [Apple: Handling location updates in the background](https://developer.apple.com/documentation/corelocation/handling-location-updates-in-the-background)
- [Apple: UIApplication.LaunchOptionsKey.location](https://developer.apple.com/documentation/uikit/uiapplication/launchoptionskey/1623101-location)
- [StackOverflow: How to get location when app is killed](https://stackoverflow.com/questions/79005288/how-can-i-get-a-users-location-when-my-ios-app-is-killed-or-terminated-in-swift)
- [transistorsoft/react-native-background-geolocation #2477](https://github.com/transistorsoft/react-native-background-geolocation/issues/2477)
