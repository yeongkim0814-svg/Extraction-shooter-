#!/usr/bin/env bash
# 헤드리스 웹 내보내기. release 실패 시 debug로 재시도. 둘 다 실패하면 비정상 종료.
set -euo pipefail
cd "$(dirname "$0")/.."
GODOT="${GODOT:-$(tools/install_godot.sh | tail -n 1)}"
tools/install_web_templates.sh >/dev/null
rm -rf build/web; mkdir -p build/web
"$GODOT" --headless --path . --import >/dev/null 2>&1 || true
if "$GODOT" --headless --path . --export-release "Web" build/web/index.html && [ -f build/web/index.html ]; then
  echo "EXPORT_MODE=release"
elif "$GODOT" --headless --path . --export-debug "Web" build/web/index.html && [ -f build/web/index.html ]; then
  echo "EXPORT_MODE=debug"
else
  echo "웹 내보내기 실패" >&2; exit 1
fi
