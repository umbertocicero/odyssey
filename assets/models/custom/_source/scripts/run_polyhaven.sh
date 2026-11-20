#!/bin/bash
# Importa i modelli Poly Haven estratti in $1 (una cartella per archivio), UNO ALLA VOLTA:
# render e import in parallelo hanno gia' bloccato il PC.
W=${1:?cartella con le cartelle estratte}
cd "$(dirname "$0")/../.."
for d in "$W"/*/; do
  f=$(ls "$d"/*.blend 2>/dev/null | head -1); [ -z "$f" ] && continue
  n=$(basename "$f" .blend)
  echo "== $n"
  nice blender -b "$f" --factory-startup -P _source/scripts/import_polyhaven.py -- "$n" 2>&1 | grep -E "^JOB|^SKIP|Error|Traceback|line [0-9]" | cut -c1-230
done
echo FINE
