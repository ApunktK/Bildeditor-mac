// Auswahl als Pixelmaske (0 = nicht ausgewählt, 255 = ausgewählt), in Kacheln mit
// den Sonderfällen „leer“ und „voll“, damit „Alles auswählen“ auch bei großen Bildern kaum Speicher braucht.
// Werttyp: Kopien teilen ihre Kacheln (Verlauf).

/// Verknüpfung einer neuen Auswahl mit der bestehenden (Werkzeugleiste „Auswahlmodus“).
public enum SelectionMode: String, CaseIterable, Sendable {
    case replace, union, exclude, intersect, xor

    public var displayName: String {
        switch self {
        case .replace: return "Ersetzen"
        case .union: return "Hinzufügen (Vereinigung)"
        case .exclude: return "Abziehen"
        case .intersect: return "Schnittmenge"
        case .xor: return "Umkehren (XOR)"
        }
    }
}

public struct SelectionMask: Equatable, Sendable {
    public static let tileSize = 256
    @usableFromInline static let shift = 8

    @usableFromInline enum Tile: Equatable, Sendable {
        case empty, full, partial([UInt8])
    }

    public let width: Int
    public let height: Int
    @usableFromInline let tilesX: Int
    @usableFromInline let tilesY: Int
    @usableFromInline var tiles: [Tile]

    public init(width: Int, height: Int) {
        self.width = max(0, width); self.height = max(0, height)
        tilesX = (self.width + Self.tileSize - 1) / Self.tileSize
        tilesY = (self.height + Self.tileSize - 1) / Self.tileSize
        tiles = Array(repeating: .empty, count: tilesX * tilesY)
    }

    public init(size: PixelSize) { self.init(width: size.width, height: size.height) }

    public var size: PixelSize { PixelSize(width, height) }

    /// Alles ausgewählt.
    public static func all(_ size: PixelSize) -> SelectionMask {
        var m = SelectionMask(size: size)
        for i in m.tiles.indices { m.tiles[i] = .full }
        m.trimEdgeTiles()
        return m
    }

    // MARK: Zugriff

    @inlinable public subscript(x: Int, y: Int) -> UInt8 {
        get {
            guard x >= 0, y >= 0, x < width, y < height else { return 0 }
            switch tiles[(y >> Self.shift) * tilesX + (x >> Self.shift)] {
            case .empty: return 0
            case .full: return 255
            case let .partial(a): return a[((y & 255) << Self.shift) | (x & 255)]
            }
        }
        set {
            guard x >= 0, y >= 0, x < width, y < height else { return }
            let ti = (y >> Self.shift) * tilesX + (x >> Self.shift)
            let o = ((y & 255) << Self.shift) | (x & 255)
            switch tiles[ti] {
            case .empty:
                if newValue == 0 { return }
                var a = [UInt8](repeating: 0, count: Self.tileSize * Self.tileSize)
                a[o] = newValue
                tiles[ti] = .partial(a)
            case .full:
                if newValue == 255 { return }
                var a = [UInt8](repeating: 255, count: Self.tileSize * Self.tileSize)
                a[o] = newValue
                tiles[ti] = .partial(a)
            case .partial(var a):
                tiles[ti] = .empty   // Referenz freigeben, damit kein Kopieren nötig ist
                a[o] = newValue
                tiles[ti] = .partial(a)
            }
        }
    }

    public func isSelected(_ x: Int, _ y: Int) -> Bool { self[x, y] >= 128 }

    func tileRect(_ tx: Int, _ ty: Int) -> PixelRect {
        PixelRect(x: tx * Self.tileSize, y: ty * Self.tileSize,
                  width: min(Self.tileSize, width - tx * Self.tileSize), height: min(Self.tileSize, height - ty * Self.tileSize))
    }

    /// Randkacheln, die über die Bildfläche hinausragen, als Teilkachel speichern (außen 0),
    /// damit „voll“ immer „jedes Pixel der Kachel im Bild ist ausgewählt“ bedeutet und außen nichts zählt.
    private mutating func trimEdgeTiles() {
        // „full“ bedeutet: alle Pixel der Kachel innerhalb des Bildes. Außerhalb liegende Pixel werden
        // nie gelesen (Subscript prüft Grenzen), daher ist keine Umwandlung nötig.
    }

    /// Kacheln vereinfachen: nur 0 → leer, nur 255 → voll.
    public mutating func normalize() {
        for ty in 0..<tilesY {
            for tx in 0..<tilesX {
                let i = ty * tilesX + tx
                guard case let .partial(a) = tiles[i] else { continue }
                let r = tileRect(tx, ty)
                var all0 = true, all255 = true
                for y in 0..<r.height {
                    let row = y << Self.shift
                    for x in 0..<r.width {
                        let v = a[row | x]
                        if v != 0 { all0 = false }
                        if v != 255 { all255 = false }
                        if !all0 && !all255 { break }
                    }
                    if !all0 && !all255 { break }
                }
                if all0 { tiles[i] = .empty } else if all255 { tiles[i] = .full }
            }
        }
    }

    public var isEmpty: Bool {
        for (i, t) in tiles.enumerated() {
            switch t {
            case .empty: continue
            case .full: return false
            case let .partial(a):
                let r = tileRect(i % tilesX, i / tilesX)
                for y in 0..<r.height { for x in 0..<r.width where a[(y << Self.shift) | x] != 0 { return false } }
            }
        }
        return true
    }

    /// Kleinstes Rechteck um alle ausgewählten Pixel (Wert ≥ 1); leer, wenn nichts ausgewählt.
    public var bounds: PixelRect {
        var minX = Int.max, minY = Int.max, maxX = Int.min, maxY = Int.min
        for ty in 0..<tilesY {
            for tx in 0..<tilesX {
                let r = tileRect(tx, ty)
                switch tiles[ty * tilesX + tx] {
                case .empty: continue
                case .full:
                    minX = min(minX, r.minX); minY = min(minY, r.minY); maxX = max(maxX, r.maxX); maxY = max(maxY, r.maxY)
                case let .partial(a):
                    for y in 0..<r.height {
                        let row = y << Self.shift
                        for x in 0..<r.width where a[row | x] != 0 {
                            minX = min(minX, r.minX + x); maxX = max(maxX, r.minX + x + 1)
                            minY = min(minY, r.minY + y); maxY = max(maxY, r.minY + y + 1)
                        }
                    }
                }
            }
        }
        if minX == Int.max { return .empty }
        return PixelRect(x: minX, y: minY, width: maxX - minX, height: maxY - minY)
    }

    /// Anzahl ausgewählter Pixel (≥ 128).
    public var selectedPixelCount: Int {
        var n = 0
        for ty in 0..<tilesY {
            for tx in 0..<tilesX {
                let r = tileRect(tx, ty)
                switch tiles[ty * tilesX + tx] {
                case .empty: continue
                case .full: n += r.width * r.height
                case let .partial(a):
                    for y in 0..<r.height { for x in 0..<r.width where a[(y << Self.shift) | x] >= 128 { n += 1 } }
                }
            }
        }
        return n
    }

    /// Ganze Kacheln setzen (schnell für Rechtecke).
    mutating func fillRect(_ rect: PixelRect, value: UInt8) {
        let r = rect.intersection(PixelRect(size: size))
        if r.isEmpty { return }
        for ty in (r.minY >> Self.shift)...((r.maxY - 1) >> Self.shift) {
            for tx in (r.minX >> Self.shift)...((r.maxX - 1) >> Self.shift) {
                let tr = tileRect(tx, ty)
                let part = tr.intersection(r)
                if part == tr { tiles[ty * tilesX + tx] = value == 0 ? .empty : (value == 255 ? .full : .partial(Array(repeating: value, count: Self.tileSize * Self.tileSize))); continue }
                for y in part.minY..<part.maxY { for x in part.minX..<part.maxX { self[x, y] = value } }
            }
        }
    }

    // MARK: Formen

    public static func rectangle(_ rect: PixelRect, in size: PixelSize) -> SelectionMask {
        var m = SelectionMask(size: size)
        m.fillRect(rect, value: 255)
        return m
    }

    /// Ellipse im Rechteck (Pixel, deren Mittelpunkt innen liegt).
    public static func ellipse(_ rect: PixelRect, in size: PixelSize) -> SelectionMask {
        var m = SelectionMask(size: size)
        guard !rect.isEmpty else { return m }
        let cx = Double(rect.minX) + Double(rect.width) / 2, cy = Double(rect.minY) + Double(rect.height) / 2
        let rx = Double(rect.width) / 2, ry = Double(rect.height) / 2
        let clip = rect.intersection(PixelRect(size: size))
        if clip.isEmpty { return m }
        for y in clip.minY..<clip.maxY {
            let dy = (Double(y) + 0.5 - cy) / ry
            let q = 1 - dy * dy
            if q < 0 { continue }
            let half = rx * q.squareRoot()
            // Pixel x mit Mittelpunkt in [cx-half, cx+half)
            let x0 = max(clip.minX, Int((cx - half - 0.5).rounded(.up)))
            let x1 = min(clip.maxX, Int((cx + half - 0.5).rounded(.up)))
            if x1 > x0 { m.fillRect(PixelRect(x: x0, y: y, width: x1 - x0, height: 1), value: 255) }
        }
        return m
    }

    /// Polygon (Lasso), geschlossen, Füllregel gerade/ungerade, Pixelmittelpunkte.
    public static func polygon(_ points: [(x: Double, y: Double)], in size: PixelSize) -> SelectionMask {
        var m = SelectionMask(size: size)
        guard points.count >= 3 else { return m }
        let minY = max(0, Int(points.map(\.y).min()!.rounded(.down))), maxY = min(size.height, Int(points.map(\.y).max()!.rounded(.up)) + 1)
        if minY >= maxY { return m }
        var xs: [Double] = []
        for y in minY..<maxY {
            let yc = Double(y) + 0.5
            xs.removeAll(keepingCapacity: true)
            for i in points.indices {
                let a = points[i], b = points[(i + 1) % points.count]
                if (a.y <= yc && b.y > yc) || (b.y <= yc && a.y > yc) {
                    xs.append(a.x + (yc - a.y) / (b.y - a.y) * (b.x - a.x))
                }
            }
            xs.sort()
            var k = 0
            while k + 1 < xs.count {
                let x0 = max(0, Int((xs[k] - 0.5).rounded(.up))), x1 = min(size.width, Int((xs[k + 1] - 0.5).rounded(.up)))
                if x1 > x0 { m.fillRect(PixelRect(x: x0, y: y, width: x1 - x0, height: 1), value: 255) }
                k += 2
            }
        }
        return m
    }

    // MARK: Verknüpfen

    public func combined(with other: SelectionMask, mode: SelectionMode) -> SelectionMask {
        precondition(other.size == size, "Auswahlgrößen verschieden")
        if mode == .replace { return other }
        var out = SelectionMask(size: size)
        for ty in 0..<tilesY {
            for tx in 0..<tilesX {
                let i = ty * tilesX + tx
                let a = tiles[i], b = other.tiles[i]
                // Schnelle Fälle ohne Pixelschleife
                switch (mode, a, b) {
                case (.union, .full, _), (.union, _, .full): out.tiles[i] = .full; continue
                case (.union, .empty, _): out.tiles[i] = b; continue
                case (.union, _, .empty): out.tiles[i] = a; continue
                case (.intersect, .empty, _), (.intersect, _, .empty): out.tiles[i] = .empty; continue
                case (.intersect, .full, _): out.tiles[i] = b; continue
                case (.intersect, _, .full): out.tiles[i] = a; continue
                case (.exclude, .empty, _), (.exclude, _, .full): out.tiles[i] = .empty; continue
                case (.exclude, _, .empty): out.tiles[i] = a; continue
                case (.xor, _, .empty): out.tiles[i] = a; continue
                case (.xor, .empty, _): out.tiles[i] = b; continue
                case (.xor, .full, .full): out.tiles[i] = .empty; continue
                default: break
                }
                let r = tileRect(tx, ty)
                var arr = [UInt8](repeating: 0, count: Self.tileSize * Self.tileSize)
                for y in 0..<r.height {
                    for x in 0..<r.width {
                        let px = r.minX + x, py = r.minY + y
                        let va = Int(self[px, py]), vb = Int(other[px, py])
                        let v: Int
                        switch mode {
                        case .replace: v = vb
                        case .union: v = max(va, vb)
                        case .intersect: v = min(va, vb)
                        case .exclude: v = min(va, 255 - vb)
                        case .xor: v = abs(va - vb)
                        }
                        arr[(y << Self.shift) | x] = UInt8(v)
                    }
                }
                out.tiles[i] = .partial(arr)
            }
        }
        out.normalize()
        return out
    }

    public func inverted() -> SelectionMask {
        var out = self
        for i in out.tiles.indices {
            switch out.tiles[i] {
            case .empty: out.tiles[i] = .full
            case .full: out.tiles[i] = .empty
            case let .partial(a): out.tiles[i] = .partial(a.map { 255 - $0 })
            }
        }
        return out
    }

    // MARK: Geometrie

    /// Verschiebt die Maske (außerhalb wird abgeschnitten).
    public func translated(dx: Int, dy: Int) -> SelectionMask {
        if dx == 0 && dy == 0 { return self }
        return resizedCanvas(to: size, offset: PixelPoint(dx, dy))
    }

    /// Allgemeine Abbildung auf eine neue Größe: `source(x, y)` liefert die Quellkoordinate für Zielpixel (x, y).
    public func remapped(to newSize: PixelSize, source: (Int, Int) -> (Int, Int)) -> SelectionMask {
        var out = SelectionMask(size: newSize)
        for y in 0..<newSize.height {
            for x in 0..<newSize.width {
                let (sx, sy) = source(x, y)
                let v = self[sx, sy]
                if v != 0 { out[x, y] = v }
            }
        }
        out.normalize()
        return out
    }

    public func flippedHorizontally() -> SelectionMask { remapped(to: size) { (self.width - 1 - $0, $1) } }
    public func flippedVertically() -> SelectionMask { remapped(to: size) { ($0, self.height - 1 - $1) } }
    public func rotated180() -> SelectionMask { remapped(to: size) { (self.width - 1 - $0, self.height - 1 - $1) } }
    /// Ziel (x, y) ← Quelle (y, H−1−x) – gleiche Richtung wie TiledSurface.rotated90Clockwise.
    public func rotated90Clockwise() -> SelectionMask { remapped(to: PixelSize(height, width)) { ($1, self.height - 1 - $0) } }
    public func rotated90CounterClockwise() -> SelectionMask { remapped(to: PixelSize(height, width)) { (self.width - 1 - $1, $0) } }

    /// Neue Leinwandgröße; Inhalt um `offset` verschoben.
    public func resizedCanvas(to newSize: PixelSize, offset: PixelPoint) -> SelectionMask {
        var out = SelectionMask(size: newSize)
        let b = bounds
        if b.isEmpty { return out }
        let dst = b.offsetBy(dx: offset.x, dy: offset.y).intersection(PixelRect(size: newSize))
        if dst.isEmpty { return out }
        for y in dst.minY..<dst.maxY {
            for x in dst.minX..<dst.maxX {
                let v = self[x - offset.x, y - offset.y]
                if v != 0 { out[x, y] = v }
            }
        }
        out.normalize()
        return out
    }

    // MARK: Kontur

    /// Kanten zwischen ausgewählten und nicht ausgewählten Pixeln als Strecken in Pixelkoordinaten
    /// (zusammengefasst zu waagrechten und senkrechten Läufen) – für die Ameisenlinie.
    public func outlineSegments() -> [(x0: Int, y0: Int, x1: Int, y1: Int)] {
        var out: [(x0: Int, y0: Int, x1: Int, y1: Int)] = []
        let b = bounds
        if b.isEmpty { return out }
        // Waagrechte Kanten: zwischen Zeile y-1 und y
        for y in b.minY...b.maxY {
            var runStart = -1
            for x in b.minX...b.maxX {
                let edge = x < b.maxX && (isSelected(x, y) != isSelected(x, y - 1))
                if edge { if runStart < 0 { runStart = x } }
                else if runStart >= 0 { out.append((runStart, y, x, y)); runStart = -1 }
            }
        }
        // Senkrechte Kanten: zwischen Spalte x-1 und x
        for x in b.minX...b.maxX {
            var runStart = -1
            for y in b.minY...b.maxY {
                let edge = y < b.maxY && (isSelected(x, y) != isSelected(x - 1, y))
                if edge { if runStart < 0 { runStart = y } }
                else if runStart >= 0 { out.append((x, runStart, x, y)); runStart = -1 }
            }
        }
        return out
    }

    /// Ausschnitt als neue Maske (für Zuschneiden).
    public func cropped(to rect: PixelRect) -> SelectionMask {
        remapped(to: rect.size) { ($0 + rect.minX, $1 + rect.minY) }
    }
}

// MARK: Zauberstab

/// Farbvergleich wie Paint.NET 3.36 `FloodToolBase.CheckColor`
/// (SPDX-License-Identifier: MIT; Copyright (C) dotPDN LLC, Rick Brewster, Tom Jackson, and contributors).
@inlinable
public func floodColorMatches(_ a: ColorBgra, _ b: ColorBgra, tolerance: Int) -> Bool {
    var sum = 0
    var d = Int(a.r) - Int(b.r); sum += (1 + d * d) * Int(a.a) / 256
    d = Int(a.g) - Int(b.g); sum += (1 + d * d) * Int(a.a) / 256
    d = Int(a.b) - Int(b.b); sum += (1 + d * d) * Int(a.a) / 256
    d = Int(a.a) - Int(b.a); sum += d * d
    return sum <= tolerance * tolerance * 4
}

/// Toleranz 0…1 (Anzeige 0…100 %) in den ganzzahligen Wert der Referenz umrechnen.
public func floodTolerance(fromFraction t: Double) -> Int { Int(t * t * 256) }

extension SelectionMask {
    /// Zauberstab: zusammenhängend (4er-Nachbarschaft) oder global alle Pixel ähnlicher Farbe.
    public static func magicWand(on surface: TiledSurface, at p: PixelPoint, tolerance: Double, global: Bool) -> SelectionMask {
        var m = SelectionMask(size: surface.size)
        guard surface.bounds.contains(p) else { return m }
        let cmp = surface[p.x, p.y]
        let tol = floodTolerance(fromFraction: max(0, min(1, tolerance)))
        let w = surface.width, h = surface.height
        if global {
            for y in 0..<h { for x in 0..<w where floodColorMatches(cmp, surface[x, y], tolerance: tol) { m[x, y] = 255 } }
            m.normalize()
            return m
        }
        // Zeilenweises Flutfüllen mit Stapel
        var visited = [Bool](repeating: false, count: w * h)
        var stack: [(Int, Int)] = [(p.x, p.y)]
        while let (sx, sy) = stack.popLast() {
            if visited[sy * w + sx] { continue }
            var l = sx, r = sx
            while l > 0 && !visited[sy * w + l - 1] && floodColorMatches(cmp, surface[l - 1, sy], tolerance: tol) { l -= 1 }
            while r < w - 1 && !visited[sy * w + r + 1] && floodColorMatches(cmp, surface[r + 1, sy], tolerance: tol) { r += 1 }
            for x in l...r { visited[sy * w + x] = true; m[x, sy] = 255 }
            for ny in [sy - 1, sy + 1] where ny >= 0 && ny < h {
                var x = l
                while x <= r {
                    if !visited[ny * w + x] && floodColorMatches(cmp, surface[x, ny], tolerance: tol) {
                        stack.append((x, ny))
                        while x <= r && !visited[ny * w + x] && floodColorMatches(cmp, surface[x, ny], tolerance: tol) { x += 1 }
                    }
                    x += 1
                }
            }
        }
        m.normalize()
        return m
    }
}
