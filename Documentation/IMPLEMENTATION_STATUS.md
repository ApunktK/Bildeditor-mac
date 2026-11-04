# IMPLEMENTATION_STATUS.md

Stand: 04.11.2026 · **Phase 1 (Referenzanalyse) abgeschlossen**, Phase 2 noch nicht begonnen.

> Es existiert noch kein Programmcode. Keine Funktion ist implementiert. Diese Datei ist **keine** Vollversion und kein Prototyp.

## Phasen

| Phase | Inhalt | Status | Ergebnis |
|---|---|---|---|
| 1 Referenzanalyse | Funktionsmatrix, Menüinventar, Werkzeuganalyse, Screenshot-Referenzen, Architektur, Lizenzprüfung | **abgeschlossen** (mit offenen Referenzmessungen R-1 bis R-10) | FUNCTION_MATRIX.md (243 Funktionen), MENU_INVENTORY.md, ARCHITECTURE.md, SOURCE_CODE_ANALYSIS.md, THIRD_PARTY_LICENSES.md, REFERENCE_SCREENSHOTS.md |
| 2 Grundanwendung | App, Hauptfenster, Menüs, Leisten, Register, Panels, Zeichenfläche, Dateiverwaltung | **blockiert** durch B-1 (keine Mac-Build-Umgebung) | – |
| 3 Bildbearbeitungsengine | Raster, Zeichnen, Auswahl, Maus, Undo, Alpha | nicht begonnen | – |
| 4 Werkzeuge | 22 Werkzeuge | nicht begonnen | – |
| 5 Ebenen und Farben | Ebenen, 14 Mischmodi, Farbenfenster, Transformationen | nicht begonnen | – |
| 6 Korrekturen und Effekte | 13 Korrekturen, 40 Effekte, GPU, Vorschau | nicht begonnen | – |
| 7 Formate und Projekte | 13 Formate, natives Projekt, PDN, Druck | nicht begonnen | – |
| 8 Einstellungen und Plugins | Einstellungen, Fensterpositionen, Plugins | nicht begonnen | – |
| 9 Qualitätssicherung | Funktions-, Bild-, UI-, Performance-, Regressionstests | nicht begonnen | – |
| 10 Release | Build, DMG, Installationsprüfung, Doku | nicht begonnen | – |

## Funktionsstatus (Zusammenfassung aus FUNCTION_MATRIX.md)

| Status-Stufe | Anzahl |
|---|---|
| implementiert und getestet | 0 |
| implementiert, aber noch nicht getestet | 0 |
| teilweise implementiert | 0 |
| nicht implementiert | 243 |
| technisch nicht möglich | 0 (Kandidaten: JPEG XR FMT-06, Updates S-07 ohne Server – Prüfung in Phase 7/8) |
| wegen fehlender Referenz ungeklärt | 72 Einträge enthalten ungeklärte Teilaspekte (zusätzlich zu „nicht implementiert“) |

## Nächste Schritte

1. Build-Weg festlegen (KNOWN_ISSUES B-1).
2. Referenzmessung an Paint.NET 5.1.12 (KNOWN_ISSUES R-1): Standardwerte und Grenzen aller Dialoge.
3. Phase 2 starten: Xcode-Projekt, Modulgerüst, Hauptfenster mit Panels, Menüs (alle Einträge vorhanden, nicht implementierte deaktiviert und in dieser Datei geführt).
