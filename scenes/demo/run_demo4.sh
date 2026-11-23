#!/bin/sh
# Demo 4: giorno, pioggia, tramonto e notte sul diorama del livello 1 (~95 s, vedi scenes/demo/README.md).
# Uso: scenes/demo/run_demo4.sh [--record[=file.avi]] [--auto-quit] [--clean] [--seed=N] [--quality=low|medium|high]
cd "$(dirname "$0")/../.." || exit 1
REC=""
ARGS=""
for a in "$@"; do
	case "$a" in
		--record) REC="out/demo4.avi" ;;
		--record=*) REC="${a#--record=}" ;;
		*) ARGS="$ARGS $a" ;;
	esac
done
if [ -n "$REC" ]; then
	mkdir -p "$(dirname "$REC")"
	# shellcheck disable=SC2086
	exec godot --path . --write-movie "$REC" --fixed-fps 30 res://scenes/demo/demo4.tscn -- --auto-quit --clean $ARGS
fi
# shellcheck disable=SC2086
exec godot --path . res://scenes/demo/demo4.tscn -- $ARGS
