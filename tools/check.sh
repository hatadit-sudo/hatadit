#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."
godot_exec="${GODOT_BIN:-godot}"
mkdir -p build
failed=0
run_checked() {
  local fjord_log="$1"
  shift
  if ! timeout 180s "$@" 2>&1 | tee "build/$fjord_log"; then failed=1; fi
  if grep -En 'SCRIPT ERROR:|Parse Error:|Compile Error:|^ERROR:|^FAIL:' "build/$fjord_log"; then failed=1; fi
}
run_checked import.log "$godot_exec" --headless --editor --path . --import
run_checked rules.log "$godot_exec" --headless --path . --quit-after 240 --script res://tests/test_rules.gd
run_checked scene.log "$godot_exec" --headless --path . --quit-after 240 --verbose --script res://tests/test_scene.gd
run_checked playthrough.log "$godot_exec" --headless --path . --quit-after 600 --script res://tests/test_playthrough.gd
if [ "$failed" != 0 ]; then echo 'Native validation failed; export stopped.' >&2; fi
exit "$failed"
