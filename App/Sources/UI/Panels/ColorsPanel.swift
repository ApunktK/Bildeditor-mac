import AppKit
import EditorCore

/// Farbton/Sättigung/Hellwert wie in der Referenz: H 0…360, S und V 0…100.
struct HSV: Equatable {
    var h: Double, s: Double, v: Double

    init(h: Double, s: Double, v: Double) { self.h = h; self.s = s; self.v = v }

    init(_ c: ColorBgra) {
        let r = Double(c.r) / 255, g = Double(c.g) / 255, b = Double(c.b) / 255
        let mx = max(r, g, b), mn = min(r, g, b), d = mx - mn
        var hh = 0.0
        if d > 0 {
            if mx == r { hh = 60 * ((g - b) / d).truncatingRemainder(dividingBy: 6) }
            else if mx == g { hh = 60 * ((b - r) / d + 2) }
            else { hh = 60 * ((r - g) / d + 4) }
        }
        if hh < 0 { hh += 360 }
        h = hh; s = mx == 0 ? 0 : d / mx * 100; v = mx * 100
    }

    func color(alpha: UInt8 = 255) -> ColorBgra {
        let s1 = max(0, min(100, s)) / 100, v1 = max(0, min(100, v)) / 100
        let hh = (h.truncatingRemainder(dividingBy: 360) + 360).truncatingRemainder(dividingBy: 360) / 60
        let c = v1 * s1, x = c * (1 - abs(hh.truncatingRemainder(dividingBy: 2) - 1)), m = v1 - c
        let (r, g, b): (Double, Double, Double)
        switch Int(hh) {
        case 0: (r, g, b) = (c, x, 0)
        case 1: (r, g, b) = (x, c, 0)
        case 2: (r, g, b) = (0, c, x)
        case 3: (r, g, b) = (0, x, c)
        case 4: (r, g, b) = (x, 0, c)
        default: (r, g, b) = (c, 0, x)
        }
        func q(_ t: Double) -> UInt8 { UInt8(max(0, min(255, ((t + m) * 255).rounded()))) }
        return ColorBgra(r: q(r), g: q(g), b: q(b), a: alpha)
    }
}

/// Eigene Standardpalette (96 Farben: Graustufen und 16 Farbtöne in fünf Abstufungen).
enum DefaultPalette {
    static let colors: [ColorBgra] = {
        var out: [ColorBgra] = (0..<16).map { i in let v = UInt8(i * 17); return ColorBgra(r: v, g: v, b: v) }
        let rows: [(Double, Double)] = [(100, 100), (50, 100), (100, 75), (100, 50), (30, 90)]
        for (s, v) in rows {
            for i in 0..<16 { out.append(HSV(h: Double(i) * 22.5, s: s, v: v).color()) }
        }
        return out
    }()
}

final class ColorsPanelController: NSViewController, NSTextFieldDelegate {
    private let selector = PrimarySecondaryView()
    private let wheel = ColorWheelView()
    private let palette = PaletteView()
    private let moreButton = NSButton(title: "Mehr »", target: nil, action: nil)
    private let details = NSStackView()
    private let hexField = NSTextField(string: "")
    private var sliders: [String: (NSSlider, NSTextField)] = [:]
    private var updating = false
    private var expanded = Settings.shared.colorsExpanded

    private var colors: ColorState {
        get { AppController.shared.colors }
        set { AppController.shared.colors = newValue }
    }

    override func loadView() {
        let v = NSView(frame: NSRect(x: 0, y: 0, width: 240, height: 250))
        moreButton.target = self; moreButton.action = #selector(toggleMore)
        moreButton.bezelStyle = .rounded; moreButton.controlSize = .small
        moreButton.toolTip = "Farbwerte (RGB, HSV, Deckkraft, Hex) und ganze Palette anzeigen"

        let top = NSStackView(views: [selector, moreButton])
        top.orientation = .horizontal
        top.alignment = .top
        top.distribution = .equalSpacing
        let left = NSStackView(views: [top, wheel, palette])
        left.orientation = .vertical
        left.alignment = .leading
        left.spacing = 8

        // Erweiterter Bereich
        details.orientation = .vertical
        details.alignment = .leading
        details.spacing = 4
        let hexLabel = NSTextField(labelWithString: "Hex:")
        hexField.delegate = self
        hexField.target = self; hexField.action = #selector(hexEntered)
        hexField.font = .monospacedSystemFont(ofSize: 11, weight: .regular)
        hexField.toolTip = "RRGGBB oder RRGGBBAA"
        hexField.widthAnchor.constraint(equalToConstant: 90).isActive = true
        details.addArrangedSubview(NSStackView(views: [hexLabel, hexField]))
        details.addArrangedSubview(sectionLabel("RGB"))
        for k in ["R", "G", "B"] { details.addArrangedSubview(makeSliderRow(k, max: 255)) }
        details.addArrangedSubview(sectionLabel("HSV"))
        details.addArrangedSubview(makeSliderRow("H", max: 360))
        details.addArrangedSubview(makeSliderRow("S", max: 100))
        details.addArrangedSubview(makeSliderRow("V", max: 100))
        details.addArrangedSubview(sectionLabel("Deckkraft"))
        details.addArrangedSubview(makeSliderRow("A", max: 255))

        let root = NSStackView(views: [left, details])
        root.orientation = .horizontal
        root.alignment = .top
        root.spacing = 14
        root.edgeInsets = NSEdgeInsets(top: 8, left: 8, bottom: 8, right: 8)
        root.translatesAutoresizingMaskIntoConstraints = false
        v.addSubview(root)
        NSLayoutConstraint.activate([
            root.leadingAnchor.constraint(equalTo: v.leadingAnchor), root.trailingAnchor.constraint(equalTo: v.trailingAnchor),
            root.topAnchor.constraint(equalTo: v.topAnchor), root.bottomAnchor.constraint(equalTo: v.bottomAnchor),
        ])

        selector.onChange = { [weak self] in self?.refresh() }
        wheel.onPick = { [weak self] hsv, toInactive in
            guard let self else { return }
            var c = self.colors
            if toInactive { c.inactive = hsv.color(alpha: c.inactive.a) } else { c.active = hsv.color(alpha: c.active.a) }
            self.colors = c
        }
        palette.onPick = { [weak self] col, toInactive in
            guard let self else { return }
            var c = self.colors
            if toInactive { c.inactive = col } else { c.active = col }
            self.colors = c
        }
        view = v
        applyExpanded()
        NotificationCenter.default.addObserver(self, selector: #selector(refresh), name: .paletteChanged, object: nil)
        refresh()
    }

    private func sectionLabel(_ t: String) -> NSTextField {
        let l = NSTextField(labelWithString: t)
        l.font = .boldSystemFont(ofSize: 11)
        return l
    }

    private func makeSliderRow(_ key: String, max: Double) -> NSView {
        let l = NSTextField(labelWithString: key + ":")
        l.font = .systemFont(ofSize: 11)
        l.widthAnchor.constraint(equalToConstant: 18).isActive = true
        let s = NSSlider(value: 0, minValue: 0, maxValue: max, target: self, action: #selector(sliderChanged(_:)))
        s.controlSize = .small
        s.identifier = NSUserInterfaceItemIdentifier(key)
        s.widthAnchor.constraint(equalToConstant: 130).isActive = true
        let f = NSTextField(string: "0")
        f.controlSize = .small
        f.font = .monospacedDigitSystemFont(ofSize: 11, weight: .regular)
        f.alignment = .right
        f.identifier = NSUserInterfaceItemIdentifier(key)
        f.target = self; f.action = #selector(fieldChanged(_:))
        f.widthAnchor.constraint(equalToConstant: 42).isActive = true
        sliders[key] = (s, f)
        let row = NSStackView(views: [l, s, f])
        row.orientation = .horizontal
        row.spacing = 4
        return row
    }

    @objc private func toggleMore() {
        expanded.toggle()
        Settings.shared.colorsExpanded = expanded
        applyExpanded()
    }

    private func applyExpanded() {
        details.isHidden = !expanded
        palette.showAll = expanded
        moreButton.title = expanded ? "« Weniger" : "Mehr »"
        view.layoutSubtreeIfNeeded()
        if let w = view.window {
            let size = view.fittingSize
            var f = w.frameRect(forContentRect: NSRect(origin: .zero, size: size))
            f.origin = NSPoint(x: w.frame.minX, y: w.frame.maxY - f.height)   // obere linke Ecke bleibt
            w.setFrame(f, display: true)
        } else {
            view.setFrameSize(view.fittingSize)
        }
    }

    @objc func refresh() {
        updating = true
        defer { updating = false }
        let c = colors
        selector.state = c
        let a = c.active
        wheel.current = HSV(a)
        let hsv = HSV(a)
        let values: [String: Double] = ["R": Double(a.r), "G": Double(a.g), "B": Double(a.b),
                                        "H": hsv.h.rounded(), "S": hsv.s.rounded(), "V": hsv.v.rounded(), "A": Double(a.a)]
        for (k, (s, f)) in sliders {
            s.doubleValue = values[k] ?? 0
            if f.currentEditor() == nil { f.stringValue = String(Int(values[k] ?? 0)) }
        }
        if hexField.currentEditor() == nil { hexField.stringValue = a.hexString }
    }

    private func apply(key: String, value: Double) {
        var a = colors.active
        switch key {
        case "R": a.r = UInt8(max(0, min(255, value.rounded())))
        case "G": a.g = UInt8(max(0, min(255, value.rounded())))
        case "B": a.b = UInt8(max(0, min(255, value.rounded())))
        case "A": a.a = UInt8(max(0, min(255, value.rounded())))
        default:
            var hsv = HSV(a)
            if key == "H" { hsv.h = value } else if key == "S" { hsv.s = value } else { hsv.v = value }
            a = hsv.color(alpha: a.a)
        }
        var c = colors
        c.active = a
        colors = c
    }

    @objc private func sliderChanged(_ s: NSSlider) {
        guard !updating, let k = s.identifier?.rawValue else { return }
        apply(key: k, value: s.doubleValue)
    }

    @objc private func fieldChanged(_ f: NSTextField) {
        guard let k = f.identifier?.rawValue, let v = Double(f.stringValue.replacingOccurrences(of: ",", with: ".")) else { NSSound.beep(); refresh(); return }
        apply(key: k, value: v)
        refresh()
    }

    @objc private func hexEntered() {
        guard let c = ColorBgra(hex: hexField.stringValue) else { NSSound.beep(); hexField.stringValue = colors.active.hexString; return }
        var s = colors
        s.active = c
        colors = s
    }
}

/// Überlappende Felder für Primär- (vorne) und Sekundärfarbe (hinten); Kerbe = aktives Feld.
/// Pfeil oben rechts tauscht, Schwarz/Weiß unten links setzt zurück.
final class PrimarySecondaryView: NSView {
    var state = ColorState(primary: .black, secondary: .white) { didSet { needsDisplay = true } }
    var onChange: (() -> Void)?

    override init(frame: NSRect) {
        super.init(frame: frame)
        translatesAutoresizingMaskIntoConstraints = false
        widthAnchor.constraint(equalToConstant: 64).isActive = true
        heightAnchor.constraint(equalToConstant: 64).isActive = true
        toolTip = "Primär- und Sekundärfarbe. Klick auf ein Feld macht es aktiv (C). Pfeil: tauschen (X). Schwarz/Weiß: zurücksetzen."
    }
    required init?(coder: NSCoder) { fatalError("nicht verwendet") }
    override var isFlipped: Bool { true }

    private let primaryRect = NSRect(x: 4, y: 4, width: 36, height: 36)
    private let secondaryRect = NSRect(x: 22, y: 22, width: 36, height: 36)
    private let swapRect = NSRect(x: 44, y: 2, width: 18, height: 16)
    private let resetRect = NSRect(x: 2, y: 44, width: 16, height: 16)

    override func draw(_ dirtyRect: NSRect) {
        func swatch(_ r: NSRect, _ c: ColorBgra, active: Bool) {
            ImageRendering.checkerboardColor.setFill(); r.fill()
            c.nsColor.setFill(); r.fill()
            NSColor.labelColor.setStroke()
            NSBezierPath(rect: r.insetBy(dx: 0.5, dy: 0.5)).stroke()
            NSColor.windowBackgroundColor.setStroke()
            NSBezierPath(rect: r.insetBy(dx: 1.5, dy: 1.5)).stroke()
            if active {
                let notch = NSBezierPath()
                notch.move(to: NSPoint(x: r.minX, y: r.minY)); notch.line(to: NSPoint(x: r.minX + 10, y: r.minY))
                notch.line(to: NSPoint(x: r.minX, y: r.minY + 10)); notch.close()
                NSColor.controlAccentColor.setFill(); notch.fill()
            }
        }
        swatch(secondaryRect, state.secondary, active: !state.primaryIsActive)
        swatch(primaryRect, state.primary, active: state.primaryIsActive)
        if let img = NSImage(systemSymbolName: "arrow.left.arrow.right", accessibilityDescription: "Tauschen") {
            img.draw(in: swapRect.insetBy(dx: 1, dy: 1))
        }
        NSColor.black.setFill(); NSRect(x: resetRect.minX, y: resetRect.minY, width: 10, height: 10).fill()
        NSColor.white.setFill(); NSRect(x: resetRect.minX + 6, y: resetRect.minY + 6, width: 10, height: 10).fill()
        NSColor.labelColor.setStroke()
        NSBezierPath(rect: NSRect(x: resetRect.minX + 6.5, y: resetRect.minY + 6.5, width: 9, height: 9)).stroke()
    }

    override func mouseDown(with e: NSEvent) {
        let p = convert(e.locationInWindow, from: nil)
        let ctrl = AppController.shared
        if swapRect.contains(p) { ctrl.swapColors() }
        else if resetRect.contains(p) { ctrl.resetColors() }
        else if primaryRect.contains(p) { ctrl.colors.primaryIsActive = true }
        else if secondaryRect.contains(p) { ctrl.colors.primaryIsActive = false }
        onChange?()
    }
}

/// Farbrad: Winkel = Farbton, Abstand zur Mitte = Sättigung, Hellwert der aktuellen Farbe bleibt.
/// Linksklick → aktives Feld, Rechtsklick → inaktives Feld (Referenz).
final class ColorWheelView: NSView {
    var current = HSV(h: 0, s: 0, v: 100) { didSet { if current.v != oldValue.v { cachedWheel = nil }; needsDisplay = true } }
    var onPick: ((HSV, Bool) -> Void)?
    private var cachedWheel: NSImage?
    private var dragToInactive = false
    private var dragStart: HSV?

    override init(frame: NSRect) {
        super.init(frame: frame)
        translatesAutoresizingMaskIntoConstraints = false
        widthAnchor.constraint(equalToConstant: 140).isActive = true
        heightAnchor.constraint(equalToConstant: 140).isActive = true
        toolTip = "Farbrad: Klick wählt die aktive Farbe, Rechtsklick die inaktive. ⇧: auf Speichen einrasten (15°)."
    }
    required init?(coder: NSCoder) { fatalError("nicht verwendet") }

    private var radius: CGFloat { min(bounds.width, bounds.height) / 2 - 2 }
    private var center: NSPoint { NSPoint(x: bounds.midX, y: bounds.midY) }

    private func wheelImage() -> NSImage {
        if let c = cachedWheel { return c }
        let n = Int(radius * 2)
        let v = max(current.v, 0)
        var bytes = [UInt8](repeating: 0, count: n * n * 4)
        let r = Double(n) / 2
        for y in 0..<n {
            for x in 0..<n {
                let dx = Double(x) + 0.5 - r, dy = r - (Double(y) + 0.5)
                let d = (dx * dx + dy * dy).squareRoot()
                guard d <= r else { continue }
                var h = atan2(dy, dx) * 180 / .pi
                if h < 0 { h += 360 }
                let c = HSV(h: h, s: d / r * 100, v: v).color()
                let o = (y * n + x) * 4
                bytes[o] = c.b; bytes[o + 1] = c.g; bytes[o + 2] = c.r; bytes[o + 3] = 255
            }
        }
        let img = ImageRendering.cgImage(premultipliedBGRA: bytes, width: n, height: n).map { NSImage(cgImage: $0, size: NSSize(width: n, height: n)) } ?? NSImage()
        cachedWheel = img
        return img
    }

    override func draw(_ dirtyRect: NSRect) {
        let rr = radius
        let rect = NSRect(x: center.x - rr, y: center.y - rr, width: rr * 2, height: rr * 2)
        wheelImage().draw(in: rect)
        NSColor.separatorColor.setStroke()
        NSBezierPath(ovalIn: rect).stroke()
        // Markierung der aktuellen Farbe
        let a = current.h * .pi / 180, d = CGFloat(current.s / 100) * rr
        let p = NSPoint(x: center.x + cos(a) * d, y: center.y + sin(a) * d)
        let ring = NSBezierPath(ovalIn: NSRect(x: p.x - 5, y: p.y - 5, width: 10, height: 10))
        ring.lineWidth = 2
        NSColor.white.setStroke(); ring.stroke()
        let inner = NSBezierPath(ovalIn: NSRect(x: p.x - 4, y: p.y - 4, width: 8, height: 8))
        NSColor.black.setStroke(); inner.stroke()
    }

    private func hsv(at e: NSEvent) -> HSV {
        let p = convert(e.locationInWindow, from: nil)
        let dx = Double(p.x - center.x), dy = Double(p.y - center.y)
        var h = atan2(dy, dx) * 180 / .pi
        if h < 0 { h += 360 }
        var s = min(1, (dx * dx + dy * dy).squareRoot() / Double(radius)) * 100
        let m = e.modifierFlags
        if m.contains(.shift) { h = (h / 15).rounded() * 15 }          // Speichen
        if m.contains(.control), let st = dragStart { s = st.s }          // gleicher Radius
        if m.contains(.option), let st = dragStart { h = st.h }           // eine Speiche
        return HSV(h: h.truncatingRemainder(dividingBy: 360), s: s, v: current.v)
    }

    override func mouseDown(with e: NSEvent) { dragToInactive = false; dragStart = current; onPick?(hsv(at: e), false) }
    override func mouseDragged(with e: NSEvent) { onPick?(hsv(at: e), dragToInactive) }
    override func rightMouseDown(with e: NSEvent) { dragToInactive = true; dragStart = current; onPick?(hsv(at: e), true) }
    override func rightMouseDragged(with e: NSEvent) { onPick?(hsv(at: e), true) }
    override func menu(for event: NSEvent) -> NSMenu? { nil }
}

/// Palette: Linksklick → aktives Feld, Rechtsklick → inaktives. Klein: 32 Farben, erweitert: 96.
final class PaletteView: NSView {
    var colors = DefaultPalette.colors
    var showAll = false { didSet { invalidateIntrinsicContentSize(); needsDisplay = true } }
    var onPick: ((ColorBgra, Bool) -> Void)?
    private let cell: CGFloat = 13
    private let perRow = 16

    override var isFlipped: Bool { true }
    override var intrinsicContentSize: NSSize {
        let n = showAll ? colors.count : min(32, colors.count)
        return NSSize(width: CGFloat(perRow) * cell + 1, height: CGFloat((n + perRow - 1) / perRow) * cell + 1)
    }

    override func draw(_ dirtyRect: NSRect) {
        let n = showAll ? colors.count : min(32, colors.count)
        for i in 0..<n {
            let r = rect(i)
            colors[i].nsColor.setFill(); r.fill()
            NSColor.separatorColor.setStroke(); NSBezierPath(rect: r.insetBy(dx: 0.5, dy: 0.5)).stroke()
        }
    }

    private func rect(_ i: Int) -> NSRect {
        NSRect(x: CGFloat(i % perRow) * cell, y: CGFloat(i / perRow) * cell, width: cell, height: cell)
    }

    private func index(at e: NSEvent) -> Int? {
        let p = convert(e.locationInWindow, from: nil)
        let i = Int(p.y / cell) * perRow + Int(p.x / cell)
        let n = showAll ? colors.count : min(32, colors.count)
        return p.x >= 0 && p.y >= 0 && Int(p.x / cell) < perRow && i < n ? i : nil
    }

    override func mouseDown(with e: NSEvent) { if let i = index(at: e) { onPick?(colors[i], false) } }
    override func rightMouseDown(with e: NSEvent) { if let i = index(at: e) { onPick?(colors[i], true) } }
    override func menu(for event: NSEvent) -> NSMenu? { nil }
}
