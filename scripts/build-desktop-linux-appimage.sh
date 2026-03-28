#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
DESKTOP_DIR="$ROOT_DIR/apps/desktop"
RELEASES_DIR="$ROOT_DIR/releases"
TOOLS_DIR="/mnt/d/VPN/tools/appimage"
LOG_DIR="$ROOT_DIR/.build-logs"
BUILD_LOG="$LOG_DIR/desktop-linux-appimage.log"
APPIMAGETOOL="$TOOLS_DIR/appimagetool-x86_64.AppImage"
VERSION="$(grep '^version:' "$DESKTOP_DIR/pubspec.yaml" | awk '{print $2}' | cut -d+ -f1)"
DATE_STAMP="$(date +%Y%m%d)"
PACKAGE_NAME="trusty-linux-x64-appimage-${VERSION}-${DATE_STAMP}"
APPDIR="$RELEASES_DIR/Trusty.AppDir"
APPIMAGE="$RELEASES_DIR/${PACKAGE_NAME}.AppImage"
APPIMAGE_SHA="$APPIMAGE.sha256"
ICON_SRC="$DESKTOP_DIR/assets/icon.png"
DESKTOP_FILE_SRC="$DESKTOP_DIR/packaging/linux/trusty.desktop"

mkdir -p "$LOG_DIR" "$RELEASES_DIR" "$TOOLS_DIR"
: >"$BUILD_LOG"

if ! command -v curl >/dev/null 2>&1; then
  echo "Missing required command: curl" >&2
  exit 1
fi

if [[ ! -x "$APPIMAGETOOL" ]]; then
  echo "[1/6] Downloading appimagetool"
  curl -L \
    -o "$APPIMAGETOOL" \
    "https://github.com/AppImage/appimagetool/releases/download/continuous/appimagetool-x86_64.AppImage" \
    >>"$BUILD_LOG" 2>&1
  chmod +x "$APPIMAGETOOL"
else
  echo "[1/6] Using cached appimagetool"
fi

echo "[2/6] Building Linux portable bundle"
bash "$ROOT_DIR/scripts/build-desktop-linux.sh" >>"$BUILD_LOG" 2>&1

echo "[3/6] Preparing AppDir"
rm -rf "$APPDIR"
mkdir -p "$APPDIR"
cp -a "$DESKTOP_DIR/build/linux/x64/release/bundle/." "$APPDIR/"

PORTABLE_DIR="$RELEASES_DIR/trusty-linux-x64-portable-${VERSION}-${DATE_STAMP}"
if [[ -d "$PORTABLE_DIR/client" ]]; then
  mkdir -p "$APPDIR/client"
  cp -a "$PORTABLE_DIR/client/." "$APPDIR/client/"
fi

cp "$ICON_SRC" "$APPDIR/trusty.png"
cp "$ICON_SRC" "$APPDIR/.DirIcon"
cp "$DESKTOP_FILE_SRC" "$APPDIR/trusty.desktop"

cat >"$APPDIR/AppRun" <<'EOF'
#!/usr/bin/env bash
set -euo pipefail
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

if [[ -n "${APPIMAGE:-}" && -f "$HERE/client/trusttunnel_client" ]]; then
  TARGET_BASE="$(cd "$(dirname "$APPIMAGE")" && pwd)"
  TARGET_CLIENT_DIR="$TARGET_BASE/client"

  if [[ ! -f "$TARGET_CLIENT_DIR/trusttunnel_client" ]]; then
    mkdir -p "$TARGET_CLIENT_DIR"
    cp "$HERE/client/trusttunnel_client" "$TARGET_CLIENT_DIR/trusttunnel_client"
    chmod +x "$TARGET_CLIENT_DIR/trusttunnel_client"

    if [[ -f "$HERE/client/trusttunnel_client.toml.example" ]]; then
      cp "$HERE/client/trusttunnel_client.toml.example" \
        "$TARGET_CLIENT_DIR/trusttunnel_client.toml.example"
    fi
  fi
fi

exec "$HERE/trusty" "$@"
EOF
chmod +x "$APPDIR/AppRun"

echo "[4/6] Cleaning previous AppImage"
rm -f "$APPIMAGE" "$APPIMAGE_SHA"

echo "[5/6] Packing AppImage"
ARCH=x86_64 APPIMAGE_EXTRACT_AND_RUN=1 "$APPIMAGETOOL" \
  "$APPDIR" \
  "$APPIMAGE" \
  >>"$BUILD_LOG" 2>&1

echo "[6/6] Writing checksum"
sha256sum "$APPIMAGE" | awk '{print $1}' >"$APPIMAGE_SHA"

echo "AppImage: $APPIMAGE"
echo "SHA256:   $(cat "$APPIMAGE_SHA")"
echo "Log:      $BUILD_LOG"
