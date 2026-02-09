# Hướng dẫn kiểm thử VietmapTrackingSDK trên iOS Simulator

## Mục lục

- [1. Cài đặt và cấu hình ban đầu](#1-cài-đặt-và-cấu-hình-ban-đầu)
- [2. Tạo file GPX giả lập GPS](#2-tạo-file-gpx-giả-lập-gps)
- [3. Thêm file GPX vào Xcode project](#3-thêm-file-gpx-vào-xcode-project)
- [4. Hiểu rõ vòng đời Tracking (quan trọng)](#4-hiểu-rõ-vòng-đời-tracking-quan-trọng)
- [5. Implement Tracking đúng cách](#5-implement-tracking-đúng-cách)
- [6. Các cách sử dụng SAI và cần tránh](#6-các-cách-sử-dụng-sai-và-cần-tránh)
- [7. Các bước kiểm thử SDK](#7-các-bước-kiểm-thử-sdk)
- [8. Xử lý sự cố thường gặp](#8-xử-lý-sự-cố-thường-gặp)
- [9. Checklist kiểm thử](#9-checklist-kiểm-thử)

---

## 1. Cài đặt và cấu hình ban đầu

### 1.1 Cài đặt plugin

```bash
npm install @vietmap/rn_vietmap_tracking_plugin
```

### 1.2 Tạo file `react-native.config.js` (bắt buộc)

Plugin `@vietmap/rn_vietmap_tracking_plugin` **không tự autolinking** trên React Native 0.83+. Cần tạo file `react-native.config.js` ở root project:

```javascript
const path = require('path');

const vietmapRoot = path.resolve(
  __dirname,
  'node_modules',
  '@vietmap',
  'rn_vietmap_tracking_plugin',
);

module.exports = {
  dependencies: {
    '@vietmap/rn_vietmap_tracking_plugin': {
      root: vietmapRoot,
      platforms: {
        ios: {
          podspecPath: path.join(vietmapRoot, 'rn_vietmap_tracking_plugin.podspec'),
        },
      },
    },
  },
};
```

### 1.3 Cài đặt CocoaPods

```bash
cd ios && pod install
```

Kiểm tra autolinking đã phát hiện plugin:

```bash
npx react-native config 2>&1 | grep -i vietmap
```

Kết quả phải chứa `@vietmap/rn_vietmap_tracking_plugin`.

### 1.4 Cấu hình `Info.plist`

File `ios/VietmapTrackingApp/Info.plist` cần có đầy đủ các key sau:

```xml
<!-- Quyền vị trí -->
<key>NSLocationWhenInUseUsageDescription</key>
<string>This app needs location access to track your GPS location when using the app.</string>
<key>NSLocationAlwaysAndWhenInUseUsageDescription</key>
<string>This app needs continuous location access to track your GPS location even when the app is in the background.</string>
<key>NSLocationAlwaysUsageDescription</key>
<string>This app needs background location access to provide continuous GPS tracking.</string>

<!-- Background Modes -->
<key>UIBackgroundModes</key>
<array>
    <string>location</string>
    <string>background-processing</string>
    <string>background-fetch</string>
</array>

<!-- Background Task Identifiers (cả 2 đều bắt buộc) -->
<key>BGTaskSchedulerPermittedIdentifiers</key>
<array>
    <string>com.vietmaptrackingsdk.location-sync</string>
    <string>com.vietmaptrackingsdk.background-location</string>
</array>
```

> ⚠️ **Lưu ý quan trọng:** Không được khai báo trùng lặp key `NSLocationWhenInUseUsageDescription`. Nếu có 2 entry, entry sau (giá trị rỗng) sẽ ghi đè entry trước → iOS từ chối cấp quyền.

---

## 2. Tạo file GPX giả lập GPS

### 2.1 Tại sao cần file GPX?

iOS Simulator **không có GPS thật**. Để kiểm thử tracking, cần tạo file `.gpx` chứa tọa độ giả lập. File GPX cho phép:

- Mô phỏng di chuyển liên tục theo lộ trình
- Tùy chỉnh tốc độ, khoảng cách, thời gian
- Đặt tọa độ ở **bất kỳ đâu trên thế giới** (không bị giới hạn ở Mỹ)

### 2.2 Format GPX chuẩn cho Xcode

Dựa trên format của [GPXRouteCreator](https://github.com/dasdom/GPXRouteCreator):

```xml
<?xml version="1.0"?>
<gpx version="1.1" creator="GPXRouteCreator">

<wpt lat="10.779785" lon="106.699015">
<time>2026-02-09T07:00:00Z</time>
</wpt>

<wpt lat="10.779520" lon="106.698830">
<time>2026-02-09T07:00:05Z</time>
</wpt>

<!-- ... thêm các waypoint khác ... -->

</gpx>
```

### 2.3 Quy tắc tạo waypoint

| Thông số | Khuyến nghị | Giải thích |
|----------|-------------|------------|
| **Format thời gian** | `yyyy-MM-dd'T'HH:mm:ss'Z'` | ISO 8601, UTC timezone |
| **Khoảng cách thời gian** | 5 giây/waypoint | Phù hợp cho mô phỏng chạy bộ |
| **Khoảng cách tọa độ** | ~0.0003° lat/lon (~15-30m) | Tương đương tốc độ chạy bộ ~10 km/h |
| **Số lượng waypoint** | ≥ 40 points | Đủ để kiểm thử trong ~3-4 phút |
| **Không cần tag `<name>`** | Bỏ qua | Không ảnh hưởng đến simulation |
| **Không cần xmlns/xsi** | Bỏ qua | Xcode không yêu cầu |

### 2.4 Tính toán tọa độ

Công thức ước tính:

- **1° latitude** ≈ 111,000 m
- **1° longitude** (tại HCM, lat ~10.78°) ≈ 109,000 m
- **Tốc độ chạy bộ ~10 km/h** = ~2.78 m/s
- **Mỗi 5 giây** di chuyển ~14m → thay đổi tọa độ ~0.00013°

### 2.5 File GPX mẫu: City Run Quận 1, HCM

Lộ trình: **Nhà thờ Đức Bà → Lê Duẩn → Nam Kỳ Khởi Nghĩa → Dinh Độc Lập → Công viên 30/4 → Lê Lợi → Nguyễn Huệ → Đồng Khởi → quay lại Nhà thờ Đức Bà**

File: `ios/VietmapTrackingApp/CityRunHCM.gpx` — 51 waypoints, ~4 phút 15 giây.

---

## 3. Thêm file GPX vào Xcode project

### Bước 1: Mở workspace trong Xcode

```bash
open ios/VietmapTrackingApp.xcworkspace
```

> ⚠️ Phải mở `.xcworkspace`, **KHÔNG** mở `.xcodeproj`

### Bước 2: Thêm file GPX

1. Trong **Project Navigator** (panel trái), chuột phải vào folder **VietmapTrackingApp**
2. Chọn **Add Files to "VietmapTrackingApp"...**
3. Tìm và chọn file `CityRunHCM.gpx`
4. Đảm bảo tick ☑️ **VietmapTrackingApp** trong phần Target Membership
5. Nhấn **Add**

### Bước 3: Kích hoạt GPX khi chạy app

1. Build & Run app từ Xcode (**⌘R**) hoặc terminal (`npx react-native run-ios`)
2. Khi app đã chạy trên Simulator, trong **Xcode** tìm **thanh Debug toolbar** (phía dưới)
3. Nhấn vào **biểu tượng 📍 (Location)** trên thanh Debug
4. Chọn **CityRunHCM** từ danh sách
5. Simulator sẽ bắt đầu phát lại lộ trình GPS theo thứ tự waypoint

---

## 4. Hiểu rõ vòng đời Tracking (quan trọng)

### 4.1 SDK là GPS Tracker thuần túy, KHÔNG phải Navigation

SDK `@vietmap/rn_vietmap_tracking_plugin` là hệ thống **ghi nhận vị trí GPS liên tục**. Nó **KHÔNG** phải navigation SDK (không có khái niệm điểm đi, điểm đến, hay tuyến đường hoàn thành).

| Đặc điểm | GPS Tracker (SDK này) | Navigation SDK |
|---|---|---|
| Biết "điểm đến"? | ❌ Không | ✅ Có |
| Tự dừng khi đến nơi? | ❌ Không | ✅ Có |
| Hiểu "tuyến đường"? | ❌ Không — chỉ ghi tọa độ | ✅ Có — theo route |
| Dừng tracking | Thủ công bắt buộc | Tự động khi đến đích |

### 4.2 Tracking KHÔNG BAO GIỜ tự động dừng

SDK **không có bất kỳ cơ chế tự động dừng nào**:

| Điều kiện | SDK tự dừng? | Thực tế xảy ra |
|---|---|---|
| GPX chạy hết waypoint cuối | ❌ Không | SDK chờ location update tiếp, tracking vẫn active |
| Hết thời gian (timeout) | ❌ Không | Không có config `maxDuration` hay `TTL` |
| Đạt khoảng cách nhất định | ❌ Không | Không có config `maxDistance` |
| Pin yếu | ❌ Không | SDK không kiểm tra pin |
| Lỗi GPS nhiều lần | ❌ Không | Chỉ gửi event `onLocationError`, tracking tiếp tục |
| Mất mạng | ❌ Không | SDK cache data, upload khi có mạng lại |
| Thu hồi quyền location | ❌ Không | Chỉ gửi event `onPermissionChanged` |
| User không di chuyển (idle) | ❌ Không | Không có idle detection |

### 4.3 Khi test GPX trên Simulator: Tracking vẫn chạy sau waypoint cuối

```
GPX bắt đầu phát
  │
  ▼
waypoint 1 → waypoint 2 → ... → waypoint 51 (điểm cuối GPX)
                                       │
                                       ▼
                          ┌────────────────────────────┐
                          │  SDK KHÔNG biết đây là     │
                          │  "điểm cuối". Với SDK,     │
                          │  đây chỉ là 1 tọa độ      │
                          │  location update bình thường│
                          └────────────────────────────┘
                                       │
                        ┌──────────────┴──────────────┐
                        │                             │
              iOS Simulator lặp GPX          iOS Simulator dừng GPX
              → Tọa độ lặp lại từ đầu       → Không có update mới
              → SDK tracking tiếp tục        → SDK vẫn ở trạng thái tracking
              → KHÔNG TỰ DỪNG               → KHÔNG TỰ DỪNG
                        │                             │
                        └──────────────┬──────────────┘
                                       │
                                       ▼
                          ╔════════════════════════════╗
                          ║  User PHẢI bấm             ║
                          ║  "⏹️ Dừng Tracking"        ║
                          ║  → gọi stopLocationTracking()║
                          ╚════════════════════════════╝
```

### 4.4 Vòng đời đầy đủ của một phiên tracking

```
┌─────────────────────────────────────────────────────────────────┐
│ 1. CONFIGURE (chỉ 1 lần khi app khởi động)                     │
│    configure(apiKey)                                            │
│    configureAlertAPI(apiKey, apiID)  ← tùy chọn                │
├─────────────────────────────────────────────────────────────────┤
│ 2. REQUEST PERMISSIONS                                          │
│    requestLocationPermissions()                                 │
│    requestAlwaysLocationPermissions()  ← cho background         │
├─────────────────────────────────────────────────────────────────┤
│ 3. ĐĂNG KÝ LISTENERS (trước khi start tracking)                │
│    addLocationUpdateListener(callback)                          │
│    addTrackingStatusListener(callback)                          │
├─────────────────────────────────────────────────────────────────┤
│ 4. START TRACKING                                               │
│    startLocationTracking(config)                                │
│    → SDK bắt đầu gửi event onLocationUpdate liên tục           │
│    → SDK gửi event onTrackingStatusChanged                      │
├─────────────────────────────────────────────────────────────────┤
│ 5. TRACKING ĐANG CHẠY (vô thời hạn)                            │
│    • Nhận location updates qua listener                         │
│    • isTrackingActive() → true                                  │
│    • getTrackingStatus() → {isTracking: true, ...}              │
│    • SDK auto-upload data lên server khi có mạng                │
│                                                                 │
│    ⚠️ KHÔNG CÓ TỰ DỪNG — chạy cho đến khi gọi stop            │
├─────────────────────────────────────────────────────────────────┤
│ 6. STOP TRACKING (BẮT BUỘC GỌI THỦ CÔNG)                      │
│    stopLocationTracking()                                       │
│    → SDK dừng gửi event                                         │
│    → Hủy listeners                                              │
│    → Hiển thị thống kê phiên                                    │
├─────────────────────────────────────────────────────────────────┤
│ 7. CLEANUP (khi component unmount / app đóng)                   │
│    Hủy tất cả listeners                                         │
│    Gọi stopLocationTracking() nếu còn đang tracking             │
└─────────────────────────────────────────────────────────────────┘
```

### 4.5 Hành vi khi app vào background / bị kill

| Tình huống | iOS | Android |
|---|---|---|
| App vào background | Tracking tiếp tục nếu có `backgroundMode: true` + quyền "Always" + `UIBackgroundModes: location` | Foreground Service giữ tracking chạy |
| App bị user kill (swipe close) | Tracking dừng. Không có cơ chế restart | `START_STICKY` service cố restart, nhưng RN bridge đã mất |
| App bị OS kill (low memory) | Tracking dừng | Service có thể được restart bởi OS |
| RN module bị invalidate (hot reload) | Callbacks bị xóa, **nhưng tracking có thể vẫn chạy** (zombie) | `invalidate()` gọi `stopTracking()` — dừng sạch |

> ⚠️ **Rủi ro "Zombie Tracking" trên iOS**: Nếu module RN bị `deinit` mà không gọi `stopLocationTracking()` trước, native `CLLocationManager` có thể vẫn chạy ngầm → tiêu tốn pin mà không ai điều khiển được.

---

## 5. Implement Tracking đúng cách

### 5.1 Tracking Presets có sẵn

SDK cung cấp 4 preset cấu hình:

| Preset | `intervalMs` | `distanceFilter` | `accuracy` | Phù hợp cho |
|---|---|---|---|---|
| `TrackingPresets.NAVIGATION` | 1000ms (1s) | 5m | high | Dẫn đường, độ chính xác cao |
| `TrackingPresets.FITNESS` | 5000ms (5s) | 10m | high | Chạy bộ, đạp xe |
| `TrackingPresets.GENERAL` | 30000ms (30s) | 50m | medium | Theo dõi chung |
| `TrackingPresets.BATTERY_SAVER` | 300000ms (5 phút) | 100m | low | Tiết kiệm pin |

**Lưu ý khi chọn preset cho test:**
- Dùng `NAVIGATION` hoặc `FITNESS` khi test với GPX (waypoint cách 5s → cần `intervalMs` ≤ 5000ms)
- Nếu dùng `GENERAL` (30s) với GPX 5s/waypoint → sẽ **bỏ lỡ nhiều waypoint**, data test không chính xác
- `BATTERY_SAVER` (5 phút) **không phù hợp** cho test GPX ngắn

### 5.2 Thứ tự gọi hàm chính xác

```typescript
// ✅ THỨ TỰ ĐÚNG:

// Bước 1: Configure SDK (1 lần duy nhất khi app khởi động)
await configure(API_KEY);
await configureAlertAPI(ALERT_API_KEY, ALERT_API_ID);

// Bước 2: Request permissions
const permission = await requestLocationPermissions();
if (Platform.OS === 'ios') {
  await requestAlwaysLocationPermissions();
}

// Bước 3: Đăng ký listeners TRƯỚC khi start
const locationSub = addLocationUpdateListener((location) => { ... });
const statusSub = addTrackingStatusListener((status) => { ... });

// Bước 4: Start tracking
const result = await startLocationTracking(TrackingPresets.NAVIGATION);

// ... tracking đang chạy, nhận events qua listeners ...

// Bước 5: Stop tracking (BẮT BUỘC gọi thủ công)
await stopLocationTracking();

// Bước 6: Hủy listeners
locationSub.remove();
statusSub.remove();
```

### 5.3 Cleanup bắt buộc khi component unmount

```typescript
useEffect(() => {
  // ... setup ...

  return () => {
    // QUAN TRỌNG: Dừng tracking khi component unmount
    // Tránh "zombie tracking" trên iOS
    stopLocationTracking().catch(() => {});

    // Hủy tất cả listeners
    locationListenerRef.current?.remove();
    statusListenerRef.current?.remove();
    permissionListenerRef.current?.remove();
  };
}, []);
```

### 5.4 Xử lý AppState (background/foreground)

Nên theo dõi AppState để xử lý khi app bị đóng:

```typescript
import { AppState } from 'react-native';

useEffect(() => {
  const subscription = AppState.addEventListener('change', (nextAppState) => {
    if (nextAppState === 'inactive' || nextAppState === 'background') {
      // App vào background — tracking vẫn chạy nếu có backgroundMode
      addLog('App vào background, tracking tiếp tục...');
    }
    if (nextAppState === 'active') {
      // App quay lại foreground — kiểm tra trạng thái tracking
      isTrackingActive().then((active) => {
        addLog(`App active, tracking: ${active}`);
        setIsTracking(active);
      });
    }
  });

  return () => subscription.remove();
}, []);
```

### 5.5 Timeout tự động dừng (khuyến nghị cho test)

Vì SDK không tự dừng, nên thêm cơ chế timeout nếu cần:

```typescript
// Tự động dừng tracking sau N phút (ví dụ: 10 phút)
const AUTO_STOP_MINUTES = 10;

const handleStartTracking = async () => {
  await startLocationTracking(config);

  // Đặt timer tự dừng
  const autoStopTimer = setTimeout(async () => {
    if (await isTrackingActive()) {
      await stopLocationTracking();
      addLog('⏱️ Tracking tự động dừng sau timeout');
    }
  }, AUTO_STOP_MINUTES * 60 * 1000);

  // Nhớ clear timer nếu user dừng thủ công trước
  // clearTimeout(autoStopTimer);
};
```

---

## 6. Các cách sử dụng SAI và cần tránh

### ❌ SAI #1: Nghĩ rằng GPX đến điểm cuối → tracking tự dừng

```
❌ SAI: "File GPX có 51 waypoints, chạy xong là tracking tự stop"
✅ ĐÚNG: File GPX chỉ cung cấp tọa độ giả cho Simulator.
         SDK KHÔNG biết GPX là gì, KHÔNG biết đâu là "điểm cuối".
         PHẢI gọi stopLocationTracking() thủ công.
```

**Hậu quả nếu không dừng:** SDK tiếp tục ở trạng thái tracking, tiêu tốn pin, gửi data lên server (dù không có location update mới).

### ❌ SAI #2: Không gọi `stopLocationTracking()` khi unmount

```typescript
// ❌ SAI — chỉ hủy listeners, không dừng tracking
useEffect(() => {
  return () => {
    locationListenerRef.current?.remove();   // Chỉ hủy listener
    statusListenerRef.current?.remove();     // Tracking VẪN CHẠY ngầm!
  };
}, []);

// ✅ ĐÚNG — dừng tracking VÀ hủy listeners
useEffect(() => {
  return () => {
    stopLocationTracking().catch(() => {});  // Dừng tracking trước
    locationListenerRef.current?.remove();
    statusListenerRef.current?.remove();
  };
}, []);
```

**Hậu quả:** Trên iOS, `deinit` của module chỉ xóa callbacks nhưng **không gọi stopTracking** → `CLLocationManager` tiếp tục chạy ngầm (zombie tracking).

### ❌ SAI #3: Đăng ký listeners SAU khi start tracking

```typescript
// ❌ SAI — có thể bỏ lỡ event đầu tiên
await startLocationTracking(config);
const sub = addLocationUpdateListener(callback);  // Quá muộn!

// ✅ ĐÚNG — đăng ký listener trước
const sub = addLocationUpdateListener(callback);
await startLocationTracking(config);
```

**Hậu quả:** Location update đầu tiên và `onTrackingStatusChanged` đầu tiên bị bỏ lỡ.

### ❌ SAI #4: Dùng preset không phù hợp với GPX

```typescript
// ❌ SAI — GPX có waypoint mỗi 5 giây, nhưng preset cập nhật mỗi 30 giây
await startLocationTracking(TrackingPresets.GENERAL);
// → Bỏ lỡ ~5/6 waypoints, data test thiếu chính xác

// ❌ SAI — GPX lộ trình ngắn 4 phút, nhưng preset 5 phút/update
await startLocationTracking(TrackingPresets.BATTERY_SAVER);
// → Có thể CHỈ nhận được 1 location update trong toàn bộ test

// ✅ ĐÚNG — interval ≤ khoảng cách thời gian giữa các waypoint
await startLocationTracking(TrackingPresets.NAVIGATION);  // 1s interval
await startLocationTracking(TrackingPresets.FITNESS);     // 5s interval
```

### ❌ SAI #5: Không bật GPX trên Simulator trước khi start tracking

```
❌ SAI:  Bấm "Bắt đầu Tracking" → rồi mới chọn GPX
         → startLocationTracking có thể trả về false vì CLLocationManager
           chưa có location nào

✅ ĐÚNG: Xcode → Debug bar → 📍 → chọn CityRunHCM
         → Đợi 1-2 giây
         → Rồi mới bấm "Bắt đầu Tracking"
```

### ❌ SAI #6: Gọi `startLocationTracking()` nhiều lần liên tiếp

```typescript
// ❌ SAI — gọi start nhiều lần khi tracking đã đang chạy
handleStartTracking();  // Lần 1
handleStartTracking();  // Lần 2 — tạo session trùng lặp

// ✅ ĐÚNG — kiểm tra trạng thái trước khi gọi
const active = await isTrackingActive();
if (!active) {
  await startLocationTracking(config);
}
```

**Hậu quả:** Có thể tạo nhiều phiên tracking chồng chéo, data bị trùng, hoặc lỗi không xác định.

### ❌ SAI #7: Không kiểm tra `isInitialized` trước khi gọi hàm SDK

```typescript
// ❌ SAI — gọi thẳng không kiểm tra
await startLocationTracking(config);

// ✅ ĐÚNG — đảm bảo SDK đã configure xong
if (!isInitialized) {
  Alert.alert('Lỗi', 'SDK chưa được khởi tạo');
  return;
}
await startLocationTracking(config);
```

**Hậu quả:** Native SDK reject với error `SDK_NOT_INITIALIZED`.

### ❌ SAI #8: Quên gọi `turnOffAlert()` trước khi stop tracking

```typescript
// ❌ SAI — stop tracking nhưng alert vẫn bật
await stopLocationTracking();
// → Speed alert có thể vẫn chạy ngầm

// ✅ ĐÚNG — tắt alert trước, rồi stop tracking
if (isAlertOn) {
  await turnOffAlert();
}
await stopLocationTracking();
```

### ❌ SAI #9: Mở `.xcodeproj` thay vì `.xcworkspace`

```bash
# ❌ SAI — không có CocoaPods dependencies
open ios/VietmapTrackingApp.xcodeproj

# ✅ ĐÚNG — bao gồm tất cả Pods
open ios/VietmapTrackingApp.xcworkspace
```

**Hậu quả:** Build lỗi do thiếu `VietmapTrackingSDK` và các pod khác.

### ❌ SAI #10: Khai báo trùng key trong `Info.plist`

```xml
<!-- ❌ SAI — key trùng lặp, entry sau ghi đè entry trước -->
<key>NSLocationWhenInUseUsageDescription</key>
<string>This app needs location access...</string>
...
<key>NSLocationWhenInUseUsageDescription</key>
<string></string>  <!-- Giá trị rỗng → iOS từ chối cấp quyền -->

<!-- ✅ ĐÚNG — chỉ 1 entry duy nhất -->
<key>NSLocationWhenInUseUsageDescription</key>
<string>This app needs location access to track your GPS location when using the app.</string>
```

### Bảng tóm tắt các lỗi thường gặp

| # | Lỗi | Mức độ | Hậu quả |
|---|---|---|---|
| 1 | Nghĩ GPX tự dừng tracking | 🔴 Nghiêm trọng | Tracking chạy mãi, tốn pin + data |
| 2 | Không stop khi unmount | 🔴 Nghiêm trọng | Zombie tracking trên iOS |
| 3 | Listener sau start | 🟡 Trung bình | Mất event đầu tiên |
| 4 | Preset không phù hợp GPX | 🟡 Trung bình | Data test thiếu chính xác |
| 5 | Không bật GPX trước start | 🟡 Trung bình | startTracking trả về false |
| 6 | Start nhiều lần | 🟡 Trung bình | Session chồng chéo |
| 7 | Không check isInitialized | 🟢 Nhẹ | Error SDK_NOT_INITIALIZED |
| 8 | Quên tắt alert | 🟢 Nhẹ | Alert chạy ngầm |
| 9 | Mở .xcodeproj | 🔴 Nghiêm trọng | Build lỗi |
| 10 | Key trùng Info.plist | 🔴 Nghiêm trọng | Không cấp quyền location |

---

## 7. Các bước kiểm thử SDK

### 7.1 Quy trình khởi động

```
Terminal 1: npx react-native start          ← Metro bundler
Terminal 2: npx react-native run-ios        ← Build & run app
            HOẶC: Xcode → ⌘R               ← Nếu cần GPX simulation
```

> **Lưu ý:** Nếu build từ Xcode, Metro phải đang chạy ở terminal trước. Nếu không sẽ gặp lỗi `"No script URL provided"`.

### 7.2 Flow kiểm thử tracking

```
1. App khởi động → SDK tự khởi tạo (xem log "SDK đã khởi tạo thành công")
2. Xcode → Debug bar → 📍 → chọn CityRunHCM (bật GPS giả lập TRƯỚC)
3. Đợi 1-2 giây cho Simulator nhận tọa độ đầu tiên
4. App → Bấm "▶️ Bắt đầu Tracking"
5. Quan sát:
   - Vị trí hiện tại (lat/lon) cập nhật liên tục
   - Tốc độ (km/h) thay đổi
   - Thống kê phiên (quãng đường, thời gian, số điểm)
   - Nhật ký log các event
6. App → Bấm "⏹️ Dừng Tracking" ← BẮT BUỘC, SDK KHÔNG TỰ DỪNG
7. Kiểm tra thống kê cuối phiên
```

> ⚠️ **QUAN TRỌNG:** Khi GPX chạy đến waypoint cuối cùng, tracking **KHÔNG** tự dừng.
> Simulator có thể lặp GPX từ đầu hoặc dừng tại điểm cuối — nhưng SDK vẫn ở trạng thái tracking.
> **Bạn PHẢI bấm "Dừng Tracking" thủ công** để kết thúc phiên test.

### 7.3 Flow kiểm thử Speed Alert

```
1. Đảm bảo SDK đã khởi tạo thành công
2. Bấm "🔔 Bật cảnh báo tốc độ"
3. Bật tracking + GPX simulation
4. Khi tốc độ vượt ngưỡng → native speech synthesis sẽ cảnh báo
5. Bấm "🔕 Tắt cảnh báo tốc độ" để dừng
```

### 7.4 Flow kiểm thử Get Current Location

```
1. Bật GPX simulation trong Xcode
2. Bấm "📍 Lấy vị trí hiện tại"
3. Kiểm tra log hiển thị lat/lon
```

---

## 8. Xử lý sự cố thường gặp

### ❌ `RnVietmapTrackingPlugin could not be found`

**Nguyên nhân:** Plugin chưa được autolinking.

**Cách sửa:**
1. Tạo file `react-native.config.js` (xem mục 1.2)
2. Chạy `cd ios && pod install`
3. Build lại app

### ❌ `No script URL provided`

**Nguyên nhân:** Build từ Xcode nhưng Metro bundler chưa chạy.

**Cách sửa:**
```bash
npx react-native start    # Chạy trước
# Sau đó mới build từ Xcode (⌘R)
```

### ❌ `Registration rejected; com.vietmaptrackingsdk.background-location is not advertised`

**Nguyên nhân:** Thiếu background task identifier trong `Info.plist`.

**Cách sửa:** Thêm `com.vietmaptrackingsdk.background-location` vào `BGTaskSchedulerPermittedIdentifiers` (xem mục 1.4).

### ❌ `startLocationTracking` trả về `false`

**Nguyên nhân có thể:**
- Chưa bật GPS giả lập trên Simulator
- Quyền vị trí chưa được cấp
- SDK chưa khởi tạo xong

**Cách debug:**
1. Xem log `SDK status: {...}` trong Nhật ký
2. Kiểm tra `isTrackingActive` có trả `true` không (SDK có thể đang chạy dù trả `false`)
3. Đảm bảo đã chọn GPX file trong Xcode Debug bar trước khi bấm tracking

### ⚠️ `Sending 'onPermissionChanged' with no listeners registered`

**Nguyên nhân:** Native SDK phát event permission trước khi JS đăng ký listener.

**Cách sửa:** Đăng ký listener `onPermissionChanged` trong `useEffect` trước khi gọi `initializeSDK()`.

### ⚠️ `NSLocationWhenInUseUsageDescription` bị rỗng

**Nguyên nhân:** `Info.plist` có 2 entry trùng key, entry sau ghi đè với giá trị rỗng.

**Cách sửa:** Xóa entry trùng lặp, chỉ giữ 1 entry có giá trị mô tả đầy đủ.

---

## 9. Checklist kiểm thử

### Trước khi kiểm thử

- [ ] `react-native.config.js` đã tạo ở root project
- [ ] `pod install` đã chạy thành công (log có `rn_vietmap_tracking_plugin`)
- [ ] `Info.plist` có đủ 3 permission key (WhenInUse, AlwaysAndWhenInUse, Always)
- [ ] `Info.plist` có `UIBackgroundModes` (location, background-processing, background-fetch)
- [ ] `Info.plist` có `BGTaskSchedulerPermittedIdentifiers` (cả 2 identifier)
- [ ] `Info.plist` **không có** key trùng lặp
- [ ] File GPX đã thêm vào Xcode project
- [ ] API key đã cấu hình đúng trong `App.tsx`

### Khi kiểm thử

- [ ] Metro bundler đang chạy
- [ ] App build thành công, không lỗi native
- [ ] Đã cấp quyền vị trí "Allow While Using App" hoặc "Always Allow"
- [ ] Đã chọn GPX file trong Xcode Debug bar **TRƯỚC KHI** bấm Start Tracking
- [ ] SDK khởi tạo thành công (log `✅ SDK đã khởi tạo thành công`)
- [ ] Tracking bắt đầu thành công
- [ ] Vị trí cập nhật liên tục trên UI
- [ ] Tốc độ hiển thị hợp lý (≈ 10 km/h cho city run)
- [ ] **Dừng tracking THỦ CÔNG** bằng nút "⏹️ Dừng Tracking" (SDK không tự dừng)
- [ ] Dừng tracking hiển thị thống kê phiên
- [ ] Speed alert bật/tắt thành công

### Lưu ý quan trọng khi test

- [ ] Dùng `TrackingPresets.NAVIGATION` (1s) hoặc `FITNESS` (5s) — KHÔNG dùng `GENERAL` hay `BATTERY_SAVER` cho GPX test
- [ ] Listeners được đăng ký TRƯỚC khi gọi `startLocationTracking()`
- [ ] `stopLocationTracking()` được gọi trong cleanup của `useEffect`
- [ ] Không gọi `startLocationTracking()` khi tracking đã đang chạy
- [ ] Alert (nếu bật) được tắt TRƯỚC khi stop tracking

---

## Tham khảo

- [NPM: @vietmap/rn_vietmap_tracking_plugin](https://www.npmjs.com/package/@vietmap/rn_vietmap_tracking_plugin)
- [Apple: Simulating Location in Tests](https://developer.apple.com/documentation/xcode/simulating-location-in-tests)
- [GPXRouteCreator](https://github.com/dasdom/GPXRouteCreator) — Tool tạo file GPX cho iOS
