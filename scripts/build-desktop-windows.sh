#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
DESKTOP_DIR="$ROOT_DIR/apps/desktop"
RELEASES_DIR="$ROOT_DIR/releases"
LOG_DIR="$ROOT_DIR/.build-logs"
BUILD_LOG="$LOG_DIR/desktop-windows-build.log"
VERSION="$(grep '^version:' "$DESKTOP_DIR/pubspec.yaml" | awk '{print $2}' | cut -d+ -f1)"
DATE_STAMP="$(date +%Y%m%d)"
PACKAGE_NAME="trusty-windows-x64-portable-${VERSION}-${DATE_STAMP}"
PACKAGE_DIR="$RELEASES_DIR/$PACKAGE_NAME"
PACKAGE_ARCHIVE="$RELEASES_DIR/${PACKAGE_NAME}.zip"
PACKAGE_SHA="$PACKAGE_ARCHIVE.sha256"
WINDOWS_FLUTTER_BIN="${WINDOWS_FLUTTER_BIN:-D:\\VPN\\tools\\flutter_windows_sdk\\flutter\\bin\\flutter.bat}"
WINDOWS_PUB_CACHE="${WINDOWS_PUB_CACHE:-D:\\VPN\\tools\\windows_pub_cache}"
WINDOWS_PROJECT_DIR="$(wslpath -w "$DESKTOP_DIR")"
WINDOWS_CMD="/mnt/c/Windows/System32/cmd.exe"
TEMP_CLIENT_DIR=""

mkdir -p "$LOG_DIR" "$RELEASES_DIR"
: >"$BUILD_LOG"

cleanup() {
  if [[ -n "$TEMP_CLIENT_DIR" && -d "$TEMP_CLIENT_DIR" ]]; then
    rm -rf "$TEMP_CLIENT_DIR"
  fi
}

trap cleanup EXIT

if [[ ! -x "$WINDOWS_CMD" ]]; then
  echo "Missing required command host bridge: $WINDOWS_CMD" >&2
  exit 1
fi

run_windows_flutter() {
  local flutter_args="$1"

  "$WINDOWS_CMD" /C \
    "set PUB_CACHE=$WINDOWS_PUB_CACHE&& cd /d $WINDOWS_PROJECT_DIR && $WINDOWS_FLUTTER_BIN $flutter_args" \
    >>"$BUILD_LOG" 2>&1
}

echo "[1/6] Fetching Flutter dependencies"
run_windows_flutter "pub get"

echo "[2/6] Generating localizations"
run_windows_flutter "gen-l10n"

echo "[3/6] Building Windows desktop app"
run_windows_flutter "build windows --release"

echo "[4/6] Preparing portable bundle"
latest_client_dir="$(find "$RELEASES_DIR" -maxdepth 2 -type d -path "$RELEASES_DIR/trusty-windows-x64-portable-${VERSION}-*/client" | sort | tail -n 1 || true)"
TEMP_CLIENT_DIR="$(mktemp -d "$RELEASES_DIR/.windows-client.XXXXXX")"

if [[ -n "$latest_client_dir" ]]; then
  cp -a "$latest_client_dir/." "$TEMP_CLIENT_DIR/"
else
  latest_portable_zip="$(find "$RELEASES_DIR" -maxdepth 1 -type f -name "trusty-windows-x64-portable-${VERSION}-*.zip" | sort | tail -n 1 || true)"
  if [[ -z "$latest_portable_zip" ]]; then
    echo "Unable to find existing Windows portable client/ source to reuse." >&2
    exit 1
  fi

  unzip -qq "$latest_portable_zip" "*/client/*" -d "$TEMP_CLIENT_DIR"
  extracted_client_dir="$(find "$TEMP_CLIENT_DIR" -type d -name client | head -n 1 || true)"
  if [[ -z "$extracted_client_dir" ]]; then
    echo "Portable zip was found, but client/ could not be extracted from it." >&2
    exit 1
  fi

  nested_client_dir="$TEMP_CLIENT_DIR/.client"
  mkdir -p "$nested_client_dir"
  cp -a "$extracted_client_dir/." "$nested_client_dir/"
  rm -rf "$TEMP_CLIENT_DIR"/*
  cp -a "$nested_client_dir/." "$TEMP_CLIENT_DIR/"
  rm -rf "$nested_client_dir"
fi

rm -rf "$PACKAGE_DIR"
mkdir -p "$PACKAGE_DIR"
cp -a "$DESKTOP_DIR/build/windows/x64/runner/Release/." "$PACKAGE_DIR/"

# Preserve runtime client files required by the packaged desktop app.
mkdir -p "$PACKAGE_DIR/client"
cp -a "$TEMP_CLIENT_DIR/." "$PACKAGE_DIR/client/"
rm -rf "$TEMP_CLIENT_DIR"
TEMP_CLIENT_DIR=""

echo "[5/6] Packing release archive"
rm -f "$PACKAGE_ARCHIVE" "$PACKAGE_SHA"
(
  cd "$RELEASES_DIR"
  zip -rq "$(basename "$PACKAGE_ARCHIVE")" "$PACKAGE_NAME"
)
sha256sum "$PACKAGE_ARCHIVE" | awk '{print $1}' >"$PACKAGE_SHA"

echo "[6/6] Done"
echo "Bundle:  $DESKTOP_DIR/build/windows/x64/runner/Release"
echo "Folder:  $PACKAGE_DIR"
echo "Archive: $PACKAGE_ARCHIVE"
echo "SHA256:  $(cat "$PACKAGE_SHA")"
echo "Log:     $BUILD_LOG"
