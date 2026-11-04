import XCTest
import EditorCore
@testable import EditorDocument

final class BlendModeTests: XCTestCase {
    let red = ColorBgra(r: 255, g: 0, b: 0)
    let half = ColorBgra(r: 0, g: 0, b: 255, a: 128)

    func testNormalOverOpaque() {
        XCTAssertEqual(BlendMode.normal.blend(bottom: .white, top: red), red)
        XCTAssertEqual(BlendMode.normal.blend(bottom: .transparent, top: half), half, "über Transparenz bleibt Quelle")
        XCTAssertEqual(BlendMode.normal.blend(bottom: red, top: .transparent), red)
        XCTAssertEqual(BlendMode.normal.blend(bottom: .transparent, top: .transparent), .transparent)
    }

    func testNormalHalfAlpha() {
        // Blau mit 128 über Weiß: Kanal = (255·127 + 255·0 + 0·128) / 255 ≈ 127; B = (255·127 + 255·128)/255 = 255
        let c = BlendMode.normal.blend(bottom: .white, top: half)
        XCTAssertEqual(c.a, 255)
        XCTAssertEqual(c.b, 255)
        XCTAssertEqual(c.r, 127)
    }

    func testOpacityHalvesEffect() {
        let c = BlendMode.normal.blend(bottom: .white, top: .black, opacity: 128)
        XCTAssertEqual(c.r, 127)
        XCTAssertEqual(c.a, 255)
    }

    func testFormulasOnOpaque() {
        let A = ColorBgra(r: 200, g: 100, b: 50), B = ColorBgra(r: 100, g: 200, b: 0)
        XCTAssertEqual(BlendMode.multiply.blend(bottom: A, top: B).r, UInt8(scale(200, 100)))
        XCTAssertEqual(BlendMode.additive.blend(bottom: A, top: B).r, 255)
        XCTAssertEqual(BlendMode.difference.blend(bottom: A, top: B).g, 100)
        XCTAssertEqual(BlendMode.lighten.blend(bottom: A, top: B).r, 200)
        XCTAssertEqual(BlendMode.darken.blend(bottom: A, top: B).r, 100)
        XCTAssertEqual(BlendMode.xor.blend(bottom: A, top: B).r, UInt8(200 ^ 100))
        XCTAssertEqual(BlendMode.screen.blend(bottom: A, top: B).b, 50)
        XCTAssertEqual(BlendMode.colorDodge.blend(bottom: A, top: ColorBgra(r: 255, g: 255, b: 255)).r, 255)
        XCTAssertEqual(BlendMode.colorBurn.blend(bottom: A, top: ColorBgra(r: 0, g: 0, b: 0)).r, 0)
        XCTAssertEqual(BlendMode.negation.blend(bottom: A, top: B).r, UInt8(255 - abs(255 - 200 - 100)))
        XCTAssertEqual(BlendMode.overlay.blend(bottom: ColorBgra(r: 64, g: 64, b: 64), top: ColorBgra(r: 128, g: 128, b: 128)).r, UInt8(scale(128, 128)))
    }

    func testScaleMatchesReference() {
        XCTAssertEqual(scale(255, 255), 255)
        XCTAssertEqual(scale(255, 0), 0)
        XCTAssertEqual(scale(128, 255), 128)
        XCTAssertEqual(scale(128, 128), 64)
    }

    func testFourteenModesInReferenceOrder() {
        XCTAssertEqual(BlendMode.allCases.count, 14)
        XCTAssertEqual(BlendMode.allCases.first, .normal)
    }
}

final class DocumentTests: XCTestCase {
    func makeDoc() -> Document { Document(size: PixelSize(800, 600), dpi: 96, name: "Unbenannt") }

    func testNewDocument() {
        let d = makeDoc()
        XCTAssertEqual(d.layers.count, 1)
        XCTAssertEqual(d.layers[0].name, "Hintergrund")
        XCTAssertEqual(d.layers[0].surface[799, 599], .white)
        XCTAssertEqual(d.history.count, 1)
        XCTAssertFalse(d.canUndo)
        XCTAssertTrue(d.isDirty, "neues, nie gespeichertes Bild gilt als ungespeichert")
        XCTAssertFalse(d.needsSavePrompt, "unverändertes neues Bild: keine Rückfrage beim Schließen")
        d.addLayer(); XCTAssertTrue(d.needsSavePrompt)
        d.undo(); XCTAssertFalse(d.needsSavePrompt)
    }

    func testAddDuplicateDeleteUndoRedo() {
        let d = makeDoc()
        d.addLayer()
        XCTAssertEqual(d.layers.count, 2); XCTAssertEqual(d.activeLayer.name, "Ebene 2"); XCTAssertEqual(d.activeLayerIndex, 1)
        d.duplicateLayer()
        XCTAssertEqual(d.layers.count, 3); XCTAssertEqual(d.activeLayer.name, "Ebene 2 Kopie")
        XCTAssertNotEqual(d.layers[1].id, d.layers[2].id, "Duplikat ist unabhängig")
        d.undo(); XCTAssertEqual(d.layers.count, 2)
        d.redo(); XCTAssertEqual(d.layers.count, 3)
        d.deleteLayer(); XCTAssertEqual(d.layers.count, 2)
        XCTAssertEqual(d.history.map(\.name), ["Neues Bild", "Ebene hinzufügen", "Ebene duplizieren", "Ebene löschen"])
    }

    func testLastLayerCannotBeDeleted() {
        let d = makeDoc()
        XCTAssertFalse(d.canDeleteLayer)
        d.deleteLayer()
        XCTAssertEqual(d.layers.count, 1)
        XCTAssertEqual(d.history.count, 1)
    }

    func testNewActionDiscardsRedo() {
        let d = makeDoc()
        d.addLayer(); d.addLayer()
        d.undo()
        XCTAssertTrue(d.canRedo)
        d.duplicateLayer()
        XCTAssertFalse(d.canRedo)
        XCTAssertEqual(d.history.count, 3)
    }

    func testHistoryJump() {
        let d = makeDoc()
        d.addLayer(); d.addLayer(); d.addLayer()
        d.jump(to: 1)
        XCTAssertEqual(d.layers.count, 2)
        d.jump(to: 3)
        XCTAssertEqual(d.layers.count, 4)
    }

    func testVisibilityAndMergeKeepComposite() {
        let d = makeDoc()
        d.addLayer()
        var s = d.state
        s.layers[1].surface.fill(PixelRect(x: 10, y: 10, width: 20, height: 20), with: ColorBgra(r: 255, g: 0, b: 0))
        d.commit(s, name: "Rechteck", kind: .edit)
        let before = d.flattenedSurface()
        XCTAssertEqual(before[15, 15], ColorBgra(r: 255, g: 0, b: 0))
        d.toggleVisibility(at: 1)
        XCTAssertEqual(d.flattenedSurface()[15, 15], .white, "ausgeblendet → Rechteck weg")
        d.toggleVisibility(at: 1)
        XCTAssertEqual(d.flattenedSurface(), before)
        d.mergeLayerDown()
        XCTAssertEqual(d.layers.count, 1)
        XCTAssertEqual(d.flattenedSurface(), before, "Zusammenführen ändert das sichtbare Ergebnis nicht")
    }

    func testMoveLayer() {
        let d = makeDoc()
        d.addLayer()
        XCTAssertFalse(d.canMoveLayer(.up))
        d.moveLayer(.down)
        XCTAssertEqual(d.layers[0].name, "Ebene 2")
        XCTAssertEqual(d.activeLayerIndex, 0)
        d.moveLayer(.top)
        XCTAssertEqual(d.layers[1].name, "Ebene 2")
    }

    func testRotateChangesSizeAndUndoRestores() {
        let d = makeDoc()
        d.transformImage(.rotate90CW)
        XCTAssertEqual(d.size, PixelSize(600, 800))
        XCTAssertEqual(d.layers[0].surface.size, PixelSize(600, 800))
        d.undo()
        XCTAssertEqual(d.size, PixelSize(800, 600))
    }

    func testFlatten() {
        let d = makeDoc()
        d.addLayer()
        let c = d.flattenedSurface()
        d.flatten()
        XCTAssertEqual(d.layers.count, 1)
        XCTAssertEqual(d.layers[0].surface, c)
    }

    func testSavedStateTracking() {
        let d = makeDoc()
        d.markSaved(as: URL(fileURLWithPath: "/tmp/a.png"))
        XCTAssertFalse(d.isDirty)
        XCTAssertEqual(d.displayName, "a.png")
        d.addLayer(); XCTAssertTrue(d.isDirty)
        d.undo(); XCTAssertFalse(d.isDirty, "Rückgängig bis zum Speicherstand = unverändert")
    }

    func testInsertLayerGrowsCanvas() {
        let d = makeDoc()
        let big = TiledSurface(size: PixelSize(1000, 700), filledWith: .black)
        d.insertLayer(surface: big, name: "Eingefügt", growCanvas: true, historyName: "In neue Ebene einfügen")
        XCTAssertEqual(d.size, PixelSize(1000, 700))
        XCTAssertEqual(d.layers[0].surface[900, 650], .transparent, "neue Fläche transparent")
        XCTAssertEqual(d.layers[1].surface[999, 699], .black)
    }

    func testObserverIsNotified() {
        let d = makeDoc()
        var got: [Document.Change] = []
        d.observe { got.append($0) }
        d.addLayer()
        XCTAssertTrue(got.contains { if case .history = $0 { return true }; return false })
    }

    func testCompositorPerformanceLargeEmptyLayers() {
        // 10000 × 10000 mit leeren Ebenen darf keine Pixelarbeit auslösen
        let size = PixelSize(10000, 10000)
        let layers = [Layer(name: "a", size: size), Layer(name: "b", size: size)]
        let t0 = Date()
        let out = Compositor.flatten(layers, size: size)
        XCTAssertEqual(out.allocatedTileCount, 0)
        XCTAssertLessThan(Date().timeIntervalSince(t0), 1.0)
    }

    func testLayerPropertiesPreview() {
        let d = makeDoc()
        d.addLayer()
        let n = d.history.count
        var p = d.activeLayer.properties
        p.opacity = 100; p.blendMode = .multiply
        d.previewLayerProperties(p, at: 1)
        XCTAssertEqual(d.layers[1].opacity, 100)
        XCTAssertEqual(d.history.count, n, "Vorschau erzeugt keinen Verlaufsschritt")
        d.endLayerPropertiesPreview(apply: false, at: 1)
        XCTAssertEqual(d.layers[1].opacity, 255, "Abbrechen stellt zurück")
        XCTAssertFalse(d.isPreviewing)
        d.previewLayerProperties(p, at: 1)
        d.endLayerPropertiesPreview(apply: true, at: 1)
        XCTAssertEqual(d.layers[1].blendMode, .multiply)
        XCTAssertEqual(d.history.count, n + 1)
        XCTAssertEqual(d.history.last?.name, "Ebeneneigenschaften")
        d.undo(); XCTAssertEqual(d.layers[1].opacity, 255)
    }
}
