import 'dart:async';
import 'package:battery_plus/battery_plus.dart';
import 'package:flutter/foundation.dart';
import '../platform/vietmap_tracking_platform_interface.dart';

/// Ngưỡng phần trăm pin thấp — khi dưới mức này sẽ áp dụng chế độ tiết kiệm.
const int _kLowBatteryThreshold = 15;

/// Độ thay đổi heading (độ) để coi là đang cua — switch sang navigation.
const double _kCorneringHeadingDelta = 15.0;

/// Số giây heading ổn định (đường thẳng) trước khi switch về preferredMovingProfile.
const int _kStraightRoadThresholdSec = 30;

/// Trạng thái hoạt động của xe (tương tự Android Activity Recognition).
/// Flutter-layer phát hiện thông qua tốc độ GPS từ SDK.
enum VehicleActivityState {
  /// Xe đang di chuyển bình thường.
  moving,

  /// Xe đứng yên (speed ≈ 0 trong một khoảng thời gian).
  stationary,
}

/// Trạng thái chuyển động chi tiết — phát hiện qua heading thay đổi.
enum _MotionDetail {
  /// Đang đi đường thẳng hoặc chưa xác định.
  straight,

  /// Đang vào khúc cua (heading delta > 15°).
  cornering,
}

/// Profile cấu hình tracking được SmartBatteryManager lựa chọn.
enum SmartBatteryProfile {
  /// GPS dày — dành cho điều hướng chính xác.
  navigation,

  /// Cân bằng giữa độ chính xác và pin.
  general,

  /// Tiết kiệm pin tối đa.
  batterySaver,
}

class SmartBatteryManager {
  SmartBatteryManager._();
  static final SmartBatteryManager instance = SmartBatteryManager._();

  // ── Dependencies ─────────────────────────────────────────────────────────

  final _battery = Battery();
  final _platform = VietmapTrackingPlatform.instance;

  // ── State ─────────────────────────────────────────────────────────────────

  bool _enabled = false;
  bool get isEnabled => _enabled;

  SmartBatteryProfile _currentProfile = SmartBatteryProfile.general;
  SmartBatteryProfile get currentProfile => _currentProfile;

  VehicleActivityState _vehicleState = VehicleActivityState.moving;
  VehicleActivityState get vehicleState => _vehicleState;

  /// Profile tối đa được phép dùng khi pin bình thường + xe chạy.
  /// Mặc định: `general`. Đặt sang `navigation` để ưu tiên độ chính xác.
  SmartBatteryProfile preferredMovingProfile = SmartBatteryProfile.general;

  /// Callback cho phép app layer cung cấp custom config cho profile `general`.
  ///
  /// Khi được set, SmartBattery sẽ **không** gọi native preset `general`
  /// mà thay vào đó gọi callback này để app tự apply config.
  /// Chỉ áp dụng cho `general` — `navigation` và `batterySaver` vẫn dùng native preset.
  Future<void> Function()? customGeneralConfigOverride;

  // ── Streams & subscriptions ───────────────────────────────────────────────

  StreamSubscription<BatteryState>? _batteryStateSub;
  Timer? _stationaryTimer;

  int _lastBatteryLevel = 100;
  bool _isCharging = false;
  DateTime? _lastBatteryFetchTime;

  // Biến phát hiện xe đứng yên qua speed của GPS points
  int _stationarySeconds = 0;

  /// Thời gian liên tiếp (giây) tốc độ ≈ 0 trước khi coi là đứng yên.
  static const int _stationaryThresholdSec = 60;

  // ── Heading / cornering detection ────────────────────────────────────────
  double? _lastHeading;
  _MotionDetail _motionDetail = _MotionDetail.straight;
  Timer? _straightRoadTimer;   // đếm ngược để switch về straight sau khi hết cua
  int _straightSeconds = 0;

  /// Stream thông báo mỗi lần profile thay đổi.
  final _profileController =
      StreamController<SmartBatteryProfile>.broadcast();
  Stream<SmartBatteryProfile> get onProfileChanged => _profileController.stream;

  // ── Public API ────────────────────────────────────────────────────────────

  /// Đọc trước mức pin ngay sau khi SDK configure() — không cần bật tracking.
  ///
  /// Gọi trong [VietmapTrackingController.configure] để khi [enable] được gọi
  /// sau [startTracking], pin đã biết → bỏ qua hoàn toàn delay khởi động.
  Future<void> prefetchBattery() async {
    try {
      _lastBatteryLevel = await _battery.batteryLevel;
      final state = await _battery.batteryState;
      _isCharging = state == BatteryState.charging || state == BatteryState.full;
      _lastBatteryFetchTime = DateTime.now();
      debugPrint(
        '[SmartBattery] prefetch | level=$_lastBatteryLevel% charging=$_isCharging',
      );
    } catch (e) {
      debugPrint('[SmartBattery] prefetchBattery failed: $e');
    }
  }

  /// Cập nhật [preferredMovingProfile] và áp dụng ngay nếu SmartBattery đang chạy.
  ///
  /// Gọi bất kỳ lúc nào — kể cả khi đang tracking.
  void setPreferredMovingProfile(SmartBatteryProfile profile) {
    preferredMovingProfile = profile;
    if (_enabled) {
      _applyBestProfile();
    }
  }

  /// Bật SmartBatteryManager. Tự động được gọi bởi `startTracking()`.
  Future<void> enable({
    SmartBatteryProfile preferredMoving = SmartBatteryProfile.general,
  }) async {
    preferredMovingProfile = preferredMoving;
    if (_enabled) {
      // Đã chạy rồi — chỉ cập nhật preferred profile và áp dụng lại
      await _applyBestProfile();
      return;
    }
    _enabled = true;

    debugPrint('[SmartBattery] Enabled | preferredMoving=$preferredMoving');

    // Lắng nghe sự kiện pin do OS phát ra (charge/discharge/full).
    _batteryStateSub = _battery.onBatteryStateChanged.listen(_onBatteryStateChanged);

    // Đọc pin ngay — configure() đã gọi prefetchBattery() trước nên thường
    // đã có giá trị sẵn. Không cần delay vì safeUpdateTrackingConfig trên
    // Android chỉ re-register FLP, không restart FGS.
    await _checkBatteryLevel();
  }

  /// Tắt SmartBatteryManager. Gọi trước hoặc sau `stopTracking()`.
  void disable() {
    if (!_enabled) return;
    _enabled = false;

    _batteryStateSub?.cancel();
    _stationaryTimer?.cancel();
    _straightRoadTimer?.cancel();
    _batteryStateSub = null;
    _stationaryTimer = null;
    _straightRoadTimer = null;
    _lastHeading = null;
    _motionDetail = _MotionDetail.straight;
    _straightSeconds = 0;
    _stationarySeconds = 0;
    // Reset profile so next enable() starts clean — prevents stale profile
    // from previous session triggering a surprise override immediately on re-enable.
    _currentProfile = SmartBatteryProfile.general;

    debugPrint('[SmartBattery] Disabled');
  }

  /// Gọi mỗi lần nhận được một GPS location update.
  ///
  /// - [speedMs]: tốc độ (m/s) từ `LocationData.speed` — phát hiện xe đứng yên.
  /// - [heading]: hướng đầu xe (0–360°) từ `LocationData.heading` — phát hiện góc cua.
  ///   Truyền `null` nếu GPS không cung cấp heading.
  void onLocationUpdate(double speedMs, {double? heading}) {
    if (!_enabled) return;

    // ── 1. Phát hiện xe đứng yên ─────────────────────────────────────────
    if (speedMs < 0.5) {
      // Dừng cornering timer vì xe không chạy
      _clearStraightRoadTimer();
      _setMotionDetail(_MotionDetail.straight);

      _stationaryTimer ??= Timer.periodic(
        const Duration(seconds: 10),
        (_) => _onStationaryTick(),
      );
    } else {
      // Xe đang di chuyển
      if (_vehicleState == VehicleActivityState.stationary) {
        _stationarySeconds = 0;
        _stationaryTimer?.cancel();
        _stationaryTimer = null;
        _setVehicleState(VehicleActivityState.moving);
      }

      // ── 2. Phát hiện góc cua (chỉ khi tốc độ đủ lớn > 3 m/s ≈ 10 km/h) ──
      if (heading != null && speedMs > 3.0) {
        _detectCornering(heading);
      }
    }
  }

  /// Tính độ lệch heading có tính vòng tròn (0–360°).
  double _headingDelta(double prev, double curr) {
    double delta = (curr - prev).abs();
    if (delta > 180) delta = 360 - delta;
    return delta;
  }

  void _detectCornering(double heading) {
    final prev = _lastHeading;
    _lastHeading = heading;
    if (prev == null) return;

    final delta = _headingDelta(prev, heading);

    if (delta >= _kCorneringHeadingDelta) {
      // Đang cua → chuyển sang navigation ngay
      _clearStraightRoadTimer();
      _straightSeconds = 0;
      _setMotionDetail(_MotionDetail.cornering);
    } else {
      // Heading ổn định — nếu vừa từ cornering ra, bắt đầu đếm ngược
      if (_motionDetail == _MotionDetail.cornering) {
        _straightRoadTimer ??= Timer.periodic(
          const Duration(seconds: 5),
          (_) => _onStraightRoadTick(),
        );
      }
    }
  }

  void _onStraightRoadTick() {
    _straightSeconds += 5;
    if (_straightSeconds >= _kStraightRoadThresholdSec) {
      _clearStraightRoadTimer();
      _setMotionDetail(_MotionDetail.straight);
      debugPrint('[SmartBattery] Straight road ${_kStraightRoadThresholdSec}s → switch back to preferredProfile');
    }
  }

  void _clearStraightRoadTimer() {
    _straightRoadTimer?.cancel();
    _straightRoadTimer = null;
    _straightSeconds = 0;
  }

  void _setMotionDetail(_MotionDetail detail) {
    if (_motionDetail == detail) return;
    _motionDetail = detail;
    debugPrint('[SmartBattery] motionDetail → $detail');
    _applyBestProfile();
  }

  /// Dispose tất cả resources. Gọi trong `dispose()` của widget.
  void dispose() {
    disable();
    _profileController.close();
  }

  // ── Internal ──────────────────────────────────────────────────────────────

  Future<void> _checkBatteryLevel() async {
    try {
      _lastBatteryLevel = await _battery.batteryLevel;
      final state = await _battery.batteryState;
      _isCharging = state == BatteryState.charging || state == BatteryState.full;
      debugPrint(
          '[SmartBattery] level=$_lastBatteryLevel% charging=$_isCharging');
      await _applyBestProfile();
    } catch (e) {
      debugPrint('[SmartBattery] batteryLevel check failed: $e');
    }
  }

  void _onBatteryStateChanged(BatteryState state) {
    _isCharging = state == BatteryState.charging || state == BatteryState.full;
    debugPrint('[SmartBattery] OS battery state → $state | charging=$_isCharging');
    // Đọc lại mức pin ngay khi OS báo state thay đổi (charging plugged/unplugged,
    // hoặc full). Đây là cách duy nhất cập nhật _lastBatteryLevel sau khi timer
    // polling bị loại bỏ.
    _checkBatteryLevel();
  }

  void _onStationaryTick() {
    _stationarySeconds += 10;
    if (_stationarySeconds >= _stationaryThresholdSec &&
        _vehicleState != VehicleActivityState.stationary) {
      debugPrint(
          '[SmartBattery] Vehicle stationary >=${_stationaryThresholdSec}s → switching to general');
      _setVehicleState(VehicleActivityState.stationary);
    }
  }

  void _setVehicleState(VehicleActivityState newState) {
    if (_vehicleState == newState) return;
    _vehicleState = newState;
    debugPrint('[SmartBattery] vehicleState → $newState');
    _applyBestProfile();
  }

  /// Quyết định và áp dụng profile tốt nhất dựa trên trạng thái hiện tại.
  ///
  /// **Thứ tự ưu tiên:**
  /// 1. Pin thấp (< 15%) + không sạc → `batterySaver` (bất kể trạng thái khác)
  /// 2. Xe đứng yên → `general`
  /// 3. Xe đang cua (cornering) → `navigation` (luôn cần chính xác cao)
  /// 4. Đường thẳng / mặc định → `preferredMovingProfile`
  Future<void> _applyBestProfile() async {
    if (!_enabled) return;

    SmartBatteryProfile newProfile;

    // Ưu tiên 1: Pin thấp + không sạc
    if (_lastBatteryLevel <= _kLowBatteryThreshold && !_isCharging) {
      newProfile = SmartBatteryProfile.batterySaver;
    }
    // Ưu tiên 2: Xe đứng yên
    else if (_vehicleState == VehicleActivityState.stationary) {
      newProfile = SmartBatteryProfile.general;
    }
    // Ưu tiên 3: Đang vào góc cua → navigation để chấm dày điểm GPS
    else if (_motionDetail == _MotionDetail.cornering) {
      newProfile = SmartBatteryProfile.navigation;
    }
    // Mặc định: profile người dùng chọn (navigation hoặc general)
    else {
      newProfile = preferredMovingProfile;
    }

    if (newProfile == _currentProfile) return;
    _currentProfile = newProfile;

    debugPrint('[SmartBattery] Apply profile=$newProfile '
        '(battery=$_lastBatteryLevel% charging=$_isCharging '
        'vehicleState=$_vehicleState)');

    // Thông báo cho app
    if (!_profileController.isClosed) {
      _profileController.add(newProfile);
    }

    // Khi có custom override (user đang dùng custom config) → app tự apply config
    // cho MỌI profile transition, không để SmartBattery ghi đè customIntervalMs
    // bằng native preset (navigation=5s, batterySaver=300s, general=30s).
    if (customGeneralConfigOverride != null) {
      debugPrint('[SmartBattery] customOverride set → delegate to app for $newProfile (skip native preset)');
      await customGeneralConfigOverride!();
      return;
    }

    // Gọi native để áp dụng cấu hình tracking
    await _applyNativeConfig(newProfile);
  }

  Future<void> _applyNativeConfig(SmartBatteryProfile profile) async {
    try {
      final presetName = switch (profile) {
        SmartBatteryProfile.navigation => 'navigation',
        SmartBatteryProfile.general => 'general',
        SmartBatteryProfile.batterySaver => 'batterySaver',
      };

      // Gọi DUY NHẤT setSmartBatteryConfig — native handler sẽ tự apply
      // TrackingConfig phù hợp (interval, distanceFilter, backgroundMode).
      //
      // KHÔNG gọi thêm updateTrackingConfig() — gọi 2 lần setTrackingConfig()
      // liên tiếp khiến SDK restart Foreground Service 2 lần, lần thứ 2 sẽ
      // miss window 5s → ForegroundServiceDidNotStartInTimeException.
      await _platform.setSmartBatteryConfig(
        enabled: true,
        preset: presetName,
      );

      debugPrint('[SmartBattery] Native config applied: $presetName');
    } catch (e) {
      debugPrint('[SmartBattery] applyNativeConfig error: $e');
    }
  }
}
