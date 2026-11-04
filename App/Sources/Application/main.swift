import AppKit

// Einstieg. `--selftest <Ordner>` startet den automatischen Oberflächentest (wird im CI-Build ausgeführt).
let app = NSApplication.shared
let appDelegate = AppDelegate()
app.delegate = appDelegate
app.run()
