import Flutter
import UIKit

@main
@objc class AppDelegate: FlutterAppDelegate {
  private var migrationChannel: FlutterMethodChannel?

  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    GeneratedPluginRegistrant.register(with: self)
    let launched = super.application(application, didFinishLaunchingWithOptions: launchOptions)
    if let controller = window?.rootViewController as? FlutterViewController {
      migrationChannel = FlutterMethodChannel(name: "eduweb/migration", binaryMessenger: controller.binaryMessenger)
      migrationChannel?.setMethodCallHandler { call, result in
        guard call.method == "readLegacyWebsites" else { result(FlutterMethodNotImplemented); return }
        let defaults = UserDefaults.standard
        guard let data = defaults.data(forKey: "web-services.v1"),
              let json = String(data: data, encoding: .utf8) else { result(nil); return }
        // Només dades de pestanyes. No es llig ni es registra cap credencial web.
        var legacy: [String: Any] = ["websites": json]
        if let selected = defaults.string(forKey: "selected-web-service") { legacy["selectedId"] = selected }
        result(legacy)
      }
    }
    return launched
  }
}
