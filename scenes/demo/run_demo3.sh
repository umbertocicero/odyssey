#!/bin/sh
# Demo 3: un bot gioca il livello 1 senza cheat, nel minor tempo possibile (vedi scenes/demo/README.md).
# Uso: scenes/demo/run_demo3.sh [--record[=file.avi]] [--auto-quit] [--clean] [--plan=...] [--seed=N]
cd "$(dirname "$0")/../.." || exit 1
REC=""
ARGS=""
for a in "$@"; do
	case "$a" in
		--record) REC="out/demo3.avi" ;;
		--record=*) REC="${a#--record=}" ;;
		*) ARGS="$ARGS $a" ;;
	esac
done
if [ -n "$REC" ]; then
	mkdir -p "$(dirname "$REC")"
	# shellcheck disable=SC2086
	exec godot --path . --write-movie "$REC" --fixed-fps 30 res://scenes/demo/demo3.tscn -- --auto-quit --clean $ARGS
fi
# shellcheck disable=SC2086
exec godot --path . res://scenes/demo/demo3.tscn -- $ARGS
