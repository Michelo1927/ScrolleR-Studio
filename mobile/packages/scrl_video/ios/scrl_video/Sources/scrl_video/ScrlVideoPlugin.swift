import Flutter
import UIKit

/// scrl_video su iOS: la parte con AVFoundation arriva nella Fase 9 (piano §12).
/// Fino ad allora ogni chiamata risponde «non disponibile» e l'app lo mostra all'utente.
public class ScrlVideoPlugin: NSObject, FlutterPlugin {
  public static func register(with registrar: FlutterPluginRegistrar) {
    let channel = FlutterMethodChannel(name: "scrl_video", binaryMessenger: registrar.messenger())
    registrar.addMethodCallDelegate(ScrlVideoPlugin(), channel: channel)
  }

  public func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
    result(FlutterMethodNotImplemented)
  }
}
