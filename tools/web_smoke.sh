#!/usr/bin/env bash
# build/web을 로컬 http.server로 서빙하고 헤드리스 Chromium 스모크 테스트 실행.
set -euo pipefail
cd "$(dirname "$0")/.."
[ -f build/web/index.html ] || { echo "build/web 없음: tools/export_web.sh 먼저 실행" >&2; exit 1; }
if ! node -e "require('playwright')" 2>/dev/null; then
  GLOBAL_ROOT="$(npm root -g 2>/dev/null || true)"
  export NODE_PATH="${GLOBAL_ROOT}${NODE_PATH:+:$NODE_PATH}"
fi
PORT="$(python3 -c 'import socket;s=socket.socket();s.bind(("127.0.0.1",0));print(s.getsockname()[1])')"
python3 -m http.server "$PORT" --bind 127.0.0.1 --directory build/web >/dev/null 2>&1 &
SRV=$!
trap 'kill $SRV 2>/dev/null || true' EXIT
sleep 1
node tools/web_smoke.mjs "http://127.0.0.1:$PORT/index.html" build/web_smoke.png build/web_smoke_console.log
