import AppKit
import UniformTypeIdentifiers
import EditorCore
import EditorDocument

/// Primär- und Sekundärfarbe mit aktivem Feld (Farbenfenster).
struct ColorState: Equatable {
    var primary: ColorBgra
    var secondary: ColorBgra
    var primaryIsActive = true

    var active: ColorBgra {
        get { primaryIsActive ? primary : secondary }
        set { if primaryIsActive { primary = newValue } else { secondary = newValue } }
    }
    var inactive: ColorBgra {
        get { primaryIsActive ? secondary : primary }
        set { if primaryIsActive { secondary = newValue } else { primary = newValue } }
    }
}

/// Zentrale Steuerung: geöffnete Bilder, aktives Bild, Werkzeug, Farben, Dateioperationen.
final class AppController: NSObject {
    static let shared = AppController()

    let commands = CommandRegistry()
    private(set) var sessions: [DocumentSession] = []
    private(set) var active: DocumentSession?
    var document: Document? { active?.document }

    private(set) var mainWindow: MainWindowController!
    private(set) var panels: PanelManager!
    private var started = false
    /// Im Selbsttest keine modalen Rückfragen.
    var isSelfTest = false

    /// Vorheriges Werkzeug (Farbpipette „zum vorigen Werkzeug wechseln“).
    private(set) var previousTool: Tool = .zoom

    var tool: Tool = .zoom {
        didSet {
            guard tool != oldValue else { return }
            previousTool = oldValue
            // Werkzeugwechsel stellt schwebende Pixel fertig (Referenz: Fertigstellen)
            document?.settlePreview()
            NotificationCenter.default.post(name: .toolChanged, object: nil)
        }
    }

    // Einstellungen der Auswahlwerkzeuge (Werkzeugleiste, Zeile 2)
    var selectionMode: SelectionMode {
        get { SelectionMode(rawValue: UserDefaults.standard.string(forKey: "Auswahl.Modus") ?? "") ?? .replace }
        set { UserDefaults.standard.set(newValue.rawValue, forKey: "Auswahl.Modus"); NotificationCenter.default.post(name: .toolChanged, object: nil) }
    }
    /// Toleranz 0…1; Referenz-Screenshot zeigt 50 % (Werkseinstellung ungeklärt, R-1).
    var wandTolerance: Double {
        get { UserDefaults.standard.object(forKey: "Zauberstab.Toleranz") as? Double ?? 0.5 }
        set { UserDefaults.standard.set(min(1, max(0, newValue)), forKey: "Zauberstab.Toleranz") }
    }
    var wandGlobal: Bool {
        get { UserDefaults.standard.bool(forKey: "Zauberstab.Global") }
        set { UserDefaults.standard.set(newValue, forKey: "Zauberstab.Global") }
    }
    // Malwerkzeuge
    private static let d = UserDefaults.standard
    /// Pinselbreite 1…2000 (Werkseinstellung der Referenz ungeklärt, R-1).
    var brushWidth: Double {
        get { let v = Self.d.double(forKey: "Pinsel.Breite"); return v >= 1 ? v : 10 }
        set { Self.d.set(min(2000, max(1, newValue.rounded())), forKey: "Pinsel.Breite"); NotificationCenter.default.post(name: .toolChanged, object: nil) }
    }
    var antialias: Bool {
        get { Self.d.object(forKey: "Pinsel.Kantenglaettung") as? Bool ?? true }
        set { Self.d.set(newValue, forKey: "Pinsel.Kantenglaettung") }
    }
    var paintBlend: PaintBlend {
        get {
            let raw = Self.d.string(forKey: "Pinsel.Mischmodus") ?? ""
            if raw == "ueberschreiben" { return .overwrite }
            return .blend(BlendMode(rawValue: raw) ?? .normal)
        }
        set {
            switch newValue {
            case .overwrite: Self.d.set("ueberschreiben", forKey: "Pinsel.Mischmodus")
            case let .blend(m): Self.d.set(m.rawValue, forKey: "Pinsel.Mischmodus")
            }
        }
    }
    // Farbverlauf, Linie, Formen
    var gradientKind: GradientKind {
        get { GradientKind(rawValue: Self.d.string(forKey: "Verlauf.Typ") ?? "") ?? .linear }
        set { Self.d.set(newValue.rawValue, forKey: "Verlauf.Typ") }
    }
    var gradientTransparency: Bool {
        get { Self.d.bool(forKey: "Verlauf.Transparenz") }
        set { Self.d.set(newValue, forKey: "Verlauf.Transparenz") }
    }
    var gradientRepeat: GradientRepeat {
        get { GradientRepeat(rawValue: Self.d.string(forKey: "Verlauf.Wiederholung") ?? "") ?? .none }
        set { Self.d.set(newValue.rawValue, forKey: "Verlauf.Wiederholung") }
    }
    var shapeKind: ShapeKind {
        get { ShapeKind(rawValue: Self.d.string(forKey: "Form.Typ") ?? "") ?? .rectangle }
        set { Self.d.set(newValue.rawValue, forKey: "Form.Typ") }
    }
    var shapeStyle: ShapeStyle {
        get { ShapeStyle(rawValue: Self.d.string(forKey: "Form.Art") ?? "") ?? .outline }
        set { Self.d.set(newValue.rawValue, forKey: "Form.Art") }
    }
    var lineDash: DashStyle {
        get { DashStyle(rawValue: Self.d.string(forKey: "Linie.Strich") ?? "") ?? .solid }
        set { Self.d.set(newValue.rawValue, forKey: "Linie.Strich") }
    }
    var arrowStart: Bool {
        get { Self.d.bool(forKey: "Linie.PfeilAnfang") }
        set { Self.d.set(newValue, forKey: "Linie.PfeilAnfang") }
    }
    var arrowEnd: Bool {
        get { Self.d.bool(forKey: "Linie.PfeilEnde") }
        set { Self.d.set(newValue, forKey: "Linie.PfeilEnde") }
    }

    enum PickerAfter: Int { case stay = 0, previous = 1, pencil = 2 }
    /// Seitenlänge der Pipetten-Stichprobe (1, 3, 5, 7, 9).
    var pickerSampleSize: Int {
        get { let v = Self.d.integer(forKey: "Pipette.Groesse"); return [1, 3, 5, 7, 9].contains(v) ? v : 1 }
        set { Self.d.set(newValue, forKey: "Pipette.Groesse") }
    }
    var pickerSampleImage: Bool {
        get { Self.d.bool(forKey: "Pipette.Bild") }
        set { Self.d.set(newValue, forKey: "Pipette.Bild") }
    }
    var pickerAfter: PickerAfter {
        get { PickerAfter(rawValue: Self.d.integer(forKey: "Pipette.Danach")) ?? .stay }
        set { Self.d.set(newValue.rawValue, forKey: "Pipette.Danach") }
    }

    /// Stichprobe aus dem ganzen Bild statt der aktiven Ebene.
    var wandSampleImage: Bool {
        get { UserDefaults.standard.bool(forKey: "Zauberstab.Bild") }
        set { UserDefaults.standard.set(newValue, forKey: "Zauberstab.Bild") }
    }

    var colors = ColorState(primary: Settings.shared.primaryColor, secondary: Settings.shared.secondaryColor) {
        didSet {
            guard colors != oldValue else { return }
            Settings.shared.primaryColor = colors.primary
            Settings.shared.secondaryColor = colors.secondary
            NotificationCenter.default.post(name: .paletteChanged, object: nil)
        }
    }

    var unit: MeasurementUnit {
        get { Settings.shared.measurementUnit }
        set { Settings.shared.measurementUnit = newValue; postViewSettings() }
    }

    var showPixelGrid: Bool {
        get { Settings.shared.showPixelGrid }
        set { Settings.shared.showPixelGrid = newValue; postViewSettings() }
    }

    func postViewSettings() { NotificationCenter.default.post(name: .viewSettingsChanged, object: nil) }

    // MARK: Start

    func start() {
        guard !started else { return }
        started = true
        registerCommands()
        NSApp.mainMenu = MenuBuilder.buildMainMenu(commands, spec: menuSpec)
        mainWindow = MainWindowController()
        mainWindow.showWindow(nil)
        panels = PanelManager(mainWindow: mainWindow.window!)
        panels.showInitial()
    }

    // MARK: Bilder verwalten

    @discardableResult
    func add(_ doc: Document) -> DocumentSession {
        let s = DocumentSession(document: doc)
        sessions.append(s)
        activate(s)
        return s
    }

    func activate(_ s: DocumentSession?) {
        guard s !== active else { return }
        active?.document.settlePreview()
        mainWindow?.rememberViewState()
        active = s
        NotificationCenter.default.post(name: .documentsChanged, object: nil)
    }

    func activateNext(_ delta: Int) {
        guard let a = active, let i = sessions.firstIndex(where: { $0 === a }), sessions.count > 1 else { return }
        activate(sessions[(i + delta + sessions.count) % sessions.count])
    }

    func untitledName() -> String {
        let names = Set(sessions.map(\.title))
        if !names.contains("Unbenannt") { return "Unbenannt" }
        var n = 2
        while names.contains("Unbenannt \(n)") { n += 1 }
        return "Unbenannt \(n)"
    }

    func newDocument(_ p: NewImageParameters) {
        add(Document(size: PixelSize(p.width, p.height), dpi: p.dpi, name: untitledName()))
    }

    /// Ein frisches, unverändertes „Unbenannt“ wird beim Öffnen eines Bildes ersetzt (wie Referenz beim Start).
    private var replaceableBlank: DocumentSession? {
        guard sessions.count == 1, let s = sessions.first, s.document.fileURL == nil,
              s.document.history.count == 1, !s.document.needsSavePrompt else { return nil }
        return s
    }

    // MARK: Öffnen

    func showOpenPanel() {
        let p = NSOpenPanel()
        p.title = "Bild öffnen"
        p.prompt = "Öffnen"
        p.allowsMultipleSelection = true
        p.canChooseDirectories = false
        p.allowedContentTypes = ImageCodec.readableTypes
        if p.runModal() == .OK { open(urls: p.urls) }
    }

    func open(urls: [URL]) {
        var errors: [String] = []
        for url in urls {
            if let existing = sessions.first(where: { $0.document.fileURL?.standardizedFileURL == url.standardizedFileURL }) {
                activate(existing); continue
            }
            do {
                let blank = replaceableBlank
                let doc = try loadDocument(url)
                add(doc)
                Settings.shared.noteRecent(url)
                if let blank { remove(blank) }
            } catch {
                errors.append("„\(url.lastPathComponent)“: \(error.localizedDescription)")
            }
        }
        if !errors.isEmpty { showError("Das Bild konnte nicht geöffnet werden.", errors.joined(separator: "\n")) }
    }

    func loadDocument(_ url: URL) throws -> Document {
        let li = try ImageCodec.load(url: url)
        let layer = Layer(name: "Hintergrund", surface: li.surface, isBackground: true)
        let st = DocumentState(size: li.surface.size, dpi: li.dpi, layers: [layer], activeLayerIndex: 0)
        return Document(state: st, name: url.lastPathComponent, fileURL: url)
    }

    // MARK: Speichern

    /// Speichert; fragt bei Bedarf nach Ort und Format. Rückgabe: tatsächlich gespeichert.
    @discardableResult
    func save(_ s: DocumentSession, askForLocation: Bool) -> Bool {
        if !askForLocation, let url = s.document.fileURL, let fmt = ImageCodec.format(for: url) {
            return write(s, to: url, format: fmt, quality: Settings.shared.jpegQuality, confirmFlatten: true)
        }
        let panel = NSSavePanel()
        panel.title = "Speichern unter"
        panel.prompt = "Speichern"
        panel.canCreateDirectories = true
        panel.isExtensionHidden = false
        let accessory = SaveAccessoryView(formats: ImageCodec.writableFormats,
                                          initial: s.document.fileURL.flatMap(ImageCodec.format(for:)) ?? ImageCodec.writableFormats[0],
                                          quality: Settings.shared.jpegQuality, panel: panel)
        panel.accessoryView = accessory
        let base = (s.document.displayName as NSString).deletingPathExtension
        panel.nameFieldStringValue = base + "." + accessory.format.fileExtension
        if let dir = s.document.fileURL?.deletingLastPathComponent() { panel.directoryURL = dir }
        guard panel.runModal() == .OK, let url = panel.url else { return false }
        Settings.shared.jpegQuality = accessory.quality
        return write(s, to: url, format: accessory.format, quality: accessory.quality, confirmFlatten: true)
    }

    /// Schreibt das Bild. Bei mehreren Ebenen wird zusammengefügt gespeichert (Bild im Editor bleibt unverändert).
    @discardableResult
    func write(_ s: DocumentSession, to url: URL, format: SaveFormat, quality: Int, confirmFlatten: Bool) -> Bool {
        let doc = s.document
        doc.settlePreview()
        if confirmFlatten && doc.layers.count > 1 && !isSelfTest {
            let a = NSAlert()
            a.messageText = "Ebenen zusammenfügen?"
            a.informativeText = "Das Format \(format.name) kann keine Ebenen speichern. Die Datei erhält das zusammengefügte Bild; die Ebenen im Editor bleiben erhalten."
            a.addButton(withTitle: "Zusammengefügt speichern")
            a.addButton(withTitle: "Abbrechen")
            if a.runModal() != .alertFirstButtonReturn { return false }
        }
        do {
            try ImageCodec.save(doc.flattenedSurface(), dpi: doc.state.dpi, to: url, format: format, quality: quality)
            doc.markSaved(as: url)
            Settings.shared.noteRecent(url)
            NotificationCenter.default.post(name: .documentsChanged, object: nil)
            return true
        } catch {
            showError("„\(url.lastPathComponent)“ konnte nicht gespeichert werden.", error.localizedDescription)
            return false
        }
    }

    func saveAll() {
        for s in sessions where s.document.isDirty {
            activate(s)
            if !save(s, askForLocation: false) { return }
        }
    }

    // MARK: Schließen / Beenden

    /// Schließt ein Bild mit Rückfrage bei ungespeicherten Änderungen. Rückgabe: geschlossen.
    @discardableResult
    func close(_ s: DocumentSession) -> Bool {
        s.document.settlePreview()
        if s.document.needsSavePrompt && !isSelfTest {
            activate(s)
            switch askToSave(s) {
            case .save: if !save(s, askForLocation: false) { return false }
            case .cancel: return false
            case .discard: break
            }
        }
        remove(s)
        return true
    }

    private func remove(_ s: DocumentSession) {
        guard let i = sessions.firstIndex(where: { $0 === s }) else { return }
        let wasActive = s === active
        sessions.remove(at: i)
        if wasActive {
            active = nil
            mainWindow?.forgetViewState()
            let next = sessions.isEmpty ? nil : sessions[min(i, sessions.count - 1)]
            active = next
        }
        NotificationCenter.default.post(name: .documentsChanged, object: nil)
    }

    enum SaveAnswer { case save, discard, cancel }

    func askToSave(_ s: DocumentSession) -> SaveAnswer {
        let a = NSAlert()
        a.messageText = "Möchten Sie die Änderungen an „\(s.title)“ speichern?"
        a.informativeText = "Ihre Änderungen gehen verloren, wenn Sie sie nicht speichern."
        a.addButton(withTitle: "Speichern")
        a.addButton(withTitle: "Abbrechen")
        let discard = a.addButton(withTitle: "Nicht speichern")
        discard.hasDestructiveAction = true
        switch a.runModal() {
        case .alertFirstButtonReturn: return .save
        case .alertThirdButtonReturn: return .discard
        default: return .cancel
        }
    }

    /// Beenden: alle ungespeicherten Bilder nacheinander abfragen.
    func shouldTerminate() -> Bool {
        for s in sessions where s.document.needsSavePrompt {
            if isSelfTest { continue }
            activate(s)
            switch askToSave(s) {
            case .save: if !save(s, askForLocation: false) { return false }
            case .cancel: return false
            case .discard: continue
            }
        }
        return true
    }

    // MARK: Zwischenablage

    static let pasteboardImageTypes: [NSPasteboard.PasteboardType] = [.png, .tiff]

    func copyToPasteboard(_ surface: TiledSurface, dpi: Double) {
        guard let png = try? ImageCodec.encode(surface, dpi: dpi, format: ImageCodec.candidateFormats[0], quality: 100) else { NSSound.beep(); return }
        let pb = NSPasteboard.general
        pb.clearContents()
        pb.declareTypes([.png, .tiff], owner: nil)
        pb.setData(png, forType: .png)
        if let tiffFmt = ImageCodec.writableFormats.first(where: { $0.id == "tiff" }),
           let tiff = try? ImageCodec.encode(surface, dpi: dpi, format: tiffFmt, quality: 100) {
            pb.setData(tiff, forType: .tiff)
        }
    }

    var pasteboardHasImage: Bool {
        let pb = NSPasteboard.general
        return pb.availableType(from: Self.pasteboardImageTypes) != nil || NSImage.canInit(with: pb)
    }

    func imageFromPasteboard() -> TiledSurface? {
        let pb = NSPasteboard.general
        for t in Self.pasteboardImageTypes {
            if let data = pb.data(forType: t), let li = try? ImageCodec.load(data: data) { return li.surface }
        }
        if let img = NSImage(pasteboard: pb), let cg = img.cgImage(forProposedRect: nil, context: nil, hints: nil) {
            return try? ImageCodec.surface(from: cg)
        }
        return nil
    }

    func pasteIntoNewImage() {
        guard let surf = imageFromPasteboard() else { showError("Die Zwischenablage enthält kein Bild.", ""); return }
        let layer = Layer(name: "Hintergrund", surface: surf, isBackground: true)
        let st = DocumentState(size: surf.size, dpi: ImageCodec.defaultDpi, layers: [layer], activeLayerIndex: 0)
        add(Document(state: st, name: untitledName(), fileURL: nil, historyName: "In neues Bild einfügen", historyKind: .paste))
    }

    /// Fügt ein Bild als neue Ebene ein; ist es größer als die Leinwand, wird gefragt (wie Referenz).
    func insertAsLayer(_ surf: TiledSurface, name: String, historyName: String, kind: HistoryKind) {
        guard let doc = document else { return }
        var grow = false
        if (surf.width > doc.size.width || surf.height > doc.size.height) && !isSelfTest {
            let a = NSAlert()
            a.messageText = "Das eingefügte Bild ist größer als die Leinwand."
            a.informativeText = "Bild \(surf.width) × \(surf.height) Pixel, Leinwand \(doc.size.width) × \(doc.size.height) Pixel. Soll die Leinwand vergrößert werden?"
            a.addButton(withTitle: "Leinwand vergrößern")
            a.addButton(withTitle: "Abbrechen")
            a.addButton(withTitle: "Leinwandgröße beibehalten")
            switch a.runModal() {
            case .alertFirstButtonReturn: grow = true
            case .alertThirdButtonReturn: grow = false
            default: return
            }
        }
        doc.insertLayer(surface: surf, name: name, growCanvas: grow, historyName: historyName, kind: kind)
    }

    /// Einfügen als schwebende Pixel (aktive oder neue Ebene); Werkzeug wechselt zu „Ausgewählte Pixel verschieben“.
    func pasteFloating(intoNewLayer: Bool) {
        guard let doc = document, let surf = imageFromPasteboard() else { NSSound.beep(); return }
        var grow = false
        if (surf.width > doc.size.width || surf.height > doc.size.height) && !isSelfTest {
            let a = NSAlert()
            a.messageText = "Das eingefügte Bild ist größer als die Leinwand."
            a.informativeText = "Bild \(surf.width) × \(surf.height) Pixel, Leinwand \(doc.size.width) × \(doc.size.height) Pixel. Soll die Leinwand vergrößert werden?"
            a.addButton(withTitle: "Leinwand vergrößern")
            a.addButton(withTitle: "Abbrechen")
            a.addButton(withTitle: "Leinwandgröße beibehalten")
            switch a.runModal() {
            case .alertFirstButtonReturn: grow = true
            case .alertThirdButtonReturn: grow = false
            default: return
            }
        } else if isSelfTest { grow = surf.width > doc.size.width || surf.height > doc.size.height }
        doc.settlePreview()
        // Referenz: links oben in der sichtbaren Fläche (bzw. in der Bildecke, wenn sie sichtbar ist)
        let origin = grow ? PixelPoint.zero : (mainWindow?.canvas.visibleTopLeftPixel ?? .zero)
        tool = .moveSelectedPixels
        doc.beginFloating(doc.floatingPaste(surf, at: origin, intoNewLayer: intoNewLayer, growCanvas: grow))
    }

    /// Schwebende Pixel fertigstellen (Eingabetaste, „Fertigstellen“).
    func finishFloating() { document?.commitFloating() }

    func pasteIntoNewLayer() { pasteFloating(intoNewLayer: true) }

    func importLayerFromFile() {
        guard document != nil else { return }
        let p = NSOpenPanel()
        p.title = "Aus Datei importieren"
        p.prompt = "Importieren"
        p.allowedContentTypes = ImageCodec.readableTypes
        guard p.runModal() == .OK, let url = p.url else { return }
        do {
            let li = try ImageCodec.load(url: url)
            insertAsLayer(li.surface, name: url.deletingPathExtension().lastPathComponent,
                          historyName: "Aus Datei importieren", kind: .layerAdd)
        } catch {
            showError("„\(url.lastPathComponent)“ konnte nicht importiert werden.", error.localizedDescription)
        }
    }

    // MARK: Drucken

    func printActive() {
        guard let s = active, let cg = s.composite else { return }
        let size = NSSize(width: CGFloat(cg.width) * 72 / CGFloat(s.document.state.dpi),
                          height: CGFloat(cg.height) * 72 / CGFloat(s.document.state.dpi))
        let view = NSImageView(frame: NSRect(origin: .zero, size: size))
        view.image = NSImage(cgImage: cg, size: size)
        view.imageScaling = .scaleProportionallyUpOrDown
        let info = NSPrintInfo.shared.copy() as! NSPrintInfo
        info.horizontalPagination = .fit
        info.verticalPagination = .fit
        info.isHorizontallyCentered = true
        info.isVerticallyCentered = true
        let op = NSPrintOperation(view: view, printInfo: info)
        op.jobTitle = s.title
        op.showsPrintPanel = true
        op.run()
    }

    // MARK: Meldungen

    func showError(_ message: String, _ info: String) {
        if isSelfTest { SelfTest.log("FEHLERMELDUNG: \(message) \(info)"); return }
        let a = NSAlert()
        a.alertStyle = .warning
        a.messageText = message
        a.informativeText = info
        a.runModal()
    }

    func showAbout() {
        let credits = NSMutableAttributedString(string:
            "Eigenständiger Bildeditor für macOS. Bedienung angelehnt an Paint.NET; kein Produkt von dotPDN LLC.\n\n" +
            "Mischmodi portiert aus Paint.NET 3.36 (MIT-Lizenz), © dotPDN LLC, Rick Brewster und Mitwirkende.\n" +
            "Vollständige Lizenzhinweise: THIRD_PARTY_LICENSES.md im Projekt.",
            attributes: [.font: NSFont.systemFont(ofSize: 11), .foregroundColor: NSColor.labelColor])
        NSApp.orderFrontStandardAboutPanel(options: [.applicationName: "Bildeditor", .credits: credits])
    }
}
