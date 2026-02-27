import Flutter
import UIKit
import CoreLocation
import VietmapTrackingSDK

public class VietmapTrackingPlugin: NSObject, FlutterPlugin {

    // MARK: - Properties
    private var isInitialized: Bool = false
    private var apiKey: String?
    private var baseURL: String?

    // MARK: - VietmapTrackingSDK Integration
    private let trackingManager = VietmapTrackingManager.shared

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

        instance.setupSDKCallbacks()
    }

    // MARK: - SDK Callbacks Setup
    private func setupSDKCallbacks() {
        trackingManager.onLocationUpdate = { [weak self] locationDict in
            guard let self = self else { return }
            if let dict = locationDict as? [String: Any] {
                self.locationStreamHandler.send(event: dict)
            }
        }

        trackingManager.onTrackingStatusChanged = { [weak self] statusDict in
            guard let self = self else { return }
            if let dict = statusDict as? [String: Any] {
                self.trackingStatusStreamHandler.send(event: dict)
            }
        }

        trackingManager.onError = { [weak self] errorMessage in
            guard let self = self else { return }
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
                event["routeData"] = routeDict
            }
            self.trackingStatusStreamHandler.send(event: event)
        }
    }

    // MARK: - Cleanup
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
        case "getTrackingHealthStatus":
            getTrackingHealthStatus(result: result)
        case "updateTrackingConfig":
            updateTrackingConfig(call, result: result)
        case "turnOnAlert":
            turnOnAlert(result: result)
        case "turnOffAlert":
            turnOffAlert(result: result)
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
        trackingManager.configure(apiKey: apiKey)

        if let baseURL = baseURL, !baseURL.isEmpty {
            trackingManager.configure(baseURL: baseURL)
        }

        trackingManager.setAutoUpload(enabled: true)
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
        trackingManager.configureAlertAPI(apiKey: apiKey, apiID: apiID)
        result(true)
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
        let intervalMs = args?["intervalMs"] as? Int ?? 5000
        let distanceFilter = args?["distanceFilter"] as? Double ?? 10.0

        trackingManager.startTracking(
            enhancedBackgroundMode: backgroundMode,
            intervalMs: intervalMs,
            distanceFilter: distanceFilter
        ) { success, message in
            DispatchQueue.main.async {
                if success {
                    result(true)
                } else {
                    result(false)
                }
            }
        }
    }

    private func stopTracking(result: @escaping FlutterResult) {
        guard isInitialized else {
            result(FlutterError(code: "SDK_NOT_INITIALIZED",
                              message: "VietmapTrackingSDK not initialized",
                              details: nil))
            return
        }

         trackingManager.stopTracking { success, message in
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

    private func updateTrackingConfig(
        _ call: FlutterMethodCall, 
        result: @escaping FlutterResult) {
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