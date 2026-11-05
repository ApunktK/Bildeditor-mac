import Foundation
import EditorCore

/// Rasterisierung von Formen, Linien und Verläufen mit Überabtastung (Kantenglättung)
/// und Begrenzung durch die Auswahl. Ergebnis ist immer eine neue Fläche der aktiven Ebene.
public enum Raster {
    /// Trägt `color` mit der Deckung `coverage(x, y)` (0…1, Pixelmittelpunkt-Koordinaten) im Rechteck auf.
    public static func paint(_ surface: TiledSurface, rect: PixelRect, selection: SelectionMask?, blend: PaintBlend,
                             coverage: (Int, Int) -> Double, color: (Int, Int) -> ColorBgra) -> TiledSurface {
        var out = surface
        let r = rect.intersection(surface.bounds)
        guard !r.isEmpty else { return out }
        for y in r.minY..<r.maxY {
            for x in r.minX..<r.maxX {
                var c = coverage(x, y)
                if c <= 0 { continue }
                if let sel = selection { c *= Double(sel[x, y]) / 255; if c <= 0 { continue } }
                out[x, y] = blend.apply(surface[x, y], color(x, y), cov: Int((min(1, c) * 255).rounded()))
            }
        }
        return out
    }

    /// Anteil der Unterabtastpunkte (n × n) eines Pixels, die `inside` erfüllen.
    @inlinable
    public static func supersample(_ x: Int, _ y: Int, _ n: Int, _ inside: (Double, Double) -> Bool) -> Double {
        if n <= 1 { return inside(Double(x) + 0.5, Double(y) + 0.5) ? 1 : 0 }
        var k = 0
        let step = 1.0 / Double(n)
        for j in 0..<n {
            let py = Double(y) + (Double(j) + 0.5) * step
            for i in 0..<n where inside(Double(x) + (Double(i) + 0.5) * step, py) { k += 1 }
        }
        return Double(k) / Double(n * n)
    }

    /// Punkt in Polygon (gerade/ungerade).
    public static func pointInPolygon(_ px: Double, _ py: Double, _ poly: [(x: Double, y: Double)]) -> Bool {
        var inside = false
        var j = poly.count - 1
        for i in poly.indices {
            let a = poly[i], b = poly[j]
            if (a.y > py) != (b.y > py), px < (b.x - a.x) * (py - a.y) / (b.y - a.y) + a.x { inside.toggle() }
            j = i
        }
        return inside
    }

    /// Abstand eines Punkts zu einer Strecke.
    public static func distanceToSegment(_ px: Double, _ py: Double, _ a: (x: Double, y: Double), _ b: (x: Double, y: Double)) -> Double {
        let dx = b.x - a.x, dy = b.y - a.y
        let l2 = dx * dx + dy * dy
        var t = l2 > 0 ? ((px - a.x) * dx + (py - a.y) * dy) / l2 : 0
        t = max(0, min(1, t))
        let ex = a.x + t * dx - px, ey = a.y + t * dy - py
        return (ex * ex + ey * ey).squareRoot()
    }
}

// MARK: Formen

public enum ShapeKind: String, CaseIterable, Sendable {
    case rectangle, roundedRectangle, ellipse, triangle, diamond

    public var displayName: String {
        switch self {
        case .rectangle: return "Rechteck"
        case .roundedRectangle: return "Abgerundetes Rechteck"
        case .ellipse: return "Ellipse"
        case .triangle: return "Dreieck"
        case .diamond: return "Raute"
        }
    }
}

/// Zeichenart einer Form (Referenz: Kontur / gefüllt / gefüllt mit Kontur).
public enum ShapeStyle: String, CaseIterable, Sendable {
    case outline, fill, fillAndOutline

    public var displayName: String {
        switch self {
        case .outline: return "Kontur"
        case .fill: return "Gefüllt"
        case .fillAndOutline: return "Gefüllt mit Kontur"
        }
    }
}

public struct ShapeSpec: Equatable, Sendable {
    public var kind: ShapeKind
    /// Begrenzungsrechteck in Bildkoordinaten (Pixelkanten).
    public var x0: Double, y0: Double, x1: Double, y1: Double
    public var style: ShapeStyle
    public var lineWidth: Double
    public var antialias: Bool
    /// Eckenradius für abgerundete Rechtecke.
    public var radius: Double

    public init(kind: ShapeKind, x0: Double, y0: Double, x1: Double, y1: Double, style: ShapeStyle, lineWidth: Double, antialias: Bool, radius: Double = 20) {
        self.kind = kind; self.x0 = min(x0, x1); self.y0 = min(y0, y1); self.x1 = max(x0, x1); self.y1 = max(y0, y1)
        self.style = style; self.lineWidth = max(1, lineWidth); self.antialias = antialias; self.radius = max(0, radius)
    }

    /// Liegt (px, py) in der um `inset` verkleinerten (negativ: vergrößerten) Form?
    public func contains(_ px: Double, _ py: Double, inset: Double) -> Bool {
        let ax = x0 + inset, ay = y0 + inset, bx = x1 - inset, by = y1 - inset
        guard bx > ax, by > ay else { return false }
        switch kind {
        case .rectangle:
            return px >= ax && px <= bx && py >= ay && py <= by
        case .roundedRectangle:
            guard px >= ax && px <= bx && py >= ay && py <= by else { return false }
            let r = max(0, min(radius - inset, (bx - ax) / 2, (by - ay) / 2))
            let cx = min(max(px, ax + r), bx - r), cy = min(max(py, ay + r), by - r)
            let dx = px - cx, dy = py - cy
            return dx * dx + dy * dy <= r * r
        case .ellipse:
            let cx = (ax + bx) / 2, cy = (ay + by) / 2, rx = (bx - ax) / 2, ry = (by - ay) / 2
            let dx = (px - cx) / rx, dy = (py - cy) / ry
            return dx * dx + dy * dy <= 1
        case .triangle:
            return Raster.pointInPolygon(px, py, [((ax + bx) / 2, ay), (bx, by), (ax, by)])
        case .diamond:
            let cx = (ax + bx) / 2, cy = (ay + by) / 2
            return abs(px - cx) / ((bx - ax) / 2) + abs(py - cy) / ((by - ay) / 2) <= 1
        }
    }

    public var pixelBounds: PixelRect {
        let m = lineWidth / 2 + 2
        let ax = Int((x0 - m).rounded(.down)), ay = Int((y0 - m).rounded(.down))
        let bx = Int((x1 + m).rounded(.up)), by = Int((y1 + m).rounded(.up))
        return PixelRect(x: ax, y: ay, width: bx - ax, height: by - ay)
    }
}

// MARK: Linie

public enum DashStyle: String, CaseIterable, Sendable {
    case solid, dashed, dotted

    public var displayName: String {
        switch self { case .solid: return "Durchgezogen"; case .dashed: return "Gestrichelt"; case .dotted: return "Gepunktet" }
    }
}

public struct LineSpec: Equatable, Sendable {
    public var x0: Double, y0: Double, x1: Double, y1: Double
    public var width: Double
    public var antialias: Bool
    public var dash: DashStyle
    public var arrowStart: Bool, arrowEnd: Bool

    public init(x0: Double, y0: Double, x1: Double, y1: Double, width: Double, antialias: Bool, dash: DashStyle = .solid,
                arrowStart: Bool = false, arrowEnd: Bool = false) {
        self.x0 = x0; self.y0 = y0; self.x1 = x1; self.y1 = y1; self.width = max(1, width); self.antialias = antialias
        self.dash = dash; self.arrowStart = arrowStart; self.arrowEnd = arrowEnd
    }

    /// Endpunkt auf 15°-Schritte einrasten (⇧).
    public static func snapped(from a: (x: Double, y: Double), to b: (x: Double, y: Double)) -> (x: Double, y: Double) {
        let dx = b.x - a.x, dy = b.y - a.y
        let len = (dx * dx + dy * dy).squareRoot()
        let step = Double.pi / 12
        let ang = (atan2(dy, dx) / step).rounded() * step
        return (a.x + cos(ang) * len, a.y + sin(ang) * len)
    }

    var arrowLength: Double { max(8, width * 4) }

    /// Teilstrecken nach Strichart (Längen in Vielfachen der Breite).
    func segments() -> [((x: Double, y: Double), (x: Double, y: Double))] {
        let a = (x: x0, y: y0), b = (x: x1, y: y1)
        let dx = b.x - a.x, dy = b.y - a.y
        let len = (dx * dx + dy * dy).squareRoot()
        guard dash != .solid, len > 0 else { return [(a, b)] }
        let on = dash == .dashed ? width * 3 : 0.01, off = dash == .dashed ? width * 2 : width * 2
        var out: [((x: Double, y: Double), (x: Double, y: Double))] = []
        var t = 0.0
        while t < len {
            let e = min(len, t + on)
            out.append(((a.x + dx * t / len, a.y + dy * t / len), (a.x + dx * e / len, a.y + dy * e / len)))
            t = e + off
        }
        return out
    }

    /// Pfeilspitze als Dreieck am Punkt `tip` in Richtung von `from` nach `tip`.
    func arrow(from: (x: Double, y: Double), tip: (x: Double, y: Double)) -> [(x: Double, y: Double)] {
        let dx = tip.x - from.x, dy = tip.y - from.y
        let len = max(0.0001, (dx * dx + dy * dy).squareRoot())
        let ux = dx / len, uy = dy / len
        let l = arrowLength, w = l * 0.6
        let bx = tip.x - ux * l, by = tip.y - uy * l
        return [tip, (bx - uy * w, by + ux * w), (bx + uy * w, by - ux * w)]
    }

    func contains(_ px: Double, _ py: Double) -> Bool {
        let r = width / 2
        var a = (x: x0, y: y0), b = (x: x1, y: y1)
        // Strecke um die Pfeilspitzen kürzen, damit die Spitze spitz bleibt
        let dx = b.x - a.x, dy = b.y - a.y
        let len = (dx * dx + dy * dy).squareRoot()
        if len > 0 {
            if arrowEnd { b = (b.x - dx / len * arrowLength * 0.7, b.y - dy / len * arrowLength * 0.7) }
            if arrowStart { a = (a.x + dx / len * arrowLength * 0.7, a.y + dy / len * arrowLength * 0.7) }
        }
        let shortened = LineSpec(x0: a.x, y0: a.y, x1: b.x, y1: b.y, width: width, antialias: antialias, dash: dash)
        for (s, e) in shortened.segments() where Raster.distanceToSegment(px, py, s, e) <= r { return true }
        if arrowEnd, Raster.pointInPolygon(px, py, arrow(from: (x0, y0), tip: (x1, y1))) { return true }
        if arrowStart, Raster.pointInPolygon(px, py, arrow(from: (x1, y1), tip: (x0, y0))) { return true }
        return false
    }

    public var pixelBounds: PixelRect {
        let m = max(width / 2, (arrowStart || arrowEnd) ? arrowLength : 0) + 2
        let ax = Int((min(x0, x1) - m).rounded(.down)), ay = Int((min(y0, y1) - m).rounded(.down))
        let bx = Int((max(x0, x1) + m).rounded(.up)), by = Int((max(y0, y1) + m).rounded(.up))
        return PixelRect(x: ax, y: ay, width: bx - ax, height: by - ay)
    }
}

// MARK: Verlauf

public enum GradientKind: String, CaseIterable, Sendable {
    case linear, reflected, diamond, radial, conical, spiralClockwise, spiralCounterClockwise

    public var displayName: String {
        switch self {
        case .linear: return "Linear"
        case .reflected: return "Linear (gespiegelt)"
        case .diamond: return "Raute"
        case .radial: return "Radial"
        case .conical: return "Konisch"
        case .spiralClockwise: return "Spirale (im Uhrzeigersinn)"
        case .spiralCounterClockwise: return "Spirale (gegen den Uhrzeigersinn)"
        }
    }
}

/// Wiederholung jenseits des Endpunkts (Referenz: „Repeat Modes“).
public enum GradientRepeat: String, CaseIterable, Sendable {
    case none, sawtooth, reflect

    public var displayName: String {
        switch self { case .none: return "Keine Wiederholung"; case .sawtooth: return "Wiederholen"; case .reflect: return "Gespiegelt wiederholen" }
    }
}

public struct GradientSpec: Equatable, Sendable {
    public var kind: GradientKind
    public var x0: Double, y0: Double, x1: Double, y1: Double
    /// Transparenzmodus: verändert nur die Deckkraft der Ebene (Referenz).
    public var transparencyMode: Bool
    public var start: ColorBgra, end: ColorBgra
    public var repeatMode: GradientRepeat

    public init(kind: GradientKind, x0: Double, y0: Double, x1: Double, y1: Double, start: ColorBgra, end: ColorBgra,
                transparencyMode: Bool = false, repeatMode: GradientRepeat = .none) {
        self.kind = kind; self.x0 = x0; self.y0 = y0; self.x1 = x1; self.y1 = y1
        self.start = start; self.end = end; self.transparencyMode = transparencyMode; self.repeatMode = repeatMode
    }

    /// Position 0…1 im Verlauf für den Punkt (px, py).
    public func t(_ px: Double, _ py: Double) -> Double {
        let dx = x1 - x0, dy = y1 - y0
        let l2 = dx * dx + dy * dy
        guard l2 > 0 else { return 0 }
        let rx = px - x0, ry = py - y0
        let along = (rx * dx + ry * dy) / l2
        let raw: Double
        switch kind {
        case .linear: raw = along
        case .reflected: raw = abs(along)
        case .diamond: raw = abs(along) + abs((rx * -dy + ry * dx) / l2)
        case .radial: raw = (rx * rx + ry * ry).squareRoot() / l2.squareRoot()
        case .conical:
            var a = atan2(ry, rx) - atan2(dy, dx)
            while a > .pi { a -= 2 * .pi }
            while a < -.pi { a += 2 * .pi }
            return abs(a) / .pi
        case .spiralClockwise, .spiralCounterClockwise:
            var a = (atan2(ry, rx) - atan2(dy, dx)) / (2 * .pi)
            if kind == .spiralCounterClockwise { a = -a }
            let r = (rx * rx + ry * ry).squareRoot() / l2.squareRoot()
            let v = (r + a).truncatingRemainder(dividingBy: 1)
            return v < 0 ? v + 1 : v
        }
        switch repeatMode {
        case .none: return max(0, min(1, raw))
        case .sawtooth:
            let f = raw.truncatingRemainder(dividingBy: 1)
            return f < 0 ? f + 1 : f
        case .reflect:
            var f = raw.truncatingRemainder(dividingBy: 2)
            if f < 0 { f += 2 }
            return f <= 1 ? f : 2 - f
        }
    }

    /// Deckkraftfaktor im Transparenzmodus: von Alpha der Primärfarbe zum Kehrwert des Alphas der Sekundärfarbe.
    public func alphaFactor(_ t: Double) -> Double {
        let f0 = Double(start.a) / 255, f1 = 1 - Double(end.a) / 255
        return f0 + (f1 - f0) * t
    }

    public static func lerp(_ a: ColorBgra, _ b: ColorBgra, _ t: Double) -> ColorBgra {
        func m(_ x: UInt8, _ y: UInt8) -> UInt8 { UInt8((Double(x) + (Double(y) - Double(x)) * t).rounded()) }
        return ColorBgra(r: m(a.r, b.r), g: m(a.g, b.g), b: m(a.b, b.b), a: m(a.a, b.a))
    }
}

// MARK: Dokument

extension Document {
    /// Zustand mit einer Form auf der aktiven Ebene (für Vorschau und Übernahme).
    /// Kontur in `outline`, Füllung in `fill` (Referenz: Kontur = Primärfarbe, Füllung bei „gefüllt mit Kontur“ = Sekundärfarbe).
    public func stateWithShape(_ spec: ShapeSpec, outline: ColorBgra, fill: ColorBgra, blend: PaintBlend, base: DocumentState? = nil) -> DocumentState {
        var s = base ?? committedState
        let li = s.activeLayerIndex
        let n = spec.antialias ? 3 : 1
        let sel = s.selection.flatMap { $0.isEmpty ? nil : $0 }
        let b = spec.pixelBounds
        var surf = s.layers[li].surface
        let w = spec.lineWidth
        switch spec.style {
        case .fill:
            surf = Raster.paint(surf, rect: b, selection: sel, blend: blend,
                                coverage: { x, y in Raster.supersample(x, y, n) { spec.contains($0, $1, inset: 0) } }, color: { _, _ in outline })
        case .outline:
            surf = Raster.paint(surf, rect: b, selection: sel, blend: blend, coverage: { x, y in
                Raster.supersample(x, y, n) { spec.contains($0, $1, inset: -w / 2) && !spec.contains($0, $1, inset: w / 2) }
            }, color: { _, _ in outline })
        case .fillAndOutline:
            surf = Raster.paint(surf, rect: b, selection: sel, blend: blend,
                                coverage: { x, y in Raster.supersample(x, y, n) { spec.contains($0, $1, inset: w / 2) } }, color: { _, _ in fill })
            surf = Raster.paint(surf, rect: b, selection: sel, blend: blend, coverage: { x, y in
                Raster.supersample(x, y, n) { spec.contains($0, $1, inset: -w / 2) && !spec.contains($0, $1, inset: w / 2) }
            }, color: { _, _ in outline })
        }
        s.layers[li].surface = surf
        return s
    }

    public func stateWithLine(_ spec: LineSpec, color: ColorBgra, blend: PaintBlend, base: DocumentState? = nil) -> DocumentState {
        var s = base ?? committedState
        let li = s.activeLayerIndex
        let n = spec.antialias ? 3 : 1
        let sel = s.selection.flatMap { $0.isEmpty ? nil : $0 }
        s.layers[li].surface = Raster.paint(s.layers[li].surface, rect: spec.pixelBounds, selection: sel, blend: blend,
                                            coverage: { x, y in Raster.supersample(x, y, n) { spec.contains($0, $1) } },
                                            color: { _, _ in color })
        return s
    }

    /// Verlauf auf die aktive Ebene (innerhalb der Auswahl, sonst ganze Ebene).
    public func stateWithGradient(_ spec: GradientSpec, blend: PaintBlend, base: DocumentState? = nil) -> DocumentState {
        var s = base ?? committedState
        let li = s.activeLayerIndex
        let sel = s.selection.flatMap { $0.isEmpty ? nil : $0 }
        let rect = sel?.bounds ?? PixelRect(size: s.size)
        let src = s.layers[li].surface
        if spec.transparencyMode {
            var out = src
            for y in rect.minY..<rect.maxY {
                for x in rect.minX..<rect.maxX {
                    let m = sel.map { Double($0[x, y]) / 255 } ?? 1
                    if m <= 0 { continue }
                    var c = src[x, y]
                    let f = spec.alphaFactor(spec.t(Double(x) + 0.5, Double(y) + 0.5))
                    let target = Double(c.a) * f
                    c.a = UInt8((Double(c.a) + (target - Double(c.a)) * m).rounded())
                    out[x, y] = c.a == 0 ? .transparent : c
                }
            }
            s.layers[li].surface = out
        } else {
            s.layers[li].surface = Raster.paint(src, rect: rect, selection: sel, blend: blend, coverage: { _, _ in 1 },
                                                color: { x, y in GradientSpec.lerp(spec.start, spec.end, spec.t(Double(x) + 0.5, Double(y) + 0.5)) })
        }
        return s
    }
}

extension Document {
    /// Fertig gerastertes Bild (z. B. Text) an `origin` auf die aktive Ebene mischen, begrenzt durch die Auswahl.
    public func stateWithImage(_ img: TiledSurface, at origin: PixelPoint, blend: PaintBlend, base: DocumentState? = nil) -> DocumentState {
        var s = base ?? committedState
        let li = s.activeLayerIndex
        let sel = s.selection.flatMap { $0.isEmpty ? nil : $0 }
        let rect = PixelRect(x: origin.x, y: origin.y, width: img.width, height: img.height)
        s.layers[li].surface = Raster.paint(s.layers[li].surface, rect: rect, selection: sel, blend: blend,
                                            coverage: { x, y in img[x - origin.x, y - origin.y].a == 0 ? 0 : 1 },
                                            color: { x, y in img[x - origin.x, y - origin.y] })
        return s
    }
}
