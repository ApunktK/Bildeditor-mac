// 32-Bit-Farbe mit geradem (nicht vormultipliziertem) Alpha, Speicherreihenfolge B, G, R, A –
// dieselbe Darstellung wie in Paint.NET-Dateien, damit Werte unter Alpha 0 erhalten bleiben.

public struct ColorBgra: Hashable, Sendable, CustomStringConvertible {
    public var b: UInt8
    public var g: UInt8
    public var r: UInt8
    public var a: UInt8

    public init(r: UInt8, g: UInt8, b: UInt8, a: UInt8 = 255) {
        self.r = r; self.g = g; self.b = b; self.a = a
    }

    /// Gepackt als UInt32 (Little Endian = Bytes B, G, R, A im Speicher).
    @inlinable public init(packed v: UInt32) {
        b = UInt8(truncatingIfNeeded: v)
        g = UInt8(truncatingIfNeeded: v >> 8)
        r = UInt8(truncatingIfNeeded: v >> 16)
        a = UInt8(truncatingIfNeeded: v >> 24)
    }
    @inlinable public var packed: UInt32 {
        UInt32(b) | UInt32(g) << 8 | UInt32(r) << 16 | UInt32(a) << 24
    }

    public static let transparent = ColorBgra(packed: 0)                    // #00000000
    public static let transparentWhite = ColorBgra(r: 255, g: 255, b: 255, a: 0)
    public static let black = ColorBgra(r: 0, g: 0, b: 0)
    public static let white = ColorBgra(r: 255, g: 255, b: 255)

    /// Hex wie im Farbenfenster: „RRGGBB“ oder „RRGGBBAA“, optional mit „#“.
    public init?(hex: String) {
        var s = hex.trimmingWhitespace()
        if s.hasPrefix("#") { s.removeFirst() }
        guard s.count == 6 || s.count == 8, let v = UInt32(s, radix: 16) else { return nil }
        if s.count == 6 {
            self.init(r: UInt8(v >> 16 & 0xFF), g: UInt8(v >> 8 & 0xFF), b: UInt8(v & 0xFF))
        } else {
            self.init(r: UInt8(v >> 24 & 0xFF), g: UInt8(v >> 16 & 0xFF), b: UInt8(v >> 8 & 0xFF), a: UInt8(v & 0xFF))
        }
    }

    /// „RRGGBB“ bei voller Deckkraft, sonst „RRGGBBAA“.
    public var hexString: String {
        let parts = a == 255 ? [r, g, b] : [r, g, b, a]
        return parts.map { byte -> String in
            let h = String(byte, radix: 16, uppercase: true)
            return h.count == 1 ? "0" + h : h
        }.joined()
    }

    /// Paint.NET-Palettenformat: „AARRGGBB“.
    public var argbHexString: String {
        [a, r, g, b].map { byte -> String in
            let h = String(byte, radix: 16, uppercase: true)
            return h.count == 1 ? "0" + h : h
        }.joined()
    }

    public var description: String { "#" + hexString }
}

extension String {
    func trimmingWhitespace() -> String {
        var s = Substring(self)
        while let c = s.first, c.isWhitespace { s.removeFirst() }
        while let c = s.last, c.isWhitespace { s.removeLast() }
        return String(s)
    }
}
