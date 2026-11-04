import AppKit
import EditorCore
import EditorDocument

/// Hauptfenster: Werkzeugleiste (zwei Zeilen), Bildregister, Zeichenfläche, Statusleiste.
final class MainWindowController: NSWindowController, NSWindowDelegate {
    let canvas = CanvasController()
    let toolbarRow = CommandToolbar()
    let toolOptions = ToolOptionsBar()
    let tabs = ImageTabsView()
    let statusBar = StatusBarView()

    init() {
        let w = EditorWindow(contentRect: NSRect(x: 0, y: 0, width: 1280, height: 820),
                             styleMask: [.titled, .closable, .miniaturizable, .resizable],
                             backing: .buffered, defer: false)
        w.title = "Bildeditor"
        w.minSize = NSSize(width: 820, height: 520)
        w.isReleasedWhenClosed = false
        w.collectionBehavior = [.fullScreenPrimary]
        super.init(window: w)
        w.delegate = self
        buildLayout()
        if !w.setFrameUsingName("Hauptfenster") { w.center() }
        w.setFrameAutosaveName("Hauptfenster")
        w.initialFirstResponder = canvas.canvasView

        let nc = NotificationCenter.default
        nc.addObserver(self, selector: #selector(documentsChanged), name: .documentsChanged, object: nil)
        nc.addObserver(self, selector: #selector(documentChanged(_:)), name: .documentChanged, object: nil)
        nc.addObserver(self, selector: #selector(viewSettingsChanged), name: .viewSettingsChanged, object: nil)
        nc.addObserver(self, selector: #selector(toolChanged), name: .toolChanged, object: nil)
        nc.addObserver(self, selector: #selector(refreshControls), name: .panelVisibilityChanged, object: nil)
        nc.addObserver(self, selector: #selector(refreshControls), name: NSApplication.didBecomeActiveNotification, object: nil)

        canvas.onPointerMoved = { [weak self] p in self?.statusBar.setPointer(p) }
        canvas.onZoomChanged = { [weak self] in self?.statusBar.refresh(); self?.toolbarRow.refresh() }
        documentsChanged()
        toolChanged()
    }

    required init?(coder: NSCoder) { fatalError("nicht verwendet") }

    private func buildLayout() {
        let root = NSView()
        window!.contentView = root
        let views: [NSView] = [toolbarRow, toolOptions, tabs, canvas.scrollView, statusBar]
        let separators = (0..<4).map { _ -> NSBox in let b = NSBox(); b.boxType = .separator; return b }
        for v in views + separators { v.translatesAutoresizingMaskIntoConstraints = false; root.addSubview(v) }
        var c: [NSLayoutConstraint] = []
        for v in views + separators {
            c += [v.leadingAnchor.constraint(equalTo: root.leadingAnchor), v.trailingAnchor.constraint(equalTo: root.trailingAnchor)]
        }
        c += [
            toolbarRow.topAnchor.constraint(equalTo: root.topAnchor),
            toolbarRow.heightAnchor.constraint(equalToConstant: 38),
            separators[0].topAnchor.constraint(equalTo: toolbarRow.bottomAnchor),
            toolOptions.topAnchor.constraint(equalTo: separators[0].bottomAnchor),
            toolOptions.heightAnchor.constraint(equalToConstant: 34),
            separators[1].topAnchor.constraint(equalTo: toolOptions.bottomAnchor),
            tabs.topAnchor.constraint(equalTo: separators[1].bottomAnchor),
            tabs.heightAnchor.constraint(equalToConstant: ImageTabsView.height),
            separators[2].topAnchor.constraint(equalTo: tabs.bottomAnchor),
            canvas.scrollView.topAnchor.constraint(equalTo: separators[2].bottomAnchor),
            separators[3].topAnchor.constraint(equalTo: canvas.scrollView.bottomAnchor),
            statusBar.topAnchor.constraint(equalTo: separators[3].bottomAnchor),
            statusBar.heightAnchor.constraint(equalToConstant: 28),
            statusBar.bottomAnchor.constraint(equalTo: root.bottomAnchor),
        ]
        NSLayoutConstraint.activate(c)
    }

    // MARK: Ansichtszustand

    func rememberViewState() { canvas.rememberViewState() }
    func forgetViewState() { }

    // MARK: Benachrichtigungen

    @objc private func documentsChanged() {
        let s = AppController.shared.active
        canvas.showActiveSession()
        tabs.reload()
        statusBar.refresh()
        updateTitle()
        refreshControls()
        _ = s
    }

    @objc private func documentChanged(_ n: Notification) {
        guard let s = n.object as? DocumentSession, let change = n.userInfo?["change"] as? Document.Change else { return }
        if s === AppController.shared.active {
            canvas.documentChanged(change)
            if change == .size { statusBar.refresh() }
            updateTitle()
            refreshControls()
        }
        tabs.update(s)
    }

    @objc private func viewSettingsChanged() {
        canvas.canvasView.needsDisplay = true
        statusBar.refresh()
        toolbarRow.refresh()
    }

    @objc private func toolChanged() {
        canvas.toolChanged()
        toolOptions.refresh()
        statusBar.setHint(AppController.shared.tool.statusHint)
    }

    @objc func refreshControls() {
        toolbarRow.refresh()
    }

    /// Kurzzeitiger Hinweis in der Statusleiste (z. B. für nicht verfügbare Werkzeuge).
    func showTransientHint(_ text: String) {
        statusBar.setHint(text)
        DispatchQueue.main.asyncAfter(deadline: .now() + 3) { [weak self] in
            self?.statusBar.setHint(AppController.shared.tool.statusHint)
        }
    }

    private func updateTitle() {
        guard let w = window else { return }
        if let d = AppController.shared.document {
            w.title = "\(d.displayName) – Bildeditor"
            w.representedURL = d.fileURL
            w.isDocumentEdited = d.isDirty
        } else {
            w.title = "Bildeditor"
            w.representedURL = nil
            w.isDocumentEdited = false
        }
    }

    // MARK: NSWindowDelegate

    /// Hauptfenster schließen = Programm beenden (ein Fenster für alle Bilder, wie Referenz).
    func windowShouldClose(_ sender: NSWindow) -> Bool {
        NSApp.terminate(nil)
        return false
    }
}

/// Obere Werkzeugleiste: häufige Befehle, Ansichtsschalter und die Fensterschalter rechts.
final class CommandToolbar: NSView {
    private struct Entry { let id: String; let symbol: String; let toggle: Bool }
    private var buttons: [(Entry, NSButton)] = []

    private static let left: [[Entry]] = [
        [Entry(id: "file.new", symbol: "doc.badge.plus", toggle: false), Entry(id: "file.open", symbol: "folder", toggle: false),
         Entry(id: "file.save", symbol: "square.and.arrow.down", toggle: false), Entry(id: "file.print", symbol: "printer", toggle: false)],
        [Entry(id: "edit.cut", symbol: "scissors", toggle: false), Entry(id: "edit.copy", symbol: "doc.on.doc", toggle: false),
         Entry(id: "edit.paste", symbol: "doc.on.clipboard", toggle: false)],
        [Entry(id: "image.crop", symbol: "crop", toggle: false), Entry(id: "edit.deselect", symbol: "rectangle.slash", toggle: false)],
        [Entry(id: "edit.undo", symbol: "arrow.uturn.backward", toggle: false), Entry(id: "edit.redo", symbol: "arrow.uturn.forward", toggle: false)],
        [Entry(id: "view.pixelGrid", symbol: "grid", toggle: true), Entry(id: "view.rulers", symbol: "ruler", toggle: true)],
    ]
    private static let right: [Entry] = PanelID.allCases.map { Entry(id: "window.\($0.rawValue)", symbol: $0.symbol, toggle: true) }

    override init(frame: NSRect) {
        super.init(frame: frame)
        let leftStack = NSStackView()
        leftStack.orientation = .horizontal
        leftStack.spacing = 2
        for (gi, group) in Self.left.enumerated() {
            if gi > 0 { leftStack.addArrangedSubview(Self.divider()) }
            for e in group { leftStack.addArrangedSubview(makeButton(e)) }
        }
        let rightStack = NSStackView()
        rightStack.orientation = .horizontal
        rightStack.spacing = 2
        for e in Self.right { rightStack.addArrangedSubview(makeButton(e)) }
        for v in [leftStack, rightStack] { v.translatesAutoresizingMaskIntoConstraints = false; addSubview(v) }
        NSLayoutConstraint.activate([
            leftStack.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 8),
            leftStack.centerYAnchor.constraint(equalTo: centerYAnchor),
            rightStack.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -8),
            rightStack.centerYAnchor.constraint(equalTo: centerYAnchor),
            rightStack.leadingAnchor.constraint(greaterThanOrEqualTo: leftStack.trailingAnchor, constant: 12),
        ])
    }

    required init?(coder: NSCoder) { fatalError("nicht verwendet") }

    private static func divider() -> NSView {
        let b = NSBox(); b.boxType = .separator
        b.translatesAutoresizingMaskIntoConstraints = false
        b.widthAnchor.constraint(equalToConstant: 1).isActive = true
        b.heightAnchor.constraint(equalToConstant: 20).isActive = true
        return b
    }

    private func makeButton(_ e: Entry) -> NSButton {
        let reg = AppController.shared.commands
        let c = reg[e.id]
        let img = NSImage(systemSymbolName: e.symbol, accessibilityDescription: c?.title)
        let b = NSButton(image: img ?? NSImage(), target: reg, action: #selector(CommandRegistry.performMenuCommand(_:)))
        if img == nil { b.title = String((c?.title ?? "?").prefix(2)) }
        b.identifier = NSUserInterfaceItemIdentifier(e.id)
        b.bezelStyle = .recessed
        b.showsBorderOnlyWhileMouseInside = !e.toggle
        b.setButtonType(e.toggle ? .pushOnPushOff : .momentaryPushIn)
        b.imagePosition = .imageOnly
        b.toolTip = c.map { cmd in
            var t = cmd.title.replacingOccurrences(of: " …", with: "")
            if let s = cmd.shortcut { t += " (\(ShortcutFormatter.string(s)))" }
            if !cmd.isImplemented { t += " – " + cmd.notImplementedHint }
            return t
        }
        b.translatesAutoresizingMaskIntoConstraints = false
        b.widthAnchor.constraint(equalToConstant: 30).isActive = true
        b.heightAnchor.constraint(equalToConstant: 26).isActive = true
        buttons.append((e, b))
        return b
    }

    func refresh() {
        let reg = AppController.shared.commands
        for (e, b) in buttons {
            guard let c = reg[e.id] else { b.isEnabled = false; continue }
            b.isEnabled = c.canRun
            if e.toggle { b.state = (c.isChecked?() ?? false) ? .on : .off }
        }
    }

    /// Für den Selbsttest: alle Knöpfe mit Befehls-ID und Zustand.
    var buttonStates: [(id: String, enabled: Bool)] { buttons.map { ($0.0.id, $0.1.isEnabled) } }
}

/// Zweite Werkzeugleisten-Zeile: Werkzeugauswahl und werkzeugspezifische Einstellungen.
final class ToolOptionsBar: NSView {
    let toolPopup = NSPopUpButton(frame: .zero, pullsDown: false)
    private let optionsLabel = NSTextField(labelWithString: "")

    override init(frame: NSRect) {
        super.init(frame: frame)
        let toolLabel = NSTextField(labelWithString: "Werkzeug:")
        toolPopup.menu?.autoenablesItems = false
        for t in Tool.allCases {
            toolPopup.addItem(withTitle: t.title)
            let it = toolPopup.lastItem!
            it.image = t.image
            it.representedObject = t.rawValue
            it.isEnabled = t.isImplemented
            it.toolTip = t.tooltip
        }
        toolPopup.target = self
        toolPopup.action = #selector(pick)
        toolPopup.controlSize = .small
        optionsLabel.textColor = .secondaryLabelColor
        optionsLabel.lineBreakMode = .byTruncatingTail
        optionsLabel.font = .systemFont(ofSize: 11)
        let stack = NSStackView(views: [toolLabel, toolPopup, optionsLabel])
        stack.orientation = .horizontal
        stack.spacing = 8
        stack.translatesAutoresizingMaskIntoConstraints = false
        addSubview(stack)
        NSLayoutConstraint.activate([
            stack.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 10),
            stack.trailingAnchor.constraint(lessThanOrEqualTo: trailingAnchor, constant: -10),
            stack.centerYAnchor.constraint(equalTo: centerYAnchor),
        ])
        refresh()
    }

    required init?(coder: NSCoder) { fatalError("nicht verwendet") }

    @objc private func pick() {
        guard let raw = toolPopup.selectedItem?.representedObject as? String, let t = Tool(rawValue: raw), t.isImplemented else { refresh(); return }
        AppController.shared.tool = t
    }

    func refresh() {
        let t = AppController.shared.tool
        if let i = Tool.allCases.firstIndex(of: t) { toolPopup.selectItem(at: i) }
        switch t {
        case .zoom: optionsLabel.stringValue = "Keine Einstellungen. Tipp: Leertaste gedrückt halten = Hand, ⌘ + Mausrad = Zoom."
        case .pan: optionsLabel.stringValue = "Keine Einstellungen. Mittlere Maustaste verschiebt bei jedem Werkzeug."
        default: optionsLabel.stringValue = ""
        }
    }
}

/// Lesbare Darstellung von Tastenkürzeln (⌘⇧⌥⌃).
enum ShortcutFormatter {
    static func string(_ s: Shortcut) -> String {
        var r = ""
        if s.modifiers.contains(.control) { r += "⌃" }
        if s.modifiers.contains(.option) { r += "⌥" }
        if s.modifiers.contains(.shift) { r += "⇧" }
        if s.modifiers.contains(.command) { r += "⌘" }
        let special: [Int: String] = [NSRightArrowFunctionKey: "→", NSLeftArrowFunctionKey: "←", NSPageUpFunctionKey: "⇞",
                                      NSPageDownFunctionKey: "⇟", 8: "⌫", 9: "⇥", NSF1FunctionKey: "F1", NSF4FunctionKey: "F4",
                                      NSF5FunctionKey: "F5", NSF6FunctionKey: "F6", NSF7FunctionKey: "F7", NSF8FunctionKey: "F8"]
        if let u = s.key.unicodeScalars.first, let sp = special[Int(u.value)] { return r + sp }
        return r + s.key.uppercased()
    }
}
