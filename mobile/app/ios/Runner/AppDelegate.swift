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
    // Canale dei file che arrivano da altre app («Apri con ScrolleR Studio», piano §6, Fase 9)
    ArrivoFile.shared.collega(engineBridge.applicationRegistrar.messenger())
  }
}

/// File ricevuti da altre app («Apri con», «Copia in ScrolleR Studio»). Un file di un'altra app non si può tenere:
/// si copia nella cartella temporanea dell'app e a Dart si consegna l'elenco delle copie, una volta sola; Dart le
/// toglie dopo l'uso. Stesso canale e stessi campi di `MainActivity.kt` su Android.
final class ArrivoFile {
  static let shared = ArrivoFile()

  private var canale: FlutterMethodChannel?
  private var inAttesa: [[String: String]] = []
  private var dartPronto = false
  private let coda = DispatchQueue(label: "io.github.michelo1927.scrollerstudio.arrivo")

  func collega(_ messenger: FlutterBinaryMessenger) {
    let c = FlutterMethodChannel(
      name: "io.github.michelo1927.scrollerstudio/ricevuti",
      binaryMessenger: messenger)
    c.setMethodCallHandler { [weak self] call, result in
      guard let self = self, call.method == "iniziali" else {
        result(FlutterMethodNotImplemented)
        return
      }
      self.coda.async {
        self.dartPronto = true
        let l = self.inAttesa
        self.inAttesa = []
        DispatchQueue.main.async { result(l) }
      }
    }
    canale = c
  }

  func ricevi(_ urls: [URL]) {
    if urls.isEmpty { return }
    coda.async {
      var lista: [[String: String]] = []
      for url in urls {
        if let m = self.copia(url) { lista.append(m) }
      }
      if lista.isEmpty { return }
      if self.dartPronto {
        DispatchQueue.main.async { self.canale?.invokeMethod("nuovi", arguments: lista) }
      } else {
        self.inAttesa.append(contentsOf: lista)
      }
    }
  }

  private func copia(_ url: URL) -> [String: String]? {
    let accede = url.startAccessingSecurityScopedResource()
    defer { if accede { url.stopAccessingSecurityScopedResource() } }
    let fm = FileManager.default
    let dir = fm.temporaryDirectory
      .appendingPathComponent("ricevuti", isDirectory: true)
      .appendingPathComponent(UUID().uuidString, isDirectory: true)
    do {
      try fm.createDirectory(at: dir, withIntermediateDirectories: true)
      let nome = url.lastPathComponent
      let dest = dir.appendingPathComponent(nome)
      try fm.copyItem(at: url, to: dest)
      var m = ["percorso": dest.path, "nome": nome]
      if let t = mime(url.pathExtension.lowercased()) { m["mime"] = t }
      return m
    } catch {
      return nil
    }
  }

  private func mime(_ estensione: String) -> String? {
    switch estensione {
    case "zip": return "application/zip"
    case "jpg", "jpeg": return "image/jpeg"
    case "png": return "image/png"
    case "heic", "heif": return "image/heic"
    case "webp": return "image/webp"
    case "mp4", "m4v": return "video/mp4"
    case "mov": return "video/quicktime"
    default: return nil
    }
  }
}
