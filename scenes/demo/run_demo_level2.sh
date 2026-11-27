#!/bin/sh
# Lancia la demo automatica del livello 2 (vedi scenes/demo/README.md).
# Uso: scenes/demo/run_demo_level2.sh [--chapter=N] [--clean] [--auto-quit] [--shots=DIR] [--timescale=N] [--quality=low|medium|high]
cd "$(dirname "$0")/../.." || exit 1
exec godot --path . res://scenes/demo/demo_level2.tscn -- "$@"
