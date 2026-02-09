import Flutter
import UIKit
import CoreLocation
import VietmapTrackingSDK

public class VietmapTrackingPlugin: NSObject, FlutterPlugin {

    // MARK: - Properties
    private var isInitialized: Bool = false
    private var apiKey: String?
    private var baseURL: String?
    private let trackingManager = VietmapTrackingManager.shared
    private let locationManager = CLLocationManager()

    // Stream handlers — mỗi EventChannel có stream handler riêng biệt
    // Khắc phục lỗi bản gốc dùng chung 1 FlutterStreamHandler cho 2 channel
    private let locationStreamHandler = LocationStreamHandler()
    private let trackingStatusStreamHandler = TrackingStatusStreamHandler()

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

        let instance = VietmapTrackingPlugin()
        registrar.addMethodCallDelegate(instance, channel: channel)
        locationUpdateChannel.setStreamHandler(instance.locationStreamHandler)
        trackingStatusChannel.setStreamHandler(instance.trackingStatusStreamHandler)

        // Setup SDK callbacks sau khi đăng ký plugin
        // (matching React Native iOS pattern: setupSDKCallbacks)
        instance.setupSDKCallbacks()
    }

    // MARK: - SDK Callbacks Setup
    // Theo Guide.md mục 5 — forward 5 events từ Native SDK Layer → Bridge Layer → Flutter EventChannel
    // RN iOS bridge setup tương tự trong setupSDKCallbacks()
    private func setupSDKCallbacks() {
        // 1. onLocationUpdate — forward vị trí GPS real-time
        // Guide.md: trackingManager.onLocationUpdate: ((NSDictionary) -> Void)?
        // Payload: {latitude, longitude, altitude, accuracy, speed, bearing, timestamp}
        trackingManager.onLocationUpdate = { [weak self] locationDict in
            guard let self = self else { return }
            if let dict = locationDict as? [String: Any] {
                self.locationStreamHandler.send(event: dict)
            }
        }

        // 2. onTrackingStatusChanged — forward trạng thái tracking
        // Guide.md: trackingManager.onTrackingStatusChanged: ((NSDictionary) -> Void)?
        // Payload: {isTracking, status, timestamp, ...}
        trackingManager.onTrackingStatusChanged = { [weak self] statusDict in
            guard let self = self else { return }
            if let dict = statusDict as? [String: Any] {
                self.trackingStatusStreamHandler.send(event: dict)
            }
        }

        // 3. onError — forward lỗi location/tracking
        // Guide.md: trackingManager.onError: ((String) -> Void)?
        // Payload: {error, timestamp}
        trackingManager.onError = { [weak self] errorMessage in
            guard let self = self else { return }
            self.locationStreamHandler.send(event: [
                "error": errorMessage,
                "timestamp": Int(Date().timeIntervalSince1970 * 1000)
            ])
        }

        // 4. onPermissionChanged — forward thay đổi quyền location
        // Guide.md: trackingManager.onPermissionChanged: ((String) -> Void)?
        // Payload: {status, timestamp}
        trackingManager.onPermissionChanged = { [weak self] status in
            guard let self = self else { return }
            self.trackingStatusStreamHandler.send(event: [
                "permissionStatus": status,
                "timestamp": Int(Date().timeIntervalSince1970 * 1000)
            ])
        }

        // 5. onRouteUpdate — forward cập nhật tuyến đường
        // Guide.md: trackingManager.onRouteUpdate: ((Bool, NSDictionary?) -> Void)?
        // Payload: {success, routeData, timestamp}
        trackingManager.onRouteUpdate = { [weak self] success, routeData in
            guard let self = self else { return }
            var event: [String: Any] = [
                "success": success,
                "timestamp": Int(Date().timeIntervalSince1970 * 1000)
            ]
            if let routeDict = routeData as? [String: Any] {
                event["routeData"] = routeDict
            }
            self.trackingStatusStreamHandler.send(event: event)
        }
    }

    // MARK: - Cleanup
    // Guide.md mục 8 — iOS deinit: CHỈ xóa callbacks, KHÔNG gọi stopTracking()
    // Matching React Native iOS deinit pattern
    deinit {
        trackingManager.onLocationUpdate = nil
        trackingManager.onTrackingStatusChanged = nil
        trackingManager.onError = nil
        trackingManager.onPermissionChanged = nil
        trackingManager.onRouteUpdate = nil
    }

    // MARK: - FlutterPlugin Methods
    public func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
        switch call.method {
        case "configure":
            configure(call, result: result)
        case "configureAlertAPI":
            configureAlertAPI(call, result: result)
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
        case "updateTrackingConfig":
            updateTrackingConfig(call, result: result)
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
        isInitialized = true
        result(true)
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

        result(true)
    }

    // MARK: - Permission Methods
    private func hasLocationPermission() -> Bool {
        let status: CLAuthorizationStatus
        if #available(iOS 14.0, *) {
            status = locationManager.authorizationStatus
        } else {
            status = CLLocationManager.authorizationStatus()
        }
        return status == .authorizedWhenInUse || status == .authorizedAlways
    }

    private func requestLocationPermissions(result: @escaping FlutterResult) {
        let status: CLAuthorizationStatus
        if #available(iOS 14.0, *) {
            status = locationManager.authorizationStatus
        } else {
            status = CLLocationManager.authorizationStatus()
        }

        if status == .authorizedWhenInUse || status == .authorizedAlways {
            result([
                "granted": true,
                "status": "granted",
                "fineLocation": true,
                "coarseLocation": true,
                "backgroundLocation": status == .authorizedAlways
            ])
            return
        }

        locationManager.requestWhenInUseAuthorization()
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            let hasPermission = self.hasLocationPermission()
            result([
                "granted": hasPermission,
                "status": hasPermission ? "granted" : "denied",
                "fineLocation": hasPermission,
                "coarseLocation": hasPermission,
                "backgroundLocation": false
            ])
        }
    }

    private func hasLocationPermissions(result: @escaping FlutterResult) {
        let hasPermission = hasLocationPermission()
        let status: CLAuthorizationStatus
        if #available(iOS 14.0, *) {
            status = locationManager.authorizationStatus
        } else {
            status = CLLocationManager.authorizationStatus()
        }
        
        result([
            "granted": hasPermission,
            "status": hasPermission ? "granted" : "denied",
            "fineLocation": hasPermission,
            "coarseLocation": hasPermission,
            "backgroundLocation": status == .authorizedAlways
        ])
    }

    private func requestAlwaysLocationPermissions(result: @escaping FlutterResult) {
        let status: CLAuthorizationStatus
        if #available(iOS 14.0, *) {
            status = locationManager.authorizationStatus
        } else {
            status = CLLocationManager.authorizationStatus()
        }

        switch status {
        case .authorizedAlways:
            result("granted")
            return

        case .authorizedWhenInUse:
            locationManager.requestAlwaysAuthorization()
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                let newStatus: CLAuthorizationStatus
                if #available(iOS 14.0, *) {
                    newStatus = self.locationManager.authorizationStatus
                } else {
                    newStatus = CLLocationManager.authorizationStatus()
                }
                result(newStatus == .authorizedAlways ? "granted" : "denied")
            }

        case .notDetermined:
            locationManager.requestAlwaysAuthorization()
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                result(self.hasLocationPermission() ? "granted" : "denied")
            }

        default:
            result("denied")
        }
    }

    // MARK: - Tracking Methods
    private func startTracking(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
        guard isInitialized else {
            result(FlutterError(code: "SDK_NOT_INITIALIZED",
                              message: "VietmapTrackingSDK not initialized",
                              details: nil))
            return
        }

        guard hasLocationPermission() else {
            result(FlutterError(code: "PERMISSION_DENIED",
                              message: "Location permission not granted",
                              details: nil))
            return
        }

        // TODO: Giai đoạn 2 — parse config từ call.arguments và gọi SDK thật
        // Tạm resolve true để không break flow
        result(true)
    }

    private func stopTracking(result: @escaping FlutterResult) {
        // TODO: Giai đoạn 2 — gọi trackingManager.stopTracking(completion:)
        result(true)
    }

    private func getCurrentLocation(result: @escaping FlutterResult) {
        guard isInitialized else {
            result(FlutterError(code: "SDK_NOT_INITIALIZED",
                              message: "VietmapTrackingSDK not initialized",
                              details: nil))
            return
        }

        // TODO: Giai đoạn 2 — gọi trackingManager.getCurrentLocation()
        result([
            "latitude": 0.0,
            "longitude": 0.0,
            "altitude": 0.0,
            "accuracy": 0.0,
            "speed": 0.0,
            "bearing": 0.0,
            "timestamp": Int(Date().timeIntervalSince1970 * 1000)
        ])
    }

    private func isTrackingActive(result: @escaping FlutterResult) {
        // TODO: Giai đoạn 2 — gọi trackingManager.isTrackingActive()
        result(false)
    }

    private func getTrackingStatus(result: @escaping FlutterResult) {
        // TODO: Giai đoạn 2 — gọi trackingManager.getTrackingStatus()
        result([
            "isTracking": false,
            "lastLocationUpdate": NSNull(),
            "trackingDuration": 0
        ])
    }

    private func updateTrackingConfig(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
        guard isInitialized else {
            result(FlutterError(code: "SDK_NOT_INITIALIZED",
                              message: "VietmapTrackingSDK not initialized",
                              details: nil))
            return
        }

        result(true)
    }

}

// MARK: - Stream Handlers
// Mỗi EventChannel có stream handler riêng — tránh lỗi bản gốc dùng chung 1 handler
// và phân biệt sink bằng thứ tự onListen (không tin cậy)

/// Stream handler cho EventChannel "vietmap_tracking_plugin/location_updates"
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
