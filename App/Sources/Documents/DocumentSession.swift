import AppKit
import EditorCore
import EditorDocument

extension Notification.Name {
    /// Inhalt/Ebenen/Verlauf eines Bildes geändert. `object` = DocumentSession, userInfo["change"] = Document.Change.
    static let documentChanged = Notification.Name("Bildeditor.documentChanged")
    /// Liste der geöffneten Bilder oder aktives Bild geändert.
    static let documentsChanged = Notification.Name("Bildeditor.documentsChanged")
    /// Zoom, Pixelraster oder Einheit geändert.
    static let viewSettingsChanged = Notification.Name("Bildeditor.viewSettingsChanged")
    static let toolChanged = Notification.Name("Bildeditor.toolChanged")
    static let paletteChanged = Notification.Name("Bildeditor.paletteChanged")
    static let panelVisibilityChanged = Notification.Name("Bildeditor.panelVisibilityChanged")
}

/// Ein geöffnetes Bild samt Ansichtszustand (Zoom, Bildlaufposition) und Anzeige-Zwischenspeicher.
final class DocumentSession {
    let document: Document
    /// Zoom in Prozent.
    var zoom: Double = 100
    /// Bildmittelpunkt der Ansicht in Bildpixeln, um beim Registerwechsel die Position wiederherzustellen.
    var viewCenter: CGPoint?
    /// Beim ersten Anzeigen an das Fenster anpassen.
    var needsInitialFit = true

    private var cachedComposite: CGImage?
    private var compositeDirty = true
    /// Vormultiplizierter Gesamtpuffer und die Ebenen, die er zeigt – für kachelweise Aktualisierung.
    private var compositeBytes: [UInt8] = []
    private var compositeLayers: [Layer] = []
    private var compositeSize = PixelSize(0, 0)
    private var cachedThumbnail: NSImage?
    private var token: UUID?

    init(document: Document) {
        self.document = document
        token = document.observe { [weak self] change in
            guard let self else { return }
            switch change {
            case .content, .layers, .size: self.compositeDirty = true; self.cachedThumbnail = nil; self.cachedOutline = nil
            case .selection: self.cachedOutline = nil
            default: break
            }
            NotificationCenter.default.post(name: .documentChanged, object: self, userInfo: ["change": change])
        }
    }

    deinit { if let token { document.removeObserver(token) } }

    var title: String { document.displayName }

    /// Komposit für die Anzeige (zwischengespeichert bis zur nächsten Änderung).
    var composite: CGImage? {
        guard compositeDirty || cachedComposite == nil else { return cachedComposite }
        let st = document.state
        compositeDirty = false
        if compositeSize == st.size, !compositeBytes.isEmpty,
           let r = Compositor.changedRect(old: compositeLayers, new: st.layers, size: st.size) {
            // Nur die geänderten Kacheln neu zusammensetzen (Malen, Verschieben, Füllen …)
            if !r.isEmpty { Compositor.updatePremultiplied(&compositeBytes, layers: st.layers, size: st.size, rect: r) }
            else if cachedComposite != nil { compositeLayers = st.layers; return cachedComposite }
        } else {
            compositeBytes = Compositor.premultipliedBGRA(st.layers, size: st.size)
            compositeSize = st.size
        }
        compositeLayers = st.layers
        cachedComposite = ImageRendering.cgImage(premultipliedBGRA: compositeBytes, width: st.size.width, height: st.size.height)
        return cachedComposite
    }

    // MARK: Auswahl-Anzeige

    struct SelectionGraphics {
        /// Kontur in Bildkoordinaten (Pixelkanten).
        let path: CGPath
        /// Maske der Auswahl im Begrenzungsrechteck (für die blaue Tönung).
        let tint: CGImage?
        let bounds: PixelRect
    }

    private var cachedOutline: SelectionGraphics??
    private var cachedFloatingKey: TiledSurface?
    private var cachedFloating: (image: CGImage?, outline: SelectionGraphics)?

    /// Kontur und Tönung der aktuellen Auswahl (nil ohne Auswahl).
    var selectionGraphics: SelectionGraphics? {
        if let c = cachedOutline { return c }
        let g = document.state.selection.flatMap { SelectionRendering.graphics(for: $0) }
        cachedOutline = .some(g)
        return g
    }

    /// Bild und Kontur der schwebenden Pixel (Kontur relativ zur linken oberen Ecke des Stücks).
    var floatingGraphics: (image: CGImage?, outline: SelectionGraphics)? {
        guard let f = document.floating else { cachedFloating = nil; cachedFloatingKey = nil; return nil }
        if let c = cachedFloating, cachedFloatingKey == f.pixels { return c }
        guard let outline = SelectionRendering.graphics(for: f.shape) else { return nil }
        var bytes = f.pixels.bgraBytes()
        Compositor.premultiplyInPlace(&bytes)
        let img = ImageRendering.cgImage(premultipliedBGRA: bytes, width: f.pixels.width, height: f.pixels.height)
        cachedFloating = (img, outline)
        cachedFloatingKey = f.pixels
        return cachedFloating
    }

    var thumbnail: NSImage {
        if let t = cachedThumbnail { return t }
        let t = ImageRendering.thumbnail(of: document.state, maxSide: 96)
        cachedThumbnail = t
        return t
    }
}
