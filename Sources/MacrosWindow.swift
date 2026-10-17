import Cocoa

/// Bảng gõ tắt: add, edit (double-click) and delete shorthand. Every edit is saved right away
/// to Macros.table, so typing picks it up without a restart.
final class MacrosWindow: NSObject, NSTableViewDataSource, NSWindowDelegate {
    private static var shared: MacrosWindow?
    private let window: NSWindow
    private let table = NSTableView()
    private var rows: [(key: String, value: String)] = []

    static func show() {
        let w = shared ?? MacrosWindow()
        shared = w
        w.reload()
        // The input method is LSBackgroundOnly: become a regular-enough app so the window gets the keyboard.
        NSApp.setActivationPolicy(.accessory)
        NSApp.activate(ignoringOtherApps: true)
        w.window.makeKeyAndOrderFront(nil)
    }

    private override init() {
        window = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 420, height: 360),
                          styleMask: [.titled, .closable, .resizable], backing: .buffered, defer: false)
        super.init()
        window.title = "Bảng gõ tắt"
        window.isReleasedWhenClosed = false
        window.minSize = NSSize(width: 300, height: 200)
        window.delegate = self
        let content = window.contentView!

        for (id, title, width) in [("key", "Viết tắt", 110.0), ("value", "Thay bằng", 270.0)] {
            let col = NSTableColumn(identifier: NSUserInterfaceItemIdentifier(id))
            col.title = title
            col.width = width
            table.addTableColumn(col)
        }
        table.dataSource = self
        table.allowsMultipleSelection = true
        table.usesAlternatingRowBackgroundColors = true
        let scroll = NSScrollView(frame: NSRect(x: 12, y: 44, width: 396, height: 304))
        scroll.documentView = table
        scroll.hasVerticalScroller = true
        scroll.borderType = .bezelBorder
        scroll.autoresizingMask = [.width, .height]
        content.addSubview(scroll)

        for (i, (title, action)) in [("+", #selector(add)), ("−", #selector(remove))].enumerated() {
            let b = NSButton(title: title, target: self, action: action)
            b.bezelStyle = .smallSquare
            b.frame = NSRect(x: 12 + CGFloat(i) * 28, y: 14, width: 28, height: 24)
            b.autoresizingMask = [.maxXMargin, .maxYMargin]
            content.addSubview(b)
        }
        let hint = NSTextField(labelWithString: "Nhấp đúp để sửa. Gõ từ tắt rồi Space để thay.")
        hint.font = .systemFont(ofSize: 11)
        hint.textColor = .secondaryLabelColor
        hint.frame = NSRect(x: 76, y: 17, width: 332, height: 16)
        hint.autoresizingMask = [.width, .maxYMargin]
        content.addSubview(hint)
        window.center()
    }

    private func reload() {
        rows = Macros.table.sorted { $0.key < $1.key }.map { ($0.key, $0.value) }
        table.reloadData()
    }

    // Rows with an empty shorthand are kept on screen but not saved; a repeated shorthand keeps the last row.
    private func save() {
        var t: [String: String] = [:]
        for r in rows {
            let k = r.key.trimmingCharacters(in: .whitespaces).lowercased()
            if !k.isEmpty { t[k] = r.value }
        }
        Macros.table = t
    }

    @objc private func add() {
        rows.append(("", ""))
        table.reloadData()
        table.selectRowIndexes([rows.count - 1], byExtendingSelection: false)
        table.editColumn(0, row: rows.count - 1, with: nil, select: true)
    }

    @objc private func remove() {
        window.makeFirstResponder(nil) // finish an edit in progress first
        for i in table.selectedRowIndexes.reversed() where i < rows.count { rows.remove(at: i) }
        save()
        table.reloadData()
    }

    func numberOfRows(in tableView: NSTableView) -> Int { rows.count }

    func tableView(_ tableView: NSTableView, objectValueFor col: NSTableColumn?, row: Int) -> Any? {
        col?.identifier.rawValue == "key" ? rows[row].key : rows[row].value
    }

    func tableView(_ tableView: NSTableView, setObjectValue object: Any?, for col: NSTableColumn?, row: Int) {
        guard row < rows.count else { return }
        let s = object as? String ?? ""
        if col?.identifier.rawValue == "key" { rows[row].key = s.trimmingCharacters(in: .whitespaces).lowercased() }
        else { rows[row].value = s }
        save()
    }

    func windowWillClose(_ notification: Notification) {
        window.makeFirstResponder(nil) // save an edit in progress
        NSApp.setActivationPolicy(.prohibited)
    }
}
