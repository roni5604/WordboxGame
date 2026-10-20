import Flutter
import UIKit
import UserNotifications

// מחזור חיים של UIScene (חובה מ-Xcode 27 / iOS 27 SDK - בלעדיו האפליקציה
// לא נפתחת). הסצנה מוגדרת ב-Info.plist (UIApplicationSceneManifest), והתוספים
// נרשמים ב-didInitializeImplicitFlutterEngine במקום ב-didFinishLaunching.
@main
@objc class AppDelegate: FlutterAppDelegate, FlutterImplicitEngineDelegate {
  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    // התראות מקומיות (flutter_local_notifications): מאפשר להציג התראה גם
    // כשהאפליקציה פתוחה, ולקבל לחיצות עליה. חייב לקרות לפני סוף ההפעלה.
    UNUserNotificationCenter.current().delegate = self as UNUserNotificationCenterDelegate
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }

  func didInitializeImplicitFlutterEngine(_ engineBridge: FlutterImplicitEngineBridge) {
    GeneratedPluginRegistrant.register(with: engineBridge.pluginRegistry)
  }
}
