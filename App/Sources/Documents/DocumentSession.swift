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
    private var cachedThumbnail: NSImage?
    private var token: UUID?

    init(document: Document) {
        self.document = document
        token = document.observe { [weak self] change in
            guard let self else { return }
            switch change {
            case .content, .layers, .size: self.cachedComposite = nil; self.cachedThumbnail = nil
            default: break
            }
            NotificationCenter.default.post(name: .documentChanged, object: self, userInfo: ["change": change])
        }
    }

    deinit { if let token { document.removeObserver(token) } }

    var title: String { document.displayName }

    /// Komposit für die Anzeige (zwischengespeichert bis zur nächsten Änderung).
    var composite: CGImage? {
        if cachedComposite == nil { cachedComposite = ImageRendering.composite(document.state) }
        return cachedComposite
    }

    var thumbnail: NSImage {
        if let t = cachedThumbnail { return t }
        let t = ImageRendering.thumbnail(of: document.state, maxSide: 96)
        cachedThumbnail = t
        return t
    }
}
