# Bildeditor für macOS

Eigenständiger, nativer Bildeditor für macOS (Swift, AppKit), dessen Bedienung sich an Paint.NET 5.1.12 orientiert. Kein Bestandteil von Paint.NET; keine Verbindung zu dotPDN LLC.

**Stand:** Version 0.2.0 – Phase 2 (Grundanwendung). Öffnen, Speichern, Zoom, Ebenen, Verlauf, Drehen/Spiegeln und Farbenfenster funktionieren; Malwerkzeuge, Auswahl, Korrekturen und Effekte folgen. Details: [Documentation/IMPLEMENTATION_STATUS.md](Documentation/IMPLEMENTATION_STATUS.md).

## Installation
1. `Bildeditor.dmg` öffnen und „Bildeditor“ auf „Programme“ ziehen.
2. Die App ist **nicht notarisiert** (keine Apple-Developer-ID). Beim ersten Start meldet macOS, dass die App nicht geprüft werden kann: Systemeinstellungen › Datenschutz & Sicherheit › „Dennoch öffnen“ wählen (einmalig).
3. Voraussetzung: macOS 13 oder neuer, Apple Silicon oder Intel.

## Bauen
Jeder Push baut über GitHub Actions (`.github/workflows/build.yml`): Kern-Tests, Universal-Build, App-Tests, Selbsttest mit Bildschirmfotos, DMG. Lokal auf einem Mac: `brew install xcodegen && xcodegen generate`, dann `Bildeditor.xcodeproj` in Xcode öffnen.
