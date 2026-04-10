import Cocoa

let app = NSApplication.shared
app.setActivationPolicy(.accessory)  // No dock icon - this IS the dock
let delegate = AppDelegate()
app.delegate = delegate
app.run()
