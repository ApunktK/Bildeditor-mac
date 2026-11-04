import AppKit
import EditorCore
import EditorDocument

/// Zeichenfläche: Bild mit Schachbrett darunter, mittig in mindestens Ansichtsgröße, damit auch Mauspositionen
/// außerhalb des Bildes (negative Koordinaten wie in der Referenz) gemeldet werden.
final class CanvasView: NSView {
    weak var controller: CanvasController?
    /// Linke obere Ecke des Bildes in Ansichtskoordinaten.
    var imageOrigin: NSPoint = .zero
    /// Rahmen des Zoom-Werkzeugs (Ansichtskoordinaten).
    var rubberBand: NSRect? { didSet { needsDisplay = true } }

    static let backgroundColor = NSColor(name: "Zeichenflaechenhintergrund") { app in
        app.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua
            ? NSColor(srgbRed: 0.16, green: 0.17, blue: 0.19, alpha: 1)
            : NSColor(srgbRed: 0.80, green: 0.83, blue: 0.87, alpha: 1)
    }

    override var isFlipped: Bool { true }
    override var acceptsFirstResponder: Bool { true }
    override var isOpaque: Bool { true }

    var imageRect: NSRect {
        guard let s = controller?.session else { return .zero }
        let sc = controller!.scale
        return NSRect(x: imageOrigin.x, y: imageOrigin.y,
                      width: (CGFloat(s.document.size.width) * sc).rounded(), height: (CGFloat(s.document.size.height) * sc).rounded())
    }

    override func draw(_ dirtyRect: NSRect) {
        Self.backgroundColor.setFill()
        dirtyRect.fill()
        guard let c = controller, let s = c.session, let ctx = NSGraphicsContext.current?.cgContext else { return }
        let ir = imageRect
        let visible = ir.intersection(dirtyRect)
        if visible.isEmpty { drawRubberBand(); return }

        // Schachbrett für Transparenz
        NSGraphicsContext.saveGraphicsState()
        NSGraphicsContext.current?.patternPhase = NSPoint(x: ir.minX, y: ir.minY)
        ImageRendering.checkerboardColor.setFill()
        visible.fill()
        NSGraphicsContext.restoreGraphicsState()

        if let img = s.composite {
            ctx.saveGState()
            ctx.clip(to: visible)
            ctx.interpolationQuality = s.zoom >= 100 ? .none : .high
            ctx.translateBy(x: ir.minX, y: ir.maxY)
            ctx.scaleBy(x: 1, y: -1)
            ctx.draw(img, in: CGRect(x: 0, y: 0, width: ir.width, height: ir.height))
            ctx.restoreGState()
        }

        // Pixelraster ab 200 % (Referenz: unter 200 % nicht sichtbar)
        if AppController.shared.showPixelGrid && s.zoom >= 200 {
            let sc = c.scale
            let size = s.document.size
            let x0 = max(0, Int(floor((visible.minX - ir.minX) / sc))), x1 = min(size.width, Int(ceil((visible.maxX - ir.minX) / sc)))
            let y0 = max(0, Int(floor((visible.minY - ir.minY) / sc))), y1 = min(size.height, Int(ceil((visible.maxY - ir.minY) / sc)))
            let path = NSBezierPath()
            path.lineWidth = 1 / max(1, window?.backingScaleFactor ?? 1)
            if x0 <= x1 && y0 <= y1 {
            for x in x0...x1 {
                let px = ir.minX + CGFloat(x) * sc
                path.move(to: NSPoint(x: px, y: visible.minY)); path.line(to: NSPoint(x: px, y: visible.maxY))
            }
            for y in y0...y1 {
                let py = ir.minY + CGFloat(y) * sc
                path.move(to: NSPoint(x: visible.minX, y: py)); path.line(to: NSPoint(x: visible.maxX, y: py))
            }
            }
            NSColor(white: 0.45, alpha: 0.55).setStroke()
            path.stroke()
        }
        drawRubberBand()
    }

    private func drawRubberBand() {
        guard let r = rubberBand, !r.isEmpty else { return }
        NSColor.controlAccentColor.withAlphaComponent(0.15).setFill()
        r.fill()
        NSColor.controlAccentColor.setStroke()
        let p = NSBezierPath(rect: r.insetBy(dx: 0.5, dy: 0.5))
        p.setLineDash([4, 3], count: 2, phase: 0)
        p.stroke()
    }

    // MARK: Eingabe → Controller

    private var tracking: NSTrackingArea?
    override func updateTrackingAreas() {
        super.updateTrackingAreas()
        if let t = tracking { removeTrackingArea(t) }
        let t = NSTrackingArea(rect: .zero, options: [.mouseMoved, .mouseEnteredAndExited, .activeInActiveApp, .inVisibleRect],
                               owner: self, userInfo: nil)
        addTrackingArea(t)
        tracking = t
    }

    override func resetCursorRects() {
        addCursorRect(visibleRect, cursor: controller?.cursor ?? .arrow)
    }

    override func mouseMoved(with e: NSEvent) { controller?.pointerMoved(e) }
    override func mouseExited(with e: NSEvent) { controller?.pointerExited() }
    override func mouseDown(with e: NSEvent) { window?.makeFirstResponder(self); controller?.mouseDown(e, button: .left) }
    override func mouseDragged(with e: NSEvent) { controller?.mouseDragged(e) }
    override func mouseUp(with e: NSEvent) { controller?.mouseUp(e) }
    override func rightMouseDown(with e: NSEvent) { controller?.mouseDown(e, button: .right) }
    override func rightMouseDragged(with e: NSEvent) { controller?.mouseDragged(e) }
    override func rightMouseUp(with e: NSEvent) { controller?.mouseUp(e) }
    override func otherMouseDown(with e: NSEvent) { controller?.mouseDown(e, button: .middle) }
    override func otherMouseDragged(with e: NSEvent) { controller?.mouseDragged(e) }
    override func otherMouseUp(with e: NSEvent) { controller?.mouseUp(e) }
    override func magnify(with e: NSEvent) { controller?.magnify(e) }

    override func scrollWheel(with e: NSEvent) {
        if controller?.scrollWheel(e) == true { return }
        super.scrollWheel(with: e)
    }

    override func keyDown(with e: NSEvent) {
        if controller?.keyDown(e) == true { return }
        super.keyDown(with: e)
    }

    override func keyUp(with e: NSEvent) {
        if controller?.keyUp(e) == true { return }
        super.keyUp(with: e)
    }

    // Rechtsklick nicht als Kontextmenü, sondern für das Zoom-Werkzeug (Referenz: Rechtsklick = verkleinern).
    override func menu(for event: NSEvent) -> NSMenu? { nil }
}

/// Steuert Zoom, Bildlauf und die Ansichtswerkzeuge (Zoom, Hand) für das aktive Bild.
final class CanvasController: NSObject {
    enum Button { case left, right, middle }

    let scrollView = DropScrollView()
    let canvasView = CanvasView()
    var onPointerMoved: ((PixelPoint?) -> Void)?
    var onZoomChanged: (() -> Void)?

    var session: DocumentSession? { AppController.shared.active }
    var scale: CGFloat { CGFloat((session?.zoom ?? 100) / 100) }
    private var clip: NSClipView { scrollView.contentView }

    override init() {
        super.init()
        canvasView.controller = self
        scrollView.documentView = canvasView
        scrollView.hasHorizontalScroller = true
        scrollView.hasVerticalScroller = true
        scrollView.autohidesScrollers = true
        scrollView.drawsBackground = true
        scrollView.backgroundColor = CanvasView.backgroundColor
        scrollView.borderType = .noBorder
        scrollView.allowsMagnification = false
        clip.postsFrameChangedNotifications = true
        NotificationCenter.default.addObserver(self, selector: #selector(clipResized), name: NSView.frameDidChangeNotification, object: clip)
    }

    // MARK: Geometrie

    func imagePoint(fromView p: NSPoint) -> CGPoint {
        CGPoint(x: (p.x - canvasView.imageOrigin.x) / scale, y: (p.y - canvasView.imageOrigin.y) / scale)
    }

    func viewPoint(fromImage p: CGPoint) -> NSPoint {
        NSPoint(x: canvasView.imageOrigin.x + p.x * scale, y: canvasView.imageOrigin.y + p.y * scale)
    }

    func pixel(at e: NSEvent) -> PixelPoint {
        let ip = imagePoint(fromView: canvasView.convert(e.locationInWindow, from: nil))
        return PixelPoint(Int(floor(ip.x)), Int(floor(ip.y)))
    }

    /// Bildpunkt in der Mitte des sichtbaren Bereichs.
    var visibleCenterInImage: CGPoint {
        let v = clip.bounds
        return imagePoint(fromView: NSPoint(x: v.midX, y: v.midY))
    }

    /// Größe und Lage der Zeichenfläche an Zoom und Fenster anpassen.
    func layoutCanvas() {
        let avail = clip.bounds.size
        guard let s = session else {
            canvasView.setFrameSize(avail)
            canvasView.needsDisplay = true
            return
        }
        let iw = (CGFloat(s.document.size.width) * scale).rounded(), ih = (CGFloat(s.document.size.height) * scale).rounded()
        let size = NSSize(width: max(iw, avail.width), height: max(ih, avail.height))
        canvasView.setFrameSize(size)
        canvasView.imageOrigin = NSPoint(x: floor((size.width - iw) / 2), y: floor((size.height - ih) / 2))
        canvasView.needsDisplay = true
    }

    @objc private func clipResized() {
        guard session != nil else { layoutCanvas(); return }
        let c = visibleCenterInImage
        layoutCanvas()
        center(onImage: c)
    }

    func scroll(to p: NSPoint) {
        let r = clip.constrainBoundsRect(NSRect(origin: p, size: clip.bounds.size))
        clip.scroll(to: r.origin)
        scrollView.reflectScrolledClipView(clip)
    }

    func center(onImage p: CGPoint) {
        let v = viewPoint(fromImage: p)
        scroll(to: NSPoint(x: v.x - clip.bounds.width / 2, y: v.y - clip.bounds.height / 2))
    }

    // MARK: Zoom

    /// Zoom setzen; `anchor` (Ansichtskoordinaten) bleibt an derselben Stelle im Fenster.
    func setZoom(_ percent: Double, anchor: NSPoint?) {
        guard let s = session else { return }
        let z = ZoomLevels.clamp(percent)
        let vis = clip.bounds
        let a = anchor ?? NSPoint(x: vis.midX, y: vis.midY)
        let ip = imagePoint(fromView: a)
        let offset = NSPoint(x: a.x - vis.minX, y: a.y - vis.minY)
        s.zoom = z
        layoutCanvas()
        let na = viewPoint(fromImage: ip)
        scroll(to: NSPoint(x: na.x - offset.x, y: na.y - offset.y))
        canvasView.window?.invalidateCursorRects(for: canvasView)
        onZoomChanged?()
    }

    func zoomStep(_ direction: Int, anchor: NSPoint? = nil) {
        guard let s = session else { return }
        setZoom(direction > 0 ? ZoomLevels.zoomIn(from: s.zoom) : ZoomLevels.zoomOut(from: s.zoom), anchor: anchor)
    }

    /// „An Fenster anpassen“ (Referenz: nie über 100 %).
    func zoomToFit() {
        guard let s = session else { return }
        let a = clip.bounds.size
        let z = ZoomLevels.fit(image: s.document.size, into: Double(max(1, a.width - 16)), Double(max(1, a.height - 16)))
        setZoom(z, anchor: nil)
        center(onImage: CGPoint(x: Double(s.document.size.width) / 2, y: Double(s.document.size.height) / 2))
        onZoomChanged?()
    }

    func zoom(toImageRect r: CGRect) {
        guard r.width >= 1, r.height >= 1 else { return }
        let a = clip.bounds.size
        let z = min(Double(a.width / r.width), Double(a.height / r.height)) * 100
        setZoom(z, anchor: nil)
        center(onImage: CGPoint(x: r.midX, y: r.midY))
        onZoomChanged?()
    }

    /// Beim Wechsel des aktiven Bildes: Ansichtszustand herstellen.
    func showActiveSession() {
        guard let s = session else { layoutCanvas(); onZoomChanged?(); return }
        if s.needsInitialFit {
            s.needsInitialFit = false
            s.zoom = 100
            layoutCanvas()
            zoomToFit()
        } else {
            layoutCanvas()
            center(onImage: s.viewCenter ?? CGPoint(x: Double(s.document.size.width) / 2, y: Double(s.document.size.height) / 2))
        }
        canvasView.window?.invalidateCursorRects(for: canvasView)
        onZoomChanged?()
    }

    func rememberViewState() {
        guard let s = session, s.document.size.area > 0 else { return }
        s.viewCenter = visibleCenterInImage
    }

    /// Bildinhalt oder -größe geändert.
    func documentChanged(_ change: Document.Change) {
        switch change {
        case .size:
            let c = visibleCenterInImage
            layoutCanvas()
            center(onImage: c)
        case .content, .layers:
            canvasView.needsDisplay = true
        default: break
        }
    }

    // MARK: Werkzeuge

    private var spaceDown = false
    private var activeDrag: (tool: Tool, button: Button, startWindow: NSPoint, startOrigin: NSPoint, startView: NSPoint)?

    private var effectiveTool: Tool { spaceDown ? .pan : AppController.shared.tool }

    var cursor: NSCursor {
        if activeDrag?.tool == .pan { return .closedHand }
        switch effectiveTool {
        case .pan: return .openHand
        case .zoom: return Self.zoomCursor
        default: return .arrow
        }
    }

    static let zoomCursor: NSCursor = {
        let cfg = NSImage.SymbolConfiguration(pointSize: 16, weight: .regular)
        guard let img = NSImage(systemSymbolName: "plus.magnifyingglass", accessibilityDescription: "Zoom")?
            .withSymbolConfiguration(cfg) else { return .crosshair }
        return NSCursor(image: img, hotSpot: NSPoint(x: img.size.width * 0.4, y: img.size.height * 0.4))
    }()

    func toolChanged() { canvasView.window?.invalidateCursorRects(for: canvasView) }

    func pointerMoved(_ e: NSEvent) {
        guard session != nil else { onPointerMoved?(nil); return }
        onPointerMoved?(pixel(at: e))
    }

    func pointerExited() { }

    func mouseDown(_ e: NSEvent, button: Button) {
        guard session != nil else { return }
        let tool: Tool = button == .middle ? .pan : effectiveTool
        guard tool == .zoom || tool == .pan else { NSSound.beep(); return }
        activeDrag = (tool, button, e.locationInWindow, clip.bounds.origin, canvasView.convert(e.locationInWindow, from: nil))
        if tool == .pan { canvasView.window?.invalidateCursorRects(for: canvasView); NSCursor.closedHand.set() }
    }

    func mouseDragged(_ e: NSEvent) {
        guard let d = activeDrag else { return }
        onPointerMoved?(pixel(at: e))
        switch d.tool {
        case .pan:
            let dx = e.locationInWindow.x - d.startWindow.x, dy = e.locationInWindow.y - d.startWindow.y
            scroll(to: NSPoint(x: d.startOrigin.x - dx, y: d.startOrigin.y + dy))
        case .zoom where d.button == .left:
            let p = canvasView.convert(e.locationInWindow, from: nil)
            canvasView.rubberBand = NSRect(x: min(p.x, d.startView.x), y: min(p.y, d.startView.y),
                                           width: abs(p.x - d.startView.x), height: abs(p.y - d.startView.y))
        default: break
        }
    }

    func mouseUp(_ e: NSEvent) {
        guard let d = activeDrag else { return }
        activeDrag = nil
        if d.tool == .zoom {
            let band = canvasView.rubberBand
            canvasView.rubberBand = nil
            if let b = band, b.width > 4, b.height > 4 {
                let a = imagePoint(fromView: b.origin), z = imagePoint(fromView: NSPoint(x: b.maxX, y: b.maxY))
                zoom(toImageRect: CGRect(x: a.x, y: a.y, width: z.x - a.x, height: z.y - a.y))
            } else {
                let zoomOut = d.button == .right || e.modifierFlags.contains(.option)
                zoomStep(zoomOut ? -1 : 1, anchor: d.startView)
            }
        }
        canvasView.window?.invalidateCursorRects(for: canvasView)
    }

    func magnify(_ e: NSEvent) {
        guard let s = session else { return }
        setZoom(s.zoom * Double(1 + e.magnification), anchor: canvasView.convert(e.locationInWindow, from: nil))
    }

    private var wheelAccumulator: CGFloat = 0

    /// Cmd + Mausrad = Zoom (Referenz: Strg + Mausrad).
    func scrollWheel(_ e: NSEvent) -> Bool {
        guard e.modifierFlags.contains(.command), session != nil else { return false }
        wheelAccumulator += e.hasPreciseScrollingDeltas ? e.scrollingDeltaY / 20 : e.scrollingDeltaY
        let anchor = canvasView.convert(e.locationInWindow, from: nil)
        while abs(wheelAccumulator) >= 1 {
            zoomStep(wheelAccumulator > 0 ? 1 : -1, anchor: anchor)
            wheelAccumulator -= wheelAccumulator > 0 ? 1 : -1
        }
        return true
    }

    func keyDown(_ e: NSEvent) -> Bool {
        let mods = e.modifierFlags.intersection(.deviceIndependentFlagsMask).subtracting([.capsLock, .numericPad, .function])
        if e.charactersIgnoringModifiers == " " && mods.isEmpty {
            if !e.isARepeat { spaceDown = true; canvasView.window?.invalidateCursorRects(for: canvasView) }
            return true
        }
        // Cmd+1 … Cmd+9: zum Bild Nummer X wechseln
        if mods == [.command], let ch = e.charactersIgnoringModifiers?.first, let n = ch.wholeNumberValue, n >= 1 {
            let list = AppController.shared.sessions
            if n <= list.count { AppController.shared.activate(list[n - 1]) } else { NSSound.beep() }
            return true
        }
        if mods.isEmpty || mods == [.shift], let ch = e.charactersIgnoringModifiers?.lowercased().first {
            return AppController.shared.handleSingleKey(ch, shift: mods.contains(.shift))
        }
        return false
    }

    func keyUp(_ e: NSEvent) -> Bool {
        if e.charactersIgnoringModifiers == " " {
            spaceDown = false
            canvasView.window?.invalidateCursorRects(for: canvasView)
            return true
        }
        return false
    }
}

/// Bildlaufbereich, der Bilddateien per Drag & Drop annimmt (öffnet sie als neue Bilder).
final class DropScrollView: NSScrollView {
    override init(frame: NSRect) {
        super.init(frame: frame)
        registerForDraggedTypes([.fileURL])
    }
    required init?(coder: NSCoder) { fatalError("nicht verwendet") }

    private func imageURLs(_ info: NSDraggingInfo) -> [URL] {
        let opts: [NSPasteboard.ReadingOptionKey: Any] = [.urlReadingFileURLsOnly: true]
        let urls = info.draggingPasteboard.readObjects(forClasses: [NSURL.self], options: opts) as? [URL] ?? []
        let types = ImageCodec.readableTypes
        return urls.filter { url in
            guard let t = try? url.resourceValues(forKeys: [.contentTypeKey]).contentType else { return false }
            return types.contains { t.conforms(to: $0) }
        }
    }

    override func draggingEntered(_ sender: NSDraggingInfo) -> NSDragOperation { imageURLs(sender).isEmpty ? [] : .copy }
    override func draggingUpdated(_ sender: NSDraggingInfo) -> NSDragOperation { imageURLs(sender).isEmpty ? [] : .copy }
    override func performDragOperation(_ sender: NSDraggingInfo) -> Bool {
        let urls = imageURLs(sender)
        guard !urls.isEmpty else { return false }
        AppController.shared.open(urls: urls)
        return true
    }
}
