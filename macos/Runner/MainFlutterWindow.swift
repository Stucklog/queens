import Cocoa
import FlutterMacOS

class MainFlutterWindow: NSWindow {
  override func awakeFromNib() {
    let flutterViewController = FlutterViewController()
    self.contentViewController = flutterViewController
    self.setContentSize(NSSize(width: 430, height: 760))
    self.contentAspectRatio = NSSize(width: 9, height: 16)
    self.minSize = NSSize(width: 360, height: 640)
    self.maxSize = NSSize(width: 600, height: 1067)

    RegisterGeneratedPlugins(registry: flutterViewController)

    super.awakeFromNib()
  }
}
