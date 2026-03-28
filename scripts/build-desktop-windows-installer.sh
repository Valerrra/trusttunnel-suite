#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
DESKTOP_DIR="$ROOT_DIR/apps/desktop"
TOOLS_DIR="/mnt/d/VPN/tools/nsis"
LOG_DIR="$ROOT_DIR/.build-logs"
BUILD_LOG="$LOG_DIR/desktop-windows-installer.log"
NSIS_ZIP="$TOOLS_DIR/nsis-3.11.zip"
NSIS_DIR="$TOOLS_DIR/nsis-3.11"
MAKENSIS_EXE="$NSIS_DIR/makensis.exe"
SCRIPT_PATH="$DESKTOP_DIR/packaging/windows/trusty-installer.nsi"
VERSION="$(grep '^version:' "$DESKTOP_DIR/pubspec.yaml" | awk '{print $2}' | cut -d+ -f1)"
DATE_STAMP="$(date +%Y%m%d)"
PORTABLE_DIR_PATTERN="$ROOT_DIR/releases/trusty-windows-x64-portable-${VERSION}-*"
INSTALLER_NAME="trusty-windows-x64-setup-${VERSION}-${DATE_STAMP}.exe"
INSTALLER_PATH="$ROOT_DIR/releases/$INSTALLER_NAME"
INSTALLER_SHA="$INSTALLER_PATH.sha256"

mkdir -p "$TOOLS_DIR" "$LOG_DIR"
: >"$BUILD_LOG"

if [[ ! -f "$MAKENSIS_EXE" ]]; then
  echo "[1/4] Downloading NSIS"
  curl -L -o "$NSIS_ZIP" \
    "https://downloads.sourceforge.net/project/nsis/NSIS%203/3.11/nsis-3.11.zip" \
    >>"$BUILD_LOG" 2>&1
  rm -rf "$NSIS_DIR"
  unzip -q "$NSIS_ZIP" -d "$TOOLS_DIR"
else
  echo "[1/4] Using cached NSIS"
fi

shopt -s nullglob
portable_matches=($PORTABLE_DIR_PATTERN)
shopt -u nullglob

portable_dirs=()
for path in "${portable_matches[@]}"; do
  if [[ -d "$path" ]]; then
    portable_dirs+=("$path")
  fi
done

if [[ ${#portable_dirs[@]} -eq 0 ]]; then
  echo "Portable release not found. Expected something like: $PORTABLE_DIR_PATTERN" >&2
  exit 1
fi

SOURCE_DIR="${portable_dirs[-1]}"

echo "[2/4] Preparing installer input"
rm -f "$INSTALLER_PATH" "$INSTALLER_SHA"

SOURCE_DIR_WIN="$(wslpath -w "$SOURCE_DIR")"
INSTALLER_PATH_WIN="$(wslpath -w "$INSTALLER_PATH")"
SCRIPT_PATH_WIN="$(wslpath -w "$SCRIPT_PATH")"

echo "[3/4] Building installer"
"$MAKENSIS_EXE" \
  /DAPP_NAME=Trusty \
  /DAPP_VERSION="$VERSION" \
  /DSOURCE_DIR="$SOURCE_DIR_WIN" \
  /DINSTALLER_OUTPUT="$INSTALLER_PATH_WIN" \
  "$SCRIPT_PATH_WIN" \
  >>"$BUILD_LOG" 2>&1

echo "[4/4] Writing checksum"
sha256sum "$INSTALLER_PATH" | awk '{print $1}' >"$INSTALLER_SHA"

echo "Installer: $INSTALLER_PATH"
echo "SHA256:    $(cat "$INSTALLER_SHA")"
echo "Log:       $BUILD_LOG"
