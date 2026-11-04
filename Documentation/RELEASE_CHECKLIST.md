# RELEASE_CHECKLIST.md

Jeder Punkt wird erst abgehakt, wenn er praktisch geprüft ist. Stand: Phase 1 – keine Punkte erfüllt.

## Funktion (Abschnitt 34)
- [ ] Funktionsmatrix vollständig bearbeitet (jede Zeile hat einen Endstatus)
- [ ] Alle zugesagten Werkzeuge funktionieren (22)
- [ ] Alle Menüeinträge reagieren korrekt
- [ ] Alle Dialoge verarbeiten Werte korrekt (Regler ↔ Zahlenfeld, Grenzen, Enter/Esc)
- [ ] Ebenen zuverlässig (inkl. 14 Mischmodi)
- [ ] Korrekturen (13) und Effekte (40) verändern echte Bilddaten; Abbrechen ändert nichts
- [ ] Undo/Redo zuverlässig, je Dokument
- [ ] Speichern/Öffnen ohne Datenverlust (natives Format, PDN-Import)
- [ ] Alle unterstützten Formate getestet (Lesen/Schreiben/Alpha/Metadaten)
- [ ] Oberfläche vollständig deutsch (automatischer Test auf unübersetzte Strings)
- [ ] Stabil in normalen Abläufen (Beispiele A–E, Langlauftest)
- [ ] Keine Windows-Komponenten

## Build und Paket (Abschnitt 30)
- [ ] Xcode-Release-Build ohne Warnungen
- [ ] Universal-Binary (`lipo -info` zeigt arm64 und x86_64)
- [ ] Info.plist: Name, Version, Build, Bundle-ID, Mindest-macOS, Dateitypen, UTTypes
- [ ] Eigenes App-Icon (alle Größen)
- [ ] Entitlements geprüft (Sandbox ja/nein begründet)
- [ ] Signiert (Developer ID) – **oder** dokumentiert ad-hoc
- [ ] Notarisiert und gestapelt (`stapler validate`) – **oder** dokumentiert „nicht notarisiert“
- [ ] DMG: App-Symbol, Verknüpfung „Programme“, Drag-&-Drop-Installation
- [ ] DMG auf sauberem Mac installiert und gestartet (Apple Silicon)
- [ ] Start auf Intel-Mac bzw. unter Rosetta geprüft

## Qualität (Abschnitt 29)
- [ ] Unit-, Integrations-, UI-, Bildvergleichs-, Format-, Speicher-, Wiederherstellungs-, Regressionstests grün
- [ ] Performance-Messungen (1920×1080 bis 10000×10000) mit echten Werten im TEST_REPORT
- [ ] UI-Vergleich mit Referenzscreenshots, Unterschiede dokumentiert
- [ ] TEST_REPORT.md vollständig, KNOWN_ISSUES.md aktuell

## Recht
- [ ] THIRD_PARTY_LICENSES.md vollständig, alle Hinweise in „Über“ sichtbar
- [ ] Keine Paint.NET-Marke, -Icons, -Texte, -Grafiken im Bundle
