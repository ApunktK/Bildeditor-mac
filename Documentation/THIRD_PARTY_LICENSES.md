# THIRD_PARTY_LICENSES.md

Herkunft und Lizenz aller Fremdbestandteile des macOS-Bildeditors.

**Stand:** 4. November 2026 – vor Beginn der Implementierung. Es wurde noch kein Fremdcode in das Projekt kopiert. Die Tabelle legt fest, **was** übernommen werden darf und **unter welchen Bedingungen**. Sobald eine Datei tatsächlich portiert oder eingebunden wird, wird ihr Status auf „übernommen“ gesetzt und der Pfad der Zieldatei ergänzt.

**Regeln für das Projekt**
1. Jede portierte Datei behält den Copyright-Kopf der Quelle und bekommt eine SPDX-Zeile (`SPDX-License-Identifier: MIT` usw.) sowie einen Hinweis „Portiert aus <Projekt>/<Pfad>, Commit <Hash>“.
2. Programmcode und Grafiken werden getrennt bewertet. **Es werden keine Icons, Bilder, Texte oder Logos aus Paint.NET oder Pinta übernommen.** Die App bekommt eigene Grafiken.
3. Keine Übernahme aus aktuellen Paint.NET-Binärdateien oder deren Decompilaten – weder direkt noch über Drittprojekte, die so entstanden sind.
4. Kein Code unter GPL/LGPL/AGPL, CC-NC oder anderen nicht-kommerziellen Lizenzen.
5. Der Name „Paint.NET“ (und „PDN“ als Produktname) wird nicht verwendet. Die Dateiendung `.pdn` und die Formatbezeichnung „Paint.NET-Bild (.pdn)“ dürfen als Kompatibilitätsangabe genannt werden.

---

## 1. Übersicht

| # | Bestandteil | Quelle (Commit/Version) | Lizenz | Verwendung | Status |
|---|---|---|---|---|---|
| 1 | Paint.NET 3.36 – Programmcode (`*.cs`: Mischmodi, Effekte, Anpassungen, Surface/ColorBgra, Spline, Resampling, Werkzeuglogik, History-Konzept, PDN-Serialisierung als Formatreferenz) | github.com/milliethompson/PaintDotNet @ `e0d7d2e` (Spiegel von Paint.NET 3.36) | MIT **mit Ausnahmen** (siehe 2.1) | Portierung nach Swift | vorgesehen |
| 2 | Pinta – Programmcode (Effekte, Anpassungen, Werkzeuge, SurfaceDiff, ORA-Format, Paletten-Formate, Tests) | github.com/PintaProject/Pinta @ master 02.11.2026 (3.2-dev) | MIT (Pinta) bzw. Paint.NET-3.36-MIT für Dateien mit PDN-Kopf | Portierung nach Swift, Testorakel | vorgesehen |
| 3 | PaintDotNet.Quantization (Octree-Quantisierer, Paletten-Mapping) | github.com/paintdotnet/PaintDotNet.Quantization @ 26.12.2024 | MIT (Repo-LICENSE); Datei-Köpfe „All Rights Reserved“ | Portierung, beide Hinweise behalten | vorgesehen (oder eigene Implementierung, siehe 2.3) |
| 4 | pypdn (PDN-/NRBF-Lesen) | github.com/addisonElliott/pypdn @ 21.02.2024 | MIT | Logik für Swift-PDN-Reader portieren | vorgesehen |
| 5 | Clipper2 (Polygon-Boolesche Operationen für Auswahl) | github.com/AngusJohnson/Clipper2 @ 29.10.2026 | Boost Software License 1.0 | Direkt eingebunden (C++ über Swift-Interop) | vorgesehen |
| 6 | DDS-Dateityp-Plugin (Dean Ashton) | in Paint.NET 3.36 `src/DdsFileType` | MIT | Portierung DDS lesen/schreiben | optional |
| 7 | libsquish (DXT-Kompression, Simon Brown) | in Paint.NET 3.36 `src/DdsFileType/Squish` | MIT | C++-Bibliothek einbinden | optional |
| 8 | GPUImage3 (einzelne Metal-Shader) | github.com/BradLarson/GPUImage3 @ 18.02.2024 | BSD-3-Clause | Einzelne Kernels als Vorlage/Übernahme | optional |
| 9 | MetalPetal (Komposition/Mischmodi auf Metal) | github.com/MetalPetal/MetalPetal @ 21.02.2023 | MIT | Referenz, ggf. einzelne Shader | optional |
| 10 | stb_image_resize2 | github.com/nothings/stb @ 01.11.2026 | MIT **oder** Public Domain (Unlicense) – Wahl: MIT | CPU-Resampling | optional |
| 11 | Apple Core Image, vImage/Accelerate, Metal, MPS, ImageIO, ColorSync, AppKit | macOS SDK | Apple-SDK-Lizenz (Systembestandteil) | Rendering, Filter, Formate, Farbmanagement, UI | vorgesehen |
| 12 | MS-NRBF-Spezifikation | learn.microsoft.com (Open Specifications) | Microsoft Open Specifications Promise / Dokumentation | Nur Spezifikation, kein Code | vorgesehen |

---

## 2. Bedingungen je Bestandteil

### 2.1 Paint.NET 3.36

**Herkunft:** Offizieller Quellcode-Release von Paint.NET 3.36 (2008/2009), hier aus dem Spiegel `milliethompson/PaintDotNet`. Da der Spiegel nicht von dotPDN stammt, wird jede portierte Datei mit der gleichnamigen Datei in Pinta (enthält dieselben 3.36-Dateien mit Original-Kopf) abgeglichen.

**Darf übernommen werden:** Programmcode (`.cs`, außer GPC-bezogen) unter MIT – Copyright-Kopf und MIT-Text müssen erhalten bleiben.

**Darf NICHT übernommen werden:**
- Ausnahme 1: Paint.NET-Logo und Icon-Grafik (CC BY-NC-ND 2.5).
- Ausnahme 2: alle „resource assets“ – Dateien mit Endung **.RESOURCES, .RESX, .PNG**, eingebettete Ressourcen (Toolbar-Icons, Menü- und Statusleistentexte) (CC BY-NC-ND 2.5). → Menütexte und Icons werden selbst geschrieben/gestaltet.
- Ausnahme 3: **GPC** (`SystemLayer/GpcWrapper`, `ShellExtension/gpc.c/.h`) – keine kommerzielle Nutzung ohne Lizenz der University of Manchester. → ersetzt durch Clipper2.
- Windows-Binärdateien im Quellbaum (`Microsoft.Ink.dll`, `Interop.WIA.dll`, `ICSharpCode.SharpZipLib.dll`, BuildTools/Cygwin-DLLs) – nicht benötigt, nicht übernommen.

Pflichthinweis (bei jeder portierten Datei und in „Über“/Lizenzanzeige der App):

```
Paint.NET
Copyright (C) dotPDN LLC, Rick Brewster, Chris Crosetto, Tom Jackson, Michael Kelsey,
Brandon Ortiz, Craig Taylor, Chris Trevino, and Luke Walker.
Portions Copyright (C) Microsoft Corporation. All Rights Reserved.

License last updated: June 1, 2008

This software is licensed as per the MIT License below, but with three (3) exceptions:

* Exception 1: The Paint.NET logo and icon artwork are Copyright (C) Rick Brewster. They
  are covered by the Creative Commons Attribution-NonCommercial-NoDerivs 2.5 license
  which is detailed here: http://creativecommons.org/licenses/by-nc-nd/2.5/ . However,
  permission is granted to use the logo and icon artwork in ways that directly discuss
  or promote Paint.NET (e.g. blog and news posts about Paint.NET, "Made with Paint.NET"
  watermarks or insets).

* Exception 2: Paint.NET makes use of certain text and graphic resources that it comes
  with (e.g., toolbar icon graphics, text for menu items and the status bar). These are
  collectively referred to as "resource assets" and are defined to include the contents
  of files installed by Paint.NET, or included in its source code distribution, that
  have a .RESOURCES, .RESX, or .PNG file extension. This also includes embedded resource
  files within the PaintDotNet.Resources.dll installed file. These "resource assets" are
  covered by the Creative Commons Attribution-NonCommercial-NoDerivs 2.5 license which
  is detailed here: http://creativecommons.org/licenses/by-nc-nd/2.5/ . However,
  permission is granted to create and distribute derivative works of the "resource
  assets" for the sole purpose of providing a translation to a language other than
  English. Some "resource assets" are included in unmodified form from external icon or
  image libraries and are still covered by their original, respective licenses (e.g.,
  "Silk", "Visual Studio 2005 Image Library").

* Exception 3: Although the Paint.NET source code distribution includes the GPC source
  code, use of the GPC code in any other commercial application is not permitted without
  a GPC Commercial Use Licence from The University of Manchester. For more information,
  please refer to the GPC website at: http://www.cs.man.ac.uk/~toby/alan/software/

MIT License: http://www.opensource.org/licenses/mit-license.php

Permission is hereby granted, free of charge, to any person obtaining a copy of this
software and associated documentation files (the "Software"), to deal in the Software
without restriction, including without limitation the rights to use, copy, modify,
merge, publish, distribute, sublicense, and/or sell copies of the Software, and to
permit persons to whom the Software is furnished to do so, subject to the following
conditions:

The above copyright notice and this permission notice shall be included in all copies
or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR IMPLIED,
INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY, FITNESS FOR A
PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT
HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION OF
CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR
THE USE OR OTHER DEALINGS IN THE SOFTWARE.
```

### 2.2 Pinta

**Darf übernommen werden:** Pinta-eigener Programmcode (MIT) und die von Paint.NET 3.36 portierten Dateien (Kopf „See license-pdn.txt“ – dann gilt 2.1 zusätzlich).

**Darf NICHT übernommen werden:** Icons und Grafiken aus `Pinta.Resources` (Herkunft teils Paint.NET 3.0, Silk/Fugue unter CC BY 3.0 mit Namensnennungspflicht – wir verwenden eigene Icons), Übersetzungen (`po/`) nur nach Einzelprüfung.

```
The MIT License

Copyright (c) 2010 Jonathan Pobst <monkey@jpobst.com>

Permission is hereby granted, free of charge, to any person obtaining a copy
of this software and associated documentation files (the "Software"), to deal
in the Software without restriction, including without limitation the rights
to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
copies of the Software, and to permit persons to whom the Software is
furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in
all copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
THE SOFTWARE.
```

Zusätzlich gilt für einzelne Dateien der jeweilige Autorenkopf (z. B. „Ported to Pinta by: …“); er wird mitübernommen.

### 2.3 PaintDotNet.Quantization

Die Repository-Datei `LICENSE` stellt den Code unter MIT. Die einzelnen Quelldateien tragen jedoch den Kopf „Copyright (C) dotPDN LLC, Rick Brewster, and contributors. All Rights Reserved.“ und der Octree-Code verweist auf einen MSDN-Artikel von 2003 als Grundlage.
**Vorgehen:** Bei Portierung beide Hinweise wörtlich übernehmen. Wenn vor dem Release keine Klarstellung vorliegt, wird der Quantisierer stattdessen **eigenständig nach Fachliteratur** (Octree nach Gervautz/Purgathofer, Median Cut, Wu) implementiert und die dokumentierten Fehlerkorrekturen nur als Anforderungsliste genutzt.

```
MIT License

Copyright (c) 2021 Rick Brewster

Permission is hereby granted, free of charge, to any person obtaining a copy
of this software and associated documentation files (the "Software"), to deal
in the Software without restriction, including without limitation the rights
to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
copies of the Software, and to permit persons to whom the Software is
furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in all
copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
SOFTWARE.
```

### 2.4 pypdn

```
MIT License

Copyright (c) 2018 Addison Elliott

Permission is hereby granted, free of charge, to any person obtaining a copy
of this software and associated documentation files (the "Software"), to deal
in the Software without restriction, including without limitation the rights
to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
copies of the Software, and to permit persons to whom the Software is
furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in all
copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
SOFTWARE.
```

### 2.5 Clipper2

Hinweis muss in Quellkopien enthalten sein; reine Binärverteilung ist laut Lizenz ausgenommen, wir führen ihn trotzdem in der Lizenzanzeige.

```
Boost Software License - Version 1.0 - August 17th, 2003

Permission is hereby granted, free of charge, to any person or organization
obtaining a copy of the software and accompanying documentation covered by
this license (the "Software") to use, reproduce, display, distribute,
execute, and transmit the Software, and to prepare derivative works of the
Software, and to permit third-parties to whom the Software is furnished to
do so, all subject to the following:

The copyright notices in the Software and this entire statement, including
the above license grant, this restriction and the following disclaimer,
must be included in all copies of the Software, in whole or in part, and
all derivative works of the Software, unless such copies or derivative
works are solely in the form of machine-executable object code generated by
a source language processor.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
FITNESS FOR A PARTICULAR PURPOSE, TITLE AND NON-INFRINGEMENT. IN NO EVENT
SHALL THE COPYRIGHT HOLDERS OR ANYONE DISTRIBUTING THE SOFTWARE BE LIABLE
FOR ANY DAMAGES OR OTHER LIABILITY, WHETHER IN CONTRACT, TORT OR OTHERWISE,
ARISING FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER
DEALINGS IN THE SOFTWARE.
```

### 2.6 DDS-Plugin und libsquish (optional)

- DDS File Type Plugin for Paint.NET – Copyright (c) 2006 Dean Ashton – MIT (Text wie in `src/DdsFileType/DdsFileType/License.txt`).
- libsquish – Copyright (c) 2006 Simon Brown – MIT (Text im Kopf von `squish.h`).

### 2.7 GPUImage3 (optional, BSD-3-Clause)

```
Copyright (c) 2018, Brad Larson and Janie Clayton.
All rights reserved.

Redistribution and use in source and binary forms, with or without modification, are
permitted provided that the following conditions are met:

Redistributions of source code must retain the above copyright notice, this list of
conditions and the following disclaimer.
Redistributions in binary form must reproduce the above copyright notice, this list of
conditions and the following disclaimer in the documentation and/or other materials
provided with the distribution.
Neither the name of the GPUImage framework nor the names of its contributors may be used
to endorse or promote products derived from this software without specific prior
written permission.
THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS" AND ANY
EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED WARRANTIES OF
MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE DISCLAIMED. IN NO EVENT SHALL
THE COPYRIGHT HOLDER OR CONTRIBUTORS BE LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL,
SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT
OF SUBSTITUTE GOODS OR SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS
INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT
LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE
OF THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
```

### 2.8 MetalPetal (optional)

MIT License – Copyright (c) 2017 Yu Ao (vollständiger MIT-Text wie in 2.3, mit diesem Copyright).

### 2.9 stb_image_resize2 (optional)

Gewählt: Alternative A – MIT License, Copyright (c) 2017 Sean Barrett (vollständiger MIT-Text wie in 2.3, mit diesem Copyright).

---

## 3. Geprüft und ausgeschlossen

| Bestandteil | Grund |
|---|---|
| Aktuelles Paint.NET (4.x/5.x) – Binärdateien, Installer, Decompilate | Proprietär; laut Vorgabe 38.5 ausdrücklich verboten |
| **EricKrouss/OpenPDN** (Apache-2.0) | Laut eigener Dokumentation mit ILSpy aus Paint.NET 5.1.12 abgeleitet – Herkunft nicht zulässig, auch nicht als Lesereferenz |
| Paint.NET-3.36-Logo, Icons, `.png`/`.resx`/`.resources`, Menü-/Statustexte | CC BY-NC-ND 2.5 (Ausnahmen 1 und 2) |
| GPC (General Polygon Clipper) | Keine kommerzielle Nutzung ohne Lizenz (Ausnahme 3) |
| PdnV5EffectSamples: `NightCircuitShaderEffect.cs`, `PolarizedMandelleavesShaderEffect.cs` | CC BY-NC-SA 3.0 (nicht kommerziell) |
| PdnV5EffectSamples (Rest, MIT) | Nur als Referenz: an proprietäre Paint.NET-5-API und Direct2D gebunden, nicht lauffähig; ShaderToy-Ports einzeln lizenzgeprüft vor jeder Nutzung |
| Pinta-Icons (`Pinta.Resources`) | Teilweise Paint.NET-Herkunft mit widersprüchlicher Lizenzlage; wir nutzen eigene Icons |
| diegomgarcia/paint.rust, Univers4craft/paint.software, storytold/photocraft (MIT bzw. MIT/Apache-2.0) | Lizenz erlaubt Nutzung, aber jung, je ein einziger Commit (Herkunft schwer prüfbar) – **nur als Referenz**, kein Code übernommen |
| libimagequant | GPLv3 bzw. kommerzielle Lizenz |
| ImageSharp | Six Labors Split License (kommerziell eingeschränkt) |
| GIMP, GEGL, Krita | GPL/LGPL – würde die App unter GPL stellen |
| `Microsoft.Ink.dll`, `Interop.WIA.dll`, SharpZipLib-DLL aus dem 3.36-Baum | Windows-Binärdateien, nicht benötigt |

---

## 4. Änderungsprotokoll

| Datum | Änderung |
|---|---|
| 2026-11-04 | Erste Fassung nach Quellcodeanalyse (vor Implementierung) |
