import AppKit

/// Tastenkürzel eines Befehls (Mac-Belegung, siehe KEYMAP.md).
struct Shortcut {
    let key: String
    let modifiers: NSEvent.ModifierFlags

    init(_ key: String, _ modifiers: NSEvent.ModifierFlags = [.command]) {
        self.key = key; self.modifiers = modifiers
    }

    static func function(_ code: Int, _ modifiers: NSEvent.ModifierFlags = []) -> Shortcut {
        Shortcut(String(Character(UnicodeScalar(UInt32(code))!)), modifiers)
    }
}

/// Ein Menü-/Tastenbefehl. `run == nil` heißt: noch nicht umgesetzt – der Eintrag erscheint deaktiviert
/// mit Hinweis auf die geplante Phase (keine Attrappe, die Erfolg vortäuscht).
final class Command {
    let id: String
    let title: String
    let shortcut: Shortcut?
    /// Standard-Aktion der Responder-Kette (z. B. `copy:`), damit Textfelder ihre eigenen Befehle behalten.
    let standardAction: Selector?
    let plannedPhase: Int?
    let run: (() -> Void)?
    let isEnabled: () -> Bool
    let isChecked: (() -> Bool)?

    init(_ id: String, _ title: String, shortcut: Shortcut? = nil, standardAction: Selector? = nil,
         planned: Int? = nil, enabled: @escaping () -> Bool = { true }, checked: (() -> Bool)? = nil,
         run: (() -> Void)? = nil) {
        self.id = id; self.title = title; self.shortcut = shortcut; self.standardAction = standardAction
        self.plannedPhase = run == nil ? (planned ?? 99) : nil
        self.run = run; self.isEnabled = enabled; self.isChecked = checked
    }

    var isImplemented: Bool { run != nil }
    var canRun: Bool { isImplemented && isEnabled() }

    var notImplementedHint: String {
        if let p = plannedPhase, p < 99 { return "„\(title.replacingOccurrences(of: "…", with: ""))“ ist noch nicht umgesetzt (geplant für Phase \(p))." }
        return "„\(title.replacingOccurrences(of: "…", with: ""))“ ist noch nicht umgesetzt."
    }
}

/// Zentrale Befehlstabelle: Menüs, Werkzeugleiste und Tastenkürzel greifen auf dieselben Einträge zu.
final class CommandRegistry: NSObject, NSMenuItemValidation {
    private(set) var byID: [String: Command] = [:]
    private(set) var ids: [String] = []

    func register(_ c: Command) {
        precondition(byID[c.id] == nil, "Befehl doppelt: \(c.id)")
        byID[c.id] = c; ids.append(c.id)
    }

    subscript(id: String) -> Command? { byID[id] }

    func canPerform(_ id: String) -> Bool { byID[id]?.canRun ?? false }

    @discardableResult
    func perform(_ id: String) -> Bool {
        guard let c = byID[id], c.canRun, let run = c.run else { NSSound.beep(); return false }
        run()
        return true
    }

    /// Ziel aller Menüeinträge ohne Standard-Aktion.
    @objc func performMenuCommand(_ sender: Any?) {
        if let item = sender as? NSMenuItem, let id = item.representedObject as? String { perform(id) }
        else if let b = sender as? NSButton, let id = b.identifier?.rawValue { perform(id) }
    }

    func validateMenuItem(_ item: NSMenuItem) -> Bool {
        guard let id = item.representedObject as? String, let c = byID[id] else { return true }
        if let checked = c.isChecked { item.state = checked() ? .on : .off }
        return c.canRun
    }

    /// Anzahl umgesetzter / aller Befehle (für IMPLEMENTATION_STATUS und Selbsttest).
    var implementationCounts: (implemented: Int, total: Int) {
        (byID.values.filter(\.isImplemented).count, byID.count)
    }
}
