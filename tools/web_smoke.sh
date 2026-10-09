#!/usr/bin/env bash
# build/web을 로컬 http.server로 서빙하고 헤드리스 Chromium 스모크 테스트 실행.
# 사용법: tools/web_smoke.sh [platform|inventory|combat|mod|ai|raid|style] [기대 마커]
#   platform (기본): ?scene=platform 로 열고 "PLATFORM_TEST:" 로그를 기다린다.
#   combat: ?scene=combat 로 열고 "COMBAT_TEST: ready" 후 좌클릭 연사(hit/shot), R 재장전(reload ok), 터치 멀티터치(이동+시점+사격)를 확인한다.
#   mod: ?scene=inventory 로 열고 소총 선택 → 모딩 → 소음기 장착(weapon_changed 이벤트·6x2) → 분리 → 닫기를 확인한다 (MOD_SCREEN 로그).
#   ai: ?scene=ai 로 열고 내비메시·적 교전(COMBAT/enemy_shot/player_hit)을 확인한 뒤 K로 적 처치 → F 루팅 화면 → 닫기 버튼을 확인한다 (AI_TEST 로그).
#   raid: ?scene=raid 로 열고 "RAID: ready" 후 구성(boxes/polys/containers/enemies) → K 전멸 → G·F 컨테이너 열기 → 수색 공개·중단·재개·완료 → 아이템 끌어오기 → T 정문 탈출 → 결과 화면을 확인한다 (RAID 로그).
#   style: ?scene=style_a 로 열어 "STYLE: ready a" 후 1·2·3 키로 세 컷(STYLE: shot n + render 통계)을 찍고, ?scene=style_b, style_c, style_d 로 같은 걸 반복한다 (D는 STYLE: vertex_ao 로그도 확인) → build/style_{a,b,c,d}_{1,2,3}.png (STYLE_LETTERS=d 처럼 환경변수로 일부만 돌릴 수 있다).
#   inventory: ?scene=inventory 로 열고 "INVENTORY_DEMO: ready" 후 드래그·탭 선택 이동·장착/해제·터치·스크롤을 확인한다.
set -euo pipefail
cd "$(dirname "$0")/.."
SCENE="${1:-platform}"
MARKER="${2:-}"
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
node tools/web_smoke.mjs "http://127.0.0.1:$PORT/index.html" "$SCENE" "$MARKER"
