import AppKit
import EditorCore
import EditorDocument

/// Alle Menübefehle. Einträge ohne `run` sind noch nicht umgesetzt und erscheinen deaktiviert (siehe IMPLEMENTATION_STATUS).
extension AppController {
    private var hasDoc: () -> Bool { { [unowned self] in self.document != nil } }

    func registerCommands() {
        let r = commands
        let fn = Shortcut.function
        func doc(_ f: @escaping (Document) -> Void) -> () -> Void { { [unowned self] in if let d = self.document { f(d) } } }
        func docIf(_ f: @escaping (Document) -> Bool) -> () -> Bool { { [unowned self] in self.document.map(f) ?? false } }

        // App-Menü
        r.register(Command("app.about", "Über Bildeditor", run: { [unowned self] in self.showAbout() }))
        r.register(Command("app.settings", "Einstellungen …", shortcut: Shortcut(","), planned: 8))

        // Datei
        r.register(Command("file.new", "Neu …", shortcut: Shortcut("n"), run: { NewImageDialog.run() }))
        r.register(Command("file.open", "Öffnen …", shortcut: Shortcut("o"), run: { [unowned self] in self.showOpenPanel() }))
        r.register(Command("file.acquire", "Vom Scanner oder von der Kamera …", planned: 7))
        r.register(Command("file.save", "Speichern", shortcut: Shortcut("s"), enabled: hasDoc,
                           run: { [unowned self] in if let s = self.active { self.save(s, askForLocation: false) } }))
        r.register(Command("file.saveAs", "Speichern unter …", shortcut: Shortcut("s", [.command, .shift]), enabled: hasDoc,
                           run: { [unowned self] in if let s = self.active { self.save(s, askForLocation: true) } }))
        r.register(Command("file.saveAll", "Alle speichern", shortcut: Shortcut("s", [.command, .option]),
                           enabled: { [unowned self] in self.sessions.contains { $0.document.isDirty } },
                           run: { [unowned self] in self.saveAll() }))
        r.register(Command("file.print", "Drucken …", shortcut: Shortcut("p"), enabled: hasDoc, run: { [unowned self] in self.printActive() }))
        r.register(Command("file.close", "Schließen", shortcut: Shortcut("w"), enabled: hasDoc,
                           run: { [unowned self] in if let s = self.active { self.close(s) } }))

        // Bearbeiten
        r.register(Command("edit.undo", "Rückgängig", shortcut: Shortcut("z"), standardAction: NSSelectorFromString("undo:"),
                           enabled: docIf { $0.canUndo }, run: doc { $0.undo() }))
        r.register(Command("edit.redo", "Wiederholen", shortcut: Shortcut("z", [.command, .shift]), standardAction: NSSelectorFromString("redo:"),
                           enabled: docIf { $0.canRedo }, run: doc { $0.redo() }))
        r.register(Command("edit.cut", "Ausschneiden", shortcut: Shortcut("x"), standardAction: #selector(NSText.cut(_:)), planned: 3))
        r.register(Command("edit.copy", "Kopieren", shortcut: Shortcut("c"), standardAction: #selector(NSText.copy(_:)), enabled: hasDoc,
                           run: { [unowned self] in if let d = self.document { self.copyToPasteboard(d.activeLayer.surface, dpi: d.state.dpi) } }))
        r.register(Command("edit.copyMerged", "Zusammengefügt kopieren", shortcut: Shortcut("c", [.command, .shift]), enabled: hasDoc,
                           run: { [unowned self] in if let d = self.document { self.copyToPasteboard(d.flattenedSurface(), dpi: d.state.dpi) } }))
        r.register(Command("edit.paste", "Einfügen", shortcut: Shortcut("v"), standardAction: #selector(NSText.paste(_:)), planned: 3))
        r.register(Command("edit.pasteNewLayer", "In neue Ebene einfügen", shortcut: Shortcut("v", [.command, .shift]),
                           enabled: { [unowned self] in self.document != nil && self.pasteboardHasImage },
                           run: { [unowned self] in self.pasteIntoNewLayer() }))
        r.register(Command("edit.pasteNewImage", "In neues Bild einfügen", shortcut: Shortcut("v", [.command, .option]),
                           enabled: { [unowned self] in self.pasteboardHasImage },
                           run: { [unowned self] in self.pasteIntoNewImage() }))
        r.register(Command("edit.copySelection", "Auswahl kopieren", shortcut: Shortcut("c", [.command, .option, .shift]), planned: 3))
        r.register(Command("edit.pasteSelection.replace", "Ersetzen", shortcut: Shortcut("v", [.command, .option, .shift]), planned: 3))
        r.register(Command("edit.pasteSelection.union", "Hinzufügen (Vereinigung)", planned: 3))
        r.register(Command("edit.pasteSelection.exclude", "Ausschließen", planned: 3))
        r.register(Command("edit.pasteSelection.intersect", "Schnittmenge", planned: 3))
        r.register(Command("edit.pasteSelection.xor", "Umkehren (XOR)", planned: 3))
        r.register(Command("edit.eraseSelection", "Auswahl löschen", shortcut: Shortcut("\u{8}", []), standardAction: #selector(NSText.delete(_:)), planned: 3))
        r.register(Command("edit.fillSelection", "Auswahl füllen", shortcut: Shortcut("\u{8}", [.option]), planned: 3))
        r.register(Command("edit.invertSelection", "Auswahl umkehren", shortcut: Shortcut("i"), planned: 3))
        r.register(Command("edit.selectAll", "Alles auswählen", shortcut: Shortcut("a"), standardAction: #selector(NSText.selectAll(_:)), planned: 3))
        r.register(Command("edit.deselect", "Auswahl aufheben", shortcut: Shortcut("d"), planned: 3))

        // Ansicht
        r.register(Command("view.zoomIn", "Vergrößern", shortcut: Shortcut("+"), enabled: hasDoc,
                           run: { [unowned self] in self.mainWindow.canvas.zoomStep(+1) }))
        r.register(Command("view.zoomOut", "Verkleinern", shortcut: Shortcut("-"), enabled: hasDoc,
                           run: { [unowned self] in self.mainWindow.canvas.zoomStep(-1) }))
        r.register(Command("view.zoomFit", "An Fenster anpassen", shortcut: Shortcut("b"), enabled: hasDoc,
                           run: { [unowned self] in self.mainWindow.canvas.zoomToFit() }))
        r.register(Command("view.zoomSelection", "Auf Auswahl zoomen", shortcut: Shortcut("b", [.command, .shift]), planned: 3))
        r.register(Command("view.actualSize", "Originalgröße", shortcut: Shortcut("0"), enabled: hasDoc,
                           run: { [unowned self] in self.mainWindow.canvas.setZoom(100, anchor: nil) }))
        r.register(Command("view.pixelGrid", "Pixelraster", checked: { [unowned self] in self.showPixelGrid },
                           run: { [unowned self] in self.showPixelGrid.toggle() }))
        r.register(Command("view.rulers", "Lineale", planned: 3))
        for (u, t) in [(MeasurementUnit.pixels, "Pixel"), (.inches, "Zoll"), (.centimeters, "Zentimeter")] {
            r.register(Command("view.unit.\(u.rawValue)", t, checked: { [unowned self] in self.unit == u },
                               run: { [unowned self] in self.unit = u }))
        }

        // Bild
        r.register(Command("image.crop", "Auf Auswahl zuschneiden", shortcut: Shortcut("x", [.command, .shift]), planned: 3))
        r.register(Command("image.resize", "Bildgröße ändern …", shortcut: Shortcut("r"), planned: 5))
        r.register(Command("image.canvasSize", "Leinwandgröße …", shortcut: Shortcut("r", [.command, .shift]), planned: 5))
        r.register(Command("image.flipH", "Horizontal spiegeln", enabled: hasDoc, run: doc { $0.transformImage(.flipHorizontal) }))
        r.register(Command("image.flipV", "Vertikal spiegeln", enabled: hasDoc, run: doc { $0.transformImage(.flipVertical) }))
        r.register(Command("image.rotateCW", "90° im Uhrzeigersinn drehen", shortcut: fn(NSRightArrowFunctionKey, [.command, .option]),
                           enabled: hasDoc, run: doc { $0.transformImage(.rotate90CW) }))
        r.register(Command("image.rotateCCW", "90° gegen den Uhrzeigersinn drehen", shortcut: fn(NSLeftArrowFunctionKey, [.command, .option]),
                           enabled: hasDoc, run: doc { $0.transformImage(.rotate90CCW) }))
        r.register(Command("image.rotate180", "180° drehen", enabled: hasDoc, run: doc { $0.transformImage(.rotate180) }))
        r.register(Command("image.colorProfile", "Farbprofil …", planned: 7))
        r.register(Command("image.flatten", "Auf eine Ebene reduzieren", shortcut: Shortcut("f", [.command, .shift]),
                           enabled: docIf { $0.canFlatten }, run: doc { $0.flatten() }))

        // Ebenen
        r.register(Command("layer.add", "Neue Ebene", shortcut: Shortcut("n", [.command, .shift]), enabled: hasDoc, run: doc { $0.addLayer() }))
        r.register(Command("layer.delete", "Ebene löschen", shortcut: Shortcut("\u{8}", [.command, .shift]),
                           enabled: docIf { $0.canDeleteLayer }, run: doc { $0.deleteLayer() }))
        r.register(Command("layer.duplicate", "Ebene duplizieren", shortcut: Shortcut("d", [.command, .shift]),
                           enabled: hasDoc, run: doc { $0.duplicateLayer() }))
        r.register(Command("layer.mergeDown", "Mit darunterliegender Ebene zusammenführen", shortcut: Shortcut("e"),
                           enabled: docIf { $0.canMergeDown }, run: doc { $0.mergeLayerDown() }))
        r.register(Command("layer.toggleVisibility", "Ebene ein-/ausblenden", shortcut: Shortcut(",", [.command, .option]),
                           enabled: hasDoc, run: doc { $0.toggleVisibility(at: $0.activeLayerIndex) }))
        r.register(Command("layer.import", "Aus Datei importieren …", enabled: hasDoc, run: { [unowned self] in self.importLayerFromFile() }))
        r.register(Command("layer.flipH", "Ebene horizontal spiegeln", enabled: hasDoc, run: doc { $0.transformActiveLayer(.flipHorizontal) }))
        r.register(Command("layer.flipV", "Ebene vertikal spiegeln", enabled: hasDoc, run: doc { $0.transformActiveLayer(.flipVertical) }))
        r.register(Command("layer.rotate180", "Ebene um 180° drehen", enabled: hasDoc, run: doc { $0.transformActiveLayer(.rotate180) }))
        r.register(Command("layer.rotateZoom", "Drehen/Zoomen …", shortcut: Shortcut("r", [.command, .option, .shift]), planned: 5))
        r.register(Command("layer.gotoTop", "Zur obersten Ebene", shortcut: fn(NSPageUpFunctionKey, [.command, .option]),
                           enabled: hasDoc, run: doc { $0.setActiveLayer($0.layers.count - 1) }))
        r.register(Command("layer.gotoAbove", "Zur Ebene darüber", shortcut: fn(NSPageUpFunctionKey, [.option]),
                           enabled: docIf { $0.activeLayerIndex < $0.layers.count - 1 }, run: doc { $0.setActiveLayer($0.activeLayerIndex + 1) }))
        r.register(Command("layer.gotoBelow", "Zur Ebene darunter", shortcut: fn(NSPageDownFunctionKey, [.option]),
                           enabled: docIf { $0.activeLayerIndex > 0 }, run: doc { $0.setActiveLayer($0.activeLayerIndex - 1) }))
        r.register(Command("layer.gotoBottom", "Zur untersten Ebene", shortcut: fn(NSPageDownFunctionKey, [.command, .option]),
                           enabled: hasDoc, run: doc { $0.setActiveLayer(0) }))
        r.register(Command("layer.moveTop", "Ebene ganz nach oben", enabled: docIf { $0.canMoveLayer(.top) }, run: doc { $0.moveLayer(.top) }))
        r.register(Command("layer.moveUp", "Ebene nach oben", enabled: docIf { $0.canMoveLayer(.up) }, run: doc { $0.moveLayer(.up) }))
        r.register(Command("layer.moveDown", "Ebene nach unten", enabled: docIf { $0.canMoveLayer(.down) }, run: doc { $0.moveLayer(.down) }))
        r.register(Command("layer.moveBottom", "Ebene ganz nach unten", enabled: docIf { $0.canMoveLayer(.bottom) }, run: doc { $0.moveLayer(.bottom) }))
        r.register(Command("layer.properties", "Ebeneneigenschaften …", shortcut: fn(NSF4FunctionKey, []), enabled: hasDoc,
                           run: { LayerPropertiesDialog.runForActiveLayer() }))

        // Korrekturen (Phase 6)
        let adjustments: [(String, String, Shortcut?)] = [
            ("autoLevel", "Auto-Tonwert", Shortcut("l", [.command, .shift])),
            ("blackWhite", "Schwarzweiß", Shortcut("g", [.command, .shift])),
            ("brightnessContrast", "Helligkeit/Kontrast …", Shortcut("t", [.command, .shift])),
            ("curves", "Gradationskurven …", Shortcut("m", [.command, .shift])),
            ("exposure", "Belichtung …", nil),
            ("highlightsShadows", "Lichter/Schatten …", nil),
            ("hueSaturation", "Farbton/Sättigung …", Shortcut("u", [.command, .shift])),
            ("invertAlpha", "Alpha umkehren", Shortcut("i", [.command, .option])),
            ("invertColors", "Farben umkehren", Shortcut("i", [.command, .shift])),
            ("levels", "Tonwertkorrektur …", Shortcut("l")),
            ("posterize", "Tontrennung …", Shortcut("p", [.command, .shift])),
            ("sepia", "Sepia", Shortcut("e", [.command, .shift])),
            ("temperatureTint", "Farbtemperatur/Tönung …", nil),
        ]
        for (id, t, k) in adjustments { r.register(Command("adjust.\(id)", t, shortcut: k, planned: 6)) }

        // Effekte (Phase 7)
        r.register(Command("effect.repeat", "Letzten Effekt wiederholen", shortcut: Shortcut("f"), planned: 6))
        for (group, items) in Self.effectGroups {
            for (i, t) in items.enumerated() { r.register(Command("effect.\(group).\(i)", t, planned: 6)) }
        }

        // Fenster
        for (i, p) in PanelID.allCases.enumerated() {
            r.register(Command("window.\(p.rawValue)", p.title, shortcut: fn(NSF5FunctionKey + i, []),
                               checked: { [unowned self] in self.panels?.isVisible(p) ?? false },
                               run: { [unowned self] in self.panels.toggle(p) }))
        }
        r.register(Command("window.resetPanels", "Fensterpositionen zurücksetzen", run: { [unowned self] in self.panels.resetPositions() }))
        r.register(Command("window.minimize", "Im Dock ablegen", shortcut: Shortcut("m"), standardAction: #selector(NSWindow.performMiniaturize(_:)), run: {}))
        r.register(Command("window.nextImage", "Nächstes Bild", shortcut: Shortcut("\t", [.control]),
                           enabled: { [unowned self] in self.sessions.count > 1 }, run: { [unowned self] in self.activateNext(+1) }))
        r.register(Command("window.previousImage", "Voriges Bild", shortcut: Shortcut("\t", [.control, .shift]),
                           enabled: { [unowned self] in self.sessions.count > 1 }, run: { [unowned self] in self.activateNext(-1) }))

        // Hilfe
        r.register(Command("help.docs", "Bildeditor-Hilfe", shortcut: fn(NSF1FunctionKey, []), run: {
            NSWorkspace.shared.open(URL(string: "https://github.com/ApunktK/Bildeditor-mac#readme")!)
        }))
        r.register(Command("help.report", "Fehler melden …", run: {
            NSWorkspace.shared.open(URL(string: "https://github.com/ApunktK/Bildeditor-mac/issues/new")!)
        }))
        r.register(Command("help.crashLogs", "Absturzprotokolle anzeigen", run: {
            let dir = FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent("Library/Logs/DiagnosticReports")
            NSWorkspace.shared.open(dir)
        }))
    }

    static let effectGroups: [(String, [String])] = [
        ("Künstlerisch", ["Tintenskizze …", "Ölgemälde …", "Bleistiftskizze …"]),
        ("Unschärfe", ["Bokeh …", "Fragment …", "Gaußscher Weichzeichner …", "Median …", "Bewegungsunschärfe …", "Radialunschärfe …",
                       "Skizzenunschärfe …", "Quadratische Unschärfe …", "Oberflächenunschärfe …", "Zoomunschärfe …"]),
        ("Farbe", ["Quantisieren …"]),
        ("Verzerren", ["Wölben …", "Kristallisieren …", "Dellen …", "Milchglas …", "Morphologie …", "Verpixeln …",
                       "Polare Inversion …", "Kachelreflexion …", "Verdrehen …"]),
        ("Rauschen", ["Rauschen hinzufügen …", "Rauschen reduzieren …"]),
        ("Objekt", ["Schlagschatten …"]),
        ("Foto", ["Leuchten …", "Rote Augen entfernen …", "Schärfen …", "Porträt weichzeichnen …", "Begradigen …", "Vignette …"]),
        ("Rendern", ["Wolken …", "Julia-Fraktal …", "Mandelbrot-Fraktal …", "Turbulenz …"]),
        ("Stilisieren", ["Kanten erkennen …", "Prägen …", "Kontur …", "Relief …"]),
    ]

    var menuSpec: [(String, [MenuNode])] {
        [
            ("Datei", [.cmd("file.new"), .cmd("file.open"), .recentFiles, .cmd("file.acquire"), .separator,
                       .cmd("file.save"), .cmd("file.saveAs"), .cmd("file.saveAll"), .separator,
                       .cmd("file.print"), .separator, .cmd("file.close")]),
            ("Bearbeiten", [.cmd("edit.undo"), .cmd("edit.redo"), .separator,
                            .cmd("edit.cut"), .cmd("edit.copy"), .cmd("edit.copyMerged"), .cmd("edit.paste"),
                            .cmd("edit.pasteNewLayer"), .cmd("edit.pasteNewImage"), .separator,
                            .cmd("edit.copySelection"),
                            .submenu("Auswahl einfügen", [.cmd("edit.pasteSelection.replace"), .cmd("edit.pasteSelection.union"),
                                                          .cmd("edit.pasteSelection.exclude"), .cmd("edit.pasteSelection.intersect"),
                                                          .cmd("edit.pasteSelection.xor")]),
                            .separator, .cmd("edit.eraseSelection"), .cmd("edit.fillSelection"), .cmd("edit.invertSelection"),
                            .cmd("edit.selectAll"), .cmd("edit.deselect")]),
            ("Ansicht", [.cmd("view.zoomIn"), .cmd("view.zoomOut"), .cmd("view.zoomFit"), .cmd("view.zoomSelection"),
                         .cmd("view.actualSize"), .separator, .cmd("view.pixelGrid"), .cmd("view.rulers"), .separator,
                         .cmd("view.unit.pixels"), .cmd("view.unit.inches"), .cmd("view.unit.centimeters")]),
            ("Bild", [.cmd("image.crop"), .cmd("image.resize"), .cmd("image.canvasSize"), .separator,
                      .cmd("image.flipH"), .cmd("image.flipV"), .separator,
                      .cmd("image.rotateCW"), .cmd("image.rotateCCW"), .cmd("image.rotate180"), .separator,
                      .cmd("image.colorProfile"), .separator, .cmd("image.flatten")]),
            ("Ebenen", [.cmd("layer.add"), .cmd("layer.delete"), .cmd("layer.duplicate"), .cmd("layer.mergeDown"),
                        .cmd("layer.toggleVisibility"), .cmd("layer.import"), .separator,
                        .cmd("layer.flipH"), .cmd("layer.flipV"), .cmd("layer.rotate180"), .cmd("layer.rotateZoom"), .separator,
                        .cmd("layer.gotoTop"), .cmd("layer.gotoAbove"), .cmd("layer.gotoBelow"), .cmd("layer.gotoBottom"), .separator,
                        .cmd("layer.moveTop"), .cmd("layer.moveUp"), .cmd("layer.moveDown"), .cmd("layer.moveBottom"), .separator,
                        .cmd("layer.properties")]),
            ("Korrekturen", ["autoLevel", "blackWhite", "brightnessContrast", "curves", "exposure", "highlightsShadows",
                             "hueSaturation", "invertAlpha", "invertColors", "levels", "posterize", "sepia", "temperatureTint"]
                .map { MenuNode.cmd("adjust.\($0)") }),
            ("Effekte", [MenuNode.cmd("effect.repeat"), MenuNode.separator] + Self.effectGroups.map { g -> MenuNode in
                MenuNode.submenu(g.0, g.1.indices.map { MenuNode.cmd("effect.\(g.0).\($0)") })
            }),
            ("Fenster", PanelID.allCases.map { MenuNode.cmd("window.\($0.rawValue)") } +
                [.separator, .cmd("window.resetPanels"), .separator, .cmd("window.minimize"),
                 .cmd("window.nextImage"), .cmd("window.previousImage")]),
            ("Hilfe", [.cmd("help.docs"), .separator, .cmd("help.report"), .cmd("help.crashLogs")]),
        ]
    }
}
