import Flutter
import UIKit

@main
@objc class AppDelegate: FlutterAppDelegate {

  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    GeneratedPluginRegistrant.register(with: self)

    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }

  // Always present notifications as banner+sound when app is in foreground.
  // This handles BOTH SDK-direct notifications (UNUserNotificationCenter.add)
  // and flutter_local_notifications notifications.
  // NOTE: intentionally not calling super — FlutterAppDelegate's forwarding
  // to plugins relies on the same completionHandler, and FLN returns early
  // (without calling completionHandler) for non-FLN notifications, causing
  // the banner to never appear. FLN tap handling is via didReceiveNotificationResponse
  // which is unaffected by this override.
  override func userNotificationCenter(
    _ center: UNUserNotificationCenter,
    willPresent notification: UNNotification,
    withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void
  ) {
    completionHandler([.banner, .sound, .badge])
  }
}
