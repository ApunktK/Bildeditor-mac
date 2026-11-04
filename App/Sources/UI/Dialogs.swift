import AppKit
import EditorCore
import EditorDocument

/// Gemeinsame Hilfen für modale Dialoge.
enum DialogKit {
    static func label(_ s: String) -> NSTextField {
        let l = NSTextField(labelWithString: s)
        l.alignment = .right
        return l
    }

    static func numberField(_ width: CGFloat = 80) -> NSTextField {
        let f = NSTextField(string: "")
        f.alignment = .right
        f.font = .monospacedDigitSystemFont(ofSize: NSFont.systemFontSize, weight: .regular)
        f.widthAnchor.constraint(equalToConstant: width).isActive = true
        return f
    }

    static func makePanel(title: String, content: NSView, okTitle: String, target: AnyObject, ok: Selector, cancel: Selector) -> (NSPanel, NSButton) {
        let okButton = NSButton(title: okTitle, target: target, action: ok)
        okButton.keyEquivalent = "\r"
        let cancelButton = NSButton(title: "Abbrechen", target: target, action: cancel)
        cancelButton.keyEquivalent = "\u{1b}"
        let buttons = NSStackView(views: [cancelButton, okButton])
        buttons.orientation = .horizontal
        let root = NSStackView(views: [content, buttons])
        root.orientation = .vertical
        root.alignment = .trailing
        root.spacing = 16
        root.edgeInsets = NSEdgeInsets(top: 18, left: 20, bottom: 18, right: 20)
        let panel = NSPanel(contentRect: NSRect(x: 0, y: 0, width: 400, height: 300), styleMask: [.titled], backing: .buffered, defer: false)
        panel.title = title
        panel.contentView = root
        panel.setContentSize(root.fittingSize)
        panel.isReleasedWhenClosed = false
        return (panel, okButton)
    }

    static func intValue(_ f: NSTextField) -> Int? {
        Int(f.stringValue.trimmingCharacters(in: .whitespaces).replacingOccurrences(of: ".", with: ""))
    }

    static func doubleValue(_ f: NSTextField) -> Double? {
        StatusBarView.number.number(from: f.stringValue.trimmingCharacters(in: .whitespaces))?.doubleValue
            ?? Double(f.stringValue.replacingOccurrences(of: ",", with: "."))
    }

    static func format(_ v: Double) -> String { StatusBarView.number.string(from: NSNumber(value: v)) ?? "\(v)" }
}

// MARK: Neues Bild

/// Dialog „Neues Bild“: Pixelgröße, Seitenverhältnis, Auflösung, Druckgröße, Speicherbedarf.
final class NewImageDialog: NSObject, NSTextFieldDelegate {
    private(set) var params = Settings.shared.lastNewImage
    private var resUnit = Settings.shared.newImageResolutionUnit
    let widthField = DialogKit.numberField()
    let heightField = DialogKit.numberField()
    let keepRatio = NSButton(checkboxWithTitle: "Seitenverhältnis beibehalten", target: nil, action: nil)
    let resField = DialogKit.numberField()
    let resPopup = NSPopUpButton(frame: .zero, pullsDown: false)
    let printWidth = DialogKit.numberField()
    let printHeight = DialogKit.numberField()
    private let printUnitW = NSTextField(labelWithString: "")
    private let printUnitH = NSTextField(labelWithString: "")
    let sizeLabel = NSTextField(labelWithString: "")
    let errorLabel = NSTextField(labelWithString: "")
    private(set) var panel: NSPanel!
    private var okButton: NSButton!
    private(set) var result: NewImageParameters?

    static func run() {
        let d = NewImageDialog()
        if let p = d.runModal() { AppController.shared.newDocument(p) }
    }

    override init() {
        super.init()
        for f in [widthField, heightField, resField, printWidth, printHeight] { f.delegate = self }
        keepRatio.target = self; keepRatio.action = #selector(ratioToggled)
        resPopup.addItems(withTitles: ["Pixel/Zoll", "Pixel/Zentimeter"])
        resPopup.target = self; resPopup.action = #selector(resUnitChanged)
        errorLabel.textColor = .systemRed
        sizeLabel.textColor = .secondaryLabelColor

        let grid = NSGridView(views: [
            [NSTextField(labelWithString: "Pixelgröße").bold(), NSGridCell.emptyContentView, NSGridCell.emptyContentView],
            [DialogKit.label("Breite:"), widthField, NSTextField(labelWithString: "Pixel")],
            [DialogKit.label("Höhe:"), heightField, NSTextField(labelWithString: "Pixel")],
            [NSGridCell.emptyContentView, keepRatio, NSGridCell.emptyContentView],
            [NSTextField(labelWithString: "Druckgröße").bold(), NSGridCell.emptyContentView, NSGridCell.emptyContentView],
            [DialogKit.label("Auflösung:"), resField, resPopup],
            [DialogKit.label("Breite:"), printWidth, printUnitW],
            [DialogKit.label("Höhe:"), printHeight, printUnitH],
            [NSGridCell.emptyContentView, sizeLabel, NSGridCell.emptyContentView],
            [NSGridCell.emptyContentView, errorLabel, NSGridCell.emptyContentView],
        ])
        grid.rowSpacing = 8
        grid.columnSpacing = 8
        grid.row(at: 4).topPadding = 8
        for r in [0, 4] { grid.row(at: r).mergeCells(in: NSRange(location: 0, length: 3)) }
        for r in [3, 8, 9] { grid.row(at: r).mergeCells(in: NSRange(location: 1, length: 2)) }
        (panel, okButton) = DialogKit.makePanel(title: "Neues Bild", content: grid, okTitle: "OK", target: self,
                                                ok: #selector(okClicked), cancel: #selector(cancelClicked))
        fill(except: nil)
    }

    func runModal() -> NewImageParameters? {
        panel.center()
        NSApp.runModal(for: panel)
        panel.orderOut(nil)
        return result
    }

    private var printUnit: MeasurementUnit { resUnit == .pixelsPerInch ? .inches : .centimeters }

    /// Felder aus `params` füllen, außer dem gerade bearbeiteten.
    func fill(except editing: NSTextField?) {
        if editing !== widthField { widthField.stringValue = String(params.width) }
        if editing !== heightField { heightField.stringValue = String(params.height) }
        keepRatio.state = params.keepAspectRatio ? .on : .off
        resPopup.selectItem(at: resUnit == .pixelsPerInch ? 0 : 1)
        if editing !== resField { resField.stringValue = DialogKit.format(UnitConversion.resolution(fromDpi: params.dpi, unit: resUnit)) }
        if editing !== printWidth { printWidth.stringValue = DialogKit.format(UnitConversion.length(pixels: params.width, dpi: params.dpi, unit: printUnit)) }
        if editing !== printHeight { printHeight.stringValue = DialogKit.format(UnitConversion.length(pixels: params.height, dpi: params.dpi, unit: printUnit)) }
        printUnitW.stringValue = printUnit == .inches ? "Zoll" : "Zentimeter"
        printUnitH.stringValue = printUnitW.stringValue
        sizeLabel.stringValue = "Speicherbedarf: \(formattedByteCount(params.estimatedBytes))"
        validate()
    }

    @discardableResult
    private func validate() -> Bool {
        switch params.validate() {
        case nil: errorLabel.stringValue = ""; okButton?.isEnabled = true; return true
        case .notPositive?: errorLabel.stringValue = "Breite und Höhe müssen mindestens 1 Pixel betragen."
        case let .tooLarge(m)?: errorLabel.stringValue = "Höchstens \(m) Pixel je Seite."
        case .invalidResolution?: errorLabel.stringValue = "Die Auflösung muss größer als 0 sein."
        }
        okButton?.isEnabled = false
        return false
    }

    func controlTextDidChange(_ n: Notification) {
        guard let f = n.object as? NSTextField else { return }
        switch f {
        case widthField: if let v = DialogKit.intValue(f) { params.setWidth(v) } else { params.width = 0 }
        case heightField: if let v = DialogKit.intValue(f) { params.setHeight(v) } else { params.height = 0 }
        case resField:
            if let v = DialogKit.doubleValue(f), v > 0 {
                // Druckgröße bleibt, Pixelzahl folgt (wie übliche Dialoge)
                params.dpi = UnitConversion.dpi(fromResolution: v, unit: resUnit)
            } else { params.dpi = 0 }
        case printWidth: if let v = DialogKit.doubleValue(f) { params.setWidth(UnitConversion.pixels(length: v, dpi: params.dpi, unit: printUnit)) }
        case printHeight: if let v = DialogKit.doubleValue(f) { params.setHeight(UnitConversion.pixels(length: v, dpi: params.dpi, unit: printUnit)) }
        default: break
        }
        fill(except: f)
    }

    @objc private func ratioToggled() { params.keepAspectRatio = keepRatio.state == .on }

    @objc private func resUnitChanged() {
        resUnit = resPopup.indexOfSelectedItem == 0 ? .pixelsPerInch : .pixelsPerCentimeter
        fill(except: nil)
    }

    @objc func okClicked() {
        guard validate() else { NSSound.beep(); return }
        Settings.shared.lastNewImage = params
        Settings.shared.newImageResolutionUnit = resUnit
        result = params
        NSApp.stopModal()
    }

    @objc func cancelClicked() { result = nil; NSApp.stopModal() }
}

// MARK: Ebeneneigenschaften

/// Dialog „Ebeneneigenschaften“: Name, Sichtbar, Mischmodus, Deckkraft – mit Live-Vorschau; Abbrechen stellt zurück.
final class LayerPropertiesDialog: NSObject, NSTextFieldDelegate {
    let doc: Document
    let index: Int
    private let original: Layer.Properties
    let nameField = NSTextField(string: "")
    let visibleBox = NSButton(checkboxWithTitle: "Sichtbar", target: nil, action: nil)
    let blendPopup = NSPopUpButton(frame: .zero, pullsDown: false)
    let opacitySlider = NSSlider(value: 255, minValue: 0, maxValue: 255, target: nil, action: nil)
    let opacityField = DialogKit.numberField(56)
    private(set) var panel: NSPanel!

    static func runForActiveLayer() {
        guard let d = AppController.shared.document else { return }
        LayerPropertiesDialog(doc: d, index: d.activeLayerIndex).runModal()
    }

    init(doc: Document, index: Int) {
        self.doc = doc
        self.index = index
        original = doc.layers[index].properties
        super.init()
        nameField.stringValue = original.name
        nameField.delegate = self
        nameField.widthAnchor.constraint(equalToConstant: 220).isActive = true
        visibleBox.state = original.isVisible ? .on : .off
        visibleBox.target = self; visibleBox.action = #selector(changed)
        for m in BlendMode.allCases { blendPopup.addItem(withTitle: m.displayName); blendPopup.lastItem?.representedObject = m.rawValue }
        blendPopup.selectItem(at: BlendMode.allCases.firstIndex(of: original.blendMode) ?? 0)
        blendPopup.target = self; blendPopup.action = #selector(changed)
        opacitySlider.integerValue = Int(original.opacity)
        opacitySlider.target = self; opacitySlider.action = #selector(sliderMoved)
        opacitySlider.isContinuous = true
        opacitySlider.widthAnchor.constraint(equalToConstant: 160).isActive = true
        opacityField.stringValue = String(original.opacity)
        opacityField.delegate = self
        let opRow = NSStackView(views: [opacitySlider, opacityField])
        opRow.orientation = .horizontal
        let grid = NSGridView(views: [
            [DialogKit.label("Name:"), nameField],
            [NSGridCell.emptyContentView, visibleBox],
            [DialogKit.label("Mischmodus:"), blendPopup],
            [DialogKit.label("Deckkraft:"), opRow],
        ])
        grid.rowSpacing = 10
        grid.columnSpacing = 8
        (panel, _) = DialogKit.makePanel(title: "Ebeneneigenschaften", content: grid, okTitle: "OK", target: self,
                                         ok: #selector(okClicked), cancel: #selector(cancelClicked))
    }

    func runModal() {
        panel.center()
        NSApp.runModal(for: panel)
        panel.orderOut(nil)
    }

    var currentProperties: Layer.Properties {
        let mode = BlendMode(rawValue: blendPopup.selectedItem?.representedObject as? String ?? "") ?? .normal
        let name = nameField.stringValue.trimmingCharacters(in: .whitespaces)
        return Layer.Properties(name: name.isEmpty ? original.name : name, isVisible: visibleBox.state == .on,
                                opacity: UInt8(max(0, min(255, opacitySlider.integerValue))), blendMode: mode)
    }

    @objc func changed() { doc.previewLayerProperties(currentProperties, at: index) }

    @objc private func sliderMoved() {
        opacityField.stringValue = String(opacitySlider.integerValue)
        changed()
    }

    func controlTextDidChange(_ n: Notification) {
        if (n.object as? NSTextField) === opacityField, let v = DialogKit.intValue(opacityField) {
            opacitySlider.integerValue = max(0, min(255, v))
        }
        changed()
    }

    @objc func okClicked() {
        doc.previewLayerProperties(currentProperties, at: index)
        doc.endLayerPropertiesPreview(apply: true, at: index)
        NSApp.stopModal()
    }

    @objc func cancelClicked() {
        doc.endLayerPropertiesPreview(apply: false, at: index)
        NSApp.stopModal()
    }
}

// MARK: Speichern-Zusatz

/// Zusatzfeld im Speichern-Dialog: Dateiformat und (bei JPEG/HEIC) Qualität.
final class SaveAccessoryView: NSView {
    private let formats: [SaveFormat]
    private let popup = NSPopUpButton(frame: .zero, pullsDown: false)
    private let slider = NSSlider(value: 95, minValue: 1, maxValue: 100, target: nil, action: nil)
    private let qualityLabel = NSTextField(labelWithString: "")
    private let qualityRow: NSStackView
    private weak var panel: NSSavePanel?

    var format: SaveFormat { formats[max(0, popup.indexOfSelectedItem)] }
    var quality: Int { slider.integerValue }

    init(formats: [SaveFormat], initial: SaveFormat, quality: Int, panel: NSSavePanel) {
        self.formats = formats
        self.panel = panel
        let qTitle = NSTextField(labelWithString: "Qualität:")
        qualityRow = NSStackView(views: [qTitle, slider, qualityLabel])
        super.init(frame: NSRect(x: 0, y: 0, width: 420, height: 64))
        for f in formats { popup.addItem(withTitle: f.name) }
        popup.selectItem(at: formats.firstIndex(of: initial) ?? 0)
        popup.target = self; popup.action = #selector(formatChanged)
        slider.integerValue = quality
        slider.target = self; slider.action = #selector(qualityChanged)
        slider.widthAnchor.constraint(equalToConstant: 180).isActive = true
        qualityLabel.widthAnchor.constraint(equalToConstant: 40).isActive = true
        let row = NSStackView(views: [NSTextField(labelWithString: "Format:"), popup])
        let stack = NSStackView(views: [row, qualityRow])
        stack.orientation = .vertical
        stack.alignment = .leading
        stack.edgeInsets = NSEdgeInsets(top: 8, left: 12, bottom: 8, right: 12)
        stack.translatesAutoresizingMaskIntoConstraints = false
        addSubview(stack)
        NSLayoutConstraint.activate([
            stack.leadingAnchor.constraint(equalTo: leadingAnchor), stack.trailingAnchor.constraint(equalTo: trailingAnchor),
            stack.topAnchor.constraint(equalTo: topAnchor), stack.bottomAnchor.constraint(equalTo: bottomAnchor),
        ])
        qualityChanged()
        formatChanged()
    }

    required init?(coder: NSCoder) { fatalError("nicht verwendet") }

    @objc private func formatChanged() {
        let f = format
        qualityRow.isHidden = !f.hasQuality
        panel?.allowedContentTypes = [f.type]
        if let p = panel {
            let base = (p.nameFieldStringValue as NSString).deletingPathExtension
            p.nameFieldStringValue = base + "." + f.fileExtension
        }
    }

    @objc private func qualityChanged() { qualityLabel.stringValue = "\(slider.integerValue)" }
}

extension NSTextField {
    func bold() -> NSTextField { font = .boldSystemFont(ofSize: NSFont.systemFontSize); return self }
}
