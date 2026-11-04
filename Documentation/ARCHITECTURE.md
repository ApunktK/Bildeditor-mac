# ARCHITECTURE.md

Stand: Phase 1 (Referenzanalyse), 04.11.2026. Diese Datei beschreibt die geplante Architektur. Noch ist kein Code geschrieben; nichts davon ist gebaut oder getestet.

## 1. Grundentscheidungen

| Thema | Entscheidung | Begründung |
|---|---|---|
| Sprache/UI | Swift 6, AppKit für Hauptfenster, Menüs, Panels, Dialoge; SwiftUI nur für einfache Dialoginhalte (z. B. Einstellungsseiten) | Projektvorgabe 3; AppKit gibt die nötige Kontrolle über schwebende Panels, Tastatur und Maus |
| Rendering | Metal (Komposition, Effekte, Anzeige), Core Image nur dort, wo das Ergebnis der Referenz entspricht | Projektvorgabe 3/25 |
| Pixelformat intern | 8 Bit je Kanal, BGRA, **nicht vormultipliziert** (wie Paint.NET/PDN), Kacheln 256×256 | Kompatibel mit PDN-Format und den Paint.NET-3.36-Formeln (Mischmodi, Radierer „RGB bleibt bei Alpha 0“). Für Filter wird intern bei Bedarf in Float/vormultipliziert umgerechnet |
| Architektur | Swift Packages je Modul; App-Target nur als Hülle | klare Grenzen, einzeln testbar |
| Algorithmen-Quelle | Ports aus Paint.NET 3.36 und Pinta (MIT), siehe SOURCE_CODE_ANALYSIS.md | keine Neuerfindung bewährter Verfahren |
| Mindest-macOS | **macOS 13 Ventura** (vorläufig) | ImageIO liest AVIF ab 13; Metal 3 verfügbar; deckt Intel-Macs ab 2017 und alle Apple-Silicon-Macs. JPEG XL (ImageIO erst ab 14) über libjxl. Endgültig festlegen, wenn alle APIs feststehen |
| Zielarchitekturen | Universal (arm64 + x86_64) | Projektvorgabe 3 |
| Build | Xcode-Projekt + `xcodebuild`; DMG per `hdiutil` | Projektvorgabe 30 |

## 2. Module (Projektvorgabe 3 und 31)

```
PaintEditorMac/
├─ Application/      App-Lebenszyklus, AppDelegate, Menüaufbau, Tastenbelegung (Mac + Windows-Modus)
├─ Core/             Geometrie, Farbe (ColorBgra), Kachel-Bitmaps, Fehler, Logging, Lokalisierung-Helfer
├─ Documents/        Dokumentmodell, Dokumentliste, Register, Änderungsstatus, Autosave
├─ Rendering/        Metal-Gerät, Kachelcache, Komposition, Canvas-Anzeige, Overlays (Raster, Lineale, Ameisen)
├─ Layers/           Ebene, Ebenenstapel, Eigenschaften, Mischmodi (CPU-Referenz + Metal)
├─ Selection/        Auswahlgeometrie (Polygone, Clipper2), Rastermaske (AA), Kombinationsmodi, JSON-Import/Export
├─ Tools/            Werkzeugprotokoll, 22 Werkzeuge, Werkzeugoptionen, Pinsel-Engine, Formenbibliothek
├─ History/          Verlaufsstapel, Mementos (Kachel-Diffs), Auslagerung auf Platte
├─ Colors/           Primär/Sekundär, Farbrad, Paletten (Paint.NET-.txt kompatibel), ICC über ColorSync
├─ Adjustments/      13 Korrekturen (Kernels + Dialogbeschreibungen)
├─ Effects/          40 Effekte, Effekt-Engine (Vorschau, Abbruch, Wiederholen)
├─ FileFormats/      ImageIO-Brücke, PDN-Leser/-Schreiber (NRBF), natives Projektformat, TGA, DDS, WebP, JXL, AVIF
├─ Plugins/          Plugin-Schnittstelle (Bundles), Versionsprüfung, Fehlerprotokoll
├─ Printing/         NSPrintOperation, Seitenlayout
├─ UI/               Hauptfenster, Werkzeugleisten, Panels (Werkzeuge, Verlauf, Ebenen, Farben), Dialog-Baukasten, Statusleiste
├─ Settings/         Einstellungsmodell, Persistenz, Einstellungsfenster
├─ Resources/        eigene Icons (Vektor/SF-Symbols-ähnlich, eigenständig gestaltet), Formen-Geometrien, Paletten
├─ Localization/     String Catalog (de, später weitere)
├─ Tests/            Unit, Integration, Bildvergleich, UI-Tests, Performance
├─ Packaging/        Info.plist, Entitlements, DMG-Skript, Notarisierung
└─ Documentation/    diese Dateien
```

Abhängigkeitsregel: `Core` ← alle; `Layers`, `Selection`, `History` ← `Documents`; `Rendering` kennt nur Datenmodelle; `UI` greift nur über `Documents`-Befehle auf Bilddaten zu (keine Bilddaten in UI-Objekten, Projektvorgabe 3).

## 3. Datenmodell

- **Document**: `id`, Größe, DPI, Farbprofil, `LayerStack`, `Selection`, `History`, `ViewState` (Zoom, Scroll), Dateibezug, Änderungszähler, Metadaten.
- **Layer**: `id` (UUID), Name, sichtbar, Deckkraft (UInt8, 0–255 wie PDN), Mischmodus (14), Hintergrund-Flag, `TiledBitmap`, Miniatur (asynchron).
- **TiledBitmap**: Kacheln 256×256 BGRA8; leere Kacheln implizit transparent; Copy-on-Write je Kachel (Grundlage für günstige Verlaufseinträge und Effekt-Vorschau).
- **Selection**: Polygon-Liste (Integer/Fixkomma) + Kombinationsmodus; daraus abgeleitete Maske (1 Bit „pixelig“ oder 8 Bit „geglättet“, je nach Auswahl-Kantenmodus).
- **Befehle**: Jede Änderung läuft über ein `Command` (macht Änderung + erzeugt Memento). Live-Objekte (Form, Text, Füllung, Verlauf, Zauberstab, Transformation) halten einen **Bearbeitungszustand**, der erst bei „Fertigstellen“ einen Verlaufseintrag erzeugt; Abbrechen verwirft ihn ohne Eintrag.

## 4. Renderpipeline

1. Pro Ebene GPU-Kacheltexturen (lazy hochgeladen, schmutzige Kacheln nachgeladen).
2. Komposition unten → oben mit Mischmodus-Shader (Formeln der Paint.NET-3.36-UserBlendOps, Deckkraft, Sichtbarkeit) in eine Komposit-Textur je Zoomstufe/Ausschnitt.
3. Live-Ebene des aktiven Werkzeugs (Strich/Form/Effektvorschau) wird zwischen aktiver Ebene und darüberliegenden eingeschoben, ohne Ebenendaten zu verändern.
4. Anzeige: Schachbrett → Komposit (nächster Nachbar ab 100 %, Mipmaps darunter) → Overlays (Pixelraster ab 200 %, Auswahl-Ameisen, Griffe, Lineale).
5. CPU-Referenzpfad für jede GPU-Operation (für Tests und als Fallback ohne GPU).

## 5. Effekt- und Korrektur-Engine

- Effekt = Parameterbeschreibung (Name, Typ, Bereich, Standard, Einheit) + Kernel (Metal) + CPU-Referenz.
- Dialoge werden aus der Parameterbeschreibung erzeugt (Regler ↔ Zahlenfeld synchron, Zurücksetzen je Wert, OK/Abbrechen, Enter/Esc) – ein gemeinsames Schema (Projektvorgabe 20); Sonderdialoge: Kurven, Tonwerte, Drehen/Zoomen, Wolken (Register), Quantisieren.
- Vorschau: jede Parameteränderung bekommt eine Generationsnummer; nur das Ergebnis der neuesten Generation wird angezeigt, ältere Berechnungen werden abgebrochen (Projektvorgabe 19).
- Anwendung nur innerhalb der Auswahlmaske; Ergebnis als ein Verlaufseintrag; „Letzten Effekt wiederholen“ speichert Effekt-ID + Parameter.

## 6. Verlauf

- Memento speichert nur betroffene Kacheln (vorher/nachher) bzw. Struktur-Änderungen (Ebene hinzugefügt, Eigenschaften).
- Speicherbudget; ältere Mementos werden komprimiert (LZ4/zlib) auf Platte ausgelagert (wie Paint.NET „begrenzt nur durch Speicher und Platte“).
- Je Dokument eigener Verlauf; Klick in Verlaufsliste springt per Undo/Redo-Kette.

## 7. Dateiformate

| Format | Lesen | Schreiben | Weg |
|---|---|---|---|
| PNG, JPEG, TIFF, GIF, BMP, HEIC | ImageIO | ImageIO (+ eigene Quantisierung für 8-Bit/GIF) | System |
| AVIF | ImageIO (≥13) | libavif (BSD-2) – Lizenz/Größe prüfen | System + Bibliothek |
| WebP | ImageIO | libwebp (BSD-3) | System + Bibliothek |
| JPEG XL | libjxl (BSD-3) | libjxl | Bibliothek |
| JPEG XR | jxrlib (BSD-2) – Machbarkeit prüfen | dito | ungeklärt |
| TGA | eigener Codec (Port PDN 3.36) | dito | Port |
| DDS | libsquish (MIT) + Port DDS-Plugin | dito | Port |
| PDN | eigener NRBF-Leser | eigener Writer, erst nach Zertifizierung freischalten | eigen |
| Natives Projekt | Paket (ZIP): `document.json` + PNG je Ebene | dito | eigen |

Sicheres Speichern: in temporäre Datei im selben Volume schreiben, `fsync`, dann `replaceItemAt` (Projektvorgabe 26).

## 8. Eingabe und Tastatur

- Zentrale Keymap-Tabelle (Mac-Belegung und optionale Windows-Belegung), Konflikte siehe KNOWN_ISSUES.
- Rechte Maustaste: echte Rechtsklicks, Zwei-Finger-Klick am Trackpad; Ctrl+Klick nur, wo kein Konflikt.
- Tablett: Druck/Neigung über `NSEvent.pressure`/`tilt`; Koaleszierte Events für flüssige Striche.

## 9. Nebenläufigkeit

Hauptthread nur für UI. Rendering und Effekte in eigenen Actors/Queues; Dateizugriff asynchron; große Operationen mit Fortschritt und Abbruch.

## 10. Plugins

Eigene Bundle-Schnittstelle (Swift-Protokoll + optional Metal-Shader), versioniert, im eigenen Prozess oder abgesichert geladen; Fehler in Einstellungen › Plugin-Fehler. **Paint.NET-DLL-Plugins sind nicht kompatibel** und werden nicht als kompatibel bezeichnet.

## 11. Teststrategie (Projektvorgabe 29)

- Unit-Tests je Modul (XCTest/Swift Testing), Bildvergleich gegen CPU-Referenz und gegen Referenzbilder (pypdn-Flatten-Testbilder, später eigene aus Paint.NET 5.1.12).
- UI-Tests (XCUITest) für die Beispielabläufe A–E und je Menüeintrag.
- Performance-Messungen bei 1920×1080, 3840×2160, 6000×4000, 10000×10000 (Projektvorgabe 25) mit echten Messwerten im TEST_REPORT.

## 12. Build-Umgebung (offen)

Bauen und Testen erfordert macOS mit Xcode. Die aktuelle Arbeitsumgebung ist Linux. Optionen: (a) Verknüpfung mit dem Mac des Nutzers, (b) GitHub Actions mit macOS-Runnern. Siehe KNOWN_ISSUES B-1.
