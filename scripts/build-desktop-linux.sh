#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
DESKTOP_DIR="$ROOT_DIR/apps/desktop"
RELEASES_DIR="$ROOT_DIR/releases"
LOG_DIR="$ROOT_DIR/.build-logs"
BUILD_LOG="$LOG_DIR/desktop-linux-build.log"
VERSION="$(grep '^version:' "$DESKTOP_DIR/pubspec.yaml" | awk '{print $2}' | cut -d+ -f1)"
DATE_STAMP="$(date +%Y%m%d)"
PACKAGE_NAME="trusty-linux-x64-portable-${VERSION}-${DATE_STAMP}"
PACKAGE_DIR="$RELEASES_DIR/$PACKAGE_NAME"
PACKAGE_ARCHIVE="$RELEASES_DIR/${PACKAGE_NAME}.tar.gz"
PACKAGE_SHA="$PACKAGE_ARCHIVE.sha256"
LINUX_CLIENT_SOURCE="${LINUX_CLIENT_SOURCE:-}"
LINUX_CLIENT_FALLBACKS=(
  "$DESKTOP_DIR/client/trusttunnel_client"
  "$ROOT_DIR/docs/trusttunnel_client"
)
LINUX_CLIENT_EXAMPLE="$DESKTOP_DIR/client/trusttunnel_client.toml.example"

mkdir -p "$LOG_DIR"
mkdir -p "$RELEASES_DIR"

if ! command -v flutter >/dev/null 2>&1; then
  echo "Missing required command: flutter" >&2
  exit 1
fi

echo "[1/3] Fetching Flutter dependencies"
(
  cd "$DESKTOP_DIR"
  flutter pub get >>"$BUILD_LOG" 2>&1
)

echo "[2/3] Building Linux desktop app"
(
  cd "$DESKTOP_DIR"
  flutter build linux >>"$BUILD_LOG" 2>&1
)

echo "[3/5] Preparing portable bundle"
rm -rf "$PACKAGE_DIR"
mkdir -p "$PACKAGE_DIR"
cp -a "$DESKTOP_DIR/build/linux/x64/release/bundle/." "$PACKAGE_DIR/"

linux_client_source="$LINUX_CLIENT_SOURCE"
if [[ -z "$linux_client_source" ]]; then
  for candidate in "${LINUX_CLIENT_FALLBACKS[@]}"; do
    if [[ -f "$candidate" ]]; then
      linux_client_source="$candidate"
      break
    fi
  done
fi

if [[ -n "$linux_client_source" && -f "$linux_client_source" ]]; then
  mkdir -p "$PACKAGE_DIR/client"
  cp "$linux_client_source" "$PACKAGE_DIR/client/trusttunnel_client"
  chmod +x "$PACKAGE_DIR/client/trusttunnel_client"

  if [[ -f "$LINUX_CLIENT_EXAMPLE" ]]; then
    cp "$LINUX_CLIENT_EXAMPLE" "$PACKAGE_DIR/client/trusttunnel_client.toml.example"
  fi
fi

echo "[4/5] Packing release archive"
rm -f "$PACKAGE_ARCHIVE" "$PACKAGE_SHA"
tar -C "$RELEASES_DIR" -czf "$PACKAGE_ARCHIVE" "$PACKAGE_NAME"
sha256sum "$PACKAGE_ARCHIVE" | awk '{print $1}' >"$PACKAGE_SHA"

echo "[5/5] Done"
echo "Binary: $DESKTOP_DIR/build/linux/x64/release/bundle/trusty"
echo "Folder:  $PACKAGE_DIR"
echo "Archive: $PACKAGE_ARCHIVE"
echo "SHA256:  $(cat "$PACKAGE_SHA")"
echo "Log:    $BUILD_LOG"
