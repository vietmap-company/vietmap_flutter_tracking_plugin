# Plan: Fix `getCurrentLocation` — tách khỏi luồng tracking + on-demand fix

## Mục tiêu
`getCurrentLocation()` phải lấy được vị trí **kể cả khi chưa từng `startTracking`**, bằng cách:
1. **Nguồn chính**: lấy fix on-demand từ device (FusedLocation / CLLocationManager).
2. **Cache** (mem + disk) để tăng tốc các lần gọi sau & khi mở lại app.
3. **Tách method khỏi `isTracking`** — không còn phụ thuộc vòng đời tracking.

> Lưu ý: KHÔNG dùng server endpoint (`/gps-tracking/latest/users/{userId}`) làm fallback —
> đó là "vị trí cuối cùng đã báo cáo", không phải vị trí hiện tại, đưa vào sẽ sai ngữ nghĩa.

## Bối cảnh hiện tại (đã trace)
- Android: `handleGetCurrentLocation` → `vietmapSDK.getLastLocation()` chỉ trả field `lastLocation`, set DUY NHẤT tại `onLocationUpdate` (VietmapTrackingSDK.java:1413) → chỉ có khi đang tracking.
- iOS: `getCurrentLocation` → `trackingManager.getCurrentLocation()` (VietmapTrackingWrapper.swift:86) → cũng cached, cùng pattern.
- Kênh Dart đã async (`Future<LocationData>`) → chuyển native sang async KHÔNG phá vỡ API surface.
- Deps có sẵn: Android `play-services-location:21.0.1` (hỗ trợ `getCurrentLocation(CurrentLocationRequest, CancellationToken)`); iOS `CLLocationManager.requestLocation()`.

## Luồng phân tầng (cả 2 nền tảng)
```
getCurrentLocation({timeoutMs=5000, maxAgeMs=10000})
 1. mem lastLocation   nếu age ≤ maxAgeMs            → source: live    (~0ms)
 2. system last fix     FusedLocation.getLastLocation / CLLocation cached, nếu fresh+accurate → source: cache
 3. ACTIVE single fix   getCurrentLocation()/requestLocation(), timeout=timeoutMs → source: fresh  ← LÕI SỬA
 4. disk last fix        nếu offline/GPS off                → source: disk
 5. fail                → error code rõ ràng
```

## Hợp đồng API mới
### Dart — `LocationData` (lib/src/models/location_data.dart)
Thêm 2 field (optional, backward-compatible):
- `final String? source;`  // live | cache | fresh | disk
- `final int? ageMs;`
Parse thêm trong `fromJson` (key `source`, `ageMs`). KHÔNG đưa vào `toJson` (payload backend giữ nguyên).

### Dart — options
```dart
class GetCurrentLocationOptions {
  final int timeoutMs;       // default 5000
  final int maxAgeMs;        // default 10000
  Map<String,dynamic> toMap();
}
```

### Error codes (thống nhất Android + iOS), thay `LOCATION_UNAVAILABLE`:
`LOCATION_PERMISSION_DENIED` · `LOCATION_DISABLED` · `LOCATION_TIMEOUT` · `SDK_NOT_INITIALIZED`

---

## CÔNG VIỆC THEO FILE

### SDK Android — `map-sdk-tracking`
**VietmapTrackingManager.java**
- [x] `requestActiveFix(int timeoutMs, SingleFixCallback cb)` + orchestrator `getCurrentLocation(maxAgeMs, timeoutMs, cb)`:
  - check permission → fail `LOCATION_PERMISSION_DENIED`.
  - `fusedLocationClient.getCurrentLocation(new CurrentLocationRequest.Builder().setPriority(Priority.PRIORITY_HIGH_ACCURACY).setMaxUpdateAgeMillis(maxAgeMs).setDurationMillis(timeoutMs).build(), cancellationToken)`.
  - addOnSuccessListener: null → fallback; có → trả + `persistLastFix(location)`.
  - timeout handler (Handler.postDelayed + CancellationTokenSource.cancel()) → `LOCATION_TIMEOUT`.
- [x] `persistLastFix(Location)` / `restoreLastFix()` qua SharedPreferences (`vm_tracking_prefs`, lat/lng lưu raw long bits giữ precision).
- [x] `getLastKnownLocation()` = mem `lastLocationUpdate` ?? disk restore.

**VietmapTrackingSDK.java**
- [x] `getCurrentLocation(maxAgeMs, timeoutMs, LocationResultCallback cb)` điều phối tầng 1→4.
- [x] giữ `getLastLocation()` cũ (đọc mem) để không vỡ caller hiện có; thêm `getLastKnownLocation()` (mem ?? disk).
- [x] khi `onLocationResult` set `lastLocationUpdate` → cũng `persistLastFix`.

### SDK iOS — `map-sdk-tracking/ios/VietmapTrackingSDK`
**EnhancedLocationManager.swift**
- [ ] thêm `requestSingleLocation(timeoutMs, completion: (CLLocation?, Error?)->Void)`:
  - dùng `CLLocationManager.requestLocation()` (one-shot) + lưu completion vào mảng pending.
  - trong `didUpdateLocations` / `didFailWithError`: resolve pending completions.
  - timeout qua `DispatchQueue.asyncAfter` → trả lỗi timeout.
- [ ] persist last fix vào `UserDefaults` (`vm_tracking_last_fix`); `lastKnownLocation` getter (mem ?? UserDefaults).

**VietmapTrackingWrapper.swift**
- [ ] expose `getCurrentLocation(timeoutMs:maxAgeMs:completion:)` async + `getLastKnownLocation()`.

### Plugin Android — `VietmapTrackingPlugin.kt` ✅ DONE
- [x] `handleGetCurrentLocation(call, result)` (thêm `call` để đọc args): parse `timeoutMs/maxAgeMs`.
- [x] bỏ phụ thuộc `isTracking`; gọi `vietmapSDK.getCurrentLocation(...)` async → `result.success(map + source + ageMs)` / `result.error(code,...)`.
- [x] map error codes; đổi dispatcher: `"getCurrentLocation" -> handleGetCurrentLocation(call, result)`.
- [x] giữ các log diagnostic.

### Plugin iOS — `VietmapTrackingPlugin.swift`
- [ ] `getCurrentLocation(_ call:, result:)` (thêm `call`): parse args, gọi wrapper async, defer result, map error codes; sửa dispatcher dòng 245-246.

### Dart layer
- [ ] `vietmap_tracking_platform_interface.dart`: `getCurrentLocation({GetCurrentLocationOptions? options})`.
- [ ] `method_channel_vietmap_tracking.dart`: truyền args; map `PlatformException.code` → `LocationException` enum.
- [ ] `vietmap_tracking_controller.dart`: forward options; cân nhắc thêm `getLastKnownLocation()`.
- [ ] `location_data.dart`: thêm `source`, `ageMs`.
- [ ] example `tracking_provider.dart` + `main.dart`: hiển thị `source`/`age` trong snackbar để verify trực quan.

---

## Ma trận test
| Case | Kỳ vọng |
|---|---|
| Chưa tracking + GPS on | tầng 3 → source: fresh |
| Chưa tracking + offline + có disk | tầng 4 → source: disk |
| User mới + offline (không gì cả) | error LOCATION_DISABLED/TIMEOUT, không crash |
| Đang tracking | tầng 1 → source: live, tức thì |
| Permission denied | LOCATION_PERMISSION_DENIED |
| GPS yếu quá timeout | LOCATION_TIMEOUT |
- [ ] Unit test Dart: map error code → exception.
- [ ] Android instrumented + iOS RunnerTests: cập nhật mock `getCurrentLocation` (hiện trả dummy/null).

## Thứ tự rollout
1. **Android tier 3** (on-demand fix) — fix gốc, test nhanh trên máy đang chạy (đã ở mavenLocal 1.0.5).
2. Local disk persistence (tầng 1/4).
3. iOS parity (tier 3 + disk).
4. Error-code chuẩn hoá + metadata `source/ageMs` + Dart layer.

## Build/verify
- SDK Android: `bash map-sdk-tracking/android/publish.sh` → mavenLocal 1.0.5 (plugin đã trỏ về local).
- SDK iOS: rebuild framework + pod nếu cần.
- Rebuild example app, chạy lại nút Get Location, xem logcat `source`.

## Lưu ý tương thích
- Giữ `getLastLocation()`/`getCurrentLocation()` cũ hoạt động (thêm mới, không xoá) để không vỡ caller.
- `source`/`ageMs` optional → app cũ không bị ảnh hưởng.
- build.gradle đang trỏ mavenLocal `1.0.5`; trước khi release nhớ trỏ lại JitPack + bump version SDK.
