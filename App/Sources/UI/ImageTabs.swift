import AppKit

/// Bildregister mit Vorschaubildern (Referenz: Bildliste oben rechts). Klick wählt, × schließt, Rechtsklick öffnet das Kontextmenü.
final class ImageTabsView: NSView {
    static let height: CGFloat = 70
    private let scroll = NSScrollView()
    private let stack = NSStackView()
    private var items: [ObjectIdentifier: ImageTabItem] = [:]

    override init(frame: NSRect) {
        super.init(frame: frame)
        stack.orientation = .horizontal
        stack.spacing = 4
        stack.edgeInsets = NSEdgeInsets(top: 4, left: 8, bottom: 4, right: 8)
        stack.translatesAutoresizingMaskIntoConstraints = false
        let doc = FlippedView()
        doc.translatesAutoresizingMaskIntoConstraints = false
        doc.addSubview(stack)
        scroll.documentView = doc
        scroll.hasHorizontalScroller = true
        scroll.autohidesScrollers = true
        scroll.drawsBackground = false
        scroll.translatesAutoresizingMaskIntoConstraints = false
        addSubview(scroll)
        NSLayoutConstraint.activate([
            scroll.leadingAnchor.constraint(equalTo: leadingAnchor), scroll.trailingAnchor.constraint(equalTo: trailingAnchor),
            scroll.topAnchor.constraint(equalTo: topAnchor), scroll.bottomAnchor.constraint(equalTo: bottomAnchor),
            stack.leadingAnchor.constraint(equalTo: doc.leadingAnchor), stack.topAnchor.constraint(equalTo: doc.topAnchor),
            stack.bottomAnchor.constraint(equalTo: doc.bottomAnchor), stack.trailingAnchor.constraint(equalTo: doc.trailingAnchor),
            doc.heightAnchor.constraint(equalTo: scroll.contentView.heightAnchor),
            doc.leadingAnchor.constraint(equalTo: scroll.contentView.leadingAnchor),
            doc.topAnchor.constraint(equalTo: scroll.contentView.topAnchor),
        ])
    }

    required init?(coder: NSCoder) { fatalError("nicht verwendet") }

    /// Liste neu aufbauen (Öffnen, Schließen, Wechsel).
    func reload() {
        let ctrl = AppController.shared
        for v in stack.arrangedSubviews { stack.removeArrangedSubview(v); v.removeFromSuperview() }
        var newItems: [ObjectIdentifier: ImageTabItem] = [:]
        for s in ctrl.sessions {
            let item = items[ObjectIdentifier(s)] ?? ImageTabItem(session: s)
            item.isActive = s === ctrl.active
            item.refresh()
            stack.addArrangedSubview(item)
            newItems[ObjectIdentifier(s)] = item
        }
        items = newItems
        if let a = ctrl.active, let item = items[ObjectIdentifier(a)] {
            DispatchQueue.main.async { item.scrollToVisible(item.bounds) }
        }
    }

    func update(_ s: DocumentSession) { items[ObjectIdentifier(s)]?.refresh() }

    var tabTitles: [String] { stack.arrangedSubviews.compactMap { ($0 as? ImageTabItem)?.session.title } }
}

final class FlippedView: NSView { override var isFlipped: Bool { true } }

final class ImageTabItem: NSView {
    let session: DocumentSession
    var isActive = false { didSet { needsDisplay = true } }
    private let thumb = NSImageView()
    private let label = NSTextField(labelWithString: "")
    private let closeButton = NSButton()
    private let dirtyDot = NSTextField(labelWithString: "●")

    init(session: DocumentSession) {
        self.session = session
        super.init(frame: .zero)
        translatesAutoresizingMaskIntoConstraints = false
        thumb.imageScaling = .scaleProportionallyDown
        label.font = .systemFont(ofSize: 11)
        label.lineBreakMode = .byTruncatingMiddle
        label.alignment = .center
        dirtyDot.font = .systemFont(ofSize: 9)
        dirtyDot.textColor = .controlAccentColor
        closeButton.image = NSImage(systemSymbolName: "xmark.circle.fill", accessibilityDescription: "Schließen")
        closeButton.isBordered = false
        closeButton.imagePosition = .imageOnly
        closeButton.contentTintColor = .secondaryLabelColor
        closeButton.target = self
        closeButton.action = #selector(closeClicked)
        closeButton.toolTip = "Bild schließen"
        for v in [thumb, label, closeButton, dirtyDot] as [NSView] { v.translatesAutoresizingMaskIntoConstraints = false; addSubview(v) }
        NSLayoutConstraint.activate([
            widthAnchor.constraint(equalToConstant: 104),
            heightAnchor.constraint(equalToConstant: 62),
            thumb.topAnchor.constraint(equalTo: topAnchor, constant: 4),
            thumb.centerXAnchor.constraint(equalTo: centerXAnchor),
            thumb.widthAnchor.constraint(equalToConstant: 56), thumb.heightAnchor.constraint(equalToConstant: 40),
            label.topAnchor.constraint(equalTo: thumb.bottomAnchor, constant: 1),
            label.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 4),
            label.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -4),
            closeButton.topAnchor.constraint(equalTo: topAnchor, constant: 2),
            closeButton.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -2),
            closeButton.widthAnchor.constraint(equalToConstant: 16), closeButton.heightAnchor.constraint(equalToConstant: 16),
            dirtyDot.topAnchor.constraint(equalTo: topAnchor, constant: 2),
            dirtyDot.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 4),
        ])
        menu = makeMenu()
    }

    required init?(coder: NSCoder) { fatalError("nicht verwendet") }

    func refresh() {
        thumb.image = checkerThumb()
        label.stringValue = session.title
        dirtyDot.isHidden = !session.document.needsSavePrompt
        toolTip = session.document.fileURL?.path ?? session.title
        needsDisplay = true
    }

    private func checkerThumb() -> NSImage {
        let t = session.thumbnail
        let box = NSSize(width: 56, height: 40)
        let s = min(box.width / max(1, t.size.width), box.height / max(1, t.size.height), 1)
        let size = NSSize(width: max(1, (t.size.width * s).rounded()), height: max(1, (t.size.height * s).rounded()))
        return NSImage(size: size, flipped: false) { r in
            ImageRendering.drawWithCheckerboard(t, in: r)
            return true
        }
    }

    override func draw(_ dirtyRect: NSRect) {
        if isActive {
            NSColor.controlAccentColor.withAlphaComponent(0.22).setFill()
            NSBezierPath(roundedRect: bounds.insetBy(dx: 1, dy: 1), xRadius: 6, yRadius: 6).fill()
            NSColor.controlAccentColor.setStroke()
            let p = NSBezierPath(roundedRect: bounds.insetBy(dx: 1, dy: 1), xRadius: 6, yRadius: 6)
            p.lineWidth = 1.5
            p.stroke()
        }
    }

    override func mouseDown(with event: NSEvent) { AppController.shared.activate(session) }

    @objc private func closeClicked() { AppController.shared.close(session) }

    private func makeMenu() -> NSMenu {
        let m = NSMenu()
        func add(_ t: String, _ sel: Selector) { let it = m.addItem(withTitle: t, action: sel, keyEquivalent: ""); it.target = self }
        add("Pfad kopieren", #selector(copyPath))
        add("Im Finder zeigen", #selector(revealInFinder))
        m.addItem(.separator())
        add("Speichern", #selector(saveItem))
        add("Speichern unter …", #selector(saveAsItem))
        m.addItem(.separator())
        add("Schließen", #selector(closeClicked))
        return m
    }

    @objc private func copyPath() {
        guard let p = session.document.fileURL?.path else { NSSound.beep(); return }
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(p, forType: .string)
    }
    @objc private func revealInFinder() {
        guard let u = session.document.fileURL else { NSSound.beep(); return }
        NSWorkspace.shared.activateFileViewerSelecting([u])
    }
    @objc private func saveItem() { AppController.shared.activate(session); AppController.shared.save(session, askForLocation: false) }
    @objc private func saveAsItem() { AppController.shared.activate(session); AppController.shared.save(session, askForLocation: true) }

    @objc func validateMenuItem(_ item: NSMenuItem) -> Bool {
        if item.action == #selector(copyPath) || item.action == #selector(revealInFinder) { return session.document.fileURL != nil }
        return true
    }
}
