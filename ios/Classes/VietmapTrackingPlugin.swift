import Flutter
import UIKit
import CoreLocation

public class VietmapTrackingPlugin: NSObject, FlutterPlugin, FlutterStreamHandler {

    // MARK: - Properties
    private var isInitialized: Bool = false
    private var apiKey: String?
    private var baseURL: String?
    private var locationUpdateSink: FlutterEventSink?
    private var trackingStatusSink: FlutterEventSink?
    private var isTracking: Bool = false
    private var trackingStartTime: Date?
    private let locationManager = CLLocationManager()

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
        locationUpdateChannel.setStreamHandler(instance)
        trackingStatusChannel.setStreamHandler(instance)
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

        isTracking = true
        trackingStartTime = Date()

        // Send status update
        trackingStatusSink?([
            "isTracking": true,
            "lastLocationUpdate": NSNull(),
            "trackingDuration": 0
        ])

        result(true)
    }

    private func stopTracking(result: @escaping FlutterResult) {
        isTracking = false
        trackingStartTime = nil

        // Send status update
        trackingStatusSink?([
            "isTracking": false,
            "lastLocationUpdate": NSNull(),
            "trackingDuration": 0
        ])

        result(true)
    }

    private func getCurrentLocation(result: @escaping FlutterResult) {
        guard isInitialized else {
            result(FlutterError(code: "SDK_NOT_INITIALIZED",
                              message: "VietmapTrackingSDK not initialized",
                              details: nil))
            return
        }

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
        result(isTracking)
    }

    private func getTrackingStatus(result: @escaping FlutterResult) {
        let duration: Int
        if isTracking, let startTime = trackingStartTime {
            duration = Int(Date().timeIntervalSince(startTime) * 1000)
        } else {
            duration = 0
        }

        result([
            "isTracking": isTracking,
            "lastLocationUpdate": NSNull(),
            "trackingDuration": duration
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

    // MARK: - FlutterStreamHandler
    public func onListen(withArguments arguments: Any?, eventSink events: @escaping FlutterEventSink) -> FlutterError? {
        // Determine which stream based on arguments or channel
        if locationUpdateSink == nil {
            locationUpdateSink = events
        } else {
            trackingStatusSink = events
        }
        return nil
    }

    public func onCancel(withArguments arguments: Any?) -> FlutterError? {
        locationUpdateSink = nil
        trackingStatusSink = nil
        return nil
    }
}
