import AppKit
import EditorCore
import EditorDocument

/// Farbverlauf, Linie und Formen: Aufziehen mit Live-Vorschau, ein Verlaufsschritt beim Loslassen.
/// Arbeitet mit Bildkoordinaten (vom Selbsttest direkt aufrufbar).
final class ShapeInteraction {
    private var tool: Tool = .shapes
    private var base: DocumentState?
    private var start = CGPoint.zero
    private var current = CGPoint.zero
    private var swapColors = false
    var onChange: (() -> Void)?

    private var ctrl: AppController { .shared }

    var isActive: Bool { base != nil }

    /// Hilfslinie (Start → Ende) für den Farbverlauf, Bildkoordinaten.
    var guide: (CGPoint, CGPoint)? { base != nil && tool == .gradient ? (start, current) : nil }

    func begin(tool: Tool, at p: CGPoint, right: Bool) {
        guard let d = ctrl.document else { return }
        d.settlePreview()
        self.tool = tool
        base = d.state
        start = p
        current = p
        swapColors = right
        onChange?()
    }

    func drag(to p: CGPoint, shift: Bool) {
        guard let d = ctrl.document, let b = base else { return }
        current = adjusted(p, shift: shift)
        if let s = resultState(base: b) { d.preview(s) }
        onChange?()
    }

    func end(at p: CGPoint, shift: Bool) {
        guard let d = ctrl.document, let b = base else { return }
        current = adjusted(p, shift: shift)
        let result = resultState(base: b)
        base = nil
        if d.isPreviewing { d.endPreview(commitAs: nil) }
        if let s = result, s != d.state { d.commit(s, name: historyName, kind: .paint) }
        onChange?()
    }

    func cancel() {
        guard base != nil else { return }
        base = nil
        ctrl.document?.endPreview(commitAs: nil)
        onChange?()
    }

    private var historyName: String {
        switch tool {
        case .gradient: return "Farbverlauf"
        case .lineCurve: return "Linie/Kurve"
        default: return ctrl.shapeKind.displayName
        }
    }

    /// ⇧: Formen quadratisch, Linie und Verlauf in 15°-Schritten.
    private func adjusted(_ p: CGPoint, shift: Bool) -> CGPoint {
        guard shift else { return p }
        if tool == .shapes {
            let dx = p.x - start.x, dy = p.y - start.y
            let s = max(abs(dx), abs(dy))
            return CGPoint(x: start.x + (dx < 0 ? -s : s), y: start.y + (dy < 0 ? -s : s))
        }
        let q = LineSpec.snapped(from: (Double(start.x), Double(start.y)), to: (Double(p.x), Double(p.y)))
        return CGPoint(x: q.x, y: q.y)
    }

    private func resultState(base b: DocumentState) -> DocumentState? {
        guard let d = ctrl.document else { return nil }
        let primary = swapColors ? ctrl.colors.secondary : ctrl.colors.primary
        let secondary = swapColors ? ctrl.colors.primary : ctrl.colors.secondary
        let (x0, y0, x1, y1) = (Double(start.x), Double(start.y), Double(current.x), Double(current.y))
        if hypot(x1 - x0, y1 - y0) < 1 { return nil }
        switch tool {
        case .gradient:
            let spec = GradientSpec(kind: ctrl.gradientKind, x0: x0, y0: y0, x1: x1, y1: y1, start: primary, end: secondary,
                                    transparencyMode: ctrl.gradientTransparency, repeatMode: ctrl.gradientRepeat)
            return d.stateWithGradient(spec, blend: ctrl.paintBlend, base: b)
        case .lineCurve:
            let spec = LineSpec(x0: x0, y0: y0, x1: x1, y1: y1, width: ctrl.brushWidth, antialias: ctrl.antialias,
                                dash: ctrl.lineDash, arrowStart: ctrl.arrowStart, arrowEnd: ctrl.arrowEnd)
            return d.stateWithLine(spec, color: primary, blend: ctrl.paintBlend, base: b)
        case .shapes:
            let spec = ShapeSpec(kind: ctrl.shapeKind, x0: x0.rounded(), y0: y0.rounded(), x1: x1.rounded(), y1: y1.rounded(),
                                 style: ctrl.shapeStyle, lineWidth: ctrl.brushWidth, antialias: ctrl.antialias)
            return d.stateWithShape(spec, outline: primary, fill: secondary, blend: ctrl.paintBlend, base: b)
        default:
            return nil
        }
    }
}
