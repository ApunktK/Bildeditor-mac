import AppKit
import EditorCore
import EditorDocument

/// Automatischer Oberflächen- und Funktionstest der fertig gebauten App (`--selftest <Ordner>`).
/// Bedient die App über dieselben Befehle wie Menü und Knöpfe, prüft Ergebnisse am Pixel,
/// speichert Bildschirmfotos aller Fenster und schreibt `result.json`. Beendet mit Status 1 bei Fehlern.
final class SelfTest {
    private static var lines: [String] = []
    static func log(_ s: String) { print(s); lines.append(s) }

    private let out: URL
    private var results: [[String: Any]] = []
    private var shots: [String] = []
    private let ctrl = AppController.shared
    private var reg: CommandRegistry { ctrl.commands }

    init(outputDirectory: URL) {
        out = outputDirectory
        try? FileManager.default.createDirectory(at: out, withIntermediateDirectories: true)
    }

    func run() {
        DispatchQueue.main.async { [self] in
            let started = Date()
            steps()
            finish(duration: Date().timeIntervalSince(started))
        }
    }

    // MARK: Hilfen

    private func check(_ name: String, _ ok: Bool, _ detail: @autoclosure () -> String = "") {
        let d = detail()
        results.append(["name": name, "ok": ok, "detail": d])
        Self.log((ok ? "OK    " : "FEHLER") + "  \(name)" + (d.isEmpty ? "" : " – \(d)"))
    }

    private func pump(_ t: TimeInterval = 0.25) { RunLoop.current.run(until: Date().addingTimeInterval(t)) }

    private func snapshot(_ view: NSView?, _ name: String) {
        guard let view else { check("Bildschirmfoto \(name)", false, "keine Ansicht"); return }
        view.layoutSubtreeIfNeeded()
        view.displayIfNeeded()
        guard let rep = view.bitmapImageRepForCachingDisplay(in: view.bounds) else { check("Bildschirmfoto \(name)", false); return }
        view.cacheDisplay(in: view.bounds, to: rep)
        // Auf Fensterhintergrund legen (die Inhaltsansicht selbst ist durchsichtig).
        let final = NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: rep.pixelsWide, pixelsHigh: rep.pixelsHigh, bitsPerSample: 8,
                                     samplesPerPixel: 4, hasAlpha: true, isPlanar: false, colorSpaceName: .deviceRGB,
                                     bytesPerRow: 0, bitsPerPixel: 0) ?? rep
        final.size = rep.size
        if final !== rep, let gc = NSGraphicsContext(bitmapImageRep: final) {
            NSGraphicsContext.saveGraphicsState()
            NSGraphicsContext.current = gc
            view.effectiveAppearance.performAsCurrentDrawingAppearance {
                NSColor.windowBackgroundColor.setFill()
                NSRect(origin: .zero, size: rep.size).fill()
            }
            rep.draw(in: NSRect(origin: .zero, size: rep.size))
            NSGraphicsContext.restoreGraphicsState()
        }
        let url = out.appendingPathComponent(name + ".png")
        if let data = final.representation(using: .png, properties: [:]), (try? data.write(to: url)) != nil {
            shots.append(name + ".png")
        } else {
            check("Bildschirmfoto \(name)", false, "Schreiben fehlgeschlagen")
        }
    }

    private func perform(_ id: String) -> Bool {
        let ok = reg.perform(id)
        pump(0.05)
        return ok
    }

    // MARK: Ablauf

    private func steps() {
        guard let main = ctrl.mainWindow, let window = main.window else { check("Hauptfenster", false); return }
        NSApp.activate(ignoringOtherApps: true)
        window.setFrame(NSRect(x: 40, y: 40, width: 1280, height: 820), display: true)
        // Im CI ist die App evtl. nicht im Vordergrund: Fenster sollen trotzdem sichtbar bleiben.
        for p in ctrl.panels.panels.values { p.hidesOnDeactivate = false }
        ctrl.panels.resetPositions()
        pump()

        // 1. Start: neues Bild
        check("Start ohne Bild", ctrl.sessions.isEmpty)
        ctrl.newDocument(NewImageParameters(width: 800, height: 600, dpi: 96))
        pump()
        guard let doc = ctrl.document else { check("Neues Bild", false); return }
        check("Neues Bild 800 × 600, weiß", doc.size == PixelSize(800, 600) && doc.layers[0].surface[400, 300] == .white)
        check("Ebene „Hintergrund“", doc.layers.map(\.name) == ["Hintergrund"])
        check("Verlauf „Neues Bild“", doc.history.map(\.name) == ["Neues Bild"])
        check("Statusleiste Bildgröße", main.statusBar.displayedSize == "800 × 600 px", main.statusBar.displayedSize)
        check("Bildregister zeigt Bild", main.tabs.tabTitles == ["Unbenannt"], main.tabs.tabTitles.joined(separator: ", "))
        check("Fenstertitel", window.title == "Unbenannt – Bildeditor", window.title)
        check("Zoom ≤ 100 % nach Anpassen", (ctrl.active?.zoom ?? 0) <= 100)
        snapshot(window.contentView, "01-hauptfenster")

        // 2. Menüs: umgesetzte Befehle aktiv, nicht umgesetzte deaktiviert
        var wrongState: [String] = []
        func walk(_ m: NSMenu) {
            m.update()
            for it in m.items {
                if let sub = it.submenu { walk(sub); continue }
                guard let id = it.representedObject as? String, let c = reg[id] else { continue }
                if !c.isImplemented && it.isEnabled { wrongState.append(id + " (aktiv, aber nicht umgesetzt)") }
            }
        }
        if let mm = NSApp.mainMenu { walk(mm) }
        check("Nicht umgesetzte Menüpunkte deaktiviert", wrongState.isEmpty, wrongState.joined(separator: ", "))
        let counts = reg.implementationCounts
        Self.log("Befehle umgesetzt: \(counts.implemented) von \(counts.total)")

        // 3. Ebenen
        _ = perform("layer.add")
        check("Neue Ebene", doc.layers.count == 2 && doc.layers[1].name == "Ebene 2" && doc.activeLayerIndex == 1)
        check("Neue Ebene transparent", doc.layers[1].surface[10, 10] == .transparent)
        _ = perform("layer.duplicate")
        check("Ebene duplizieren", doc.layers.count == 3 && doc.layers[2].name == "Ebene 2 Kopie")
        _ = perform("layer.moveDown")
        check("Ebene nach unten", doc.layers[1].name == "Ebene 2 Kopie" && doc.activeLayerIndex == 1)
        _ = perform("edit.undo")
        check("Rückgängig", doc.layers[2].name == "Ebene 2 Kopie")
        _ = perform("edit.redo")
        check("Wiederholen", doc.layers[1].name == "Ebene 2 Kopie")
        _ = perform("layer.toggleVisibility")
        check("Ebene ausblenden", !doc.layers[1].isVisible)
        let layersVC = ctrl.panels.controllers[.layers] as? LayersPanelController
        check("Ebenenfenster zeigt 3 Ebenen", layersVC?.table.numberOfRows == 3)
        check("Ebenenfenster: aktive Ebene markiert", layersVC?.table.selectedRow == 1)
        check("Ebenenfenster: Knopf „Neue Ebene“ aktiv", layersVC?.buttonEnabled("layer.add") == true)
        _ = perform("layer.mergeDown")
        check("Zusammenführen", doc.layers.count == 2)
        _ = perform("layer.delete")
        check("Ebene löschen", doc.layers.count == 1)
        check("Letzte Ebene nicht löschbar", !reg.canPerform("layer.delete"))

        // 4. Ebeneneigenschaften mit Vorschau
        _ = perform("layer.add")
        let dlg = LayerPropertiesDialog(doc: doc, index: doc.activeLayerIndex)
        dlg.opacitySlider.integerValue = 128
        dlg.blendPopup.selectItem(at: BlendMode.allCases.firstIndex(of: .multiply)!)
        dlg.changed()
        let hBefore = doc.history.count
        check("Eigenschaften: Vorschau ohne Verlaufsschritt", doc.activeLayer.opacity == 128 && doc.history.count == hBefore)
        snapshot(dlg.panel.contentView, "05-ebeneneigenschaften")
        doc.endLayerPropertiesPreview(apply: true, at: dlg.index)
        check("Eigenschaften übernommen", doc.activeLayer.blendMode == .multiply && doc.history.last?.name == "Ebeneneigenschaften")

        // 5. Bild drehen/spiegeln am Pixel
        var s = doc.state
        s.layers[0].surface[0, 0] = ColorBgra(r: 255, g: 0, b: 0)
        doc.commit(s, name: "Testpixel", kind: .edit)
        _ = perform("image.rotateCW")
        check("90° drehen: Größe", doc.size == PixelSize(600, 800))
        check("90° drehen: Pixel", doc.layers[0].surface[599, 0] == ColorBgra(r: 255, g: 0, b: 0))
        _ = perform("image.rotateCCW")
        _ = perform("image.flipH")
        check("Horizontal spiegeln", doc.layers[0].surface[799, 0] == ColorBgra(r: 255, g: 0, b: 0))
        _ = perform("image.flatten")
        check("Auf eine Ebene reduzieren", doc.layers.count == 1)

        // 6. Verlauf
        let histVC = ctrl.panels.controllers[.history] as? HistoryPanelController
        check("Verlaufsfenster: alle Einträge", histVC?.table.numberOfRows == doc.history.count)
        doc.jump(to: 0)
        pump()
        check("Sprung im Verlauf", doc.layers.count == 1 && doc.size == PixelSize(800, 600) && doc.layers[0].surface[0, 0] == .white)
        snapshot(ctrl.panels.panels[.history]?.contentView, "03-verlauf")
        doc.jump(to: doc.history.count - 1)
        pump()

        // 7. Zoom
        main.canvas.setZoom(200, anchor: nil)
        pump(0.05)
        check("Zoom 200 %", ctrl.active?.zoom == 200 && main.statusBar.zoomField.stringValue == "200 %", main.statusBar.zoomField.stringValue)
        _ = perform("view.zoomIn")
        check("Vergrößern → 300 %", ctrl.active?.zoom == 300)
        _ = perform("view.zoomOut"); _ = perform("view.zoomOut")
        check("Verkleinern → 150 %", ctrl.active?.zoom == 150)
        _ = perform("view.actualSize")
        check("Originalgröße", ctrl.active?.zoom == 100)
        // Testbild mit Verlauf und Halbtransparenz für sichtbare Bildschirmfotos
        let pattern = Self.testPattern(PixelSize(1200, 800))
        ctrl.add(Document(state: DocumentState(size: pattern.size, dpi: 96, layers: [Layer(name: "Hintergrund", surface: pattern, isBackground: true)],
                                               activeLayerIndex: 0), name: "Testbild", fileURL: nil, historyName: "Bild öffnen", historyKind: .openImage))
        pump()
        snapshot(window.contentView, "02-testbild-angepasst")
        _ = perform("view.pixelGrid")
        check("Pixelraster an", ctrl.showPixelGrid && main.toolbarRow.buttonStates.contains { $0.id == "view.pixelGrid" })
        main.canvas.setZoom(1600, anchor: nil)
        main.canvas.center(onImage: CGPoint(x: 600, y: 400))
        pump()
        snapshot(window.contentView, "02-zoom-1600-pixelraster")
        _ = perform("view.pixelGrid")
        if let t = ctrl.active { ctrl.close(t) }
        pump()
        check("Testbild geschlossen, voriges Bild aktiv", ctrl.document === doc)
        _ = perform("view.zoomFit")
        _ = perform("view.unit.centimeters")
        check("Einheit Zentimeter", main.statusBar.displayedSize == "21,17 × 15,88 cm", main.statusBar.displayedSize)
        _ = perform("view.unit.pixels")

        // 8. Speichern und Öffnen (gerades Alpha bleibt exakt)
        let tmp = FileManager.default.temporaryDirectory.appendingPathComponent("bildeditor-selbsttest-\(UUID().uuidString)")
        try? FileManager.default.createDirectory(at: tmp, withIntermediateDirectories: true)
        var st = doc.state
        let semi = ColorBgra(r: 200, g: 100, b: 50, a: 128)
        st.layers[0].surface[5, 5] = semi
        st.layers[0].surface[6, 5] = ColorBgra(r: 10, g: 20, b: 30, a: 1)
        doc.commit(st, name: "Halbtransparent", kind: .edit)
        let png = tmp.appendingPathComponent("test.png")
        let pngFormat = ImageCodec.writableFormats.first { $0.id == "png" }!
        check("PNG speichern", ctrl.write(ctrl.active!, to: png, format: pngFormat, quality: 100, confirmFlatten: false))
        check("Nach Speichern unverändert", !doc.isDirty && doc.fileURL == png && window.title == "test.png – Bildeditor", window.title)
        if let re = try? ctrl.loadDocument(png) {
            check("PNG: Größe", re.size == doc.size)
            check("PNG: halbtransparent exakt", re.layers[0].surface[5, 5] == semi, "\(re.layers[0].surface[5, 5])")
            check("PNG: fast transparent exakt", re.layers[0].surface[6, 5] == ColorBgra(r: 10, g: 20, b: 30, a: 1), "\(re.layers[0].surface[6, 5])")
            check("PNG: deckend exakt", re.layers[0].surface[799, 0] == ColorBgra(r: 255, g: 0, b: 0))
            check("PNG: Auflösung", abs(re.state.dpi - 96) < 0.5, "\(re.state.dpi)")
        } else { check("PNG öffnen", false) }
        for fid in ["jpeg", "bmp", "tiff", "gif", "heic", "tga"] {
            guard let f = ImageCodec.writableFormats.first(where: { $0.id == fid }) else { Self.log("Format \(fid) auf diesem System nicht schreibbar"); continue }
            let u = tmp.appendingPathComponent("test." + f.fileExtension)
            do {
                try ImageCodec.save(doc.flattenedSurface(), dpi: 96, to: u, format: f, quality: 90)
                let li = try ImageCodec.load(url: u)
                let ok = li.surface.size == doc.size
                let alphaOk = f.supportsAlpha || li.surface[5, 5].a == 255
                check("\(f.name) speichern und öffnen", ok && alphaOk, "\(li.surface.size), Pixel \(li.surface[5, 5])")
            } catch { check("\(f.name) speichern und öffnen", false, error.localizedDescription) }
        }

        // 9. Mehrere Bilder, Register, Schließen
        ctrl.open(urls: [png])
        check("Bereits geöffnete Datei wird nur aktiviert", ctrl.sessions.count == 1)
        ctrl.newDocument(NewImageParameters(width: 320, height: 240, dpi: 96))
        pump()
        check("Zweites Bild", ctrl.sessions.count == 2 && main.tabs.tabTitles == ["test.png", "Unbenannt"], main.tabs.tabTitles.joined(separator: ", "))
        _ = perform("window.nextImage")
        check("Nächstes Bild", ctrl.document === doc)

        // 10. Zwischenablage
        _ = perform("edit.copyMerged")
        check("Zusammengefügt kopieren", ctrl.pasteboardHasImage)
        _ = perform("edit.pasteNewImage")
        check("In neues Bild einfügen", ctrl.sessions.count == 3 && ctrl.document?.size == PixelSize(800, 600)
              && ctrl.document?.layers[0].surface[5, 5] == semi, "\(String(describing: ctrl.document?.layers[0].surface[5, 5]))")
        let pastedDoc = ctrl.document
        _ = perform("edit.pasteNewLayer")
        check("In neue Ebene einfügen", pastedDoc?.layers.count == 2 && pastedDoc?.history.last?.name == "In neue Ebene einfügen")
        snapshot(window.contentView, "04-mehrere-bilder")
        if let a = ctrl.active { ctrl.close(a) }
        check("Bild schließen", ctrl.sessions.count == 2)

        // 11. Werkzeuge und Farben
        ctrl.tool = .pan
        check("Werkzeug Hand", ctrl.tool == .pan && main.toolOptions.toolPopup.titleOfSelectedItem == "Hand")
        check("Taste Z → Zoom", ctrl.handleSingleKey("z", shift: false) && ctrl.tool == .zoom)
        _ = ctrl.handleSingleKey("b", shift: false)
        check("Nicht umgesetztes Werkzeug nicht wählbar", ctrl.tool == .zoom)
        let before = ctrl.colors
        _ = ctrl.handleSingleKey("x", shift: false)
        check("Farben tauschen (X)", ctrl.colors.primary == before.secondary && ctrl.colors.secondary == before.primary)
        _ = ctrl.handleSingleKey("x", shift: false)
        check("HSV-Umrechnung", HSV(ColorBgra(r: 255, g: 0, b: 0)) == HSV(h: 0, s: 100, v: 100) && HSV(h: 120, s: 100, v: 100).color() == ColorBgra(r: 0, g: 255, b: 0))

        // 12. Fenster
        for id in PanelID.allCases {
            check("Fenster \(id.title) sichtbar", ctrl.panels.isVisible(id))
        }
        _ = perform("window.layers")
        check("Ebenenfenster ausblenden", !ctrl.panels.isVisible(.layers))
        _ = perform("window.resetPanels")
        check("Fensterpositionen zurücksetzen", PanelID.allCases.allSatisfy { ctrl.panels.isVisible($0) })
        pump()
        for id in PanelID.allCases { snapshot(ctrl.panels.panels[id]?.contentView, "06-fenster-\(id.rawValue)") }

        // 13. Dialog „Neues Bild“
        let nd = NewImageDialog()
        nd.widthField.stringValue = "1600"
        nd.controlTextDidChange(Notification(name: NSControl.textDidChangeNotification, object: nd.widthField))
        check("Neues Bild: Seitenverhältnis", nd.params.width == 1600 && nd.params.height == 1200 && nd.heightField.stringValue == "1200",
              "\(nd.params.width) × \(nd.params.height)")
        nd.widthField.stringValue = "70000"
        nd.controlTextDidChange(Notification(name: NSControl.textDidChangeNotification, object: nd.widthField))
        check("Neues Bild: Grenze", !nd.errorLabel.stringValue.isEmpty)
        nd.widthField.stringValue = "800"
        nd.controlTextDidChange(Notification(name: NSControl.textDidChangeNotification, object: nd.widthField))
        snapshot(nd.panel.contentView, "07-neues-bild")

        // 14. Werkzeugleiste
        main.refreshControls()
        let states = main.toolbarRow.buttonStates
        let wrong = states.filter { st in (reg[st.id].map { !$0.isImplemented } ?? true) && st.enabled }.map(\.id)
        check("Werkzeugleiste: nicht umgesetzte Knöpfe deaktiviert", wrong.isEmpty, wrong.joined(separator: ", "))
        check("Werkzeugleiste: Speichern aktiv", states.contains { $0.id == "file.save" && $0.enabled })

        try? FileManager.default.removeItem(at: tmp)
    }

    private func finish(duration: TimeInterval) {
        let failed = results.filter { ($0["ok"] as? Bool) == false }.count
        let counts = reg.implementationCounts
        let notImplemented = reg.ids.compactMap { reg[$0] }.filter { !$0.isImplemented }.map { "\($0.id) (Phase \($0.plannedPhase ?? 0))" }
        let info = Bundle.main.infoDictionary ?? [:]
        let json: [String: Any] = [
            "version": info["CFBundleShortVersionString"] ?? "?",
            "build": info["CFBundleVersion"] ?? "?",
            "macOS": ProcessInfo.processInfo.operatingSystemVersionString,
            "architektur": Self.architecture,
            "dauerSekunden": (duration * 10).rounded() / 10,
            "tests": results,
            "bestanden": results.count - failed,
            "fehlgeschlagen": failed,
            "befehleUmgesetzt": counts.implemented,
            "befehleGesamt": counts.total,
            "nichtUmgesetzt": notImplemented,
            "bildschirmfotos": shots,
        ]
        if let data = try? JSONSerialization.data(withJSONObject: json, options: [.prettyPrinted, .sortedKeys]) {
            try? data.write(to: out.appendingPathComponent("result.json"))
        }
        try? Self.lines.joined(separator: "\n").write(to: out.appendingPathComponent("selftest.log"), atomically: true, encoding: .utf8)
        Self.log("Selbsttest: \(results.count - failed) bestanden, \(failed) fehlgeschlagen")
        exit(failed == 0 ? 0 : 1)
    }

    /// Farbverlauf mit halbtransparenten Kreisen und durchsichtigem Rand.
    static func testPattern(_ size: PixelSize) -> TiledSurface {
        var s = TiledSurface(size: size)
        let w = Double(size.width), h = Double(size.height)
        for y in 0..<size.height {
            for x in 0..<size.width {
                let fx = Double(x) / w, fy = Double(y) / h
                var c = HSV(h: fx * 300, s: 70, v: 55 + 45 * (1 - fy)).color()
                for (cx, cy, r, a) in [(0.3, 0.4, 0.18, 200.0), (0.65, 0.55, 0.22, 120.0), (0.5, 0.25, 0.1, 255.0)] {
                    let dx = fx - cx, dy = (fy - cy) * h / w
                    if (dx * dx + dy * dy).squareRoot() < r {
                        c = BlendMode.normal.blend(bottom: c, top: ColorBgra(r: 255, g: 255, b: 255, a: UInt8(a)))
                    }
                }
                if x < 40 || y < 40 { c.a = UInt8(min(255, (min(x, y) * 255) / 40)) }
                s[x, y] = c
            }
        }
        return s
    }

    static var architecture: String {
        #if arch(arm64)
        return "arm64"
        #elseif arch(x86_64)
        return "x86_64"
        #else
        return "unbekannt"
        #endif
    }
}
