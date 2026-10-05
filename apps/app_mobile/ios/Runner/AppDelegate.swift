import CoreMotion
import Flutter
import PDFKit
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
      let timezoneChannel = FlutterMethodChannel(
        name: "stk_haven/timezone",
        binaryMessenger: controller.binaryMessenger
      )
      timezoneChannel.setMethodCallHandler { call, result in
        guard call.method == "getTimeZoneName" else {
          result(FlutterMethodNotImplemented)
          return
        }
        result(TimeZone.current.identifier)
      }

      let channel = FlutterMethodChannel(
        name: "stk_haven/daily_steps",
        binaryMessenger: controller.binaryMessenger
      )

      let pdfChannel = FlutterMethodChannel(
        name: "stk_haven/pdf_reader",
        binaryMessenger: controller.binaryMessenger
      )

      pdfChannel.setMethodCallHandler { call, result in
        guard call.method == "openPdf",
              let args = call.arguments as? [String: Any],
              let path = args["path"] as? String else {
          result(FlutterMethodNotImplemented)
          return
        }

        let fileURL = URL(fileURLWithPath: path)
        guard FileManager.default.fileExists(atPath: fileURL.path) else {
          result(
            FlutterError(
              code: "pdf_missing",
              message: "The PDF file is no longer available.",
              details: nil
            )
          )
          return
        }

        let title = args["title"] as? String ?? fileURL.lastPathComponent
        let initialPage = args["initialPage"] as? Int ?? 1
        let reader = StkPdfReaderViewController(
          fileURL: fileURL,
          titleText: title,
          initialPage: initialPage
        ) { payload in
          result(payload)
        }
        let navigation = UINavigationController(rootViewController: reader)
        navigation.modalPresentationStyle = .fullScreen
        controller.present(navigation, animated: true)
      }

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


private final class StkPdfReaderViewController: UIViewController {
  private let fileURL: URL
  private let titleText: String
  private let initialPage: Int
  private let onClose: ([String: Int]) -> Void
  private let pdfView = PDFView()
  private var didComplete = false

  init(
    fileURL: URL,
    titleText: String,
    initialPage: Int,
    onClose: @escaping ([String: Int]) -> Void
  ) {
    self.fileURL = fileURL
    self.titleText = titleText
    self.initialPage = max(1, initialPage)
    self.onClose = onClose
    super.init(nibName: nil, bundle: nil)
    isModalInPresentation = true
  }

  required init?(coder: NSCoder) {
    fatalError("init(coder:) has not been implemented")
  }

  override func viewDidLoad() {
    super.viewDidLoad()
    view.backgroundColor = .systemBackground
    title = titleText
    navigationItem.rightBarButtonItem = UIBarButtonItem(
      barButtonSystemItem: .done,
      target: self,
      action: #selector(closeReader)
    )

    pdfView.translatesAutoresizingMaskIntoConstraints = false
    pdfView.autoScales = true
    pdfView.displayMode = .singlePageContinuous
    pdfView.displayDirection = .vertical
    view.addSubview(pdfView)

    NSLayoutConstraint.activate([
      pdfView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
      pdfView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
      pdfView.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor),
      pdfView.bottomAnchor.constraint(equalTo: view.bottomAnchor),
    ])

    guard let document = PDFDocument(url: fileURL) else {
      complete(currentPage: initialPage, totalPages: 0)
      dismiss(animated: true)
      return
    }

    pdfView.document = document
    let pageIndex = min(
      max(initialPage - 1, 0),
      max(document.pageCount - 1, 0)
    )
    if let page = document.page(at: pageIndex) {
      pdfView.go(to: page)
    }
  }

  @objc private func closeReader() {
    let totalPages = pdfView.document?.pageCount ?? 0
    var currentPage = min(initialPage, max(totalPages, 1))
    if let document = pdfView.document,
       let page = pdfView.currentPage {
      let index = document.index(for: page)
      if index >= 0 {
        currentPage = index + 1
      }
    }
    complete(currentPage: currentPage, totalPages: totalPages)
    dismiss(animated: true)
  }

  private func complete(currentPage: Int, totalPages: Int) {
    guard !didComplete else { return }
    didComplete = true
    onClose([
      "currentPage": currentPage,
      "totalPages": totalPages,
    ])
  }
}
