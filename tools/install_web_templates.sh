#!/usr/bin/env bash
# Godot 4.7.2 웹(단일 스레드) 내보내기 템플릿 설치 (idempotent).
set -euo pipefail
VERSION="4.7.2-stable"
TPL_DIR="${GODOT_TEMPLATES_DIR:-$HOME/.local/share/godot/export_templates/4.7.2.stable}"
if ls "$TPL_DIR"/web_nothreads_*.zip >/dev/null 2>&1 && [ -f "$TPL_DIR/version.txt" ]; then
  echo "$TPL_DIR"; exit 0
fi
WORK="${M4_TMP:-/tmp/claude-0/m4}"
mkdir -p "$WORK" "$TPL_DIR"
TPZ="$WORK/Godot_v${VERSION}_export_templates.tpz"
CA=()
if [ -z "${CURL_CA_BUNDLE:-}" ] && [ -f /root/.ccr/ca-bundle.crt ]; then CA=(--cacert /root/.ccr/ca-bundle.crt); fi
curl -fsSL --retry 3 "${CA[@]}" -o "$TPZ" \
  "https://github.com/godotengine/godot/releases/download/${VERSION}/Godot_v${VERSION}_export_templates.tpz"
EXTRACT="$WORK/extract"
rm -rf "$EXTRACT"; mkdir -p "$EXTRACT"
unzip -oq "$TPZ" 'templates/web_nothreads_*.zip' 'templates/version.txt' -d "$EXTRACT"
cp "$EXTRACT"/templates/web_nothreads_*.zip "$EXTRACT/templates/version.txt" "$TPL_DIR/"
rm -rf "$EXTRACT" "$TPZ"
echo "$TPL_DIR"
