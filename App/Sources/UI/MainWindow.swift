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
        canvas.onSelectionInfo = { [weak self] size in self?.statusBar.setSelectionSize(size) }
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
            w.isDocumentEdited = d.needsSavePrompt
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
        b.showsBorderOnlyWhileMouseInside = true
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
            if e.toggle {
                let on = c.isChecked?() ?? false
                b.state = on ? .on : .off
                b.contentTintColor = on ? .controlAccentColor : nil
                b.showsBorderOnlyWhileMouseInside = !on
            }
        }
    }

    /// Für den Selbsttest: alle Knöpfe mit Befehls-ID und Zustand.
    var buttonStates: [(id: String, enabled: Bool)] { buttons.map { ($0.0.id, $0.1.isEnabled) } }
}

/// Zweite Werkzeugleisten-Zeile: Werkzeugauswahl und werkzeugspezifische Einstellungen.
final class ToolOptionsBar: NSView {
    let toolPopup = NSPopUpButton(frame: .zero, pullsDown: false)
    private let optionsLabel = NSTextField(labelWithString: "")
    // Auswahlwerkzeuge
    let modeControl = NSSegmentedControl(labels: SelectionMode.allCases.map { ToolOptionsBar.shortName($0) }, trackingMode: .selectOne, target: nil, action: nil)
    let floodPopup = NSPopUpButton(frame: .zero, pullsDown: false)
    let samplePopup = NSPopUpButton(frame: .zero, pullsDown: false)
    let toleranceSlider = NSSlider(value: 50, minValue: 0, maxValue: 100, target: nil, action: nil)
    private let toleranceLabel = NSTextField(labelWithString: "50 %")
    let finishButton = NSButton(title: "Fertigstellen", target: nil, action: nil)
    // Malwerkzeuge
    let widthField = NSTextField(string: "10")
    let widthStepper = NSStepper()
    let antialiasBox = NSButton(checkboxWithTitle: "Kantenglättung", target: nil, action: nil)
    let blendPopup = NSPopUpButton(frame: .zero, pullsDown: false)
    let pickerSizePopup = NSPopUpButton(frame: .zero, pullsDown: false)
    let pickerSourcePopup = NSPopUpButton(frame: .zero, pullsDown: false)
    let pickerAfterPopup = NSPopUpButton(frame: .zero, pullsDown: false)
    private var brushGroup: NSStackView!
    private var blendGroup: NSStackView!
    private var pickerGroup: NSStackView!
    // Verlauf, Linie, Formen
    let gradientKindPopup = NSPopUpButton(frame: .zero, pullsDown: false)
    let gradientModePopup = NSPopUpButton(frame: .zero, pullsDown: false)
    let gradientRepeatPopup = NSPopUpButton(frame: .zero, pullsDown: false)
    let shapeKindPopup = NSPopUpButton(frame: .zero, pullsDown: false)
    let shapeStylePopup = NSPopUpButton(frame: .zero, pullsDown: false)
    let dashPopup = NSPopUpButton(frame: .zero, pullsDown: false)
    let arrowStartBox = NSButton(checkboxWithTitle: "Pfeil am Anfang", target: nil, action: nil)
    let arrowEndBox = NSButton(checkboxWithTitle: "Pfeil am Ende", target: nil, action: nil)
    private var gradientGroup: NSStackView!
    private var shapeGroup: NSStackView!
    private var lineGroup: NSStackView!
    private var tolGroup: NSStackView!
    // Text
    let fontPopup = NSPopUpButton(frame: .zero, pullsDown: false)
    let fontSizeField = NSTextField(string: "24")
    let boldButton = NSButton(title: "F", target: nil, action: nil)
    let italicButton = NSButton(title: "K", target: nil, action: nil)
    let underlineButton = NSButton(title: "U", target: nil, action: nil)
    let alignControl = NSSegmentedControl(labels: ["Links", "Mitte", "Rechts"], trackingMode: .selectOne, target: nil, action: nil)
    let textAntialiasBox = NSButton(checkboxWithTitle: "Kantenglättung", target: nil, action: nil)
    private var textGroup: NSStackView!
    private var modeGroup: NSStackView!
    private var wandGroup: NSStackView!
    private var stack: NSStackView!

    /// Für den Selbsttest: Gruppe sichtbar und nicht wegen Platzmangel ausgeblendet.
    var isWandGroupShown: Bool { !wandGroup.isHidden && !stack.detachedViews.contains(wandGroup) }
    var isModeGroupShown: Bool { !modeGroup.isHidden && !stack.detachedViews.contains(modeGroup) }

    static func shortName(_ m: SelectionMode) -> String {
        // Kurz, damit auch schmale Fenster Platz für die Zauberstab-Optionen haben; Klartext im Tooltip.
        switch m { case .replace: return "Ersetzen"; case .union: return "＋"; case .exclude: return "−"
        case .intersect: return "∩"; case .xor: return "⊕" }
    }

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
        optionsLabel.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)

        modeControl.controlSize = .small
        modeControl.target = self; modeControl.action = #selector(modeChanged)
        for (i, m) in SelectionMode.allCases.enumerated() { modeControl.setToolTip("Auswahlmodus: \(m.displayName)", forSegment: i) }
        let modeLabel = NSTextField(labelWithString: "Auswahlmodus:")
        modeLabel.font = .systemFont(ofSize: 11)
        modeGroup = NSStackView(views: [modeLabel, modeControl])
        modeGroup.spacing = 4

        floodPopup.addItems(withTitles: ["Zusammenhängend", "Global"])
        floodPopup.controlSize = .small
        floodPopup.target = self; floodPopup.action = #selector(wandChanged)
        floodPopup.toolTip = "Flutmodus (⇧ beim Klicken kehrt ihn um)"
        samplePopup.addItems(withTitles: ["Aus Ebene", "Aus Bild"])
        samplePopup.controlSize = .small
        samplePopup.target = self; samplePopup.action = #selector(wandChanged)
        samplePopup.toolTip = "Farben aus der aktiven Ebene oder dem ganzen Bild vergleichen"
        toleranceSlider.controlSize = .small
        toleranceSlider.isContinuous = true
        toleranceSlider.target = self; toleranceSlider.action = #selector(wandChanged)
        toleranceSlider.widthAnchor.constraint(equalToConstant: 110).isActive = true
        toleranceLabel.font = .monospacedDigitSystemFont(ofSize: 11, weight: .regular)
        toleranceLabel.widthAnchor.constraint(equalToConstant: 40).isActive = true
        let tolTitle = NSTextField(labelWithString: "Toleranz:"); tolTitle.font = .systemFont(ofSize: 11)
        let floodTitle = NSTextField(labelWithString: "Flutmodus:"); floodTitle.font = .systemFont(ofSize: 11)
        let sampleTitle = NSTextField(labelWithString: "Stichprobe:"); sampleTitle.font = .systemFont(ofSize: 11)
        wandGroup = NSStackView(views: [floodPopup, samplePopup])
        tolGroup = NSStackView(views: [tolTitle, toleranceSlider, toleranceLabel])
        tolGroup.spacing = 4
        _ = (floodTitle, sampleTitle)
        wandGroup.spacing = 4

        // Pinselbreite, Kantenglättung, Mischmodus
        let wTitle = NSTextField(labelWithString: "Breite:"); wTitle.font = .systemFont(ofSize: 11)
        widthField.controlSize = .small
        widthField.font = .monospacedDigitSystemFont(ofSize: 11, weight: .regular)
        widthField.alignment = .right
        widthField.widthAnchor.constraint(equalToConstant: 48).isActive = true
        widthField.target = self; widthField.action = #selector(widthEntered)
        widthField.toolTip = "Pinselbreite in Pixeln (1–2000)"
        widthStepper.minValue = 1; widthStepper.maxValue = 2000; widthStepper.increment = 1
        widthStepper.valueWraps = false; widthStepper.autorepeat = true; widthStepper.controlSize = .small
        widthStepper.target = self; widthStepper.action = #selector(widthStepped)
        antialiasBox.controlSize = .small; antialiasBox.font = .systemFont(ofSize: 11)
        antialiasBox.target = self; antialiasBox.action = #selector(antialiasToggled)
        brushGroup = NSStackView(views: [wTitle, widthField, widthStepper, antialiasBox])
        brushGroup.spacing = 4
        blendPopup.controlSize = .small
        for m in BlendMode.allCases { blendPopup.addItem(withTitle: m.displayName); blendPopup.lastItem?.representedObject = m.rawValue }
        blendPopup.menu?.addItem(.separator())
        blendPopup.addItem(withTitle: "Überschreiben"); blendPopup.lastItem?.representedObject = "ueberschreiben"
        blendPopup.target = self; blendPopup.action = #selector(blendChanged)
        blendPopup.toolTip = "Mischmodus beim Auftragen; „Überschreiben“ ersetzt Pixel einschließlich Deckkraft"
        let bTitle = NSTextField(labelWithString: "Mischmodus:"); bTitle.font = .systemFont(ofSize: 11)
        blendGroup = NSStackView(views: [bTitle, blendPopup])
        blendGroup.spacing = 4
        // Farbpipette
        pickerSizePopup.controlSize = .small
        for n in [1, 3, 5, 7, 9] { pickerSizePopup.addItem(withTitle: n == 1 ? "Einzelnes Pixel" : "\(n) × \(n) Bereich"); pickerSizePopup.lastItem?.tag = n }
        pickerSourcePopup.controlSize = .small
        pickerSourcePopup.addItems(withTitles: ["Aus Ebene", "Aus Bild"])
        pickerAfterPopup.controlSize = .small
        pickerAfterPopup.addItems(withTitles: ["Werkzeug beibehalten", "Zum vorigen Werkzeug", "Zum Stift wechseln"])
        for p in [pickerSizePopup, pickerSourcePopup, pickerAfterPopup] { p.target = self; p.action = #selector(pickerChanged) }
        let aTitle = NSTextField(labelWithString: "Danach:"); aTitle.font = .systemFont(ofSize: 11)
        pickerGroup = NSStackView(views: [pickerSizePopup, pickerSourcePopup, aTitle, pickerAfterPopup])
        pickerGroup.spacing = 4

        for (p, items) in [(gradientKindPopup, GradientKind.allCases.map(\.displayName)), (gradientModePopup, ["Farbmodus", "Transparenzmodus"]),
                           (gradientRepeatPopup, GradientRepeat.allCases.map(\.displayName)), (shapeKindPopup, ShapeKind.allCases.map(\.displayName)),
                           (shapeStylePopup, ShapeStyle.allCases.map(\.displayName)), (dashPopup, DashStyle.allCases.map(\.displayName))] {
            p.controlSize = .small
            p.addItems(withTitles: items)
            p.target = self; p.action = #selector(shapeOptionsChanged)
        }
        for b in [arrowStartBox, arrowEndBox] {
            b.controlSize = .small; b.font = .systemFont(ofSize: 11); b.target = self; b.action = #selector(shapeOptionsChanged)
        }
        fontPopup.controlSize = .small
        fontPopup.addItems(withTitles: NSFontManager.shared.availableFontFamilies.sorted())
        fontSizeField.controlSize = .small
        fontSizeField.alignment = .right
        fontSizeField.font = .monospacedDigitSystemFont(ofSize: 11, weight: .regular)
        fontSizeField.widthAnchor.constraint(equalToConstant: 44).isActive = true
        fontSizeField.toolTip = "Schriftgröße in Pixeln"
        for (b, tip) in [(boldButton, "Fett"), (italicButton, "Kursiv"), (underlineButton, "Unterstrichen")] {
            b.setButtonType(.pushOnPushOff); b.bezelStyle = .recessed; b.controlSize = .small; b.toolTip = tip
        }
        boldButton.font = .boldSystemFont(ofSize: 11)
        italicButton.font = NSFontManager.shared.convert(.systemFont(ofSize: 11), toHaveTrait: .italicFontMask)
        alignControl.controlSize = .small
        textAntialiasBox.controlSize = .small; textAntialiasBox.font = .systemFont(ofSize: 11)
        for c in [fontPopup, fontSizeField, boldButton, italicButton, underlineButton, alignControl, textAntialiasBox] as [NSControl] {
            c.target = self; c.action = #selector(textOptionsChanged)
        }
        textGroup = NSStackView(views: [fontPopup, fontSizeField, boldButton, italicButton, underlineButton, alignControl, textAntialiasBox])
        textGroup.spacing = 4

        gradientGroup = NSStackView(views: [gradientKindPopup, gradientModePopup, gradientRepeatPopup])
        gradientGroup.spacing = 4
        shapeGroup = NSStackView(views: [shapeKindPopup, shapeStylePopup])
        shapeGroup.spacing = 4
        lineGroup = NSStackView(views: [dashPopup, arrowStartBox, arrowEndBox])
        lineGroup.spacing = 4

        finishButton.controlSize = .small
        finishButton.bezelStyle = .rounded
        finishButton.target = self; finishButton.action = #selector(finish)
        finishButton.toolTip = "Schwebende Pixel einmischen (Eingabetaste)"

        stack = NSStackView()
        stack.setViews([toolLabel, toolPopup, modeGroup, textGroup, gradientGroup, shapeGroup, brushGroup, lineGroup, wandGroup, tolGroup, blendGroup, pickerGroup,
                        finishButton, optionsLabel], in: .leading)
        // Gruppen nicht dehnen (sonst große Lücken); nur der Hinweistext nimmt Restplatz
        stack.setVisibilityPriority(NSStackView.VisibilityPriority(rawValue: 600), for: tolGroup)
        for g in [modeGroup, brushGroup, wandGroup, tolGroup, blendGroup, pickerGroup, gradientGroup, shapeGroup, lineGroup, textGroup] as [NSStackView] {
            g.setHuggingPriority(.required, for: .horizontal)
        }
        optionsLabel.setContentHuggingPriority(.defaultLow, for: .horizontal)
        stack.orientation = .horizontal
        stack.distribution = .gravityAreas
        stack.spacing = 10
        // Schmale Fenster: zuerst den Hinweistext, dann die Zauberstab-Optionen ausblenden statt das Fenster zu verbreitern.
        stack.setClippingResistancePriority(.defaultLow, for: .horizontal)
        stack.setVisibilityPriority(NSStackView.VisibilityPriority(rawValue: 300), for: optionsLabel)
        stack.setVisibilityPriority(NSStackView.VisibilityPriority(rawValue: 600), for: wandGroup)
        stack.setVisibilityPriority(NSStackView.VisibilityPriority(rawValue: 500), for: modeGroup)
        stack.translatesAutoresizingMaskIntoConstraints = false
        addSubview(stack)
        NSLayoutConstraint.activate([
            stack.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 10),
            // volle Breite, damit ausgeblendete Gruppen beim Vergrößern des Fensters zurückkehren
            stack.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -10),
            stack.centerYAnchor.constraint(equalTo: centerYAnchor),
        ])
        NotificationCenter.default.addObserver(self, selector: #selector(docChanged), name: .documentChanged, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(docChanged), name: .documentsChanged, object: nil)
        refresh()
    }

    required init?(coder: NSCoder) { fatalError("nicht verwendet") }

    @objc private func pick() {
        guard let raw = toolPopup.selectedItem?.representedObject as? String, let t = Tool(rawValue: raw), t.isImplemented else { refresh(); return }
        AppController.shared.tool = t
    }

    @objc private func modeChanged() {
        AppController.shared.selectionMode = SelectionMode.allCases[max(0, modeControl.selectedSegment)]
    }

    @objc private func wandChanged() {
        let c = AppController.shared
        c.wandGlobal = floodPopup.indexOfSelectedItem == 1
        c.wandSampleImage = samplePopup.indexOfSelectedItem == 1
        c.wandTolerance = toleranceSlider.doubleValue / 100
        toleranceLabel.stringValue = "\(Int(toleranceSlider.doubleValue.rounded())) %"
    }

    @objc private func finish() { AppController.shared.finishFloating() }

    @objc private func widthEntered() {
        guard let v = Double(widthField.stringValue.replacingOccurrences(of: ",", with: ".")), v >= 1 else { NSSound.beep(); refresh(); return }
        AppController.shared.brushWidth = min(2000, v)
    }
    @objc private func widthStepped() { AppController.shared.brushWidth = widthStepper.doubleValue }
    @objc private func antialiasToggled() { AppController.shared.antialias = antialiasBox.state == .on }
    @objc private func blendChanged() {
        let raw = blendPopup.selectedItem?.representedObject as? String ?? ""
        AppController.shared.paintBlend = raw == "ueberschreiben" ? .overwrite : .blend(BlendMode(rawValue: raw) ?? .normal)
    }
    @objc private func textOptionsChanged() {
        let c = AppController.shared
        if let f = fontPopup.titleOfSelectedItem { c.textFontFamily = f }
        if let v = Double(fontSizeField.stringValue.replacingOccurrences(of: ",", with: ".")), v >= 1 { c.textSize = v }
        c.textBold = boldButton.state == .on
        c.textItalic = italicButton.state == .on
        c.textUnderline = underlineButton.state == .on
        c.textAlignment = [NSTextAlignment.left, .center, .right][max(0, alignControl.selectedSegment)]
        c.antialias = textAntialiasBox.state == .on
        c.mainWindow?.canvas.text.optionsChanged()
    }

    @objc private func shapeOptionsChanged() {
        let c = AppController.shared
        c.gradientKind = GradientKind.allCases[max(0, gradientKindPopup.indexOfSelectedItem)]
        c.gradientTransparency = gradientModePopup.indexOfSelectedItem == 1
        c.gradientRepeat = GradientRepeat.allCases[max(0, gradientRepeatPopup.indexOfSelectedItem)]
        c.shapeKind = ShapeKind.allCases[max(0, shapeKindPopup.indexOfSelectedItem)]
        c.shapeStyle = ShapeStyle.allCases[max(0, shapeStylePopup.indexOfSelectedItem)]
        c.lineDash = DashStyle.allCases[max(0, dashPopup.indexOfSelectedItem)]
        c.arrowStart = arrowStartBox.state == .on
        c.arrowEnd = arrowEndBox.state == .on
    }

    @objc private func pickerChanged() {
        let c = AppController.shared
        c.pickerSampleSize = pickerSizePopup.selectedItem?.tag ?? 1
        c.pickerSampleImage = pickerSourcePopup.indexOfSelectedItem == 1
        c.pickerAfter = AppController.PickerAfter(rawValue: pickerAfterPopup.indexOfSelectedItem) ?? .stay
    }

    /// Für den Selbsttest: welche Optionsgruppen gerade sichtbar sind.
    var visibleGroups: [String] {
        var r: [String] = []
        if !modeGroup.isHidden { r.append("modus") }
        if !brushGroup.isHidden { r.append("pinsel") }
        if !textGroup.isHidden { r.append("text") }
        if !wandGroup.isHidden { r.append("flut") }
        if !tolGroup.isHidden { r.append("toleranz") }
        if !blendGroup.isHidden { r.append("mischung") }
        if !pickerGroup.isHidden { r.append("pipette") }
        if !gradientGroup.isHidden { r.append("verlauf") }
        if !shapeGroup.isHidden { r.append("form") }
        if !lineGroup.isHidden { r.append("linie") }
        return r
    }

    @objc private func docChanged() { finishButton.isEnabled = AppController.shared.document?.floating != nil }

    func refresh() {
        let c = AppController.shared
        let t = c.tool
        if let i = Tool.allCases.firstIndex(of: t) { toolPopup.selectItem(at: i) }
        modeGroup.isHidden = !t.isSelectionTool
        wandGroup.isHidden = !(t == .magicWand || t == .paintBucket)
        tolGroup.isHidden = !(t == .magicWand || t == .paintBucket || t == .recolor)
        textGroup.isHidden = t != .text
        fontPopup.selectItem(withTitle: c.textFontFamily)
        if fontPopup.selectedItem == nil { fontPopup.selectItem(at: 0) }
        if fontSizeField.currentEditor() == nil { fontSizeField.stringValue = String(Int(c.textSize)) }
        boldButton.state = c.textBold ? .on : .off
        italicButton.state = c.textItalic ? .on : .off
        underlineButton.state = c.textUnderline ? .on : .off
        alignControl.selectedSegment = c.textAlignment == .center ? 1 : (c.textAlignment == .right ? 2 : 0)
        textAntialiasBox.state = c.antialias ? .on : .off
        brushGroup.isHidden = !(t.hasBrushWidth || t == .lineCurve || t == .shapes)
        blendGroup.isHidden = !(t == .paintbrush || t == .pencil || t == .paintBucket || t.isShapeTool || t == .text || t == .cloneStamp)
        gradientGroup.isHidden = t != .gradient
        shapeGroup.isHidden = t != .shapes
        lineGroup.isHidden = t != .lineCurve
        gradientKindPopup.selectItem(at: GradientKind.allCases.firstIndex(of: c.gradientKind) ?? 0)
        gradientModePopup.selectItem(at: c.gradientTransparency ? 1 : 0)
        gradientRepeatPopup.selectItem(at: GradientRepeat.allCases.firstIndex(of: c.gradientRepeat) ?? 0)
        shapeKindPopup.selectItem(at: ShapeKind.allCases.firstIndex(of: c.shapeKind) ?? 0)
        shapeStylePopup.selectItem(at: ShapeStyle.allCases.firstIndex(of: c.shapeStyle) ?? 0)
        dashPopup.selectItem(at: DashStyle.allCases.firstIndex(of: c.lineDash) ?? 0)
        arrowStartBox.state = c.arrowStart ? .on : .off
        arrowEndBox.state = c.arrowEnd ? .on : .off
        pickerGroup.isHidden = t != .colorPicker
        widthField.stringValue = String(Int(c.brushWidth))
        widthStepper.doubleValue = c.brushWidth
        antialiasBox.state = c.antialias ? .on : .off
        switch c.paintBlend {
        case .overwrite: blendPopup.selectItem(at: blendPopup.numberOfItems - 1)
        case let .blend(m): blendPopup.selectItem(at: BlendMode.allCases.firstIndex(of: m) ?? 0)
        }
        pickerSizePopup.selectItem(withTag: c.pickerSampleSize)
        pickerSourcePopup.selectItem(at: c.pickerSampleImage ? 1 : 0)
        pickerAfterPopup.selectItem(at: c.pickerAfter.rawValue)
        finishButton.isHidden = !t.isMoveTool
        finishButton.isEnabled = c.document?.floating != nil
        modeControl.selectedSegment = SelectionMode.allCases.firstIndex(of: c.selectionMode) ?? 0
        floodPopup.selectItem(at: c.wandGlobal ? 1 : 0)
        samplePopup.selectItem(at: c.wandSampleImage ? 1 : 0)
        toleranceSlider.doubleValue = c.wandTolerance * 100
        toleranceLabel.stringValue = "\(Int((c.wandTolerance * 100).rounded())) %"
        switch t {
        case .zoom: optionsLabel.stringValue = "Keine Einstellungen. Tipp: Leertaste gedrückt halten = Hand, ⌘ + Mausrad = Zoom."
        case .pan: optionsLabel.stringValue = "Keine Einstellungen. Mittlere Maustaste verschiebt bei jedem Werkzeug."
        case .moveSelectedPixels: optionsLabel.stringValue = "Drehen und Skalieren folgen später; Verschieben mit Maus oder Pfeiltasten."
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
