# REQUIREMENTS.md

Verbindliche Anforderungen aus dem Master-Prompt (Abschnitte 1–37) und der Quellcode-Vorgabe (Abschnitt 38), verdichtet und nummeriert. Jede Anforderung wird in IMPLEMENTATION_STATUS.md und TEST_REPORT.md mit ihrer ID geführt. Funktionsdetails stehen in FUNCTION_MATRIX.md.

## R-GEN – Grundsätze (Abschnitt 1, 33, 34)
- R-GEN-01 Eigenständige macOS-Desktop-App, die die typischen Arbeitsabläufe von Paint.NET 5.1.12 ermöglicht.
- R-GEN-02 Jeder Button, Menüeintrag, Dialogwert und jedes Werkzeug hat eine echte, sichtbare Wirkung; keine Platzhalter, keine simulierten Erfolge.
- R-GEN-03 Vollständig deutsche Oberfläche, Texte zentral lokalisierbar (Abschnitt 27).
- R-GEN-04 Läuft als .app und wird als .dmg (Drag-&-Drop-Installation, Programme-Verknüpfung) geliefert (Abschnitt 30).
- R-GEN-05 Ohne Windows, Wine, VM, Web, Electron, Cloud oder Server; nach Installation keine Entwicklungsumgebung nötig.
- R-GEN-06 Stabilität, Geschwindigkeit und Präzision vor Zusatzfunktionen.
- R-GEN-07 Keine proprietären Paint.NET-Bestandteile (Code, Icons, Logos, Texte); eigene Gestaltung (Abschnitt 1, 38.5).
- R-GEN-08 Funktion gilt nur als fertig, wenn implementiert, praktisch geprüft und getestet; Status-Stufen nach Abschnitt 34.
- R-GEN-09 Fehlende/technisch unmögliche Funktionen werden ausdrücklich aufgeführt.

## R-REF – Referenzanalyse (Abschnitt 2)
- R-REF-01 Offizielle Doku inkl. Unterseiten auswerten. → erledigt (57 Seiten).
- R-REF-02 Funktionsmatrix mit allen geforderten Feldern; Ungeklärtes kennzeichnen, keine erfundenen Standardwerte. → FUNCTION_MATRIX.md.
- R-REF-03 Abgleich mit der echten Windows-Anwendung (Screenshots, Testinstallation). → offen (KNOWN_ISSUES R-1).

## R-ARC – Technik (Abschnitt 3, 31)
- R-ARC-01 Swift, AppKit, SwiftUI nur untergeordnet, Metal, Core Image (nur referenzkonform), Core Graphics, ImageIO, Core Text, vImage, UTType, macOS-Dateidialoge.
- R-ARC-02 19 getrennte Module, Datenmodell getrennt von UI; keine Bilddaten in UI-Objekten.
- R-ARC-03 Universal-App arm64 + x86_64; Mindest-macOS begründet dokumentiert.
- R-ARC-04 Retina-korrekt; keine blockierenden Operationen auf dem Hauptthread.
- R-ARC-05 Fremdbibliotheken nur mit passender Lizenz und nachweisbarem Vorteil (THIRD_PARTY_LICENSES.md).

## R-UI – Oberfläche (Abschnitt 4–6, 22, 35)
- R-UI-01 Helles, kompaktes klassisches Desktop-Design; kein Liquid-Glass/Dashboard-Stil.
- R-UI-02 Aufbau: Titel, Menüs, Symbolleiste, kontextabhängige Werkzeugoptionen, Bildregister mit Miniaturen; Zeichenfläche mit grauem Rand, Schachbrett, Scrollleisten, Zoom; schwebende Fenster Werkzeuge (links), Verlauf (rechts oben), Ebenen (rechts unten), Farben (links unten); Statusleiste.
- R-UI-03 Fenster verschiebbar, ein-/ausblendbar, Zustand persistent, Befehl „Fensterpositionen zurücksetzen“.
- R-UI-04 Alle Zustände je Bedienelement (Hover, aktiv, deaktiviert, Fokus, Tooltip, Kontextmenü, Doppelklick) definiert.
- R-UI-05 Werkzeugleiste mit den 21 Aktionen aus Abschnitt 6, Tooltips, korrekt deaktiviert.
- R-UI-06 Statusleiste: Bildgröße, Cursor in Bildkoordinaten, Auswahlgröße, Zoom, Hinweise, Fortschritt.
- R-UI-07 Paint.NET-Nutzer finden Werkzeuge und Fenster an vergleichbarer Stelle (Abschnitt 35).

## R-DOC – Dokumente (Abschnitt 5)
- R-DOC-01 Mehrdokument-Oberfläche: je Dokument eigene Ebenen, Verlauf, Zoom, Auswahl, Datei, Änderungsstatus.
- R-DOC-02 Register mit Live-Miniatur, wechseln, verschieben, schließen; Mehrfachöffnen, Drag & Drop.
- R-DOC-03 Kein Datenverlust beim Schließen/Beenden.

## R-TOOL – Werkzeuge (Abschnitt 7, 8)
- R-TOOL-01 Alle 22 Standardwerkzeuge mit eigenem Symbol, Mauszeiger, Optionen, Vorschau, Auswahl-Clipping, Undo, Alpha-Korrektheit, hoher Zoom, flüssiger Eingabe.
- R-TOOL-02 Auswahlwerkzeuge mit 5 Kombinationsmodi, feste Größe/Verhältnis, Zauberstab mit Toleranz, Flut-/Sampling-/Alpha-Modi.
- R-TOOL-03 Verschiebewerkzeuge mit Skalieren, Drehen, Kopie, Resampling-Modi.
- R-TOOL-04 Zeichen-, Füll-, Foto-, Text-, Linien- und Formwerkzeuge laut Matrix (29 Formen).
- R-TOOL-05 Kontextabhängige zweite Werkzeugleiste; Werte je Werkzeug gemerkt.

## R-LAY – Ebenen (Abschnitt 9, 17)
- R-LAY-01 Ebene mit ID, Name, Bild, Sichtbarkeit, Deckkraft, Mischmodus, Position, Miniatur.
- R-LAY-02 Ebenenfenster mit allen Symbolen, Drag & Drop, Doppelklick = Eigenschaften.
- R-LAY-03 Alle Ebenenbefehle inkl. Import, Spiegeln, Drehen/Zoomen (Abbrechen ohne Änderung), Reduzieren.
- R-LAY-04 14 Mischmodi mathematisch korrekt inkl. Alpha.

## R-HIS – Verlauf (Abschnitt 10)
- R-HIS-01 Jede abgeschlossene Aktion im Verlaufsfenster; Sprung, mehrere Schritte, Tastatur.
- R-HIS-02 Differenzielle Speicherung, je Dokument, abgebrochene Aktionen erzeugen keinen Eintrag.

## R-COL – Farben (Abschnitt 11)
- R-COL-01 Primär/Sekundär, Tauschen, Standard, Farbrad, Palette (96), Hex, RGB, HSV, Alpha, eigene Paletten, kompakt/erweitert; synchron mit Werkzeugen.

## R-MENU – Menüs (Abschnitt 12, 14–19)
- R-MENU-01 Datei, Bearbeiten, Ansicht, Bild, Ebenen, Korrekturen (13), Effekte (40 in 9 Gruppen) laut Matrix.
- R-MENU-02 Dialoge Neues Bild, Größe ändern, Leinwandgröße mit allen Feldern und Umrechnung.
- R-MENU-03 Resampling-Methoden der Referenz (8 bei Größe ändern), Alpha-korrekt.
- R-MENU-04 Zwischenablage innerhalb, zwischen Dokumenten und mit anderen Mac-Programmen, mit Transparenz.

## R-FX – Korrekturen/Effekte (Abschnitt 18–20)
- R-FX-01 Jede Korrektur/jeder Effekt: aktive Ebene, Auswahlmaske, Parameter, Live-Vorschau, abbrechbar ohne Änderung, ein Verlaufseintrag, große Bilder stabil, Alpha korrekt, möglichst GPU.
- R-FX-02 Nicht-destruktive Vorschau; ältere Berechnungen überschreiben neuere nicht.
- R-FX-03 Letzten Effekt wiederholen (Cmd+F).
- R-FX-04 Einheitliches Dialogschema: Regler ↔ Zahlenfeld synchron, Grenzen, Zurücksetzen, OK/Abbrechen, Enter/Esc.

## R-KEY – Tastatur/Maus (Abschnitt 21)
- R-KEY-01 Mac-Grundbefehle laut Abschnitt 21; weitere Paint.NET-Kürzel übertragen; Konflikte vermeiden (KNOWN_ISSUES K).
- R-KEY-02 Optionaler Windows-Belegungsmodus.
- R-KEY-03 Maus (links, rechts, Doppelklick, Rad, Mitte, Modifikatoren), Trackpad (Scrollen, Pinch, kein versehentliches Bearbeiten).

## R-FMT – Formate (Abschnitt 13)
- R-FMT-01 PNG, JPEG, BMP, GIF, TIFF, TGA, WebP, AVIF, HEIC, JPEG XL, JPEG XR, DDS, PDN – je Lesen/Schreiben/Transparenz/Farbtiefe/Metadaten/Kompression/Qualität geprüft.
- R-FMT-02 PDN-Import mit Ebenen, Namen, Sichtbarkeit, Deckkraft, Mischmodus, Größe, Pixel, Transparenz; Schreiber, wenn verlustfrei gesichert.
- R-FMT-03 Eigenes natives Projektformat; teilweise unterstützte PDN-Dateien nie stillschweigend überschreiben.
- R-FMT-04 Speichern: Formatwahl, Qualität, Transparenz, Metadaten, sicheres Schreiben, Rechtefehler, Überschreiben bestätigen, Endungen.
- R-FMT-05 Drucken mit macOS-Druckdialog, Vorschau, Papier, Ausrichtung, Skalierung, Rändern.

## R-SET – Einstellungen (Abschnitt 23)
- R-SET-01 Bereiche Allgemein, Oberfläche, Werkzeuge, Grafik, Eingabegeräte, Dateiverwaltung; persistent; „Standardwerte wiederherstellen“.

## R-PLG – Plugins (Abschnitt 24)
- R-PLG-01 Eigene Schnittstelle für Effekte, Korrekturen, Formate: Erkennung, (De-)Aktivierung, Versionsprüfung, Fehlerprotokoll, sichere Fehlerbehandlung; keine falsche Paint.NET-Kompatibilität.

## R-PERF – Leistung (Abschnitt 25)
- R-PERF-01 GPU-Komposition, Kacheln, inkrementelle Updates, minimale Kopien.
- R-PERF-02 Sofortige Reaktion bei Werkzeug-/Register-/Ebenen-/Farb-/Zoomwechsel.
- R-PERF-03 Messung bei 1920×1080, 3840×2160, 6000×4000, 10000×10000; keine erfundenen Leistungsangaben.

## R-STAB – Stabilität (Abschnitt 26)
- R-STAB-01 Kein Datenverlust bei defekten Dateien, Speichermangel, fehlenden Rechten, getrennten Laufwerken, Plugin-Fehlern, Abbruch.
- R-STAB-02 Autosave, Absturz-Wiederherstellung, sicheres Speichern über temporäre Dateien.

## R-QA – Qualität (Abschnitt 28, 29)
- R-QA-01 Testfälle für alle Werkzeuge, Menüs, Dialoge, Tastaturaktionen (Beispiele A–E).
- R-QA-02 Unit-, Integrations-, UI-, Bildvergleichs-, Import/Export-, Speicher-, Wiederherstellungs-, Regressions-, Performancetests; Toleranzen dokumentiert; UI-Vergleich mit Referenzscreenshots.

## R-REL – Auslieferung (Abschnitt 30, 32, 36)
- R-REL-01 Xcode-Projekt, Universal-Release-Build, Info.plist, eigenes App-Icon, Dateitypzuordnungen, Versionsinfo, Berechtigungen, DMG.
- R-REL-02 Signierung/Notarisierung, falls möglich; sonst klar dokumentiert.
- R-REL-03 Phasen 1–10; Zwischenversionen nie als Vollversion bezeichnen.
- R-REL-04 Laufend gepflegte Dateien: REQUIREMENTS, FUNCTION_MATRIX, ARCHITECTURE, IMPLEMENTATION_STATUS, TEST_REPORT, KNOWN_ISSUES, RELEASE_CHECKLIST.

## R-SRC – Quellcode-Wiederverwendung (Abschnitt 38)
- R-SRC-01 Vorhandenen, rechtlich nutzbaren Code bevorzugen; Herkunft und Lizenz je Datei dokumentiert. → SOURCE_CODE_ANALYSIS.md, THIRD_PARTY_LICENSES.md.
