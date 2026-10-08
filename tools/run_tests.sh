#!/usr/bin/env bash
# 헤드리스 GUT 실행. 실패 시 비정상 종료 코드.
set -euo pipefail
cd "$(dirname "$0")/.."
GODOT="${GODOT:-$(tools/install_godot.sh | tail -n 1)}"
"$GODOT" --headless --path . --import >/dev/null 2>&1 || true
"$GODOT" --headless --path . -s addons/gut/gut_cmdln.gd \
  -gdir=res://tests -ginclude_subdirs -gexit
