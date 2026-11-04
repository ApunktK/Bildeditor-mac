import AppKit

/// Die vier schwebenden Fenster der Referenz.
enum PanelID: String, CaseIterable {
    case tools, history, layers, colors

    var title: String {
        switch self { case .tools: return "Werkzeuge"; case .history: return "Verlauf"; case .layers: return "Ebenen"; case .colors: return "Farben" }
    }
    var symbol: String {
        switch self {
        case .tools: return "hammer"
        case .history: return "clock.arrow.circlepath"
        case .layers: return "square.3.layers.3d"
        case .colors: return "paintpalette"
        }
    }
    var autosaveName: String { "Fenster.\(rawValue)" }
}

/// Erzeugt, zeigt und positioniert die schwebenden Fenster; Lage und Sichtbarkeit bleiben gespeichert.
final class PanelManager: NSObject, NSWindowDelegate {
    private(set) var panels: [PanelID: EditorPanel] = [:]
    private(set) var controllers: [PanelID: NSViewController] = [:]
    private weak var mainWindow: NSWindow?

    init(mainWindow: NSWindow) {
        self.mainWindow = mainWindow
        super.init()
        for id in PanelID.allCases { create(id) }
    }

    private func create(_ id: PanelID) {
        let vc: NSViewController
        switch id {
        case .tools: vc = ToolsPanelController()
        case .history: vc = HistoryPanelController()
        case .layers: vc = LayersPanelController()
        case .colors: vc = ColorsPanelController()
        }
        let resizable = id == .history || id == .layers
        var style: NSWindow.StyleMask = [.titled, .closable, .utilityWindow]
        if resizable { style.insert(.resizable) }
        let p = EditorPanel(contentRect: NSRect(origin: .zero, size: vc.view.fittingSize), styleMask: style, backing: .buffered, defer: false)
        p.title = id.title
        p.contentViewController = vc
        p.isFloatingPanel = true
        p.hidesOnDeactivate = true
        p.becomesKeyOnlyIfNeeded = true
        p.isReleasedWhenClosed = false
        p.delegate = self
        p.identifier = NSUserInterfaceItemIdentifier(id.rawValue)
        if resizable { p.minSize = NSSize(width: 200, height: 160) }
        p.setFrame(defaultFrame(id, panel: p), display: false)
        p.setFrameUsingName(id.autosaveName)
        p.setFrameAutosaveName(id.autosaveName)
        panels[id] = p
        controllers[id] = vc
    }

    /// Anordnung wie in der Referenz: Werkzeuge links oben, Farben links unten, Verlauf rechts oben, Ebenen rechts unten.
    func defaultFrame(_ id: PanelID, panel: NSPanel) -> NSRect {
        let host = mainWindow?.frame ?? NSScreen.main?.visibleFrame ?? NSRect(x: 0, y: 0, width: 1280, height: 800)
        let size: NSSize
        switch id {
        case .tools: size = panel.frame.size
        case .colors: size = panel.frame.size
        case .history: size = NSSize(width: 240, height: 260)
        case .layers: size = NSSize(width: 240, height: 280)
        }
        let top = host.maxY - 170   // unter Titelleiste, Werkzeugleiste und Register
        let bottom = host.minY + 40  // über der Statusleiste
        switch id {
        case .tools: return NSRect(x: host.minX + 12, y: top - size.height, width: size.width, height: size.height)
        case .colors: return NSRect(x: host.minX + 12, y: bottom, width: size.width, height: size.height)
        case .history: return NSRect(x: host.maxX - size.width - 12, y: top - size.height, width: size.width, height: size.height)
        case .layers: return NSRect(x: host.maxX - size.width - 12, y: bottom, width: size.width, height: size.height)
        }
    }

    func showInitial() {
        for id in PanelID.allCases where Settings.shared.panelVisible(id.rawValue) { panels[id]?.orderFront(nil) }
        NotificationCenter.default.post(name: .panelVisibilityChanged, object: nil)
    }

    func isVisible(_ id: PanelID) -> Bool { panels[id]?.isVisible ?? false }

    func toggle(_ id: PanelID) {
        guard let p = panels[id] else { return }
        if p.isVisible { p.orderOut(nil) } else { p.orderFront(nil) }
        Settings.shared.setPanelVisible(id.rawValue, p.isVisible)
        NotificationCenter.default.post(name: .panelVisibilityChanged, object: nil)
    }

    /// „Fensterpositionen zurücksetzen“: Standardlage und alle Fenster sichtbar.
    func resetPositions() {
        for id in PanelID.allCases {
            guard let p = panels[id] else { continue }
            p.setFrame(defaultFrame(id, panel: p), display: true, animate: false)
            p.saveFrame(usingName: id.autosaveName)
            p.orderFront(nil)
            Settings.shared.setPanelVisible(id.rawValue, true)
        }
        NotificationCenter.default.post(name: .panelVisibilityChanged, object: nil)
    }

    func windowWillClose(_ notification: Notification) {
        guard let p = notification.object as? NSPanel, let raw = p.identifier?.rawValue else { return }
        Settings.shared.setPanelVisible(raw, false)
        DispatchQueue.main.async { NotificationCenter.default.post(name: .panelVisibilityChanged, object: nil) }
    }
}
