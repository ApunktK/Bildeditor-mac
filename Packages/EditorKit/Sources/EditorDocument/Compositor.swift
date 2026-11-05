import EditorCore

/// Setzt alle sichtbaren Ebenen von unten nach oben mit ihrem Mischmodus und ihrer Deckkraft zusammen.
/// CPU-Referenzpfad: Grundlage für Export, „Zusammengefügt kopieren“, Reduzieren und für die Tests der GPU-Komposition.
public enum Compositor {
    /// Komposit eines Bereichs als neue Fläche (gerades Alpha, transparenter Grund).
    public static func flatten(_ layers: [Layer], size: PixelSize, rect: PixelRect? = nil) -> TiledSurface {
        let area = (rect ?? PixelRect(size: size)).intersection(PixelRect(size: size))
        var out = TiledSurface(size: size)
        let visible = layers.filter { $0.isVisible && $0.opacity > 0 }
        if area.isEmpty || visible.isEmpty { return out }
        // Kachelweise, damit leere Kacheln übersprungen werden.
        for (tx, ty) in out.tiles(touching: area) {
            let tr = out.tileRect(tx: tx, ty: ty).intersection(area)
            if visible.allSatisfy({ $0.surface.tileIsEmpty(tx: tx, ty: ty) }) { continue }
            for y in tr.minY..<tr.maxY {
                for x in tr.minX..<tr.maxX {
                    var c = ColorBgra.transparent
                    for l in visible {
                        let s = l.surface[x, y]
                        if s.a == 0 { continue }
                        c = l.blendMode.blend(bottom: c, top: s, opacity: Int(l.opacity))
                    }
                    if c.packed != 0 { out[x, y] = c }
                }
            }
        }
        return out
    }

    /// Komposit als Bytes für die Anzeige: BGRA **vormultipliziert** (für CGImage/Metal), Zeilen ohne Auffüllung.
    public static func premultipliedBGRA(_ layers: [Layer], size: PixelSize, rect: PixelRect? = nil) -> [UInt8] {
        let r = (rect ?? PixelRect(size: size)).intersection(PixelRect(size: size))
        var bytes = flatten(layers, size: size, rect: r).bgraBytes(in: r)
        premultiplyInPlace(&bytes)
        return bytes
    }

    public static func premultiplyInPlace(_ bytes: inout [UInt8]) {
        bytes.withUnsafeMutableBufferPointer { p in
            var i = 0
            while i < p.count {
                let a = Int(p[i + 3])
                if a == 0 { p[i] = 0; p[i + 1] = 0; p[i + 2] = 0 }
                else if a != 255 {
                    p[i] = UInt8((Int(p[i]) * a + 127) / 255)
                    p[i + 1] = UInt8((Int(p[i + 1]) * a + 127) / 255)
                    p[i + 2] = UInt8((Int(p[i + 2]) * a + 127) / 255)
                }
                i += 4
            }
        }
    }
}

extension Compositor {
    /// Bereich, in dem sich zwei Ebenenlisten unterscheiden. nil = Ebenen/Eigenschaften anders → alles neu.
    public static func changedRect(old: [Layer], new: [Layer], size: PixelSize) -> PixelRect? {
        guard old.count == new.count else { return nil }
        var r = PixelRect.empty
        for (a, b) in zip(old, new) {
            guard a.id == b.id, a.properties == b.properties, a.surface.size == b.surface.size, a.surface.size == size else { return nil }
            for (tx, ty) in b.surface.changedTiles(comparedTo: a.surface) {
                let t = b.surface.tileRect(tx: tx, ty: ty)
                r = r.isEmpty ? t : r.union(t)
            }
        }
        return r
    }

    /// Aktualisiert einen Ausschnitt in einem vormultiplizierten Gesamtpuffer (Breite × Höhe × 4).
    public static func updatePremultiplied(_ bytes: inout [UInt8], layers: [Layer], size: PixelSize, rect: PixelRect) {
        let r = rect.intersection(PixelRect(size: size))
        guard !r.isEmpty, bytes.count == size.width * size.height * 4 else { return }
        let part = premultipliedBGRA(layers, size: size, rect: r)
        let rowBytes = r.width * 4
        part.withUnsafeBufferPointer { src in
            bytes.withUnsafeMutableBufferPointer { dst in
                for y in 0..<r.height {
                    let d = ((r.minY + y) * size.width + r.minX) * 4
                    for i in 0..<rowBytes { dst[d + i] = src[y * rowBytes + i] }
                }
            }
        }
    }
}
