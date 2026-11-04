import AppKit
import EditorCore
import EditorDocument

/// Umwandlung zwischen Kernflächen und CGImage/NSImage für Anzeige, Vorschaubilder und Zwischenablage.
enum ImageRendering {
    static let sRGB = CGColorSpace(name: CGColorSpace.sRGB)!

    /// BGRA vormultipliziert, little-endian → CGImage (Anzeige).
    static func cgImage(premultipliedBGRA bytes: [UInt8], width: Int, height: Int) -> CGImage? {
        guard width > 0, height > 0, bytes.count >= width * height * 4 else { return nil }
        let info = CGBitmapInfo(rawValue: CGImageAlphaInfo.premultipliedFirst.rawValue | CGBitmapInfo.byteOrder32Little.rawValue)
        guard let provider = CGDataProvider(data: Data(bytes) as CFData) else { return nil }
        return CGImage(width: width, height: height, bitsPerComponent: 8, bitsPerPixel: 32, bytesPerRow: width * 4,
                       space: sRGB, bitmapInfo: info, provider: provider, decode: nil, shouldInterpolate: false,
                       intent: .defaultIntent)
    }

    /// BGRA mit geradem Alpha → CGImage ohne Vormultiplikation (verlustfreier Export, z. B. PNG).
    static func cgImage(straightBGRA bytes: [UInt8], width: Int, height: Int) -> CGImage? {
        guard width > 0, height > 0, bytes.count >= width * height * 4 else { return nil }
        let info = CGBitmapInfo(rawValue: CGImageAlphaInfo.first.rawValue | CGBitmapInfo.byteOrder32Little.rawValue)
        guard let provider = CGDataProvider(data: Data(bytes) as CFData) else { return nil }
        return CGImage(width: width, height: height, bitsPerComponent: 8, bitsPerPixel: 32, bytesPerRow: width * 4,
                       space: sRGB, bitmapInfo: info, provider: provider, decode: nil, shouldInterpolate: false,
                       intent: .defaultIntent)
    }

    /// Fläche mit geradem Alpha als CGImage.
    static func cgImage(surface: TiledSurface) -> CGImage? {
        cgImage(straightBGRA: surface.bgraBytes(), width: surface.width, height: surface.height)
    }

    /// Komposit aller sichtbaren Ebenen für die Zeichenfläche.
    static func composite(_ state: DocumentState) -> CGImage? {
        let bytes = Compositor.premultipliedBGRA(state.layers, size: state.size)
        return cgImage(premultipliedBGRA: bytes, width: state.size.width, height: state.size.height)
    }

    /// Größe eines Vorschaubilds, das in `maxSide` passt (Seitenverhältnis bleibt).
    static func thumbnailSize(for size: PixelSize, maxSide: Int) -> PixelSize {
        guard !size.isEmpty else { return PixelSize(1, 1) }
        let s = min(1.0, Double(maxSide) / Double(max(size.width, size.height)))
        return PixelSize(max(1, Int((Double(size.width) * s).rounded())), max(1, Int((Double(size.height) * s).rounded())))
    }

    /// Vorschaubild durch Stichproben (schnell, auch bei großen Bildern). `pixel` liefert die Farbe an (x, y).
    static func sampledThumbnail(size: PixelSize, maxSide: Int, pixel: (Int, Int) -> ColorBgra) -> NSImage {
        let t = thumbnailSize(for: size, maxSide: maxSide)
        var bytes = [UInt8](repeating: 0, count: t.width * t.height * 4)
        for ty in 0..<t.height {
            let y = min(size.height - 1, Int((Double(ty) + 0.5) * Double(size.height) / Double(t.height)))
            for tx in 0..<t.width {
                let x = min(size.width - 1, Int((Double(tx) + 0.5) * Double(size.width) / Double(t.width)))
                let c = pixel(x, y)
                let o = (ty * t.width + tx) * 4
                bytes[o] = c.b; bytes[o + 1] = c.g; bytes[o + 2] = c.r; bytes[o + 3] = c.a
            }
        }
        Compositor.premultiplyInPlace(&bytes)
        guard let cg = cgImage(premultipliedBGRA: bytes, width: t.width, height: t.height) else { return NSImage() }
        return NSImage(cgImage: cg, size: NSSize(width: t.width, height: t.height))
    }

    static func thumbnail(of state: DocumentState, maxSide: Int) -> NSImage {
        let visible = state.layers.filter { $0.isVisible && $0.opacity > 0 }
        return sampledThumbnail(size: state.size, maxSide: maxSide) { x, y in
            var c = ColorBgra.transparent
            for l in visible {
                let s = l.surface[x, y]
                if s.a == 0 { continue }
                c = l.blendMode.blend(bottom: c, top: s, opacity: Int(l.opacity))
            }
            return c
        }
    }

    static func thumbnail(of layer: Layer, maxSide: Int) -> NSImage {
        sampledThumbnail(size: layer.surface.size, maxSide: maxSide) { x, y in layer.surface[x, y] }
    }

    // MARK: Schachbrett (Transparenzanzeige)

    static let checkerboardColor: NSColor = {
        let size = 16
        let img = NSImage(size: NSSize(width: size, height: size), flipped: false) { r in
            NSColor.white.setFill(); r.fill()
            NSColor(white: 0.80, alpha: 1).setFill()
            NSRect(x: 0, y: 0, width: 8, height: 8).fill()
            NSRect(x: 8, y: 8, width: 8, height: 8).fill()
            return true
        }
        return NSColor(patternImage: img)
    }()

    /// Zeichnet ein Bild mit Schachbrett darunter in ein Rechteck (für Vorschaubilder).
    static func drawWithCheckerboard(_ image: NSImage, in rect: NSRect) {
        NSGraphicsContext.saveGraphicsState()
        checkerboardColor.setFill()
        rect.fill()
        image.draw(in: rect, from: .zero, operation: .sourceOver, fraction: 1)
        NSColor.separatorColor.setStroke()
        NSBezierPath(rect: rect.insetBy(dx: 0.5, dy: 0.5)).stroke()
        NSGraphicsContext.restoreGraphicsState()
    }
}

extension ColorBgra {
    var nsColor: NSColor {
        NSColor(srgbRed: CGFloat(r) / 255, green: CGFloat(g) / 255, blue: CGFloat(b) / 255, alpha: CGFloat(a) / 255)
    }

    init(nsColor: NSColor) {
        let c = nsColor.usingColorSpace(.sRGB) ?? NSColor.black
        func q(_ v: CGFloat) -> UInt8 { UInt8(max(0, min(255, (v * 255).rounded()))) }
        self.init(r: q(c.redComponent), g: q(c.greenComponent), b: q(c.blueComponent), a: q(c.alphaComponent))
    }
}
