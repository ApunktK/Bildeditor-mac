# RELEASE_CHECKLIST.md

Jeder Punkt wird erst abgehakt, wenn er praktisch geprüft ist. Stand: Phase 2 (0.2.0) – erfüllte Punkte sind praktisch im CI geprüft.

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
- [x] Keine Windows-Komponenten (nur AppKit, ImageIO, Accelerate)

## Build und Paket (Abschnitt 30)
- [x] Xcode-Release-Build ohne Compiler-Warnungen (CI 04.11.2026; nur Hinweis des AppIntents-Werkzeugs)
- [x] Universal-Binary (`lipo -info` zeigt arm64 und x86_64) – CI-Lauf 04.11.2026
- [ ] Info.plist: Name, Version, Build, Bundle-ID, Mindest-macOS, Dateitypen, UTTypes
- [x] Eigenes App-Icon (alle Größen 16–1024)
- [x] Entitlements geprüft (Sandbox aus, begründet in KNOWN_ISSUES A-10)
- [x] Signiert (Developer ID) – **oder** dokumentiert ad-hoc → ad-hoc (B-2)
- [x] Notarisiert und gestapelt (`stapler validate`) – **oder** dokumentiert „nicht notarisiert“ → **nicht notarisiert**
- [ ] DMG: App-Symbol, Verknüpfung „Programme“, Drag-&-Drop-Installation (gebaut und `hdiutil verify` ok; Installation noch nicht von Hand geprüft)
- [ ] DMG auf sauberem Mac installiert und gestartet (Apple Silicon)
- [ ] Start auf Intel-Mac bzw. unter Rosetta geprüft

## Qualität (Abschnitt 29)
- [ ] Unit-, Integrations-, UI-, Bildvergleichs-, Format-, Speicher-, Wiederherstellungs-, Regressionstests grün
- [ ] Performance-Messungen (1920×1080 bis 10000×10000) mit echten Werten im TEST_REPORT
- [ ] UI-Vergleich mit Referenzscreenshots, Unterschiede dokumentiert
- [ ] TEST_REPORT.md vollständig, KNOWN_ISSUES.md aktuell

## Recht
- [ ] THIRD_PARTY_LICENSES.md vollständig, alle Hinweise in „Über“ sichtbar
- [x] Keine Paint.NET-Marke, -Icons, -Texte, -Grafiken im Bundle (Name nur im Lizenz-/Abgrenzungshinweis)
