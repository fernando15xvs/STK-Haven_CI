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
        case "requestAccess":
          self.requestStepAccess(result: result)
        case "requestPermission":
          self.requestStepAccess { payload in
            guard let map = payload as? [String: Any] else {
              result(false)
              return
            }
            result(map["status"] as? String == "authorized")
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

  private func requestStepAccess(result: @escaping FlutterResult) {
    guard CMPedometer.isStepCountingAvailable() else {
      result([
        "status": "unavailable",
        "message": "Step counting is not available on this device.",
      ])
      return
    }

    let currentStatus = stepAuthorizationStatus()
    if currentStatus == "denied" || currentStatus == "restricted" {
      result(["status": currentStatus])
      return
    }

    // Querying the pedometer is what triggers the system Motion & Fitness
    // authorization prompt the first time. Resolve the status again after the
    // query so Flutter can distinguish denial, restriction and sensor errors.
    readTodaySteps { [weak self] steps, error in
      guard let self else {
        result(["status": "query_failed"])
        return
      }

      let resolvedStatus = self.stepAuthorizationStatus()
      if let steps {
        result([
          "status": "authorized",
          "steps": steps,
        ])
        return
      }

      if resolvedStatus == "denied" || resolvedStatus == "restricted" {
        result(["status": resolvedStatus])
        return
      }

      result([
        "status": resolvedStatus == "not_determined"
          ? "query_failed"
          : resolvedStatus,
        "message": error?.localizedDescription ??
          "Pedometer query did not return data.",
      ])
    }
  }

  private func stepAuthorizationStatus() -> String {
    switch CMPedometer.authorizationStatus() {
    case .authorized:
      return "authorized"
    case .denied:
      return "denied"
    case .restricted:
      return "restricted"
    case .notDetermined:
      return "not_determined"
    @unknown default:
      return "query_failed"
    }
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
