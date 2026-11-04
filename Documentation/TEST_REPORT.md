# TEST_REPORT.md

Stand: 04.11.2026 · Phase 1. **Es gibt noch keinen Programmcode, daher keine Programmtests.** Geprüft wurden die Phase-1-Dokumente selbst.

## 1. Prüfung der Referenzanalyse

| Prüfung | Methode | Ergebnis |
|---|---|---|
| Doku vollständig geladen | Crawler über alle Links unter paint.net/doc/latest | 57 HTML-Seiten, 542 Bilder |
| Menüinventar vollständig | Texterkennung (Tesseract 5.3.4) aller Menü-Screenshots, Abgleich mit MENU_INVENTORY.md | alle Menüeinträge der Screenshots Datei, Bearbeiten, Ansicht, Bild, Ebenen, Korrekturen, Effekte (9 Untermenüs), Hilfe, Register-Kontextmenü, Palettenmenü enthalten |
| Korrekturen | Abgleich Menü-Screenshot ↔ Matrix | 13 von 13 (A-01 … A-13) |
| Effekte | Abgleich Untermenü-Screenshots ↔ Matrix | 40 von 40 (Künstlerisch 3, Unschärfe 10, Farbe 1, Verzerren 9, Rauschen 2, Objekt 1, Foto 6, Rendern 4, Stilisieren 4) |
| Werkzeuge | Abgleich ToolsWindow + Hauptfenster-Screenshot | 22 von 22 (T-10 … T-72) |
| Formen | Abgleich ShapeTools-Liste ↔ T-72 (Skript) | 29 von 29 |
| Mischmodi | Abgleich BlendModes + Werkzeug-Mischmodus-Screenshot | 14 + Überschreiben |
| Tastenkürzel | Skript: 135 Kürzel-Zellen der KeyboardMouseCommands-Seite gegen Matrix-Text; 87 wörtliche Treffer, die übrigen 48 (Modifikator-Gesten, Mehrfachtasten, Menü-Hotkeys) manuell als inhaltlich abgedeckt geprüft | vollständig; zusätzlich KEYMAP.md mit allen 256 Einträgen der Seite |
| Eindeutige IDs | build.py prüft doppelte IDs und Spaltenanzahl | 243 Einträge, keine Dubletten, je 11 Spalten |
| Keine erfundenen Standardwerte | Durchsicht: Werte nur aus Doku-Text oder als „Beispiel/Screenshot-Zustand“ gekennzeichnet | 72 Einträge mit „ungeklärt“ markiert |
| Konsistenz Mac-Kürzel | Abgleich Matrix ↔ MENU_INVENTORY ↔ KNOWN_ISSUES ↔ KEYMAP | ein Widerspruch gefunden (90° gegen Uhrzeigersinn: Cmd+G vs. Cmd+Option+←) und behoben |

## 2. Bekannte Lücken der Analyse

- Standardwerte, Wertebereiche und Schrittweiten aller Regler: **nicht in der Doku** → Referenzmessung nötig (KNOWN_ISSUES R-1).
- Kontextmenüs der Ebenenliste und der Zeichenfläche: nicht dokumentiert.
- Fehlermeldungstexte der Referenz: kaum dokumentiert (nur Speicherabfrage, Leinwand-vergrößern-Frage, Schlagschatten-Hinweis, Plugin-Fehler).
- Genaue Pixelmaße/Abstände der Oberfläche: nur aus Screenshots ableitbar; die Optik wird ohnehin eigenständig gestaltet.

## 3. Vorlage Referenzmessung (für eine Person mit Paint.NET 5.1.12 unter Windows)

Für jeden Dialog aus FUNCTION_MATRIX (A-xx, FX-xx, I-02, I-03, L-10, L-16, F-01, Speicherdialoge):

| Dialog | Parameter | Standard (nach „Zurücksetzen“) | Minimum | Maximum | Schrittweite/Dezimalen | Einheit | Bemerkung |
|---|---|---|---|---|---|---|---|
| z. B. Gaußscher Weichzeichner | Radius | | | | | px | |

Zusätzlich je Werkzeug: alle Optionen der zweiten Werkzeugleiste nach „Einstellungen › Werkzeuge › Zurücksetzen“. Dazu Referenzbilder: Testbild (wird mitgeliefert) mit jedem Effekt bei Standardwerten als PNG speichern – Grundlage für Bildvergleichstests mit Toleranzen.

## 4. Programmtests

Noch keine. Sobald Phase 2 begonnen hat, stehen hier je Test: ID, Anforderung, Ablauf, erwartetes/tatsächliches Ergebnis, Datum, Gerät, macOS-Version.
