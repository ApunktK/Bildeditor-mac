import AppKit
import EditorCore

/// Statusleiste: Hinweis, Bildgröße, Mausposition, Maßeinheit, Zoomfeld, Schnellgröße, Zoomregler.
final class StatusBarView: NSView, NSTextFieldDelegate {
    private let hint = NSTextField(labelWithString: "")
    private let sizeLabel = NSTextField(labelWithString: "")
    private let posLabel = NSTextField(labelWithString: "")
    private let selLabel = NSTextField(labelWithString: "")
    private var lastSelection: PixelSize?
    private let unitPopup = NSPopUpButton(frame: .zero, pullsDown: false)
    let zoomField = NSTextField(string: "100 %")
    private let quickSize = NSButton()
    let zoomSlider = NSSlider(value: 0.5, minValue: 0, maxValue: 1, target: nil, action: nil)
    private let zoomOutButton = NSButton()
    private let zoomInButton = NSButton()
    private var lastPointer: PixelPoint?

    static let number: NumberFormatter = {
        let f = NumberFormatter()
        f.locale = Locale(identifier: "de_DE")
        f.numberStyle = .decimal
        f.maximumFractionDigits = 2
        f.minimumFractionDigits = 0
        f.usesGroupingSeparator = false
        return f
    }()

    override init(frame: NSRect) {
        super.init(frame: frame)
        for l in [hint, sizeLabel, posLabel, selLabel] { l.font = .systemFont(ofSize: 11); l.lineBreakMode = .byTruncatingTail }
        hint.textColor = .secondaryLabelColor
        hint.setContentCompressionResistancePriority(NSLayoutConstraint.Priority(200), for: .horizontal)
        hint.setContentHuggingPriority(.required, for: .horizontal)
        sizeLabel.toolTip = "Bildgröße"
        posLabel.toolTip = "Mausposition (von links oben)"
        selLabel.toolTip = "Größe der Auswahl"

        unitPopup.controlSize = .small
        unitPopup.font = .systemFont(ofSize: 11)
        for (u, t) in [(MeasurementUnit.pixels, "Pixel"), (.inches, "Zoll"), (.centimeters, "Zentimeter")] {
            unitPopup.addItem(withTitle: t); unitPopup.lastItem?.representedObject = u.rawValue
        }
        unitPopup.target = self; unitPopup.action = #selector(unitPicked)
        unitPopup.toolTip = "Maßeinheit"

        zoomField.controlSize = .small
        zoomField.font = .monospacedDigitSystemFont(ofSize: 11, weight: .regular)
        zoomField.alignment = .right
        zoomField.delegate = self
        zoomField.target = self; zoomField.action = #selector(zoomEntered)
        zoomField.toolTip = "Zoom in Prozent – Wert eingeben und Eingabetaste drücken"

        func iconButton(_ b: NSButton, _ symbol: String, _ tip: String, _ sel: Selector) {
            b.image = NSImage(systemSymbolName: symbol, accessibilityDescription: tip)
            b.bezelStyle = .recessed; b.isBordered = true; b.showsBorderOnlyWhileMouseInside = true
            b.imagePosition = .imageOnly; b.toolTip = tip; b.target = self; b.action = sel
            b.controlSize = .small
        }
        iconButton(quickSize, "arrow.up.left.and.arrow.down.right", "Schnellgröße: zwischen 100 % und „An Fenster anpassen“ wechseln", #selector(quickSizeClicked))
        iconButton(zoomOutButton, "minus.magnifyingglass", "Verkleinern (⌘−)", #selector(zoomOutClicked))
        iconButton(zoomInButton, "plus.magnifyingglass", "Vergrößern (⌘+)", #selector(zoomInClicked))

        zoomSlider.controlSize = .small
        zoomSlider.target = self; zoomSlider.action = #selector(sliderMoved)
        zoomSlider.isContinuous = true
        zoomSlider.toolTip = "Zoom"

        let sizeIcon = NSImageView(image: NSImage(systemSymbolName: "photo", accessibilityDescription: "Bildgröße") ?? NSImage())
        let posIcon = NSImageView(image: NSImage(systemSymbolName: "cursorarrow", accessibilityDescription: "Mausposition") ?? NSImage())
        let selIcon = NSImageView(image: NSImage(systemSymbolName: "rectangle.dashed", accessibilityDescription: "Auswahlgröße") ?? NSImage())
        for i in [sizeIcon, posIcon, selIcon] { i.contentTintColor = .secondaryLabelColor; i.symbolConfiguration = .init(pointSize: 11, weight: .regular) }

        let right = NSStackView()
        right.distribution = .gravityAreas
        right.setViews([sizeIcon, sizeLabel, posIcon, posLabel, selIcon, selLabel, unitPopup, zoomField, quickSize, zoomOutButton, zoomSlider, zoomInButton], in: .trailing)
        right.orientation = .horizontal
        right.spacing = 6
        // Schmale Fenster: weniger wichtige Angaben werden ausgeblendet statt das Fenster zu verbreitern.
        right.setClippingResistancePriority(.defaultLow, for: .horizontal)
        for (v, p) in [(selIcon, 400), (selLabel, 400), (posIcon, 500), (posLabel, 500), (zoomSlider, 600), (unitPopup, 700)] as [(NSView, Float)] {
            right.setVisibilityPriority(NSStackView.VisibilityPriority(rawValue: p), for: v)
        }
        right.setCustomSpacing(16, after: sizeLabel)
        right.setCustomSpacing(16, after: posLabel)
        right.setCustomSpacing(16, after: selLabel)
        right.setCustomSpacing(14, after: unitPopup)
        for v in [hint, right] as [NSView] { v.translatesAutoresizingMaskIntoConstraints = false; addSubview(v) }
        NSLayoutConstraint.activate([
            hint.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 10),
            hint.centerYAnchor.constraint(equalTo: centerYAnchor),
            right.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -8),
            right.centerYAnchor.constraint(equalTo: centerYAnchor),
            right.leadingAnchor.constraint(equalTo: hint.trailingAnchor, constant: 12),
            sizeLabel.widthAnchor.constraint(greaterThanOrEqualToConstant: 90),
            posLabel.widthAnchor.constraint(greaterThanOrEqualToConstant: 80),
            selLabel.widthAnchor.constraint(greaterThanOrEqualToConstant: 80),
            zoomField.widthAnchor.constraint(equalToConstant: 64),
            zoomSlider.widthAnchor.constraint(equalToConstant: 120),
        ])
        refresh()
    }

    required init?(coder: NSCoder) { fatalError("nicht verwendet") }

    // MARK: Anzeige

    func setHint(_ s: String) { hint.stringValue = s }

    func format(_ px: Int, dpi: Double, unit: MeasurementUnit) -> String {
        if unit == .pixels { return String(px) }
        return Self.number.string(from: NSNumber(value: UnitConversion.length(pixels: px, dpi: dpi, unit: unit))) ?? "?"
    }

    func refresh() {
        let ctrl = AppController.shared
        let unit = ctrl.unit
        if let i = unitPopup.itemArray.firstIndex(where: { ($0.representedObject as? String) == unit.rawValue }) { unitPopup.selectItem(at: i) }
        let hasDoc = ctrl.active != nil
        for c in [zoomField, quickSize, zoomSlider, zoomInButton, zoomOutButton] as [NSControl] { c.isEnabled = hasDoc }
        if let s = ctrl.active {
            let d = s.document
            sizeLabel.stringValue = "\(format(d.size.width, dpi: d.state.dpi, unit: unit)) × \(format(d.size.height, dpi: d.state.dpi, unit: unit)) \(unit.shortName)"
            if zoomField.currentEditor() == nil { zoomField.stringValue = Self.zoomText(s.zoom) }
            zoomSlider.doubleValue = Self.sliderValue(forZoom: s.zoom)
        } else {
            sizeLabel.stringValue = "–"
            zoomField.stringValue = ""
        }
        setPointer(lastPointer)
        setSelectionSize(ctrl.document?.floating?.rect.size ?? ctrl.document?.selectionBounds?.size)
    }

    func setSelectionSize(_ s: PixelSize?) {
        lastSelection = s
        let ctrl = AppController.shared
        guard let s, let d = ctrl.document else { selLabel.stringValue = "–"; return }
        let u = ctrl.unit
        selLabel.stringValue = "\(format(s.width, dpi: d.state.dpi, unit: u)) × \(format(s.height, dpi: d.state.dpi, unit: u)) \(u.shortName)"
    }

    var displayedSelection: String { selLabel.stringValue }

    func setPointer(_ p: PixelPoint?) {
        lastPointer = p
        let ctrl = AppController.shared
        guard let p, let d = ctrl.document else { posLabel.stringValue = "–"; return }
        let u = ctrl.unit
        posLabel.stringValue = "\(format(p.x, dpi: d.state.dpi, unit: u)), \(format(p.y, dpi: d.state.dpi, unit: u)) \(u.shortName)"
    }

    var displayedSize: String { sizeLabel.stringValue }
    var displayedPointer: String { posLabel.stringValue }

    static func zoomText(_ z: Double) -> String {
        (number.string(from: NSNumber(value: (z * 100).rounded() / 100)) ?? "\(z)") + " %"
    }

    /// Logarithmischer Regler von 1 % bis 6400 %.
    static func sliderValue(forZoom z: Double) -> Double {
        let lo = log(ZoomLevels.minimum), hi = log(ZoomLevels.maximum)
        return (log(ZoomLevels.clamp(z)) - lo) / (hi - lo)
    }
    static func zoom(forSlider v: Double) -> Double {
        let lo = log(ZoomLevels.minimum), hi = log(ZoomLevels.maximum)
        return exp(lo + v * (hi - lo))
    }

    /// „150“, „150 %“, „150,5“ → Prozentwert.
    static func parseZoom(_ s: String) -> Double? {
        let t = s.replacingOccurrences(of: "%", with: "").trimmingCharacters(in: .whitespaces)
        if let n = number.number(from: t) { return n.doubleValue }
        return Double(t.replacingOccurrences(of: ",", with: "."))
    }

    // MARK: Aktionen

    private var canvas: CanvasController? { AppController.shared.mainWindow?.canvas }

    @objc private func unitPicked() {
        if let raw = unitPopup.selectedItem?.representedObject as? String, let u = MeasurementUnit(rawValue: raw) { AppController.shared.unit = u }
    }

    @objc private func zoomEntered() {
        guard let v = Self.parseZoom(zoomField.stringValue), v > 0 else { NSSound.beep(); refresh(); return }
        canvas?.setZoom(v, anchor: nil)
        window?.makeFirstResponder(canvas?.canvasView)
        refresh()
    }

    @objc private func sliderMoved() {
        // Regler rastet in der Nähe fester Stufen ein, damit 100 % leicht zu treffen ist.
        var z = Self.zoom(forSlider: zoomSlider.doubleValue)
        if let snap = ZoomLevels.presets.min(by: { abs(log($0) - log(z)) < abs(log($1) - log(z)) }), abs(log(snap) - log(z)) < 0.04 { z = snap }
        canvas?.setZoom(z, anchor: nil)
    }

    @objc private func quickSizeClicked() {
        guard let s = AppController.shared.active else { return }
        if abs(s.zoom - 100) < 0.01 { canvas?.zoomToFit() } else { canvas?.setZoom(100, anchor: nil) }
    }

    @objc private func zoomOutClicked() { canvas?.zoomStep(-1) }
    @objc private func zoomInClicked() { canvas?.zoomStep(+1) }
}
