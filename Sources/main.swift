import Cocoa
import InputMethodKit

let server = IMKServer(name: Bundle.main.infoDictionary!["InputMethodConnectionName"] as? String,
                       bundleIdentifier: Bundle.main.bundleIdentifier)
// Warm up the dictionaries so the first word typed doesn't hitch (~50 ms on first use).
_ = Dictionaries.isVietnamese("ấm")
let app = NSApplication.shared
showModeBadge() // English left on from last time; needs NSApp to exist
app.run()
