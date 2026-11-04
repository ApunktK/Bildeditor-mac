// Gekachelte Rasterfläche (BGRA, gerades Alpha).
// - Kacheln 256 × 256; nicht vorhandene Kacheln gelten als #00000000 und belegen keinen Speicher.
// - Kacheln sind Werttypen (Swift-Arrays mit Copy-on-Write): Eine Kopie der Fläche kostet fast nichts,
//   erst geänderte Kacheln werden tatsächlich kopiert. Darauf beruht das Rückgängig-System.

public struct TiledSurface: Equatable, Sendable {
    public static let tileSize = 256
    public static let tileShift = 8

    public let width: Int
    public let height: Int
    public let tilesX: Int
    public let tilesY: Int
    /// Zeilenweise Kachelliste; nil = vollständig transparent (#00000000).
    @usableFromInline var tiles: [[UInt32]?]

    public init(width: Int, height: Int) {
        precondition(width > 0 && height > 0, "Fläche braucht positive Maße")
        self.width = width
        self.height = height
        tilesX = (width + Self.tileSize - 1) >> Self.tileShift
        tilesY = (height + Self.tileSize - 1) >> Self.tileShift
        tiles = Array(repeating: nil, count: tilesX * tilesY)
    }

    public init(size: PixelSize) { self.init(width: size.width, height: size.height) }

    public init(size: PixelSize, filledWith color: ColorBgra) {
        self.init(size: size)
        fill(PixelRect(size: size), with: color)
    }

    public var size: PixelSize { PixelSize(width, height) }
    public var bounds: PixelRect { PixelRect(size: size) }

    /// Anzahl tatsächlich belegter Kacheln (für Speicheranzeige und Tests).
    public var allocatedTileCount: Int { tiles.reduce(0) { $0 + ($1 == nil ? 0 : 1) } }

    // MARK: Pixelzugriff

    @inlinable public subscript(x: Int, y: Int) -> ColorBgra {
        get {
            precondition(x >= 0 && y >= 0 && x < width && y < height, "Pixel außerhalb")
            let ti = (y >> Self.tileShift) * tilesX + (x >> Self.tileShift)
            guard let t = tiles[ti] else { return .transparent }
            return ColorBgra(packed: t[(y & (Self.tileSize - 1)) << Self.tileShift | (x & (Self.tileSize - 1))])
        }
        set {
            precondition(x >= 0 && y >= 0 && x < width && y < height, "Pixel außerhalb")
            let ti = (y >> Self.tileShift) * tilesX + (x >> Self.tileShift)
            if tiles[ti] == nil {
                if newValue.packed == 0 { return }
                tiles[ti] = Array(repeating: 0, count: Self.tileSize * Self.tileSize)
            }
            tiles[ti]![(y & (Self.tileSize - 1)) << Self.tileShift | (x & (Self.tileSize - 1))] = newValue.packed
        }
    }

    /// true, wenn die Kachel nicht belegt ist (vollständig #00000000).
    public func tileIsEmpty(tx: Int, ty: Int) -> Bool { tiles[ty * tilesX + tx] == nil }

    /// Kachelrechteck in Pixeln (am Rand beschnitten).
    public func tileRect(tx: Int, ty: Int) -> PixelRect {
        let x = tx << Self.tileShift, y = ty << Self.tileShift
        return PixelRect(x: x, y: y, width: min(Self.tileSize, width - x), height: min(Self.tileSize, height - y))
    }

    /// Kachelindizes, die ein Rechteck berühren.
    public func tiles(touching rect: PixelRect) -> [(tx: Int, ty: Int)] {
        let r = rect.intersection(bounds)
        if r.isEmpty { return [] }
        var out: [(Int, Int)] = []
        for ty in (r.minY >> Self.tileShift)...((r.maxY - 1) >> Self.tileShift) {
            for tx in (r.minX >> Self.tileShift)...((r.maxX - 1) >> Self.tileShift) { out.append((tx, ty)) }
        }
        return out
    }

    // MARK: Massenoperationen

    public mutating func fill(_ rect: PixelRect, with color: ColorBgra) {
        let r = rect.intersection(bounds)
        if r.isEmpty { return }
        let v = color.packed
        for (tx, ty) in tiles(touching: r) {
            let tr = tileRect(tx: tx, ty: ty)
            let part = r.intersection(tr)
            let ti = ty * tilesX + tx
            if part == tr && tr.width == Self.tileSize && tr.height == Self.tileSize {
                tiles[ti] = v == 0 ? nil : Array(repeating: v, count: Self.tileSize * Self.tileSize)
                continue
            }
            if tiles[ti] == nil {
                if v == 0 { continue }
                tiles[ti] = Array(repeating: 0, count: Self.tileSize * Self.tileSize)
            }
            tiles[ti]!.withUnsafeMutableBufferPointer { buf in
                for y in part.minY..<part.maxY {
                    let row = (y - tr.minY) << Self.tileShift
                    for x in part.minX..<part.maxX { buf[row + (x - tr.minX)] = v }
                }
            }
        }
    }

    /// Zeilenweise BGRA-Bytes eines Bereichs (gerades Alpha), z. B. für Export und Anzeige.
    public func bgraBytes(in rect: PixelRect? = nil) -> [UInt8] {
        let r = (rect ?? bounds).intersection(bounds)
        var out = [UInt8](repeating: 0, count: r.width * r.height * 4)
        if r.isEmpty { return out }
        out.withUnsafeMutableBytes { raw in
            let dst = raw.bindMemory(to: UInt32.self)
            for (tx, ty) in tiles(touching: r) {
                guard let t = tiles[ty * tilesX + tx] else { continue }
                let tr = tileRect(tx: tx, ty: ty)
                let part = r.intersection(tr)
                for y in part.minY..<part.maxY {
                    let srcRow = (y - tr.minY) << Self.tileShift
                    let dstRow = (y - r.minY) * r.width
                    for x in part.minX..<part.maxX { dst[dstRow + x - r.minX] = t[srcRow + x - tr.minX].littleEndian }
                }
            }
        }
        return out
    }

    /// Fläche aus zeilenweisen BGRA-Bytes (gerades Alpha, Zeilenlänge = Breite × 4, sofern bytesPerRow nil).
    public init(width: Int, height: Int, bgra: [UInt8], bytesPerRow: Int? = nil) {
        self.init(width: width, height: height)
        let stride = bytesPerRow ?? width * 4
        precondition(bgra.count >= stride * (height - 1) + width * 4, "zu wenige Bilddaten")
        bgra.withUnsafeBytes { raw in
            for ty in 0..<tilesY {
                for tx in 0..<tilesX {
                    let tr = tileRect(tx: tx, ty: ty)
                    var tile = [UInt32](repeating: 0, count: Self.tileSize * Self.tileSize)
                    var any = false
                    for y in tr.minY..<tr.maxY {
                        let rowOff = y * stride
                        for x in tr.minX..<tr.maxX {
                            let o = rowOff + x * 4
                            let v = UInt32(raw[o]) | UInt32(raw[o + 1]) << 8 | UInt32(raw[o + 2]) << 16 | UInt32(raw[o + 3]) << 24
                            if v != 0 { any = true }
                            tile[(y - tr.minY) << Self.tileShift | (x - tr.minX)] = v
                        }
                    }
                    if any { tiles[ty * tilesX + tx] = tile }
                }
            }
        }
    }

    /// Kopiert einen Bereich einer anderen Fläche an eine Zielposition (Pixel werden ersetzt, nicht gemischt).
    public mutating func copy(from src: TiledSurface, sourceRect: PixelRect, to dest: PixelPoint) {
        let s = sourceRect.intersection(src.bounds)
        if s.isEmpty { return }
        let d = PixelRect(x: dest.x, y: dest.y, width: s.width, height: s.height).intersection(bounds)
        if d.isEmpty { return }
        let dx = s.minX - dest.x, dy = s.minY - dest.y
        for y in d.minY..<d.maxY { for x in d.minX..<d.maxX { self[x, y] = src[x + dx, y + dy] } }
    }

    /// Kacheln, die sich zwischen zwei gleich großen Flächen unterscheiden (Grundlage für Verlauf und Neuzeichnen).
    public func changedTiles(comparedTo other: TiledSurface) -> [(tx: Int, ty: Int)] {
        precondition(other.width == width && other.height == height)
        var out: [(Int, Int)] = []
        for i in 0..<tiles.count where tiles[i] != other.tiles[i] { out.append((i % tilesX, i / tilesX)) }
        return out
    }
}
