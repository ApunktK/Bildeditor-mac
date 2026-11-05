# KNOWN_ISSUES.md

Stand: Phase 2, 04.11.2026. Offene Punkte, Risiken und Konflikte. Jeder Punkt hat eine ID, auf die Matrix und Status verweisen.

## B – Build und Umgebung

| ID | Problem | Folge | Lösungsweg | Status |
|---|---|---|---|---|
| B-1 | Arbeitsumgebung ist Linux; AppKit/Xcode dort nicht verfügbar | – | GitHub-Repository + GitHub Actions (macOS-15-Runner) baut, testet und packt | **gelöst** (Phase 2) |
| B-2 | Keine Apple-Developer-ID bekannt | App nur ad-hoc signierbar, nicht notarisierbar; Gatekeeper-Warnung beim ersten Start | Developer-ID-Zertifikat + notarytool, sonst Dokumentation „Rechtsklick › Öffnen“ | offen |
| B-3 | Universal-Build für Intel nur testbar mit Intel-Mac oder Rosetta-Lauf | x86_64-Pfad ungetestet | Test über `arch -x86_64` auf Apple Silicon bzw. Intel-Runner | offen – Universal wird gebaut (lipo geprüft), ausgeführt nur arm64 |

## R – Referenz ungeklärt

| ID | Problem | Betroffene Funktionen | Lösungsweg |
|---|---|---|---|
| R-1 | Die Doku nennt fast keine **Standardwerte und Wertebereiche** (Regler-Min/Max, Schrittweiten) | alle Korrekturen und Effekte, Werkzeugoptionen, Dialoge (72 Matrix-Einträge mit „ungeklärt“) | Messung an Paint.NET 5.1.12 auf Windows: jeden Dialog öffnen, „Zurücksetzen“ drücken, Werte und Grenzen protokollieren (Vorlage in TEST_REPORT, Abschnitt „Referenzmessung“) |
| R-2 | Mathematik der neuen 5.x-Effekte (Bokeh, Sketch Blur, Square/Median Blur neu, Kristallisieren, Turbulenz, Schlagschatten, Morphologie, Begradigen, Belichtung, Lichter/Schatten, Temperatur/Tönung) ist nicht dokumentiert | FX-20, FX-26, FX-27, FX-23, FX-41, FX-83, FX-60, FX-44, FX-74, A-05, A-06, A-13 | Eigene Implementierung nach Fachliteratur; Abgleich per Bildvergleich mit Referenzausgaben (Blackbox), **keine Dekompilierung** |
| R-3 | Widerspruch Startwerkzeug: Text sagt Pinsel, Einstellungs-Screenshot zeigt Rechteckauswahl | T-00, S-03 | Referenzmessung |
| R-4 | Ältere Doku-Seiten nennen 9 Korrekturen / 33 Effekte, aktuelle Menüs 13 / 40 | Menüs | Aktueller Menü-Screenshot gilt (13 Korrekturen, 40 Effekte) |
| R-5 | AVIF-Maximalgröße 65535 vs. 65536 | FMT-14 | Formatgrenze aus libavif/ImageIO übernehmen |
| R-6 | Füllstil-Muster (Anzahl, Aussehen), Strichmuster-Varianten | TB-26, TB-27 | Referenzmessung; Muster selbst gestalten |
| R-7 | Paint.NET-Text-Rendermodi beruhen auf DirectWrite/ClearType | T-70 | Mac-Entsprechungen festlegen (Glatt = Core Text AA; „Scharf“ = Pixelraster-Hinting) und als Abweichung dokumentieren |
| R-8 | Verhalten von Ausschneiden/Löschen/Umkehren **ohne** Auswahl | E-03, E-11, E-13 | Referenzmessung |
| R-9 | Ob Sichtbarkeit umschalten einen Verlaufseintrag erzeugt | L-05 | Referenzmessung (vorläufig: erzeugt einen Verlaufseintrag „Ebeneneigenschaften“) |
| R-10 | Retina: Bedeutung von „100 %“ und Standardgröße 800×600 × DPI-Faktor | UI-04, V-05 | Vorschlag: 100 % = 1 Bildpixel pro logischem Punkt; Option für physische Pixel (umgesetzt: 1 Bildpixel = 1 Punkt; Option für physische Pixel offen) |

## K – Tastenkürzel-Konflikte mit macOS

Grundregel: Strg → Cmd, Alt → Option. Folgende Paint.NET-Kürzel kollidieren mit reservierten oder sehr gebräuchlichen macOS-Kürzeln. Vorschläge sind **vorläufig** und werden in einer Belegungstabelle umschaltbar gemacht (Mac-Modus / Windows-Modus).

| Paint.NET | Funktion | Konflikt auf dem Mac | Vorschlag Mac-Modus |
|---|---|---|---|
| Strg+H | 90° im Uhrzeigersinn | Cmd+H = App ausblenden (System) | Cmd+Option+→ |
| Strg+G | 90° gegen Uhrzeigersinn | Cmd+G = Weitersuchen (App-übergreifende Konvention) | Cmd+Option+← |
| Strg+M | Nach unten zusammenführen | Cmd+M = Fenster minimieren | Cmd+E |
| Strg+, | Ebene ein-/ausblenden | Cmd+, = Einstellungen | Cmd+Option+, |
| Strg+Umschalt+Z | Drehen/Zoomen | Cmd+Shift+Z = Wiederholen (Mac-Standard) | Cmd+Option+Shift+R |
| Strg+Y | Wiederholen | Mac-Standard ist Cmd+Shift+Z | beide anbieten (Cmd+Y nur Windows-Modus) |
| Alt+X | Einstellungen | Cmd+, ist Mac-Standard | Cmd+, |
| Alt+F4 | Beenden | Cmd+Q | Cmd+Q |
| Entf / Rücktaste | Auswahl löschen / Auswahl füllen | Mac-Taste „⌫“ ist Rücktaste; Mac-Nutzer erwarten ⌫ = Löschen | Mac-Modus: ⌫ = Auswahl löschen, Option+⌫ = Auswahl füllen; Windows-Modus: wie Referenz |
| Strg+Tab | Nächstes Bild | Ctrl+Tab frei (Control-Taste) | Ctrl+Tab unverändert |
| F1, F4–F8 | Hilfe, Eigenschaften, Fenster | Funktionstasten auf Mac-Tastaturen oft Medientasten | F-Tasten (mit fn) + Alternativen im Menü |
| Alt + Buchstabe | Menü-Hotkeys | auf dem Mac unüblich | entfällt |
| Strg+Alt+Umschalt+˜ | Diagnose | – | entfällt (Diagnose im Einstellungsfenster) |
| Rechte Maustaste | viele Werkzeuge | Mac-Mäuse/Trackpads: Zwei-Finger-Klick; Ctrl+Klick = Kontextmenü | Rechtsklick/Zwei-Finger; Ctrl+Klick nicht als Rechtsklick-Ersatz in Werkzeugen |

## A – Bewusste Abweichungen und vorläufige Entscheidungen (Phase 2)

| ID | Punkt | Umsetzung | Grund |
|---|---|---|---|
| A-1 | Speichern als PNG/JPEG/… bei mehreren Ebenen | Datei erhält das zusammengefügte Bild, **die Ebenen im Editor bleiben erhalten** (Rückfrage „Zusammengefügt speichern“) | Referenz reduziert das Bild im Editor; Verhalten wird bei R-1 nachgemessen |
| A-2 | Ausgangszustand „ungespeichert“ | ein frisches, unverändertes neues Bild wird ohne Rückfrage geschlossen und beim Öffnen einer Datei ersetzt | entspricht dem Startbild der Referenz |
| A-3 | Kopieren ohne Auswahl | kopiert die ganze aktive Ebene | übliche Erwartung; Referenz R-8 |
| A-11 | Auswahl umkehren ohne Auswahl | wählt alles aus | Umkehrung von „nichts“; Referenz ungeklärt (E-13) |
| A-12 | Auswahlkanten | hart (pixelgenau, ohne Kantenglättung); Modus „geglättet“ fehlt | Referenz-Standard ungeklärt (TB-24) |
| A-13 | Verschieben angehobener Pixel | Ursprungsbereich wird transparent (0,0,0,0) | Referenz-Verhalten auf der Hintergrundebene ungeklärt |
| A-14 | Während des Verschiebens schwebender Pixel | das Stück wird über allen Ebenen angezeigt; beim Fertigstellen wird es korrekt in die aktive Ebene gemischt | flüssiges Ziehen auch bei großen Bildern (sonst Neuberechnung des ganzen Bildes je Mausbewegung) |
| A-15 | Rücktaste ⌫ | löscht die Auswahl nur, wenn die Zeichenfläche den Fokus hat; kein Menükürzel | sonst würde ⌫ in Textfeldern die Auswahl löschen |
| A-16 | Zuschneiden | hebt die Auswahl danach auf | Referenz ungeklärt |
| A-18 | Verlauf, Linie, Formen, Text | werden beim Loslassen bzw. Fertigstellen sofort eingemischt; Nachbearbeiten mit Anfassern (Referenz) fehlt noch | folgt (T-41, T-71, T-72, T-70) |
| A-19 | Pinselbreite | Werkseinstellung 10 px; gemeinsam für Pinsel, Radiergummi, Kopierstempel, Umfärben, Linie und Formen | Referenzwert ungeklärt (R-1) |
| A-20 | Umfärben | überträgt den Hellwert des Pixels relativ zur Sekundärfarbe auf die Primärfarbe | Verfahren der Referenz ungeklärt |
| A-21 | Ellipsenkontur | Innenkante als verkleinerte Ellipse angenähert (bei sehr flachen Ellipsen leicht ungleichmäßige Breite) | einfache, schnelle Rasterung |
| A-17 | Schmale Fenster (unter ca. 1150 pt) | beim Zauberstab wird der Auswahlmodus in der Werkzeugleiste ausgeblendet; Modi bleiben über ⌘/⌥ erreichbar | Fenster soll nicht breiter als der Bildschirm werden |
| A-4 | Farbrad | immer in voller Helligkeit dargestellt; Klick bei (fast) Schwarz setzt Hellwert 100 | sonst bei Schwarz unbenutzbar; Referenzverhalten ungeklärt |
| A-5 | Standardpalette | eigene 96 Farben (16 Grau + 16 Farbtöne × 5 Abstufungen) | Referenzpalette nicht übernommen (L-4) |
| A-6 | Werkzeugsymbole | Apple SF Symbols, Fensterschalter rechts in der Werkzeugleiste | eigene Optik (L-1) |
| A-7 | Einfügen eines größeren Bildes als Ebene | Rückfrage: vergrößern / beibehalten / abbrechen | wie Referenz-Rückfrage, Wortlaut eigen |
| A-8 | EXIF-Ausrichtung | beim Öffnen verlustfrei angewendet (nur 90°-Schritte/Spiegeln) | übliche Erwartung; Referenzverhalten ungeklärt |
| A-9 | Farbraum | Bilder werden beim Öffnen nach sRGB umgerechnet, Farbprofil wird nicht mitgespeichert | Farbmanagement folgt mit I-09/FMT-15 |
| A-10 | App-Sandbox | aus | freier Dateizugriff (Öffnen/Speichern überall, später Plugins); Hardened Runtime ist an |

## F – Formate

| ID | Problem | Folge | Lösungsweg |
|---|---|---|---|
| F-1 | ImageIO schreibt TIFF vormultipliziert | halbtransparente Pixel weichen beim TIFF-Hin-/Rückweg um ±1 ab (gemessen: R 200 → 199 bei α 128) | eigener TIFF-Schreiber mit „unassociated alpha“ (Phase 7) |
| F-2 | ImageIO schreibt kein WebP, AVIF-Schreiben nicht angeboten | WebP/AVIF nur öffnen | Bibliothek prüfen (libwebp/libavif, Lizenz) in Phase 7 |
| F-3 | Mehrseitige TIFF/animierte GIF | nur das erste Bild wird geöffnet | Phase 7 |
| F-4 | Speichern-Konfiguration der Referenz (Vorschau, Dateigröße, Bittiefe, GIF-Dithering, TGA-RLE) | derzeit nur Format und Qualität | Phase 7 |

## L – Rechtliches / Marke

| ID | Punkt | Umgang |
|---|---|---|
| L-1 | Name „Paint.NET“, Logo, Icons, Menütexte und Grafiken der Referenz sind geschützt | eigener Produktname, eigene Icons und eigene Texte; Bedienung und Anordnung werden nachgebildet, die Optik eigenständig gestaltet |
| L-2 | Weblinks im Hilfe-Menü verweisen auf Dienste von dotPDN | nicht übernehmen (HLP-02) |
| L-3 | Doku-Screenshots wurden nur zur Analyse lokal verwendet | nicht in App oder Repository übernehmen |
| L-4 | Palette, Formen-Geometrien, Muster der Referenz | eigene Werte/Geometrien erstellen, nicht abzeichnen |

## T – Technische Risiken

| ID | Risiko | Gegenmaßnahme |
|---|---|---|
| T-1 | PDN-Schreiben ohne Zertifizierung könnte Dateien liefern, die Paint.NET nicht öffnet | Schreiben erst nach Test mit echtem Paint.NET freischalten; bis dahin natives Projektformat (FMT-02) |
| T-2 | 10000×10000 px × mehrere Ebenen = mehrere GB | Kachelung, leere Kacheln sparen, Auslagerung, Warnung vor Speichermangel |
| T-4 | Anzeige setzt das Bild bei jeder Änderung vollständig auf der CPU zusammen | bei sehr großen Bildern spürbar langsam | Metal-Komposit / kachelweise Aktualisierung (ARCHITECTURE), spätestens mit den Malwerkzeugen (Phase 4) |
| T-5 | Auswahl-Operationen auf großen Bildern (12 MP, gemessen unter Linux, Release): Ellipse 0,18 s, Kontur 0,1 s, Zauberstab 0,5 s, Anheben 0,4 s, Bild neu zusammensetzen 0,5 s | spürbar bei sehr großen Bildern | kachelweise Neuzeichnung und GPU-Komposit (Phase 4/9) |
| T-3 | Pixelgenaue Gleichheit mit Referenz bei GPU-Effekten | Toleranzen je Effekt definieren und dokumentieren (Projektvorgabe 29) |
