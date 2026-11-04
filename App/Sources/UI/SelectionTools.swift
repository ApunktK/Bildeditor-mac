import AppKit
import EditorCore
import EditorDocument

/// Kontur (Ameisenlinie) und Tönung einer Auswahlmaske.
enum SelectionRendering {
    static func graphics(for mask: SelectionMask) -> DocumentSession.SelectionGraphics? {
        let b = mask.bounds
        guard !b.isEmpty else { return nil }
        let path = CGMutablePath()
        for s in mask.outlineSegments() {
            path.move(to: CGPoint(x: s.x0, y: s.y0))
            path.addLine(to: CGPoint(x: s.x1, y: s.y1))
        }
        // Graustufenmaske des Begrenzungsrechtecks (weiß = ausgewählt) für die Tönung
        var bytes = [UInt8](repeating: 0, count: b.width * b.height)
        for y in 0..<b.height {
            let row = y * b.width
            for x in 0..<b.width { bytes[row + x] = mask[b.minX + x, b.minY + y] }
        }
        var tint: CGImage?
        if let provider = CGDataProvider(data: Data(bytes) as CFData) {
            tint = CGImage(maskWidth: b.width, height: b.height, bitsPerComponent: 8, bitsPerPixel: 8, bytesPerRow: b.width,
                           provider: provider, decode: [1, 0], shouldInterpolate: false)
        }
        return .init(path: path, tint: tint, bounds: b)
    }

    /// Ameisenlinie zeichnen: Pfad in Bildkoordinaten, Versatz in Bildpixeln.
    static func drawOutline(_ g: DocumentSession.SelectionGraphics, offset: CGPoint, in ctx: CGContext,
                            origin: NSPoint, scale: CGFloat, phase: CGFloat) {
        ctx.saveGState()
        ctx.translateBy(x: origin.x + offset.x * scale, y: origin.y + offset.y * scale)
        ctx.scaleBy(x: scale, y: scale)
        let w = 1 / scale
        ctx.setLineWidth(w)
        ctx.addPath(g.path)
        ctx.setStrokeColor(NSColor.white.cgColor)
        ctx.strokePath()
        ctx.addPath(g.path)
        ctx.setLineDash(phase: phase * w, lengths: [4 * w, 4 * w])
        ctx.setStrokeColor(NSColor.black.cgColor)
        ctx.strokePath()
        ctx.restoreGState()
    }

    /// Blaue Tönung der ausgewählten Fläche (nur bei aktivem Auswahlwerkzeug, Referenz T-15).
    static func drawTint(_ g: DocumentSession.SelectionGraphics, offset: CGPoint, in ctx: CGContext, origin: NSPoint, scale: CGFloat) {
        guard let mask = g.tint else { return }
        let r = CGRect(x: origin.x + (CGFloat(g.bounds.minX) + offset.x) * scale, y: origin.y + (CGFloat(g.bounds.minY) + offset.y) * scale,
                       width: CGFloat(g.bounds.width) * scale, height: CGFloat(g.bounds.height) * scale)
        ctx.saveGState()
        // Ansicht ist gespiegelt (y nach unten): Maske passend drehen.
        ctx.translateBy(x: 0, y: r.maxY + r.minY)
        ctx.scaleBy(x: 1, y: -1)
        ctx.clip(to: r, mask: mask)
        ctx.setFillColor(NSColor.systemBlue.withAlphaComponent(0.16).cgColor)
        ctx.fill(r)
        ctx.restoreGState()
    }
}

/// Bedienung der Auswahl- und Verschiebewerkzeuge auf der Zeichenfläche.
/// Die Methoden arbeiten mit Bildkoordinaten, damit der Selbsttest sie ohne echte Mausereignisse aufrufen kann.
final class SelectionInteraction {
    enum DragShape {
        case rect(CGRect), ellipse(CGRect), lasso([CGPoint])
    }

    struct Modifiers {
        var shift = false, command = false, option = false, right = false
        init(shift: Bool = false, command: Bool = false, option: Bool = false, right: Bool = false) {
            self.shift = shift; self.command = command; self.option = option; self.right = right
        }
        init(_ e: NSEvent, right: Bool) {
            let f = e.modifierFlags
            shift = f.contains(.shift); command = f.contains(.command); option = f.contains(.option); self.right = right
        }
    }

    /// Vorschauform während des Aufziehens (Bildkoordinaten).
    private(set) var dragShape: DragShape?
    /// Versatz der Kontur beim Werkzeug „Auswahl verschieben“ (Bildpixel).
    private(set) var selectionOffset: CGPoint?
    var onChange: (() -> Void)?

    private var tool: Tool = .rectangleSelect
    private var start = CGPoint.zero
    private var points: [CGPoint] = []
    private var mods = Modifiers()
    private var floatStartOrigin = PixelPoint.zero
    private var active = false

    private var ctrl: AppController { .shared }
    private var doc: Document? { ctrl.document }

    /// Modus aus Werkzeugleiste und Zusatztasten (Referenz: Strg/Alt mit linker bzw. rechter Taste).
    static func mode(base: SelectionMode, _ m: Modifiers) -> SelectionMode {
        if m.command { return m.right ? .xor : .union }
        if m.option { return m.right ? .intersect : .exclude }
        return base
    }

    /// Rechteck aus Start und aktuellem Punkt, auf Pixelkanten gerundet; ⇧ = Quadrat.
    static func snappedRect(from a: CGPoint, to b: CGPoint, square: Bool) -> CGRect {
        var dx = b.x - a.x, dy = b.y - a.y
        if square {
            let s = max(abs(dx), abs(dy))
            dx = dx < 0 ? -s : s; dy = dy < 0 ? -s : s
        }
        let x0 = (min(a.x, a.x + dx)).rounded(), x1 = (max(a.x, a.x + dx)).rounded()
        let y0 = (min(a.y, a.y + dy)).rounded(), y1 = (max(a.y, a.y + dy)).rounded()
        return CGRect(x: x0, y: y0, width: x1 - x0, height: y1 - y0)
    }

    var isActive: Bool { active }

    // MARK: Ablauf

    func begin(tool: Tool, at p: CGPoint, modifiers: Modifiers) {
        guard let d = doc else { return }
        self.tool = tool
        start = p
        mods = modifiers
        active = true
        switch tool {
        case .rectangleSelect, .ellipseSelect:
            dragShape = nil
        case .lassoSelect:
            points = [p]
            dragShape = .lasso(points)
        case .magicWand:
            active = false
            applyMagicWand(at: p, modifiers: modifiers)
        case .moveSelection:
            guard d.hasSelection else { NSSound.beep(); active = false; return }
            d.settlePreview()
            selectionOffset = .zero
        case .moveSelectedPixels:
            if d.floating != nil && modifiers.command {
                // ⌘ bei schwebenden Pixeln: aktuelle Lage einmischen und eine Kopie weiterziehen
                d.commitFloating()
            }
            if d.floating == nil {
                guard let f = d.liftSelectedPixels(copy: modifiers.command) else { NSSound.beep(); active = false; return }
                d.beginFloating(f)
            }
            floatStartOrigin = d.floating?.origin ?? .zero
        default:
            active = false
        }
        onChange?()
    }

    func drag(to p: CGPoint, modifiers: Modifiers) {
        guard active, let d = doc else { return }
        mods.shift = modifiers.shift
        switch tool {
        case .rectangleSelect:
            dragShape = .rect(Self.snappedRect(from: start, to: p, square: mods.shift))
        case .ellipseSelect:
            dragShape = .ellipse(Self.snappedRect(from: start, to: p, square: mods.shift))
        case .lassoSelect:
            if let last = points.last, hypot(last.x - p.x, last.y - p.y) < 0.5 { return }
            points.append(p)
            dragShape = .lasso(points)
        case .moveSelection:
            selectionOffset = CGPoint(x: (p.x - start.x).rounded(), y: (p.y - start.y).rounded())
        case .moveSelectedPixels:
            d.moveFloating(to: PixelPoint(floatStartOrigin.x + Int((p.x - start.x).rounded()),
                                          floatStartOrigin.y + Int((p.y - start.y).rounded())))
        default: break
        }
        onChange?()
    }

    func end(at p: CGPoint, modifiers: Modifiers) {
        guard active, let d = doc else { return }
        drag(to: p, modifiers: modifiers)
        active = false
        let mode = Self.mode(base: ctrl.selectionMode, mods)
        switch tool {
        case .rectangleSelect, .ellipseSelect:
            let r = Self.snappedRect(from: start, to: p, square: mods.shift)
            dragShape = nil
            if r.width < 1 || r.height < 1 {
                // Einfacher Klick ohne Aufziehen hebt im Modus „Ersetzen“ die Auswahl auf (Referenz).
                if mode == .replace && d.hasSelection { d.deselect() }
                break
            }
            let pr = PixelRect(x: Int(r.minX), y: Int(r.minY), width: Int(r.width), height: Int(r.height))
            let mask = tool == .rectangleSelect ? SelectionMask.rectangle(pr, in: d.size) : SelectionMask.ellipse(pr, in: d.size)
            d.setSelection(d.combinedSelection(mask, mode: mode), name: tool.historyName)
        case .lassoSelect:
            dragShape = nil
            let poly = points.map { (x: Double($0.x), y: Double($0.y)) }
            points = []
            let mask = SelectionMask.polygon(poly, in: d.size)
            if mask.isEmpty { if mode == .replace && d.hasSelection { d.deselect() }; break }
            d.setSelection(d.combinedSelection(mask, mode: mode), name: tool.historyName)
        case .moveSelection:
            let off = selectionOffset ?? .zero
            selectionOffset = nil
            if off != .zero {
                d.commit(d.selectionMoved(dx: Int(off.x), dy: Int(off.y), from: d.state), name: "Auswahl verschieben", kind: .selectionMove)
            }
        case .moveSelectedPixels:
            break   // bleibt schwebend bis „Fertigstellen“ (Eingabetaste, Werkzeugwechsel, anderer Befehl)
        default: break
        }
        onChange?()
    }

    func cancelDrag() {
        active = false; dragShape = nil; selectionOffset = nil; points = []
        onChange?()
    }

    func applyMagicWand(at p: CGPoint, modifiers: Modifiers) {
        guard let d = doc else { return }
        let px = PixelPoint(Int(p.x.rounded(.down)), Int(p.y.rounded(.down)))
        guard PixelRect(size: d.size).contains(px) else { return }
        d.settlePreview()
        let source = ctrl.wandSampleImage ? d.flattenedSurface() : d.activeLayer.surface
        let global = ctrl.wandGlobal != modifiers.shift
        let mask = SelectionMask.magicWand(on: source, at: px, tolerance: ctrl.wandTolerance, global: global)
        d.setSelection(d.combinedSelection(mask, mode: Self.mode(base: ctrl.selectionMode, modifiers)), name: Tool.magicWand.historyName)
    }

    /// Pfeiltasten bei den Verschiebewerkzeugen.
    func nudge(dx: Int, dy: Int) {
        guard let d = doc else { return }
        switch ctrl.tool {
        case .moveSelectedPixels:
            if d.floating == nil {
                guard let f = d.liftSelectedPixels(copy: false) else { NSSound.beep(); return }
                d.beginFloating(f)
            }
            if let o = d.floating?.origin { d.moveFloating(to: PixelPoint(o.x + dx, o.y + dy)) }
        case .moveSelection:
            guard d.hasSelection else { NSSound.beep(); return }
            d.commit(d.selectionMoved(dx: dx, dy: dy, from: d.state), name: "Auswahl verschieben", kind: .selectionMove)
        default: break
        }
        onChange?()
    }

    /// Größe für die Statusleiste: laufendes Aufziehen, schwebende Pixel oder Auswahl.
    var displayedSize: PixelSize? {
        switch dragShape {
        case let .rect(r)?, let .ellipse(r)?: return PixelSize(Int(r.width), Int(r.height))
        case let .lasso(pts)?:
            guard let minX = pts.map(\.x).min(), let maxX = pts.map(\.x).max(), let minY = pts.map(\.y).min(), let maxY = pts.map(\.y).max() else { return nil }
            return PixelSize(Int((maxX - minX).rounded()), Int((maxY - minY).rounded()))
        case nil: break
        }
        if let f = doc?.floating { return f.rect.size }
        return doc?.selectionBounds?.size
    }

    /// Pfad der Vorschauform in Bildkoordinaten.
    var dragPath: CGPath? {
        guard let s = dragShape else { return nil }
        switch s {
        case let .rect(r): return CGPath(rect: r, transform: nil)
        case let .ellipse(r): return CGPath(ellipseIn: r, transform: nil)
        case let .lasso(pts):
            let p = CGMutablePath()
            p.addLines(between: pts)
            if pts.count > 2 { p.closeSubpath() }
            return p
        }
    }
}
