import AppKit

final class AppDelegate: NSObject, NSApplicationDelegate {
    private var launched = false
    private var pendingURLs: [URL] = []

    func applicationDidFinishLaunching(_ notification: Notification) {
        let args = CommandLine.arguments
        let ctrl = AppController.shared
        if let i = args.firstIndex(of: "--selftest"), i + 1 < args.count {
            ctrl.isSelfTest = true
            ctrl.start()
            SelfTest(outputDirectory: URL(fileURLWithPath: args[i + 1])).run()
            return
        }
        ctrl.start()
        launched = true
        if !pendingURLs.isEmpty {
            ctrl.open(urls: pendingURLs)
            pendingURLs = []
        }
        // Referenz: beim Start ein leeres Bild, falls nichts geöffnet wurde.
        if ctrl.sessions.isEmpty { ctrl.newDocument(Settings.shared.lastNewImage) }
        NSApp.activate(ignoringOtherApps: true)
    }

    /// Öffnen per Finder, Dock oder „Öffnen mit“ – auch beim Kaltstart (dann nach dem Start abgearbeitet).
    func application(_ application: NSApplication, open urls: [URL]) {
        if launched { AppController.shared.open(urls: urls) } else { pendingURLs.append(contentsOf: urls) }
    }

    func applicationShouldTerminate(_ sender: NSApplication) -> NSApplication.TerminateReply {
        AppController.shared.shouldTerminate() ? .terminateNow : .terminateCancel
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool { false }

    func applicationSupportsSecureRestorableState(_ app: NSApplication) -> Bool { true }
}

/// Leitet Standardaktionen (Rückgängig, Kopieren …) an die Befehlstabelle weiter, außer ein Textfeld bearbeitet gerade.
enum StandardActionRouting {
    static let map: [Selector: String] = [
        NSSelectorFromString("undo:"): "edit.undo",
        NSSelectorFromString("redo:"): "edit.redo",
        #selector(NSText.cut(_:)): "edit.cut",
        #selector(NSText.copy(_:)): "edit.copy",
        #selector(NSText.paste(_:)): "edit.paste",
        #selector(NSText.selectAll(_:)): "edit.selectAll",
        #selector(NSText.delete(_:)): "edit.eraseSelection",
    ]

    static func isTextEditing(_ w: NSWindow) -> Bool { w.firstResponder is NSText }
}

/// Hauptfenster: Rückgängig/Wiederholen gehören dem Bild, solange kein Textfeld bearbeitet wird.
final class EditorWindow: NSWindow {
    @objc func undo(_ sender: Any?) {
        if StandardActionRouting.isTextEditing(self), let um = undoManager, um.canUndo { um.undo(); return }
        AppController.shared.commands.perform("edit.undo")
    }
    @objc func redo(_ sender: Any?) {
        if StandardActionRouting.isTextEditing(self), let um = undoManager, um.canRedo { um.redo(); return }
        AppController.shared.commands.perform("edit.redo")
    }
    @objc func copy(_ sender: Any?) { AppController.shared.commands.perform("edit.copy") }
    @objc func paste(_ sender: Any?) { AppController.shared.commands.perform("edit.paste") }
    @objc func cut(_ sender: Any?) { AppController.shared.commands.perform("edit.cut") }
    @objc override func selectAll(_ sender: Any?) { AppController.shared.commands.perform("edit.selectAll") }
    @objc func delete(_ sender: Any?) { AppController.shared.commands.perform("edit.eraseSelection") }

    override func validateUserInterfaceItem(_ item: NSValidatedUserInterfaceItem) -> Bool {
        if let action = item.action, let id = StandardActionRouting.map[action] {
            if StandardActionRouting.isTextEditing(self) {
                if action == NSSelectorFromString("undo:") { return undoManager?.canUndo ?? false }
                if action == NSSelectorFromString("redo:") { return undoManager?.canRedo ?? false }
            }
            return AppController.shared.commands.canPerform(id)
        }
        return super.validateUserInterfaceItem(item)
    }
}

/// Schwebende Fenster (Werkzeuge, Verlauf, Ebenen, Farben) mit derselben Weiterleitung.
final class EditorPanel: NSPanel {
    @objc func undo(_ sender: Any?) {
        if StandardActionRouting.isTextEditing(self), let um = undoManager, um.canUndo { um.undo(); return }
        AppController.shared.commands.perform("edit.undo")
    }
    @objc func redo(_ sender: Any?) {
        if StandardActionRouting.isTextEditing(self), let um = undoManager, um.canRedo { um.redo(); return }
        AppController.shared.commands.perform("edit.redo")
    }
    @objc func copy(_ sender: Any?) { AppController.shared.commands.perform("edit.copy") }
    @objc func paste(_ sender: Any?) { AppController.shared.commands.perform("edit.paste") }

    override func validateUserInterfaceItem(_ item: NSValidatedUserInterfaceItem) -> Bool {
        if let action = item.action, let id = StandardActionRouting.map[action],
           action == NSSelectorFromString("undo:") || action == NSSelectorFromString("redo:") || action == #selector(NSText.copy(_:)) || action == #selector(NSText.paste(_:)) {
            if StandardActionRouting.isTextEditing(self) {
                if action == NSSelectorFromString("undo:") { return undoManager?.canUndo ?? false }
                if action == NSSelectorFromString("redo:") { return undoManager?.canRedo ?? false }
            }
            return AppController.shared.commands.canPerform(id)
        }
        return super.validateUserInterfaceItem(item)
    }
}
