import UIKit
import Flutter
import UserNotifications

@main
@objc class AppDelegate: FlutterAppDelegate {
  private var deviceToken: String?
  private var pendingDeviceTokenResults: [FlutterResult] = []

  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
    ) -> Bool {
    GeneratedPluginRegistrant.register(with: self)
    UNUserNotificationCenter.current().delegate = self
    if let controller = window?.rootViewController as? FlutterViewController {
      let channel = FlutterMethodChannel(
        name: "work_app/push",
        binaryMessenger: controller.binaryMessenger
      )
      channel.setMethodCallHandler { [weak self] call, result in
        guard call.method == "getDevicePushToken" else {
          result(FlutterMethodNotImplemented)
          return
        }
        self?.getDevicePushToken(application: application, result: result)
      }
    }
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }

  private func getDevicePushToken(application: UIApplication, result: @escaping FlutterResult) {
    if let deviceToken = deviceToken {
      result(deviceToken)
      return
    }
    pendingDeviceTokenResults.append(result)
    UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .badge, .sound]) { granted, error in
      DispatchQueue.main.async {
        if let error = error {
          self.finishPendingDeviceTokenResults(
            FlutterError(code: "notification_permission_failed", message: error.localizedDescription, details: nil)
          )
          return
        }
        if !granted {
          self.finishPendingDeviceTokenResults(nil)
          return
        }
        application.registerForRemoteNotifications()
      }
    }
  }

  override func application(
    _ application: UIApplication,
    didRegisterForRemoteNotificationsWithDeviceToken deviceToken: Data
  ) {
    let token = deviceToken.map { String(format: "%02.2hhx", $0) }.joined()
    self.deviceToken = token
    finishPendingDeviceTokenResults(token)
  }

  override func application(
    _ application: UIApplication,
    didFailToRegisterForRemoteNotificationsWithError error: Error
  ) {
    finishPendingDeviceTokenResults(
      FlutterError(code: "apns_registration_failed", message: error.localizedDescription, details: nil)
    )
  }

  override func userNotificationCenter(
    _ center: UNUserNotificationCenter,
    willPresent notification: UNNotification,
    withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void
  ) {
    if #available(iOS 14.0, *) {
      completionHandler([.banner, .sound, .badge])
    } else {
      completionHandler([.alert, .sound, .badge])
    }
  }

  private func finishPendingDeviceTokenResults(_ value: Any?) {
    let results = pendingDeviceTokenResults
    pendingDeviceTokenResults.removeAll()
    results.forEach { $0(value) }
  }
}
