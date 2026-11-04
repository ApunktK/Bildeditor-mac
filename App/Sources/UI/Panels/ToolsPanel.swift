import AppKit

/// Werkzeugfenster: zwei Spalten mit allen Werkzeugen. Noch nicht umgesetzte Werkzeuge sind deaktiviert.
final class ToolsPanelController: NSViewController {
    private var buttons: [Tool: NSButton] = [:]
    private static let cell: CGFloat = 34

    override func loadView() {
        let cols = 2
        let rows = Int(ceil(Double(Tool.allCases.count) / Double(cols)))
        let pad: CGFloat = 6
        let v = NSView(frame: NSRect(x: 0, y: 0, width: CGFloat(cols) * Self.cell + pad * 2, height: CGFloat(rows) * Self.cell + pad * 2))
        for (i, t) in Tool.allCases.enumerated() {
            let b = NSButton(frame: NSRect(x: pad + CGFloat(i % cols) * Self.cell,
                                           y: v.frame.height - pad - CGFloat(i / cols + 1) * Self.cell,
                                           width: Self.cell - 2, height: Self.cell - 2))
            if let img = t.image { b.image = img; b.imagePosition = .imageOnly } else { b.title = String(t.key).uppercased() }
            b.bezelStyle = .regularSquare
            b.setButtonType(.pushOnPushOff)
            b.isBordered = true
            b.toolTip = t.tooltip
            b.isEnabled = t.isImplemented
            b.target = self
            b.action = #selector(pick(_:))
            b.identifier = NSUserInterfaceItemIdentifier(t.rawValue)
            b.setAccessibilityLabel(t.title)
            v.addSubview(b)
            buttons[t] = b
        }
        view = v
        NotificationCenter.default.addObserver(self, selector: #selector(refresh), name: .toolChanged, object: nil)
        refresh()
    }

    @objc private func pick(_ sender: NSButton) {
        guard let raw = sender.identifier?.rawValue, let t = Tool(rawValue: raw), t.isImplemented else { refresh(); return }
        AppController.shared.tool = t
        refresh()
    }

    @objc func refresh() {
        let cur = AppController.shared.tool
        for (t, b) in buttons { b.state = t == cur ? .on : .off }
    }
}
