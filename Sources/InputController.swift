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

@objc(InputController)
class InputController: IMKInputController {
    private var raw = ""
    private var literal = false // word can't be Vietnamese any more: show/commit keys as typed
    private let noRange = NSRange(location: NSNotFound, length: 0)

    private var method: Method {
        get { Method(rawValue: UserDefaults.standard.string(forKey: "method") ?? "") ?? .telex }
        set { UserDefaults.standard.set(newValue.rawValue, forKey: "method") }
    }

    override func handle(_ event: NSEvent!, client sender: Any!) -> Bool {
        guard event.type == .keyDown, let client = sender as? IMKTextInput else { return false }
        if !event.modifierFlags.intersection([.command, .control, .option]).isEmpty {
            commit(client); return false
        }
        if (event.keyCode == 36 || event.keyCode == 76), !raw.isEmpty, // Return / keypad Enter
           let id = client.bundleIdentifier() {
            commit(client)
            let posted = repost(event, to: id)
            log.info("Return in \(id, privacy: .public): reposted=\(posted, privacy: .public) access=\(CGPreflightPostEventAccess(), privacy: .public)")
            if posted { return true }
            // No permission: Chromium swallows it (a 2nd Return sends); native apps get it now.
            return isChromium(id)
        }
        if event.keyCode == 51 { // backspace
            guard !raw.isEmpty else { return false }
            (raw, literal) = backspace(raw, literal: literal, method: method)
            update(client); return true
        }
        guard let s = event.characters, s.count == 1, let c = s.first, c.isASCII,
              c.isLetter || (method == .vni && c.isNumber && !raw.isEmpty) else {
            commit(client); return false // space, punctuation, enter, arrows… end the word
        }
        raw.append(c)
        if !literal && isLiteral(raw, method: method) { literal = true } // sticky until word end
        update(client); return true
    }

    private func update(_ client: IMKTextInput) {
        let s = literal ? raw : compose(raw, method: method)
        // Thin underline only: a plain string lets some apps paint it like a selection.
        let marked = NSAttributedString(string: s, attributes: [.underlineStyle: NSUnderlineStyle.single.rawValue])
        client.setMarkedText(marked, selectionRange: NSRange(location: s.utf16.count, length: 0), replacementRange: noRange)
    }

    // Word end: auto-restore non-Vietnamese words to the typed keys (UniKey "gõ thông minh").
    private func commit(_ client: IMKTextInput) {
        guard !raw.isEmpty else { return }
        client.insertText(literal ? raw : finish(raw, method: method), replacementRange: noRange)
        raw = ""; literal = false
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
        for (title, sel, meth) in [("Telex", #selector(selectTelex), Method.telex), ("VNI", #selector(selectVNI), .vni)] {
            let item = NSMenuItem(title: title, action: sel, keyEquivalent: "")
            item.state = method == meth ? .on : .off
            m.addItem(item)
        }
        return m
    }

    @objc func selectTelex(_ sender: Any?) { method = .telex }
    @objc func selectVNI(_ sender: Any?) { method = .vni }
}
