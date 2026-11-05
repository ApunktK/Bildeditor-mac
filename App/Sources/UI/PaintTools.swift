import AppKit
import EditorCore
import EditorDocument

/// Bedienung der Malwerkzeuge (Pinsel, Stift, Radiergummi, Farbeimer, Farbpipette) in Bildkoordinaten,
/// damit der Selbsttest sie ohne echte Mausereignisse aufrufen kann.
final class PaintInteraction {
    private(set) var stroke: StrokeSession?
    private var tool: Tool = .paintbrush
    private var right = false
    /// Ende des letzten Strichs je Werkzeug (⇧-Klick verbindet mit gerader Linie).
    private var lastEnd: (tool: Tool, x: Double, y: Double)?
    /// Mausposition für den Pinselumriss (Bildkoordinaten).
    var hover: CGPoint?
    var onChange: (() -> Void)?

    private var ctrl: AppController { .shared }

    var isActive: Bool { stroke != nil || tool == .colorPicker && pickerActive }
    private var pickerActive = false

    /// Kopierstempel: Quelle festlegen (⌘-Klick); der Versatz ergibt sich beim nächsten Strich.
    func setCloneSource(_ p: CGPoint) {
        ctrl.cloneSource = PixelPoint(Int(p.x.rounded(.down)), Int(p.y.rounded(.down)))
        ctrl.cloneOffset = nil
        onChange?()
    }

    func begin(tool: Tool, at p: CGPoint, right: Bool, shift: Bool) {
        guard let d = ctrl.document else { return }
        self.tool = tool
        self.right = right
        let color = right ? ctrl.colors.secondary : ctrl.colors.primary
        switch tool {
        case .paintbrush, .pencil, .eraser, .cloneStamp, .recolor:
            d.settlePreview()
            let kind: StrokeSession.Kind
            switch tool {
            case .eraser: kind = .eraser
            case .pencil: kind = .pencil(color)
            case .cloneStamp:
                guard let src = ctrl.cloneSource else {
                    NSSound.beep(); ctrl.mainWindow?.showTransientHint("Zuerst mit ⌘-Klick die Quelle festlegen."); return
                }
                if ctrl.cloneOffset == nil {
                    ctrl.cloneOffset = (src.x - Int(p.x.rounded(.down)), src.y - Int(p.y.rounded(.down)))
                }
                kind = .clone(dx: ctrl.cloneOffset!.dx, dy: ctrl.cloneOffset!.dy)
            case .recolor:
                let from = right ? ctrl.colors.primary : ctrl.colors.secondary, to = right ? ctrl.colors.secondary : ctrl.colors.primary
                kind = .recolor(from: from, to: to, tolerance: ctrl.wandTolerance)
            default: kind = .brush(color)
            }
            let s = StrokeSession(base: d.state, kind: kind, width: tool == .pencil ? 1 : ctrl.brushWidth,
                                  antialias: tool == .pencil ? false : ctrl.antialias, blend: ctrl.paintBlend)
            if shift, let le = lastEnd, le.tool == tool { s.add(x: le.x, y: le.y) }
            s.add(x: Double(p.x), y: Double(p.y))
            stroke = s
            d.previewStroke(s)
        case .paintBucket:
            let px = PixelPoint(Int(p.x.rounded(.down)), Int(p.y.rounded(.down)))
            if !d.floodFill(at: px, color: color, tolerance: ctrl.wandTolerance, global: ctrl.wandGlobal != shift,
                            sampleImage: ctrl.wandSampleImage, blend: ctrl.paintBlend) { NSSound.beep() }
        case .colorPicker:
            pickerActive = true
            pick(at: p)
        default: break
        }
        onChange?()
    }

    func drag(to p: CGPoint) {
        guard let d = ctrl.document else { return }
        hover = p
        if let s = stroke {
            s.add(x: Double(p.x), y: Double(p.y))
            d.previewStroke(s)
        } else if pickerActive {
            pick(at: p)
        }
        onChange?()
    }

    func end(at p: CGPoint) {
        guard let d = ctrl.document else { return }
        drag(to: p)
        if let s = stroke {
            d.commitStroke(s)
            if let l = s.lastPoint { lastEnd = (tool, l.x, l.y) }
            stroke = nil
        }
        if pickerActive {
            pickerActive = false
            switch ctrl.pickerAfter {
            case .stay: break
            case .previous: ctrl.tool = ctrl.previousTool
            case .pencil: ctrl.tool = .pencil
            }
        }
        onChange?()
    }

    private func pick(at p: CGPoint) {
        guard let d = ctrl.document else { return }
        let px = PixelPoint(Int(p.x.rounded(.down)), Int(p.y.rounded(.down)))
        guard let c = d.sampleColor(at: px, size: ctrl.pickerSampleSize, sampleImage: ctrl.pickerSampleImage) else { return }
        var cs = ctrl.colors
        if right { cs.secondary = c } else { cs.primary = c }
        ctrl.colors = cs
    }

    /// Umriss des Pinsels in Ansichtskoordinaten.
    func brushOutline(origin: NSPoint, scale: CGFloat) -> NSRect? {
        guard let h = hover, ctrl.tool.hasBrushWidth else { return nil }
        let r = CGFloat(ctrl.brushWidth) / 2 * scale
        return NSRect(x: origin.x + h.x * scale - r, y: origin.y + h.y * scale - r, width: r * 2, height: r * 2)
    }
}
