import XCTest
import EditorCore
@testable import EditorDocument

final class SelectionMaskTests: XCTestCase {
    let size = PixelSize(600, 400)

    func testRectangleAndBounds() {
        let m = SelectionMask.rectangle(PixelRect(x: 10, y: 20, width: 300, height: 100), in: size)
        XCTAssertEqual(m.bounds, PixelRect(x: 10, y: 20, width: 300, height: 100))
        XCTAssertEqual(m.selectedPixelCount, 30000)
        XCTAssertEqual(m[10, 20], 255); XCTAssertEqual(m[9, 20], 0); XCTAssertEqual(m[309, 119], 255); XCTAssertEqual(m[310, 119], 0)
        XCTAssertFalse(m.isEmpty)
    }

    func testAllUsesFullTiles() {
        let m = SelectionMask.all(PixelSize(10000, 10000))
        XCTAssertEqual(m.bounds, PixelRect(x: 0, y: 0, width: 10000, height: 10000))
        XCTAssertEqual(m[9999, 9999], 255)
        XCTAssertEqual(m[10000, 0], 0)
    }

    func testRectangleClippedToCanvas() {
        let m = SelectionMask.rectangle(PixelRect(x: -50, y: -50, width: 100, height: 100), in: size)
        XCTAssertEqual(m.bounds, PixelRect(x: 0, y: 0, width: 50, height: 50))
    }

    func testEllipseSymmetric() {
        let m = SelectionMask.ellipse(PixelRect(x: 100, y: 100, width: 101, height: 61), in: size)
        XCTAssertEqual(m.bounds, PixelRect(x: 100, y: 100, width: 101, height: 61))
        for y in 100..<161 { for x in 100..<201 { XCTAssertEqual(m[x, y], m[300 - x, y]); XCTAssertEqual(m[x, y], m[x, 260 - y]) } }
        XCTAssertEqual(m[150, 130], 255)
        XCTAssertEqual(m[100, 100], 0)
        let area = Double(m.selectedPixelCount), expected = Double.pi * 50.5 * 30.5
        XCTAssertEqual(area, expected, accuracy: expected * 0.03)
    }

    func testPolygonTriangle() {
        let m = SelectionMask.polygon([(0, 0), (100, 0), (0, 100)], in: size)
        XCTAssertEqual(m[1, 1], 255)
        XCTAssertEqual(m[98, 98], 0)
        XCTAssertEqual(Double(m.selectedPixelCount), 5000, accuracy: 120)
        XCTAssertTrue(SelectionMask.polygon([(0, 0), (5, 5)], in: size).isEmpty)
    }

    func testModes() {
        let a = SelectionMask.rectangle(PixelRect(x: 0, y: 0, width: 300, height: 300), in: size)
        let b = SelectionMask.rectangle(PixelRect(x: 200, y: 200, width: 300, height: 100), in: size)
        XCTAssertEqual(a.combined(with: b, mode: .replace), b)
        XCTAssertEqual(a.combined(with: b, mode: .union).selectedPixelCount, 90000 + 30000 - 10000)
        XCTAssertEqual(a.combined(with: b, mode: .intersect).bounds, PixelRect(x: 200, y: 200, width: 100, height: 100))
        XCTAssertEqual(a.combined(with: b, mode: .exclude).selectedPixelCount, 80000)
        XCTAssertEqual(a.combined(with: b, mode: .xor).selectedPixelCount, 120000 - 20000)
        XCTAssertEqual(a.inverted().selectedPixelCount, 240000 - 90000)
        XCTAssertTrue(a.combined(with: a, mode: .xor).isEmpty)
        XCTAssertEqual(a.inverted().inverted(), a)
    }

    func testTransformsMatchSurfaceTransforms() {
        let m = SelectionMask.rectangle(PixelRect(x: 3, y: 5, width: 10, height: 4), in: PixelSize(40, 30))
        var s = TiledSurface(width: 40, height: 30)
        for y in 0..<30 { for x in 0..<40 where m[x, y] == 255 { s[x, y] = .black } }
        func same(_ mm: SelectionMask, _ ss: TiledSurface) {
            XCTAssertEqual(mm.size, ss.size)
            for y in 0..<ss.height { for x in 0..<ss.width { XCTAssertEqual(mm[x, y] == 255, ss[x, y] == .black, "\(x),\(y)") } }
        }
        same(m.rotated90Clockwise(), s.rotated90Clockwise())
        same(m.rotated90CounterClockwise(), s.rotated90CounterClockwise())
        same(m.flippedHorizontally(), s.flippedHorizontally())
        same(m.flippedVertically(), s.flippedVertically())
        same(m.rotated180(), s.rotated180())
    }

    func testTranslateAndOutline() {
        let m = SelectionMask.rectangle(PixelRect(x: 10, y: 10, width: 20, height: 5), in: size)
        XCTAssertEqual(m.translated(dx: 5, dy: -3).bounds, PixelRect(x: 15, y: 7, width: 20, height: 5))
        let segs = m.outlineSegments()
        XCTAssertEqual(segs.count, 4)
        let total = segs.map { abs($0.x1 - $0.x0) + abs($0.y1 - $0.y0) }.reduce(0, +)
        XCTAssertEqual(total, 2 * (20 + 5))
    }

    func testMagicWand() {
        var s = TiledSurface(size: PixelSize(50, 50), filledWith: .white)
        s.fill(PixelRect(x: 10, y: 10, width: 10, height: 10), with: ColorBgra(r: 255, g: 0, b: 0))
        s.fill(PixelRect(x: 30, y: 30, width: 5, height: 5), with: ColorBgra(r: 250, g: 0, b: 0))
        let c = SelectionMask.magicWand(on: s, at: PixelPoint(12, 12), tolerance: 0.5, global: false)
        XCTAssertEqual(c.bounds, PixelRect(x: 10, y: 10, width: 10, height: 10))
        let g = SelectionMask.magicWand(on: s, at: PixelPoint(12, 12), tolerance: 0.5, global: true)
        XCTAssertEqual(g.selectedPixelCount, 125)
        let exact = SelectionMask.magicWand(on: s, at: PixelPoint(12, 12), tolerance: 0, global: true)
        XCTAssertEqual(exact.selectedPixelCount, 100)
        let bg = SelectionMask.magicWand(on: s, at: PixelPoint(0, 0), tolerance: 0.5, global: false)
        XCTAssertEqual(bg.selectedPixelCount, 2500 - 125)
    }
}

final class DocumentSelectionTests: XCTestCase {
    func makeDoc() -> Document { Document(size: PixelSize(100, 80), dpi: 96, name: "T") }

    func testSelectAllDeselectInvertHistory() {
        let d = makeDoc()
        d.selectAll()
        XCTAssertTrue(d.hasSelection)
        XCTAssertEqual(d.history.last?.name, "Alles auswählen")
        d.invertSelection()
        XCTAssertFalse(d.hasSelection)
        d.undo()
        XCTAssertTrue(d.hasSelection)
        d.deselect()
        XCTAssertNil(d.state.selection)
        let n = d.history.count
        d.deselect()
        XCTAssertEqual(d.history.count, n, "keine Änderung = kein Verlaufsschritt")
    }

    func testEraseFillCopyCut() {
        let d = makeDoc()
        d.setSelection(.rectangle(PixelRect(x: 10, y: 10, width: 20, height: 10), in: d.size), name: "Rechteckauswahl")
        d.fillSelection(with: ColorBgra(r: 0, g: 0, b: 255))
        XCTAssertEqual(d.layers[0].surface[10, 10], ColorBgra(r: 0, g: 0, b: 255))
        XCTAssertEqual(d.layers[0].surface[9, 10], .white)
        XCTAssertTrue(d.hasSelection, "Füllen behält die Auswahl")
        let copy = d.selectedPixels(merged: false)
        XCTAssertEqual(copy.size, PixelSize(20, 10))
        XCTAssertEqual(copy[0, 0], ColorBgra(r: 0, g: 0, b: 255))
        d.eraseSelection()
        XCTAssertEqual(d.layers[0].surface[15, 15], .transparent)
        XCTAssertFalse(d.hasSelection, "Löschen hebt die Auswahl auf")
        d.undo()
        XCTAssertTrue(d.hasSelection)
        let cut = d.cutSelection()
        XCTAssertEqual(cut?[5, 5], ColorBgra(r: 0, g: 0, b: 255))
        XCTAssertEqual(d.layers[0].surface[15, 15], .transparent)
        XCTAssertEqual(d.history.last?.name, "Ausschneiden")
    }

    func testCropEllipseMakesCornersTransparent() {
        let d = makeDoc()
        d.setSelection(.ellipse(PixelRect(x: 20, y: 10, width: 40, height: 30), in: d.size), name: "Ellipsenauswahl")
        d.cropToSelection()
        XCTAssertEqual(d.size, PixelSize(40, 30))
        XCTAssertEqual(d.layers[0].surface[0, 0], .transparent)
        XCTAssertEqual(d.layers[0].surface[20, 15], .white)
        XCTAssertNil(d.state.selection)
        d.undo()
        XCTAssertEqual(d.size, PixelSize(100, 80))
    }

    func testCropRectKeepsTransparentPixelValues() {
        let d = makeDoc()
        var s = d.state
        s.layers[0].surface[15, 15] = ColorBgra(r: 1, g: 2, b: 3, a: 0)
        d.commit(s, name: "x", kind: .edit)
        d.setSelection(.rectangle(PixelRect(x: 10, y: 10, width: 10, height: 10), in: d.size), name: "R")
        d.cropToSelection()
        XCTAssertEqual(d.layers[0].surface[5, 5], ColorBgra(r: 1, g: 2, b: 3, a: 0))
    }

    func testMoveSelectedPixelsFloatingCommit() {
        let d = makeDoc()
        var s = d.state
        s.layers[0].surface.fill(PixelRect(x: 10, y: 10, width: 5, height: 5), with: .black)
        d.commit(s, name: "x", kind: .edit)
        d.setSelection(.rectangle(PixelRect(x: 10, y: 10, width: 5, height: 5), in: d.size), name: "R")
        let n = d.history.count
        guard let f = d.liftSelectedPixels(copy: false) else { return XCTFail() }
        d.beginFloating(f)
        d.moveFloating(to: PixelPoint(50, 40))
        d.moveFloating(to: PixelPoint(60, 40))
        XCTAssertEqual(d.history.count, n, "Verschieben läuft als Vorschau")
        XCTAssertEqual(d.layers[0].surface[10, 10], .transparent, "Ursprung geleert")
        XCTAssertEqual(d.floating?.rect, PixelRect(x: 60, y: 40, width: 5, height: 5))
        XCTAssertEqual(d.floating?.composed().layers[0].surface[60, 40], .black)
        d.commitFloating()
        XCTAssertEqual(d.layers[0].surface[60, 40], .black)
        XCTAssertEqual(d.selectionBounds, PixelRect(x: 60, y: 40, width: 5, height: 5))
        XCTAssertEqual(d.history.count, n + 1)
        XCTAssertEqual(d.history.last?.name, "Ausgewählte Pixel verschieben")
        XCTAssertFalse(d.isPreviewing)
        d.undo()
        XCTAssertEqual(d.layers[0].surface[10, 10], .black)
        XCTAssertEqual(d.layers[0].surface[60, 40], .white)
    }

    func testFloatingOffCanvasKeepsPixelsUntilCommit() {
        let d = makeDoc()
        d.setSelection(.rectangle(PixelRect(x: 0, y: 0, width: 10, height: 10), in: d.size), name: "R")
        let f = d.liftSelectedPixels(copy: true)!
        d.beginFloating(f)
        d.moveFloating(to: PixelPoint(-100, 0))
        d.moveFloating(to: PixelPoint(40, 0))
        XCTAssertEqual(d.floating?.composed().layers[0].surface[45, 5], .white)
        XCTAssertEqual(d.layers[0].surface[5, 5], .white, "Kopie: Ursprung bleibt")
        d.undo()   // schließt das Verschieben ab und macht es dann rückgängig
        XCTAssertFalse(d.isPreviewing)
        XCTAssertEqual(d.history.last?.name, "Kopie der Pixel verschieben")
    }

    func testPasteFloatingAndNewLayer() {
        let d = makeDoc()
        let img = TiledSurface(size: PixelSize(30, 20), filledWith: ColorBgra(r: 0, g: 255, b: 0, a: 128))
        d.beginFloating(d.floatingPaste(img, at: PixelPoint(5, 5), intoNewLayer: false, growCanvas: false))
        d.commitFloating()
        XCTAssertEqual(d.history.last?.name, "Einfügen")
        let c = d.layers[0].surface[10, 10]
        XCTAssertEqual(c.a, 255); XCTAssertTrue(c.g > 200 && c.r < 140, "halbtransparent über Weiß gemischt: \(c)")
        XCTAssertEqual(d.selectionBounds, PixelRect(x: 5, y: 5, width: 30, height: 20))
        d.beginFloating(d.floatingPaste(img, at: .zero, intoNewLayer: true, growCanvas: false))
        d.commitFloating()
        XCTAssertEqual(d.layers.count, 2)
        XCTAssertEqual(d.layers[1].surface[0, 0], ColorBgra(r: 0, g: 255, b: 0, a: 128), "auf transparenter Ebene exakt")
        let big = TiledSurface(size: PixelSize(150, 90), filledWith: .black)
        d.beginFloating(d.floatingPaste(big, at: .zero, intoNewLayer: false, growCanvas: true))
        d.commitFloating()
        XCTAssertEqual(d.size, PixelSize(150, 90))
    }

    func testImageRotateCarriesSelection() {
        let d = makeDoc()
        d.setSelection(.rectangle(PixelRect(x: 0, y: 0, width: 10, height: 5), in: d.size), name: "R")
        d.transformImage(.rotate90CW)
        XCTAssertEqual(d.selectionBounds, PixelRect(x: 75, y: 0, width: 5, height: 10))
    }

    func testCancelFloatingRestores() {
        let d = makeDoc()
        d.setSelection(.rectangle(PixelRect(x: 0, y: 0, width: 10, height: 10), in: d.size), name: "R")
        let n = d.history.count
        d.beginFloating(d.liftSelectedPixels(copy: false)!)
        XCTAssertEqual(d.layers[0].surface[5, 5], .transparent)
        d.cancelFloating()
        XCTAssertEqual(d.layers[0].surface[5, 5], .white)
        XCTAssertEqual(d.history.count, n)
        XCTAssertTrue(d.hasSelection)
    }

    func testSelectionChangeDoesNotReportContent() {
        let d = makeDoc()
        var changes: [Document.Change] = []
        d.observe { changes.append($0) }
        d.selectAll()
        XCTAssertTrue(changes.contains(.selection))
        XCTAssertFalse(changes.contains(.content), "nur Auswahl geändert → Bild nicht neu zusammensetzen")
    }

    func testSelectionPreviewDuringDrag() {
        let d = makeDoc()
        let n = d.history.count
        d.previewSelection(.rectangle(PixelRect(x: 0, y: 0, width: 5, height: 5), in: d.size))
        d.previewSelection(.rectangle(PixelRect(x: 0, y: 0, width: 8, height: 8), in: d.size))
        XCTAssertEqual(d.history.count, n)
        XCTAssertEqual(d.selectionBounds?.width, 8)
        d.setSelection(.rectangle(PixelRect(x: 0, y: 0, width: 8, height: 8), in: d.size), name: "Rechteckauswahl")
        XCTAssertEqual(d.history.count, n + 1)
        XCTAssertFalse(d.isPreviewing)
    }
}
