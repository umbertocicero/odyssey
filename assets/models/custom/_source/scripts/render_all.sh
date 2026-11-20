#!/bin/bash
# Rigenera tutte le anteprime in _previews/, UNA ALLA VOLTA (render paralleli bloccano il PC).
set -u
cd "$(dirname "$0")/../.."
S=_source/scripts; P=_previews; T=$(mktemp -d)
r() { timeout 180 nice blender -b --factory-startup -P $S/render_preview.py -- "$@" >/dev/null 2>&1; }
for f in personaggi/*.glb; do
  n=$(basename $f .glb)
  r $f $T/$n.png idle_loop:0 walk_loop:6 attack:10 death:30 --size 360
  r $f $T/${n}_back.png idle_loop:0 --az 160 --size 360
  python3 $S/sheet.py $P/$n.png $T/${n}_0.png $T/${n}_back_0.png $T/${n}_1.png $T/${n}_2.png $T/${n}_3.png
  echo "ok $n"
done
for f in accampamento/*.glb navi/*.glb stendardi/*.glb; do
  n=$(basename $f .glb)
  r $f $T/$n.png --size 480
  python3 $S/sheet.py $P/$n.png $T/$n.png
  echo "ok $n"
done
python3 $S/sheet.py $P/_panoramica_oggetti.png $T/tenda_padiglione.png $T/rastrelliera_lance.png $T/carro_coperto.png $T/trireme.png
python3 $S/sheet.py $P/_panoramica_stendardi.png $T/scudo_acheo.png $T/scudo_ulisse.png $T/scudo_troiano.png $T/stendardo_acheo.png $T/stendardo_troiano.png $T/drappo_muro_acheo.png $T/drappo_muro_troiano.png
rm -rf $T
