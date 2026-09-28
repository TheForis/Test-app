import Flutter
import UIKit

@main
@objc class AppDelegate: FlutterAppDelegate, FlutterImplicitEngineDelegate {
  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }

  func didInitializeImplicitFlutterEngine(_ engineBridge: FlutterImplicitEngineBridge) {
    GeneratedPluginRegistrant.register(with: engineBridge.pluginRegistry)
    if let registrar = engineBridge.pluginRegistry.registrar(forPlugin: "BurrowStorage") {
      registerStorageChannel(registrar.messenger())
    }
  }

  /// Total and free bytes of the device, for the storage overview on the home screen.
  private func registerStorageChannel(_ messenger: FlutterBinaryMessenger) {
    let channel = FlutterMethodChannel(name: "burrow/storage", binaryMessenger: messenger)
    channel.setMethodCallHandler { call, result in
      guard call.method == "space" else {
        result(FlutterMethodNotImplemented)
        return
      }
      do {
        let values = try URL(fileURLWithPath: NSHomeDirectory()).resourceValues(forKeys: [
          .volumeTotalCapacityKey, .volumeAvailableCapacityForImportantUsageKey,
        ])
        guard let total = values.volumeTotalCapacity,
          let free = values.volumeAvailableCapacityForImportantUsage
        else {
          result(FlutterError(code: "unavailable", message: nil, details: nil))
          return
        }
        result(["total": Int64(total), "free": free])
      } catch {
        result(FlutterError(code: "unavailable", message: error.localizedDescription, details: nil))
      }
    }
  }
}
