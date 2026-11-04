// Ganzzahlige Bildgeometrie. Ursprung oben links, y nach unten (wie Paint.NET).

public struct PixelPoint: Hashable, Sendable, CustomStringConvertible {
    public var x: Int
    public var y: Int
    public init(_ x: Int, _ y: Int) { self.x = x; self.y = y }
    public static let zero = PixelPoint(0, 0)
    public var description: String { "\(x), \(y)" }
}

public struct PixelSize: Hashable, Sendable, CustomStringConvertible {
    public var width: Int
    public var height: Int
    public init(_ width: Int, _ height: Int) { self.width = width; self.height = height }
    public var area: Int { width * height }
    public var isEmpty: Bool { width <= 0 || height <= 0 }
    public var description: String { "\(width) × \(height)" }
}

public struct PixelRect: Hashable, Sendable, CustomStringConvertible {
    public var x: Int
    public var y: Int
    public var width: Int
    public var height: Int

    public init(x: Int, y: Int, width: Int, height: Int) {
        self.x = x; self.y = y; self.width = width; self.height = height
    }
    public init(size: PixelSize) { self.init(x: 0, y: 0, width: size.width, height: size.height) }

    public static let empty = PixelRect(x: 0, y: 0, width: 0, height: 0)

    public var minX: Int { x }
    public var minY: Int { y }
    public var maxX: Int { x + width }   // exklusiv
    public var maxY: Int { y + height }  // exklusiv
    public var size: PixelSize { PixelSize(width, height) }
    public var isEmpty: Bool { width <= 0 || height <= 0 }
    public var description: String { "(\(x), \(y)) \(width) × \(height)" }

    public func contains(_ p: PixelPoint) -> Bool {
        p.x >= minX && p.x < maxX && p.y >= minY && p.y < maxY
    }

    public func intersection(_ o: PixelRect) -> PixelRect {
        let x0 = max(minX, o.minX), y0 = max(minY, o.minY)
        let x1 = min(maxX, o.maxX), y1 = min(maxY, o.maxY)
        if x1 <= x0 || y1 <= y0 { return .empty }
        return PixelRect(x: x0, y: y0, width: x1 - x0, height: y1 - y0)
    }

    public func union(_ o: PixelRect) -> PixelRect {
        if isEmpty { return o }
        if o.isEmpty { return self }
        let x0 = min(minX, o.minX), y0 = min(minY, o.minY)
        let x1 = max(maxX, o.maxX), y1 = max(maxY, o.maxY)
        return PixelRect(x: x0, y: y0, width: x1 - x0, height: y1 - y0)
    }

    public func offsetBy(dx: Int, dy: Int) -> PixelRect {
        PixelRect(x: x + dx, y: y + dy, width: width, height: height)
    }
}
