#!/bin/sh
# Demo dei 15 personaggi (rig a 17 ossa con skinning e clip Mixamo): tutti in fila con il nome, giro automatico di azioni, guidabile a mano.
# Uso: scenes/demo/run_demo_characters.sh [--focus=menelao] [--procedural] [--noauto] [--nogear] [--once] [--shots=DIR]
# Tasti in finestra: 1-7 azione, Space auto, Left/Right primo piano, Esc tutti, M clip Mixamo/procedurali, G armi, H aiuto, Q esci.
cd "$(dirname "$0")/../.." || exit 1
exec godot --path . res://scenes/demo/demo_characters.tscn -- "$@"
