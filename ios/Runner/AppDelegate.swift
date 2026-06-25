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
    let clipboardChannel = FlutterMethodChannel(
      name: "mithka/clipboard",
      binaryMessenger: engineBridge.applicationRegistrar.messenger()
    )
    clipboardChannel.setMethodCallHandler { call, result in
      guard call.method == "readImage" else {
        result(FlutterMethodNotImplemented)
        return
      }
      let pasteboard = UIPasteboard.general
      if let data = pasteboard.data(forPasteboardType: "public.png") {
        result(["mimeType": "image/png", "data": FlutterStandardTypedData(bytes: data)])
        return
      }
      if let data = pasteboard.data(forPasteboardType: "public.jpeg") {
        result(["mimeType": "image/jpeg", "data": FlutterStandardTypedData(bytes: data)])
        return
      }
      if let image = pasteboard.image, let data = image.pngData() {
        result(["mimeType": "image/png", "data": FlutterStandardTypedData(bytes: data)])
        return
      }
      result(nil)
    }
  }
}
