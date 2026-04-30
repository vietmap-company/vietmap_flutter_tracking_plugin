import Flutter
import UIKit
import CoreLocation
import VietmapTrackingSDK

public class VietmapTrackingPlugin: NSObject, FlutterPlugin {

    // MARK: - Properties
    private var isInitialized: Bool = false
    private var apiKey: String?
    private var baseURL: String?
    
    // Device metadata (from startTracking config)
    private var deviceId: String?
    private var userId: String?
    private var vehicleId: String?

    // MARK: - Sync Logger
    private var syncWatchdogTimer: Timer?
    private var lastSdkNetworkStatus: Bool?
    private var manualSyncInProgress: Bool = false
    private let nativeLogTag = "🍎 [iOSNative]"
    private var gpsPointCounter: Int = 0

    // MARK: - Smart Battery Optimization
    // Khi bật: iOS CoreLocation dùng .automotiveNavigation activity type →
    // OS tự điều chỉnh tần suất GPS theo tốc độ/góc cua; tự tạm dừng GPS khi xe đỗ
    private var smartBatteryEnabled: Bool = false

    // MARK: - VietmapTrackingSDK Integration
    private let trackingManager = VietmapTrackingManager.shared

    // MethodChannel reference — stored to enable native→Dart invokeMethod calls
    // (e.g. onFakeGPSDetected). Set once in register(with:) before setupSDKCallbacks().
    // Strong reference: FlutterMethodChannel must remain alive for the plugin lifetime.
    private var channel: FlutterMethodChannel?

    private let locationStreamHandler = LocationStreamHandler()
    private let trackingStatusStreamHandler = TrackingStatusStreamHandler()
    private let speedSignStreamHandler = SimpleStreamHandler()
    private let ttsStreamHandler = SimpleStreamHandler()

    // MARK: - Plugin Registration
    public static func register(with registrar: FlutterPluginRegistrar) {
        let channel = FlutterMethodChannel(
            name: "vietmap_tracking_plugin",
            binaryMessenger: registrar.messenger()
        )

        let locationUpdateChannel = FlutterEventChannel(
            name: "vietmap_tracking_plugin/location_updates",
            binaryMessenger: registrar.messenger()
        )

        let trackingStatusChannel = FlutterEventChannel(
            name: "vietmap_tracking_plugin/tracking_status",
            binaryMessenger: registrar.messenger()
        )

        let speedSignChannel = FlutterEventChannel(
            name: "vietmap_tracking_plugin/speed_sign",
            binaryMessenger: registrar.messenger()
        )

        let ttsChannel = FlutterEventChannel(
            name: "vietmap_tracking_plugin/tts",
            binaryMessenger: registrar.messenger()
        )

        let instance = VietmapTrackingPlugin()
        instance.nativeLog("=======Register Plugin=======")
        registrar.addMethodCallDelegate(instance, channel: channel)
        // Store channel reference BEFORE setupSDKCallbacks() so the closure
        // can safely call invokeMethod. Must be strong to survive for plugin lifetime.
        instance.channel = channel
        locationUpdateChannel.setStreamHandler(instance.locationStreamHandler)
        trackingStatusChannel.setStreamHandler(instance.trackingStatusStreamHandler)
        speedSignChannel.setStreamHandler(instance.speedSignStreamHandler)
        ttsChannel.setStreamHandler(instance.ttsStreamHandler)

        instance.setupSDKCallbacks()
        instance.setupLifecycleObservers()
        instance.nativeLog("=======End Register Plugin=======")
    }

    // MARK: - SDK Callbacks Setup
    private func setupSDKCallbacks() {
        nativeLog("=======Setup SDK Callbacks=======")
        nativeLog("🔌 setupSDKCallbacks attached")

        // SDK tự quản lý toàn bộ pipeline:
        //   GPS captured → lưu SQLite (SENDING) → POST online / reset PENDING offline
        //   Timer 30s: quét PENDING → bulk upload
        // Plugin chỉ forward event lên Flutter và log diagnostics — KHÔNG tự POST.

        trackingManager.onLocationUpdate = { [weak self] locationDict in
            guard let self = self else { return }
            guard let dict = locationDict as? [String: Any] else { return }

            self.gpsPointCounter += 1
            let counter = self.gpsPointCounter
            let cached  = self.trackingManager.getCachedLocationsCount()
            let isOnline = self.trackingManager.isNetworkConnected()
            let dbSize  = self.trackingManager.getDatabaseSizeBytes()

            // Log data payload sent to server
            let lat = dict["lat"] ?? dict["latitude"] ?? "?"
            let lng = dict["lng"] ?? dict["longitude"] ?? "?"
            let speed = dict["speed"] ?? "?"
            let heading = dict["heading"] ?? dict["bearing"] ?? "?"
            let accuracy = dict["accuracy"] ?? "?"
            let ts = dict["timestamp"] ?? "?"
            let devId = dict["deviceId"] ?? self.deviceId ?? "?"
            let uid = dict["userId"] ?? dict["driverId"] ?? self.userId ?? "?"
            let vid = dict["vehicleId"] ?? self.vehicleId ?? "?"

            // Always log first 3 points for debugging sync pipeline
            let shouldLog = !isOnline || counter <= 3 || counter % 5 == 0

            if !isOnline {
                self.nativeLog("[#\(counter)] 💾 OFFLINE → SDK queued in DB | pending=\(cached) | dbSize=\(dbSize)B")
            } else if counter <= 3 {
                self.nativeLog("[#\(counter)] 🆕 SDK uploading (initial) | pending=\(cached) | dbSize=\(dbSize)B")
            } else if counter % 5 == 0 {
                self.nativeLog("[#\(counter)] ✅ SDK uploading | pending=\(cached) | dbSize=\(dbSize)B")
            }

            if shouldLog {
                self.nativeLog("[#\(counter)] 📍 Data: lat=\(lat) lng=\(lng) speed=\(speed) heading=\(heading) accuracy=\(accuracy) ts=\(ts)")
                self.nativeLog("[#\(counter)] 🆔 IDs: deviceId=\(devId) userId=\(uid) vehicleId=\(vid)")
            }

            // Forward to Flutter EventChannel
            self.locationStreamHandler.send(event: dict)
        }

        trackingManager.onTrackingStatusChanged = { [weak self] statusDict in
            guard let self = self else { return }
            if let dict = statusDict as? [String: Any] {
                self.trackingStatusStreamHandler.send(event: dict)
            }
        }

        trackingManager.onError = { [weak self] errorMessage in
            guard let self = self else { return }
            self.nativeLog("❌ SDK Error: \(errorMessage)")
            self.locationStreamHandler.send(event: [
                "error": errorMessage,
                "timestamp": Int(Date().timeIntervalSince1970 * 1000)
            ])
        }

        trackingManager.onPermissionChanged = { [weak self] status in
            guard let self = self else { return }
            self.trackingStatusStreamHandler.send(event: [
                "permissionStatus": status,
                "timestamp": Int(Date().timeIntervalSince1970 * 1000)
            ])
        }

        trackingManager.onRouteUpdate = { [weak self] success, routeData in
            guard let self = self else { return }
            var event: [String: Any] = [
                "success": success,
                "timestamp": Int(Date().timeIntervalSince1970 * 1000)
            ]
            if let routeDict = routeData as? [String: Any] {
                event["route"] = routeDict
            }
            self.trackingStatusStreamHandler.send(event: event)
        }

        // Fake GPS detection — native debounces at 30s, iOS 15+ only
        // Payload keys: isFake, isFirstDetection, reason, lat, lng, timestamp
        // SDK is pure Swift — KHÔNG import Flutter. Plugin layer là nơi duy nhất
        // được phép gọi invokeMethod.
        trackingManager.onFakeGPSDetected = { [weak self] payload in
            guard let self = self else { return }
            guard let dict = payload as? [String: Any] else { return }
            self.nativeLog("⚠️ FakeGPS detected: \(dict)")
            // MUST dispatch to main thread — FlutterMethodChannel is not thread-safe
            DispatchQueue.main.async {
                self.channel?.invokeMethod("onFakeGPSDetected", arguments: dict)
            }
        }

        // Speed-sign + TTS callbacks are SDK-version dependent.
        // Current SDK build in this workspace does not expose
        // `onSpeedSignUpdate` / `onTtsAlert` on VietmapAlertBridge,
        // so keep channels alive but skip binding to avoid compile errors.
        nativeLog("ℹ️ VietmapAlertBridge callbacks are unavailable in current SDK build")

        nativeLog("=======End Setup SDK Callbacks=======")
    }

    // MARK: - Cleanup
    deinit {
        syncWatchdogTimer?.invalidate()
        syncWatchdogTimer = nil
        NotificationCenter.default.removeObserver(self)
        trackingManager.onLocationUpdate = nil
        trackingManager.onTrackingStatusChanged = nil
        trackingManager.onError = nil
        trackingManager.onPermissionChanged = nil
        trackingManager.onRouteUpdate = nil
        trackingManager.onFakeGPSDetected = nil
    }

    // MARK: - FlutterPlugin Methods
    public func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
        nativeLog("📩 Method call: \(call.method)")
        switch call.method {
        case "configureTracking":
            configureTracking(call, result: result)
        case "configure":
            configure(call, result: result)
        case "configureAlertAPI":
            configureAlertAPI(call, result: result)
        case "configureZoneNetworkV2":
            configureZoneNetworkV2(call, result: result)
        case "resetZoneNetworkV2":
            resetZoneNetworkV2(result: result)
        case "requestLocationPermissions":
            requestLocationPermissions(result: result)
        case "hasLocationPermissions":
            hasLocationPermissions(result: result)
        case "requestAlwaysLocationPermissions":
            requestAlwaysLocationPermissions(result: result)
        case "startTracking":
            startTracking(call, result: result)
        case "stopTracking":
            stopTracking(result: result)
        case "getCurrentLocation":
            getCurrentLocation(result: result)
        case "isTrackingActive":
            isTrackingActive(result: result)
        case "getTrackingStatus":
            getTrackingStatus(result: result)
        case "getTrackingHealthStatus":
            getTrackingHealthStatus(result: result)
        case "getTrackingHistory":
            getTrackingHistory(call, result: result)
        case "updateTrackingConfig":
            updateTrackingConfig(call, result: result)
        case "turnOnAlert":
            turnOnAlert(result: result)
        case "turnOffAlert":
            turnOffAlert(result: result)
        case "isSpeedAlertActive":
            isSpeedAlertActive(result: result)
        case "configureVehicle":
            configureVehicle(call, result: result)
        case "setVehicleId":
            setVehicleId(call, result: result)
        case "setDriverId":
            setDriverId(call, result: result)
        case "getVehicleId":
            result(trackingManager.getVehicleId())
        case "getDriverId":
            result(trackingManager.getDriverId())
        case "setAutoUpload":
            setAutoUpload(call, result: result)
        case "setSmartBatteryConfig":
            setSmartBatteryConfig(call, result: result)
        case "processExternalLocation":
            processExternalLocation(call, result: result)
        case "isNetworkConnected":
            result(trackingManager.isNetworkConnected())
        case "getCachedLocationsCount":
            getCachedLocationsCount(result: result)
        case "uploadCachedLocationsManually":
            uploadCachedLocationsManually(result: result)
        case "clearCachedLocations":
            clearCachedLocations(result: result)
        case "configureCacheLimits":
            configureCacheLimits(call, result: result)
        case "getDatabaseSizeBytes":
            getDatabaseSizeBytes(result: result)
        case "setFakeGPSPolicy":
            setFakeGPSPolicy(call, result: result)
        case "onAppBackground":
            trackingManager.onAppBackground(); result(nil)
        case "onAppForeground":
            trackingManager.onAppForeground(); result(nil)
        case "getPlatformVersion":
            result("iOS " + UIDevice.current.systemVersion)
        default:
            result(FlutterMethodNotImplemented)
        }
    }

    // MARK: - Configuration Methods
    private func configure(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
        guard let args = call.arguments as? [String: Any],
              let apiKey = args["apiKey"] as? String else {
            result(FlutterError(code: "INVALID_ARGUMENTS",
                              message: "API key is required",
                              details: nil))
            return
        }

        self.apiKey = apiKey
        self.baseURL = args["baseURL"] as? String

        logSection("Configure SDK")
        nativeLog("⚙️ configure | apiKey=\(apiKey.prefix(10))... baseURL=\(self.baseURL ?? "nil")")
        defer { logSection("Configure SDK", end: true) }

        // Dùng initialize(apiKey:baseURL:) nếu có baseURL — atomic, tránh race condition
        // giữa configure(apiKey:) và configure(baseURL:) riêng lẻ.
        if let baseURL = self.baseURL, !baseURL.isEmpty {
            trackingManager.initialize(apiKey: apiKey, baseURL: baseURL)
        } else {
            trackingManager.configure(apiKey: apiKey)
        }

        trackingManager.setAutoUpload(enabled: true)
        isInitialized = true
        nativeLog("✅ configure success | autoUpload=true")

        // ── Sync Logger: setup network monitor + retention callback ──
        setupSyncLogger()

        result(true)
    }

    // MARK: - App Lifecycle Observers
    //
    // Plugin tự lắng nghe UIApplication lifecycle notifications để đảm bảo SDK
    // luôn nhận đúng app state — ngay cả khi Flutter không gọi onAppBackground/onAppForeground.
    // Dart layer cũng gọi các method này qua MethodChannel (double safety).
    private func setupLifecycleObservers() {
        logSection("Register Lifecycle Observers")
        let nc = NotificationCenter.default
        nc.addObserver(self,
                       selector: #selector(appDidEnterBackground),
                       name: UIApplication.didEnterBackgroundNotification,
                       object: nil)
        nc.addObserver(self,
                       selector: #selector(appWillEnterForeground),
                       name: UIApplication.willEnterForegroundNotification,
                       object: nil)
        nativeLog("📱 [Lifecycle] NotificationCenter observers registered")
        logSection("Register Lifecycle Observers", end: true)
    }

    @objc private func appDidEnterBackground() {
        logSection("Lifecycle: App Background")
        nativeLog("📱 [Lifecycle] appDidEnterBackground → SDK.onAppBackground()")
        trackingManager.onAppBackground()
        logSection("Lifecycle: App Background", end: true)
    }

    @objc private func appWillEnterForeground() {
        logSection("Lifecycle: App Foreground")
        nativeLog("📱 [Lifecycle] appWillEnterForeground → SDK.onAppForeground()")
        trackingManager.onAppForeground()
        logSection("Lifecycle: App Foreground", end: true)
        // SDK's appWillEnterForeground already calls restartNetworkMonitor() internally.
        // Wait for monitor to stabilize, then trigger manual sync if needed.
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) { [weak self] in
            guard let self = self else { return }
            let pending = self.trackingManager.getCachedLocationsCount()
            let sdkNetwork = self.trackingManager.isNetworkConnected()
            self.nativeLog("📱 [Lifecycle] Post-foreground | sdkNetwork=\(sdkNetwork) pending=\(pending)")
            if sdkNetwork && pending > 0 {
                self.triggerManualSync(reason: "foreground-return")
            }
        }
    }

    // MARK: - Sync Logger + Watchdog Setup
    //
    // Thiết kế: SDK đã có NWPathMonitor riêng (restartNetworkMonitor) và tự xử lý
    // upload khi network restored. Plugin KHÔNG dùng NWPathMonitor thứ hai để tránh
    // double-trigger. Thay vào đó plugin dùng:
    //   1. Watchdog timer (5s poll) — phát hiện SDK bị stuck offline (simulator edge case).
    //   2. URLSession probe — xác nhận kết nối thực khi SDK báo offline nhưng có pending.
    //   3. Manual sync — trigger uploadCachedLocationsManually() khi SDK không tự làm.
    //
    // ⚠️ iOS Simulator: SDK's NWPathMonitor có thể LUÔN báo .satisfied hoặc bị stale.
    //    Dùng toggle "Simulator Offline" trong example app (setAutoUpload false/true)
    //    để test offline behavior trên simulator.
    private func setupSyncLogger() {
        startSyncWatchdog()
    }

    /// Fallback watchdog: kiểm tra network state theo SDK mỗi 5s.
    /// Dùng khi NWPathMonitor không bắn event (thường gặp trên simulator hoặc edge cases).
    private func startSyncWatchdog() {
        syncWatchdogTimer?.invalidate()
        lastSdkNetworkStatus = trackingManager.isNetworkConnected()
        nativeLog("👀 [SYNC] Watchdog started | sdkNetwork=\(lastSdkNetworkStatus ?? false)")

        syncWatchdogTimer = Timer.scheduledTimer(withTimeInterval: 5.0, repeats: true) { [weak self] _ in
            guard let self = self else { return }

            let sdkNetwork = self.trackingManager.isNetworkConnected()
            let pending = self.trackingManager.getCachedLocationsCount()
            let previous = self.lastSdkNetworkStatus

            if previous != sdkNetwork {
                self.nativeLog("🔁 [SYNC] Watchdog network transition | sdk: \(previous.map(String.init(describing:)) ?? "nil") -> \(sdkNetwork)")
                self.lastSdkNetworkStatus = sdkNetwork
            }

            // Key scenario: offline -> online nhưng NWPathMonitor callback không chạy.
            if previous == false && sdkNetwork == true {
                self.nativeLog("🟢 [SYNC] Watchdog detected reconnect | pending=\(pending)")
                self.triggerManualSync(reason: "watchdog-reconnect")
                return
            }

            // Scenario phổ biến trên simulator: SDK stuck ở isNetworkAvailable=false
            // dù thực tế có mạng. Dùng URLSession probe để detect thực sự.
            if !sdkNetwork && pending > 0 {
                self.probeRealConnectivity { [weak self] isReallyOnline in
                    guard let self = self else { return }
                    if isReallyOnline {
                        self.nativeLog("⚠️ [SYNC] Watchdog MISMATCH: probe=online but SDK=offline | pending=\(pending) → refreshNetworkStatus")
                        self.trackingManager.refreshNetworkStatus()
                        // Sau khi refresh, đợi monitor fire (1s) rồi trigger sync
                        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) { [weak self] in
                            guard let self = self else { return }
                            self.lastSdkNetworkStatus = self.trackingManager.isNetworkConnected()
                            self.nativeLog("🔍 [SYNC] Post-refresh SDK state | sdkNetwork=\(self.lastSdkNetworkStatus ?? false)")
                            self.triggerManualSync(reason: "watchdog-mismatch-fixed")
                        }
                    } else {
                        self.nativeLog("🔴 [SYNC] Watchdog confirmed offline | pending=\(pending)")
                    }
                }
                return
            }

            // Safety net: nếu đang online và vẫn còn pending thì thử trigger sync định kỳ.
            if sdkNetwork && pending > 0 {
                self.nativeLog("⏱ [SYNC] Watchdog online with pending | pending=\(pending) -> trigger sync")
                self.triggerManualSync(reason: "watchdog-online-pending")
            }
        }
    }

    /// Kiểm tra kết nối thực tế bằng URLSession HEAD request đến DNS public.
    /// Dùng khi SDK's isNetworkConnected() bị nghi là stale (stuck false).
    private func probeRealConnectivity(completion: @escaping (Bool) -> Void) {
        guard let url = URL(string: "https://dns.google/") else {
            completion(false)
            return
        }
        var request = URLRequest(url: url)
        request.httpMethod = "HEAD"
        request.timeoutInterval = 5.0
        URLSession.shared.dataTask(with: request) { _, response, error in
            let isOnline = error == nil && (response as? HTTPURLResponse) != nil
            DispatchQueue.main.async { completion(isOnline) }
        }.resume()
    }

    private func triggerManualSync(reason: String) {
        if manualSyncInProgress {
            nativeLog("⏳ [SYNC] Skip manual sync (in-progress) | reason=\(reason)")
            return
        }

        let pendingBefore = trackingManager.getCachedLocationsCount()
        let dbBefore = trackingManager.getDatabaseSizeBytes()
        nativeLog("⏫ [SYNC] Trigger manual sync | reason=\(reason) pending=\(pendingBefore) dbSize=\(dbBefore)B")

        guard pendingBefore > 0 else {
            nativeLog("✅ [SYNC] Skip manual sync (no pending) | reason=\(reason)")
            return
        }

        manualSyncInProgress = true
        trackingManager.uploadCachedLocationsManually { [weak self] success, message in
            guard let self = self else { return }
            self.manualSyncInProgress = false
            let pendingAfter = self.trackingManager.getCachedLocationsCount()
            let dbAfter = self.trackingManager.getDatabaseSizeBytes()
            self.nativeLog("📤 [SYNC] Manual sync callback | reason=\(reason) success=\(success) msg=\(message ?? "nil") pending=\(pendingAfter) dbSize=\(dbAfter)B")
            self.scheduleCacheSnapshot("sync-\(reason)", after: 2)
            self.scheduleCacheSnapshot("sync-\(reason)", after: 10)
        }
    }

    // MARK: - configureTracking (new unified init method)

    /// configureTracking({apiKey, baseUrl?, authMode?, gpsTrackingEndpoint?,
    ///                     gpsBulkEndpoint?, autoUpload?})
    ///
    /// Unified configure entry point that maps `authMode` String → `VMAuthMode`
    /// and forwards optional endpoint overrides to the SDK.
    private func configureTracking(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
        guard let args = call.arguments as? [String: Any],
              let apiKey = args["apiKey"] as? String, !apiKey.isEmpty else {
            result(FlutterError(code: "INVALID_ARGUMENTS",
                               message: "apiKey is required",
                               details: nil))
            return
        }

        self.apiKey  = apiKey
        self.baseURL = args["baseUrl"] as? String

        logSection("Configure Tracking")
        defer { logSection("Configure Tracking", end: true) }

        // Initialise SDK
        if let baseURL = self.baseURL, !baseURL.isEmpty {
            trackingManager.initialize(apiKey: apiKey, baseURL: baseURL)
        } else {
            trackingManager.configure(apiKey: apiKey)
        }

        let authModeStr = args["authMode"] as? String ?? "header"
        let authMode: VMAuthMode = (authModeStr.lowercased() == "queryparam") ? .queryParam : .header
        trackingManager.configure(authMode: authMode)
        nativeLog("ℹ️ authMode=\(authModeStr) applied via configure(authMode:)")

        let autoUpload = args["autoUpload"] as? Bool ?? true
        trackingManager.setAutoUpload(enabled: autoUpload)

        isInitialized = true
        setupSyncLogger()

        nativeLog("✅ configureTracking OK | authMode=\(authModeStr) autoUpload=\(autoUpload)")
        result(true)
    }

    // MARK: - Zone Network V2

    /// configureZoneNetworkV2({baseUrl: String})
    private func configureZoneNetworkV2(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
        guard isInitialized else {
            result(FlutterError(code: "SDK_NOT_INITIALIZED",
                               message: "VietmapTrackingSDK not initialized",
                               details: nil))
            return
        }
        guard let args = call.arguments as? [String: Any],
              let baseUrl = args["baseUrl"] as? String, !baseUrl.isEmpty else {
            result(FlutterError(code: "INVALID_ARGUMENTS",
                               message: "baseUrl is required",
                               details: nil))
            return
        }

        logSection("Configure Zone Network V2")
        defer { logSection("Configure Zone Network V2", end: true) }

        let supported = VietmapTrackingWrapper.shared.configureZoneNetworkV2(baseUrl: baseUrl)
        if !supported {
            nativeLog("⚠️ configureZoneNetworkV2 is unavailable in current VietmapTrackingSDK build")
        }
        result(supported)
    }

    /// resetZoneNetworkV2()
    private func resetZoneNetworkV2(result: @escaping FlutterResult) {
        guard isInitialized else {
            result(FlutterError(code: "SDK_NOT_INITIALIZED",
                               message: "VietmapTrackingSDK not initialized",
                               details: nil))
            return
        }

        logSection("Reset Zone Network V2")
        defer { logSection("Reset Zone Network V2", end: true) }

        let supported = VietmapTrackingWrapper.shared.resetZoneNetworkV2()
        if !supported {
            nativeLog("⚠️ resetZoneNetworkV2 is unavailable in current VietmapTrackingSDK build")
        }
        result(supported)
    }

    private func configureAlertAPI(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
        guard isInitialized else {
            result(FlutterError(code: "SDK_NOT_INITIALIZED",
                              message: "VietmapTrackingSDK not initialized",
                              details: nil))
            return
        }

        guard let args = call.arguments as? [String: Any],
              let apiKey = args["apiKey"] as? String,
              let apiID = args["apiID"] as? String else {
            result(FlutterError(code: "INVALID_ARGUMENTS",
                              message: "Alert API key and ID are required",
                              details: nil))
            return
        }

        logSection("Configure Alert API")
        trackingManager.configureAlertAPI(apiKey: apiKey, apiID: apiID)
        result(true)
        logSection("Configure Alert API", end: true)
    }

    // MARK: - Permission Methods

    private func requestLocationPermissions(result: @escaping FlutterResult) {
        trackingManager.requestLocationPermissions { [weak self] status in
            guard let self = self else { return }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                let hasPermission = self.trackingManager.hasLocationPermissions()
                result([
                    "granted": hasPermission,
                    "status": hasPermission ? "granted" : "denied",
                    "fineLocation": hasPermission,
                    "coarseLocation": hasPermission,
                    "backgroundLocation": false
                ])
            }
        }
    }

    private func hasLocationPermissions(result: @escaping FlutterResult) {
        let hasPermission = trackingManager.hasLocationPermissions()
        result([
            "granted": hasPermission,
            "status": hasPermission ? "granted" : "not_granted",
            "fineLocation": hasPermission,
            "coarseLocation": hasPermission,
            "backgroundLocation": hasPermission  
        ])
    }

    private func requestAlwaysLocationPermissions(result: @escaping FlutterResult) {
        let status = CLLocationManager.authorizationStatus()
        let tempLocationManager = CLLocationManager()

        switch status {
        case .authorizedAlways:
            result("granted")
            return

        case .authorizedWhenInUse:
            tempLocationManager.requestAlwaysAuthorization()
            DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
                let newStatus: CLAuthorizationStatus
                if #available(iOS 14.0, *) {
                    newStatus = tempLocationManager.authorizationStatus
                } else {
                    newStatus = CLLocationManager.authorizationStatus()
                }
                switch newStatus {
                case .authorizedAlways:
                    result("granted")
                case .authorizedWhenInUse:
                    result("when_in_use")
                case .denied, .restricted:
                    result("denied")
                default:
                    result("denied")
                }
            }

        case .notDetermined:
            tempLocationManager.requestAlwaysAuthorization()
            DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
                let newStatus = CLLocationManager.authorizationStatus()
                switch newStatus {
                case .authorizedAlways:
                    result("granted")
                case .authorizedWhenInUse:
                    result("when_in_use")
                case .denied:
                    result("denied")
                default:
                    result("denied")
                }
            }

        case .denied, .restricted:
            result("denied")

        default:
            result("denied")
        }
    }

    // MARK: - Tracking Methods
    
    private func startTracking(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
            logSection("Start Tracking SDK")
        guard isInitialized else {
            result(FlutterError(code: "SDK_NOT_INITIALIZED",
                              message: "VietmapTrackingSDK not initialized",
                              details: nil))
            return
        }

        guard trackingManager.hasLocationPermissions() else {
            result(FlutterError(code: "PERMISSION_DENIED",
                              message: "Location permission not granted",
                              details: nil))
            return
        }

        let args = call.arguments as? [String: Any]
        let backgroundMode = args?["backgroundMode"] as? Bool ?? true
        let intervalMsInput = args?["intervalMs"] as? Int
        let distanceFilterInput = args?["distanceFilter"] as? Double
        let allowMockLocation = args?["allowMockLocation"] as? Bool ?? false
        
        // Internal default values for logging
        let intervalMs = intervalMsInput ?? -1
        let distanceFilter = distanceFilterInput ?? -1.0

        let deviceId = args?["deviceId"] as? String
        let userId = args?["userId"] as? String
        let vehicleId = args?["vehicleId"] as? String

        self.deviceId = deviceId
        self.userId = userId
        self.vehicleId = vehicleId

        // Determine trigger mode: SDK supports only ONE trigger mechanism
        let triggerMode: String
        if let interval = intervalMsInput, interval > 0, (distanceFilterInput == nil || distanceFilterInput! <= 0) {
            triggerMode = "⏱ TIMER ONLY (interval=\(interval)ms)"
        } else if let distance = distanceFilterInput, distance > 0, (intervalMsInput == nil || intervalMsInput! <= 0) {
            triggerMode = "📏 DISTANCE ONLY (distance=\(distance)m)"
        } else if intervalMsInput == nil && distanceFilterInput == nil {
            triggerMode = "ℹ️ SDK DEFAULTS (No values passed to SDK)"
        } else {
            triggerMode = "⚠️ BOTH (interval=\(intervalMs)ms + distance=\(distanceFilter)m)"
        }

        nativeLog("🚀 startTracking | bg=\(backgroundMode) \(triggerMode) mock=\(allowMockLocation) smartBattery=\(smartBatteryEnabled)")
        nativeLog("🆔 ids | deviceId=\(deviceId ?? "nil") userId=\(userId ?? "nil") vehicleId=\(vehicleId ?? "nil")")

        // ── Fake GPS Toggle ──
        let policy = allowMockLocation ? "allow" : "skip"
        trackingManager.setFakeGPSPolicy(policy)
        nativeLog("🕵️ [FakeGPS] allowMockLocation=\(allowMockLocation) -> force policy='\(policy)'")

        // ── iOS Battery Optimization via CoreLocation ──
        if let vid = vehicleId, !vid.isEmpty {
            trackingManager.setVehicleId(vid)
        }
        if let uid = userId, !uid.isEmpty {
            trackingManager.setDriverId(uid)
        }

        // ── iOS Battery Optimization via CoreLocation ──────────────────────────
        if smartBatteryEnabled {
            CLLocationManager().activityType = .automotiveNavigation
            CLLocationManager().pausesLocationUpdatesAutomatically = true
        } else {
            CLLocationManager().activityType = .other
            CLLocationManager().pausesLocationUpdatesAutomatically = false
        }

        // Logic check: if both are nil, call SDK's default startTracking
        // Note: iOS SDK 1.3.5 startTracking follows the same pattern as Android:
        // parameters are optional, falling back to internal defaults.
        trackingManager.startTracking(
            enhancedBackgroundMode: backgroundMode,
            intervalMs: intervalMs,
            distanceFilter: distanceFilter
        ) { [weak self] success, message in
            self?.handleStartResult(success: success, message: message, result: result)
        }
    }

    private func handleStartResult(success: Bool, message: String?, result: @escaping FlutterResult) {
        self.nativeLog("🏁 startTracking result | success=\(success) message=\(message ?? "nil")")
        DispatchQueue.main.async {
            result(success)
        }
    }

    private func stopTracking(result: @escaping FlutterResult) {
        logSection("Stop Tracking SDK")
        guard isInitialized else {
            result(FlutterError(code: "SDK_NOT_INITIALIZED",
                              message: "VietmapTrackingSDK not initialized",
                              details: nil))
            return
        }

        nativeLog("🛑 stopTracking called")
        trackingManager.stopTracking { [weak self] success, message in
            self?.nativeLog("🏁 stopTracking result | success=\(success) message=\(message ?? "nil")")
            DispatchQueue.main.async {
                if success {
                    result(true)
                } else {
                    result(false)
                }
            }
        }
    }
    // MARK: - Location Methods
    private func getCurrentLocation(result: @escaping FlutterResult) {
        guard isInitialized else {
            result(FlutterError(code: "SDK_NOT_INITIALIZED",
                              message: "VietmapTrackingSDK not initialized",
                              details: nil))
            return
        }

        if let location = trackingManager.getCurrentLocation() {
            result(location)
        } else {
            result(FlutterError(code: "LOCATION_UNAVAILABLE",
                              message: "Unable to get current location",
                              details: nil))
        }
    }

    private func isTrackingActive(result: @escaping FlutterResult) {
        let status = trackingManager.isTrackingActive()
        result(status)
    }

    private func getTrackingStatus(result: @escaping FlutterResult) {
        let status = trackingManager.getTrackingStatus()
        result(status)
    }

    private func getTrackingHealthStatus(result: @escaping FlutterResult) {
        let healthStatus = trackingManager.getTrackingHealthStatus()
        result(healthStatus)
    }

    private func getTrackingHistory(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
        logSection("Get Tracking History")
        defer { logSection("Get Tracking History", end: true) }

        guard isInitialized else {
            result(FlutterError(code: "SDK_NOT_INITIALIZED",
                              message: "VietmapTrackingSDK not initialized",
                              details: nil))
            return
        }

        guard let args = call.arguments as? [String: Any] else {
            result(FlutterError(code: "INVALID_ARGUMENTS",
                              message: "History arguments are required",
                              details: nil))
            return
        }

        let userId = (args["userId"] as? String ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
        let fromTime = (args["fromTime"] as? NSNumber)?.int64Value ?? 0
        let toTime = (args["toTime"] as? NSNumber)?.int64Value ?? 0
        let pageNumber = (args["pageNumber"] as? NSNumber)?.intValue ?? 1
        let pageSize = (args["pageSize"] as? NSNumber)?.intValue ?? 100
        let sortByRaw = (args["sortBy"] as? String ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
        let sortBy = sortByRaw.isEmpty ? "timestamp" : sortByRaw
        let sortDescending = args["sortDescending"] as? Bool ?? false

        guard !userId.isEmpty else {
            result(FlutterError(code: "INVALID_ARGUMENTS",
                              message: "userId is required",
                              details: nil))
            return
        }

        guard fromTime > 0, toTime > 0, fromTime <= toTime else {
            result(FlutterError(code: "INVALID_ARGUMENTS",
                              message: "fromTime/toTime are invalid",
                              details: nil))
            return
        }

        nativeLog("📜 getTrackingHistory | userId=\(userId) from=\(fromTime) to=\(toTime) page=\(pageNumber) size=\(pageSize) sortBy=\(sortBy) desc=\(sortDescending)")

        trackingManager.getHistory(
            userId: userId,
            fromTime: fromTime,
            toTime: toTime,
            pageNumber: pageNumber,
            pageSize: pageSize,
            sortBy: sortBy,
            sortDescending: sortDescending
        ) { [weak self] historyJson, errorCode, errorMessage in
            self?.nativeLog("📜 getTrackingHistory callback | errorCode=\(errorCode ?? "nil") message=\(errorMessage ?? "nil")")
            DispatchQueue.main.async {
                if let errorCode = errorCode {
                    result(FlutterError(
                        code: "GET_TRACKING_HISTORY_FAILED",
                        message: "[\(errorCode)] \(errorMessage ?? "Unknown error")",
                        details: ["code": errorCode, "message": errorMessage ?? ""]
                    ))
                    return
                }
                result(historyJson ?? "{}")
            }
        }
    }
    
    // MARK: - Alert Methods
    private func turnOnAlert (result: @escaping FlutterResult) {
        guard isInitialized else {
            result(FlutterError(code: "SDK_NOT_INITIALIZED",
                              message: "VietmapTrackingSDK not initialized",
                              details: nil))
            return
        }

        trackingManager.turnOnAlert { success in
            DispatchQueue.main.async {
                result(success)
            }
        }
    }

    private func turnOffAlert (result: @escaping FlutterResult) {
        guard isInitialized else {
            result(FlutterError(code: "SDK_NOT_INITIALIZED",
                              message: "VietmapTrackingSDK not initialized",
                              details: nil))
            return
        }

        trackingManager.turnOffAlert { success in
            DispatchQueue.main.async {
                result(success)
            }
        }
    }

    // MARK: - Legacy Support Methods (kept for backward compatibility)

    /// updateTrackingConfig(config) → bool
    ///
    /// IMPORTANT:
    /// iOS SDK hiện KHÔNG expose setTrackingInterval/setDistanceFilter nên
    /// update config phải stop → start (có rủi ro mất pending cache do SDK clear cache khi start).
    private func updateTrackingConfig(
        _ call: FlutterMethodCall,
        result: @escaping FlutterResult) {
        logSection("Update Tracking Config")
        guard isInitialized else {
            result(FlutterError(code: "SDK_NOT_INITIALIZED",
                              message: "VietmapTrackingSDK not initialized",
                              details: nil))
            return
        }
        let args = call.arguments as? [String: Any]
        let intervalMsInput = args?["intervalMs"] as? Int
        let distanceFilterInput = args?["distanceFilter"] as? Double

        // Values for logging
        let intervalMs = intervalMsInput ?? -1
        let distanceFilter = distanceFilterInput ?? -1.0

        // Determine trigger mode
        let triggerMode: String
        if let interval = intervalMsInput, interval > 0, (distanceFilterInput == nil || distanceFilterInput! <= 0) {
            triggerMode = "⏱ TIMER ONLY"
        } else if let distance = distanceFilterInput, distance > 0, (intervalMsInput == nil || intervalMsInput! <= 0) {
            triggerMode = "📏 DISTANCE ONLY"
        } else if intervalMsInput == nil && distanceFilterInput == nil {
            triggerMode = "ℹ️ SDK DEFAULTS"
        } else {
            triggerMode = "⚠️ BOTH"
        }
        nativeLog("⚙️ updateTrackingConfig | \(triggerMode) interval=\(intervalMs)ms distance=\(distanceFilter)m")
        logCacheSnapshot("update-config/before")

        // iOS SDK does NOT have setTrackingInterval() / setDistanceFilter() public methods.
        // The only way to change interval/distance is stop → start with new params.
        // Note: SDK's startTracking() calls clearCachedLocations() internally,
        // so pending records WILL be lost on config update.
        let backgroundMode = trackingManager.getTrackingStatus()["enhancedBackgroundMode"] as? Bool ?? true
        let cachedBefore = trackingManager.getCachedLocationsCount()

        if cachedBefore > 0 {
            nativeLog("⚠️ updateTrackingConfig: \(cachedBefore) pending records will be lost on restart")
            // Try to flush pending records before restart
            trackingManager.uploadCachedLocationsManually { [weak self] success, msg in
                self?.nativeLog("⏫ Pre-restart flush: success=\(success) msg=\(msg ?? "nil")")
                self?.logCacheSnapshot("update-config/pre-restart-flush-callback")
            }
        }

        logCacheSnapshot("update-config/before-stop")
        trackingManager.stopTracking { [weak self] _, _ in
            guard let self = self else { return }
            self.logCacheSnapshot("update-config/after-stop")
            self.nativeLog("🔄 updateTrackingConfig: stopped, restarting with new config...")
            self.trackingManager.startTracking(
                enhancedBackgroundMode: backgroundMode,
                intervalMs: intervalMsInput ?? 10000,
                distanceFilter: distanceFilterInput ?? 0.0
            ) { [weak self] success, message in
                self?.nativeLog("✅ updateTrackingConfig restart | success=\(success) msg=\(message ?? "nil")")
                self?.logCacheSnapshot("update-config/restart-callback")
                self?.scheduleCacheSnapshot("update-config/post-restart", after: 2)
                self?.scheduleCacheSnapshot("update-config/post-restart", after: 10)
                DispatchQueue.main.async {
                    result(success)
                }
            }
        }
    }

    // MARK: - Alert Extended Methods

    private func isSpeedAlertActive(result: @escaping FlutterResult) {
        result(trackingManager.isSpeedAlertCurrentlyActive())
    }

    private func configureVehicle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
        guard isInitialized else {
            result(FlutterError(code: "SDK_NOT_INITIALIZED", message: "SDK not initialized", details: nil))
            return
        }
        guard let args = call.arguments as? [String: Any],
              let vehicleId = args["vehicleId"] as? String else {
            result(FlutterError(code: "INVALID_ARGUMENTS", message: "vehicleId required", details: nil))
            return
        }
        let vehicleType = args["vehicleType"] as? Int ?? 0
        let seats = args["seats"] as? Int ?? 0
        let weight = args["weight"] as? Double ?? 0.0
        let maxProvision = args["maxProvision"] as? Int
        if let maxProvision = maxProvision {
            trackingManager.configureVehicle(vehicleId: vehicleId, vehicleType: vehicleType,
                                             seats: seats, weight: weight, maxProvision: maxProvision)
        } else {
            trackingManager.configureVehicle(vehicleId: vehicleId, vehicleType: vehicleType,
                                             seats: seats, weight: weight, maxProvision: 0)
        }
        result(true)
    }

    // MARK: - Identifier Methods

    private func setVehicleId(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
        guard let args = call.arguments as? [String: Any],
              let id = args["vehicleId"] as? String else {
            result(FlutterError(code: "INVALID_ARGUMENTS", message: "vehicleId required", details: nil))
            return
        }
        self.vehicleId = id
        trackingManager.setVehicleId(id)
        result(true)
    }

    private func setDriverId(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
        guard let args = call.arguments as? [String: Any],
              let id = args["driverId"] as? String else {
            result(FlutterError(code: "INVALID_ARGUMENTS", message: "driverId required", details: nil))
            return
        }
        self.userId = id
        trackingManager.setDriverId(id)
        result(true)
    }

    // MARK: - Smart Battery Config

    /// setSmartBatteryConfig(enabled: bool, preset: String)
    /// Bật/tắt tối ưu pin thông minh trên iOS.
    /// - enabled=true → activityType=.automotiveNavigation + pausesAuto=true (hiệu lực lần startTracking kế tiếp hoặc ngay lập tức nếu đang tracking)
    /// - preset: "navigation" | "general" | "batterySaver" — không áp dụng trực tiếp trên iOS
    ///   vì iOS CoreLocation tự điều chỉnh; chỉ log để reference.
    private func setSmartBatteryConfig(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
            logSection("Smart Battery Config")
        let args = call.arguments as? [String: Any]
        let enabled = args?["enabled"] as? Bool ?? false
        let preset = args?["preset"] as? String ?? "general"
        smartBatteryEnabled = enabled
        nativeLog("🔋 setSmartBatteryConfig | enabled=\(enabled) preset=\(preset)")
        // Nếu đang tracking, áp dụng ngay
        if trackingManager.isTrackingActive() {
            let clm = CLLocationManager()
            if enabled {
                clm.activityType = .automotiveNavigation
                clm.pausesLocationUpdatesAutomatically = true
                nativeLog("🔋 [SmartBattery] Applied LIVE: automotiveNavigation + pausesAuto=true")
            } else {
                clm.activityType = .other
                clm.pausesLocationUpdatesAutomatically = false
                nativeLog("🔋 [SmartBattery] Applied LIVE: .other + pausesAuto=false")
            }
        }
        result(true)
    }

    // MARK: - Fake GPS Policy

    /// Set the policy for handling detected fake GPS locations.
    /// Valid values: "skip" (default) | "warn" | "stopTracking" | "logToServer"
    /// Invalid values are silently ignored by the native SDK (falls back to "skip").
    private func setFakeGPSPolicy(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
        let args = call.arguments as? [String: Any]
        let policy = args?["policy"] as? String ?? "skip"
        nativeLog("⚙️ setFakeGPSPolicy: \(policy)")
        trackingManager.setFakeGPSPolicy(policy)
        result(nil)
    }

    // MARK: - Auto Upload

    private func setAutoUpload(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
        let args = call.arguments as? [String: Any]
        let enabled = args?["enabled"] as? Bool ?? true
        trackingManager.setAutoUpload(enabled: enabled)
        result(true)
    }

    // MARK: - External GPS Injection

    private func processExternalLocation(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
        guard isInitialized else {
            result(FlutterError(code: "SDK_NOT_INITIALIZED", message: "SDK not initialized", details: nil))
            return
        }
        guard let args = call.arguments as? [String: Any],
              let lat = args["lat"] as? Double,
              let lng = args["lng"] as? Double,
              let speed = args["speed"] as? Double,
              let heading = args["heading"] as? Double else {
            result(FlutterError(code: "INVALID_ARGUMENTS", message: "lat, lng, speed, heading required", details: nil))
            return
        }
        let accuracy = args["accuracy"] as? Double ?? 0.0
        let altitude = args["altitude"] as? Double ?? 0.0
        let timestamp = args["timestamp"] as? Int ?? Int(Date().timeIntervalSince1970 * 1000)
        nativeLog("🛰️ processExternalLocation | lat=\(lat) lng=\(lng) speed=\(speed) heading=\(heading) accuracy=\(accuracy) altitude=\(altitude) timestamp=\(timestamp)")
        trackingManager.processExternalLocation(
            lat: lat, lng: lng, speed: speed, heading: heading,
            // accuracy: accuracy, altitude: altitude, timestamp: timestamp
        )
        result(true)
    }

    // MARK: - Cache Methods

    private func getCachedLocationsCount(result: @escaping FlutterResult) {
        let count = trackingManager.getCachedLocationsCount()
        nativeLog("📦 getCachedLocationsCount | count=\(count)")
        logCacheSnapshot("method/getCachedLocationsCount")
        result(count)
    }

    private func getDatabaseSizeBytes(result: @escaping FlutterResult) {
        let size = trackingManager.getDatabaseSizeBytes()
        nativeLog("🗄️ getDatabaseSizeBytes | size=\(size)B")
        logCacheSnapshot("method/getDatabaseSizeBytes")
        result(size)
    }

    private func uploadCachedLocationsManually(result: @escaping FlutterResult) {
        nativeLog("📤 uploadCachedLocationsManually called")
        logCacheSnapshot("manual-upload/before")
        trackingManager.uploadCachedLocationsManually { [weak self] success, message in
            self?.nativeLog("📤 uploadCachedLocationsManually result | success=\(success) message=\(message ?? "nil")")
            self?.logCacheSnapshot("manual-upload/callback")
            self?.scheduleCacheSnapshot("manual-upload/post", after: 2)
            DispatchQueue.main.async { result(success) }
        }
    }

    private func clearCachedLocations(result: @escaping FlutterResult) {
        logCacheSnapshot("clear-cache/before")
        let before = trackingManager.getCachedLocationsCount()
        trackingManager.clearCachedLocations()
        let after = trackingManager.getCachedLocationsCount()
        nativeLog("🧹 clearCachedLocations | before=\(before) after=\(after)")
        logCacheSnapshot("clear-cache/after")
        result(true)
    }

    // MARK: - Cache Limits Config

    private func configureCacheLimits(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
        let args = call.arguments as? [String: Any]
        let maxRecords = args?["maxRecords"] as? Int ?? 0
        let maxDbSizeBytes = args?["maxDbSizeBytes"] as? Int64 ?? 0
        let batchSize = args?["batchSize"] as? Int ?? 0
        // Use SDK defaults for zero values
        let finalMaxRecords = maxRecords > 0 ? maxRecords : 10_000
        let finalMaxDbSize: Int64 = maxDbSizeBytes > 0 ? maxDbSizeBytes : 52_428_800 // 50 MB
        let finalBatchSize = batchSize > 0 ? batchSize : 50
        nativeLog("💾 configureCacheLimits | maxRecords=\(finalMaxRecords) maxDbSize=\(finalMaxDbSize) batchSize=\(finalBatchSize)")
        trackingManager.configureCacheLimits(
            maxRecords: finalMaxRecords,
            maxDbSizeBytes: finalMaxDbSize,
            batchSize: finalBatchSize
        )
        result(true)
    }

    // MARK: - BMP → PNG conversion
    //
    // VietmapAlertBridge may deliver raw BGRA bytes (matching the Windows BMP
    // colour-channel order).  We swap B↔R to obtain RGBA and then create a
    // CGImage so UIKit can produce a standard PNG for Dart.
    private func imageFromBmpData(_ data: Data) -> UIImage? {
        // Try direct BitmapFactory-style decode first (SDK may wrap in BMP header)
        if let img = UIImage(data: data) { return img }

        // Manual BGRA → RGBA swap
        let pixelCount = data.count / 4
        guard pixelCount > 0 else { return nil }

        var rgba = [UInt8](repeating: 0, count: data.count)
        data.copyBytes(to: &rgba, count: data.count)
        var i = 0
        while i < rgba.count - 3 {
            let b = rgba[i], r = rgba[i + 2]
            rgba[i] = r; rgba[i + 2] = b
            i += 4
        }

        // Assume square-ish image — use sqrt heuristic for width
        let side = Int(sqrt(Double(pixelCount)))
        guard side > 0 else { return nil }
        let w = side, h = pixelCount / side

        let colorSpace = CGColorSpaceCreateDeviceRGB()
        guard let ctx = CGContext(
            data: &rgba,
            width: w, height: h,
            bitsPerComponent: 8, bytesPerRow: w * 4,
            space: colorSpace,
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        ), let cgImg = ctx.makeImage() else { return nil }

        return UIImage(cgImage: cgImg)
    }

    private func nativeLog(_ message: String) {
        NSLog("%@ %@", nativeLogTag, message)
    }

    private func logSection(_ section: String, end: Bool = false) {
        let prefix = end ? "End " : ""
        nativeLog("=======\(prefix)\(section)=======")
    }

    private func logCacheSnapshot(_ stage: String) {
        let pending = trackingManager.getCachedLocationsCount()
        let dbSize = trackingManager.getDatabaseSizeBytes()
        let network = trackingManager.isNetworkConnected()
        let tracking = trackingManager.isTrackingActive()
        nativeLog("📊 [CACHE] \(stage) | pending=\(pending) dbSize=\(dbSize)B network=\(network) tracking=\(tracking)")
    }

    private func scheduleCacheSnapshot(_ stage: String, after seconds: TimeInterval) {
        DispatchQueue.main.asyncAfter(deadline: .now() + seconds) { [weak self] in
            self?.logCacheSnapshot("\(stage)+\(Int(seconds))s")
        }
    }

} // end VietmapTrackingPlugin

// MARK: - Stream Handlers

private class LocationStreamHandler: NSObject, FlutterStreamHandler {
    private var eventSink: FlutterEventSink?

    func onListen(withArguments arguments: Any?, eventSink events: @escaping FlutterEventSink) -> FlutterError? {
        self.eventSink = events
        return nil
    }

    func onCancel(withArguments arguments: Any?) -> FlutterError? {
        self.eventSink = nil
        return nil
    }

    func send(event: Any) {
        eventSink?(event)
    }
}

/// Stream handler cho EventChannel "vietmap_tracking_plugin/tracking_status"
private class TrackingStatusStreamHandler: NSObject, FlutterStreamHandler {
    private var eventSink: FlutterEventSink?

    func onListen(withArguments arguments: Any?, eventSink events: @escaping FlutterEventSink) -> FlutterError? {
        self.eventSink = events
        return nil
    }

    func onCancel(withArguments arguments: Any?) -> FlutterError? {
        self.eventSink = nil
        return nil
    }

    func send(event: Any) {
        eventSink?(event)
    }
}

/// Generic stream handler for speed-sign and TTS EventChannels.
private class SimpleStreamHandler: NSObject, FlutterStreamHandler {
    private var eventSink: FlutterEventSink?

    func onListen(withArguments arguments: Any?, eventSink events: @escaping FlutterEventSink) -> FlutterError? {
        self.eventSink = events
        return nil
    }

    func onCancel(withArguments arguments: Any?) -> FlutterError? {
        self.eventSink = nil
        return nil
    }

    func send(event: Any) {
        DispatchQueue.main.async { [weak self] in
            self?.eventSink?(event)
        }
    }
}