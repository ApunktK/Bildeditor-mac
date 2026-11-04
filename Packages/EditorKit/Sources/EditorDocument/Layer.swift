import Foundation
import EditorCore

/// Eine Rasterebene. Werttyp: Kopien teilen ihre Kacheln, bis eine Seite sie ändert.
public struct Layer: Equatable, Sendable, Identifiable {
    public let id: UUID
    public var name: String
    public var isVisible: Bool
    /// Deckkraft 0…255 (wie im PDN-Format).
    public var opacity: UInt8
    public var blendMode: BlendMode
    public var isBackground: Bool
    public var surface: TiledSurface

    public init(id: UUID = UUID(), name: String, size: PixelSize, fill: ColorBgra = .transparent,
                isVisible: Bool = true, opacity: UInt8 = 255, blendMode: BlendMode = .normal, isBackground: Bool = false) {
        self.id = id
        self.name = name
        self.isVisible = isVisible
        self.opacity = opacity
        self.blendMode = blendMode
        self.isBackground = isBackground
        surface = fill == .transparent ? TiledSurface(size: size) : TiledSurface(size: size, filledWith: fill)
    }

    public init(id: UUID = UUID(), name: String, surface: TiledSurface, isVisible: Bool = true,
                opacity: UInt8 = 255, blendMode: BlendMode = .normal, isBackground: Bool = false) {
        self.id = id; self.name = name; self.surface = surface; self.isVisible = isVisible
        self.opacity = opacity; self.blendMode = blendMode; self.isBackground = isBackground
    }

    /// Nur die Eigenschaften (für Dialog und Verlauf).
    public struct Properties: Equatable, Sendable {
        public var name: String
        public var isVisible: Bool
        public var opacity: UInt8
        public var blendMode: BlendMode
        public init(name: String, isVisible: Bool, opacity: UInt8, blendMode: BlendMode) {
            self.name = name; self.isVisible = isVisible; self.opacity = opacity; self.blendMode = blendMode
        }
    }

    public var properties: Properties {
        get { Properties(name: name, isVisible: isVisible, opacity: opacity, blendMode: blendMode) }
        set { name = newValue.name; isVisible = newValue.isVisible; opacity = newValue.opacity; blendMode = newValue.blendMode }
    }
}
