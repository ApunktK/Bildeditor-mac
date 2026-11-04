# IMPLEMENTATION_STATUS.md

Stand: 04.11.2026 · Version 0.2.0 (Build 2) · **Phase 2 (Grundanwendung) weitgehend abgeschlossen** – Zwischenstand, keine Vollversion.

> Die App startet, verwaltet mehrere Bilder, öffnet und speichert, zeigt und zoomt, und alle Ebenen-, Bild- (Drehen/Spiegeln/Reduzieren) und Verlaufsbefehle arbeiten echt. **Malen, Auswahl, Korrekturen und Effekte gibt es noch nicht**; die zugehörigen Menüpunkte und Werkzeuge sind sichtbar, aber deaktiviert und mit Hinweis auf die geplante Phase versehen.
> „Getestet“ bedeutet in dieser Datei: automatisch geprüft im CI auf macOS 15.8 (Apple Silicon) – Kern-Tests, App-Tests und Selbsttest der fertig gebauten App (TEST_REPORT.md). Eine Bedienprobe von Hand am Mac des Nutzers steht noch aus.

## Phasen

| Phase | Inhalt | Status | Ergebnis |
|---|---|---|---|
| 1 Referenzanalyse | Funktionsmatrix, Menüinventar, Architektur, Lizenzprüfung | **abgeschlossen** (offene Referenzmessungen R-1 bis R-10) | FUNCTION_MATRIX.md (243 Funktionen), MENU_INVENTORY.md, ARCHITECTURE.md, SOURCE_CODE_ANALYSIS.md, THIRD_PARTY_LICENSES.md |
| 2 Grundanwendung | App, Hauptfenster, Menüs, Leisten, Register, Fenster, Zeichenfläche, Dateiverwaltung | **weitgehend abgeschlossen** – offen: Lineale, Einstellungsfenster, Lokalisierungsdateien | Bildeditor.app (Universal), DMG, Selbsttest 72/72 |
| 3 Bildbearbeitungsengine | Auswahl, Zeichnen, Maus, Alpha, Ausschneiden/Einfügen | nicht begonnen | – |
| 4 Werkzeuge | 22 Werkzeuge (umgesetzt: Zoom, Hand) | nicht begonnen | – |
| 5 Ebenen und Farben | Ebenen ✔ (vorgezogen), 14 Mischmodi ✔, Farbenfenster ✔ (Grundfunktion), Bildgröße/Leinwand, Drehen/Zoomen | teilweise vorgezogen | siehe Matrix L-xx, BM-01, C-xx |
| 6 Korrekturen und Effekte | 13 Korrekturen, 40 Effekte | nicht begonnen | – |
| 7 Formate und Projekte | Formate über ImageIO ✔ (PNG, JPEG, BMP, TIFF, GIF, HEIC, TGA); natives Projekt, PDN, Farbprofil, Scanner | teilweise vorgezogen | siehe Matrix FMT-xx |
| 8 Einstellungen und Plugins | Einstellungen, Plugins | nicht begonnen | – |
| 9 Qualitätssicherung | Bildvergleich, Performance, Regression | Grundlage steht (CI mit Selbsttest) | – |
| 10 Release | Signierung, Notarisierung, Installationsprüfung | offen (B-2) | – |

## Funktionsstatus (aus FUNCTION_MATRIX.md, Spalte „Status“)

| Status-Stufe | Anzahl |
|---|---|
| implementiert und getestet | 49 |
| implementiert, aber noch nicht getestet | 41 |
| teilweise implementiert | 14 |
| nicht implementiert | 139 |
| technisch nicht möglich | 0 (Kandidaten: JPEG XR FMT-06, WebP-Schreiben FMT-13 über ImageIO) |
| wegen fehlender Referenz ungeklärt | 73 Einträge enthalten ungeklärte Teilaspekte |

Menübefehle laut Befehlstabelle der App: **57 von 133 umgesetzt**; die übrigen 76 sind deaktiviert (vom Selbsttest geprüft) und tragen ihre geplante Phase im Tooltip.

## Was funktioniert (Phase 2)

- **Hauptfenster:** Werkzeugleiste (Neu, Öffnen, Speichern, Drucken, Kopieren, Rückgängig/Wiederholen, Pixelraster, vier Fensterschalter), zweite Zeile mit Werkzeugliste, Bildregister mit Live-Miniaturen, Schließknopf, Änderungsmarke und Kontextmenü (Pfad kopieren, Im Finder zeigen, Speichern, Speichern unter, Schließen), Statusleiste (Hinweis, Bildgröße, Mausposition auch außerhalb des Bildes, Maßeinheit px/Zoll/cm, Zoomfeld mit Eingabe, Schnellgröße, logarithmischer Zoomregler, ± Knöpfe).
- **Zeichenfläche:** Schachbrett für Transparenz, zentriert, Bildlauf, Zoom 1–6400 % (feste Stufen, ⌘+Mausrad, Trackpad-Geste, Zoom-Werkzeug mit Klick/Rechtsklick/⌥-Klick/Rahmen), Hand-Werkzeug, Leertaste = Hand, mittlere Maustaste verschiebt, Pixelraster ab 200 %, Ziehen von Bilddateien öffnet sie.
- **Fenster:** Werkzeuge, Verlauf, Ebenen, Farben – schwebend, Lage und Sichtbarkeit gespeichert, F5–F8, „Fensterpositionen zurücksetzen“.
- **Verlauf:** jede Aktion ein Eintrag, Sprung per Klick, erneuter Klick wechselt zum vorherigen Eintrag, rückgängig gemachte Einträge grau.
- **Ebenen:** neu, löschen, duplizieren, nach unten zusammenführen, ein-/ausblenden, aus Datei importieren, spiegeln, 180°, aktive Ebene wechseln (vier Befehle), verschieben (vier Befehle, ⌘-Klick, Ziehen in der Liste), Eigenschaften mit Live-Vorschau (Name, Sichtbar, 14 Mischmodi, Deckkraft 0–255).
- **Bild:** horizontal/vertikal spiegeln, 90° rechts/links, 180°, auf eine Ebene reduzieren.
- **Farben:** Primär/Sekundär mit aktivem Feld, Tauschen (X), aktives Feld wechseln (C), Schwarz/Weiß, Farbrad (Links-/Rechtsklick, ⇧/⌃/⌥), RGB/HSV/Deckkraft-Regler, Hex, Palette 32/96.
- **Datei:** Neu (Dialog mit Seitenverhältnis, Auflösung, Druckgröße, Speicherbedarf, Grenzen), Öffnen (mehrere, Finder, Kaltstart, „Zuletzt geöffnet“ mit 10 Einträgen), Speichern / Speichern unter (Formatwahl, JPEG/HEIC-Qualität), Alle speichern, Drucken, Schließen und Beenden mit Rückfrage.
- **Zwischenablage:** Kopieren (ganze Ebene), Zusammengefügt kopieren, In neue Ebene einfügen (mit Leinwand-Rückfrage), In neues Bild einfügen.
- **Build:** Universal (arm64 + x86_64), ad-hoc signiert, Hardened Runtime, DMG mit Verknüpfung „Programme“.

## Nächste Schritte

1. Bedienprobe von Hand auf dem Mac des Nutzers (DMG aus diesem Stand).
2. Phase 3: Auswahlmodell (Rechteck/Ellipse/Lasso/Zauberstab-Grundlage, Ameisenlinie), Ausschneiden/Einfügen/Löschen/Füllen, Zuschneiden, Lineale.
3. Phase 4: Malwerkzeuge (Pinsel, Stift, Radierer, Farbeimer, Pipette, Verlauf, Linie, Formen, Text, Kopierstempel, Umfärben).
4. Referenzmessung (R-1) für Standardwerte, sobald jemand Paint.NET 5.1.12 unter Windows bedienen kann.
