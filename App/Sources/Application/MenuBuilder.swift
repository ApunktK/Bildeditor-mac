import AppKit

/// Beschreibung eines Menüs: Befehl, Trennlinie, Untermenü oder dynamische Liste.
indirect enum MenuNode {
    case cmd(String)
    case separator
    case submenu(String, [MenuNode])
    case recentFiles
}

/// Baut die Menüleiste aus der Befehlstabelle.
enum MenuBuilder {
    private static let recentDelegate = RecentFilesMenuDelegate()

    static func buildMainMenu(_ reg: CommandRegistry, spec: [(String, [MenuNode])]) -> NSMenu {
        let main = NSMenu(title: "Hauptmenü")
        main.addItem(submenuItem(appMenu(reg)))
        for (title, nodes) in spec {
            let m = NSMenu(title: title)
            for n in nodes { m.addItem(item(for: n, reg)) }
            main.addItem(submenuItem(m))
            if title == "Fenster" { NSApp.windowsMenu = m }
            if title == "Hilfe" { NSApp.helpMenu = m }
        }
        return main
    }

    private static func submenuItem(_ m: NSMenu) -> NSMenuItem {
        let it = NSMenuItem(title: m.title, action: nil, keyEquivalent: "")
        it.submenu = m
        return it
    }

    private static func item(for node: MenuNode, _ reg: CommandRegistry) -> NSMenuItem {
        switch node {
        case .separator:
            return .separator()
        case let .submenu(title, nodes):
            let m = NSMenu(title: title)
            for n in nodes { m.addItem(item(for: n, reg)) }
            return submenuItem(m)
        case .recentFiles:
            let m = NSMenu(title: "Zuletzt geöffnet")
            m.delegate = recentDelegate
            return submenuItem(m)
        case let .cmd(id):
            guard let c = reg[id] else { preconditionFailure("Unbekannter Befehl im Menü: \(id)") }
            return menuItem(for: c, reg)
        }
    }

    static func menuItem(for c: Command, _ reg: CommandRegistry) -> NSMenuItem {
        let it = NSMenuItem(title: c.title, action: c.standardAction ?? #selector(CommandRegistry.performMenuCommand(_:)),
                            keyEquivalent: c.shortcut?.key ?? "")
        it.keyEquivalentModifierMask = c.shortcut?.modifiers ?? []
        it.target = c.standardAction == nil ? reg : nil
        it.representedObject = c.id
        if !c.isImplemented { it.toolTip = c.notImplementedHint }
        return it
    }

    private static func appMenu(_ reg: CommandRegistry) -> NSMenu {
        let name = "Bildeditor"
        let m = NSMenu(title: name)
        m.addItem(menuItem(for: reg["app.about"]!, reg))
        m.addItem(.separator())
        m.addItem(menuItem(for: reg["app.settings"]!, reg))
        m.addItem(.separator())
        let services = NSMenuItem(title: "Dienste", action: nil, keyEquivalent: "")
        let sm = NSMenu(title: "Dienste")
        services.submenu = sm
        NSApp.servicesMenu = sm
        m.addItem(services)
        m.addItem(.separator())
        m.addItem(withTitle: "\(name) ausblenden", action: #selector(NSApplication.hide(_:)), keyEquivalent: "h")
        let others = m.addItem(withTitle: "Andere ausblenden", action: #selector(NSApplication.hideOtherApplications(_:)), keyEquivalent: "h")
        others.keyEquivalentModifierMask = [.command, .option]
        m.addItem(withTitle: "Alle einblenden", action: #selector(NSApplication.unhideAllApplications(_:)), keyEquivalent: "")
        m.addItem(.separator())
        m.addItem(withTitle: "\(name) beenden", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q")
        return m
    }
}

/// Füllt „Datei › Zuletzt geöffnet“ beim Öffnen des Menüs.
final class RecentFilesMenuDelegate: NSObject, NSMenuDelegate {
    func menuNeedsUpdate(_ menu: NSMenu) {
        menu.removeAllItems()
        let files = Settings.shared.recentFiles
        if files.isEmpty {
            let it = NSMenuItem(title: "Keine Einträge", action: nil, keyEquivalent: "")
            it.isEnabled = false
            menu.addItem(it)
        }
        for url in files {
            let it = NSMenuItem(title: url.lastPathComponent, action: #selector(openRecent(_:)), keyEquivalent: "")
            it.target = self
            it.representedObject = url
            it.toolTip = url.path
            it.image = NSWorkspace.shared.icon(forFile: url.path)
            it.image?.size = NSSize(width: 16, height: 16)
            menu.addItem(it)
        }
        menu.addItem(.separator())
        let clear = NSMenuItem(title: "Liste löschen", action: #selector(clearList(_:)), keyEquivalent: "")
        clear.target = self
        clear.isEnabled = !files.isEmpty
        menu.autoenablesItems = false
        menu.addItem(clear)
    }

    @objc func openRecent(_ sender: NSMenuItem) {
        guard let url = sender.representedObject as? URL else { return }
        AppController.shared.open(urls: [url])
    }

    @objc func clearList(_ sender: Any?) {
        Settings.shared.recentFiles = []
        NSDocumentController.shared.clearRecentDocuments(nil)
    }
}
