// SPDX-License-Identifier: MIT
// Portiert aus Paint.NET 3.36, src/Data/UserBlendOps.Generated.H.cs (Makros BLEND, OVER … XOR).
// Paint.NET – Copyright (C) dotPDN LLC, Rick Brewster, Tom Jackson, and contributors.
// Portions Copyright (C) Microsoft Corporation. All Rights Reserved.
// Lizenz: MIT mit Ausnahmen, siehe Documentation/THIRD_PARTY_LICENSES.md (Abschnitt 2.1).
// Änderungen: nach Swift übertragen; Division über masTable durch exakte Ganzzahldivision ersetzt
// (masTable implementiert genau ⌊n / d⌋).

import EditorCore

/// Die 14 Ebenen-Mischmodi (Referenz: BlendModes.html). Reihenfolge = Reihenfolge in der Referenz-Auswahlliste.
public enum BlendMode: String, CaseIterable, Sendable, Codable {
    case normal, multiply, additive, colorBurn, colorDodge, reflect, glow, overlay,
         difference, negation, lighten, darken, screen, xor

    /// Deutscher Anzeigename.
    public var displayName: String {
        switch self {
        case .normal: return "Normal"
        case .multiply: return "Multiplizieren"
        case .additive: return "Additiv"
        case .colorBurn: return "Farbig nachbelichten"
        case .colorDodge: return "Farbig abwedeln"
        case .reflect: return "Reflektieren"
        case .glow: return "Leuchten"
        case .overlay: return "Überlagern"
        case .difference: return "Differenz"
        case .negation: return "Negation"
        case .lighten: return "Aufhellen"
        case .darken: return "Abdunkeln"
        case .screen: return "Negativ multiplizieren"
        case .xor: return "XOR"
        }
    }

    /// Mischfunktion F(A, B) je Kanal; A = Hintergrund (unten), B = Vordergrund (oben), beide 0…255.
    @inlinable func f(_ A: Int, _ B: Int) -> Int {
        switch self {
        case .normal: return B
        case .multiply: return scale(A, B)
        case .additive: return min(255, A + B)
        case .colorBurn: return B == 0 ? 0 : max(0, 255 - ((255 - A) * 255) / B)
        case .colorDodge: return B == 255 ? 255 : min(255, (A * 255) / (255 - B))
        case .reflect: return B == 255 ? 255 : min(255, (A * A) / (255 - B))
        case .glow: return A == 255 ? 255 : min(255, (B * B) / (255 - A))
        case .overlay: return A < 128 ? scale(2 * A, B) : 255 - scale(2 * (255 - A), 255 - B)
        case .difference: return abs(B - A)
        case .negation: return 255 - abs(255 - A - B)
        case .lighten: return max(A, B)
        case .darken: return min(A, B)
        case .screen: return B + A - scale(B, A)
        case .xor: return A ^ B
        }
    }

    /// Mischt `top` über `bottom`. `opacity` (0…255) ist die Ebenendeckkraft.
    @inlinable public func blend(bottom lhs: ColorBgra, top rhs: ColorBgra, opacity: Int = 255) -> ColorBgra {
        let lhsA = Int(lhs.a)
        let rhsA = opacity == 255 ? Int(rhs.a) : scale(Int(rhs.a), opacity)
        let y = scale(lhsA, 255 - rhsA)
        let totalA = y + rhsA
        if totalA == 0 { return .transparent }
        let x = scale(lhsA, rhsA)
        let z = rhsA - x
        let fb = f(Int(lhs.b), Int(rhs.b)), fg = f(Int(lhs.g), Int(rhs.g)), fr = f(Int(lhs.r), Int(rhs.r))
        let b = (Int(lhs.b) * y + Int(rhs.b) * z + fb * x) / totalA
        let g = (Int(lhs.g) * y + Int(rhs.g) * z + fg * x) / totalA
        let r = (Int(lhs.r) * y + Int(rhs.r) * z + fr * x) / totalA
        let a = scale(lhsA, 255 - rhsA) + rhsA
        return ColorBgra(r: UInt8(r), g: UInt8(g), b: UInt8(b), a: UInt8(a))
    }
}

/// Multipliziert zwei Werte 0…255 wie Anteile 0…1 (INT_SCALE der Referenz, gerundet).
@inlinable func scale(_ a: Int, _ b: Int) -> Int {
    let r = a * b + 0x80
    return ((r >> 8) + r) >> 8
}
