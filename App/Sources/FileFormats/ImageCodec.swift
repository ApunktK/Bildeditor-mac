import Foundation
import ImageIO
import Accelerate
import UniformTypeIdentifiers
import EditorCore

enum ImageCodecError: LocalizedError {
    case unreadable
    case tooLarge(Int, Int)
    case writeFailed
    case unsupportedFormat

    var errorDescription: String? {
        switch self {
        case .unreadable: return "Die Datei ist kein lesbares Bild oder beschädigt."
        case let .tooLarge(w, h): return "Das Bild ist zu groß (\(w) × \(h) Pixel). Höchstens \(NewImageParameters.maxDimension) Pixel je Seite."
        case .writeFailed: return "Das Bild konnte nicht geschrieben werden."
        case .unsupportedFormat: return "Dieses Dateiformat kann nicht gespeichert werden."
        }
    }
}

struct LoadedImage {
    let surface: TiledSurface
    let dpi: Double
    let typeIdentifier: String?
}

/// Ein Format zum Speichern.
struct SaveFormat: Equatable {
    let id: String
    let name: String
    let type: UTType
    let fileExtension: String
    /// Format kann Transparenz speichern (sonst wird auf Weiß reduziert).
    let supportsAlpha: Bool
    /// Format hat einen Qualitätsregler.
    let hasQuality: Bool
}

/// Öffnen und Speichern über ImageIO. Pixel werden als **gerades** Alpha übernommen (vImage),
/// damit halbtransparente Pixel beim Öffnen/Speichern nicht durch Vormultiplikation verfälscht werden.
enum ImageCodec {
    static let defaultDpi = 96.0

    static var readableTypes: [UTType] {
        let ids = (CGImageSourceCopyTypeIdentifiers() as? [String]) ?? []
        return ids.compactMap { UTType($0) }.filter { $0.conforms(to: .image) && $0 != .pdf }
    }

    static let candidateFormats: [SaveFormat] = [
        SaveFormat(id: "png", name: "PNG", type: .png, fileExtension: "png", supportsAlpha: true, hasQuality: false),
        SaveFormat(id: "jpeg", name: "JPEG", type: .jpeg, fileExtension: "jpg", supportsAlpha: false, hasQuality: true),
        SaveFormat(id: "bmp", name: "BMP", type: .bmp, fileExtension: "bmp", supportsAlpha: true, hasQuality: false),
        SaveFormat(id: "tiff", name: "TIFF", type: .tiff, fileExtension: "tif", supportsAlpha: true, hasQuality: false),
        SaveFormat(id: "gif", name: "GIF", type: .gif, fileExtension: "gif", supportsAlpha: true, hasQuality: false),
        SaveFormat(id: "heic", name: "HEIC", type: .heic, fileExtension: "heic", supportsAlpha: true, hasQuality: true),
        SaveFormat(id: "tga", name: "TGA", type: UTType("com.truevision.tga-image") ?? .image, fileExtension: "tga", supportsAlpha: true, hasQuality: false),
    ]

    /// Nur Formate, die ImageIO auf diesem System tatsächlich schreiben kann.
    static var writableFormats: [SaveFormat] {
        let ids = Set((CGImageDestinationCopyTypeIdentifiers() as? [String]) ?? [])
        return candidateFormats.filter { ids.contains($0.type.identifier) }
    }

    static func format(for url: URL) -> SaveFormat? {
        guard let t = UTType(filenameExtension: url.pathExtension.lowercased()) else { return nil }
        return writableFormats.first { t.conforms(to: $0.type) }
    }

    // MARK: Öffnen

    static func load(url: URL) throws -> LoadedImage {
        guard let src = CGImageSourceCreateWithURL(url as CFURL, [kCGImageSourceShouldCache: false] as CFDictionary) else {
            throw ImageCodecError.unreadable
        }
        return try load(source: src)
    }

    static func load(data: Data) throws -> LoadedImage {
        guard let src = CGImageSourceCreateWithData(data as CFData, nil) else { throw ImageCodecError.unreadable }
        return try load(source: src)
    }

    private static func load(source src: CGImageSource) throws -> LoadedImage {
        guard CGImageSourceGetCount(src) > 0,
              let cg = CGImageSourceCreateImageAtIndex(src, 0, [kCGImageSourceShouldCache: false] as CFDictionary) else {
            throw ImageCodecError.unreadable
        }
        let props = CGImageSourceCopyPropertiesAtIndex(src, 0, nil) as? [CFString: Any] ?? [:]
        var surface = try surface(from: cg)
        // EXIF-Ausrichtung verlustfrei anwenden (nur Spiegeln/Drehen in 90°-Schritten).
        let orientation = (props[kCGImagePropertyOrientation] as? NSNumber)?.intValue ?? 1
        switch orientation {
        case 2: surface = surface.flippedHorizontally()
        case 3: surface = surface.rotated180()
        case 4: surface = surface.flippedVertically()
        case 5: surface = surface.rotated90Clockwise().flippedHorizontally()
        case 6: surface = surface.rotated90Clockwise()
        case 7: surface = surface.rotated90Clockwise().flippedVertically()
        case 8: surface = surface.rotated90CounterClockwise()
        default: break
        }
        let dpi = (props[kCGImagePropertyDPIWidth] as? NSNumber)?.doubleValue ?? defaultDpi
        return LoadedImage(surface: surface, dpi: dpi > 0 ? dpi : defaultDpi, typeIdentifier: CGImageSourceGetType(src) as String?)
    }

    /// CGImage → Fläche (BGRA, gerades Alpha, sRGB).
    static func surface(from cg: CGImage) throws -> TiledSurface {
        let w = cg.width, h = cg.height
        guard w > 0, h > 0 else { throw ImageCodecError.unreadable }
        guard w <= NewImageParameters.maxDimension, h <= NewImageParameters.maxDimension else { throw ImageCodecError.tooLarge(w, h) }
        guard let format = vImage_CGImageFormat(
            bitsPerComponent: 8, bitsPerPixel: 32, colorSpace: ImageRendering.sRGB,
            bitmapInfo: CGBitmapInfo(rawValue: CGImageAlphaInfo.first.rawValue | CGBitmapInfo.byteOrder32Little.rawValue),
            renderingIntent: .defaultIntent) else { throw ImageCodecError.unreadable }
        var buffer: vImage_Buffer
        do { buffer = try vImage_Buffer(cgImage: cg, format: format) } catch { throw ImageCodecError.unreadable }
        defer { buffer.free() }
        let rowBytes = buffer.rowBytes
        let bytes = Array(UnsafeBufferPointer(start: buffer.data.assumingMemoryBound(to: UInt8.self), count: rowBytes * h))
        return TiledSurface(width: w, height: h, bgra: bytes, bytesPerRow: rowBytes)
    }

    // MARK: Speichern

    /// Schreibt eine Fläche (gerades Alpha) atomar in eine Datei.
    static func save(_ surface: TiledSurface, dpi: Double, to url: URL, format: SaveFormat, quality: Int) throws {
        let data = try encode(surface, dpi: dpi, format: format, quality: quality)
        do { try data.write(to: url, options: .atomic) } catch { throw ImageCodecError.writeFailed }
    }

    static func encode(_ surface: TiledSurface, dpi: Double, format: SaveFormat, quality: Int) throws -> Data {
        var bytes = surface.bgraBytes()
        if !format.supportsAlpha { flattenOntoWhite(&bytes) }
        guard let cg = ImageRendering.cgImage(straightBGRA: bytes, width: surface.width, height: surface.height) else {
            throw ImageCodecError.writeFailed
        }
        let out = NSMutableData()
        guard let dest = CGImageDestinationCreateWithData(out as CFMutableData, format.type.identifier as CFString, 1, nil) else {
            throw ImageCodecError.unsupportedFormat
        }
        var props: [CFString: Any] = [kCGImagePropertyDPIWidth: dpi, kCGImagePropertyDPIHeight: dpi]
        if format.hasQuality { props[kCGImageDestinationLossyCompressionQuality] = Double(quality) / 100.0 }
        CGImageDestinationAddImage(dest, cg, props as CFDictionary)
        guard CGImageDestinationFinalize(dest) else { throw ImageCodecError.writeFailed }
        return out as Data
    }

    /// Für Formate ohne Transparenz: auf weißen Grund mischen.
    static func flattenOntoWhite(_ bytes: inout [UInt8]) {
        var i = 0
        while i < bytes.count {
            let a = Int(bytes[i + 3])
            if a != 255 {
                for k in 0..<3 { bytes[i + k] = UInt8((Int(bytes[i + k]) * a + 255 * (255 - a) + 127) / 255) }
                bytes[i + 3] = 255
            }
            i += 4
        }
    }
}
