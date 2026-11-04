# KNOWN_ISSUES.md

Stand: Phase 1, 04.11.2026. Offene Punkte, Risiken und Konflikte. Jeder Punkt hat eine ID, auf die Matrix und Status verweisen.

## B – Build und Umgebung

| ID | Problem | Folge | Lösungsweg | Status |
|---|---|---|---|---|
| B-1 | Arbeitsumgebung ist Linux; Swift/AppKit/Metal/Xcode sind dort nicht verfügbar | Es kann weder kompiliert noch getestet noch eine DMG gebaut werden | (a) Mac des Nutzers verknüpfen (Xcode erforderlich) oder (b) GitHub-Repository + GitHub Actions (macOS-Runner) | **offen – Entscheidung des Nutzers** |
| B-2 | Keine Apple-Developer-ID bekannt | App nur ad-hoc signierbar, nicht notarisierbar; Gatekeeper-Warnung beim ersten Start | Developer-ID-Zertifikat + notarytool, sonst Dokumentation „Rechtsklick › Öffnen“ | offen |
| B-3 | Universal-Build für Intel nur testbar mit Intel-Mac oder Rosetta-Lauf | x86_64-Pfad ungetestet | Test über `arch -x86_64` auf Apple Silicon bzw. Intel-Runner | offen |

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
| R-9 | Ob Sichtbarkeit umschalten einen Verlaufseintrag erzeugt | L-05 | Referenzmessung |
| R-10 | Retina: Bedeutung von „100 %“ und Standardgröße 800×600 × DPI-Faktor | UI-04, V-05 | Vorschlag: 100 % = 1 Bildpixel pro logischem Punkt; Option für physische Pixel |

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
| T-3 | Pixelgenaue Gleichheit mit Referenz bei GPU-Effekten | Toleranzen je Effekt definieren und dokumentieren (Projektvorgabe 29) |
