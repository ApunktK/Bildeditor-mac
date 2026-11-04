import AppKit
import EditorCore

/// Dauerhafte Einstellungen (UserDefaults). Schlüssel sind stabil, damit spätere Versionen sie weiterlesen.
final class Settings {
    static let shared = Settings()
    private let d = UserDefaults.standard

    private enum Key {
        static let unit = "Ansicht.Einheit"
        static let pixelGrid = "Ansicht.Pixelraster"
        static let recent = "Datei.ZuletztGeoeffnet"
        static let newWidth = "NeuesBild.Breite"
        static let newHeight = "NeuesBild.Hoehe"
        static let newDpi = "NeuesBild.DPI"
        static let newKeepRatio = "NeuesBild.Seitenverhaeltnis"
        static let newResUnit = "NeuesBild.Aufloesungseinheit"
        static let jpegQuality = "Speichern.JPEGQualitaet"
        static let primary = "Farben.Primaer"
        static let secondary = "Farben.Sekundaer"
        static let colorsExpanded = "Farben.Erweitert"
    }

    static let maxRecent = 10   // Referenz: 10 Einträge

    var measurementUnit: MeasurementUnit {
        get { MeasurementUnit(rawValue: d.string(forKey: Key.unit) ?? "") ?? .pixels }
        set { d.set(newValue.rawValue, forKey: Key.unit) }
    }

    var showPixelGrid: Bool {
        get { d.bool(forKey: Key.pixelGrid) }
        set { d.set(newValue, forKey: Key.pixelGrid) }
    }

    var recentFiles: [URL] {
        get { (d.stringArray(forKey: Key.recent) ?? []).map { URL(fileURLWithPath: $0) } }
        set { d.set(Array(newValue.prefix(Self.maxRecent)).map(\.path), forKey: Key.recent) }
    }

    func noteRecent(_ url: URL) {
        var list = recentFiles.filter { $0.standardizedFileURL != url.standardizedFileURL }
        list.insert(url, at: 0)
        recentFiles = list
        NSDocumentController.shared.noteNewRecentDocumentURL(url)   // auch für Dock-Menü
    }

    /// Zuletzt im Dialog „Neues Bild“ verwendete Werte (Referenz: Dialog merkt sich die Werte).
    var lastNewImage: NewImageParameters {
        get {
            let w = d.integer(forKey: Key.newWidth), h = d.integer(forKey: Key.newHeight)
            let dpi = d.double(forKey: Key.newDpi)
            let keep = d.object(forKey: Key.newKeepRatio) as? Bool ?? true
            return NewImageParameters(width: w > 0 ? w : 800, height: h > 0 ? h : 600, dpi: dpi > 0 ? dpi : 96, keepAspectRatio: keep)
        }
        set {
            d.set(newValue.width, forKey: Key.newWidth); d.set(newValue.height, forKey: Key.newHeight)
            d.set(newValue.dpi, forKey: Key.newDpi); d.set(newValue.keepAspectRatio, forKey: Key.newKeepRatio)
        }
    }

    var newImageResolutionUnit: ResolutionUnit {
        get { ResolutionUnit(rawValue: d.string(forKey: Key.newResUnit) ?? "") ?? .pixelsPerInch }
        set { d.set(newValue.rawValue, forKey: Key.newResUnit) }
    }

    /// JPEG-Qualität 1…100.
    var jpegQuality: Int {
        get { let q = d.integer(forKey: Key.jpegQuality); return q > 0 ? min(q, 100) : 95 }
        set { d.set(min(max(newValue, 1), 100), forKey: Key.jpegQuality) }
    }

    var primaryColor: ColorBgra {
        get { d.string(forKey: Key.primary).flatMap { ColorBgra(hex: $0) } ?? .black }
        set { d.set(newValue.hexString, forKey: Key.primary) }
    }

    var secondaryColor: ColorBgra {
        get { d.string(forKey: Key.secondary).flatMap { ColorBgra(hex: $0) } ?? .white }
        set { d.set(newValue.hexString, forKey: Key.secondary) }
    }

    var colorsExpanded: Bool {
        get { d.bool(forKey: Key.colorsExpanded) }
        set { d.set(newValue, forKey: Key.colorsExpanded) }
    }

    // Sichtbarkeit der Fenster (Werkzeuge, Verlauf, Ebenen, Farben)
    func panelVisible(_ id: String) -> Bool { d.object(forKey: "Fenster.\(id).sichtbar") as? Bool ?? true }
    func setPanelVisible(_ id: String, _ v: Bool) { d.set(v, forKey: "Fenster.\(id).sichtbar") }
}
