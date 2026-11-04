import AppKit
import EditorDocument

/// Ebenenfenster: oberste Ebene oben. Klick = aktive Ebene, Häkchen = sichtbar, Doppelklick = Eigenschaften,
/// Ziehen = Reihenfolge ändern. Knöpfe wie in der Referenz (⌘-Klick auf Hoch/Runter = ganz nach oben/unten).
final class LayersPanelController: NSViewController, NSTableViewDataSource, NSTableViewDelegate {
    let table = NSTableView()
    private var buttons: [(String, NSButton)] = []
    private static let dragType = NSPasteboard.PasteboardType("de.apunktk.bildeditor.ebene")
    private var doc: Document? { AppController.shared.document }

    override func loadView() {
        let v = NSView(frame: NSRect(x: 0, y: 0, width: 240, height: 260))
        let col = NSTableColumn(identifier: NSUserInterfaceItemIdentifier("ebene"))
        col.resizingMask = .autoresizingMask
        table.addTableColumn(col)
        table.headerView = nil
        table.rowHeight = 44
        table.style = .plain
        table.dataSource = self
        table.delegate = self
        table.target = self
        table.doubleAction = #selector(doubleClicked)
        table.registerForDraggedTypes([Self.dragType])
        table.setDraggingSourceOperationMask(.move, forLocal: true)
        table.columnAutoresizingStyle = .uniformColumnAutoresizingStyle
        let scroll = NSScrollView()
        scroll.documentView = table
        scroll.hasVerticalScroller = true
        scroll.autohidesScrollers = true

        let defs: [(String, String, String)] = [
            ("layer.add", "plus.square", "Neue Ebene"),
            ("layer.delete", "trash", "Ebene löschen"),
            ("layer.duplicate", "square.on.square", "Ebene duplizieren"),
            ("layer.mergeDown", "arrow.down.to.line", "Mit darunterliegender Ebene zusammenführen"),
            ("layer.moveUp", "arrow.up", "Ebene nach oben (⌘-Klick: ganz nach oben)"),
            ("layer.moveDown", "arrow.down", "Ebene nach unten (⌘-Klick: ganz nach unten)"),
            ("layer.properties", "slider.horizontal.3", "Ebeneneigenschaften (F4)"),
        ]
        let bar = NSStackView()
        bar.orientation = .horizontal
        bar.spacing = 2
        for (id, sym, tip) in defs {
            let b = NSButton(image: NSImage(systemSymbolName: sym, accessibilityDescription: tip) ?? NSImage(), target: self, action: #selector(buttonClicked(_:)))
            b.identifier = NSUserInterfaceItemIdentifier(id)
            b.bezelStyle = .recessed; b.showsBorderOnlyWhileMouseInside = true; b.imagePosition = .imageOnly
            b.toolTip = tip
            bar.addArrangedSubview(b)
            buttons.append((id, b))
        }
        for x in [scroll, bar] as [NSView] { x.translatesAutoresizingMaskIntoConstraints = false; v.addSubview(x) }
        NSLayoutConstraint.activate([
            scroll.topAnchor.constraint(equalTo: v.topAnchor),
            scroll.leadingAnchor.constraint(equalTo: v.leadingAnchor), scroll.trailingAnchor.constraint(equalTo: v.trailingAnchor),
            bar.topAnchor.constraint(equalTo: scroll.bottomAnchor, constant: 4),
            bar.leadingAnchor.constraint(equalTo: v.leadingAnchor, constant: 4),
            bar.bottomAnchor.constraint(equalTo: v.bottomAnchor, constant: -4),
            bar.heightAnchor.constraint(equalToConstant: 24),
        ])
        view = v
        let nc = NotificationCenter.default
        nc.addObserver(self, selector: #selector(reload), name: .documentsChanged, object: nil)
        nc.addObserver(self, selector: #selector(docChanged(_:)), name: .documentChanged, object: nil)
        reload()
    }

    // Tabellenzeile ↔ Ebenenindex (Zeile 0 = oberste Ebene)
    private func layerIndex(forRow r: Int) -> Int { (doc?.layers.count ?? 0) - 1 - r }
    private func row(forLayer i: Int) -> Int { (doc?.layers.count ?? 0) - 1 - i }

    @objc private func docChanged(_ n: Notification) {
        guard (n.object as? DocumentSession) === AppController.shared.active,
              let c = n.userInfo?["change"] as? Document.Change, c == .layers || c == .activeLayer || c == .content else { return }
        reload()
    }

    private var reloading = false

    @objc func reload() {
        reloading = true
        table.reloadData()
        if let d = doc { table.selectRowIndexes(IndexSet(integer: row(forLayer: d.activeLayerIndex)), byExtendingSelection: false) }
        reloading = false
        let reg = AppController.shared.commands
        for (id, b) in buttons { b.isEnabled = reg.canPerform(id) }
    }

    func buttonEnabled(_ id: String) -> Bool { buttons.first { $0.0 == id }?.1.isEnabled ?? false }

    @objc private func buttonClicked(_ sender: NSButton) {
        guard var id = sender.identifier?.rawValue else { return }
        if NSEvent.modifierFlags.contains(.command) {
            if id == "layer.moveUp" { id = "layer.moveTop" } else if id == "layer.moveDown" { id = "layer.moveBottom" }
        }
        AppController.shared.commands.perform(id)
    }

    @objc private func doubleClicked() {
        guard table.clickedRow >= 0 else { return }
        LayerPropertiesDialog.runForActiveLayer()
    }

    @objc fileprivate func visibilityToggled(_ sender: NSButton) {
        guard let d = doc else { return }
        let r = table.row(for: sender)
        guard r >= 0 else { return }
        d.toggleVisibility(at: layerIndex(forRow: r))
    }

    // MARK: Datenquelle

    func numberOfRows(in tableView: NSTableView) -> Int { doc?.layers.count ?? 0 }

    func tableView(_ tableView: NSTableView, viewFor tableColumn: NSTableColumn?, row: Int) -> NSView? {
        guard let d = doc else { return nil }
        let i = layerIndex(forRow: row)
        guard i >= 0, i < d.layers.count else { return nil }
        let layer = d.layers[i]
        let cell = tableView.makeView(withIdentifier: LayerCellView.id, owner: nil) as? LayerCellView ?? LayerCellView(owner: self)
        cell.configure(layer)
        return cell
    }

    func tableViewSelectionDidChange(_ notification: Notification) {
        guard !reloading, let d = doc, table.selectedRow >= 0 else { return }
        d.setActiveLayer(layerIndex(forRow: table.selectedRow))
    }

    // MARK: Ziehen zum Umsortieren

    func tableView(_ tableView: NSTableView, pasteboardWriterForRow row: Int) -> NSPasteboardWriting? {
        let item = NSPasteboardItem()
        item.setString(String(row), forType: Self.dragType)
        return item
    }

    func tableView(_ tableView: NSTableView, validateDrop info: NSDraggingInfo, proposedRow row: Int,
                   proposedDropOperation op: NSTableView.DropOperation) -> NSDragOperation {
        if op == .on { tableView.setDropRow(row, dropOperation: .above) }
        return info.draggingSource as? NSTableView === tableView ? .move : []
    }

    func tableView(_ tableView: NSTableView, acceptDrop info: NSDraggingInfo, row: Int, dropOperation: NSTableView.DropOperation) -> Bool {
        guard let d = doc, let s = info.draggingPasteboard.pasteboardItems?.first?.string(forType: Self.dragType), let src = Int(s) else { return false }
        let newRow = row > src ? row - 1 : row
        guard newRow != src else { return false }
        d.moveLayer(from: layerIndex(forRow: src), to: layerIndex(forRow: newRow))
        return true
    }
}

final class LayerCellView: NSTableCellView {
    static let id = NSUserInterfaceItemIdentifier("ebenenzelle")
    let visible = NSButton(checkboxWithTitle: "", target: nil, action: nil)
    let thumb = NSImageView()
    let name = NSTextField(labelWithString: "")
    let detail = NSTextField(labelWithString: "")

    init(owner: LayersPanelController) {
        super.init(frame: .zero)
        identifier = Self.id
        visible.target = owner
        visible.action = #selector(LayersPanelController.visibilityToggled(_:))
        visible.toolTip = "Sichtbar"
        thumb.imageScaling = .scaleProportionallyDown
        name.lineBreakMode = .byTruncatingTail
        detail.font = .systemFont(ofSize: 10)
        detail.textColor = .secondaryLabelColor
        detail.lineBreakMode = .byTruncatingTail
        for x in [visible, thumb, name, detail] as [NSView] { x.translatesAutoresizingMaskIntoConstraints = false; addSubview(x) }
        NSLayoutConstraint.activate([
            visible.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 4), visible.centerYAnchor.constraint(equalTo: centerYAnchor),
            thumb.leadingAnchor.constraint(equalTo: visible.trailingAnchor, constant: 4), thumb.centerYAnchor.constraint(equalTo: centerYAnchor),
            thumb.widthAnchor.constraint(equalToConstant: 48), thumb.heightAnchor.constraint(equalToConstant: 36),
            name.leadingAnchor.constraint(equalTo: thumb.trailingAnchor, constant: 8),
            name.trailingAnchor.constraint(lessThanOrEqualTo: trailingAnchor, constant: -4),
            name.bottomAnchor.constraint(equalTo: centerYAnchor, constant: 1),
            detail.leadingAnchor.constraint(equalTo: name.leadingAnchor),
            detail.trailingAnchor.constraint(lessThanOrEqualTo: trailingAnchor, constant: -4),
            detail.topAnchor.constraint(equalTo: centerYAnchor, constant: 1),
        ])
        textField = name
        imageView = thumb
    }

    required init?(coder: NSCoder) { fatalError("nicht verwendet") }

    func configure(_ layer: Layer) {
        visible.state = layer.isVisible ? .on : .off
        name.stringValue = layer.name
        var d: [String] = []
        if layer.opacity != 255 { d.append("Deckkraft \(Int((Double(layer.opacity) / 255 * 100).rounded())) %") }
        if layer.blendMode != .normal { d.append(layer.blendMode.displayName) }
        if !layer.isVisible { d.append("ausgeblendet") }
        detail.stringValue = d.joined(separator: " · ")
        let t = ImageRendering.thumbnail(of: layer, maxSide: 72)
        let s = min(48 / max(1, t.size.width), 36 / max(1, t.size.height), 1)
        let size = NSSize(width: max(1, (t.size.width * s).rounded()), height: max(1, (t.size.height * s).rounded()))
        thumb.image = NSImage(size: size, flipped: false) { r in ImageRendering.drawWithCheckerboard(t, in: r); return true }
    }
}
