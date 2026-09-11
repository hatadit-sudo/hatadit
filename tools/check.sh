#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."
godot_exec="${GODOT_BIN:-godot}"
mkdir -p build
run_checked() {
  local fjord_log="$1"
  shift
  timeout 180s "$@" 2>&1 | tee "build/$fjord_log"
  if grep -En 'SCRIPT ERROR:|Parse Error:|Compile Error:|^ERROR:|^FAIL:' "build/$fjord_log"; then
    echo 'Native validation failed; APK export must not proceed.' >&2
    exit 1
  fi
}
run_checked import.log "$godot_exec" --headless --editor --path . --import
run_checked rules.log "$godot_exec" --headless --path . --script res://tests/test_rules.gd
run_checked scene.log "$godot_exec" --headless --path . --script res://tests/test_scene.gd
