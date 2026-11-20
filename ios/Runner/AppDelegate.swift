import AVFoundation
import Flutter
import UIKit

@main
@objc class AppDelegate: FlutterAppDelegate, FlutterImplicitEngineDelegate {
  private var audioPlayers: [String: AVAudioPlayer] = [:]
  private var pluginRegistrar: FlutterPluginRegistrar?

  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    try? AVAudioSession.sharedInstance().setCategory(.ambient, options: [.mixWithOthers])
    try? AVAudioSession.sharedInstance().setActive(true)
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }

  func didInitializeImplicitFlutterEngine(_ engineBridge: FlutterImplicitEngineBridge) {
    GeneratedPluginRegistrant.register(with: engineBridge.pluginRegistry)

    guard let registrar = engineBridge.pluginRegistry.registrar(forPlugin: "FlightsPlatformPlugin") else {
      return
    }
    self.pluginRegistrar = registrar

    let channel = FlutterMethodChannel(
      name: "me.guslipkin.flights/platform",
      binaryMessenger: registrar.messenger()
    )

    preloadAudioPlayers(registrar: registrar)

    channel.setMethodCallHandler { [weak self] call, result in
      guard let self = self else {
        result(nil)
        return
      }
      switch call.method {
      case "playSound":
        let args = call.arguments as? [String: Any]
        let name = (args?["name"] as? String) ?? "jet_hop"
        self.playSound(name: name)
        result(nil)

      case "shareText":
        let args = call.arguments as? [String: Any]
        let text = (args?["text"] as? String) ?? ""
        self.shareText(text: text)
        result(nil)

      case "readSave":
        result(self.readSaveFile())

      case "writeSave":
        let args = call.arguments as? [String: Any]
        let content = (args?["content"] as? String) ?? ""
        result(self.writeSaveFile(content: content))

      default:
        result(FlutterMethodNotImplemented)
      }
    }
  }

  private func preloadAudioPlayers(registrar: FlutterPluginRegistrar) {
    for name in ["jet_hop", "jet_back", "jet_longer", "jet_victory"] {
      let key = registrar.lookupKey(forAsset: "assets/audio/\(name).wav")
      if let path = Bundle.main.path(forResource: key, ofType: nil) {
        let url = URL(fileURLWithPath: path)
        if let player = try? AVAudioPlayer(contentsOf: url) {
          player.prepareToPlay()
          audioPlayers[name] = player
        }
      }
    }
  }

  private func playSound(name: String) {
    if audioPlayers[name] == nil, let registrar = pluginRegistrar {
      let key = registrar.lookupKey(forAsset: "assets/audio/\(name).wav")
      if let path = Bundle.main.path(forResource: key, ofType: nil) {
        let url = URL(fileURLWithPath: path)
        if let player = try? AVAudioPlayer(contentsOf: url) {
          player.prepareToPlay()
          audioPlayers[name] = player
        }
      }
    }
    guard let player = audioPlayers[name] else { return }
    let volume: Float
    switch name {
    case "jet_victory": volume = 0.85
    case "jet_longer": volume = 0.78
    case "jet_back": volume = 0.70
    default: volume = 0.75
    }
    player.volume = volume
    player.currentTime = 0
    player.play()
  }

  private func shareText(text: String) {
    DispatchQueue.main.async {
      guard let rootVC = self.activeRootViewController() else { return }
      let activityVC = UIActivityViewController(activityItems: [text], applicationActivities: nil)
      if let popover = activityVC.popoverPresentationController {
        popover.sourceView = rootVC.view
        popover.sourceRect = CGRect(
          x: rootVC.view.bounds.midX,
          y: rootVC.view.bounds.midY,
          width: 0,
          height: 0
        )
        popover.permittedArrowDirections = []
      }
      rootVC.present(activityVC, animated: true)
    }
  }

  private func activeRootViewController() -> UIViewController? {
    for scene in UIApplication.shared.connectedScenes {
      if let windowScene = scene as? UIWindowScene {
        for window in windowScene.windows where window.isKeyWindow {
          var top = window.rootViewController
          while let presented = top?.presentedViewController {
            top = presented
          }
          return top
        }
        if let firstRoot = windowScene.windows.first?.rootViewController {
          return firstRoot
        }
      }
    }
    return nil
  }

  private func saveFileURL() -> URL? {
    guard let dir = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first else {
      return nil
    }
    try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
    return dir.appendingPathComponent("saves.json")
  }

  private func readSaveFile() -> String? {
    guard let url = saveFileURL(), FileManager.default.fileExists(atPath: url.path) else {
      return nil
    }
    return try? String(contentsOf: url, encoding: .utf8)
  }

  private func writeSaveFile(content: String) -> Bool {
    guard let url = saveFileURL() else { return false }
    do {
      try content.write(to: url, atomically: true, encoding: .utf8)
      return true
    } catch {
      return false
    }
  }
}
