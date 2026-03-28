#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
WEBUI_DIR="$ROOT_DIR/apps/webui"
LOG_DIR="$ROOT_DIR/.build-logs"
BUILD_LOG="$LOG_DIR/webui-build.log"

mkdir -p "$LOG_DIR"

if ! command -v go >/dev/null 2>&1; then
  echo "Missing required command: go" >&2
  exit 1
fi

echo "[1/3] Running WebUI tests"
(
  cd "$WEBUI_DIR"
  go test ./... >>"$BUILD_LOG" 2>&1
)

echo "[2/3] Building WebUI binary"
(
  cd "$WEBUI_DIR"
  mkdir -p build
  go build -o build/trusttunnel-webui ./cmd/webui >>"$BUILD_LOG" 2>&1
)

echo "[3/3] Done"
echo "Binary: $WEBUI_DIR/build/trusttunnel-webui"
echo "Log:    $BUILD_LOG"
