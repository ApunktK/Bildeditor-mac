// Maßeinheiten (Ansicht › Pixel / Zoll / Zentimeter) und Umrechnung für die Dialoge
// „Neues Bild“, „Bildgröße ändern“ und „Leinwandgröße“.

public enum MeasurementUnit: String, CaseIterable, Sendable, Codable {
    case pixels, inches, centimeters

    public var shortName: String {
        switch self { case .pixels: return "px"; case .inches: return "in"; case .centimeters: return "cm" }
    }
}

/// Auflösungsangabe wie in Paint.NET: Pixel pro Zoll oder Pixel pro Zentimeter.
public enum ResolutionUnit: String, CaseIterable, Sendable, Codable {
    case pixelsPerInch, pixelsPerCentimeter
}

public enum UnitConversion {
    public static let cmPerInch = 2.54

    /// Pixel → Maß in Einheit (Auflösung immer in Pixel pro Zoll).
    public static func length(pixels: Int, dpi: Double, unit: MeasurementUnit) -> Double {
        switch unit {
        case .pixels: return Double(pixels)
        case .inches: return Double(pixels) / dpi
        case .centimeters: return Double(pixels) / dpi * cmPerInch
        }
    }

    /// Maß in Einheit → Pixel (gerundet).
    public static func pixels(length: Double, dpi: Double, unit: MeasurementUnit) -> Int {
        switch unit {
        case .pixels: return Int(length.rounded())
        case .inches: return Int((length * dpi).rounded())
        case .centimeters: return Int((length / cmPerInch * dpi).rounded())
        }
    }

    public static func dpi(fromResolution value: Double, unit: ResolutionUnit) -> Double {
        unit == .pixelsPerInch ? value : value * cmPerInch
    }

    public static func resolution(fromDpi dpi: Double, unit: ResolutionUnit) -> Double {
        unit == .pixelsPerInch ? dpi : dpi / cmPerInch
    }
}

/// Berechnung im Dialog „Neues Bild“ (Pixelgröße ↔ Druckgröße, Seitenverhältnis, Speicherbedarf).
public struct NewImageParameters: Equatable, Sendable {
    /// Obergrenze je Kante. Der Referenzwert ist nicht dokumentiert (KNOWN_ISSUES R-1);
    /// 65535 entspricht der größten von gängigen Formaten (AVIF/PDN) speicherbaren Kante.
    public static let maxDimension = 65535

    public var width: Int
    public var height: Int
    public var dpi: Double
    public var keepAspectRatio: Bool

    public init(width: Int, height: Int, dpi: Double, keepAspectRatio: Bool = true) {
        self.width = width; self.height = height; self.dpi = dpi; self.keepAspectRatio = keepAspectRatio
    }

    /// Geschätzter Speicherbedarf einer Ebene in Byte (4 Byte je Pixel).
    public var estimatedBytes: Int64 { Int64(width) * Int64(height) * 4 }

    public mutating func setWidth(_ w: Int) {
        if keepAspectRatio, width > 0 { height = max(1, Int((Double(w) * Double(height) / Double(width)).rounded())) }
        width = w
    }

    public mutating func setHeight(_ h: Int) {
        if keepAspectRatio, height > 0 { width = max(1, Int((Double(h) * Double(width) / Double(height)).rounded())) }
        height = h
    }

    public enum ValidationError: Error, Equatable {
        case notPositive, tooLarge(max: Int), invalidResolution
    }

    public func validate() -> ValidationError? {
        if width < 1 || height < 1 { return .notPositive }
        if width > Self.maxDimension || height > Self.maxDimension { return .tooLarge(max: Self.maxDimension) }
        if !(dpi > 0 && dpi.isFinite) { return .invalidResolution }
        return nil
    }
}

/// Byte-Angabe auf Deutsch, z. B. „1,8 MB“.
public func formattedByteCount(_ bytes: Int64) -> String {
    let units = ["Byte", "KB", "MB", "GB", "TB"]
    var v = Double(bytes), i = 0
    while v >= 1024 && i < units.count - 1 { v /= 1024; i += 1 }
    if i == 0 { return "\(bytes) Byte" }
    let rounded = (v * 10).rounded() / 10
    var s = String(rounded)
    if s.hasSuffix(".0") { s.removeLast(2) }
    return String(s.map { $0 == "." ? "," : $0 }) + " " + units[i]
}
