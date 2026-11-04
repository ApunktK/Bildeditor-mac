# Funktionsmatrix Teil 4: Korrekturen und Effekte
# Hinweis Standardwerte: Die Doku nennt fast nie Standardwerte oder Wertebereiche. Werte aus Doku-Screenshots
# sind Beispielzustände („Beispiel“), keine belegten Standardwerte. Messung an einer Referenzinstallation nötig.
G = "Wirkt auf aktive Ebene innerhalb der Auswahl; Vorschau live; OK = 1 Verlaufseintrag; Abbrechen = unverändert"
T = "Effekt-Engine: Metal-Kernel, Vorschau abbrechbar (neuere Parameter verdrängen ältere)"
def fx(id_, pfad, besch, ref, eing, std, mac="", test=""):
    return (id_, pfad, besch, ref, eing, std, G, "Abbrechen/Fehler → Originalpixel bleiben", (mac + "; " if mac else "") + T, test or "Bild öffnen, Effekt mit Beispielwerten, Abbrechen = unverändert, OK + Undo = Original")
ROWS = [
# ---------------- Korrekturen (AdjustmentsMenu) ----------------
fx("A-01","Korrekturen › Auto-Pegel (Strg+Umschalt+L)","Automatische Tonwertkorrektur","Kein Dialog; entspricht Tonwerte › Auto (AdjustmentsMenu)","–","–","Cmd+Shift+L","Ergebnis = Levels-Auto-Ergebnis"),
fx("A-02","Korrekturen › Schwarzweiß (Strg+Umschalt+G)","Entsättigen","Kein Dialog; Graustufen (AdjustmentsMenu); Gewichtung der Kanäle **ungeklärt**","–","–","Cmd+Shift+G","R=G=B je Pixel; Alpha unverändert"),
fx("A-03","Korrekturen › Helligkeit/Kontrast… (Strg+Umschalt+T)","Helligkeit und Kontrast","Zwei Regler mit Zahlenfeld (AdjustmentsMenu)","Helligkeit, Kontrast","Beispiel 0/0 bzw. 0/50; Bereiche **ungeklärt**","Cmd+Shift+T"),
fx("A-04","Korrekturen › Gradationskurven… (Strg+Umschalt+M)","Kurven","Transfer-Map Luminosität oder RGB (Häkchen Rot/Grün/Blau); Punkt hinzufügen per Klick, entfernen per Rechtsklick, ziehen; Kurve läuft durch alle Punkte; Koordinatenanzeige; Zurücksetzen (Curves)","Kurvenpunkte, Modus, Kanäle","Diagonale, Luminosität","Cmd+Shift+M","Kurve invertiert → Helligkeit invertiert, Farbe bleibt"),
fx("A-05","Korrekturen › Belichtung…","Belichtung","Ein Regler (AdjustmentsMenu, Screenshot)","Belichtung","**ungeklärt**","kein Kürzel"),
fx("A-06","Korrekturen › Lichter/Schatten…","Lichter und Schatten","Regler Lichter, Schatten, Klarheit, Radius (Screenshot)","4 Werte","**ungeklärt**","kein Kürzel"),
fx("A-07","Korrekturen › Farbton/Sättigung… (Strg+Umschalt+U)","Farbton, Sättigung, Helligkeit","Farbton dreht, Sättigung und Helligkeit starten bei 0 laut Text; Screenshot zeigt Sättigung als Zahl ≠ 0 → **Skala ungeklärt** (AdjustmentsMenu)","3 Werte","Farbton 0, Helligkeit 0; Sättigung **ungeklärt**","Cmd+Shift+U"),
fx("A-08","Korrekturen › Alpha invertieren (Strg+Alt+I)","Deckkraft umkehren","Kein Dialog; zweimal = Original (AdjustmentsMenu)","–","–","Cmd+Option+I","α' = 255 − α; 2× = Original"),
fx("A-09","Korrekturen › Farben invertieren (Strg+Umschalt+I)","Negativ","Kein Dialog; zweimal = Original (AdjustmentsMenu)","–","–","Cmd+Shift+I","RGB' = 255 − RGB; Alpha bleibt"),
fx("A-10","Korrekturen › Tonwerte… (Strg+L)","Levels","Eingabe-Schwarz/Weißpunkt, Ausgabe Schwarz/Grau(Gamma)/Weiß, Farbfelder per Doppelklick, Histogramme Ein/Aus, Kanäle R/G/B einzeln, Auto, Zurücksetzen (Levels)","Punkte, Gamma, Kanäle","0/255, Gamma 1,00 (Screenshot)","Cmd+L","Standardwerte = Identität"),
fx("A-11","Korrekturen › Tontrennung… (Strg+Umschalt+P)","Posterize","Rot/Grün/Blau(/Alpha laut Screenshot) 2–64 Stufen, „Verknüpft“ (AdjustmentsMenu)","Stufen je Kanal, ☐ verknüpft","Beispiel 6, verknüpft","Cmd+Shift+P","Stufen 2 → nur 2 Werte je Kanal"),
fx("A-12","Korrekturen › Sepia… (Strg+Umschalt+E)","Sepia","Ein Regler Intensität (AdjustmentsMenu)","Intensität","**ungeklärt**","Cmd+Shift+E"),
fx("A-13","Korrekturen › Temperatur/Tönung…","Farbtemperatur und Tönung","Zwei Regler (AdjustmentsMenu, Screenshot)","Temperatur, Tönung","**ungeklärt**","kein Kürzel"),
# ---------------- Effekte allgemein (EffectsMenu) ----------------
("FX-00","Effekte › Letzten Effekt wiederholen (Strg+F)","Wiederholen ohne Dialog","Oberster Menüeintrag „<Effekt> wiederholen“, gleiche Parameter (EffectsMenu)","–","–","1 Verlaufseintrag","kein Effekt bisher → deaktiviert","Cmd+F kollidiert mit „Suchen“ (kein Suchfeld, vertretbar) → Cmd+F","Effekt anwenden, Cmd+F → zweite identische Anwendung"),
("FX-01","Effekte › Plugin-Fehler…","Nur bei Ladefehlern sichtbar","Öffnet Einstellungen › Plugin-Fehler (EffectsMenu)","–","–","–","–","Eigenes Plugin-System","Defektes Plugin → Eintrag erscheint"),
("FX-02","Effekte › Untermenüs","9 Kategorien","Künstlerisch, Unschärfe, Farbe, Verzerren, Rauschen, Objekt, Foto, Rendern, Stilisieren; Plugins mit Puzzle-Symbol; Tooltip mit Autor (EffectsMenu)","–","–","–","–","–","Menüstruktur = Referenz"),
# Künstlerisch
fx("FX-10","Effekte › Künstlerisch › Tintenskizze…","Tuschezeichnung","Regler Tintenkontur, Färbung (EffectsArtisticMenu)","2 Werte","**ungeklärt**"),
fx("FX-11","Effekte › Künstlerisch › Ölgemälde…","Ölgemälde","Pinselgröße, Grobheit (EffectsArtisticMenu)","2 Werte","**ungeklärt**"),
fx("FX-12","Effekte › Künstlerisch › Bleistiftskizze…","Bleistift","Spitzengröße, Bereich (EffectsArtisticMenu)","2 Werte","**ungeklärt**"),
# Unschärfe (10)
fx("FX-20","Effekte › Unschärfe › Bokeh…","Bokeh","Radius, Gamma-Anhebung, Qualität; ersetzt „Unfocus“ (EffectsBlursMenu)","3 Werte","**ungeklärt**"),
fx("FX-21","Effekte › Unschärfe › Fragment…","Fragmente","Anzahl, Abstand, Drehung (EffectsBlursMenu)","3 Werte","**ungeklärt**"),
fx("FX-22","Effekte › Unschärfe › Gaußscher Weichzeichner…","Gauß","Radius, Gamma-Anhebung, Qualität (EffectsBlursMenu)","3 Werte","Beispiel Radius 4,0, Gamma 0,00, Qualität 4 (Screenshot)","","Beispiel D der Projektvorgabe"),
fx("FX-23","Effekte › Unschärfe › Median…","Median","Radius, Perzentil (Standard 50 laut Text), Qualität (EffectsBlursMenu)","3 Werte","Perzentil 50"),
fx("FX-24","Effekte › Unschärfe › Bewegungsunschärfe…","Bewegung","Winkel, Distanz, ☐ Zentriert, Randverhalten Klemmen/Umbrechen/Spiegeln/Transparent (EffectsBlursMenu)","4 Werte","Randverhalten laut Screenshot Klemmen"),
fx("FX-25","Effekte › Unschärfe › Radialunschärfe…","Drehunschärfe","Winkel, Mittelpunkt (Doppelregler/Fadenkreuz in Vorschau), Qualität (EffectsBlursMenu)","Winkel, X/Y, Qualität","Mitte 0,00/0,00 (Screenshot)"),
fx("FX-26","Effekte › Unschärfe › Skizzen-Unschärfe…","Sketch Blur","Radius, Perzentil (Standard 50), Glätte; P²-Quantil-Schätzer (EffectsBlursMenu)","3 Werte","Perzentil 50","Algorithmus nach öffentlicher P²-Literatur selbst implementieren"),
fx("FX-27","Effekte › Unschärfe › Quadrat-Unschärfe…","Box-Blur","Radius, Gamma-Anhebung (EffectsBlursMenu)","2 Werte","**ungeklärt**"),
fx("FX-28","Effekte › Unschärfe › Oberflächenunschärfe…","Kantenerhaltend","Radius, Schwelle (EffectsBlursMenu)","2 Werte","**ungeklärt**"),
fx("FX-29","Effekte › Unschärfe › Zoom-Unschärfe…","Zoom","Distanz, Fokus, Mittelpunkt, Qualität (EffectsBlursMenu)","4 Werte","Mitte 0/0"),
# Farbe
fx("FX-30","Effekte › Farbe › Quantisieren…","Farbreduktion","Algorithmus Median Cut/Octree, Farben ≤256, Dithering 9 Stufen, Transparenzschwelle (EffectsColorMenu, Screenshot)","4 Werte","Beispiel Octree; Rest **ungeklärt**","Octree/Median Cut nach THIRD_PARTY_LICENSES"),
# Verzerren (9)
fx("FX-40","Effekte › Verzerren › Wölben…","Bulge","Stärke, Mittelpunkt, Randverhalten Klemmen/Umbrechen/Spiegeln/Transparent, Qualität (EffectsDistortMenu)","4 Werte","**ungeklärt**"),
fx("FX-41","Effekte › Verzerren › Kristallisieren…","Polygonzellen","Zellgröße, Qualität, Zufall (EffectsDistortMenu)","3 Werte","**ungeklärt**"),
fx("FX-42","Effekte › Verzerren › Dellen…","Dents","Skalierung, Brechung, Detail, Turbulenz, Winkel, Qualität, Zufall (EffectsDistortMenu)","7 Werte","**ungeklärt**"),
fx("FX-43","Effekte › Verzerren › Milchglas…","Frosted Glass","Max./Min. Streuradius, Diffusion, Glätte, Zufall (EffectsDistortMenu)","5 Werte","**ungeklärt**"),
fx("FX-44","Effekte › Verzerren › Morphologie…","Erodieren/Dilatieren","Modus, Breite, Höhe, ☐ verknüpft (EffectsDistortMenu)","4 Werte","Beispiel Dilate"),
fx("FX-45","Effekte › Verzerren › Verpixeln…","Pixelate","Zellgröße; Verkleinern: Anisotrop/Multisample bilinear; Vergrößern: Nächster Nachbar/Bilinear/Bikubisch/Bikubisch (hohe Qualität) (EffectsDistortMenu, Screenshots)","3 Werte","**ungeklärt**"),
fx("FX-46","Effekte › Verzerren › Polare Inversion…","Polar","Skalierung, Versatz, Randverhalten Klemmen/Spiegeln/Umbrechen, Qualität (EffectsDistortMenu)","4 Werte","**ungeklärt**"),
fx("FX-47","Effekte › Verzerren › Kachelreflexion…","Spiegelkacheln","Winkel, Kachelgröße, Krümmung, Randverhalten, Qualität (EffectsDistortMenu)","5 Werte","**ungeklärt**"),
fx("FX-48","Effekte › Verzerren › Verdrehen…","Twist","Stärke/Richtung (±), Größe (1,00 = ganze Fläche), Mittelpunkt, Qualität (EffectsDistortMenu)","4 Werte","Größe-Beispiel 1,00"),
# Rauschen
fx("FX-50","Effekte › Rauschen › Rauschen hinzufügen…","Add Noise","Intensität, Farbsättigung, Abdeckung, Zufall; keine Wirkung auf transparente Bereiche (EffectsNoiseMenu)","4 Werte","**ungeklärt**","","Transparenter Bereich bleibt unverändert"),
fx("FX-51","Effekte › Rauschen › Rauschen reduzieren…","Reduce Noise","Radius, Stärke (EffectsNoiseMenu)","2 Werte","**ungeklärt**"),
# Objekt
fx("FX-60","Effekte › Objekt › Schlagschatten…","Drop Shadow","Schattenradius, Abstand, Winkel, Deckkraft, Farbe, ☐ Nur Schatten; benötigt Transparenz um Objekt (EffectsObjectMenu)","6 Werte","**ungeklärt**","","Objekt ohne Transparenz → Hinweistext"),
# Foto (6)
fx("FX-70","Effekte › Foto › Leuchten…","Glow","Radius, Helligkeit, Kontrast (EffectsPhotoMenu)","3 Werte","**ungeklärt**"),
fx("FX-71","Effekte › Foto › Rote Augen entfernen…","Red Eye","Stärke; Hinweis Auswahl der Augen (EffectsPhotoMenu)","1 Wert","**ungeklärt**"),
fx("FX-72","Effekte › Foto › Schärfen…","Sharpen","Stärke, Schwelle (EffectsPhotoMenu)","2 Werte","**ungeklärt**"),
fx("FX-73","Effekte › Foto › Porträt weichzeichnen…","Soften Portrait","Weichheit, Beleuchtung, Wärme (EffectsPhotoMenu)","3 Werte","**ungeklärt**"),
fx("FX-74","Effekte › Foto › Begradigen…","Straighten","Winkel ±45° (2 Dezimalen), Umschalt = 15°; Sampling Bikubisch (Standard)/Nächster Nachbar/Bilinear; automatische Skalierung (EffectsPhotoMenu)","Winkel, Sampling","Bikubisch"),
fx("FX-75","Effekte › Foto › Vignette…","Vignette","Mittelpunkt, Radius, Stärke; immer schwarz (EffectsPhotoMenu)","4 Werte","Beispiel Radius 0,50, Stärke 1,00 (Screenshot)"),
# Rendern
fx("FX-80","Effekte › Rendern › Wolken…","Clouds","Register Wolken: Skalierung, Rauheit, Mischmodus, Zufall; Register Farben: Farbe 1/2 (Startwert Primär/Sekundär, bleibt bis Neustart) (EffectsRenderMenu)","5 Werte","Farben = Primär/Sekundär","Zufallsgenerator selbst (nicht Referenz-RNG)","Alpha 0 in Farbe 1 → einfarbig"),
fx("FX-81","Effekte › Rendern › Julia-Fraktal…","Julia","Faktor, Zoom, Winkel, Qualität, Mischmodus (EffectsRenderMenu)","5 Werte","**ungeklärt**"),
fx("FX-82","Effekte › Rendern › Mandelbrot-Fraktal…","Mandelbrot","Faktor, Zoom, Winkel, Qualität, ☐ Farben invertieren, Mischmodus (EffectsRenderMenu)","6 Werte","Beispiel Faktor 1,00, Zoom 10,00, Winkel 0, Mischmodus Overwrite (Screenshot)"),
fx("FX-83","Effekte › Rendern › Turbulenz…","Turbulence","Oktaven, Periode, Größe, Rauschtyp Turbulenz/Fraktale Summe, Zufall, Mischen/Überschreiben (EffectsRenderMenu)","6 Werte","**ungeklärt**"),
# Stilisieren
fx("FX-90","Effekte › Stilisieren › Kanten erkennen…","Edge Detect","Stärke, Weichzeichnung, Algorithmus Prewitt/Sobel (Standard), ☐ Kanten überlagern (EffectsStylizeMenu)","4 Werte","Sobel"),
fx("FX-91","Effekte › Stilisieren › Prägen…","Emboss","Winkel; Ergebnis immer Graustufen (EffectsStylizeMenu)","1 Wert","**ungeklärt**"),
fx("FX-92","Effekte › Stilisieren › Kontur…","Outline","Dicke, Intensität, Qualität (EffectsStylizeMenu)","3 Werte","**ungeklärt**"),
fx("FX-93","Effekte › Stilisieren › Relief…","Relief","Winkel; mischt mit Original (EffectsStylizeMenu)","1 Wert","**ungeklärt**"),
]
