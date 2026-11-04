// Verlustfreie Transformationen (Spiegeln, 90°-Drehungen) für Bild- und Ebenenmenü.

extension TiledSurface {
    public func flippedHorizontally() -> TiledSurface {
        var out = TiledSurface(width: width, height: height)
        for y in 0..<height { for x in 0..<width { let c = self[x, y]; if c.packed != 0 { out[width - 1 - x, y] = c } } }
        return out
    }

    public func flippedVertically() -> TiledSurface {
        var out = TiledSurface(width: width, height: height)
        for y in 0..<height { for x in 0..<width { let c = self[x, y]; if c.packed != 0 { out[x, height - 1 - y] = c } } }
        return out
    }

    /// 90° im Uhrzeigersinn: (x, y) → (H−1−y, x); neue Größe H × W.
    public func rotated90Clockwise() -> TiledSurface {
        var out = TiledSurface(width: height, height: width)
        for y in 0..<height { for x in 0..<width { let c = self[x, y]; if c.packed != 0 { out[height - 1 - y, x] = c } } }
        return out
    }

    /// 90° gegen den Uhrzeigersinn: (x, y) → (y, W−1−x).
    public func rotated90CounterClockwise() -> TiledSurface {
        var out = TiledSurface(width: height, height: width)
        for y in 0..<height { for x in 0..<width { let c = self[x, y]; if c.packed != 0 { out[y, width - 1 - x] = c } } }
        return out
    }

    public func rotated180() -> TiledSurface {
        var out = TiledSurface(width: width, height: height)
        for y in 0..<height { for x in 0..<width { let c = self[x, y]; if c.packed != 0 { out[width - 1 - x, height - 1 - y] = c } } }
        return out
    }

    /// Neue Leinwandgröße ohne Skalierung; `offset` = Lage des alten Bildes in der neuen Fläche, Rest mit `fill`.
    public func resizedCanvas(to size: PixelSize, offset: PixelPoint, fill: ColorBgra) -> TiledSurface {
        var out = fill == .transparent ? TiledSurface(size: size) : TiledSurface(size: size, filledWith: fill)
        out.copy(from: self, sourceRect: bounds, to: offset)
        return out
    }
}
