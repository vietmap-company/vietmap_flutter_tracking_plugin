import Flutter
import UIKit
import CoreLocation

@main
@objc class AppDelegate: FlutterAppDelegate {

  /// Shared SLC manager — lives for the entire process lifetime
  private lazy var slcManager = SLCBackgroundLocationManager.shared

  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {

    // ── Phase 3 Check: Was this launch triggered by a significant-location-change? ──
    let launchedByLocation = launchOptions?[.location] != nil

    let deviceId = UIDevice.current.uniqueDeviceID
    NSLog("[SLC] 🚀 App Launched. Device ID: \(deviceId) | Launched by location: \(launchedByLocation)")

    if launchedByLocation {
      // App was terminated and re-launched by iOS because the user moved ≥ 500 m
      // or a cell-tower handover occurred.
      // Flutter engine is NOT yet alive → we must handle GPS natively.
      NSLog("[SLC] 🟢 App re-launched by Significant Location Change")
      slcManager.handleSLCWakeUp()
    }

    GeneratedPluginRegistrant.register(with: self)

    // Register a MethodChannel so Dart can start/stop SLC
    if let controller = window?.rootViewController as? FlutterViewController {
      let slcChannel = FlutterMethodChannel(
        name: "vietmap_tracking_plugin/slc",
        binaryMessenger: controller.binaryMessenger
      )
      slcChannel.setMethodCallHandler { [weak self] (call, result) in
        guard let self = self else { return }
        switch call.method {
        case "startSLC":
          let args = call.arguments as? [String: Any]
          let config = SLCConfig(
            apiKey: args?["apiKey"] as? String ?? "",
            deviceId: args?["deviceId"] as? String ?? UIDevice.current.uniqueDeviceID,
            vehicleId: args?["vehicleId"] as? String,
            userId: args?["userId"] as? String,
            apiEndpoint: args?["apiEndpoint"] as? String ?? "https://dev.fleetwork.vn/api/v1/gps-tracking",
            distanceFilter: (args?["distanceFilter"] as? NSNumber)?.doubleValue ?? 500.0  // Default 500m
          )
          self.slcManager.startSLC(config: config)
          result(true)
        case "stopSLC":
          self.slcManager.stopSLC()
          result(true)
        case "isSLCActive":
          result(self.slcManager.isSLCActive())
        case "getSLCLogs":
          result(self.slcManager.getSLCLogs())
        default:
          result(FlutterMethodNotImplemented)
        }
      }
    }

    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }
}

// MARK: - SLC Configuration (persisted in UserDefaults)

struct SLCConfig: Codable {
  let apiKey: String
  let deviceId: String
  let vehicleId: String?
  let userId: String?
  let apiEndpoint: String
  let distanceFilter: CLLocationDistance  // Minimum distance to trigger location update (meters)

  private static let key = "vietmap_slc_config"

  func save() {
    if let data = try? JSONEncoder().encode(self) {
      UserDefaults.standard.set(data, forKey: SLCConfig.key)
      UserDefaults.standard.synchronize()
      NSLog("[SLC] Config saved to UserDefaults")
    }
  }

  static func load() -> SLCConfig? {
    guard let data = UserDefaults.standard.data(forKey: SLCConfig.key) else { return nil }
    return try? JSONDecoder().decode(SLCConfig.self, from: data)
  }

  static func clear() {
    UserDefaults.standard.removeObject(forKey: SLCConfig.key)
    UserDefaults.standard.synchronize()
  }
}

// MARK: - SLC Background Location Manager

/// Manages Significant Location Change monitoring independently of the
/// Flutter engine.  When iOS re-launches the app after a force-kill, this
/// class reads the persisted config from UserDefaults, creates a
/// CLLocationManager, and sends the GPS fix to the backend via a
/// background URLSession (which survives even if the process is suspended
/// again within seconds).
class SLCBackgroundLocationManager: NSObject, CLLocationManagerDelegate, URLSessionTaskDelegate {

  static let shared = SLCBackgroundLocationManager()

  private var locationManager: CLLocationManager?
  private var config: SLCConfig?

  /// In-memory ring-buffer of recent SLC log lines (max 200).
  private var logBuffer: [String] = []
  private let logBufferMax = 200
  
  /// Location deduplication: track last sent location to avoid sending same location multiple times
  private var lastSentLocation: CLLocation?
  private var lastSentTimestamp: TimeInterval = 0
  
  /// Minimum distance between sent locations (meters) - prevents noise
  private let locationDeduplicationThreshold: CLLocationDistance = 50.0
  
  /// Minimum accuracy threshold (meters) - filter poor GPS fixes
  private let minAccuracyThreshold: CLLocationDistance = 1000.0

  /// Background URLSession identifier — must be unique per app.
  private let backgroundSessionId = "com.vietmap.slc.background.upload"

  private lazy var bgURLSession: URLSession = {
    let sessionConfig = URLSessionConfiguration.background(withIdentifier: backgroundSessionId)
    sessionConfig.isDiscretionary = false
    sessionConfig.sessionSendsLaunchEvents = true
    sessionConfig.allowsCellularAccess = true
    sessionConfig.timeoutIntervalForRequest = 30
    sessionConfig.timeoutIntervalForResource = 60
    return URLSession(configuration: sessionConfig, delegate: self, delegateQueue: nil)
  }()

  private override init() {
    super.init()
  }

  // MARK: Public API

  /// Called from Dart (Phase 1): persist config & start SLC monitoring.
  func startSLC(config: SLCConfig) {
    // Stop any existing monitoring first to prevent duplicate location managers
    locationManager?.stopMonitoringSignificantLocationChanges()
    
    self.config = config
    config.save()
    
    // Verify config was saved successfully
    if let savedConfig = SLCConfig.load() {
      appendLog("🔒 Config verified saved: deviceId=\(savedConfig.deviceId), distanceFilter=\(savedConfig.distanceFilter)m, apiKey=\(savedConfig.apiKey.prefix(10))...")
    } else {
      appendLog("⚠️ WARNING: Config may not have been saved correctly")
    }

    let lm = CLLocationManager()
    lm.delegate = self
    lm.allowsBackgroundLocationUpdates = true
    lm.pausesLocationUpdatesAutomatically = false
    // Changed from kCLLocationAccuracyBest to HundredMeters for better battery life
    // SLC doesn't need ultra-high accuracy; ±100m is sufficient for 500m+ distance filter
    lm.desiredAccuracy = kCLLocationAccuracyHundredMeters
    lm.distanceFilter = config.distanceFilter  // Only trigger location update if moved >= distanceFilter meters
    
    appendLog("📏 Distance filter set to: \(config.distanceFilter)m")

    // SLC only needs "Always" authorization
    if CLLocationManager.authorizationStatus() == .authorizedAlways {
      lm.startMonitoringSignificantLocationChanges()
      appendLog("✅ SLC monitoring started (Always auth) with \(config.distanceFilter)m filter")
    } else if CLLocationManager.authorizationStatus() == .authorizedWhenInUse {
      // Request upgrade to Always
      lm.requestAlwaysAuthorization()
      // Start anyway — it will work in foreground/background but NOT after kill
      // until the user grants "Always".
      lm.startMonitoringSignificantLocationChanges()
      appendLog("⚠️ SLC started but needs Always authorization for post-kill wake-up. Distance filter: \(config.distanceFilter)m")
    } else {
      lm.requestAlwaysAuthorization()
      appendLog("⚠️ Requesting Always authorization for SLC. Distance filter: \(config.distanceFilter)m")
    }

    self.locationManager = lm
    let authStatus = CLLocationManager.authorizationStatus().rawValue
    appendLog("📡 SLC registration complete. Auth=\(authStatus), Distance=\(config.distanceFilter)m, DeviceId=\(config.deviceId)")
  }

  /// Called from Dart (Phase 4) or when user explicitly stops.
  func stopSLC() {
    locationManager?.stopMonitoringSignificantLocationChanges()
    locationManager = nil
    config = nil
    SLCConfig.clear()
    appendLog("🛑 SLC monitoring stopped and config cleared")
  }

  /// Called from AppDelegate when `launchOptions` contains `.location`
  /// (Phase 3: app was relaunched by iOS after force-kill).
  func handleSLCWakeUp() {
    guard let savedConfig = SLCConfig.load() else {
      NSLog("[SLC] ❌ No saved config — cannot resume SLC after wake-up")
      return
    }

    // Pre-load config BEFORE re-registering monitoring to prevent race condition
    self.config = savedConfig
    appendLog("🔄 SLC wake-up: restoring config from UserDefaults with distance filter: \(savedConfig.distanceFilter)m")

    let lm = CLLocationManager()
    lm.delegate = self
    lm.allowsBackgroundLocationUpdates = true
    lm.pausesLocationUpdatesAutomatically = false
    // Use HundredMeters for consistency (same as startSLC)
    lm.desiredAccuracy = kCLLocationAccuracyHundredMeters
    lm.distanceFilter = savedConfig.distanceFilter  // Restore distance filter from saved config

    // Re-start monitoring so iOS keeps sending SLC events
    lm.startMonitoringSignificantLocationChanges()
    self.locationManager = lm

    appendLog("📡 SLC monitoring re-registered after wake-up with \(savedConfig.distanceFilter)m filter")
    appendLog("🏃 Pre-loaded config in memory to prevent race conditions during location delivery")
  }

  func isSLCActive() -> Bool {
    return config != nil && locationManager != nil
  }

  func getSLCLogs() -> [String] {
    return logBuffer
  }

  // MARK: CLLocationManagerDelegate

  func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
    guard let config = self.config ?? SLCConfig.load() else {
      appendLog("❌ didUpdateLocations but no config available")
      return
    }

    // If config was nil (e.g. wake-up race), cache it
    if self.config == nil { self.config = config }

    // Filter locations by accuracy and recency before sending
    let validLocations = locations.filter { location in
      // Only use recent locations (last 30 seconds)
      let age = -location.timestamp.timeIntervalSinceNow
      let isRecent = age < 30
      
      // Only use accurate locations (±1000m max horizontal accuracy)
      let isAccurate = location.horizontalAccuracy > 0 && location.horizontalAccuracy <= minAccuracyThreshold
      
      return isRecent && isAccurate
    }
    
    if validLocations.isEmpty {
      appendLog("⚠️ No valid locations (all filtered by accuracy or recency)")
      return
    }
    
    let now = Date().timeIntervalSince1970
    
    for location in validLocations {
      // Implement deduplication: only send if moved > 50m OR > 60 seconds since last send
      let distance = lastSentLocation?.distance(from: location) ?? Double.infinity
      let timeSinceLastSend = now - lastSentTimestamp
      
      let shouldSend = distance > locationDeduplicationThreshold || timeSinceLastSend > 60
      
      if shouldSend {
        let payload = buildPayload(location: location, config: config)
        appendLog("📍 SLC location: \(location.coordinate.latitude),\(location.coordinate.longitude) " +
                  "speed=\(location.speed) accuracy=\(location.horizontalAccuracy)m")
        
        if distance != Double.infinity {
          appendLog("📏 Distance from last: \(Int(distance))m (threshold: \(Int(locationDeduplicationThreshold))m)")
        }
        
        sendToServer(payload: payload, config: config)
        lastSentLocation = location
        lastSentTimestamp = now
      } else {
        appendLog("↩️ Skipped duplicate location (distance: \(Int(distance))m, time: \(Int(timeSinceLastSend))s)")
      }
    }
  }

  func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
    appendLog("❌ CLLocationManager error: \(error.localizedDescription)")
  }

  func locationManager(_ manager: CLLocationManager, didChangeAuthorization status: CLAuthorizationStatus) {
    switch status {
    case .authorizedAlways:
      appendLog("✅ Authorization: Always — SLC will survive force-kill")
      manager.startMonitoringSignificantLocationChanges()
    case .authorizedWhenInUse:
      appendLog("⚠️ Authorization: WhenInUse — SLC will NOT survive force-kill")
    case .denied, .restricted:
      appendLog("❌ Authorization denied/restricted — SLC cannot work")
    case .notDetermined:
      appendLog("⏳ Authorization: not determined")
    @unknown default:
      appendLog("❓ Authorization: unknown status \(status.rawValue)")
    }
  }

  // MARK: Payload Builder

  private func buildPayload(location: CLLocation, config: SLCConfig) -> [String: Any] {
    let rawDeviceId = config.deviceId.isEmpty ? UIDevice.current.uniqueDeviceID : config.deviceId
    return [
      "deviceId": rawDeviceId,
      "timestamp": Int(location.timestamp.timeIntervalSince1970 * 1000),
      "lat": location.coordinate.latitude,
      "lng": location.coordinate.longitude,
      "speed": max(0, location.speed),
      "heading": max(0, location.course),
      "altitude": location.altitude,
      "accuracy": location.horizontalAccuracy,
      "vehicleId": config.vehicleId ?? "",
      "userId": config.userId ?? "",
      "status": "slc_background"
    ]
  }

  // MARK: Background Upload via URLSession

  /// Sends GPS payload to the server using a **background** URLSession.
  /// This is critical: even if iOS suspends the process 10 seconds after
  /// the SLC wake-up, the background URLSession will continue the upload
  /// independently in a separate system daemon process.
  private func sendToServer(payload: [String: Any], config: SLCConfig) {
    guard var urlComponents = URLComponents(string: config.apiEndpoint) else {
      appendLog("❌ Invalid API endpoint: \(config.apiEndpoint)")
      return
    }

    // Add apiKey as a URL Query Parameter to ensure it is included 
    var queryItems = urlComponents.queryItems ?? []
    queryItems.append(URLQueryItem(name: "apikey", value: config.apiKey))
    urlComponents.queryItems = queryItems

    guard let url = urlComponents.url else {
      appendLog("❌ Failed to construct URL with apikey")
      return
    }

    guard let jsonData = try? JSONSerialization.data(withJSONObject: payload) else {
      appendLog("❌ Failed to serialize payload")
      return
    }
    
    // Log the actual payload being sent
    if let jsonString = String(data: jsonData, encoding: .utf8) {
      appendLog("📤 Sending payload: \(jsonString)")
    }

    // Write JSON to a temp file (background upload requires a file, not Data)
    let tempDir = FileManager.default.temporaryDirectory
    let fileName = "slc_\(UUID().uuidString).json"
    let fileURL = tempDir.appendingPathComponent(fileName)

    do {
      try jsonData.write(to: fileURL)
    } catch {
      appendLog("❌ Failed to write temp file: \(error)")
      return
    }

    var request = URLRequest(url: url)
    request.httpMethod = "POST"
    request.setValue("application/json", forHTTPHeaderField: "Content-Type")
    request.setValue("text/plain", forHTTPHeaderField: "Accept")
    request.setValue(config.apiKey, forHTTPHeaderField: "x-api-key")

    let task = bgURLSession.uploadTask(with: request, fromFile: fileURL)
    task.taskDescription = fileName // for cleanup later
    task.resume()

    appendLog("📤 Upload Task [\(task.taskIdentifier)] started to \(config.apiEndpoint)")
  }

  // MARK: URLSessionTaskDelegate

  func urlSession(_ session: URLSession, task: URLSessionTask, didCompleteWithError error: Error?) {
    let fileName = task.taskDescription ?? "unknown_file.json"
    
    if let error = error {
      appendLog("❌ Upload Task [\(task.taskIdentifier)] Failed: \(error.localizedDescription)")
    } else if let response = task.response as? HTTPURLResponse {
      let statusIcon = (200...299).contains(response.statusCode) ? "✅" : "⚠️"
      appendLog("\(statusIcon) Upload Task [\(task.taskIdentifier)] Finished. HTTP Status: \(response.statusCode)")
      
      // Cleanup temp file on success
      let tempDir = FileManager.default.temporaryDirectory
      let fileURL = tempDir.appendingPathComponent(fileName)
      try? FileManager.default.removeItem(at: fileURL)
    }
  }

  // MARK: Logging

  private func appendLog(_ message: String) {
    let timestamp = ISO8601DateFormatter().string(from: Date())
    let line = "[\(timestamp)] \(message)"
    NSLog("[SLC] \(message)")
    logBuffer.append(line)
    if logBuffer.count > logBufferMax {
      logBuffer.removeFirst()
    }

    // Also persist last 50 log lines to UserDefaults for post-mortem debugging
    let persistKey = "vietmap_slc_logs"
    let persistLines = Array(logBuffer.suffix(50))
    UserDefaults.standard.set(persistLines, forKey: persistKey)
  }
}

// MARK: - Device ID Helper
extension UIDevice {
  var uniqueDeviceID: String {
    return identifierForVendor?.uuidString ?? "unknown_device_id"
  }
}
