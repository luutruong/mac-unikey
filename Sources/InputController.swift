import Cocoa
import InputMethodKit
import os

private let log = Logger(subsystem: "com.luutruong.inputmethod.MacUnikey", category: "return")

// Every word is composed as marked text (thin underline) and committed at word end.
// In-place rewriting via insertText(replacementRange:) proved unreliable: Chromium/Electron
// apply edits asynchronously and editors like Sublime Text mis-track the range -> dropped or
// duplicated characters. Marked text is the path every text view supports.

// A Return that arrives while a word is marked is treated as part of the composition by many
// chat boxes (Chromium/Electron flag it keyCode 229; native Telegram too) -> newline, not send.
// So Return commits the word, is swallowed and re-posted once the word is plain text.
// Chromium is detected by its resource pack (cached per bundle id) for the no-permission fallback.
private var chromiumCache: [String: Bool] = [:]
private func isChromium(_ bundleID: String?) -> Bool {
    guard let id = bundleID else { return false }
    if let v = chromiumCache[id] { return v }
    var v = false
    if let app = NSWorkspace.shared.urlForApplication(withBundleIdentifier: id) {
        let fw = app.appendingPathComponent("Contents/Frameworks")
        let items = (try? FileManager.default.contentsOfDirectory(atPath: fw.path)) ?? []
        v = items.contains { FileManager.default.fileExists(atPath: fw.appendingPathComponent("\($0)/Resources/chrome_100_percent.pak").path) }
    }
    chromiumCache[id] = v
    return v
}

// Re-posting keys needs the Accessibility permission; ask macOS once per launch.
// Returns false when it can't post (no permission / app not found).
private var askedPostAccess = false
private func repost(_ event: NSEvent, to bundleID: String) -> Bool {
    guard CGPreflightPostEventAccess() else {
        if !askedPostAccess { askedPostAccess = true; _ = CGRequestPostEventAccess() }
        return false
    }
    let apps = NSRunningApplication.runningApplications(withBundleIdentifier: bundleID)
    guard let pid = (apps.first { $0.isActive } ?? apps.first)?.processIdentifier else { return false }
    let flags = CGEventFlags(rawValue: UInt64(event.modifierFlags.intersection(.deviceIndependentFlagsMask).rawValue))
    DispatchQueue.main.asyncAfter(deadline: .now() + 0.02) { // let the app apply the commit first
        for down in [true, false] {
            let e = CGEvent(keyboardEventSource: nil, virtualKey: event.keyCode, keyDown: down)
            e?.flags = flags
            e?.postToPid(pid)
        }
    }
    return true
}

// Brief "Tiếng Việt" / "English" label under the cursor when toggling V/E: the menu-bar icon of
// an input method without modes can't change, so this is the only state feedback.
private var hud: NSPanel?
private var hudToken = 0
private func showHUD(_ text: String, near client: IMKTextInput) {
    var line = NSRect.zero
    _ = client.attributes(forCharacterIndex: 0, lineHeightRectangle: &line)
    let label = NSTextField(labelWithString: text)
    label.font = .systemFont(ofSize: 13, weight: .semibold)
    label.textColor = .white
    label.sizeToFit()
    let size = NSSize(width: label.frame.width + 20, height: label.frame.height + 10)
    let bg = NSView(frame: NSRect(origin: .zero, size: size))
    bg.wantsLayer = true
    bg.layer?.backgroundColor = NSColor.black.withAlphaComponent(0.75).cgColor
    bg.layer?.cornerRadius = 6
    label.frame.origin = NSPoint(x: 10, y: 5)
    bg.addSubview(label)
    let panel = hud ?? NSPanel(contentRect: .zero, styleMask: [.borderless, .nonactivatingPanel], backing: .buffered, defer: false)
    hud = panel
    panel.level = .popUpMenu
    panel.backgroundColor = .clear
    panel.isOpaque = false
    panel.ignoresMouseEvents = true
    panel.contentView = bg
    let origin = line == .zero ? NSEvent.mouseLocation : NSPoint(x: line.minX, y: line.minY - size.height - 4)
    panel.setFrame(NSRect(origin: origin, size: size), display: true)
    panel.orderFrontRegardless()
    hudToken += 1
    let t = hudToken
    DispatchQueue.main.asyncAfter(deadline: .now() + 0.8) { if t == hudToken { panel.orderOut(nil) } }
}

private var loggedFontApps = Set<String>() // log the marked-text font once per app (debugging)
private var loggedModeApps = Set<String>()

// Typing log, to improve the English/Vietnamese rules from real use: one tab-separated line per
// finished word (keys typed -> text committed) and per Delete (what was on screen), with the app.
// Built in only with `./build.sh --enable-logging`; written to ~/Library/Application Support/MacUnikey/.
// Password fields never reach input methods.
#if TYPING_LOG
private let typingLogURL: URL = {
    let dir = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        .appendingPathComponent("MacUnikey")
    try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
    return dir.appendingPathComponent("typing.log")
}()
private let typingLogFile: FileHandle? = {
    if !FileManager.default.fileExists(atPath: typingLogURL.path) {
        FileManager.default.createFile(atPath: typingLogURL.path, contents: nil)
    }
    let h = try? FileHandle(forWritingTo: typingLogURL)
    _ = try? h?.seekToEnd()
    return h
}()
private func logTyping(_ fields: String...) {
    let line = ([ISO8601DateFormatter().string(from: Date())] + fields).joined(separator: "\t") + "\n"
    typingLogFile?.write(Data(line.utf8))
}
#else
private func logTyping(_ fields: String...) {}
#endif

@objc(InputController)
class InputController: IMKInputController {
    private var word = Word() // the word being typed; all typing decisions live in Word.swift
    private var markedStyle: [NSAttributedString.Key: Any]? // per word, see markedAttributes
    // Direct mode (native apps like Telegram, TextEdit): the word is typed straight into the text
    // and rewritten in place, with no marked text — marked text gets redrawn in another font there
    // (Telegram reports no font), so the line shakes. `start`/`shown` = where the word sits.
    // Chromium/Electron apps apply edits asynchronously, so they keep marked text (start = NSNotFound).
    private var start = NSNotFound
    private var shown = 0
    private var shownText = "" // what direct mode last put in the document
    private let noRange = NSRange(location: NSNotFound, length: 0)
    private var chordArmed = false // Ctrl+Shift pressed with no other key yet
    private var afterDelete = false // last key was a Delete the app handled: the next word may continue the text

    // V/E toggle (UniKey Ctrl+Shift), shared by all apps.
    private var vietnamese: Bool {
        get { UserDefaults.standard.object(forKey: "vietnamese") as? Bool ?? true }
        set { UserDefaults.standard.set(newValue, forKey: "vietnamese") }
    }

    private var method: Method {
        get { Method(rawValue: UserDefaults.standard.string(forKey: "method") ?? "") ?? .telex }
        set { UserDefaults.standard.set(newValue.rawValue, forKey: "method") }
    }

    override func recognizedEvents(_ sender: Any!) -> Int {
        Int(NSEvent.EventTypeMask([.keyDown, .flagsChanged]).rawValue)
    }

    override func handle(_ event: NSEvent!, client sender: Any!) -> Bool {
        guard let client = sender as? IMKTextInput else { return false }
        if event.type == .flagsChanged { // Ctrl+Shift pressed and released alone -> toggle V/E
            let f = event.modifierFlags.intersection([.shift, .control, .option, .command])
            if f == [.control, .shift] { chordArmed = true }
            else if f.isEmpty { if chordArmed { toggle(client) }; chordArmed = false }
            else if !f.isSubset(of: [.control, .shift]) { chordArmed = false }
            return false
        }
        guard event.type == .keyDown else { return false }
        chordArmed = false
        guard vietnamese else { return false }
        let resume = afterDelete
        afterDelete = false
        // Direct mode: the cursor moved (click, other edit) since our last change -> forget the word.
        if !word.isEmpty, start != NSNotFound, client.selectedRange().location != start + shown { reset() }
        if !event.modifierFlags.intersection([.command, .control, .option]).isEmpty {
            commit(client); return false
        }
        if event.keyCode == 36 || event.keyCode == 76, word.isEmpty { // Return with no word: passes through
            log.notice("Return passthrough in \(client.bundleIdentifier() ?? "?", privacy: .public)")
        }
        if (event.keyCode == 36 || event.keyCode == 76), !word.isEmpty, start == NSNotFound, // Return on marked text
           let id = client.bundleIdentifier() {
            commit(client)
            let posted = repost(event, to: id)
            log.notice("Return in \(id, privacy: .public): reposted=\(posted, privacy: .public) access=\(CGPreflightPostEventAccess(), privacy: .public)")
            if posted { return true }
            // No permission: Chromium swallows it (a 2nd Return sends); native apps get it now.
            return isChromium(id)
        }
        if event.keyCode == 51 { // backspace
            logTyping("delete", client.bundleIdentifier() ?? "?", word.isEmpty ? "" : word.display(method))
            guard !word.isEmpty else { afterDelete = true; return false }
            word.delete(method)
            // Direct mode, Delete just removes the last letter ("việt" -> "việ"): let the app delete it natively.
            if start != NSNotFound, !shownText.isEmpty, shown == shownText.utf16.count,
               word.display(method) == String(shownText.dropLast()) {
                shownText.removeLast()
                shown = shownText.utf16.count
                if word.isEmpty { reset(); afterDelete = true }
                return false
            }
            update(client)
            if word.isEmpty { reset() }
            return true
        }
        guard let s = event.characters, s.count == 1, let c = s.first, c.isASCII,
              c.isLetter || (method == .vni && c.isNumber && !word.isEmpty) else {
            commit(client); return false // space, punctuation, enter, arrows… end the word
        }
        if word.isEmpty { begin(client, resume: resume) }
        word.type(c, method)
        // Direct mode, key just adds itself at the end ("trướ" + "c"): let the app type it natively.
        // Telegram spends 3-6 ms on every insertText(replacementRange:) call; a plain key costs it nothing extra.
        if start != NSNotFound, shown == shownText.utf16.count, word.display(method) == shownText + s {
            shownText += s
            shown = shownText.utf16.count
            return false
        }
        update(client); return true
    }

    // First key of a word: pick direct or marked mode for this app.
    private func begin(_ client: IMKTextInput, resume: Bool) {
        let id = client.bundleIdentifier()
        let sel = isChromium(id) ? noRange : client.selectedRange()
        start = sel.location
        shown = sel.location == NSNotFound ? 0 : sel.length // typing replaces a selection
        // Direct mode, right after Delete: pick up the letters before the cursor as the word so far.
        if resume, start != NSNotFound, sel.length == 0, start > 0,
           let before = client.attributedSubstring(from: NSRange(location: max(0, start - 8), length: min(start, 8)))?.string {
            let prefix = String(before.reversed().prefix { $0.isLetter }.reversed())
            if !prefix.isEmpty {
                word = Word(resuming: prefix, method)
                shownText = prefix
                shown = prefix.utf16.count
                start -= shown
            }
        }
        if let id, loggedModeApps.insert(id).inserted {
            log.notice("mode in \(id, privacy: .public): \(self.start == NSNotFound ? "marked" : "direct", privacy: .public)")
        }
    }

    private func reset() { word = Word(); markedStyle = nil; start = NSNotFound; shown = 0; shownText = "" }

    // Direct mode: send only what changed, not the whole word. Most keys just add a letter
    // ("trướ" -> "trước" inserts "c"); rewriting the word on every key makes apps like Telegram
    // re-process it each time and typing feels slow.
    private func replaceShown(with s: String, _ client: IMKTextInput) {
        guard s != shownText else { return }
        let same = zip(shownText, s).prefix { $0 == $1 }.count
        let keep = String(shownText.prefix(same)).utf16.count
        client.insertText(String(s.dropFirst(same)), replacementRange: NSRange(location: start + keep, length: shown - keep))
        shownText = s
        shown = s.utf16.count
    }

    private func update(_ client: IMKTextInput) {
        let s = word.display(method)
        if start != NSNotFound { replaceShown(with: s, client); return }
        let style = markedStyle ?? markedAttributes(client)
        markedStyle = style
        client.setMarkedText(NSAttributedString(string: s, attributes: style),
                             selectionRange: NSRange(location: s.utf16.count, length: 0), replacementRange: noRange)
    }

    // The word being typed must be drawn in the text field's own font: without a font attribute,
    // native apps (Telegram) draw it in a default font of another size, so the line shifts on every
    // key and again when the word is committed. Style = macOS's "converted text" mark (thin
    // underline), never a selection-like background. Looked up once per word.
    private func markedAttributes(_ client: IMKTextInput) -> [NSAttributedString.Key: Any] {
        var style = [NSAttributedString.Key: Any]()
        let range = NSRange(location: NSNotFound, length: 0)
        for (k, v) in mark(forStyle: kTSMHiliteConvertedText, at: range) ?? [:] {
            if let key = k.base as? NSAttributedString.Key { style[key] = v }
            else if let key = k.base as? String { style[NSAttributedString.Key(key)] = v }
        }
        let at = client.selectedRange().location
        var line = NSRect.zero
        if at != NSNotFound, let attrs = client.attributes(forCharacterIndex: max(at, 1) - 1, lineHeightRectangle: &line),
           let font = attrs[NSAttributedString.Key.font] ?? attrs[NSAttributedString.Key.font.rawValue] {
            style[.font] = font
        }
        style[.underlineStyle] = NSUnderlineStyle.single.rawValue
        style[.backgroundColor] = nil
        if let id = client.bundleIdentifier(), loggedFontApps.insert(id).inserted {
            log.notice("marked font in \(id, privacy: .public): \(String(describing: style[.font]), privacy: .public)")
        }
        return style
    }

    // Word end: insert the decided text (Vietnamese, English, or keys as typed).
    private func commit(_ client: IMKTextInput) {
        guard !word.isEmpty else { return }
        let final = word.commit(method)
        logTyping("word", client.bundleIdentifier() ?? "?", method.rawValue, word.raw, final)
        if start == NSNotFound {
            client.insertText(final, replacementRange: noRange)
        } else {
            replaceShown(with: final, client)
        }
        reset()
    }

    private func toggle(_ client: IMKTextInput) {
        commit(client)
        vietnamese.toggle()
        showHUD(vietnamese ? "Tiếng Việt" : "English", near: client)
    }

    override func commitComposition(_ sender: Any!) {
        if let c = sender as? IMKTextInput { commit(c) }
    }

    override func deactivateServer(_ sender: Any!) {
        commitComposition(sender)
        super.deactivateServer(sender)
    }

    override func menu() -> NSMenu! {
        let m = NSMenu()
        let v = NSMenuItem(title: "Tiếng Việt (⌃⇧)", action: #selector(toggleVietnamese), keyEquivalent: "")
        v.state = vietnamese ? .on : .off
        m.addItem(v)
        m.addItem(.separator())
        for (title, sel, meth) in [("Telex", #selector(selectTelex), Method.telex), ("VNI", #selector(selectVNI), .vni)] {
            let item = NSMenuItem(title: title, action: sel, keyEquivalent: "")
            item.state = method == meth ? .on : .off
            m.addItem(item)
        }
        return m
    }

    @objc func toggleVietnamese(_ sender: Any?) {
        if let c = client() { toggle(c) } else { vietnamese.toggle() }
    }
    @objc func selectTelex(_ sender: Any?) { method = .telex }
    @objc func selectVNI(_ sender: Any?) { method = .vni }
}
