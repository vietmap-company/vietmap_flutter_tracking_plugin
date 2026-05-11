import Flutter
import UIKit
import UserNotifications

@main
@objc class AppDelegate: FlutterAppDelegate {

  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    // Set AppDelegate as UNUserNotificationCenter delegate BEFORE registering
    // plugins. This prevents flutter_local_notifications from replacing it
    // with its own delegate during initialize(), which would bypass our
    // willPresent override and suppress foreground banners.
    UNUserNotificationCenter.current().delegate = self

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
    let id = notification.request.identifier
    let title = notification.request.content.title
    print("[AppDelegate] willPresent fired — id=\(id) title=\(title)")
    completionHandler([.banner, .sound, .badge])
  }
}
