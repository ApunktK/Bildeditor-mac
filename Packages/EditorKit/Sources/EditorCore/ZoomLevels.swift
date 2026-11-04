// Feste Zoomstufen für Vergrößern/Verkleinern (Ansicht-Menü, Zoom-Werkzeug).
// Stufen ≥ 100 %: laut Referenzdoku (ViewMenu). Stufen < 100 %: Doku nennt „67, 50, 33, 25, 20 …“,
// darunter ungeklärt (KNOWN_ISSUES R-1) – ergänzt um feinere Stufen bis 1 %.

public enum ZoomLevels {
    public static let presets: [Double] = [
        1, 2, 3, 4, 5, 6, 8, 12, 16, 20, 25, 33, 50, 67,
        100, 150, 200, 300, 400, 500, 600, 800, 1000, 1200, 1400, 1600,
        2000, 2400, 2800, 3200, 4000, 4800, 5600, 6400,
    ]
    public static let minimum = presets.first!
    public static let maximum = presets.last!

    /// Nächste größere Stufe (in Prozent); bei Maximum bleibt der Wert.
    public static func zoomIn(from percent: Double) -> Double {
        presets.first { $0 > percent + 0.001 } ?? maximum
    }

    /// Nächste kleinere Stufe.
    public static func zoomOut(from percent: Double) -> Double {
        presets.last { $0 < percent - 0.001 } ?? minimum
    }

    /// Freie Eingabe (Statusleiste) auf erlaubten Bereich begrenzen.
    public static func clamp(_ percent: Double) -> Double {
        guard percent.isFinite else { return 100 }
        return min(max(percent, minimum), maximum)
    }

    /// Zoom, mit dem ein Bild vollständig in einen Bereich passt; nie über 100 % (Referenz: „kleiner → 100 %“).
    public static func fit(image: PixelSize, into width: Double, _ height: Double) -> Double {
        guard image.width > 0, image.height > 0, width > 0, height > 0 else { return 100 }
        let s = min(width / Double(image.width), height / Double(image.height)) * 100
        return min(100, max(minimum, s))
    }
}
