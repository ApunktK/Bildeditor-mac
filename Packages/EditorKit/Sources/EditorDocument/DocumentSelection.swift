import EditorCore

/// Schwebende Pixel: eingefügtes oder angehobenes Bildstück, das bis zum Fertigstellen verschoben werden kann.
/// `base` ist der Zustand ohne das Stück (beim Verschieben: Ursprungsbereich bereits geleert).
public struct FloatingPixels: Equatable, Sendable {
    public var base: DocumentState
    /// Pixel des Stücks (gerades Alpha; außerhalb der Auswahlform transparent).
    public var pixels: TiledSurface
    /// Form der Auswahl in Stückgröße.
    public var shape: SelectionMask
    /// Lage der linken oberen Ecke im Bild.
    public var origin: PixelPoint
    public let historyName: String
    public let kind: HistoryKind

    public init(base: DocumentState, pixels: TiledSurface, shape: SelectionMask, origin: PixelPoint, historyName: String, kind: HistoryKind) {
        self.base = base; self.pixels = pixels; self.shape = shape; self.origin = origin; self.historyName = historyName; self.kind = kind
    }

    public var rect: PixelRect { PixelRect(x: origin.x, y: origin.y, width: pixels.width, height: pixels.height) }

    /// Zustand mit dem Stück an `origin` (normal über die aktive Ebene gemischt) und der verschobenen Auswahl.
    public func composed() -> DocumentState {
        var s = base
        let li = s.activeLayerIndex
        var surf = s.layers[li].surface
        let dst = rect.intersection(surf.bounds)
        if !dst.isEmpty {
            for y in dst.minY..<dst.maxY {
                for x in dst.minX..<dst.maxX {
                    let top = pixels[x - origin.x, y - origin.y]
                    if top.a == 0 { continue }
                    surf[x, y] = top.a == 255 ? top : BlendMode.normal.blend(bottom: surf[x, y], top: top)
                }
            }
        }
        s.layers[li].surface = surf
        let sel = shape.resizedCanvas(to: s.size, offset: origin)
        s.selection = sel.isEmpty ? nil : sel
        return s
    }
}

extension Document {
    /// Auswahl vorhanden und nicht leer.
    public var hasSelection: Bool { state.selection.map { !$0.isEmpty } ?? false }

    /// Begrenzungsrechteck der Auswahl (nil ohne Auswahl).
    public var selectionBounds: PixelRect? {
        guard let s = state.selection else { return nil }
        let b = s.bounds
        return b.isEmpty ? nil : b
    }

    // MARK: Auswahl festlegen

    /// Verknüpft eine neue Form mit der bestehenden Auswahl. Ergebnis leer → keine Auswahl.
    public func combinedSelection(_ mask: SelectionMask, mode: SelectionMode) -> SelectionMask? {
        let current = state.selection ?? SelectionMask(size: state.size)
        let r = mode == .replace ? mask : current.combined(with: mask, mode: mode)
        return r.isEmpty ? nil : r
    }

    /// Setzt die Auswahl als Verlaufsschritt (nur bei Änderung).
    public func setSelection(_ mask: SelectionMask?, name: String) {
        settlePreview()
        let m = (mask?.isEmpty ?? true) ? nil : mask
        guard m != state.selection else { return }
        var s = state
        s.selection = m
        commit(s, name: name, kind: .selection)
    }

    /// Vorschau einer Auswahl während des Aufziehens (ohne Verlaufsschritt).
    public func previewSelection(_ mask: SelectionMask?) {
        if floating != nil { settlePreview() }
        var s = previewBaseState
        s.selection = (mask?.isEmpty ?? true) ? nil : mask
        preview(s)
    }

    public func selectAll() { setSelection(.all(state.size), name: "Alles auswählen") }
    public func deselect() { setSelection(nil, name: "Auswahl aufheben") }

    /// Ohne Auswahl wird alles ausgewählt (Umkehrung von „nichts“).
    public func invertSelection() {
        setSelection((state.selection ?? SelectionMask(size: state.size)).inverted(), name: "Auswahl umkehren")
    }

    // MARK: Pixel in der Auswahl

    /// Auswahl löschen: ausgewählte Pixel der aktiven Ebene werden transparent (0,0,0,0); Auswahl wird aufgehoben.
    public func eraseSelection() {
        settlePreview()
        guard let sel = state.selection, hasSelection else { return }
        var s = state
        s.layers[s.activeLayerIndex].surface = Self.erased(s.layers[s.activeLayerIndex].surface, by: sel)
        s.selection = nil
        commit(s, name: "Auswahl löschen", kind: .erase)
    }

    static func erased(_ surface: TiledSurface, by sel: SelectionMask) -> TiledSurface {
        var out = surface
        let b = sel.bounds
        if b.isEmpty { return out }
        for y in b.minY..<b.maxY {
            for x in b.minX..<b.maxX {
                let m = Int(sel[x, y])
                if m == 0 { continue }
                if m == 255 { out[x, y] = .transparent; continue }
                var c = out[x, y]
                c.a = UInt8(Int(c.a) * (255 - m) / 255)
                out[x, y] = c.a == 0 ? .transparent : c
            }
        }
        return out
    }

    /// Auswahl füllen: ausgewählte Pixel der aktiven Ebene erhalten die Farbe; Auswahl bleibt.
    public func fillSelection(with color: ColorBgra) {
        settlePreview()
        guard let sel = state.selection, hasSelection else { return }
        var s = state
        var surf = s.layers[s.activeLayerIndex].surface
        let b = sel.bounds
        for y in b.minY..<b.maxY {
            for x in b.minX..<b.maxX {
                let m = Int(sel[x, y])
                if m == 0 { continue }
                if m == 255 { surf[x, y] = color; continue }
                let o = surf[x, y]
                func mix(_ a: UInt8, _ b: UInt8) -> UInt8 { UInt8((Int(a) * (255 - m) + Int(b) * m + 127) / 255) }
                surf[x, y] = ColorBgra(r: mix(o.r, color.r), g: mix(o.g, color.g), b: mix(o.b, color.b), a: mix(o.a, color.a))
            }
        }
        s.layers[s.activeLayerIndex].surface = surf
        commit(s, name: "Auswahl füllen", kind: .fill)
    }

    /// Ausgewählte Pixel als eigenes Bild (Begrenzungsrechteck; außerhalb der Form transparent).
    /// Ohne Auswahl: ganze aktive Ebene bzw. ganzes Bild.
    public func selectedPixels(merged: Bool) -> TiledSurface {
        let source = merged ? Compositor.flatten(state.layers, size: state.size) : state.layers[state.activeLayerIndex].surface
        guard let sel = state.selection, let b = selectionBounds else { return source }
        return Self.extract(source, mask: sel, rect: b)
    }

    static func extract(_ source: TiledSurface, mask: SelectionMask, rect b: PixelRect) -> TiledSurface {
        var out = TiledSurface(size: b.size)
        for y in b.minY..<b.maxY {
            for x in b.minX..<b.maxX {
                let m = Int(mask[x, y])
                if m == 0 { continue }
                var c = source[x, y]
                if c.a == 0 { continue }
                if m != 255 { c.a = UInt8(Int(c.a) * m / 255) }
                if c.a != 0 { out[x - b.minX, y - b.minY] = c }
            }
        }
        return out
    }

    /// Ausschneiden = ausgewählte Pixel liefern und löschen.
    public func cutSelection() -> TiledSurface? {
        settlePreview()
        guard hasSelection else { return nil }
        let pixels = selectedPixels(merged: false)
        guard let sel = state.selection else { return nil }
        var s = state
        s.layers[s.activeLayerIndex].surface = Self.erased(s.layers[s.activeLayerIndex].surface, by: sel)
        s.selection = nil
        commit(s, name: "Ausschneiden", kind: .erase)
        return pixels
    }

    /// Auf Auswahl zuschneiden: Begrenzungsrechteck; Pixel außerhalb einer nicht rechteckigen Auswahl werden (0,0,0,0).
    public func cropToSelection() {
        settlePreview()
        guard let sel = state.selection, let b = selectionBounds else { return }
        var s = state
        let isRect = sel.selectedPixelCount == b.width * b.height
        for i in s.layers.indices {
            let src = s.layers[i].surface
            if isRect {
                var out = TiledSurface(size: b.size)
                out.copy(from: src, sourceRect: b, to: .zero)
                s.layers[i].surface = out
            } else {
                s.layers[i].surface = Self.extract(src, mask: sel, rect: b)
            }
        }
        s.size = b.size
        s.selection = nil
        commit(s, name: "Auf Auswahl zuschneiden", kind: .crop)
    }

    // MARK: Verschieben

    /// Nur die Auswahlkontur verschieben (Pixel bleiben).
    public func selectionMoved(dx: Int, dy: Int, from base: DocumentState) -> DocumentState {
        var s = base
        if let sel = base.selection {
            let t = sel.translated(dx: dx, dy: dy)
            s.selection = t.isEmpty ? nil : t
        }
        return s
    }

    /// Ausgewählte Pixel anheben (ohne Auswahl: ganze Ebene). `copy` = Ursprung bleibt erhalten.
    public func liftSelectedPixels(copy: Bool) -> FloatingPixels? {
        settlePreview()
        var base = state
        let li = base.activeLayerIndex
        let layer = base.layers[li].surface
        let sel = state.selection ?? .all(state.size)
        let b = sel.bounds
        guard !b.isEmpty else { return nil }
        let pixels = Self.extract(layer, mask: sel, rect: b)
        if !copy { base.layers[li].surface = Self.erased(layer, by: sel) }
        base.selection = nil
        return FloatingPixels(base: base, pixels: pixels, shape: sel.cropped(to: b), origin: PixelPoint(b.minX, b.minY),
                              historyName: copy ? "Kopie der Pixel verschieben" : "Ausgewählte Pixel verschieben", kind: .pixelsMove)
    }

    /// Eingefügtes Bild als schwebende Pixel an `origin` (aktive Ebene oder neue Ebene).
    public func floatingPaste(_ surface: TiledSurface, at origin: PixelPoint, intoNewLayer: Bool, growCanvas: Bool) -> FloatingPixels {
        settlePreview()
        var base = state
        if growCanvas && (surface.width > base.size.width || surface.height > base.size.height) {
            let ns = PixelSize(max(base.size.width, surface.width), max(base.size.height, surface.height))
            for i in base.layers.indices { base.layers[i].surface = base.layers[i].surface.resizedCanvas(to: ns, offset: .zero, fill: .transparent) }
            base.size = ns
        }
        if intoNewLayer {
            base.layers.insert(Layer(name: nextLayerName(), size: base.size), at: base.activeLayerIndex + 1)
            base.activeLayerIndex += 1
        }
        base.selection = nil
        return FloatingPixels(base: base, pixels: surface, shape: .all(surface.size), origin: origin,
                              historyName: intoNewLayer ? "In neue Ebene einfügen" : "Einfügen", kind: .paste)
    }

    /// Zustand ohne laufende Vorschau (Grundlage für das Aufziehen einer Auswahl).
    public var previewBaseState: DocumentState { committedState }
}
