#!/bin/sh
# Registra la demo 2 (~2 min) in out/demo2.avi a 30 fps fissi (MJPEG, senza audio).
# Uso: scenes/demo/run_demo2.sh [file.avi] [--quality=high]
cd "$(dirname "$0")/../.." || exit 1
OUT="${1:-out/demo2.avi}"
[ $# -gt 0 ] && shift
mkdir -p "$(dirname "$OUT")"
exec godot --path . --write-movie "$OUT" --fixed-fps 30 res://scenes/demo/demo2.tscn -- "$@"
