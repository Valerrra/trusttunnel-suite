# Build Runbook

Короткий практический runbook для `trusttunnel-suite`.

## Workspace

- Root: `/mnt/d/VPN/trusttunnel-suite`
- Desktop: `/mnt/d/VPN/trusttunnel-suite/apps/desktop`
- Android: `/mnt/d/VPN/trusttunnel-suite/apps/android`
- WebUI: `/mnt/d/VPN/trusttunnel-suite/apps/webui`
- Local Flutter plugin fork: `/mnt/d/VPN/trusttunnel-suite/packages/vpn_plugin`

## Installed Tooling

- Flutter SDK:
  - `/home/valerrra/tools/flutter`
- Android SDK:
  - `/home/valerrra/Android/Sdk`
- Conan:
  - `/home/valerrra/.local/bin/conan`
- Rustup:
  - `/home/valerrra/.rustup`
- Cargo bin:
  - `/home/valerrra/.cargo/bin`
- Go helper:
  - `/mnt/d/VPN/tools/gow`

## Desktop Build

### Linux

Shortcut:
```bash
./scripts/build-desktop-linux.sh
```

1. Go to:
   - `/mnt/d/VPN/trusttunnel-suite/apps/desktop`
2. Run:
```bash
flutter pub get
flutter build linux
```
3. Result:
   - `/mnt/d/VPN/trusttunnel-suite/apps/desktop/build/linux/x64/release/bundle/trusty`

### Windows Portable

Shortcut:
```bash
./scripts/build-desktop-windows.sh
```

1. Base project:
   - `/mnt/d/VPN/trusttunnel-suite/apps/desktop`
2. Working build path from WSL uses Windows-host Flutter via `cmd.exe`:
```bash
/mnt/c/Windows/System32/cmd.exe /C "set PUB_CACHE=D:\VPN\tools\windows_pub_cache&& cd /d D:\VPN\trusttunnel-suite\apps\desktop && D:\VPN\tools\flutter_windows_sdk\flutter\bin\flutter.bat pub get"
/mnt/c/Windows/System32/cmd.exe /C "set PUB_CACHE=D:\VPN\tools\windows_pub_cache&& cd /d D:\VPN\trusttunnel-suite\apps\desktop && D:\VPN\tools\flutter_windows_sdk\flutter\bin\flutter.bat gen-l10n"
/mnt/c/Windows/System32/cmd.exe /C "set PUB_CACHE=D:\VPN\tools\windows_pub_cache&& cd /d D:\VPN\trusttunnel-suite\apps\desktop && D:\VPN\tools\flutter_windows_sdk\flutter\bin\flutter.bat build windows --release"
```
3. Then refresh portable bundle from:
   - `/mnt/d/VPN/trusttunnel-suite/apps/desktop/build/windows/x64/runner/Release`
4. Keep `client/` inside portable bundle untouched, because it contains:
   - `trusttunnel_client.exe`
   - `trusttunnel_client.toml`
   - `trusttunnel_client.toml.example`
   - `wintun.dll`
5. Portable release artifacts:
   - `/mnt/d/VPN/trusttunnel-suite/releases/trusty-windows-x64-portable-0.1.0-20260328.zip`
   - `/mnt/d/VPN/trusttunnel-suite/releases/trusty-windows-x64-portable-0.1.0-20260328.zip.sha256`
6. Extracted portable bundle:
   - `/mnt/d/VPN/trusttunnel-suite/releases/trusty-windows-x64-portable-0.1.0-20260328`

Current Windows portable SHA-256:

- `31b68a671d21ed51d7fcc4314184dff1c9af1f462783ba72ebc5ae5541aaf294`

### Windows Installer

Shortcut:
```bash
./scripts/build-desktop-windows-installer.sh
```

Artifacts:

- `/mnt/d/VPN/trusttunnel-suite/releases/trusty-windows-x64-setup-0.1.0-20260328.exe`
- `/mnt/d/VPN/trusttunnel-suite/releases/trusty-windows-x64-setup-0.1.0-20260328.exe.sha256`

Current Windows installer SHA-256:

- `aa4b999740068f8cf38b6c55401a464f372e8ed49a1b873409c21a27210fca8b`

### Linux AppImage Runtime Note

Current AppImage artifact:

- `/mnt/d/VPN/trusttunnel-suite/releases/trusty-linux-x64-appimage-0.1.0-20260328.AppImage`

Current AppImage SHA-256:

- `c093602b7a9c4d11519ad50e03f378b1d767a926e7f5c318b09e1b602e4476e3`

Current Linux portable SHA-256:

- `866d75ca79828488b9d2cef1b030a6058a66494b9d2d1da444a7cf5a857efae5`

Known runtime issue from user test log:

- app reaches the endpoint and reports `Successfully connected to endpoint`
- then Linux tun setup fails with:
  - `OS_TUNNEL_LINUX setup_if: Failed to set IPv4 address`
  - `Unable to setup routes for linuxtun session`

Saved log:

- `/mnt/d/VPN/trusttunnel-suite/docs/trustylogs.txt`

Current Linux packaging/runtime behavior:

- Linux portable now includes:
  - `client/trusttunnel_client`
  - `client/trusttunnel_client.toml.example`
- AppImage now auto-extracts `client/` next to the `.AppImage` on first launch
- Linux app resolves `client/` relative to the binary location or the `.AppImage` location, not the current shell directory
- Linux app now also tries to configure `systemd-resolved` automatically with `resolvectl`
- For actual VPN operation on Linux, run one-time:
```bash
sudo setcap cap_net_admin,cap_net_raw+eip client/trusttunnel_client
```

If the tunnel still fails on a `systemd-resolved` host, apply the confirmed workaround:

```bash
sudo resolvectl dns tun0 8.8.8.8
sudo resolvectl domain tun0 "~."
```

This was confirmed on the user's Linux machine together with:

```bash
ls -l /dev/net/tun
ip -o route show to default
```

Observed values:

- `/dev/net/tun` existed and was world-accessible
- default route was present on `enp7s0`

Inference:

- endpoint connectivity itself was fine
- the remaining Linux issue was tied to DNS ownership/binding for `tun0` under `systemd-resolved`

## Android Build

## Android UI-only APK

1. Go to:
   - `/mnt/d/VPN/trusttunnel-suite/apps/android`
2. Run:
```bash
flutter pub get
flutter build apk --release
```
3. Old UI-first artifact:
   - `/mnt/d/VPN/trusttunnel-suite/releases/trusty-android-arm-universal-0.1.0-20260328.apk`

## Android Backend APK

Это основной рабочий путь с настоящим TrustTunnel backend.

Shortcut:
```bash
./scripts/build-android-backend-release.sh
```

### 1. Build prerequisites

Нужно иметь:

- `flutter`
- Android SDK + NDK
- `go`
- `conan`
- `rustup`
- `cargo-ndk`

### 2. Rust setup

Нужны оба шага:

```bash
rustup default stable
rustup target add aarch64-linux-android
rustup target add --toolchain 1.85-x86_64-unknown-linux-gnu aarch64-linux-android
cargo install cargo-ndk
```

Причина:

- upstream pin'ит Rust toolchain `1.85` в:
  - `/tmp/TrustTunnelClient-upstream/rust-toolchain.toml`

### 3. Conan bootstrap

From:
  - `/tmp/TrustTunnelClient-upstream`

Run:
```bash
PATH=$HOME/.local/bin:$PATH python3 scripts/bootstrap_conan_deps.py
```

### 4. Upstream Android backend build

Upstream paths used:

- Flutter client reference:
  - `/tmp/TrustTunnelFlutterClient-upstream`
- Native client reference:
  - `/tmp/TrustTunnelClient-upstream`
- Android native library module:
  - `/tmp/TrustTunnelClient-upstream/platform/android/lib`

For current successful path we used temporary arm64-only optimization in:

- `/tmp/TrustTunnelClient-upstream/platform/android/lib/build.gradle.kts`

with:

- `abiFilters += listOf("arm64-v8a")`

Build command:
```bash
cd /tmp/TrustTunnelClient-upstream/platform/android
PATH=$HOME/.cargo/bin:$HOME/.local/bin:/mnt/d/VPN/tools/go-local/go/bin:$PATH \
./gradlew -Dorg.gradle.java.home=/usr/lib/jvm/java-17-openjdk-amd64 :lib:assembleRelease
```

Output AAR:

- `/tmp/TrustTunnelClient-upstream/platform/android/lib/build/outputs/aar/lib-release.aar`

### 5. Publish backend to local Maven

Important:

- direct local `.aar` dependency inside Flutter plugin library failed under AGP
- working scheme is `mavenLocal()`

Publish command:
```bash
cd /tmp/TrustTunnelClient-upstream/platform/android
PATH=$HOME/.cargo/bin:$HOME/.local/bin:/mnt/d/VPN/tools/go-local/go/bin:$PATH \
./gradlew -Dorg.gradle.java.home=/usr/lib/jvm/java-17-openjdk-amd64 :lib:publishReleasePublicationToMavenLocal
```

Expected local artifact:

- `~/.m2/repository/com/adguard/trusttunnel/trusttunnel-client-android/1.0.39`

### 6. App-side resolution

Required files in repo:

- App repositories:
  - `/mnt/d/VPN/trusttunnel-suite/apps/android/android/build.gradle.kts`
- Plugin repositories:
  - `/mnt/d/VPN/trusttunnel-suite/packages/vpn_plugin/android/build.gradle`
- App service wiring:
  - `/mnt/d/VPN/trusttunnel-suite/apps/android/lib/services/vpn_service.dart`

Important config:

- app `minSdk = 26`
- `mavenLocal()` enabled in app-wide Android repositories
- `mavenLocal()` enabled in plugin Android repositories
- plugin depends on:
  - `com.adguard.trusttunnel:trusttunnel-client-android:1.0.39`

### 7. Final APK build

From:
  - `/mnt/d/VPN/trusttunnel-suite/apps/android`

Run:
```bash
flutter pub get
flutter build apk --release --target-platform android-arm64
```

Final output:

- `/mnt/d/VPN/trusttunnel-suite/apps/android/build/app/outputs/flutter-apk/app-release.apk`

Published release copy:

- `/mnt/d/VPN/trusttunnel-suite/releases/trusty-android-arm64-backend-0.1.0-20260328.apk`
- `/mnt/d/VPN/trusttunnel-suite/releases/trusty-android-arm64-backend-0.1.0-20260328.apk.sha256`

SHA-256:

- `81321666a90b772a58512ee346e31735c3b1801429f132d9337061e97e913a2d`

Known current state:

- build is `arm64` only
- backend path was verified in a live VPN scenario

## WebUI Build

Shortcut:
```bash
./scripts/build-webui.sh
```

1. Go to:
   - `/mnt/d/VPN/trusttunnel-suite/apps/webui`
2. Run tests:
```bash
go test ./...
```
3. Build:
```bash
go build -o build/trusttunnel-webui ./cmd/webui
```
4. Output:
   - `/mnt/d/VPN/trusttunnel-suite/apps/webui/build/trusttunnel-webui`

## WebUI Deploy Notes

- Main server binary entry:
  - `/mnt/d/VPN/trusttunnel-suite/apps/webui/cmd/webui/main.go`
- Main HTTP server:
  - `/mnt/d/VPN/trusttunnel-suite/apps/webui/internal/web/server.go`
- Real endpoint integration:
  - `/mnt/d/VPN/trusttunnel-suite/apps/webui/internal/endpoint/live.go`
- Storage:
  - `/mnt/d/VPN/trusttunnel-suite/apps/webui/internal/storage/storage.go`
- `tt://` encoder:
  - `/mnt/d/VPN/trusttunnel-suite/apps/webui/internal/ttlink/encode.go`
- systemd templates:
  - `/mnt/d/VPN/trusttunnel-suite/apps/webui/deploy/systemd/trusttunnel-webui.service`
  - `/mnt/d/VPN/trusttunnel-suite/apps/webui/deploy/systemd/trusttunnel-webui.env.example`

## Quick References

- Architecture:
  - `/mnt/d/VPN/trusttunnel-suite/PROJECT_ARCHITECTURE.md`
- Main project README:
  - `/mnt/d/VPN/trusttunnel-suite/README.md`
- Memory note:
  - `/mnt/d/VPN/trusttunnel-suite/docs/CODEX_MEMORY.md`
