import Cocoa
import FlutterMacOS

class MainFlutterWindow: NSWindow, NSWindowDelegate {
  override func awakeFromNib() {
    let flutterViewController = FlutterViewController()
    self.contentViewController = flutterViewController
    self.setContentSize(NSSize(width: 1440, height: 900))
    self.minSize = NSSize(width: 1100, height: 700)
    self.title = "Llama Village"
    self.center()
    self.delegate = self

    RegisterGeneratedPlugins(registry: flutterViewController)

    let env = ProcessInfo.processInfo.environment
    // macOS stops drawing a covered window, which would pause self-test runs.
    if env["VILLAGE_CAPTURE"] == "1" {
      self.level = .floating
    }
    // VILLAGE_WINDOW=1280x720: an exact content size, for the offline
    // cinematic render's frames.
    if let s = env["VILLAGE_WINDOW"] {
      let size = s.split(separator: "x").compactMap { Double($0) }
      if size.count == 2 {
        self.minSize = NSSize(width: min(size[0], 400), height: min(size[1], 400))
        self.setContentSize(NSSize(width: size[0], height: size[1]))
        self.center()
      }
    }
    // Self-test of the two quit paths: the window's close button and Cmd-Q
    // (the Quit menu item sends terminate:).
    if let s = env["VILLAGE_CLOSE_AFTER"], let delay = Double(s) {
      DispatchQueue.main.asyncAfter(deadline: .now() + delay) { [weak self] in
        self?.performClose(nil)
      }
    }
    if let s = env["VILLAGE_QUIT_AFTER"], let delay = Double(s) {
      DispatchQueue.main.asyncAfter(deadline: .now() + delay) {
        NSApp.sendAction(#selector(NSApplication.terminate(_:)), to: nil, from: nil)
      }
    }

    super.awakeFromNib()
  }

  // Closing the window quits through the same path as Cmd-Q, so the Dart
  // side gets its exit request and frees the models while the engine is
  // still running.
  func windowShouldClose(_ sender: NSWindow) -> Bool {
    NSApp.terminate(nil)
    return false
  }
}
