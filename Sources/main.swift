import Cocoa
import InputMethodKit

// Build step: print every real Vietnamese syllable (build.sh stores it in Resources/vietnamese.txt).
if CommandLine.arguments.contains("--syllables") {
    print(Dictionaries.realSyllables().joined(separator: "\n"))
    exit(0)
}

let server = IMKServer(name: Bundle.main.infoDictionary!["InputMethodConnectionName"] as? String,
                       bundleIdentifier: Bundle.main.bundleIdentifier)
// Warm up the dictionaries so the first word typed doesn't hitch (~50 ms on first use).
_ = Dictionaries.isEnglish("warm") && Dictionaries.isVietnamese("ấm") && Dictionaries.inWordList("warm")
_ = Dictionaries.canBecomeVietnamese("ấm")
NSApplication.shared.run()
