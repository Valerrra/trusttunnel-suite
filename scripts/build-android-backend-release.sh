#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
ANDROID_APP_DIR="$ROOT_DIR/apps/android"
UPSTREAM_CLIENT_DIR="${TRUSTTUNNEL_CLIENT_UPSTREAM:-/tmp/TrustTunnelClient-upstream}"
UPSTREAM_ANDROID_DIR="$UPSTREAM_CLIENT_DIR/platform/android"
UPSTREAM_LIB_GRADLE="$UPSTREAM_ANDROID_DIR/lib/build.gradle.kts"
GO_BIN_DIR="${GO_BIN_DIR:-/mnt/d/VPN/tools/go-local/go/bin}"
GRADLE_JAVA_HOME="${GRADLE_JAVA_HOME:-/usr/lib/jvm/java-17-openjdk-amd64}"
BACKEND_VERSION="${BACKEND_VERSION:-1.0.39}"
RELEASE_APK_NAME="${RELEASE_APK_NAME:-trusty-android-arm64-backend-0.1.0-$(date +%Y%m%d).apk}"
RELEASES_DIR="$ROOT_DIR/releases"
LOG_DIR="$ROOT_DIR/.build-logs"
BUILD_LOG="$LOG_DIR/android-backend-build.log"

mkdir -p "$LOG_DIR" "$RELEASES_DIR"

need_cmd() {
  if ! command -v "$1" >/dev/null 2>&1; then
    echo "Missing required command: $1" >&2
    exit 1
  fi
}

need_file() {
  if [ ! -f "$1" ]; then
    echo "Missing required file: $1" >&2
    exit 1
  fi
}

need_cmd flutter
need_cmd rustup
need_cmd cargo
need_cmd python3
need_cmd sha256sum
need_cmd sed
need_cmd awk
need_cmd grep
need_file "$UPSTREAM_CLIENT_DIR/scripts/bootstrap_conan_deps.py"
need_file "$UPSTREAM_LIB_GRADLE"

export PATH="$HOME/.cargo/bin:$HOME/.local/bin:$GO_BIN_DIR:$PATH"

need_cmd conan
need_cmd cargo-ndk

echo "[1/8] Ensuring Rust targets are installed"
rustup default stable >/dev/null
rustup target add aarch64-linux-android >/dev/null
rustup target add --toolchain 1.85-x86_64-unknown-linux-gnu aarch64-linux-android >/dev/null

echo "[2/8] Bootstrapping Conan dependencies"
(
  cd "$UPSTREAM_CLIENT_DIR"
  python3 scripts/bootstrap_conan_deps.py >/dev/null
)

echo "[3/8] Ensuring arm64-only upstream Android build"
if ! grep -q 'abiFilters += listOf("arm64-v8a")' "$UPSTREAM_LIB_GRADLE"; then
  python3 - "$UPSTREAM_LIB_GRADLE" <<'PY'
from pathlib import Path
import sys

path = Path(sys.argv[1])
text = path.read_text()
needle = "    defaultConfig {\n        minSdk = 26\n"
replacement = (
    "    defaultConfig {\n"
    "        minSdk = 26\n"
    "        ndk {\n"
    "            abiFilters += listOf(\"arm64-v8a\")\n"
    "        }\n"
)
if needle not in text:
    raise SystemExit(f"Unable to patch {path}: expected defaultConfig block not found")
path.write_text(text.replace(needle, replacement, 1))
PY
fi

echo "[4/8] Building upstream Android backend AAR"
(
  cd "$UPSTREAM_ANDROID_DIR"
  ./gradlew -Dorg.gradle.java.home="$GRADLE_JAVA_HOME" :lib:assembleRelease >>"$BUILD_LOG" 2>&1
)

echo "[5/8] Publishing upstream Android backend to mavenLocal()"
(
  cd "$UPSTREAM_ANDROID_DIR"
  ./gradlew -Dorg.gradle.java.home="$GRADLE_JAVA_HOME" :lib:publishReleasePublicationToMavenLocal >>"$BUILD_LOG" 2>&1
)

if [ ! -f "$HOME/.m2/repository/com/adguard/trusttunnel/trusttunnel-client-android/$BACKEND_VERSION/trusttunnel-client-android-$BACKEND_VERSION.aar" ]; then
  echo "Local Maven artifact was not published as expected" >&2
  exit 1
fi

echo "[6/8] Fetching Flutter dependencies"
(
  cd "$ANDROID_APP_DIR"
  flutter pub get >>"$BUILD_LOG" 2>&1
)

echo "[7/8] Building final Android APK"
(
  cd "$ANDROID_APP_DIR"
  flutter build apk --release --target-platform android-arm64 >>"$BUILD_LOG" 2>&1
)

APK_PATH="$ANDROID_APP_DIR/build/app/outputs/flutter-apk/app-release.apk"
need_file "$APK_PATH"

echo "[8/8] Publishing release artifact"
cp "$APK_PATH" "$RELEASES_DIR/$RELEASE_APK_NAME"
(
  cd "$RELEASES_DIR"
  sha256sum "$RELEASE_APK_NAME" > "$RELEASE_APK_NAME.sha256"
)

echo
echo "Android backend release ready:"
echo "  APK:    $RELEASES_DIR/$RELEASE_APK_NAME"
echo "  SHA256: $RELEASES_DIR/$RELEASE_APK_NAME.sha256"
echo "  Log:    $BUILD_LOG"
