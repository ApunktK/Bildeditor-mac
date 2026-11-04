import AppKit
import EditorCore

/// Einzeltasten wie in der Referenz: Werkzeugwahl (Mehrfachdruck schaltet in der Gruppe weiter) und Farbtasten.
extension AppController {
    /// Rückgabe: Taste verarbeitet.
    func handleSingleKey(_ ch: Character, shift: Bool) -> Bool {
        switch ch {
        case "x":   // Primär- und Sekundärfarbe tauschen
            swapColors(); return true
        case "c":   // aktives Farbfeld wechseln
            colors.primaryIsActive.toggle(); return true
        default: break
        }
        let group = Tool.allCases.filter { $0.key == ch }
        guard !group.isEmpty else { return false }
        let next: Tool
        if let i = group.firstIndex(of: tool) {
            next = group[(i + (shift ? group.count - 1 : 1)) % group.count]
        } else {
            next = shift ? group.last! : group.first!
        }
        if next.isImplemented {
            tool = next
        } else {
            NSSound.beep()
            mainWindow?.showTransientHint(next.statusHint)
        }
        return true
    }

    func swapColors() {
        var c = colors
        (c.primary, c.secondary) = (c.secondary, c.primary)
        colors = c
    }

    func resetColors() { var c = colors; c.primary = .black; c.secondary = .white; colors = c }
}
