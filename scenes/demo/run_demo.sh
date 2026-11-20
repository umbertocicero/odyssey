#!/bin/sh
# Lancia la demo automatica del livello 1 (vedi scenes/demo/README.md).
# Uso: scenes/demo/run_demo.sh [--chapter=N] [--clean] [--auto-quit] [--shots=DIR] [--quality=low|medium|high]
cd "$(dirname "$0")/../.." || exit 1
exec godot --path . res://scenes/demo/demo.tscn -- "$@"
