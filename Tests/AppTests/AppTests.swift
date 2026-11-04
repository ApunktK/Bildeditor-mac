import XCTest
import EditorCore
import EditorDocument
@testable import Bildeditor

final class AppTests: XCTestCase {
    func testPNGRoundTripKeepsStraightAlpha() throws {
        var s = TiledSurface(width: 300, height: 260)
        let colors: [ColorBgra] = [ColorBgra(r: 200, g: 100, b: 50, a: 128), ColorBgra(r: 1, g: 2, b: 3, a: 1),
                                   ColorBgra(r: 255, g: 255, b: 255, a: 254), ColorBgra(r: 0, g: 0, b: 0, a: 255)]
        for (i, c) in colors.enumerated() { s[i * 70, 257] = c }
        let fmt = try XCTUnwrap(ImageCodec.writableFormats.first { $0.id == "png" })
        let data = try ImageCodec.encode(s, dpi: 150, format: fmt, quality: 100)
        let back = try ImageCodec.load(data: data)
        XCTAssertEqual(back.surface.size, s.size)
        for (i, c) in colors.enumerated() { XCTAssertEqual(back.surface[i * 70, 257], c) }
        XCTAssertEqual(back.surface[10, 10], .transparent)
        XCTAssertEqual(back.dpi, 150, accuracy: 0.5)
    }

    func testJPEGFlattensOntoWhite() throws {
        var s = TiledSurface(width: 16, height: 16)
        s.fill(PixelRect(x: 0, y: 0, width: 16, height: 16), with: ColorBgra(r: 0, g: 0, b: 0, a: 0))
        let fmt = try XCTUnwrap(ImageCodec.writableFormats.first { $0.id == "jpeg" })
        let back = try ImageCodec.load(data: try ImageCodec.encode(s, dpi: 96, format: fmt, quality: 100))
        let c = back.surface[8, 8]
        XCTAssertEqual(c.a, 255)
        XCTAssertGreaterThan(c.r, 250, "transparent → weiß")
    }

    func testFlattenOntoWhiteMath() {
        var b: [UInt8] = [0, 0, 0, 128,  10, 20, 30, 255]
        ImageCodec.flattenOntoWhite(&b)
        XCTAssertEqual(Array(b[0..<4]), [127, 127, 127, 255])
        XCTAssertEqual(Array(b[4..<8]), [10, 20, 30, 255])
    }

    func testHSV() {
        XCTAssertEqual(HSV(ColorBgra(r: 255, g: 0, b: 0)), HSV(h: 0, s: 100, v: 100))
        XCTAssertEqual(HSV(h: 240, s: 100, v: 100).color(), ColorBgra(r: 0, g: 0, b: 255))
        XCTAssertEqual(HSV(h: 0, s: 0, v: 50).color(), ColorBgra(r: 128, g: 128, b: 128))
        for c in DefaultPalette.colors { XCTAssertEqual(HSV(c).color(), c, "Hin- und Rückweg für \(c)") }
        XCTAssertEqual(DefaultPalette.colors.count, 96)
    }

    func testZoomParsingAndSlider() {
        XCTAssertEqual(StatusBarView.parseZoom("150 %"), 150)
        XCTAssertEqual(StatusBarView.parseZoom("66,5"), 66.5)
        XCTAssertNil(StatusBarView.parseZoom("abc"))
        XCTAssertEqual(StatusBarView.zoomText(66.666), "66,67 %")
        for z in [1.0, 33, 100, 6400] {
            XCTAssertEqual(StatusBarView.zoom(forSlider: StatusBarView.sliderValue(forZoom: z)), z, accuracy: 0.0001)
        }
    }

    func testAllMenuCommandsRegistered() {
        let ctrl = AppController.shared
        var missing: [String] = []
        func walk(_ nodes: [MenuNode]) {
            for n in nodes {
                switch n {
                case let .cmd(id): if ctrl.commands[id] == nil { missing.append(id) }
                case let .submenu(_, sub): walk(sub)
                default: break
                }
            }
        }
        for (_, nodes) in ctrl.menuSpec { walk(nodes) }
        XCTAssertEqual(missing, [])
    }

    func testShortcutFormatting() {
        XCTAssertEqual(ShortcutFormatter.string(Shortcut("s", [.command, .shift])), "⇧⌘S")
        XCTAssertEqual(ShortcutFormatter.string(Shortcut.function(NSRightArrowFunctionKey, [.command, .option])), "⌥⌘→")
    }

    func testSingleKeyToolCycling() {
        let ctrl = AppController.shared
        ctrl.tool = .zoom
        XCTAssertTrue(ctrl.handleSingleKey("h", shift: false))
        XCTAssertEqual(ctrl.tool, .pan)
        XCTAssertTrue(ctrl.handleSingleKey("z", shift: false))
        XCTAssertEqual(ctrl.tool, .zoom)
        XCTAssertFalse(ctrl.handleSingleKey("q", shift: false))
    }
}

final class SelectionToolTests: XCTestCase {
    typealias M = SelectionInteraction.Modifiers
    func testModeFromModifiers() {
        XCTAssertEqual(SelectionInteraction.mode(base: .replace, M()), .replace)
        XCTAssertEqual(SelectionInteraction.mode(base: .intersect, M()), .intersect)
        XCTAssertEqual(SelectionInteraction.mode(base: .replace, M(command: true)), .union)
        XCTAssertEqual(SelectionInteraction.mode(base: .replace, M(option: true)), .exclude)
        XCTAssertEqual(SelectionInteraction.mode(base: .replace, M(command: true, right: true)), .xor)
        XCTAssertEqual(SelectionInteraction.mode(base: .replace, M(option: true, right: true)), .intersect)
    }

    func testSnappedRect() {
        XCTAssertEqual(SelectionInteraction.snappedRect(from: CGPoint(x: 10.4, y: 20.6), to: CGPoint(x: 5.2, y: 30.1), square: false),
                       CGRect(x: 5, y: 21, width: 5, height: 9))
        XCTAssertEqual(SelectionInteraction.snappedRect(from: CGPoint(x: 0, y: 0), to: CGPoint(x: 30, y: -10), square: true),
                       CGRect(x: 0, y: -30, width: 30, height: 30))
    }

    func testOutlineGraphics() {
        let m = SelectionMask.rectangle(PixelRect(x: 2, y: 3, width: 10, height: 4), in: PixelSize(20, 20))
        let g = SelectionRendering.graphics(for: m)
        XCTAssertEqual(g?.bounds, PixelRect(x: 2, y: 3, width: 10, height: 4))
        XCTAssertEqual(g?.path.boundingBox, CGRect(x: 2, y: 3, width: 10, height: 4))
        XCTAssertNotNil(g?.tint)
    }
}
