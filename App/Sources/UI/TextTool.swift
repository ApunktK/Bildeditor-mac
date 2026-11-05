import AppKit
import EditorCore
import EditorDocument

/// Textwerkzeug: Klick setzt die Einfügemarke, Tippen schreibt (Live-Vorschau), Zeilenumbruch mit der Eingabetaste.
/// Fertigstellen (ein Verlaufsschritt) bei Esc, Klick an andere Stelle, Werkzeugwechsel oder einem anderen Befehl.
final class TextInteraction {
    private(set) var text = ""
    private(set) var origin: PixelPoint?
    private var base: DocumentState?
    private var color = ColorBgra.black
    var onChange: (() -> Void)?

    private var ctrl: AppController { .shared }
    var isEditing: Bool { origin != nil }

    /// Begrenzungsrechteck des aktuellen Textes (Bildpixel) für Rahmen und Einfügemarke.
    private(set) var textRect: PixelRect?

    func click(at p: CGPoint, right: Bool) {
        commit()
        guard let d = ctrl.document else { return }
        d.settlePreview()
        base = d.state
        origin = PixelPoint(Int(p.x.rounded(.down)), Int(p.y.rounded(.down)))
        color = right ? ctrl.colors.secondary : ctrl.colors.primary
        text = ""
        update()
    }

    /// Tastendruck während der Bearbeitung. Rückgabe: verarbeitet.
    func handleKey(_ e: NSEvent) -> Bool {
        guard isEditing else { return false }
        let mods = e.modifierFlags.intersection(.deviceIndependentFlagsMask).subtracting([.capsLock, .numericPad, .function, .shift])
        if mods.contains(.command) || mods.contains(.control) { return false }
        switch Int(e.keyCode) {
        case 53: commit(); return true                       // Esc
        case 51: if !text.isEmpty { text.removeLast(); update() }; return true   // ⌫
        case 36, 76: text.append("\n"); update(); return true  // Eingabe: neue Zeile
        default: break
        }
        guard let ch = e.characters, !ch.isEmpty, ch.unicodeScalars.allSatisfy({ $0.value >= 32 && $0.value != 127 && !(0xF700...0xF8FF).contains($0.value) }) else {
            return true
        }
        text.append(ch)
        update()
        return true
    }

    /// Für den Selbsttest und das Einfügen: Text direkt anhängen.
    func type(_ s: String) { guard isEditing else { return }; text.append(s); update() }

    func commit() {
        guard let d = ctrl.document, let b = base, let o = origin else { reset(); return }
        let state = rendered(base: b, origin: o)
        reset()
        if d.isPreviewing { d.endPreview(commitAs: nil) }
        if let s = state, s != d.state { d.commit(s, name: "Text", kind: .paint) }
        onChange?()
    }

    func cancel() {
        guard base != nil else { return }
        reset()
        ctrl.document?.endPreview(commitAs: nil)
        onChange?()
    }

    private func reset() { base = nil; origin = nil; text = ""; textRect = nil }

    /// Optionen geändert (Schrift, Größe …): Vorschau neu.
    func optionsChanged() { if isEditing { update() } }

    private func update() {
        guard let d = ctrl.document, let b = base, let o = origin else { return }
        if let s = rendered(base: b, origin: o) { d.preview(s) } else if d.isPreviewing { d.preview(b) }
        onChange?()
    }

    private func rendered(base b: DocumentState, origin o: PixelPoint) -> DocumentState? {
        let font = ctrl.textFont
        let lineHeight = Int(ceil(font.ascender - font.descender + font.leading))
        guard !text.isEmpty, let img = Self.render(text, font: font, color: color, antialias: ctrl.antialias,
                                                   alignment: ctrl.textAlignment, underline: ctrl.textUnderline) else {
            textRect = PixelRect(x: o.x, y: o.y, width: 1, height: max(1, lineHeight))
            return nil
        }
        textRect = PixelRect(x: o.x, y: o.y, width: img.width, height: img.height)
        return ctrl.document?.stateWithImage(img, at: o, blend: ctrl.paintBlend, base: b)
    }

    /// Text rastern: gerades Alpha in der Textfarbe, Deckung aus der Glyphenform.
    static func render(_ text: String, font: NSFont, color: ColorBgra, antialias: Bool,
                       alignment: NSTextAlignment, underline: Bool) -> TiledSurface? {
        let para = NSMutableParagraphStyle()
        para.alignment = alignment
        var attrs: [NSAttributedString.Key: Any] = [.font: font, .foregroundColor: NSColor.white, .paragraphStyle: para]
        if underline { attrs[.underlineStyle] = NSUnderlineStyle.single.rawValue }
        let str = NSAttributedString(string: text, attributes: attrs)
        let bounds = str.boundingRect(with: NSSize(width: 100_000, height: 100_000), options: [.usesLineFragmentOrigin, .usesFontLeading])
        let w = max(1, Int(ceil(bounds.width)) + 2), h = max(1, Int(ceil(bounds.height)) + 2)
        guard w <= 16384, h <= 16384,
              let ctx = CGContext(data: nil, width: w, height: h, bitsPerComponent: 8, bytesPerRow: w * 4, space: ImageRendering.sRGB,
                                  bitmapInfo: CGImageAlphaInfo.premultipliedFirst.rawValue | CGBitmapInfo.byteOrder32Little.rawValue) else { return nil }
        ctx.setShouldAntialias(antialias)
        ctx.setAllowsFontSmoothing(false)
        let gc = NSGraphicsContext(cgContext: ctx, flipped: false)
        NSGraphicsContext.saveGraphicsState()
        NSGraphicsContext.current = gc
        str.draw(with: NSRect(x: 1, y: 1, width: CGFloat(w - 2), height: CGFloat(h - 2)), options: [.usesLineFragmentOrigin, .usesFontLeading])
        NSGraphicsContext.restoreGraphicsState()
        guard let data = ctx.data else { return nil }
        let p = data.assumingMemoryBound(to: UInt8.self)
        var out = TiledSurface(width: w, height: h)
        // Speicher beginnt mit der obersten Zeile; Deckung = Alpha (weiß vormultipliziert)
        for y in 0..<h {
            for x in 0..<w {
                let a = Int(p[(y * w + x) * 4 + 3])
                if a == 0 { continue }
                out[x, y] = ColorBgra(r: color.r, g: color.g, b: color.b, a: UInt8(a * Int(color.a) / 255))
            }
        }
        return out
    }
}
