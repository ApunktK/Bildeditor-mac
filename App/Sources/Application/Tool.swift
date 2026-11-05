import AppKit

/// Werkzeuge in der Reihenfolge des Werkzeugfensters der Referenz.
/// `plannedPhase != nil` = noch nicht umgesetzt; der Knopf ist dann deaktiviert.
enum Tool: String, CaseIterable {
    case moveSelectedPixels, moveSelection
    case rectangleSelect, lassoSelect, ellipseSelect, magicWand
    case zoom, pan
    case paintBucket, gradient
    case paintbrush, eraser, pencil
    case colorPicker, cloneStamp, recolor
    case text, lineCurve, shapes

    var title: String {
        switch self {
        case .moveSelectedPixels: return "Ausgewählte Pixel verschieben"
        case .moveSelection: return "Auswahl verschieben"
        case .rectangleSelect: return "Rechteckauswahl"
        case .lassoSelect: return "Lassoauswahl"
        case .ellipseSelect: return "Ellipsenauswahl"
        case .magicWand: return "Zauberstab"
        case .zoom: return "Zoom"
        case .pan: return "Hand"
        case .paintBucket: return "Farbeimer"
        case .gradient: return "Farbverlauf"
        case .paintbrush: return "Pinsel"
        case .eraser: return "Radiergummi"
        case .pencil: return "Stift"
        case .colorPicker: return "Farbpipette"
        case .cloneStamp: return "Kopierstempel"
        case .recolor: return "Umfärben"
        case .text: return "Text"
        case .lineCurve: return "Linie/Kurve"
        case .shapes: return "Formen"
        }
    }

    /// Einzeltaste (Referenz, KEYMAP.md). Mehrfachdruck schaltet innerhalb der Gruppe weiter.
    var key: Character {
        switch self {
        case .moveSelectedPixels, .moveSelection: return "m"
        case .rectangleSelect, .lassoSelect, .ellipseSelect, .magicWand: return "s"
        case .zoom: return "z"
        case .pan: return "h"
        case .paintBucket: return "f"
        case .gradient: return "g"
        case .paintbrush: return "b"
        case .eraser: return "e"
        case .pencil: return "p"
        case .colorPicker: return "k"
        case .cloneStamp: return "l"
        case .recolor: return "r"
        case .text: return "t"
        case .lineCurve, .shapes: return "o"
        }
    }

    /// Eigene Symbole (SF Symbols des Systems), keine Übernahme der Referenz-Icons.
    var symbolName: String {
        switch self {
        case .moveSelectedPixels: return "arrow.up.and.down.and.arrow.left.and.right"
        case .moveSelection: return "arrow.up.left.and.down.right.and.arrow.up.right.and.down.left"
        case .rectangleSelect: return "rectangle.dashed"
        case .lassoSelect: return "lasso"
        case .ellipseSelect: return "circle.dashed"
        case .magicWand: return "wand.and.stars"
        case .zoom: return "plus.magnifyingglass"
        case .pan: return "hand.raised"
        case .paintBucket: return "drop.fill"
        case .gradient: return "circle.lefthalf.filled"
        case .paintbrush: return "paintbrush.pointed"
        case .eraser: return "eraser"
        case .pencil: return "pencil"
        case .colorPicker: return "eyedropper"
        case .cloneStamp: return "seal"
        case .recolor: return "paintpalette"
        case .text: return "textformat"
        case .lineCurve: return "line.diagonal"
        case .shapes: return "square.on.circle"
        }
    }

    var plannedPhase: Int? {
        switch self {
        case .zoom, .pan, .rectangleSelect, .lassoSelect, .ellipseSelect, .magicWand, .moveSelectedPixels, .moveSelection,
             .paintbrush, .pencil, .eraser, .paintBucket, .colorPicker: return nil
        default: return 4
        }
    }

    var isImplemented: Bool { plannedPhase == nil }

    var isSelectionTool: Bool { self == .rectangleSelect || self == .lassoSelect || self == .ellipseSelect || self == .magicWand }
    var isMoveTool: Bool { self == .moveSelectedPixels || self == .moveSelection }
    var isPaintTool: Bool { self == .paintbrush || self == .pencil || self == .eraser || self == .paintBucket || self == .colorPicker }
    /// Werkzeuge mit Pinselbreite (Umriss als Mauszeiger).
    var hasBrushWidth: Bool { self == .paintbrush || self == .eraser }

    /// Hinweis in der Statusleiste (eigener Text).
    var statusHint: String {
        switch self {
        case .zoom: return "Klicken: vergrößern · Rechtsklick oder ⌥-Klick: verkleinern · Rahmen ziehen: auf Bereich zoomen"
        case .pan: return "Ziehen, um die Ansicht zu verschieben"
        case .rectangleSelect: return "Rechteck aufziehen · ⇧ Quadrat · ⌘ hinzufügen · ⌥ abziehen · Rechtsklick+⌘ umkehren · Rechtsklick+⌥ Schnittmenge"
        case .ellipseSelect: return "Ellipse aufziehen · ⇧ Kreis · ⌘ hinzufügen · ⌥ abziehen"
        case .lassoSelect: return "Freihand umfahren; die Form wird zum Startpunkt geschlossen · ⌘ hinzufügen · ⌥ abziehen"
        case .magicWand: return "Klicken wählt ähnliche Farben · ⇧ global · ⌘ hinzufügen · ⌥ abziehen"
        case .moveSelectedPixels: return "Ziehen verschiebt die ausgewählten Pixel · ⌘ Kopie · Pfeiltasten 1 px (⌘ 10 px) · Eingabetaste: fertigstellen"
        case .moveSelection: return "Ziehen verschiebt nur die Auswahlkontur · Pfeiltasten 1 px (⌘ 10 px)"
        case .paintbrush: return "Linke Taste: Primärfarbe · Rechte Taste: Sekundärfarbe · ⇧-Klick: gerade Linie vom letzten Punkt"
        case .pencil: return "1 Pixel breit, ohne Kantenglättung · Rechte Taste: Sekundärfarbe · ⇧-Klick: gerade Linie"
        case .eraser: return "Macht Pixel der aktiven Ebene durchsichtig · ⇧-Klick: gerade Linie"
        case .paintBucket: return "Klick füllt ähnliche Farben mit der Primärfarbe · Rechtsklick: Sekundärfarbe · ⇧: global"
        case .colorPicker: return "Klick nimmt die Farbe als Primärfarbe auf · Rechtsklick: Sekundärfarbe"
        default: return "\(title): noch nicht verfügbar (geplant für Phase \(plannedPhase ?? 0))"
        }
    }

    /// Verlaufsname für eine mit diesem Werkzeug erzeugte Auswahl.
    var historyName: String { title }

    var image: NSImage? {
        NSImage(systemSymbolName: symbolName, accessibilityDescription: title)
    }

    var tooltip: String {
        let k = String(key).uppercased()
        if isImplemented { return "\(title) (\(k))" }
        return "\(title) (\(k)) – noch nicht verfügbar, geplant für Phase \(plannedPhase ?? 0)"
    }
}
