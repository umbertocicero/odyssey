#!/bin/sh
# Demo 5: gli animali del livello 1 (~90 s, vedi scenes/demo/README.md).
# Uso: scenes/demo/run_demo5.sh [--record[=file.avi]] [--auto-quit] [--clean] [--seed=N] [--quality=low|medium|high]
cd "$(dirname "$0")/../.." || exit 1
REC=""
ARGS=""
for a in "$@"; do
	case "$a" in
		--record) REC="out/demo5.avi" ;;
		--record=*) REC="${a#--record=}" ;;
		*) ARGS="$ARGS $a" ;;
	esac
done
if [ -n "$REC" ]; then
	mkdir -p "$(dirname "$REC")"
	# shellcheck disable=SC2086
	exec godot --path . --write-movie "$REC" --fixed-fps 30 res://scenes/demo/demo5.tscn -- --auto-quit --clean --quality=high $ARGS
fi
# shellcheck disable=SC2086
exec godot --path . res://scenes/demo/demo5.tscn -- --quality=high $ARGS
