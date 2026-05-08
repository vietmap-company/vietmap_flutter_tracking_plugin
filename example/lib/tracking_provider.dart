import 'dart:async';
import 'dart:io';
import 'dart:math' show sqrt, asin;

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:device_info_plus/device_info_plus.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:vietmap_tracking_plugin/vietmap_tracking_plugin.dart';

const _kPrefEmail = 'user_email';

// Set to `true` to make the tracking SDK send the API key via query parameter
// instead of the default request header.
bool useQueryParamAuth = false;

class TrackingProvider extends ChangeNotifier {
  final _controller = VietmapTrackingController.instance;

  void _logSection(String section, {bool end = false}) {
    debugPrint('=======${end ? 'End ' : ''}$section=======');
  }

  // ── Identity ────────────────────────────────────────────────────
  String deviceId = '047000f7a187494e';
  String userEmail = '';

  // ── Tracking state ───────────────────────────────────────────────
  bool isTracking = false;
  /// True while startTracking() native call is in-flight.
  /// UI reacts immediately (button disables / shows spinner) before native returns.
  bool isStartingTracking = false;
  /// True while stopTracking() native call is in-flight.
  /// Used to disable Stop button and show deterministic loading feedback.
  bool isStoppingTracking = false;
  bool hasPermissions = false;
  bool isSpeedAlertEnabled = false;
  bool _trackingWithTimer = false;
  get trackingWithTimer => _trackingWithTimer;
  bool _trackingWithDistance = false;
  get trackingWithDistance => _trackingWithDistance;


  LocationData? currentLocation;
  TrackingStatus? trackingStatus;
  final List<LocationData> locationHistory = [];

  // Session stats
  DateTime? sessionStartTime;
  double totalDistance = 0.0;
  double averageSpeed = 0.0;

  // ── Config ───────────────────────────────────────────────────────
  bool useCustomConfig = false;
  int customIntervalMs = 5000;
  double customDistanceFilter = 10.0;
  bool customBackgroundMode = false;

  // ── Smart Battery ────────────────────────────────────────────────
  SmartBatteryProfile smartBatteryProfile = SmartBatteryProfile.general;
  String smartBatteryPreferredPreset = 'general';

  // ── Cache stats ──────────────────────────────────────────────────
  int cachedLocationsCount = 0;
  int dbSizeBytes = 0;
  bool cacheConfigExpanded = false;
  int maxRecords = 5000;
  int maxDbSizeMb = 50;
  int batchSize = 50;

  // ── SLC ──────────────────────────────────────────────────────────
  bool slcEnabled = false;
  List<String> slcLogs = [];
  bool isSLCAwakeFromKill = false;

  // ── Fake GPS ──────────────────────────────────────────────────────
  String fakeGpsPolicy = FakeGpsPolicy.skip;
  bool allowMockLocation = true;
  FakeGpsEvent? lastFakeGpsEvent;
  final List<FakeGpsEvent> fakeGpsHistory = [];
  StreamSubscription<FakeGpsEvent>? _fakeGpsSub;

  // ── Initialization ────────────────────────────────────────────────
  bool _initialized = false;
  String? initError;
  bool isSdkConfigured = false;
  String _apiKey = '';

  // ── Internal subscriptions ────────────────────────────────────────
  StreamSubscription<LocationData>? _locationSub;
  StreamSubscription<TrackingStatus>? _statusSub;
  StreamSubscription<SmartBatteryProfile>? _batterySub;

  // ── Server History ────────────────────────────────────────────────
  List<GpsLocation> serverHistory = [];
  bool isFetchingHistory = false;
  bool isFetchingMoreHistory = false;
  bool hasMoreHistory = true;
  String? historyFetchError;
  int _historyPage = 1;
  static const int _historyPageSize = 50;

  // ── Cache auto-refresh: throttle to once per 2s ───────────────────
  DateTime? _lastCacheRefresh;

  // ── Local Notifications ───────────────────────────────────────────
  final _notifications = FlutterLocalNotificationsPlugin();
  bool _notificationsReady = false;

  // ─────────────────────────────────────────────────────────────────
  // Init
  // ─────────────────────────────────────────────────────────────────

  Future<void> init() async {
    if (_initialized) return;
    _initialized = true;

    _logSection('Provider Init');

    await _loadSavedEmail();
    await _resolveDeviceId();
    await _checkPermissions();
    await _checkTrackingStatus();
    _subscribeStreams();

    _logSection('Provider Init', end: true);
  }

  Future<void> _loadSavedEmail() async {
    final prefs = await SharedPreferences.getInstance();
    userEmail = prefs.getString(_kPrefEmail) ?? '';
    notifyListeners();
  }

  Future<void> saveEmail(String email) async {
    userEmail = email.trim();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_kPrefEmail, userEmail);
    if (isSdkConfigured) {
      await _controller.setMetadata({
        'userName': userEmail.isNotEmpty ? userEmail : 'anonymous',
        'appVersion': '1.0.0',
        'device-id': deviceId,
      });
    }
    notifyListeners();
  }

  Future<void> _resolveDeviceId() async {
    try {
      final info = DeviceInfoPlugin();
      if (Platform.isIOS) {
        final ios = await info.iosInfo;
        deviceId = ios.identifierForVendor ?? deviceId;
      } else if (Platform.isAndroid) {
        final android = await info.androidInfo;
        deviceId = android.id;
      }
    } catch (_) {}
  }

  /// Initialize and configure the SDK explicitly.
  ///
  /// Calls the following SDK methods in sequence:
  ///   1. `initializeTracking(apiKey, baseURL)` — validates the API key
  ///      server-side. Throws `PlatformException(code: 'INVALID_API_KEY')`
  ///      if the key is rejected.
  ///   2. `setMetadata({...})` — attaches user context to every GPS record
  ///      uploaded (optional but recommended).
  ///   3. `configureAlertAPI(key, id)` — configures speed alert API
  ///      credentials (only called when both are provided).
  Future<void> configureSdk(
    String apiKey, {
    String? baseURL,
    String? alertApiKey,
    String? alertApiId,
  }) async {
    _logSection('Configure SDK');
    try {
      debugPrint('Provider: initializeTracking + setMetadata + configureAlertAPI');

      // 1. Validate API key against server and initialize SDK.
      //    Throws PlatformException(code: 'INVALID_API_KEY') if rejected.
      await _controller.initializeTracking(
        apiKey,
        baseURL: baseURL,
      );

      // 2. Attach metadata to every GPS record uploaded (optional).
      await _controller.setMetadata({
        'userName': userEmail.isNotEmpty ? userEmail : 'anonymous',
        'appVersion': '1.0.0',
        'device-id': deviceId,
      });

      // 3. Configure speed-alert API (optional — only when credentials provided).
      if (alertApiKey != null && alertApiKey.isNotEmpty &&
          alertApiId != null && alertApiId.isNotEmpty) {
        await _controller.configureAlertAPI(alertApiKey, alertApiId);
      }

      _apiKey = apiKey;
      isSdkConfigured = true;
      initError = null;
      _controller.registerLifecycleObserver();
      notifyListeners();
    } on PlatformException catch (e) {
      if (e.code == 'INVALID_API_KEY') {
        initError = 'API key không hợp lệ: ${e.message}';
      } else {
        initError = e.toString();
      }
      isSdkConfigured = false;
      notifyListeners();
      debugPrint('Failed to configure SDK: $initError');
    } catch (e) {
      initError = e.toString();
      isSdkConfigured = false;
      notifyListeners();
      debugPrint('Failed to configure SDK: $e');
    } finally {
      _logSection('Configure SDK', end: true);
    }
  }

  // ─────────────────────────────────────────────────────────────────
  // Streams
  // ─────────────────────────────────────────────────────────────────

  void _subscribeStreams() {
    _locationSub = _controller.onLocationUpdate.listen(_onLocation);
    _statusSub = _controller.onTrackingStatusChanged.listen(_onStatus);
    _fakeGpsSub = _controller.onFakeGpsDetected.listen(_onFakeGps);
  }

  /// Call once from main() before runApp.
  Future<void> initNotifications() async {
    if (_notificationsReady) return;
    const android = AndroidInitializationSettings('@mipmap/ic_launcher');
    // defaultPresentAlert/Sound MUST be true so iOS shows banners when app is
    // in the foreground. Per-notification presentAlert only overrides the default
    // but the default must be enabled for the delegate to fire at all.
    const ios = DarwinInitializationSettings(
      requestAlertPermission: false, // permission handled by permission_handler
      requestBadgePermission: false,
      requestSoundPermission: false,
      defaultPresentAlert: true,
      defaultPresentSound: true,
      defaultPresentBadge: false,
    );
    await _notifications.initialize(
      const InitializationSettings(android: android, iOS: ios),
    );
    _notificationsReady = true;
  }

  Future<void> _showFakeGpsNotification(FakeGpsEvent event) async {
    if (!_notificationsReady) return;
    final body = 'lat=${event.lat.toStringAsFixed(5)} '
        'lng=${event.lng.toStringAsFixed(5)}'
        '${event.reason != null ? ' · ${event.reason}' : ''}';
    await _notifications.show(
      999, // fixed ID — overwrites previous, no stacking
      '⚠️ Fake GPS Detected',
      body,
      const NotificationDetails(
        android: AndroidNotificationDetails(
          'fake_gps_channel',
          'Fake GPS Alerts',
          channelDescription: 'Alert when a fake GPS location is detected',
          importance: Importance.high,
          priority: Priority.high,
          icon: '@mipmap/ic_launcher',
        ),
        iOS: DarwinNotificationDetails(
          presentAlert: true,
          presentSound: true,
          presentBadge: false,
        ),
      ),
    );
  }

  void _onFakeGps(FakeGpsEvent event) {
    lastFakeGpsEvent = event;
    fakeGpsHistory.insert(0, event);
    if (fakeGpsHistory.length > 20) fakeGpsHistory.removeLast();

    // SDK already stops tracking natively for policy=stopTracking.
    // Sync UI state immediately so buttons react without waiting for status stream timing.
    if (fakeGpsPolicy == FakeGpsPolicy.stopTracking) {
      _syncStopState();
    }

    notifyListeners();

    // Show local notification when policy is warn
    if (fakeGpsPolicy == FakeGpsPolicy.warn) {
      _showFakeGpsNotification(event);
    }
  }

  void _onLocation(LocationData loc) {
    _controller.feedLocationToSmartBattery(loc.speed, heading: loc.heading);

    if (currentLocation != null && sessionStartTime != null) {
      final d = _haversine(
        currentLocation!.latitude, currentLocation!.longitude,
        loc.latitude, loc.longitude,
      );
      totalDistance += d;
      final elapsed = DateTime.now().difference(sessionStartTime!).inSeconds;
      if (elapsed > 0) averageSpeed = totalDistance / elapsed;
    }

    currentLocation = loc;
    locationHistory.add(loc);
    if (locationHistory.length > 50) locationHistory.removeAt(0);

    // Auto-refresh cache stats at most once every 2 seconds
    final now = DateTime.now();
    if (_lastCacheRefresh == null ||
        now.difference(_lastCacheRefresh!) >= const Duration(seconds: 2)) {
      _lastCacheRefresh = now;
      _refreshCacheStatsQuietly();
    }

    notifyListeners();
  }

  void _onStatus(TrackingStatus status) {
    debugPrint('🔄 TRACKING STATUS: isTracking=${status.isTracking}');
    trackingStatus = status;
    isTracking = status.isTracking;
    if (!status.isTracking) {
      isStoppingTracking = false;
    }
    notifyListeners();
  }

  // ─────────────────────────────────────────────────────────────────
  // Permission
  // ─────────────────────────────────────────────────────────────────

  Future<void> _checkPermissions() async {
    try {
      final r = await _controller.hasLocationPermissions();
      hasPermissions = r.granted;
      notifyListeners();
    } catch (_) {}
  }

  Future<PermissionResult> requestPermissions() async {
    final r = await _controller.requestLocationPermissions();
    hasPermissions = r.granted;
    notifyListeners();
    return r;
  }

  // ─────────────────────────────────────────────────────────────────
  // Tracking status
  // ─────────────────────────────────────────────────────────────────

  Future<void> _checkTrackingStatus() async {
    try {
      final s = await _controller.getTrackingStatus();
      trackingStatus = s;
      isTracking = s.isTracking;
      notifyListeners();
    } catch (_) {
      isTracking = false;
      notifyListeners();
    }
  }

  Future<void> refreshStatus() async {
    await _checkTrackingStatus();
    await refreshCacheStats();
  }

  // ─────────────────────────────────────────────────────────────────
  // Config helpers
  // ─────────────────────────────────────────────────────────────────

  String get effectiveUserId =>
      userEmail.isNotEmpty ? userEmail : 'anonymous_${deviceId.substring(0, 8)}';

  void toggleTrackingWithTimer(bool v) {
    _trackingWithTimer = v;
    if (v) _trackingWithDistance = false;
    notifyListeners();
  }

  void toggleTrackingWithDistance(bool v) {
    _trackingWithDistance = v;
    if (v) _trackingWithTimer = false;
    notifyListeners();
  }

  LocationTrackingConfig get activeConfig {
    if (useCustomConfig) {
      // Timer mode  → chỉ dùng interval, null distance filter
      // Distance mode → chỉ dùng distanceFilter, null interval
      // Cả hai OFF   → dùng null cho cả hai (SDK defaults)
      final int? resolvedInterval = _trackingWithDistance ? null : (_trackingWithTimer ? customIntervalMs : null);
      final double? resolvedDistance = _trackingWithTimer ? null : (_trackingWithDistance ? customDistanceFilter : null);

      return LocationTrackingConfig(
        intervalMs: resolvedInterval,
        distanceFilter: resolvedDistance,
        accuracy: LocationAccuracy.high,
        backgroundMode: customBackgroundMode,
        notificationTitle: 'GPS Tracking',
        notificationMessage: 'Your location is being tracked',
        userId: effectiveUserId,
        allowMockLocation: allowMockLocation,
      );
    }
    // Default mode: use general preset (10s / 15m, balanced battery/accuracy)
    return TrackingPresets.general().copyWith(
      userId: effectiveUserId,
      allowMockLocation: allowMockLocation,
    );
  }

  // ─────────────────────────────────────────────────────────────────
  // Tracking actions
  // ─────────────────────────────────────────────────────────────────

  /// Sync local UI state when tracking has already stopped natively.
  /// This method only updates local state and does not call platform stop APIs.
  void _syncStopState() {
    SmartBatteryManager.instance.customGeneralConfigOverride = null;
    _batterySub?.cancel();
    _batterySub = null;
    isTracking = false;
    trackingStatus = null;
    sessionStartTime = null;
    isStartingTracking = false;
    isStoppingTracking = false;
  }

  Future<bool> startTracking() async {
    if (isStartingTracking || isStoppingTracking) return false;

    _logSection('Start Tracking SDK');

    // Nếu dùng custom config → set override để SmartBattery không ghi đè
    // preset 'general' lên custom config của user
    if (useCustomConfig) {
      SmartBatteryManager.instance.customGeneralConfigOverride = () async {
        debugPrint('🔋 [Provider] customOverride → apply activeConfig (${activeConfig.intervalMs}ms / ${activeConfig.distanceFilter}m)');
        await _controller.updateTrackingConfig(activeConfig);
      };
    } else {
      SmartBatteryManager.instance.customGeneralConfigOverride = null;
    }

    // Notify immediately so the button disables / shows spinner before native returns
    isStartingTracking = true;
    notifyListeners();

    try {
      final result = await _controller.startTracking(activeConfig);
      if (result) {
        final isActive = await _controller.isTrackingActive();
        if (!isActive) {
          _syncStopState();
          return false;
        }

        isTracking = true;
        isStoppingTracking = false;
        sessionStartTime = DateTime.now();
        totalDistance = 0.0;
        averageSpeed = 0.0;

        _batterySub?.cancel();
        _batterySub = _controller.onSmartBatteryProfileChanged.listen((profile) {
          smartBatteryProfile = profile;
          notifyListeners();
        });
        smartBatteryProfile = SmartBatteryManager.instance.currentProfile;
      }
      return result;
    } finally {
      isStartingTracking = false;
      notifyListeners();
      _logSection('Start Tracking SDK', end: true);
    }
  }

  Future<bool> stopTracking() async {
    if (isStoppingTracking || isStartingTracking) return false;

    _logSection('Stop Tracking SDK');

    isStoppingTracking = true;
    notifyListeners();

    try {
      final result = await _controller.stopTracking();
      if (result) {
        _syncStopState();
      }
      return result;
    } finally {
      isStoppingTracking = false;
      notifyListeners();
      _logSection('Stop Tracking SDK', end: true);
    }
  }

  Future<bool> updateConfig() async {
    _logSection('Update Tracking Config');
    return _controller.updateTrackingConfig(activeConfig);
  }

  Future<LocationData> getCurrentLocation() async {
    final loc = await _controller.getCurrentLocation();
    currentLocation = loc;
    notifyListeners();
    return loc;
  }

  void clearHistory() {
    locationHistory.clear();
    totalDistance = 0.0;
    averageSpeed = 0.0;
    if (!isTracking) sessionStartTime = null;
    notifyListeners();
  }

  /// Reset and fetch page 1 (dùng cho auto-refresh 20s hoặc fetch lần đầu).
  Future<void> fetchServerHistory() async {
    if (!isSdkConfigured) return;
    if (isFetchingHistory) return;
    _historyPage = 1;
    isFetchingHistory = true;
    historyFetchError = null;
    hasMoreHistory = true;
    notifyListeners();
    try {
      final results = await _controller.getTrackingHistory(
        userId: effectiveUserId,
        pageNumber: 1,
        pageSize: _historyPageSize,
        sortDescending: true,
      );
      serverHistory = results;
      hasMoreHistory = results.length >= _historyPageSize;
    } catch (e) {
      historyFetchError = e.toString();
    } finally {
      isFetchingHistory = false;
      notifyListeners();
    }
  }

  /// Append next page (gọi khi scroll tới cuối list).
  Future<void> fetchMoreServerHistory() async {
    if (!isSdkConfigured) return;
    if (isFetchingMoreHistory || isFetchingHistory || !hasMoreHistory) return;
    isFetchingMoreHistory = true;
    notifyListeners();
    try {
      _historyPage++;
      final results = await _controller.getTrackingHistory(
        userId: effectiveUserId,
        pageNumber: _historyPage,
        pageSize: _historyPageSize,
        sortDescending: true,
      );
      serverHistory = [...serverHistory, ...results];
      hasMoreHistory = results.length >= _historyPageSize;
    } catch (e) {
      historyFetchError = e.toString();
      _historyPage--; // rollback so retry is possible
    } finally {
      isFetchingMoreHistory = false;
      notifyListeners();
    }
  }

  // ─────────────────────────────────────────────────────────────────
  // Speed Alert
  // ─────────────────────────────────────────────────────────────────

  Future<void> toggleSpeedAlert(bool enabled) async {
    if (enabled) {
      isSpeedAlertEnabled = await _controller.turnOnAlert();
    } else {
      final off = await _controller.turnOffAlert();
      isSpeedAlertEnabled = !off;
    }
    notifyListeners();
  }

  // ─────────────────────────────────────────────────────────────────
  // Cache stats — auto-updated on location write
  // ─────────────────────────────────────────────────────────────────

  Future<void> _refreshCacheStatsQuietly() async {
    try {
      final count = await _controller.getCachedLocationsCount();
      final size = await _controller.getDatabaseSizeBytes();
      cachedLocationsCount = count;
      dbSizeBytes = size;
      notifyListeners();
    } catch (_) {}
  }

  Future<void> refreshCacheStats() async {
    await _refreshCacheStatsQuietly();
  }

  Future<bool> applyConfigureCacheLimits() async {
    return _controller.configureCacheLimits(
      maxRecords: maxRecords,
      maxDbSizeBytes: maxDbSizeMb * 1024 * 1024,
      batchSize: batchSize,
    );
  }

  Future<bool> manualUploadCache() async {
    final ok = await _controller.uploadCachedLocationsManually();
    await _refreshCacheStatsQuietly();
    return ok;
  }

  Future<bool> clearCache() async {
    final ok = await _controller.clearCachedLocations();
    await _refreshCacheStatsQuietly();
    return ok;
  }

  // ─────────────────────────────────────────────────────────────────
  // Smart Battery
  // ─────────────────────────────────────────────────────────────────

  void setPreferredBatteryPreset(String preset) {
    smartBatteryPreferredPreset = preset;
    final profile = preset == 'navigation'
        ? SmartBatteryProfile.navigation
        : SmartBatteryProfile.general;
    _controller.setSmartBatteryPreferredProfile(profile);
    notifyListeners();
  }

  // ─────────────────────────────────────────────────────────────────
  // Config setters (notify after change)
  // ─────────────────────────────────────────────────────────────────

  void setUseCustomConfig(bool v) {
    useCustomConfig = v;
    // Cập nhật override cho SmartBattery khi toggle trong lúc tracking
    if (isTracking) {
      if (v) {
        SmartBatteryManager.instance.customGeneralConfigOverride = () async {
          debugPrint('🔋 [Provider] customOverride → apply activeConfig (${activeConfig.intervalMs}ms / ${activeConfig.distanceFilter}m)');
          await _controller.updateTrackingConfig(activeConfig);
        };
      } else {
        SmartBatteryManager.instance.customGeneralConfigOverride = null;
      }
    }
    notifyListeners();
  }
  void setCustomIntervalMs(int v) { customIntervalMs = v; notifyListeners(); }
  void setCustomDistanceFilter(double v) { customDistanceFilter = v; notifyListeners(); }
  void setCustomBackgroundMode(bool v) { customBackgroundMode = v; notifyListeners(); }
  void setCacheConfigExpanded(bool v) { cacheConfigExpanded = v; notifyListeners(); }
  void setMaxRecords(int v) { maxRecords = v; }
  void setMaxDbSizeMb(int v) { maxDbSizeMb = v; }
  void setBatchSize(int v) { batchSize = v; }

  // ─────────────────────────────────────────────────────────────────
  // Fake GPS
  // ─────────────────────────────────────────────────────────────────

  Future<void> setFakeGpsPolicy(String policy) async {
    fakeGpsPolicy = policy;
    await _controller.setFakeGpsPolicy(policy);
    notifyListeners();
  }

  void setAllowMockLocation(bool v) {
    allowMockLocation = v;
    notifyListeners();
  }

  /// Returns true if notification permission is already granted.
  /// Uses flutter_local_notifications on iOS (same UNUserNotificationCenter
  /// delegate that FLN registered), permission_handler on Android.
  Future<bool> hasNotificationPermission() async {
    if (Platform.isIOS) {
      final ios = _notifications
          .resolvePlatformSpecificImplementation<
              IOSFlutterLocalNotificationsPlugin>();
      final result = await ios?.checkPermissions();
      return result?.isEnabled ?? false;
    }
    final status = await Permission.notification.status;
    return status.isGranted;
  }

  /// Requests notification permission.
  /// iOS: uses flutter_local_notifications so it shares the same
  ///      UNUserNotificationCenter delegate — guaranteed to show the OS popup.
  /// Android API 33+: uses permission_handler runtime dialog.
  Future<bool> requestNotificationPermission() async {
    if (Platform.isIOS) {
      final ios = _notifications
          .resolvePlatformSpecificImplementation<
              IOSFlutterLocalNotificationsPlugin>();
      final granted = await ios?.requestPermissions(
            alert: true,
            sound: true,
            badge: false,
          ) ??
          false;
      notifyListeners();
      return granted;
    }
    // Android
    final status = await Permission.notification.request();
    notifyListeners();
    return status.isGranted;
  }

  void clearFakeGpsHistory() {
    fakeGpsHistory.clear();
    lastFakeGpsEvent = null;
    notifyListeners();
  }

  /*
  // ─────────────────────────────────────────────────────────────────
  // SLC
  // ─────────────────────────────────────────────────────────────────

  void addSLCLog(String message) {
    slcLogs.insert(0, '[${DateTime.now().toIso8601String()}] $message');
    if (slcLogs.length > 50) slcLogs = slcLogs.sublist(0, 50);
    slcEnabled = true;
    notifyListeners();
  }

  Future<void> checkSLCWakeUp(MethodChannel ch) async {
    try {
      final waked = await ch.invokeMethod<bool>('wasWakedBySLC') ?? false;
      isSLCAwakeFromKill = waked;
      if (waked) addSLCLog('🟢 App was woken up by iOS (SLC after force-kill)');
      notifyListeners();
    } catch (_) {}
  }

  void listenSLCEvents(MethodChannel ch) {
    ch.setMethodCallHandler((call) async {
      if (call.method == 'onSLCEvent') {
        final msg = (call.arguments as Map)['message'] as String? ?? '';
        addSLCLog(msg);
      }
      return null;
    });
  }

  Future<void> startSLC(MethodChannel ch) async {
    if (!Platform.isIOS) {
      addSLCLog('⚠️ SLC is only supported on iOS');
      return;
    }
    try {
      _logSection('Start SLC');
      addSLCLog('📡 Starting SLC with deviceId: $deviceId...');
      await ch.invokeMethod('startSLC', {
        'apiKey': _apiKey,
        'deviceId': deviceId,
        'vehicleId': 'vehicle_001',
        'userId': effectiveUserId,
        'apiEndpoint': 'https://staging.fleetwork.vn/api/v1/gps-tracking/history',
        'distanceFilter': 500.0,
      });
      slcEnabled = true;
      addSLCLog('✅ SLC started successfully');
    } catch (e) {
      addSLCLog('❌ Failed to start SLC: $e');
    } finally {
      _logSection('Start SLC', end: true);
    }
  }

  Future<void> stopSLC(MethodChannel ch) async {
    try {
      _logSection('Stop SLC');
      addSLCLog('⏹️ Stopping SLC...');
      await ch.invokeMethod('stopSLC');
      slcEnabled = false;
      addSLCLog('✅ SLC stopped');
      notifyListeners();
    } catch (e) {
      addSLCLog('❌ Failed to stop SLC: $e');
    } finally {
      _logSection('Stop SLC', end: true);
    }
  }

  Future<void> refreshSLCLogs(MethodChannel ch) async {
    try {
      _logSection('Refresh SLC Logs');
      final logs = await ch.invokeMethod<List>('getSLCLogs') ?? [];
      slcLogs = logs.cast<String>().toList();
      notifyListeners();
    } catch (e) {
      addSLCLog('❌ Failed to refresh logs: $e');
    } finally {
      _logSection('Refresh SLC Logs', end: true);
    }
  }
  */

  // ─────────────────────────────────────────────────────────────────
  // Haversine (no dart:math dependency — approximate via Taylor)
  // ─────────────────────────────────────────────────────────────────

  double _haversine(double lat1, double lon1, double lat2, double lon2) {
    const r = 6371000.0;
    final dLat = _rad(lat2 - lat1);
    final dLon = _rad(lon2 - lon1);
    final a = (_sin(dLat / 2) * _sin(dLat / 2)) +
        (_cos(_rad(lat1)) * _cos(_rad(lat2)) * _sin(dLon / 2) * _sin(dLon / 2));
    return r * 2 * asin(sqrt(a));
  }

  double _rad(double d) => d * 3.14159265359 / 180.0;
  double _sin(double x) => x - (x * x * x) / 6 + (x * x * x * x * x) / 120;
  double _cos(double x) => 1 - (x * x) / 2 + (x * x * x * x) / 24;

  // ─────────────────────────────────────────────────────────────────

  @override
  void dispose() {
    _locationSub?.cancel();
    _statusSub?.cancel();
    _batterySub?.cancel();
    _fakeGpsSub?.cancel();
    if (_controller.isConfigured) {
      _controller.unregisterLifecycleObserver();
    }
    SmartBatteryManager.instance.dispose();
    super.dispose();
  }
}
