import CoreMotion
import Flutter
import UIKit
import UserNotifications

@main
@objc class AppDelegate: FlutterAppDelegate {
  private let pedometer = CMPedometer()

  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    UNUserNotificationCenter.current().delegate =
      self as? UNUserNotificationCenterDelegate
    GeneratedPluginRegistrant.register(with: self)

    let launched = super.application(
      application,
      didFinishLaunchingWithOptions: launchOptions
    )

    if let controller = window?.rootViewController as? FlutterViewController {
      let channel = FlutterMethodChannel(
        name: "stk_haven/daily_steps",
        binaryMessenger: controller.binaryMessenger
      )

      channel.setMethodCallHandler { [weak self] call, result in
        guard let self else {
          result(
            FlutterError(
              code: "unavailable",
              message: "Step service is unavailable.",
              details: nil
            )
          )
          return
        }

        switch call.method {
        case "requestPermission":
          self.readTodaySteps { steps, error in
            if let cmError = error as? CMError,
               cmError.code == .notAuthorized {
              result(false)
            } else {
              result(steps != nil)
            }
          }
        case "getTodaySteps":
          self.readTodaySteps { steps, error in
            if let steps {
              result(steps)
            } else {
              result(
                FlutterError(
                  code: "steps_unavailable",
                  message: error?.localizedDescription ??
                    "Daily steps are unavailable.",
                  details: nil
                )
              )
            }
          }
        default:
          result(FlutterMethodNotImplemented)
        }
      }
    }

    return launched
  }

  private func readTodaySteps(
    completion: @escaping (Int?, Error?) -> Void
  ) {
    guard CMPedometer.isStepCountingAvailable() else {
      completion(nil, nil)
      return
    }

    let start = Calendar.current.startOfDay(for: Date())
    pedometer.queryPedometerData(
      from: start,
      to: Date()
    ) { data, error in
      DispatchQueue.main.async {
        completion(data?.numberOfSteps.intValue, error)
      }
    }
  }
}
