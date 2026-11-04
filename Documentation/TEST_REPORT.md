# TEST_REPORT.md

Stand: 04.11.2026 · Version 0.2.0 (Build 2) · Branch `phase-2`

## 1. Testumgebung

| | |
|---|---|
| Build und Tests | GitHub Actions, Runner `macos-15`, macOS 15.8.2 (24H232), Xcode 16.4, Apple Silicon (arm64, virtualisiert) |
| Kern-Tests (Linux) | Swift 6.1 unter Ubuntu 24.04 (nur EditorKit, ohne AppKit) |
| Ablauf | `.github/workflows/build.yml`: Kern-Tests → `xcodegen` → Release-Build Universal → `lipo -info` → App-Tests (XCTest, App als Testhost) → Selbsttest der fertigen Release-App (`--selftest`) → DMG → Hochladen von Protokollen, Bildschirmfotos und DMG |
| Nicht geprüft | Intel-Mac / Rosetta (B-3), Bedienung von Hand, Retina-Darstellung auf echtem Bildschirm, Installation aus der DMG auf einem frischen Mac |

## 2. Ergebnisse

| Testsuite | Anzahl | Ergebnis |
|---|---|---|
| EditorKit (Kern: Kacheln, Farben, Einheiten, Zoom, Mischmodi, Dokument, Verlauf, Ebenen) | 33 | 33 bestanden (Linux und macOS) |
| App-Tests (PNG-Hin-/Rückweg mit Halbtransparenz, JPEG auf Weiß, HSV, Palette, Zoomeingabe/-regler, Befehlstabelle ↔ Menüs, Tastenkürzel-Anzeige, Werkzeugtasten) | 8 | 8 bestanden |
| Selbsttest der Release-App | 72 | 72 bestanden, Dauer ca. 7 s |
| Universal-Binary | `lipo -info` | „x86_64 arm64“ |
| DMG | `hdiutil verify` | gültig |

### Selbsttest im Einzelnen (Auszug, vollständig in `selftest.log` des CI-Laufs)

| Bereich | Geprüft |
|---|---|
| Start | ohne Bild im Testmodus; neues Bild 800 × 600 weiß, Ebene „Hintergrund“, Verlauf „Neues Bild“, Statusleiste „800 × 600 px“, Register, Fenstertitel, Zoom ≤ 100 % |
| Menüs | jeder nicht umgesetzte Menüpunkt ist deaktiviert; Werkzeugleiste ebenso |
| Ebenen | neu (transparent, „Ebene 2“), duplizieren („Ebene 2 Kopie“), nach unten, Rückgängig, Wiederholen, ausblenden, Ebenenfenster (3 Zeilen, Markierung, Knopfzustand), zusammenführen, löschen, letzte Ebene nicht löschbar |
| Eigenschaften | Vorschau ohne Verlaufsschritt, Übernehmen erzeugt genau einen Eintrag |
| Bild | 90° drehen (Größe und Pixellage), zurückdrehen, horizontal spiegeln (Pixellage), reduzieren |
| Verlauf | Fenster zeigt alle Einträge; Sprung zum Anfang stellt Größe und Pixel wieder her |
| Zoom | 200 %, Stufen 300 % / 150 %, Originalgröße, Pixelraster bei 1600 %, Einheit Zentimeter „21,17 × 15,88 cm“ |
| Dateien | PNG speichern → unverändert-Status und Titel; Wiederöffnen: Größe, halbtransparent (200,100,50,128) exakt, fast transparent (α = 1) exakt, deckend exakt, 96 dpi; JPEG, BMP, TIFF, GIF, HEIC, TGA speichern und öffnen |
| Bilder | gleiche Datei nicht doppelt geöffnet, zweites Bild, Register-Reihenfolge, nächstes Bild, Schließen |
| Zwischenablage | Zusammengefügt kopieren, In neues Bild einfügen (Pixel exakt), In neue Ebene einfügen |
| Werkzeuge/Farben | Hand, Taste Z, nicht umgesetztes Werkzeug nicht wählbar, Farben tauschen, HSV-Umrechnung |
| Fenster | alle vier sichtbar, ausblenden, Positionen zurücksetzen |
| Dialog Neues Bild | Seitenverhältnis 1600 → 1200, Grenze 70000 abgewiesen |

### Bildschirmfotos (Artefakt „ergebnisse“ des CI-Laufs)
`01-hauptfenster`, `02-testbild-angepasst`, `02-zoom-1600-pixelraster`, `03-verlauf`, `04-mehrere-bilder`, `05-ebeneneigenschaften`, `06-fenster-{tools,history,layers,colors}`, `07-neues-bild`. Durchgesehen: Darstellung, Schachbrett, Pixelraster, Register, Statusleiste und Fenster entsprechen dem Entwurf. Gefundene und behobene Fehler: halbe Pixelkante am Bildrand (gebrochene Zoomgröße), Farbrad bei Schwarz komplett schwarz, Schalterzustand der Werkzeugleiste nicht erkennbar, „ungespeichert“-Punkt bei unberührtem neuen Bild.

## 3. Fehler, die durch Tests gefunden wurden

| Fund | Ursache | Behoben |
|---|---|---|
| Build-Fehler: F-Tasten-Kürzel | Funktionsreferenz verliert Standardargument | ja |
| Build-Fehler: `selectAll` | NSWindow hat die Methode bereits | ja |
| Rand-Artefakt rechts am Bild | Bildrahmen mit Nachkommastellen | ja (ganzzahlig gerundet) |
| TIFF: halbtransparenter Pixel R 200 → 199 | ImageIO multipliziert beim TIFF-Schreiben vor | nein, dokumentiert (KNOWN_ISSUES F-1) |

## 4. Offene Tests

- Bedienung mit Maus/Trackpad von Hand (Zoomrahmen, Hand, Ziehen in der Ebenenliste, Kontextmenü der Register, Dialoge mit Enter/Esc).
- Neustart: Fensterlage und „Zuletzt geöffnet“ bleiben erhalten.
- Intel/Rosetta (`arch -x86_64`).
- Performance mit großen Bildern (Phase 9; Anzeige derzeit CPU-Komposit, siehe KNOWN_ISSUES T-4).

## 5. Vorlage Referenzmessung
Unverändert aus Phase 1 (Standardwerte, Grenzen, Schrittweiten je Dialog an Paint.NET 5.1.12) – siehe KNOWN_ISSUES R-1.
