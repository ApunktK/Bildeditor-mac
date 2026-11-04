#!/bin/bash
# Erstellt eine DMG mit der App und einer Verknüpfung zum Programme-Ordner (Drag-&-Drop-Installation).
# Aufruf: Packaging/make_dmg.sh <Pfad/zur/Bildeditor.app> <Ausgabe.dmg>
set -euo pipefail
APP="$1"; OUT="$2"
STAGE="$(mktemp -d)"
cp -R "$APP" "$STAGE/"
ln -s /Applications "$STAGE/Programme"
rm -f "$OUT"
hdiutil create -volname "Bildeditor" -srcfolder "$STAGE" -fs HFS+ -format UDZO -ov "$OUT"
hdiutil verify "$OUT"
rm -rf "$STAGE"
echo "DMG erstellt: $OUT"
