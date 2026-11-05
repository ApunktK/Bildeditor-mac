import XCTest
import EditorCore
@testable import EditorDocument

final class ShapeTests: XCTestCase {
    func makeDoc() -> Document { Document(size: PixelSize(200, 150), dpi: 96, name: "T") }
    let red = ColorBgra(r: 255, g: 0, b: 0), blue = ColorBgra(r: 0, g: 0, b: 255)

    func testFilledRectangleExact() {
        let d = makeDoc()
        let spec = ShapeSpec(kind: .rectangle, x0: 10, y0: 20, x1: 60, y1: 50, style: .fill, lineWidth: 2, antialias: false)
        let s = d.stateWithShape(spec, outline: red, fill: blue, blend: .normal)
        let l = s.layers[0].surface
        XCTAssertEqual(l[10, 20], red); XCTAssertEqual(l[59, 49], red)
        XCTAssertEqual(l[9, 20], .white); XCTAssertEqual(l[60, 49], .white); XCTAssertEqual(l[10, 50], .white)
    }

    func testOutlineAndFillWithOutline() {
        let d = makeDoc()
        let o = d.stateWithShape(ShapeSpec(kind: .rectangle, x0: 20, y0: 20, x1: 120, y1: 100, style: .outline, lineWidth: 4, antialias: false),
                                 outline: red, fill: blue, blend: .normal).layers[0].surface
        XCTAssertEqual(o[20, 60], red, "Kontur liegt mittig auf der Kante")
        XCTAssertEqual(o[70, 60], .white, "innen leer")
        XCTAssertEqual(o[17, 60], .white)
        let fo = d.stateWithShape(ShapeSpec(kind: .ellipse, x0: 20, y0: 20, x1: 120, y1: 100, style: .fillAndOutline, lineWidth: 4, antialias: true),
                                  outline: red, fill: blue, blend: .normal).layers[0].surface
        XCTAssertEqual(fo[70, 60], blue, "Füllung = zweite Farbe")
        XCTAssertEqual(fo[70, 20], red, "Kontur oben")
        XCTAssertEqual(fo[22, 22], .white, "Ecke außerhalb der Ellipse")
    }

    func testShapeKindsContain() {
        let tri = ShapeSpec(kind: .triangle, x0: 0, y0: 0, x1: 100, y1: 100, style: .fill, lineWidth: 1, antialias: false)
        XCTAssertTrue(tri.contains(50, 90, inset: 0)); XCTAssertFalse(tri.contains(5, 5, inset: 0))
        let dia = ShapeSpec(kind: .diamond, x0: 0, y0: 0, x1: 100, y1: 100, style: .fill, lineWidth: 1, antialias: false)
        XCTAssertTrue(dia.contains(50, 50, inset: 0)); XCTAssertFalse(dia.contains(10, 10, inset: 0))
        let rr = ShapeSpec(kind: .roundedRectangle, x0: 0, y0: 0, x1: 100, y1: 100, style: .fill, lineWidth: 1, antialias: false, radius: 20)
        XCTAssertFalse(rr.contains(1, 1, inset: 0)); XCTAssertTrue(rr.contains(10, 50, inset: 0)); XCTAssertTrue(rr.contains(50, 1, inset: 0))
    }

    func testAntialiasedEdgesPartial() {
        let d = makeDoc()
        let s = d.stateWithShape(ShapeSpec(kind: .ellipse, x0: 10, y0: 10, x1: 110, y1: 110, style: .fill, lineWidth: 1, antialias: true),
                                 outline: red, fill: blue, blend: .normal).layers[0].surface
        var partial = 0
        for x in 10..<110 { let c = s[x, 30]; if c != red && c != .white { partial += 1 } }
        XCTAssertGreaterThan(partial, 0)
    }

    func testLineWidthDashArrow() {
        let d = makeDoc()
        let l = d.stateWithLine(LineSpec(x0: 10, y0: 50.5, x1: 190, y1: 50.5, width: 5, antialias: false), color: red, blend: .normal).layers[0].surface
        XCTAssertEqual(l[100, 50], red); XCTAssertEqual(l[100, 48], red); XCTAssertEqual(l[100, 52], red); XCTAssertEqual(l[100, 54], .white)
        let dashed = d.stateWithLine(LineSpec(x0: 10, y0: 50.5, x1: 190, y1: 50.5, width: 4, antialias: false, dash: .dashed),
                                     color: red, blend: .normal).layers[0].surface
        var gaps = 0
        for x in 12..<188 where dashed[x, 50] == .white { gaps += 1 }
        XCTAssertGreaterThan(gaps, 20, "Lücken bei gestrichelter Linie")
        let arrow = d.stateWithLine(LineSpec(x0: 10, y0: 100.5, x1: 150, y1: 100.5, width: 2, antialias: false, arrowEnd: true),
                                    color: red, blend: .normal).layers[0].surface
        XCTAssertEqual(arrow[145, 100], red)
        XCTAssertEqual(arrow[143, 103], red, "Pfeilspitze breiter als die Linie")
        XCTAssertEqual(arrow[60, 104], .white)
        let s = LineSpec.snapped(from: (0, 0), to: (100, 7))
        XCTAssertEqual(s.y, 0, accuracy: 1e-9)
    }

    func testGradients() {
        let d = makeDoc()
        let g = GradientSpec(kind: .linear, x0: 0, y0: 0, x1: 200, y1: 0, start: .black, end: .white)
        XCTAssertEqual(g.t(0, 5), 0); XCTAssertEqual(g.t(100, 5), 0.5); XCTAssertEqual(g.t(250, 5), 1)
        let s = d.stateWithGradient(g, blend: .normal).layers[0].surface
        XCTAssertEqual(s[0, 10].r, 0, accuracy: 1)
        XCTAssertEqual(Int(s[100, 10].r), 128, accuracy: 1)
        XCTAssertEqual(s[199, 10].r, 254, accuracy: 1)
        XCTAssertEqual(GradientSpec(kind: .reflected, x0: 100, y0: 0, x1: 200, y1: 0, start: .black, end: .white).t(50, 0), 0.5)
        XCTAssertEqual(GradientSpec(kind: .radial, x0: 100, y0: 75, x1: 150, y1: 75, start: .black, end: .white).t(100, 100), 0.5)
        XCTAssertEqual(GradientSpec(kind: .conical, x0: 100, y0: 75, x1: 150, y1: 75, start: .black, end: .white).t(50, 75), 1, accuracy: 1e-9)
        let saw = GradientSpec(kind: .linear, x0: 0, y0: 0, x1: 100, y1: 0, start: .black, end: .white, repeatMode: .sawtooth)
        XCTAssertEqual(saw.t(150, 0), 0.5, accuracy: 1e-9)
        let refl = GradientSpec(kind: .linear, x0: 0, y0: 0, x1: 100, y1: 0, start: .black, end: .white, repeatMode: .reflect)
        XCTAssertEqual(refl.t(150, 0), 0.5, accuracy: 1e-9); XCTAssertEqual(refl.t(190, 0), 0.1, accuracy: 1e-9)
        let sp = GradientSpec(kind: .spiralClockwise, x0: 100, y0: 75, x1: 150, y1: 75, start: .black, end: .white)
        XCTAssertTrue((0..<1).contains(sp.t(10, 10)))
        XCTAssertEqual(GradientSpec(kind: .diamond, x0: 100, y0: 75, x1: 150, y1: 75, start: .black, end: .white).t(125, 100), 1, accuracy: 1e-9)
    }

    func testGradientTransparencyModeAndSelection() {
        let d = makeDoc()
        d.setSelection(.rectangle(PixelRect(x: 0, y: 0, width: 100, height: 150), in: d.size), name: "R")
        let g = GradientSpec(kind: .linear, x0: 0, y0: 0, x1: 100, y1: 0, start: .black, end: .white, transparencyMode: true)
        let s = d.stateWithGradient(g, blend: .normal).layers[0].surface
        XCTAssertEqual(s[0, 5].a, 255, accuracy: 3)
        XCTAssertEqual(Int(s[50, 5].a), 127, accuracy: 2)
        XCTAssertEqual(s[150, 5], .white, "außerhalb der Auswahl unverändert")
        XCTAssertEqual(s[50, 5].r, 255, "Transparenzmodus ändert keine Farbe")
    }
}
