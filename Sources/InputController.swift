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

@objc(InputController)
class InputController: IMKInputController {
    private var word = Word() // the word being typed; all typing decisions live in Word.swift
    private let noRange = NSRange(location: NSNotFound, length: 0)
    private var chordArmed = false // Ctrl+Shift pressed with no other key yet

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
        if !event.modifierFlags.intersection([.command, .control, .option]).isEmpty {
            commit(client); return false
        }
        if event.keyCode == 36 || event.keyCode == 76, word.isEmpty { // Return with no word: passes through
            log.notice("Return passthrough in \(client.bundleIdentifier() ?? "?", privacy: .public)")
        }
        if (event.keyCode == 36 || event.keyCode == 76), !word.isEmpty, // Return / keypad Enter
           let id = client.bundleIdentifier() {
            commit(client)
            let posted = repost(event, to: id)
            log.notice("Return in \(id, privacy: .public): reposted=\(posted, privacy: .public) access=\(CGPreflightPostEventAccess(), privacy: .public)")
            if posted { return true }
            // No permission: Chromium swallows it (a 2nd Return sends); native apps get it now.
            return isChromium(id)
        }
        if event.keyCode == 51 { // backspace
            guard !word.isEmpty else { return false }
            word.delete(method)
            update(client); return true
        }
        guard let s = event.characters, s.count == 1, let c = s.first, c.isASCII,
              c.isLetter || (method == .vni && c.isNumber && !word.isEmpty) else {
            commit(client); return false // space, punctuation, enter, arrows… end the word
        }
        word.type(c, method)
        update(client); return true
    }

    private func update(_ client: IMKTextInput) {
        let s = word.display(method)
        // Thin underline only: a plain string lets some apps paint it like a selection.
        let marked = NSAttributedString(string: s, attributes: [.underlineStyle: NSUnderlineStyle.single.rawValue])
        client.setMarkedText(marked, selectionRange: NSRange(location: s.utf16.count, length: 0), replacementRange: noRange)
    }

    // Word end: insert the decided text (Vietnamese, English, or keys as typed).
    private func commit(_ client: IMKTextInput) {
        guard !word.isEmpty else { return }
        client.insertText(word.commit(method), replacementRange: noRange)
        word = Word()
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
