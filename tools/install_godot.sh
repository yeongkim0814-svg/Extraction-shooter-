#!/usr/bin/env bash
# Godot 4.7.2 설치 (idempotent). 바이너리 경로를 stdout 마지막 줄에 출력한다.
set -euo pipefail
VERSION="4.7.2-stable"
DIR="${GODOT_DIR:-$HOME/.local/godot}"
BIN="$DIR/Godot_v${VERSION}_linux.x86_64"
if [ ! -x "$BIN" ]; then
  mkdir -p "$DIR"
  ZIP="$DIR/godot.zip"
  CA=()
  if [ -z "${CURL_CA_BUNDLE:-}" ] && [ -f /root/.ccr/ca-bundle.crt ]; then CA=(--cacert /root/.ccr/ca-bundle.crt); fi
  curl -fsSL --retry 3 "${CA[@]}" -o "$ZIP" \
    "https://github.com/godotengine/godot/releases/download/${VERSION}/Godot_v${VERSION}_linux.x86_64.zip"
  unzip -oq "$ZIP" -d "$DIR"
  rm -f "$ZIP"
  chmod +x "$BIN"
fi
echo "$BIN"
