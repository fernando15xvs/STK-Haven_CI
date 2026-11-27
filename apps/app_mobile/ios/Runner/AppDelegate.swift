import AudioToolbox
import CoreMotion
import Flutter
import PDFKit
import LocalAuthentication
import UIKit
import UserNotifications
import WidgetKit

@main
@objc class AppDelegate: FlutterAppDelegate {
  private let pedometer = CMPedometer()
  private var restToneSoundId: SystemSoundID = 0

  // iOS may suspend the Flutter isolate before a rest finishes. Restore a
  // consistent Live Activity state as soon as the person reopens STK Haven.
  // This does not acquire audio focus or launch any background audio service.
  override func applicationDidBecomeActive(_ application: UIApplication) {
    super.applicationDidBecomeActive(application)
    if #available(iOS 16.2, *) {
      Task { await StkRestLiveActivityBridge.endExpired() }
    }
  }

  deinit {
    if restToneSoundId != 0 {
      AudioServicesDisposeSystemSoundID(restToneSoundId)
    }
  }

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

    // Only registered for an explicitly enabled, static internal GPU review.
    // Nothing in the exercise catalogue creates this platform view.
    if let registrar = self.registrar(forPlugin: "StkAnatomyGpuReview") {
      registrar.register(
        StkAnatomyGpuReviewFactory(messenger: registrar.messenger()),
        withId: "stk_haven/anatomy_gpu_static"
      )
    }
    if let registrar = self.registrar(forPlugin: "StkAnatomyGpuSkinned") {
      registrar.register(
        StkAnatomyGpuSkinnedFactory(messenger: registrar.messenger()),
        withId: "stk_haven/anatomy_gpu_skinning"
      )
    }

    if let controller = window?.rootViewController as? FlutterViewController {
      let toneChannel = FlutterMethodChannel(
        name: "stk_haven/rest_tone",
        binaryMessenger: controller.binaryMessenger
      )
      toneChannel.setMethodCallHandler { [weak self] call, result in
        guard call.method == "play" else {
          result(FlutterMethodNotImplemented)
          return
        }
        guard let self,
              let url = Bundle.main.url(
                forResource: "stk_rest_complete", withExtension: "wav"
              ) else {
          result(false)
          return
        }
        // This is a brief system cue, not a second music player. AVAudioPlayer
        // with the app's nonmixable playback category can interrupt another
        // app (e.g. YouTube Music) when the rest ends. System Sound Services
        // does not activate/reconfigure the app's AVAudioSession or claim
        // music focus; it respects the device's system sound behavior.
        if self.restToneSoundId == 0 {
          var soundId: SystemSoundID = 0
          let status = AudioServicesCreateSystemSoundID(url as CFURL, &soundId)
          guard status == noErr else {
            result(false)
            return
          }
          self.restToneSoundId = soundId
        }
        AudioServicesPlaySystemSound(self.restToneSoundId)
        result(true)
      }

      let restActivityChannel = FlutterMethodChannel(
        name: "stk_haven/rest_activity",
        binaryMessenger: controller.binaryMessenger
      )
      restActivityChannel.setMethodCallHandler { call, result in
        if #available(iOS 16.2, *) {
          switch call.method {
          case "update":
            guard let args = call.arguments as? [String: Any],
                  let sessionId = args["sessionId"] as? String,
                  let epoch = args["endEpochMillis"] as? NSNumber else {
              result(false)
              return
            }
            let endTime = Date(timeIntervalSince1970: epoch.doubleValue / 1000)
            Task {
              result(await StkRestLiveActivityBridge.update(
                sessionId: sessionId, endTime: endTime))
            }
          case "end":
            Task {
              await StkRestLiveActivityBridge.end()
              result(true)
            }
          default:
            result(FlutterMethodNotImplemented)
          }
        } else {
          // Pre-16.2 iPhones retain the in-app timer and final local alert.
          result(false)
        }
      }

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

      let verseWidgetChannel = FlutterMethodChannel(
        name: "stk_haven/verse_widget",
        binaryMessenger: controller.binaryMessenger
      )
      verseWidgetChannel.setMethodCallHandler { call, result in
        if call.method == "diagnostics" {
          let ext = Bundle.main.builtInPlugInsURL?
            .appendingPathComponent("StkVerseWidget.appex")
          let bundled = ext.map { FileManager.default.fileExists(atPath: $0.path) }
            ?? false
          let group = FileManager.default.containerURL(
            forSecurityApplicationGroupIdentifier: "group.com.FernandoSac.gymTracker"
          ) != nil
          result(["extensionBundled": bundled, "appGroupAvailable": group])
          return
        }
        guard let shared = UserDefaults(
          suiteName: "group.com.FernandoSac.gymTracker"
        ) else {
          result(FlutterError(
            code: "app_group_unavailable",
            message: "Enable the same App Group for Runner and StkVerseWidget.",
            details: nil
          ))
          return
        }
        switch call.method {
        case "publish":
          guard let args = call.arguments as? [String: String],
                let text = args["text"], !text.isEmpty,
                let reference = args["reference"], !reference.isEmpty else {
            result(FlutterError(
              code: "invalid_verse", message: "Missing verse data.", details: nil
            ))
            return
          }
          shared.set(true, forKey: "stkVerseWidgetEnabled")
          shared.set(String(text.prefix(1200)), forKey: "stkVerseText")
          shared.set(String(reference.prefix(120)), forKey: "stkVerseReference")
          shared.set(args["date"] ?? "", forKey: "stkVerseDate")
          WidgetCenter.shared.reloadTimelines(ofKind: "StkVerseLockWidget")
          result(true)
        case "clear":
          shared.set(false, forKey: "stkVerseWidgetEnabled")
          shared.removeObject(forKey: "stkVerseText")
          shared.removeObject(forKey: "stkVerseReference")
          shared.removeObject(forKey: "stkVerseDate")
          WidgetCenter.shared.reloadTimelines(ofKind: "StkVerseLockWidget")
          result(true)
        default:
          result(FlutterMethodNotImplemented)
        }
      }

      let channel = FlutterMethodChannel(
        name: "stk_haven/daily_steps",
        binaryMessenger: controller.binaryMessenger
      )

      let journalChannel = FlutterMethodChannel(name: "stk_haven/private_journal", binaryMessenger: controller.binaryMessenger)
      journalChannel.setMethodCallHandler { call, result in
        if call.method == "authenticate" {
          let auth = LAContext()
          var error: NSError?
          guard auth.canEvaluatePolicy(.deviceOwnerAuthentication, error: &error) else {
            result(false); return
          }
          auth.evaluatePolicy(.deviceOwnerAuthentication, localizedReason: "Abrir diario privado") { success, _ in
            DispatchQueue.main.async { result(success) }
          }
          return
        }
        do {
          let manager = FileManager.default
          let root = try manager.url(for: .applicationSupportDirectory, in: .userDomainMask, appropriateFor: nil, create: true)
          var dir = root.appendingPathComponent("stk_private_journal", isDirectory: true)
          try manager.createDirectory(at: dir, withIntermediateDirectories: true)
          var values = URLResourceValues()
          values.isExcludedFromBackup = true
          try dir.setResourceValues(values)
          let file = dir.appendingPathComponent("journal.json")
          switch call.method {
          case "read":
            if manager.fileExists(atPath: file.path) {
              result(try String(contentsOf: file, encoding: .utf8))
            } else {
              result("[]")
            }
          case "write":
            guard let args = call.arguments as? [String: Any], let data = args["data"] as? String else {
              result(FlutterError(code: "journal_input", message: "Datos no válidos", details: nil)); return
            }
            try Data(data.utf8).write(to: file, options: [.atomic, .completeFileProtection])
            result(true)
          default: result(FlutterMethodNotImplemented)
          }
        } catch {
          result(FlutterError(code: "journal_storage", message: "No se pudo acceder al diario privado", details: nil))
        }
      }

      let pdfChannel = FlutterMethodChannel(
        name: "stk_haven/pdf_reader",
        binaryMessenger: controller.binaryMessenger
      )

      pdfChannel.setMethodCallHandler { call, result in
        if call.method == "searchText",
           let args = call.arguments as? [String: Any],
           let path = args["path"] as? String,
           let query = args["query"] as? String {
          DispatchQueue.global(qos: .userInitiated).async {
            guard let document = PDFDocument(url: URL(fileURLWithPath: path)), !document.isLocked else {
              DispatchQueue.main.async { result(FlutterError(code: "pdf_search_unavailable", message: "Búsqueda no disponible", details: nil)) }
              return
            }
            let pages = Set(document.findString(String(query.prefix(200)), withOptions: .caseInsensitive)
              .flatMap { $0.pages }.map { document.index(for: $0) + 1 }.filter { $0 > 0 })
            DispatchQueue.main.async { result(Array(pages.sorted().prefix(200))) }
          }
          return
        }
        if call.method == "renderPage",
           let args = call.arguments as? [String: Any],
           let path = args["path"] as? String {
          let requested = args["page"] as? Int ?? 1
          let thumbnail = args["thumbnail"] as? Bool ?? false
          let highlightTerms = (args["highlightTerms"] as? [String] ?? []).prefix(20)
          DispatchQueue.global(qos: .userInitiated).async {
            guard let document = PDFDocument(url: URL(fileURLWithPath: path)),
                  document.pageCount > 0,
                  !document.isLocked else {
              DispatchQueue.main.async { result(FlutterError(code: "pdf_unreadable", message: "No se pudo abrir el PDF", details: nil)) }
              return
            }
            let index = min(max(requested - 1, 0), document.pageCount - 1)
            guard let page = document.page(at: index) else {
              DispatchQueue.main.async { result(FlutterError(code: "pdf_page", message: "Página no disponible", details: nil)) }
              return
            }
            let bounds = page.bounds(for: .cropBox)
            guard bounds.width > 0, bounds.height > 0 else {
              DispatchQueue.main.async { result(FlutterError(code: "pdf_page", message: "Página no válida", details: nil)) }
              return
            }
            let scale = thumbnail ? min(220 / bounds.width, 300 / bounds.height) : min(1600 / bounds.width, 2200 / bounds.height)
            let size = CGSize(width: bounds.width * scale, height: bounds.height * scale)
            for term in highlightTerms where !term.isEmpty {
              for selection in document.findString(String(term.prefix(200)), withOptions: .caseInsensitive) where selection.pages.contains(page) {
                let mark = PDFAnnotation(bounds: selection.bounds(for: page), forType: .highlight, withProperties: nil)
                mark.color = UIColor.yellow.withAlphaComponent(0.45)
                page.addAnnotation(mark)
              }
            }
            let image = page.thumbnail(of: size, for: .cropBox)
            guard let data = image.pngData() else {
              DispatchQueue.main.async { result(FlutterError(code: "pdf_page", message: "Página no disponible", details: nil)) }
              return
            }
            let payload: [String: Any] = ["bytes": FlutterStandardTypedData(bytes: data), "currentPage": index + 1, "totalPages": document.pageCount]
            DispatchQueue.main.async { result(payload) }
          }
          return
        }
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
