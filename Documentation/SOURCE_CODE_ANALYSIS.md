# SOURCE_CODE_ANALYSIS.md

**Projekt:** Paint.NET-inspirierter Bildeditor für macOS (Arbeitstitel neutral – der Name „Paint.NET“ wird nicht verwendet)
**Abschnitt:** 38 – Verbindliche GitHub- und Quellcodeanalyse
**Stand der Analyse:** 4. November 2026
**Methode:** Alle genannten Repositories wurden geklont und im Quelltext untersucht (Struktur, Umfang, Lizenzdateien, Datei-Kopfzeilen, Kernklassen, Build). Ergänzend wurden weitere öffentlich auffindbare Projekte geprüft. Zahlen (Dateien/Zeilen) stammen aus der eigenen Auszählung des jeweiligen Standes.

> Hinweis: Dieser Bericht ist eine technische Lizenz- und Herkunftsprüfung, keine Rechtsberatung. Für eine kommerzielle Veröffentlichung sollte die Lizenzliste (THIRD_PARTY_LICENSES.md) vor dem Release von einer fachkundigen Person gegengelesen werden.

---

## 0. Kurzfassung

| Ergebnis | Entscheidung |
|---|---|
| **Architektur** | **Variante B: native Swift-/AppKit-App** mit Metal/Core Image. Algorithmen werden aus **Paint.NET 3.36 (MIT)** und **Pinta (MIT)** gezielt nach Swift portiert. |
| **Pinta als Basis (Variante A)?** | Funktional die beste vorhandene Codebasis (~64 000 Zeilen C# ohne Tests, 22 Werkzeuge, 37 Effekte, 9 Anpassungen), aber GTK 4 + .NET auf macOS: fremdes Look & Feel, CPU-Rendering über Cairo, großes Bundle, Abhängigkeit von Homebrew-GTK. **Als Algorithmus-Quelle ja, als App-Gerüst nein.** |
| **Direkt nutzbarer Paint.NET-Code** | Nur **Paint.NET 3.36** (MIT mit 3 Ausnahmen) und die beiden aktuellen MIT-Repos **PaintDotNet.Quantization** und **PdnV5EffectSamples** (Letzteres nur als Referenz, da an proprietäre v5-API/Direct2D gebunden). |
| **Ausgeschlossen** | Aktuelle Paint.NET-Binärdateien (proprietär), alle **Icons/RESX/PNG** aus Paint.NET 3.36 (CC BY-NC-ND), **GPC** (keine kommerzielle Nutzung), **OpenPDN** (laut eigener Doku aus dekompiliertem Paint.NET 5.1.12 abgeleitet), zwei Shader-Beispiele unter CC BY-NC-SA. |
| **PDN-Dateiformat** | Seit Paint.NET 2.1 bis 5.1.12 stabil: `PDN3` + XML-Kopf + .NET-BinaryFormatter-Daten (MS-NRBF), Pixel in 1-MiB-Chunks (gzip). Lesen ist gut dokumentiert (pypdn, MIT). **Schreiben ist bei keinem offenen Projekt gegen echtes Paint.NET 5 verifiziert.** Paint.NET 6.0 (2027 geplant) führt ein **neues** PDN-Format ein. |
| **Wichtigste offene Voraussetzung** | Ein Satz echter `.pdn`-Testdateien, gespeichert mit Paint.NET 5.1.12 auf Windows (Ebenen, alle 14 Mischmodi, Deckkraft, Sichtbarkeit, große Bilder), um Import/Export zu zertifizieren. |

---

## 1. Untersuchte Projekte im Detail

### 1.1 milliethompson/PaintDotNet – Paint.NET 3.36 Quellcode

| Punkt | Befund |
|---|---|
| 1. URL | https://github.com/milliethompson/PaintDotNet |
| 2. Version | **Paint.NET 3.36** (einziger Commit „Paint.NET 3.36“). Es ist ein **inoffizieller Spiegel** einer Drittperson, kein Repository von dotPDN. |
| 3. Sprache | C# (.NET 2.0/3.5, Visual Studio 2008), dazu C/C++ (Shell-Erweiterung, Squish/DDS) |
| 4. Lizenz | `src/Resources/Files/License.txt`: **MIT mit drei Ausnahmen** (Stand 1. Juni 2008): (1) Logo/Icon-Grafik → CC BY-NC-ND 2.5; (2) alle **.RESOURCES, .RESX, .PNG**-Dateien („resource assets“: Toolbar-Icons, Menütexte, Statusleiste) → CC BY-NC-ND 2.5; (3) **GPC**-Code → keine kommerzielle Nutzung ohne Lizenz der University of Manchester. Alle 649 `.cs`-Dateien tragen den Kopf „Copyright (C) dotPDN LLC, Rick Brewster, Tom Jackson, and contributors. Portions Copyright (C) Microsoft Corporation“. Abweichend: DDS-Plugin (Dean Ashton, MIT) und libsquish (Simon Brown, MIT). |
| 5. Architektur | Projekte: `Core` (146 Dateien/36 000 Z.: Surface, ColorBgra, PixelOps, PdnRegion, Selection, Histogramme, Curves-UI), `Data` (41/12 700: Document, Layer, BitmapLayer, Dateitypen, Mischmodi, Quantisierer), `Effects` (85/15 700), `tools` (26/10 700), `SystemLayer` (69/14 900, **Windows-only**: P/Invoke, WIA, Ink, Dateidialoge), `HistoryMementos`/`HistoryFunctions`, `Menus`, `Actions`. UI: WinForms. |
| 6. Vorhandene Funktionen | **Werkzeuge (22):** Rechteck-/Ellipsen-/Lasso-Auswahl, Zauberstab, Auswahl/Pixel verschieben, Zoom, Hand, Farbeimer, Verlauf, Pinsel, Stift, Radierer, Pipette, Kopierstempel, Umfärben, Text, Linie/Kurve, Rechteck, abgerundetes Rechteck, Ellipse, Freiform. **Anpassungen (9):** Auto-Pegel, Schwarzweiß, Helligkeit/Kontrast, Kurven, Farbton/Sättigung, Invertieren, Tonwerte (Levels), Tontrennung, Sepia. **Effekte (32):** Künstlerisch (Tuschezeichnung, Ölgemälde, Bleistiftskizze), Weichzeichner (Fragment, Gauß, Bewegung, Radial, Oberfläche, Unschärfe, Zoom), Verzerren (Wölben, Dellen, Milchglas, Verpixeln, Polar-Inversion, Kachelspiegelung, Wirbel), Rauschen (Hinzufügen, Median, Reduzieren), Foto (Leuchten, Rote Augen, Schärfen, Porträt weichzeichnen, Vignette), Rendern (Wolken, Julia, Mandelbrot), Stilisieren (Kanten, Prägen, Umriss, Relief). **Mischmodi (14):** Normal, Multiplizieren, Additiv, Farbig nachbelichten, Farbig abwedeln, Reflektieren, Leuchten, Überlagern, Differenz, Negation, Aufhellen, Abdunkeln, Negativ multiplizieren, XOR. **Resampling:** Nächster Nachbar, Bilinear, Bikubisch, Super-Sampling. **Formate:** PDN, PNG, JPEG, BMP, GIF, TIFF, TGA, DDS. |
| — Zeichenwerkzeuge | Basisklasse `Tool` + Konfigurationsschnittstellen (`IBrushConfig`, `IPenConfig`, `IAntiAliasingConfig`, `IAlphaBlendingConfig` …). Strich wird als GDI+-Pfad (`PdnGraphicsPath`) gerendert und in die Ebene geschrieben. |
| — Ebenen | `Document` → `LayerList` → `BitmapLayer` (eigene `Surface`, **BGRA 32 Bit, nicht vormultipliziertes Alpha**), Eigenschaften: Name, sichtbar, Deckkraft (0–255), `BlendOp`, Hintergrund-Flag. |
| — Auswahl | `Selection` hält einen `PdnGraphicsPath`; Kombinationsmodi (Ersetzen, Vereinigen, Ausschließen, Schnitt, XOR) über **GPC** (`SystemLayer/GpcWrapper`). → GPC darf nicht übernommen werden. |
| — Farbverwaltung | `ColorBgra`, `HsvColor`, `RgbColor`, Paletten (`PaletteCollection`), Farbrad-UI. **Kein ICC-Farbmanagement** (kam erst in 5.1). |
| — Effekt-Mathematik | Gauß: separierbarer Kern mit Gewichtstabelle; Bewegung/Radial/Zoom: Abtastung entlang Linie/Bogen/Strahl; Schärfen/Rauschen/Median/Ölgemälde: `LocalHistogramEffect` (gleitendes Histogramm); Verzerrungen: `WarpEffectBase` mit inverser Abbildung + Super-Sampling (Antialiasing); Kurven: `SplineInterpolator` (kubischer Spline) → Lookup-Tabellen; Levels: `UnaryPixelOps.Level` (Gamma + Ein-/Ausgabebereich). |
| — Transformation | `Surface.BicubicFitSurface`, `SuperSamplingFitSurface`, `NearestNeighborFitSurface`; Drehen/Zoomen über `RotateZoomEffect` und Matrizen; Ebenen spiegeln/drehen als `HistoryFunction`. |
| — Undo/Redo | `HistoryStack` mit `HistoryMemento`-Objekten; `BitmapHistoryMemento` speichert nur den **geänderten Bereich** (`PdnRegion`) und lagert ihn per `PersistedObject` auf die Platte aus; `CompoundHistoryMemento` bündelt Schritte. Sehr gutes Vorbild. |
| — Werkzeugoptionen | `AppEnvironment` (geteilter Zustand: Farben, Pinselbreite, Antialiasing, Toleranz, Füllmodus …) + `ToolConfigStrip`; Standardwerte speicherbar (`ChooseToolDefaultsDialog`). |
| — Menüs/Dialoge/Zustand | `Menus/*Menu.cs` (Datei, Bearbeiten, Ansicht, Bild, Ebenen, Anpassungen, Effekte, Fenster, Hilfe), `Actions/*`, Dialoge als WinForms-Klassen; Werkzeuge mit `StateMachine`. Struktur gut als Vorlage für die Menüordnung (eigene Texte, siehe Lizenz-Ausnahme 2). |
| 7. Fehlende Funktionen (ggü. 5.1.12) | GPU-Rendering, Druckempfindlichkeit, neue Pinsel-Engine, Formen mit editierbaren Griffen, Farbmanagement/ICC, neue Anpassungen (Belichtung, Lichter/Schatten, Temperatur/Tönung), neue Effekte (u. a. Bokeh, Begradigen, Schlagschatten, Skizzen-, Quadrat- und Median-Unschärfe; Quantisieren seit 4.2.16), Lanczos/Adaptiv-Resampling, AVIF/WebP/JPEG XL/HEIC, moderne Plugin-API. |
| 8. macOS | **Nicht lauffähig** (WinForms, P/Invoke, GDI+). Plattformunabhängig sind: Surface/ColorBgra/PixelOps, Mischmodi, Effektalgorithmen, Spline, Histogramme, Quantisierer, PDN-(De)Serialisierungslogik, History-Konzept. |
| 9. Wiederverwendung | **Portieren** (C# → Swift, MIT-Hinweis behalten): Mischmodi, alle Effekt-/Anpassungsalgorithmen, Spline/Levels, Resampling, Zauberstab-Toleranz, Verlaufsrenderer, History-Konzept, PDN-Reader-Logik. **Nicht übernehmen:** Icons/PNG/RESX/Strings, Logo, GPC, SystemLayer, Installer/Updater. |
| 10. Anpassungen | GDI+-Pfade → Core Graphics/eigener Rasterizer; Threading → Swift Concurrency; Auswahl-Booleans → Clipper2; Speicher → Metal-Texturen/Kacheln. |
| 11. Einschränkungen | Inoffizieller Spiegel: Herkunft gegen Pinta (der dieselben 3.36-Dateien mit Originalköpfen enthält) und gegen die Lizenzdatei abgleichen. Code von 2009, nicht gepflegt, viele `unsafe`-Zeiger. |

### 1.2 paintdotnet (Organisation)

Die Organisationsseite selbst war über das Werkzeug nicht abrufbar; untersucht wurden die drei genannten Repositories. Von dotPDN veröffentlicht ist dort **kein** Quellcode der aktuellen Anwendung – Paint.NET ist seit Version 4 Closed Source.

### 1.3 paintdotnet/release

| Punkt | Befund |
|---|---|
| URL / Version | https://github.com/paintdotnet/release – nur `README.md` (Vorlage für Release-Beschreibungen) |
| Inhalt | **Kein Quellcode.** Installer/Portable-ZIPs werden nur als Release-Anhänge verteilt; der „Source code“-ZIP ist laut README leer. |
| Nutzen | Systemanforderungen von 5.x (Windows 10/11, AVX2, Direct3D 11, HDR/WCG optional) → zeigt, dass aktuelle Paint.NET-Funktionen stark an Direct2D/Windows gebunden sind. Aktuelle Version laut paint.net-Roadmap: **5.1.12** (8. März 2026); **5.2** in Entwicklung (neue FileType-Plugin-Architektur, 32-Bit-Float-Ebenenkomposition), **6.0** für 2027 mit **neuem PDN-Format**, Ebenengruppen, 16 Bit/Kanal. |
| Wiederverwendung | Keine. Binärdateien sind proprietär und dürfen weder übernommen noch dekompiliert werden. |

### 1.4 paintdotnet/PdnV5EffectSamples

| Punkt | Befund |
|---|---|
| URL / Version | https://github.com/paintdotnet/PdnV5EffectSamples – letzter Commit 26.10.2026 („PDN v5.2 Samples“) |
| Sprache | C# + HLSL-Shader über ComputeSharp.D2D1 |
| Lizenz | **MIT** (2022, dotPDN LLC), *gilt nur für Dateien ohne eigenen Lizenzkopf*. **Ausnahmen:** `NightCircuitShaderEffect.cs`, `PolarizedMandelleavesShaderEffect.cs` → **CC BY-NC-SA 3.0** (nicht kommerziell); weitere ShaderToy-Ports verweisen auf ihre Quelle (Lizenz der Originale einzeln prüfen). |
| Architektur | 21 GPU-Effekte (`GpuImageEffect`/`GpuDrawingEffect` auf Direct2D) + 1 CPU-Effekt (`BitmapEffect`). Beispiele: Schlagschatten, Kanalunschärfe, Iris-Unschärfe, Gauß-Bokeh, Farbton drehen, Quadrat-Unschärfe, Welle, Rauschen. |
| Nutzen | Zeigt **wie Paint.NET 5 Effekte als Effektgraph aufbaut** (Unschärfe → Versatz → Komposition). Code hängt an der proprietären Paint.NET-5-API und Direct2D → **nicht lauffähig/übernehmbar**, aber als Referenz für Effekt-Parameter und GPU-Aufbau nutzbar. |
| Wiederverwendung | Nur Ideen/Graph-Struktur; eigene Metal-Shader schreiben. CC-BY-NC-SA-Dateien vollständig meiden. |

### 1.5 paintdotnet/PaintDotNet.Quantization

| Punkt | Befund |
|---|---|
| URL / Version | https://github.com/paintdotnet/PaintDotNet.Quantization – letzter Commit 26.12.2024 (.NET 9) |
| Sprache / Lizenz | C#; Repo-`LICENSE`: **MIT** (2021, Rick Brewster). **Achtung:** die 70 Datei-Köpfe sagen „Copyright (C) dotPDN LLC … All Rights Reserved“, der Octree-Quantisierer verweist zusätzlich auf einen MSDN-Artikel von 2003 als Grundlage. |
| Architektur | Octree-Quantisierer mit Fehlerkorrekturen (Rechtsverschiebungs-Bug, Blattreduktion …), Paletten-Mapping (linear, Cache, Nachbarschaft), Histogramme. Absichtlich „zum Integrieren, nicht zum Verlinken“. |
| Wiederverwendung | Algorithmus portieren, **beide** Hinweise (MIT-Text + Datei-Copyright) übernehmen. Wegen des Widerspruchs Kopfzeile/LICENSE alternativ: eigene Implementierung nach Literatur (Octree, Median Cut, Wu) mit den dokumentierten Fixes als Anforderungsliste. |

### 1.6 PintaProject/Pinta – Hauptkandidat als technische Grundlage

| Punkt | Befund |
|---|---|
| 1. URL | https://github.com/PintaProject/Pinta |
| 2. Version | `master` = **3.2-Entwicklung** (Commit 2.11.2026); letzte Veröffentlichung **3.1.2** (29.03.2026) |
| 3. Sprache | C# (.NET 10), GTK 4 + libadwaita über GirCore, Cairo, Mono.Addins (Plugins), ParagonClipper 6.4.2 (Clipper-Port) |
| 4. Lizenz | Pinta-eigener Code **MIT** (Jonathan Pobst u. a.). 97 Dateien aus Paint.NET 3.36 mit Original-Kopf unter `license-pdn.txt` (MIT, Logo-Ausnahme). **Icons:** laut README teils aus Paint.NET 3.0 („MIT“), Silk und Fugue (CC BY 3.0) sowie eigene. ⚠ Die Paint.NET-3.36-Lizenz stellt PNG-Ressourcen unter CC BY-NC-ND – Pinta beruft sich auf die ältere 3.0-Lizenz. **Icons deshalb nicht übernehmen.** |
| 5. Architektur | `Pinta.Core` (208 Dateien/25 800 Z.: Document, DocumentLayers, DocumentSelection, DocumentHistory, Layer/UserLayer, BlendModes, PixelOps, Bildformate, Manager), `Pinta.Tools` (58/11 600), `Pinta.Effects` (62/9 300), `Pinta.Gui.Widgets` (27/6 900), `Pinta` (App, 61/8 600), `Pinta.Docking`, `Pinta.Gui.Addins`, `tests` (58/5 400, NUnit). |
| — Dokumentmodell | `Document` mit `DocumentLayers` (Liste von `UserLayer`), `DocumentSelection`, `DocumentHistory`, Workspace (Zoom/Scroll). |
| — Zeichenfläche | GTK-Widget, Rendering mit **Cairo auf der CPU**; Ebenen als Cairo `ImageSurface` **ARGB32 (vormultipliziert)**. |
| — Ebenensystem | Name, sichtbar, Deckkraft, Mischmodus (16 Cairo-Modi: Normal, Multiplizieren, Farbig nachbelichten/abwedeln, Überlagern, Differenz, Aufhellen, Abdunkeln, Negativ multiplizieren, XOR, Hart-/Weiches Licht, Farbe, Luminanz, Farbton, Sättigung). Die 14 Paint.NET-Mischoperationen (`UserBlendOps.*`) sind zusätzlich vorhanden. ⚠ Additiv, Reflektieren, Leuchten, Negation fehlen als Ebenenmodus → für PDN-Kompatibilität nötig. |
| — Auswahl | Polygon-Pfade + Clipper (Vereinigen, XOR, Ausschließen, Ersetzen, Schnitt); Werkzeuge Rechteck, Ellipse, Lasso (Freihand/Polygon), Zauberstab (lokal/global). |
| — Pinsel | `BasePaintBrush` + 6 Pinsel (Normal, Kreis, Raster, Quadrate, Spritzer, Schräg). Keine Druckempfindlichkeit auf macOS. |
| — Farbverwaltung | RGB/HSV, Paletten-Formate (GIMP, PDN-Palette, …), Farbwähler-Dialog; **kein ICC**. |
| — Korrekturen | Auto-Pegel, Schwarzweiß, Helligkeit/Kontrast, Kurven, Farbton/Sättigung, Invertieren, Tonwerte, Tontrennung, Sepia (9). |
| — Effekte (37) | Paint.NET-3.36-Ports + neue: Zellen, Dithering, Ausblenden (Feather), Objekt ausrichten, Objekt-Umriss, Voronoi, Vignette u. a. Live-Vorschau (`LivePreviewManager`, `AsyncEffectRenderer`, aktuell Umbau auf `ILivePreviewSession`). |
| — Dateiformate | GdkPixbuf (PNG, JPEG, BMP, TIFF, ICO, WebP je nach Loader), **ORA** (OpenRaster, mit Ebenen) lesen/schreiben, TGA-Export, Netpbm/PPM-Import. **Kein PDN, kein PSD.** |
| — Historie | `DocumentHistory` mit `BaseHistoryItem`-Ableitungen; `SimpleHistoryItem` speichert Ebenen-Abbilder bzw. **`SurfaceDiff`** (nur geänderte Pixel). |
| — Maus/Eingabe | GTK-Gesten/Controller, Tastaturkürzel, Werkzeugzyklus. |
| — Oberfläche | GTK 4/libadwaita, Docking-Panels; auf dem Mac sichtbar „Linux-artig“ (Header-Bar statt nativer Menüleiste, GTK-Dialoge). |
| — macOS-Build | `installer/macos/build_installer.sh`: Homebrew-GTK wird ins Bundle kopiert, `DYLD_LIBRARY_PATH`, Signierung mit Hardened Runtime; Entitlements u. a. `allow-jit`, `allow-unsigned-executable-memory`, **`disable-library-validation`**, Sandbox seit 3.2. Getrennte Builds osx-x64/osx-arm64. |
| 7. Fehlend ggü. Paint.NET 5.1 | PDN-Import/-Export, Druckempfindlichkeit, GPU-Rendering, Farbmanagement, Formen mit editierbaren Griffen in Paint.NET-Umfang, neuere Effekte (u. a. Bokeh, Begradigen, Schlagschatten, Skizzen-/Quadrat-Unschärfe, Quantisieren), neue Anpassungen (Belichtung, Lichter/Schatten, Temperatur/Tönung), PDN-Plugin-Kompatibilität. |
| 8. macOS | **Lauffähig**, aber nicht nativ (GTK). |
| 9. Wiederverwendung | **Sehr hoch als Algorithmus-Quelle:** Effekte, Anpassungen, Zauberstab, Verläufe, SurfaceDiff-Undo, Kurven/Levels-Logik, Clipper-Integration, ORA-Format, Paletten-Formate, Unit-Tests als Testfälle. |
| 10. Anpassungen | Cairo → Metal/Core Graphics; GTK-UI vollständig ersetzen; Mono.Addins → eigenes Plugin-Konzept. |
| 11. Einschränkungen | Rendering-Leistung bei großen Bildern (CPU), Bundle-Größe (.NET-Runtime + GTK), Upstream ändert gerade viel (Live-Preview-Umbau). |

### 1.7 Weitere gefundene Projekte

| Projekt | Sprache / Lizenz | Befund | Nutzung |
|---|---|---|---|
| **addisonElliott/pypdn** – https://github.com/addisonElliott/pypdn | Python, **MIT** (2018) | Nur **Lesen** von PDN. Eigener MS-NRBF-Parser (746 Z.) + PDN-Reader (343 Z.). Selbst getestet: liest Testdateien von **Paint.NET 3.5.10 und 4.2.x** (interne Version 4.21) korrekt (Größe, Version, Ebenenname, Deckkraft, Mischmodus, Sichtbarkeit). Keine 5.x-Testdatei im Repo. | **Referenz-Implementierung für unseren Swift-Reader** (Logik portieren, MIT-Hinweis). |
| **diegomgarcia/paint.rust** – https://github.com/diegomgarcia/paint.rust | Rust, MIT (2026) | Paint.NET-inspirierter Editor (egui), Status „development preview“. Eigene `pdn3`-Crate liest **und schreibt** PDN, laut eigener Doku nur **Normal-Mischmodus**, Writer „nur selbst-rundlauf-getestet“; eine echte 5.1.12-Datei (2×2 px) als Fixture. Gibt an, Paint.NET nur als Blackbox über die UI beobachtet zu haben. | Nur Referenz (Format-Notizen, Grenzwerte, Sicherheitsgrenzen beim Parsen). |
| **Univers4craft/paint.software** – https://github.com/Univers4craft/paint.software | C++17/Qt 6, MIT (2026) | „Paint.NET-Klon für Linux“, ~27 000 Zeilen, PDN **nur lesen**. | Nur Referenz. |
| **storytold/photocraft** – https://github.com/storytold/photocraft | Rust, MIT/Apache-2.0 (2026) | Photoshop-Nachbau, sehr groß (~850 000 Zeilen), PDN **nur Import** (eigener NRBF-Parser, nach pypdn). | Nur Referenz (PSD-/Blend-Ideen). |
| **EricKrouss/OpenPDN** – https://github.com/EricKrouss/OpenPDN | Rust, Apache-2.0 (2026) | Ziel „Paint.NET 5.1.12-Parität“, liest/schreibt PDN. **Laut eigener Doku mit ILSpy aus den originalen Paint.NET-5.1.12-Assemblies dekompiliert** („reverse engineered“, Fixtures aus „original managed routines“). | **Ausgeschlossen** – verstößt gegen 38.5 („keine Übernahme aus dekompilierten aktuellen Paint.NET-Binärdateien“). Auch nicht als Referenz lesen. |
| **AngusJohnson/Clipper2** – https://github.com/AngusJohnson/Clipper2 | C++/C#, **Boost Software License 1.0** | Polygon-Boolesche Operationen, Offset (gepflegt, Commit 29.10.2026). Nachfolger von Clipper 6, das Pinta nutzt. | **Direkt übernehmen** für Auswahl-Kombinationen (Swift-C++-Interop). |
| **BradLarson/GPUImage3** – https://github.com/BradLarson/GPUImage3 | Swift/Metal, BSD-3-Clause | Metal-Filter: Gauß, Bewegung, Zoom, Schärfen, Sobel/Prewitt, Median, Kuwahara, Wölben/Kneifen/Wirbel, Tonwerte, Mischmodi … Letzter Commit 2024. | Shader-Referenz, einzelne Kernels übernehmbar (BSD-Hinweis). |
| **MetalPetal/MetalPetal** – https://github.com/MetalPetal/MetalPetal | Obj-C/Swift/Metal, MIT | Metal-Bildverarbeitung, 27 Mischmodi, Mehrebenen-Komposition, CLAHE. Letzter Commit 2023. | Referenz für Mehrebenen-Komposition auf Metal. |
| **nothings/stb** (stb_image_resize2) – https://github.com/nothings/stb | C, MIT **oder** Public Domain | Hochwertiges Skalieren (Lanczos, Mitchell …). | Optional für CPU-Resampling. |
| **Apple-Frameworks** (Core Image, vImage/Accelerate, Metal Performance Shaders, ImageIO, ColorSync) | Systembestandteil | Gauß, Bewegung, Zoom, Schärfen, Rauschreduzierung, Kanten, Verzerrungen, Farbsteuerung, Tonkurve, Belichtung, Lichter/Schatten, Temperatur/Tönung, Lanczos, Histogramm, Morphologie, ICC-Farbmanagement, Formate (HEIC, AVIF, WebP-Lesen, TIFF, PSD-Lesen …). | **Bevorzugt nutzen**, wo exakte Paint.NET-Ergebnisse nicht verlangt sind. Keine Lizenzpflichten. |

Nicht geeignet wegen Lizenz: **GPC** (nicht kommerziell), **libimagequant** (GPLv3/kommerziell), **ImageSharp** (Six-Labors-Split-License, kommerziell eingeschränkt), GIMP/Krita/GEGL-Code (GPL/LGPL – würde bei Übernahme die ganze App unter GPL stellen).

---

## 2. Algorithmen – Quelle je Funktion (38.3)

| Funktion | Beste lizenzsaubere Quelle | Lizenz | Empfehlung |
|---|---|---|---|
| Gaußscher Weichzeichner | PDN 3.36 `GaussianBlurEffect` / Pinta; Core Image `CIGaussianBlur`, MPS `MPSImageGaussianBlur` | MIT / System | MPS für Geschwindigkeit; PDN-Kern für exakte PDN-Optik |
| Bewegungsunschärfe | PDN 3.36 `MotionBlurEffect` / Pinta; `CIMotionBlur`; GPUImage3 `MotionBlur` | MIT / System / BSD-3 | Metal-Port der PDN-Abtastung (zentriert/gerichtet) |
| Radialunschärfe (Dreh) | PDN 3.36 `RadialBlurEffect` / Pinta | MIT | Metal-Port (Core Image hat keine Dreh-Unschärfe) |
| Zoomunschärfe | PDN 3.36 `ZoomBlurEffect`; `CIZoomBlur`; GPUImage3 | MIT / System / BSD-3 | Metal-Port mit PDN-Parametern |
| Schärfen | PDN 3.36 `SharpenEffect` (LocalHistogram); `CIUnsharpMask`, `CISharpenLuminance` | MIT / System | Unscharf maskieren + PDN-Variante |
| Rauschreduzierung | PDN 3.36 `ReduceNoiseEffect`, `MedianEffect`; `CINoiseReduction`, MPS Median | MIT / System | PDN-Algorithmus portieren; Core Image als „Schnell“-Modus |
| Kantenerkennung | PDN 3.36 `EdgeDetectEffect` (gerichtete Faltung); MPS `MPSImageSobel`; GPUImage3 Sobel/Prewitt | MIT / System / BSD-3 | PDN-Faltung auf Metal |
| Verzerrungen | PDN 3.36 `WarpEffectBase` (Wölben, Dellen, Wirbel, Polar-Inversion, Kacheln) / Pinta | MIT | Ein generischer Metal-„Warp“-Kernel + PDN-Abbildungsfunktionen |
| Farbanpassungen | PDN 3.36 `UnaryPixelOps`, `HueAndSaturationAdjustment`, `BrightnessAndContrastAdjustment`; `CIColorControls`, `CIExposureAdjust`, `CIHighlightShadowAdjust`, `CITemperatureAndTint` | MIT / System | PDN-Formeln für die 9 Klassiker, Core Image für Belichtung, Lichter/Schatten, Temperatur |
| Gradationskurven | PDN 3.36 `CurvesEffect` + `SplineInterpolator` + Kurven-UI-Logik / Pinta | MIT | Port (LUT auf GPU anwenden) |
| Tonwertkorrektur | PDN 3.36 `LevelsEffect`, `UnaryPixelOps.Level`, `AutoLevelEffect` / Pinta | MIT | Port |
| Mischmodi | PDN 3.36 `UserBlendOps` (14 Modi, Ganzzahl-Formeln) | MIT | **Pflicht für PDN-Kompatibilität**, als Metal-Shader + CPU-Referenz |
| Ebenentransformationen | PDN 3.36 `MoveTool`/`RotateZoom`, Pinta `BaseTransformTool`, `Matrix3x2D` | MIT | Port; Abtastung über Metal (bilinear/bikubisch/anisotrop) |
| Auswahlmasken | Clipper2 (Polygone) + eigene Alpha-Maske (Antialiasing); Pinta `DocumentSelection` als Vorbild | Boost / MIT | Clipper2 direkt, Maske selbst |
| Bildskalierung | PDN 3.36 `Surface.*FitSurface`; vImage (`vImageScale`), `CILanczosScaleTransform`; stb_image_resize2 | MIT / System / MIT-PD | vImage/Lanczos + PDN-Bikubisch für Kompatibilität |
| Bildrotation | vImage `vImageRotate`, PDN `RotateDocumentFunction` (90/180/270), Pinta | System / MIT | vImage für freie Winkel, 90°-Schritte verlustfrei selbst |
| Farbquantisierung | PaintDotNet.Quantization (Octree, verbessert); PDN 3.36 `OctreeQuantizer`; `CIKMeans`/`CIPalettize` | MIT / System | Octree-Port mit Fixes; Dithering nach Floyd-Steinberg selbst |

---

## 3. PDN-Dateiformat (38.4)

**Quellen:** PDN 3.36 `Data/Document.cs` und `Core/MemoryBlock.cs` (MIT, Original-Implementierung), pypdn (MIT), Microsoft-Spezifikation **MS-NRBF** (öffentlich), Format-Notizen von paint.rust, AssetHoard-Artikel. Aktuelle Paint.NET-Binärdateien wurden **nicht** angesehen.

### 3.1 Struktur (gültig von Paint.NET 2.1 bis 5.1.12)

```
Offset 0   4 Byte   "PDN3"                       Magic
Offset 4   3 Byte   N (24-Bit, Little Endian)     Länge des XML-Kopfs in Byte
Offset 7   N Byte   UTF-8-XML  <pdnImage width= height= layers= savedWithVersion=>
                                 <custom><thumb png="…base64…"/></custom></pdnImage>
danach     2 Byte   00 01  → .NET-Serialisierung (MS-NRBF), „deferred“ Pixeldaten
                    1F 8B  → ältere Variante: alles gzip-komprimiert (≤ 2.0 ohne Magic)
NRBF-Graph:  PaintDotNet.Document { width, height, layers: LayerList, userMetaData,
             savedWith Version } → BitmapLayer { properties: name, visible,
             isBackground, opacity, blendOp (Klassenname z. B. …UserBlendOps+MultiplyBlendOp) }
             → Surface { width, height, stride, scan0: MemoryBlock }
Pixel (MemoryBlock, „deferred“ nach dem Graphen):
   1 Byte formatVersion (0 = gzip-Chunks, 1 = unkomprimiert)
   4 Byte chunkSize (Big Endian, Standard 1 048 576)
   je Chunk: 4 Byte Chunk-Nr., 4 Byte gespeicherte Länge N, N Byte Daten (Big Endian, Reihenfolge beliebig)
Pixelformat: BGRA, 8 Bit je Kanal, **nicht vormultipliziert**, Zeilen mit stride
```

### 3.2 Inhalte
- **Metadaten:** XML-Kopf (Größe, Ebenenanzahl, Version, Vorschaubild PNG), `userMetaData` im Graphen (EXIF/benutzerdefiniert), Auflösung/DPI.
- **Ebenen:** Reihenfolge unten → oben; Name, Sichtbarkeit, Hintergrund-Flag, Deckkraft 0–255, Mischmodus als **Klassenname** der BlendOp (14 Modi).
- **Alpha:** voller 8-Bit-Alpha je Pixel, gerade (straight) Alpha; RGB unter Alpha 0 bleibt erhalten.
- **Komprimierung:** gzip je 1-MiB-Chunk.
- **Versionen:** 3.5.10 und 4.21 (interne Versionsnummer, Paint.NET 4.2.x) mit pypdn verifiziert; laut AssetHoard teilen auch Dateien aus 5.1.8/5.1.9 die Kopfstruktur; paint.rust liest eine echte 5.1.12-Datei. Paint.NET 5 kann Farbprofile speichern (Metadaten). **Paint.NET 6.0 (2027) führt ein neues PDN-Format ein** (laut Roadmap mit öffentlicher Doku und evtl. Referenz-Implementierung).

### 3.3 Eignung vorhandener Implementierungen

| Implementierung | Lesen | Schreiben | Für aktuelle PDN geeignet? |
|---|---|---|---|
| PDN 3.36 `Document.FromStream/SaveToStream` (MIT) | ✔ | ✔ | Original-Logik, aber über .NET BinaryFormatter (auf macOS/Swift nicht vorhanden) → nur als Spezifikation |
| pypdn (MIT) | ✔ (3.5–4.2 verifiziert) | ✘ | Beste offene Lese-Referenz |
| paint.rust `pdn3` (MIT) | ✔ (Normal) | ✔ experimentell | Writer nicht von Paint.NET bestätigt |
| PhotoCraft / paint.software (MIT) | ✔ | ✘ | Referenz |
| OpenPDN | – | – | **ausgeschlossen** (dekompiliert) |

**Plan:** Eigener Swift-NRBF-Reader/-Writer nach MS-NRBF; Lesepfad nach pypdn-Logik; Schreiben erzeugt den Graphen exakt in der Form, die Paint.NET 3.36 `SaveToStream` erzeugt (Klassen- und Assemblynamen sind Daten). **Zertifizierung nur mit echten Paint.NET-5.1.12-Dateien** (Abschnitt 7). Beim Parsen harte Grenzen (Größe, Tiefe, Anzahl) – NRBF niemals „ausführen“.

---

## 4. Funktionsvergleich: aktuelles Paint.NET 5.1.12 vs. offene Quellen

Legende: ✔ vorhanden · ◐ teilweise · ✘ fehlt · Quelle für Paint.NET 5.x: offizielle Release-Notes 5.0/5.1 und Roadmap.

| Bereich | Paint.NET 5.1.12 | PDN 3.36 (MIT) | Pinta 3.2-dev (MIT) | Apple-Frameworks | Lücke → eigene Entwicklung |
|---|---|---|---|---|---|
| Ebenen, Deckkraft, Sichtbarkeit | ✔ | ✔ | ✔ | – | – |
| 14 PDN-Mischmodi | ✔ | ✔ | ◐ (Ops vorhanden, nicht alle als Ebenenmodus) | ◐ (andere Formeln) | Ebenenmodi vervollständigen |
| Auswahl Rechteck/Ellipse/Lasso/Zauberstab | ✔ | ✔ (GPC ✘) | ✔ (Clipper) | – | Clipper2 statt GPC |
| Auswahl-Antialiasing, Qualität | ✔ | ✘ | ◐ | – | eigene Masken-Engine |
| Pinsel mit Druck/Glättung/Abstand | ✔ | ✘ | ◐ (ohne Druck) | NSEvent-Druck | neue Pinsel-Engine |
| Formen mit editierbaren Griffen | ✔ | ✘ | ◐ (re-editierbare Formen) | – | ausbauen |
| Text, Verlauf, Kopierstempel, Umfärben, Farbeimer | ✔ | ✔ | ✔ | Core Text | – |
| Anpassungen | ✔ (9 klassische + Belichtung, Lichter/Schatten, Temperatur/Tönung seit 5.0) | 9 | 9 | Belichtung, Lichter/Schatten, Temperatur | 3 neue |
| Effekte | alle 3.36-Effekte (teils überarbeitet) + neu u. a. Bokeh, Begradigen, Schlagschatten (5.0), Skizzen-, Quadrat-, Median-Unschärfe (5.1), Quantisieren (4.2.16) | 32 | 37 | viele Bausteine | neue 4.x/5.x-Effekte |
| GPU-Rendering | ✔ (Direct2D) | ✘ | ✘ | Metal | eigene Render-Pipeline |
| Farbmanagement (ICC, P3, Adobe RGB) | ✔ (5.1) | ✘ | ✘ | ColorSync/Core Image | Integration |
| Resampling Lanczos/Adaptiv | ✔ | ✘ (Super-Sampling) | ◐ | vImage/CI | – |
| Undo/Redo, Verlaufsfenster | ✔ | ✔ | ✔ | – | – |
| Dateiformate | PDN, PNG, JPEG, BMP, GIF, TIFF, TGA, DDS, WebP, AVIF, HEIC, JPEG XL | PDN, PNG, JPEG, BMP, GIF, TIFF, TGA, DDS | PNG, JPEG, BMP, TIFF, ICO, WebP, ORA, TGA, PPM | ImageIO: PNG, JPEG, HEIC, AVIF, TIFF, GIF, BMP, WebP(lesen) | PDN-Writer, DDS, JPEG XL, ORA-Port |
| Plugins | ✔ (Windows-API) | ✔ (alt) | ✔ (Mono.Addins) | – | eigenes Konzept; **Paint.NET-Plugins laufen grundsätzlich nicht** (Windows/.NET/Direct2D) |
| Tablet/Stift | ✔ (Windows Ink) | ✘ | ◐ | ✔ (Druck, Neigung, Sidecar) | – |

---

## 5. Variantenvergleich (38.2)

| Kriterium | **A: Pinta erweitern** | **B: Native Swift/AppKit + Ports** |
|---|---|---|
| Funktionsumfang am Start | Hoch (sofort fast alle Funktionen von Paint.NET 3.36 und mehr) | Niedrig – wächst schnell durch mechanische C#→Swift-Ports |
| Entwicklungsaufwand bis „Paint.NET-nah“ | Mittel für Funktionen, **hoch für die Oberfläche** (GTK-UI auf Paint.NET-Bedienung umbauen, Fork pflegen) | Hoch für Kern + UI am Anfang, danach pro Funktion gering |
| macOS-Integration | Schwach: GTK-Header-Bar statt Menüleiste, GTK-Dialoge, eingeschränkte Dienste/Teilen/Quick Look, Druck via GTK, kein Stift-Druck | **Voll:** Menüleiste, native Dialoge, Dokumentfenster/Tabs, Versionen/Autosave, Quick Look, Teilen, Retina, Dunkelmodus, Stift/Sidecar |
| Geschwindigkeit | Cairo/CPU; große Bilder und Effekte langsam | Metal/MPS/Core Image auf Apple Silicon – Echtzeit-Vorschau möglich |
| Wartbarkeit | Abhängig von Upstream-Umbauten, .NET 10 + GTK 4 + Homebrew-Bundle, `disable-library-validation` nötig | Ein Swift-Codebestand, Apple-Werkzeuge, keine Laufzeit-Bündel |
| Stabilität | Gut auf Linux; macOS-GTK hat bekannte Eigenheiten (Fokus, HiDPI, Tastatur) | Hängt von eigener Qualität ab; Apple-Frameworks stabil |
| Bundle-Größe | Groß (.NET-Runtime + GTK + Icons) | Klein |
| Lizenzrisiko | Gering (MIT), aber Icons/Ressourcen bereinigen | Gering (nur geprüfte Algorithmen, eigene Grafiken) |

**Entscheidung: Variante B.** Der Mehraufwand liegt vor allem in Oberfläche und Render-Kern; die eigentlichen Algorithmen (Effekte, Anpassungen, Mischmodi, Zauberstab, Kurven, Quantisierung, History-Konzept, PDN-Logik) existieren lizenzsauber und werden **nicht neu erfunden**, sondern portiert. Pinta wird zusätzlich als **lauffähige Referenz** genutzt, um Ergebnisse Pixel für Pixel zu vergleichen (Testorakel).

---

## 6. Entwicklungsentscheidung je Baustein (38.7)

| Baustein | Herkunft | Art |
|---|---|---|
| Dokumentmodell, Ebenen, Deckkraft, Sichtbarkeit | Konzept PDN 3.36 `Document`/`BitmapLayer` + Pinta `DocumentLayers` | Port, Datenhaltung in Kacheln (Metal-Texturen + CPU-Spiegel, BGRA straight wie PDN) |
| Mischmodi (14) | PDN 3.36 `UserBlendOps` | Port (CPU-Referenz + Metal-Shader, gegen PDN-3.36-Formeln getestet) |
| Undo/Redo | PDN `BitmapHistoryMemento` (nur geänderte Region, auslagerbar) + Pinta `SurfaceDiff` | Port des Konzepts |
| Auswahl | Clipper2 (Polygone) + eigene antialiasierte Maske | Übernahme Clipper2, Rest eigen |
| Zauberstab/Farbeimer | PDN 3.36 `FloodToolBase` / Pinta `FloodTool` (Toleranz, global/lokal) | Port |
| Werkzeuge (Auswahl, Verschieben, Text, Formen, Verlauf, Stempel, Umfärben) | PDN 3.36 `tools/*` + Pinta `Pinta.Tools` | Logik-Port, Rendering über Core Graphics/Metal |
| Pinsel-Engine | Pinta `BasePaintBrush` als Start | Neu (Druck, Glättung, Abstand, Härte) |
| Anpassungen (9 klassisch) | PDN 3.36 / Pinta | Port |
| Anpassungen (Belichtung, Lichter/Schatten, Temperatur/Tönung) | Core Image | Neu über Systemfilter |
| Effekte (32 klassisch) | PDN 3.36 / Pinta | Port nach Metal (Warp-, Faltungs-, Histogramm-Kernels) |
| Effekte (neu in 5.x) | Core Image/MPS, GPUImage3-Kernels (BSD), eigene Shader | Neu |
| Quantisierung/Dithering | PaintDotNet.Quantization (MIT) | Port mit beiden Hinweisen |
| Skalieren/Drehen | vImage + PDN-Bikubisch | System + Port |
| Farbmanagement | ColorSync / Core Image Farbräume | System |
| Formate PNG/JPEG/TIFF/GIF/BMP/HEIC/AVIF | ImageIO | System |
| PDN lesen/schreiben | Eigener Swift-NRBF nach MS-NRBF + pypdn-Logik + PDN-3.36-Struktur | Neu (Port-Logik), mit echten 5.1.12-Dateien zertifiziert |
| ORA | Pinta `OraFormat` | Port |
| DDS/TGA | PDN 3.36 DDS-Plugin (Dean Ashton, MIT) + libsquish (MIT), TGA aus PDN | Port bzw. C-Bibliothek einbinden |
| Oberfläche | Menüstruktur nach PDN 3.36 `Menus/*` (Anordnung), **eigene Texte und eigene Icons** | Neu (AppKit) |

**Nie übernommen:** aktuelle Paint.NET-Binärdateien/Decompilate, OpenPDN, Paint.NET-Logo, Icons, PNG/RESX/Strings aus 3.36, GPC, CC-BY-NC-Inhalte, Pinta-Icons aus Paint.NET-Herkunft, der Name „Paint.NET“ oder „PDN“ im Produktnamen.

---

## 7. Nächste Schritte

1. **Testkorpus beschaffen:** auf einem Windows-PC mit Paint.NET 5.1.12 Testbilder speichern – 1×1 bis 4000×3000, 1/2/64 Ebenen, alle 14 Mischmodi, Deckkraft 0/1/127/128/255, versteckte Ebenen, Sonderzeichen im Ebenennamen, 72/96/300 DPI, eingebettetes Farbprofil. Dazu je ein PNG-Export als Soll-Bild.
2. **Swift-Projektgerüst** (AppKit, Dokument-basierte App, Swift Package für den Kern), SPDX-Köpfe und `THIRD_PARTY_LICENSES.md` ab dem ersten portierten Code pflegen.
3. **Reihenfolge der Ports:** Surface/ColorBgra → Mischmodi → Ebenen-Komposition (Metal) → Undo → PDN-Reader → Auswahl (Clipper2) → Werkzeuge → Anpassungen → Effekte → PDN-Writer → neue 5.x-Funktionen.
4. **Testorakel:** gleiche Eingaben durch Pinta (lauffähig) bzw. PDN-3.36-Formeln schicken und Pixel vergleichen; Toleranzen je Effekt festlegen.
5. **Lizenz-Gate im Build:** jede neue Fremddatei braucht einen Eintrag in `THIRD_PARTY_LICENSES.md`, sonst schlägt der Build fehl.

---

### Quellen
- [milliethompson/PaintDotNet](https://github.com/milliethompson/PaintDotNet) · [paintdotnet/release](https://github.com/paintdotnet/release) · [paintdotnet/PdnV5EffectSamples](https://github.com/paintdotnet/PdnV5EffectSamples) · [paintdotnet/PaintDotNet.Quantization](https://github.com/paintdotnet/PaintDotNet.Quantization)
- [PintaProject/Pinta](https://github.com/PintaProject/Pinta) · [addisonElliott/pypdn](https://github.com/addisonElliott/pypdn) · [diegomgarcia/paint.rust](https://github.com/diegomgarcia/paint.rust) · [Univers4craft/paint.software](https://github.com/Univers4craft/paint.software) · [storytold/photocraft](https://github.com/storytold/photocraft) · [EricKrouss/OpenPDN](https://github.com/EricKrouss/OpenPDN)
- [AngusJohnson/Clipper2](https://github.com/AngusJohnson/Clipper2) · [BradLarson/GPUImage3](https://github.com/BradLarson/GPUImage3) · [MetalPetal/MetalPetal](https://github.com/MetalPetal/MetalPetal) · [nothings/stb](https://github.com/nothings/stb)
- [paint.net Roadmap](https://paint.net/roadmap.html) · [paint.net 5.0 Release-Blog](https://blog.paint.net/2023/01/10/paint-net-5-0-is-now-available/) · [BetaNews zu Paint.NET 5.1](https://betanews.com/2024/11/14/paint-net-5-1-unveils-color-management-support-new-and-improved-effects/) · [AssetHoard: Reading Paint.NET Files](https://assethoard.com/blog/paint-net-pdn-support) · [MS-NRBF-Spezifikation](https://learn.microsoft.com/en-us/openspecs/windows_protocols/ms-nrbf/75b9fe09-be15-475f-85b8-ae7b7558cfe5)
