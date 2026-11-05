import EditorCore

/// Wie Farbe aufgetragen wird: über einen Mischmodus oder „Überschreiben“ (Alpha-Mischung aus).
public enum PaintBlend: Equatable, Sendable {
    case blend(BlendMode)
    case overwrite

    public static let normal = PaintBlend.blend(.normal)

    /// Farbe `c` mit Deckung `cov` (0…255) auf `b` auftragen.
    @inlinable public func apply(_ b: ColorBgra, _ c: ColorBgra, cov: Int) -> ColorBgra {
        if cov <= 0 { return b }
        switch self {
        case let .blend(m):
            return m.blend(bottom: b, top: c, opacity: cov)
        case .overwrite:
            if cov >= 255 { return c }
            func mix(_ x: UInt8, _ y: UInt8) -> UInt8 { UInt8((Int(x) * (255 - cov) + Int(y) * cov + 127) / 255) }
            return ColorBgra(r: mix(b.r, c.r), g: mix(b.g, c.g), b: mix(b.b, c.b), a: mix(b.a, c.a))
        }
    }
}

/// Ein laufender Pinselstrich (Pinsel, Stift, Radiergummi). Die Deckung je Pixel wird als Maximum gespeichert,
/// damit sich überlappende Stempel innerhalb eines Strichs nicht aufsummieren; jedes Pixel wird aus dem
/// Ausgangszustand neu berechnet. Nach jedem Abschnitt liegt das Ergebnis in `working`.
public final class StrokeSession {
    public enum Kind: Equatable, Sendable {
        case brush(ColorBgra)
        case pencil(ColorBgra)
        case eraser
    }

    public let base: DocumentState
    public let layerIndex: Int
    public let kind: Kind
    public let width: Double
    public let antialias: Bool
    public let blend: PaintBlend
    public private(set) var working: TiledSurface
    /// Seit Beginn veränderter Bereich.
    public private(set) var dirty: PixelRect = .empty
    private var coverage: SelectionMask
    private let selection: SelectionMask?
    private var last: (x: Double, y: Double)?

    public init(base: DocumentState, kind: Kind, width: Double, antialias: Bool, blend: PaintBlend) {
        self.base = base
        layerIndex = base.activeLayerIndex
        self.kind = kind
        self.width = max(1, width)
        self.antialias = antialias
        self.blend = blend
        working = base.layers[base.activeLayerIndex].surface
        coverage = SelectionMask(size: base.size)
        selection = base.selection.flatMap { $0.isEmpty ? nil : $0 }
    }

    public var lastPoint: (x: Double, y: Double)? { last }

    public var resultState: DocumentState {
        var s = base
        s.layers[layerIndex].surface = working
        return s
    }

    public var historyName: String {
        switch kind { case .brush: return "Pinsel"; case .pencil: return "Stift"; case .eraser: return "Radiergummi" }
    }

    /// Nächsten Punkt (Bildkoordinaten) anfügen; liefert den neu veränderten Bereich.
    @discardableResult
    public func add(x: Double, y: Double) -> PixelRect {
        let from = last ?? (x, y)
        last = (x, y)
        if case .pencil = kind { return pencilLine(from, (x, y)) }
        return capsule(from, (x, y))
    }

    private func setCoverage(_ px: Int, _ py: Int, _ cov: Int) -> Bool {
        var c = cov
        if let sel = selection { c = c * Int(sel[px, py]) / 255 }
        if c <= Int(coverage[px, py]) { return false }
        coverage[px, py] = UInt8(c)
        let b = base.layers[layerIndex].surface[px, py]
        switch kind {
        case let .brush(col), let .pencil(col):
            working[px, py] = blend.apply(b, col, cov: c)
        case .eraser:
            let a = Int(b.a) * (255 - c) / 255
            working[px, py] = a == 0 ? .transparent : ColorBgra(r: b.r, g: b.g, b: b.b, a: UInt8(a))
        }
        return true
    }

    /// Strecke mit runden Enden (Pinselbreite), Pixelmittelpunkte; Kantenglättung über den Abstand zur Kante.
    private func capsule(_ a: (x: Double, y: Double), _ b: (x: Double, y: Double)) -> PixelRect {
        let r = width / 2
        let minX = max(0, Int((min(a.x, b.x) - r - 1).rounded(.down))), maxX = min(base.size.width, Int((max(a.x, b.x) + r + 1).rounded(.up)))
        let minY = max(0, Int((min(a.y, b.y) - r - 1).rounded(.down))), maxY = min(base.size.height, Int((max(a.y, b.y) + r + 1).rounded(.up)))
        guard minX < maxX, minY < maxY else { return .empty }
        let dx = b.x - a.x, dy = b.y - a.y
        let len2 = dx * dx + dy * dy
        var changed = PixelRect.empty
        for py in minY..<maxY {
            let cy = Double(py) + 0.5
            for px in minX..<maxX {
                let cx = Double(px) + 0.5
                var t = len2 > 0 ? ((cx - a.x) * dx + (cy - a.y) * dy) / len2 : 0
                t = max(0, min(1, t))
                let ex = a.x + t * dx - cx, ey = a.y + t * dy - cy
                let d = (ex * ex + ey * ey).squareRoot()
                let cov: Int
                if antialias {
                    let f = r - d + 0.5
                    if f <= 0 { continue }
                    cov = f >= 1 ? 255 : Int((f * 255).rounded())
                } else {
                    if d > r { continue }
                    cov = 255
                }
                if setCoverage(px, py, cov) {
                    let p = PixelRect(x: px, y: py, width: 1, height: 1)
                    changed = changed.isEmpty ? p : changed.union(p)
                }
            }
        }
        if !changed.isEmpty { dirty = dirty.isEmpty ? changed : dirty.union(changed) }
        return changed
    }

    /// Stift: 1 Pixel, ohne Kantenglättung (Bresenham).
    private func pencilLine(_ a: (x: Double, y: Double), _ b: (x: Double, y: Double)) -> PixelRect {
        var x0 = Int(a.x.rounded(.down)), y0 = Int(a.y.rounded(.down))
        let x1 = Int(b.x.rounded(.down)), y1 = Int(b.y.rounded(.down))
        let dx = abs(x1 - x0), sx = x0 < x1 ? 1 : -1, dy = -abs(y1 - y0), sy = y0 < y1 ? 1 : -1
        var err = dx + dy
        var changed = PixelRect.empty
        let bounds = PixelRect(size: base.size)
        while true {
            if bounds.contains(PixelPoint(x0, y0)), setCoverage(x0, y0, 255) {
                let p = PixelRect(x: x0, y: y0, width: 1, height: 1)
                changed = changed.isEmpty ? p : changed.union(p)
            }
            if x0 == x1 && y0 == y1 { break }
            let e2 = 2 * err
            if e2 >= dy { err += dy; x0 += sx }
            if e2 <= dx { err += dx; y0 += sy }
        }
        if !changed.isEmpty { dirty = dirty.isEmpty ? changed : dirty.union(changed) }
        return changed
    }
}

extension Document {
    /// Laufender Strich als Vorschau anzeigen.
    public func previewStroke(_ s: StrokeSession) { preview(s.resultState) }

    /// Strich abschließen: ein Verlaufsschritt (nur wenn sich etwas geändert hat).
    public func commitStroke(_ s: StrokeSession) {
        if isPreviewing { endPreview(commitAs: nil) }
        guard !s.dirty.isEmpty, s.resultState != committedState else { return }
        commit(s.resultState, name: s.historyName, kind: .paint)
    }

    /// Farbeimer: ähnliche Farben (zusammenhängend oder global) mit der Farbe füllen, innerhalb der Auswahl.
    @discardableResult
    public func floodFill(at p: PixelPoint, color: ColorBgra, tolerance: Double, global: Bool, sampleImage: Bool, blend: PaintBlend) -> Bool {
        settlePreview()
        guard PixelRect(size: state.size).contains(p) else { return false }
        if let sel = state.selection, !sel.isEmpty, sel[p.x, p.y] == 0 { return false }
        let source = sampleImage ? flattenedSurface() : activeLayer.surface
        var region = SelectionMask.magicWand(on: source, at: p, tolerance: tolerance, global: global)
        if let sel = state.selection, !sel.isEmpty { region = region.combined(with: sel, mode: .intersect) }
        let b = region.bounds
        guard !b.isEmpty else { return false }
        var s = state
        var surf = s.layers[s.activeLayerIndex].surface
        for y in b.minY..<b.maxY {
            for x in b.minX..<b.maxX {
                let m = Int(region[x, y])
                if m != 0 { surf[x, y] = blend.apply(surf[x, y], color, cov: m) }
            }
        }
        s.layers[s.activeLayerIndex].surface = surf
        commit(s, name: "Farbeimer", kind: .fill)
        return true
    }

    /// Farbpipette: Mittelwert eines quadratischen Bereichs (Seitenlänge `size`, ungerade) – aus Ebene oder Bild.
    /// Farbkanäle werden nach Deckkraft gewichtet, damit transparente Pixel die Farbe nicht verfälschen.
    public func sampleColor(at p: PixelPoint, size: Int, sampleImage: Bool) -> ColorBgra? {
        guard PixelRect(size: state.size).contains(p) else { return nil }
        let half = max(0, size / 2)
        let area = PixelRect(x: p.x - half, y: p.y - half, width: half * 2 + 1, height: half * 2 + 1).intersection(PixelRect(size: state.size))
        let source = sampleImage ? Compositor.flatten(state.layers, size: state.size, rect: area) : activeLayer.surface
        if area.width == 1 && area.height == 1 { return source[p.x, p.y] }
        var sr = 0, sg = 0, sb = 0, sa = 0, n = 0
        for y in area.minY..<area.maxY {
            for x in area.minX..<area.maxX {
                let c = source[x, y]
                sr += Int(c.r) * Int(c.a); sg += Int(c.g) * Int(c.a); sb += Int(c.b) * Int(c.a); sa += Int(c.a); n += 1
            }
        }
        guard n > 0 else { return nil }
        if sa == 0 { return .transparent }
        return ColorBgra(r: UInt8((sr + sa / 2) / sa), g: UInt8((sg + sa / 2) / sa), b: UInt8((sb + sa / 2) / sa), a: UInt8((sa + n / 2) / n))
    }
}
