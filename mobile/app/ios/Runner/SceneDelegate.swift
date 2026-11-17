import Flutter
import UIKit

class SceneDelegate: FlutterSceneDelegate {
  // File aperti con «Apri con» quando l'app si avvia (la scena nasce con gli URL)...
  override func scene(
    _ scene: UIScene,
    willConnectTo session: UISceneSession,
    options connectionOptions: UIScene.ConnectionOptions
  ) {
    super.scene(scene, willConnectTo: session, options: connectionOptions)
    ArrivoFile.shared.ricevi(connectionOptions.urlContexts.map { $0.url })
  }

  // ...e quando l'app è già aperta
  override func scene(_ scene: UIScene, openURLContexts URLContexts: Set<UIOpenURLContext>) {
    super.scene(scene, openURLContexts: URLContexts)
    ArrivoFile.shared.ricevi(URLContexts.map { $0.url })
  }
}
