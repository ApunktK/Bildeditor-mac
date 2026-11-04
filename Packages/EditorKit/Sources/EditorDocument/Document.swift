import Foundation
import EditorCore

/// Gesamtzustand eines Bildes, wie ihn der Verlauf speichert. Werttyp: Kopien teilen unveränderte Kacheln.
public struct DocumentState: Equatable, Sendable {
    public var size: PixelSize
    /// Auflösung in Pixel pro Zoll.
    public var dpi: Double
    /// Ebenen von unten (Index 0) nach oben.
    public var layers: [Layer]
    public var activeLayerIndex: Int

    public init(size: PixelSize, dpi: Double, layers: [Layer], activeLayerIndex: Int) {
        self.size = size; self.dpi = dpi; self.layers = layers; self.activeLayerIndex = activeLayerIndex
    }
}

/// Art eines Verlaufseintrags (bestimmt das Symbol im Verlaufsfenster).
public enum HistoryKind: String, Sendable {
    case newImage, openImage, layerAdd, layerDelete, layerDuplicate, layerMerge, layerMove, layerProperties,
         imageTransform, imageResize, flatten, paste, edit
}

public struct HistoryEntry: Sendable {
    public let name: String
    public let kind: HistoryKind
    public let state: DocumentState
}

/// Ein geöffnetes Bild mit eigenem Verlauf. Alle Änderungen laufen über Methoden dieser Klasse,
/// damit jede abgeschlossene Aktion genau einen Verlaufseintrag erzeugt.
public final class Document {
    public enum Change: Sendable { case content, layers, activeLayer, history, size, file }

    public let id = UUID()
    public private(set) var state: DocumentState
    public private(set) var history: [HistoryEntry]
    /// Index des aktuellen Eintrags in `history`; spätere Einträge sind rückgängig gemacht (grau).
    public private(set) var historyIndex: Int

    /// Dateibezug (nil = noch nie gespeichert).
    public var fileURL: URL? { didSet { notify(.file) } }
    /// Name für Titel und Register.
    public var displayName: String
    /// Verlaufsindex des zuletzt gespeicherten Zustands (nil = nie gespeichert / verworfen).
    public private(set) var savedHistoryIndex: Int?

    private var observers: [UUID: (Change) -> Void] = [:]

    public var isDirty: Bool { savedHistoryIndex != historyIndex }
    /// Ob beim Schließen nachgefragt werden muss: ungespeichert und nicht mehr im unberührten Neuzustand
    /// (ein frisches, unverändertes neues Bild wird ohne Rückfrage geschlossen).
    public var needsSavePrompt: Bool {
        isDirty && !(fileURL == nil && savedHistoryIndex == nil && historyIndex == 0 && history[0].kind == .newImage)
    }
    public var size: PixelSize { state.size }
    public var layers: [Layer] { state.layers }
    public var activeLayerIndex: Int { state.activeLayerIndex }
    public var activeLayer: Layer { state.layers[state.activeLayerIndex] }
    public var canUndo: Bool { historyIndex > 0 }
    public var canRedo: Bool { historyIndex < history.count - 1 }

    /// Neues Bild: eine Hintergrundebene, gefüllt (Referenz: weiß).
    public init(size: PixelSize, dpi: Double, background: ColorBgra = .white, name: String) {
        let layer = Layer(name: "Hintergrund", size: size, fill: background, isBackground: true)
        state = DocumentState(size: size, dpi: dpi, layers: [layer], activeLayerIndex: 0)
        history = [HistoryEntry(name: "Neues Bild", kind: .newImage, state: state)]
        historyIndex = 0
        displayName = name
        savedHistoryIndex = nil
    }

    /// Geöffnetes Bild aus vorhandenen Ebenen.
    public init(state: DocumentState, name: String, fileURL: URL?,
                historyName: String = "Bild öffnen", historyKind: HistoryKind = .openImage) {
        precondition(!state.layers.isEmpty, "Dokument braucht mindestens eine Ebene")
        self.state = state
        history = [HistoryEntry(name: historyName, kind: historyKind, state: state)]
        historyIndex = 0
        displayName = name
        self.fileURL = fileURL
        savedHistoryIndex = fileURL == nil ? nil : 0
    }

    // MARK: Beobachter

    @discardableResult
    public func observe(_ handler: @escaping (Change) -> Void) -> UUID {
        let token = UUID(); observers[token] = handler; return token
    }
    public func removeObserver(_ token: UUID) { observers[token] = nil }
    private func notify(_ c: Change) { for h in observers.values { h(c) } }

    // MARK: Verlauf

    /// Übernimmt einen neuen Zustand als Verlaufseintrag (verwirft rückgängig gemachte Einträge).
    public func commit(_ newState: DocumentState, name: String, kind: HistoryKind) {
        let sizeChanged = newState.size != state.size
        history.removeSubrange((historyIndex + 1)...)
        if let s = savedHistoryIndex, s > historyIndex { savedHistoryIndex = nil }
        history.append(HistoryEntry(name: name, kind: kind, state: newState))
        historyIndex = history.count - 1
        state = newState
        if sizeChanged { notify(.size) }
        notify(.layers); notify(.content); notify(.history)
    }

    public func undo() { if canUndo { jump(to: historyIndex - 1) } }
    public func redo() { if canRedo { jump(to: historyIndex + 1) } }

    /// Sprung zu einem Verlaufseintrag (Klick im Verlaufsfenster).
    public func jump(to index: Int) {
        guard index >= 0, index < history.count, index != historyIndex else { return }
        let old = state.size
        historyIndex = index
        state = history[index].state
        if old != state.size { notify(.size) }
        notify(.layers); notify(.content); notify(.history)
    }

    public func markSaved(as url: URL?) {
        if let url { fileURL = url; displayName = url.lastPathComponent }
        savedHistoryIndex = historyIndex
        notify(.history)
    }

    // MARK: Ebenen (ohne Verlauf)

    public func setActiveLayer(_ index: Int) {
        guard index >= 0, index < state.layers.count, index != state.activeLayerIndex else { return }
        state.activeLayerIndex = index
        // Auswahl der aktiven Ebene ist kein Verlaufsschritt; der Zustand im aktuellen Eintrag wird mitgeführt.
        history[historyIndex] = HistoryEntry(name: history[historyIndex].name, kind: history[historyIndex].kind, state: state)
        notify(.activeLayer)
    }

    // MARK: Ebenenbefehle (Menü „Ebenen“)

    /// „Ebene X“ mit kleinster freier Nummer ≥ Anzahl + 1 (eindeutig, wie Referenz).
    public func nextLayerName() -> String {
        var n = state.layers.count + 1
        let names = Set(state.layers.map(\.name))
        while names.contains("Ebene \(n)") { n += 1 }
        return "Ebene \(n)"
    }

    public func addLayer() {
        var s = state
        s.layers.insert(Layer(name: nextLayerName(), size: s.size), at: s.activeLayerIndex + 1)
        s.activeLayerIndex += 1
        commit(s, name: "Ebene hinzufügen", kind: .layerAdd)
    }

    public var canDeleteLayer: Bool { state.layers.count > 1 }

    public func deleteLayer() {
        guard canDeleteLayer else { return }
        var s = state
        s.layers.remove(at: s.activeLayerIndex)
        s.activeLayerIndex = max(0, s.activeLayerIndex - 1)
        commit(s, name: "Ebene löschen", kind: .layerDelete)
    }

    public func duplicateLayer() {
        var s = state
        var copy = s.layers[s.activeLayerIndex]
        copy = Layer(name: uniqueCopyName(copy.name), surface: copy.surface, isVisible: copy.isVisible,
                     opacity: copy.opacity, blendMode: copy.blendMode, isBackground: false)
        s.layers.insert(copy, at: s.activeLayerIndex + 1)
        s.activeLayerIndex += 1
        commit(s, name: "Ebene duplizieren", kind: .layerDuplicate)
    }

    private func uniqueCopyName(_ base: String) -> String {
        let names = Set(state.layers.map(\.name))
        var candidate = base + " Kopie"
        var n = 2
        while names.contains(candidate) { candidate = base + " Kopie \(n)"; n += 1 }
        return candidate
    }

    public var canMergeDown: Bool { state.activeLayerIndex > 0 }

    /// Fügt die aktive Ebene mit Mischmodus und Deckkraft in die Ebene darunter ein.
    public func mergeLayerDown() {
        guard canMergeDown else { return }
        var s = state
        let top = s.layers[s.activeLayerIndex]
        var bottom = s.layers[s.activeLayerIndex - 1]
        if top.isVisible && top.opacity > 0 {
            for (tx, ty) in top.surface.tiles(touching: top.surface.bounds) where !top.surface.tileIsEmpty(tx: tx, ty: ty) {
                let tr = top.surface.tileRect(tx: tx, ty: ty)
                for y in tr.minY..<tr.maxY {
                    for x in tr.minX..<tr.maxX {
                        let t = top.surface[x, y]
                        if t.a == 0 { continue }
                        bottom.surface[x, y] = top.blendMode.blend(bottom: bottom.surface[x, y], top: t, opacity: Int(top.opacity))
                    }
                }
            }
        }
        s.layers[s.activeLayerIndex - 1] = bottom
        s.layers.remove(at: s.activeLayerIndex)
        s.activeLayerIndex -= 1
        commit(s, name: "Mit darunterliegender Ebene zusammenführen", kind: .layerMerge)
    }

    public enum LayerMove: Sendable { case up, down, top, bottom }

    public func canMoveLayer(_ m: LayerMove) -> Bool {
        switch m {
        case .up, .top: return state.activeLayerIndex < state.layers.count - 1
        case .down, .bottom: return state.activeLayerIndex > 0
        }
    }

    public func moveLayer(_ m: LayerMove) {
        guard canMoveLayer(m) else { return }
        var s = state
        let i = s.activeLayerIndex
        let target: Int
        switch m {
        case .up: target = i + 1
        case .down: target = i - 1
        case .top: target = s.layers.count - 1
        case .bottom: target = 0
        }
        let l = s.layers.remove(at: i)
        s.layers.insert(l, at: target)
        s.activeLayerIndex = target
        let names: [LayerMove: String] = [.up: "Ebene nach oben", .down: "Ebene nach unten", .top: "Ebene ganz nach oben", .bottom: "Ebene ganz nach unten"]
        commit(s, name: names[m]!, kind: .layerMove)
    }

    /// Ebene per Drag & Drop an neue Position (Ebenenfenster).
    public func moveLayer(from: Int, to: Int) {
        guard from != to, from >= 0, to >= 0, from < state.layers.count, to < state.layers.count else { return }
        var s = state
        let l = s.layers.remove(at: from)
        s.layers.insert(l, at: to)
        s.activeLayerIndex = to
        commit(s, name: "Ebene verschieben", kind: .layerMove)
    }

    public func setLayerProperties(_ props: Layer.Properties, at index: Int) {
        guard index >= 0, index < state.layers.count, state.layers[index].properties != props else { return }
        var s = state
        s.layers[index].properties = props
        commit(s, name: "Ebeneneigenschaften", kind: .layerProperties)
    }

    // Vorschau im Dialog „Ebeneneigenschaften“: Änderungen sofort sichtbar, aber erst beim Bestätigen
    // ein Verlaufsschritt. Abbrechen stellt den Ausgangszustand wieder her.
    private var previewBase: DocumentState?
    public var isPreviewing: Bool { previewBase != nil }

    public func previewLayerProperties(_ props: Layer.Properties, at index: Int) {
        guard index >= 0, index < state.layers.count else { return }
        if previewBase == nil { previewBase = state }
        state.layers[index].properties = props
        notify(.layers); notify(.content)
    }

    /// Beendet die Vorschau: `apply` übernimmt die Werte als einen Verlaufsschritt, sonst Rückkehr zum Ausgangszustand.
    public func endLayerPropertiesPreview(apply: Bool, at index: Int) {
        guard let base = previewBase else { return }
        let props = state.layers[index].properties
        previewBase = nil
        state = base
        if apply && base.layers[index].properties != props { setLayerProperties(props, at: index) }
        else { notify(.layers); notify(.content) }
    }

    public func toggleVisibility(at index: Int) {
        guard index >= 0, index < state.layers.count else { return }
        var p = state.layers[index].properties
        p.isVisible.toggle()
        setLayerProperties(p, at: index)
    }

    // MARK: Bildbefehle (Menü „Bild“)

    public var canFlatten: Bool { state.layers.count > 1 }

    public func flatten() {
        guard canFlatten else { return }
        var s = state
        let merged = Compositor.flatten(s.layers, size: s.size)
        s.layers = [Layer(name: s.layers[0].name, surface: merged, isBackground: true)]
        s.activeLayerIndex = 0
        commit(s, name: "Auf eine Ebene reduzieren", kind: .flatten)
    }

    public enum ImageTransform: Sendable { case flipHorizontal, flipVertical, rotate90CW, rotate90CCW, rotate180 }

    public func transformImage(_ t: ImageTransform) {
        var s = state
        for i in s.layers.indices { s.layers[i].surface = Self.apply(t, s.layers[i].surface) }
        if t == .rotate90CW || t == .rotate90CCW { s.size = PixelSize(s.size.height, s.size.width) }
        commit(s, name: Self.name(t, layer: false), kind: .imageTransform)
    }

    public func transformActiveLayer(_ t: ImageTransform) {
        precondition(t == .flipHorizontal || t == .flipVertical || t == .rotate180, "90°-Drehung nur fürs ganze Bild")
        var s = state
        s.layers[s.activeLayerIndex].surface = Self.apply(t, s.layers[s.activeLayerIndex].surface)
        commit(s, name: Self.name(t, layer: true), kind: .imageTransform)
    }

    private static func apply(_ t: ImageTransform, _ surf: TiledSurface) -> TiledSurface {
        switch t {
        case .flipHorizontal: return surf.flippedHorizontally()
        case .flipVertical: return surf.flippedVertically()
        case .rotate90CW: return surf.rotated90Clockwise()
        case .rotate90CCW: return surf.rotated90CounterClockwise()
        case .rotate180: return surf.rotated180()
        }
    }

    private static func name(_ t: ImageTransform, layer: Bool) -> String {
        let what = layer ? "Ebene" : "Bild"
        switch t {
        case .flipHorizontal: return "\(what) horizontal spiegeln"
        case .flipVertical: return "\(what) vertikal spiegeln"
        case .rotate90CW: return "90° im Uhrzeigersinn drehen"
        case .rotate90CCW: return "90° gegen den Uhrzeigersinn drehen"
        case .rotate180: return "\(what) um 180° drehen"
        }
    }

    // MARK: Ebene aus Bild (Einfügen in neue Ebene, Ebene importieren)

    /// Fügt eine Ebene mit gegebenem Inhalt über der aktiven ein; ist sie größer, wird die Leinwand
    /// (nach Zustimmung des Aufrufers) rechts/unten mit Transparenz vergrößert.
    public func insertLayer(surface: TiledSurface, name: String, growCanvas: Bool, historyName: String, kind: HistoryKind = .layerAdd) {
        var s = state
        if growCanvas && (surface.width > s.size.width || surface.height > s.size.height) {
            let ns = PixelSize(max(s.size.width, surface.width), max(s.size.height, surface.height))
            for i in s.layers.indices {
                let fill: ColorBgra = .transparent
                s.layers[i].surface = s.layers[i].surface.resizedCanvas(to: ns, offset: .zero, fill: fill)
            }
            s.size = ns
        }
        var target = TiledSurface(size: s.size)
        target.copy(from: surface, sourceRect: surface.bounds, to: .zero)
        s.layers.insert(Layer(name: name, surface: target), at: s.activeLayerIndex + 1)
        s.activeLayerIndex += 1
        commit(s, name: historyName, kind: kind)
    }

    /// Komposit aller sichtbaren Ebenen.
    public func flattenedSurface() -> TiledSurface { Compositor.flatten(state.layers, size: state.size) }
}
