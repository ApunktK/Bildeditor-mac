import XCTest
import EditorCore
@testable import EditorDocument

final class PaintingTests: XCTestCase {
    func makeDoc() -> Document { Document(size: PixelSize(100, 80), dpi: 96, name: "T") }
    let red = ColorBgra(r: 255, g: 0, b: 0)

    func testBrushStrokeAndHistory() {
        let d = makeDoc()
        let s = StrokeSession(base: d.state, kind: .brush(red), width: 10, antialias: true, blend: .normal)
        s.add(x: 20, y: 20.25); s.add(x: 60, y: 20.25)
        d.previewStroke(s)
        XCTAssertEqual(d.layers[0].surface[40, 20], red)
        XCTAssertEqual(d.layers[0].surface[40, 30], .white)
        let edge = d.layers[0].surface[40, 15]   // Kante (Abstand 4,75 bei Radius 5) → teilweise
        XCTAssertTrue(edge.g > 0 && edge.g < 255, "Kantenglättung: \(edge)")
        let n = d.history.count
        d.commitStroke(s)
        XCTAssertEqual(d.history.count, n + 1)
        XCTAssertEqual(d.history.last?.name, "Pinsel")
        XCTAssertFalse(d.isPreviewing)
        d.undo()
        XCTAssertEqual(d.layers[0].surface[40, 20], .white)
    }

    func testOverlapDoesNotAccumulateWithinStroke() {
        let d = makeDoc()
        let half = ColorBgra(r: 0, g: 0, b: 0, a: 128)
        let s = StrokeSession(base: d.state, kind: .brush(half), width: 6, antialias: false, blend: .normal)
        s.add(x: 30, y: 30); s.add(x: 50, y: 30); s.add(x: 30, y: 30)
        let once = PaintBlend.normal.apply(.white, half, cov: 255)
        XCTAssertEqual(s.working[40, 30], once, "Hin und zurück im selben Strich: nicht doppelt")
    }

    func testAliasedWidth() {
        let d = makeDoc()
        let s = StrokeSession(base: d.state, kind: .brush(red), width: 4, antialias: false, blend: .normal)
        s.add(x: 50.5, y: 40.5)
        // Radius 2: Pixel mit Mittelpunkt im Abstand ≤ 2
        XCTAssertEqual(s.working[52, 40], red); XCTAssertEqual(s.working[53, 40], .white)
        XCTAssertEqual(s.working[50, 38], red); XCTAssertEqual(s.working[51, 38], .white)
    }

    func testSelectionClipsStroke() {
        let d = makeDoc()
        d.setSelection(.rectangle(PixelRect(x: 0, y: 0, width: 40, height: 80), in: d.size), name: "R")
        let s = StrokeSession(base: d.state, kind: .brush(red), width: 4, antialias: false, blend: .normal)
        s.add(x: 20, y: 10); s.add(x: 80, y: 10)
        XCTAssertEqual(s.working[30, 10], red)
        XCTAssertEqual(s.working[50, 10], .white, "außerhalb der Auswahl unverändert")
    }

    func testEraserAndOverwrite() {
        let d = makeDoc()
        let e = StrokeSession(base: d.state, kind: .eraser, width: 4, antialias: false, blend: .normal)
        e.add(x: 10.5, y: 10.5)
        XCTAssertEqual(e.working[10, 10], .transparent)
        let o = StrokeSession(base: d.state, kind: .brush(ColorBgra(r: 0, g: 0, b: 255, a: 0)), width: 4, antialias: false, blend: .overwrite)
        o.add(x: 10.5, y: 10.5)
        XCTAssertEqual(o.working[10, 10], ColorBgra(r: 0, g: 0, b: 255, a: 0), "Überschreiben ersetzt auch Alpha")
        let n = StrokeSession(base: d.state, kind: .brush(ColorBgra(r: 0, g: 0, b: 255, a: 0)), width: 4, antialias: false, blend: .normal)
        n.add(x: 10.5, y: 10.5)
        XCTAssertEqual(n.working[10, 10], .white, "Normal mit transparenter Farbe ändert nichts")
    }

    func testPencilLine() {
        let d = makeDoc()
        let s = StrokeSession(base: d.state, kind: .pencil(red), width: 30, antialias: true, blend: .normal)
        s.add(x: 0.5, y: 0.5); s.add(x: 9.5, y: 3.5)
        XCTAssertEqual(s.working[0, 0], red)
        XCTAssertEqual(s.working[9, 3], red)
        XCTAssertEqual(s.working[0, 1], .white, "Stift immer 1 Pixel")
        var count = 0
        for y in 0..<10 { for x in 0..<12 where s.working[x, y] == red { count += 1 } }
        XCTAssertEqual(count, 10)
        XCTAssertEqual(s.historyName, "Stift")
    }

    func testFloodFill() {
        let d = makeDoc()
        var st = d.state
        st.layers[0].surface.fill(PixelRect(x: 50, y: 0, width: 2, height: 80), with: .black)
        d.commit(st, name: "x", kind: .edit)
        XCTAssertTrue(d.floodFill(at: PixelPoint(10, 10), color: red, tolerance: 0.5, global: false, sampleImage: false, blend: .normal))
        XCTAssertEqual(d.layers[0].surface[49, 79], red)
        XCTAssertEqual(d.layers[0].surface[60, 10], .white, "hinter der Linie nicht gefüllt")
        XCTAssertEqual(d.history.last?.name, "Farbeimer")
        d.floodFill(at: PixelPoint(60, 10), color: red, tolerance: 0.5, global: true, sampleImage: false, blend: .normal)
        XCTAssertEqual(d.layers[0].surface[99, 0], red)
        XCTAssertEqual(d.layers[0].surface[50, 0], .black)
    }

    func testFloodFillRespectsSelection() {
        let d = makeDoc()
        d.setSelection(.rectangle(PixelRect(x: 0, y: 0, width: 10, height: 10), in: d.size), name: "R")
        XCTAssertFalse(d.floodFill(at: PixelPoint(50, 50), color: red, tolerance: 0.5, global: false, sampleImage: false, blend: .normal))
        d.floodFill(at: PixelPoint(5, 5), color: red, tolerance: 0.5, global: false, sampleImage: false, blend: .normal)
        XCTAssertEqual(d.layers[0].surface[9, 9], red)
        XCTAssertEqual(d.layers[0].surface[10, 10], .white)
    }

    func testSampleColor() {
        let d = makeDoc()
        var st = d.state
        st.layers[0].surface[10, 10] = red
        st.layers[0].surface[11, 10] = .transparent
        d.commit(st, name: "x", kind: .edit)
        XCTAssertEqual(d.sampleColor(at: PixelPoint(10, 10), size: 1, sampleImage: false), red)
        let avg = d.sampleColor(at: PixelPoint(10, 10), size: 3, sampleImage: false)!
        // 7 weiße, 1 rotes, 1 transparentes Pixel
        XCTAssertEqual(avg.r, 255)
        let expectedG: Int = (7 * 255 * 255 + 1020) / 2040
        XCTAssertEqual(Int(avg.g), expectedG)
        let expectedA: Int = (8 * 255 + 4) / 9
        XCTAssertEqual(Int(avg.a), expectedA)
        XCTAssertNil(d.sampleColor(at: PixelPoint(-1, 0), size: 1, sampleImage: false))
    }

    func testIncrementalCompositeMatchesFull() {
        let d = makeDoc()
        d.addLayer()
        let old = d.layers
        let s = StrokeSession(base: d.state, kind: .brush(ColorBgra(r: 10, g: 200, b: 30, a: 140)), width: 8, antialias: true, blend: .normal)
        s.add(x: 5, y: 5); s.add(x: 90, y: 70)
        d.previewStroke(s)
        let r = Compositor.changedRect(old: old, new: d.layers, size: d.size)
        XCTAssertNotNil(r)
        var bytes = Compositor.premultipliedBGRA(old, size: d.size)
        Compositor.updatePremultiplied(&bytes, layers: d.layers, size: d.size, rect: r!)
        XCTAssertEqual(bytes, Compositor.premultipliedBGRA(d.layers, size: d.size))
        XCTAssertNil(Compositor.changedRect(old: old, new: Array(old.dropLast()), size: d.size))
    }

    func testCloneStamp() {
        let d = makeDoc()
        var st = d.state
        st.layers[0].surface.fill(PixelRect(x: 10, y: 10, width: 10, height: 10), with: red)
        d.commit(st, name: "x", kind: .edit)
        let s = StrokeSession(base: d.state, kind: .clone(dx: -40, dy: 0), width: 6, antialias: false, blend: .normal)
        s.add(x: 55, y: 15)
        XCTAssertEqual(s.working[55, 15], red, "Quelle 40 px links")
        XCTAssertEqual(s.working[70, 15], .white)
        XCTAssertEqual(s.historyName, "Kopierstempel")
    }

    func testRecolorKeepsShadingAndIgnoresOthers() {
        let d = makeDoc()
        var st = d.state
        st.layers[0].surface[20, 20] = ColorBgra(r: 200, g: 0, b: 0)
        st.layers[0].surface[21, 20] = ColorBgra(r: 180, g: 0, b: 0)
        d.commit(st, name: "x", kind: .edit)
        let s = StrokeSession(base: d.state, kind: .recolor(from: ColorBgra(r: 200, g: 0, b: 0), to: ColorBgra(r: 0, g: 0, b: 200), tolerance: 0.5),
                              width: 10, antialias: false, blend: .normal)
        s.add(x: 21, y: 20.5)
        XCTAssertEqual(s.working[20, 20], ColorBgra(r: 0, g: 0, b: 200))
        XCTAssertEqual(s.working[21, 20], ColorBgra(r: 0, g: 0, b: 180), "Schattierung bleibt")
        XCTAssertEqual(s.working[23, 20], .white, "Weiß weicht zu stark ab")
    }
}
