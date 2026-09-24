import Cocoa
import InputMethodKit

@objc(InputController)
class InputController: IMKInputController {
    private var raw = ""
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
        if event.keyCode == 51 { // backspace
            guard !raw.isEmpty else { return false }
            raw.removeLast(); update(client); return true
        }
        guard let s = event.characters, s.count == 1, let c = s.first, c.isASCII,
              c.isLetter || (method == .vni && c.isNumber && !raw.isEmpty) else {
            commit(client); return false // space, punctuation, enter, arrows… end the word
        }
        raw.append(c); update(client); return true
    }

    private func update(_ client: IMKTextInput) {
        let s = compose(raw, method: method)
        client.setMarkedText(s, selectionRange: NSRange(location: s.utf16.count, length: 0), replacementRange: noRange)
    }

    private func commit(_ client: IMKTextInput) {
        guard !raw.isEmpty else { return }
        client.insertText(compose(raw, method: method), replacementRange: noRange)
        raw = ""
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
