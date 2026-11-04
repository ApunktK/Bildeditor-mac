import XCTest
@testable import EditorCore

final class ColorTests: XCTestCase {
    func testPackedRoundTripAndByteOrder() {
        let c = ColorBgra(r: 0x11, g: 0x22, b: 0x33, a: 0x44)
        XCTAssertEqual(c.packed, 0x4411_2233)
        XCTAssertEqual(ColorBgra(packed: c.packed), c)
    }

    func testHex() {
        XCTAssertEqual(ColorBgra(hex: "#FF00FF"), ColorBgra(r: 255, g: 0, b: 255))
        XCTAssertEqual(ColorBgra(hex: "ff00ff80")?.a, 0x80)
        XCTAssertNil(ColorBgra(hex: "XYZ"))
        XCTAssertNil(ColorBgra(hex: "12345"))
        XCTAssertEqual(ColorBgra(r: 1, g: 2, b: 3).hexString, "010203")
        XCTAssertEqual(ColorBgra(r: 1, g: 2, b: 3, a: 4).hexString, "01020304")
        XCTAssertEqual(ColorBgra(r: 1, g: 2, b: 3, a: 4).argbHexString, "04010203")
    }
}

final class SurfaceTests: XCTestCase {
    func testEmptySurfaceAllocatesNothing() {
        let s = TiledSurface(width: 1000, height: 700)
        XCTAssertEqual(s.tilesX, 4); XCTAssertEqual(s.tilesY, 3)
        XCTAssertEqual(s.allocatedTileCount, 0)
        XCTAssertEqual(s[999, 699], .transparent)
    }

    func testSetPixelAllocatesOneTile() {
        var s = TiledSurface(width: 600, height: 600)
        s[300, 300] = .black
        XCTAssertEqual(s.allocatedTileCount, 1)
        XCTAssertEqual(s[300, 300], .black)
        XCTAssertEqual(s[299, 300], .transparent)
        s[10, 10] = .transparent   // setzt in leerer Kachel nichts an
        XCTAssertEqual(s.allocatedTileCount, 1)
    }

    func testFillAcrossTilesAndEdges() {
        var s = TiledSurface(width: 300, height: 260)
        s.fill(PixelRect(x: 250, y: 250, width: 100, height: 100), with: .white)
        XCTAssertEqual(s[250, 250], .white)
        XCTAssertEqual(s[299, 259], .white)
        XCTAssertEqual(s[249, 250], .transparent)
        XCTAssertEqual(s.allocatedTileCount, 4)
    }

    func testCopyOnWriteSharesUntilChanged() {
        var a = TiledSurface(size: PixelSize(512, 512), filledWith: .white)
        let b = a
        a[0, 0] = .black
        XCTAssertEqual(b[0, 0], .white, "Kopie darf sich nicht mitändern")
        let changed = a.changedTiles(comparedTo: b)
        XCTAssertEqual(changed.count, 1)
        XCTAssertEqual(changed.first?.tx, 0); XCTAssertEqual(changed.first?.ty, 0)
    }

    func testBytesRoundTrip() {
        var s = TiledSurface(width: 3, height: 2)
        s[0, 0] = ColorBgra(r: 1, g: 2, b: 3, a: 4)
        s[2, 1] = ColorBgra(r: 9, g: 8, b: 7, a: 255)
        let bytes = s.bgraBytes()
        XCTAssertEqual(Array(bytes[0..<4]), [3, 2, 1, 4])
        XCTAssertEqual(Array(bytes[20..<24]), [7, 8, 9, 255])
        XCTAssertEqual(TiledSurface(width: 3, height: 2, bgra: bytes), s)
    }

    func testRgbUnderZeroAlphaIsPreserved() {
        var s = TiledSurface(width: 1, height: 1)
        s[0, 0] = .transparentWhite
        XCTAssertEqual(s[0, 0], .transparentWhite, "#FFFFFF00 muss erhalten bleiben (Ausschneiden-Verhalten)")
    }

    func testTransforms() {
        var s = TiledSurface(width: 3, height: 2)
        s[0, 0] = .black                       // oben links
        XCTAssertEqual(s.flippedHorizontally()[2, 0], .black)
        XCTAssertEqual(s.flippedVertically()[0, 1], .black)
        let cw = s.rotated90Clockwise()
        XCTAssertEqual(cw.size, PixelSize(2, 3)); XCTAssertEqual(cw[1, 0], .black)
        let ccw = s.rotated90CounterClockwise()
        XCTAssertEqual(ccw[0, 2], .black)
        XCTAssertEqual(s.rotated180()[2, 1], .black)
        XCTAssertEqual(cw.rotated90Clockwise().rotated90Clockwise().rotated90Clockwise(), s)
    }

    func testCanvasResize() {
        let s = TiledSurface(size: PixelSize(2, 2), filledWith: .black)
        let r = s.resizedCanvas(to: PixelSize(4, 4), offset: PixelPoint(1, 1), fill: .white)
        XCTAssertEqual(r[0, 0], .white); XCTAssertEqual(r[1, 1], .black); XCTAssertEqual(r[2, 2], .black); XCTAssertEqual(r[3, 3], .white)
    }
}

final class UnitsAndZoomTests: XCTestCase {
    func testConversions() {
        XCTAssertEqual(UnitConversion.length(pixels: 96, dpi: 96, unit: .inches), 1, accuracy: 1e-9)
        XCTAssertEqual(UnitConversion.length(pixels: 96, dpi: 96, unit: .centimeters), 2.54, accuracy: 1e-9)
        XCTAssertEqual(UnitConversion.pixels(length: 2.54, dpi: 300, unit: .centimeters), 300)
        XCTAssertEqual(UnitConversion.dpi(fromResolution: 100, unit: .pixelsPerCentimeter), 254, accuracy: 1e-9)
    }

    func testNewImageAspectAndValidation() {
        var p = NewImageParameters(width: 800, height: 600, dpi: 96)
        p.setWidth(400); XCTAssertEqual(p.height, 300)
        p.keepAspectRatio = false; p.setHeight(1000); XCTAssertEqual(p.width, 400)
        XCTAssertNil(p.validate())
        p.width = 0; XCTAssertEqual(p.validate(), .notPositive)
        p.width = 70000; XCTAssertEqual(p.validate(), .tooLarge(max: 65535))
        XCTAssertEqual(NewImageParameters(width: 800, height: 600, dpi: 96).estimatedBytes, 1_920_000)
        XCTAssertEqual(formattedByteCount(1_920_000), "1,8 MB")
        XCTAssertEqual(formattedByteCount(512), "512 Byte")
    }

    func testZoomSteps() {
        XCTAssertEqual(ZoomLevels.zoomIn(from: 100), 150)
        XCTAssertEqual(ZoomLevels.zoomIn(from: 6400), 6400)
        XCTAssertEqual(ZoomLevels.zoomOut(from: 100), 67)
        XCTAssertEqual(ZoomLevels.zoomOut(from: 67), 50)
        XCTAssertEqual(ZoomLevels.zoomIn(from: 120), 150, "freier Wert springt zur nächsten Stufe")
        XCTAssertEqual(ZoomLevels.fit(image: PixelSize(4000, 3000), into: 1000, 1000), 25)
        XCTAssertEqual(ZoomLevels.fit(image: PixelSize(100, 100), into: 1000, 1000), 100, "kleine Bilder bleiben bei 100 %")
    }
}
