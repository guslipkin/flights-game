import AVFoundation
import Cocoa
import FlutterMacOS

class MainFlutterWindow: NSWindow {
  private var audioPlayers: [String: AVAudioPlayer] = [:]

  override func awakeFromNib() {
    let flutterViewController = FlutterViewController()
    let defaultSize = NSSize(width: 1180, height: 760)
    self.contentViewController = flutterViewController
    // Narrow enough to reach the stacked (portrait) layout, which the app
    // uses whenever the window is taller than it is wide.
    self.minSize = NSSize(width: 380, height: 520)
    self.setContentSize(defaultSize)
    self.center()
    self.title = "Flights"

    RegisterGeneratedPlugins(registry: flutterViewController)
    setupPlatformChannel(controller: flutterViewController)

    super.awakeFromNib()
  }

  private func setupPlatformChannel(controller: FlutterViewController) {
    let channel = FlutterMethodChannel(
      name: "me.guslipkin.flights/platform",
      binaryMessenger: controller.engine.binaryMessenger
    )

    preloadAudioPlayers()

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
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        pasteboard.setString(text, forType: .string)
        if let contentView = self.contentView {
          let picker = NSSharingServicePicker(items: [text])
          let rect = NSRect(
            x: contentView.bounds.midX - 1,
            y: contentView.bounds.midY - 1,
            width: 2,
            height: 2
          )
          picker.show(relativeTo: rect, of: contentView, preferredEdge: .minY)
        }
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

  private func audioFileURL(name: String) -> URL? {
    let relativePath = "Contents/Frameworks/App.framework/Resources/flutter_assets/assets/audio/\(name).wav"
    let url = Bundle.main.bundleURL.appendingPathComponent(relativePath)
    if FileManager.default.fileExists(atPath: url.path) {
      return url
    }
    return nil
  }

  private func preloadAudioPlayers() {
    for name in ["jet_hop", "jet_back", "jet_longer", "jet_victory"] {
      if let url = audioFileURL(name: name),
         let player = try? AVAudioPlayer(contentsOf: url) {
        player.prepareToPlay()
        audioPlayers[name] = player
      }
    }
  }

  private func playSound(name: String) {
    if audioPlayers[name] == nil {
      if let url = audioFileURL(name: name),
         let player = try? AVAudioPlayer(contentsOf: url) {
        player.prepareToPlay()
        audioPlayers[name] = player
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

  private func saveFileURL() -> URL? {
    guard let base = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first else {
      return nil
    }
    let dir = base.appendingPathComponent("me.guslipkin.flights", isDirectory: true)
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
