import AppKit

let app = NSApplication.shared
let delegate = AppDelegate()
app.delegate = delegate
// Accessory app: no Dock icon, lives in the menu bar / notch only.
app.setActivationPolicy(.accessory)
app.run()
