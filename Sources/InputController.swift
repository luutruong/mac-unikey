import Cocoa
import InputMethodKit

@objc(InputController)
class InputController: IMKInputController {
    private var raw = ""
    // Direct mode: the word is typed straight into the document and rewritten in place
    // (no marked-text highlight). `start` = where the word begins, `shown` = its current length.
    // start == NSNotFound -> client can't report the cursor (e.g. Terminal), use marked text.
    private var start = NSNotFound
    private var shown = 0
    private let noRange = NSRange(location: NSNotFound, length: 0)

    private var method: Method {
        get { Method(rawValue: UserDefaults.standard.string(forKey: "method") ?? "") ?? .telex }
        set { UserDefaults.standard.set(newValue.rawValue, forKey: "method") }
    }

    override func handle(_ event: NSEvent!, client sender: Any!) -> Bool {
        guard event.type == .keyDown, let client = sender as? IMKTextInput else { return false }
        // Cursor moved (mouse click, other input) since our last edit -> forget the word.
        if !raw.isEmpty, start != NSNotFound, client.selectedRange().location != start + shown { reset() }
        if !event.modifierFlags.intersection([.command, .control, .option]).isEmpty {
            commit(client); return false
        }
        if event.keyCode == 51 { // backspace
            guard !raw.isEmpty else { return false }
            raw.removeLast(); update(client)
            if raw.isEmpty { reset() }
            return true
        }
        guard let s = event.characters, s.count == 1, let c = s.first, c.isASCII,
              c.isLetter || (method == .vni && c.isNumber && !raw.isEmpty) else {
            commit(client); return false // space, punctuation, enter, arrows… end the word
        }
        if raw.isEmpty { // first key of a word: remember where it goes (replacing any selection)
            let sel = client.selectedRange()
            start = sel.location
            shown = sel.location == NSNotFound ? 0 : sel.length
        }
        raw.append(c); update(client); return true
    }

    private func update(_ client: IMKTextInput) {
        let s = compose(raw, method: method)
        if start != NSNotFound {
            client.insertText(s, replacementRange: NSRange(location: start, length: shown))
            shown = s.utf16.count
        } else {
            client.setMarkedText(s, selectionRange: NSRange(location: s.utf16.count, length: 0), replacementRange: noRange)
        }
    }

    private func commit(_ client: IMKTextInput) {
        if !raw.isEmpty && start == NSNotFound {
            client.insertText(compose(raw, method: method), replacementRange: noRange)
        }
        reset()
    }

    private func reset() { raw = ""; start = NSNotFound; shown = 0 }

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
