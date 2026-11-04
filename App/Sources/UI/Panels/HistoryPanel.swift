import AppKit
import EditorDocument

/// Verlaufsfenster: jede Aktion als Eintrag; rückgängig gemachte Einträge grau hinterlegt.
/// Klick springt zum Eintrag; erneuter Klick auf den aktuellen Eintrag wechselt zum vorherigen (Referenz-Tipp).
final class HistoryPanelController: NSViewController, NSTableViewDataSource, NSTableViewDelegate {
    let table = NSTableView()
    private let undoButton = NSButton()
    private let redoButton = NSButton()
    private var doc: Document? { AppController.shared.document }

    override func loadView() {
        let v = NSView(frame: NSRect(x: 0, y: 0, width: 240, height: 240))
        let col = NSTableColumn(identifier: NSUserInterfaceItemIdentifier("eintrag"))
        col.resizingMask = .autoresizingMask
        table.addTableColumn(col)
        table.headerView = nil
        table.rowHeight = 22
        table.dataSource = self
        table.delegate = self
        table.target = self
        table.action = #selector(rowClicked)
        table.allowsEmptySelection = true
        table.style = .plain
        table.columnAutoresizingStyle = .uniformColumnAutoresizingStyle
        let scroll = NSScrollView()
        scroll.documentView = table
        scroll.hasVerticalScroller = true
        scroll.autohidesScrollers = true

        func setup(_ b: NSButton, _ symbol: String, _ tip: String, _ sel: Selector) {
            b.image = NSImage(systemSymbolName: symbol, accessibilityDescription: tip)
            b.imagePosition = .imageOnly; b.bezelStyle = .recessed; b.showsBorderOnlyWhileMouseInside = true
            b.toolTip = tip; b.target = self; b.action = sel
        }
        setup(undoButton, "arrow.uturn.backward", "Rückgängig (⌘Z)", #selector(undo))
        setup(redoButton, "arrow.uturn.forward", "Wiederholen (⇧⌘Z)", #selector(redo))
        let bar = NSStackView(views: [undoButton, redoButton])
        bar.orientation = .horizontal
        bar.spacing = 4
        for x in [scroll, bar] as [NSView] { x.translatesAutoresizingMaskIntoConstraints = false; v.addSubview(x) }
        NSLayoutConstraint.activate([
            scroll.topAnchor.constraint(equalTo: v.topAnchor),
            scroll.leadingAnchor.constraint(equalTo: v.leadingAnchor), scroll.trailingAnchor.constraint(equalTo: v.trailingAnchor),
            bar.topAnchor.constraint(equalTo: scroll.bottomAnchor, constant: 4),
            bar.leadingAnchor.constraint(equalTo: v.leadingAnchor, constant: 6),
            bar.bottomAnchor.constraint(equalTo: v.bottomAnchor, constant: -4),
            bar.heightAnchor.constraint(equalToConstant: 24),
        ])
        view = v
        let nc = NotificationCenter.default
        nc.addObserver(self, selector: #selector(reload), name: .documentsChanged, object: nil)
        nc.addObserver(self, selector: #selector(docChanged(_:)), name: .documentChanged, object: nil)
        reload()
    }

    @objc private func docChanged(_ n: Notification) {
        guard (n.object as? DocumentSession) === AppController.shared.active,
              let c = n.userInfo?["change"] as? Document.Change, c == .history || c == .file else { return }
        reload()
    }

    @objc func reload() {
        table.reloadData()
        if let d = doc {
            table.selectRowIndexes(IndexSet(integer: d.historyIndex), byExtendingSelection: false)
            table.scrollRowToVisible(d.historyIndex)
        } else {
            table.deselectAll(nil)
        }
        undoButton.isEnabled = doc?.canUndo ?? false
        redoButton.isEnabled = doc?.canRedo ?? false
    }

    @objc private func rowClicked() {
        guard let d = doc else { return }
        let row = table.clickedRow
        guard row >= 0 else { reload(); return }
        if row == d.historyIndex && row > 0 { d.jump(to: row - 1) } else { d.jump(to: row) }
        reload()
    }

    @objc private func undo() { AppController.shared.commands.perform("edit.undo") }
    @objc private func redo() { AppController.shared.commands.perform("edit.redo") }

    func numberOfRows(in tableView: NSTableView) -> Int { doc?.history.count ?? 0 }

    static func symbol(for k: HistoryKind) -> String {
        switch k {
        case .newImage: return "doc"
        case .openImage: return "folder"
        case .layerAdd: return "plus.square.on.square"
        case .layerDelete: return "trash"
        case .layerDuplicate: return "square.on.square"
        case .layerMerge: return "arrow.down.to.line"
        case .layerMove: return "arrow.up.arrow.down"
        case .layerProperties: return "slider.horizontal.3"
        case .imageTransform: return "rotate.right"
        case .imageResize: return "arrow.up.left.and.arrow.down.right"
        case .flatten: return "square.stack.3d.down.right"
        case .paste: return "doc.on.clipboard"
        case .edit: return "pencil"
        }
    }

    func tableView(_ tableView: NSTableView, viewFor tableColumn: NSTableColumn?, row: Int) -> NSView? {
        guard let d = doc, row < d.history.count else { return nil }
        let e = d.history[row]
        let id = NSUserInterfaceItemIdentifier("verlaufszelle")
        let cell = tableView.makeView(withIdentifier: id, owner: nil) as? NSTableCellView ?? {
            let c = NSTableCellView()
            c.identifier = id
            let iv = NSImageView(); let tf = NSTextField(labelWithString: "")
            tf.lineBreakMode = .byTruncatingTail
            for x in [iv, tf] as [NSView] { x.translatesAutoresizingMaskIntoConstraints = false; c.addSubview(x) }
            NSLayoutConstraint.activate([
                iv.leadingAnchor.constraint(equalTo: c.leadingAnchor, constant: 4), iv.centerYAnchor.constraint(equalTo: c.centerYAnchor),
                iv.widthAnchor.constraint(equalToConstant: 16), iv.heightAnchor.constraint(equalToConstant: 16),
                tf.leadingAnchor.constraint(equalTo: iv.trailingAnchor, constant: 6), tf.centerYAnchor.constraint(equalTo: c.centerYAnchor),
                tf.trailingAnchor.constraint(lessThanOrEqualTo: c.trailingAnchor, constant: -4),
            ])
            c.imageView = iv; c.textField = tf
            return c
        }()
        cell.imageView?.image = NSImage(systemSymbolName: Self.symbol(for: e.kind), accessibilityDescription: nil)
        cell.textField?.stringValue = e.name
        let undone = row > d.historyIndex
        cell.textField?.textColor = undone ? .tertiaryLabelColor : .labelColor
        cell.imageView?.contentTintColor = undone ? .tertiaryLabelColor : .secondaryLabelColor
        return cell
    }

    func tableView(_ tableView: NSTableView, rowViewForRow row: Int) -> NSTableRowView? {
        let rv = HistoryRowView()
        if let d = doc { rv.isUndone = row > d.historyIndex }
        return rv
    }

    /// Auswahl nur über Klick (rowClicked) – sonst würde die Tastatur-Auswahl unbemerkt springen.
    func tableViewSelectionDidChange(_ notification: Notification) {
        guard let d = doc, table.selectedRow >= 0, table.selectedRow != d.historyIndex, table.clickedRow < 0 else { return }
        d.jump(to: table.selectedRow)
    }
}

/// Grauer Hintergrund für rückgängig gemachte Einträge (Referenz).
final class HistoryRowView: NSTableRowView {
    var isUndone = false
    override func drawBackground(in dirtyRect: NSRect) {
        if isUndone {
            NSColor.quaternaryLabelColor.setFill()
            bounds.fill()
        } else {
            super.drawBackground(in: dirtyRect)
        }
    }
}
