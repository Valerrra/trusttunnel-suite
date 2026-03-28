# Codex Memory

Короткая внутренняя памятка по `trusttunnel-suite`, чтобы быстро возвращаться в проект без повторного чтения всего репозитория.

## Workspace

- Root: `/mnt/d/VPN/trusttunnel-suite`
- Desktop app: `/mnt/d/VPN/trusttunnel-suite/apps/desktop`
- Android app: `/mnt/d/VPN/trusttunnel-suite/apps/android`
- WebUI: `/mnt/d/VPN/trusttunnel-suite/apps/webui`
- Local Flutter plugin fork: `/mnt/d/VPN/trusttunnel-suite/packages/vpn_plugin`
- Releases: `/mnt/d/VPN/trusttunnel-suite/releases`

## Live Server State

- FI TrustTunnel endpoint canonical domain: `fin.dsinkerii.com`
- Old VPN domain `vlaerrrapupkin.linkpc.net` выпилен из FI endpoint-конфига
- WebUI admin password copy: `/mnt/d/VPN/trusttunnel-suite/docs/webui-admin-password.txt`
- FI staging notes: `/mnt/d/VPN/trusttunnel-suite/docs/FI_STAGING.md`

## Installed Tooling

- Flutter SDK: `/home/valerrra/tools/flutter`
- Flutter helpers:
  - `/mnt/d/VPN/tools/flutterw`
  - `/mnt/d/VPN/tools/flutter-env.sh`
- Go helper:
  - `/mnt/d/VPN/tools/gow`
  - `/mnt/d/VPN/tools/go-env.sh`
- Android SDK: `/home/valerrra/Android/Sdk`
- Rustup home: `/home/valerrra/.rustup`
- Cargo bin: `/home/valerrra/.cargo/bin`
- Conan: `/home/valerrra/.local/bin/conan`
- Local Maven artifact cache used for Android backend:
  - `~/.m2/repository/com/adguard/trusttunnel/trusttunnel-client-android/1.0.39`

## Android Backend Outcome

- Current working APK:
  - `/mnt/d/VPN/trusttunnel-suite/releases/trusty-android-arm64-backend-0.1.0-20260328.apk`
- SHA-256:
  - `81321666a90b772a58512ee346e31735c3b1801429f132d9337061e97e913a2d`
- This build is `arm64` only
- Verified live result from user:
  - external IP seen through VPN: `109.206.243.245`

## Android Code Path

- Real Android VPN service is wired through:
  - `/mnt/d/VPN/trusttunnel-suite/apps/android/lib/services/vpn_service.dart`
- App depends on local Flutter plugin fork via:
  - `/mnt/d/VPN/trusttunnel-suite/apps/android/pubspec.yaml`
- Plugin Android Gradle config:
  - `/mnt/d/VPN/trusttunnel-suite/packages/vpn_plugin/android/build.gradle`
- App-wide repositories include `mavenLocal()` in:
  - `/mnt/d/VPN/trusttunnel-suite/apps/android/android/build.gradle.kts`
- Android app minSdk raised to `26` in:
  - `/mnt/d/VPN/trusttunnel-suite/apps/android/android/app/build.gradle.kts`

## TrustTunnel Upstream Sources Used

- Flutter client reference:
  - `/tmp/TrustTunnelFlutterClient-upstream`
- Native client reference:
  - `/tmp/TrustTunnelClient-upstream`
- Android native library module used for backend build:
  - `/tmp/TrustTunnelClient-upstream/platform/android/lib`

## Route That Worked For Android Backend

1. Install local build prerequisites:
   - `go`
   - `conan`
   - `rustup`
   - Rust target `aarch64-linux-android`
   - `cargo-ndk`
2. Bootstrap Conan packages from `TrustTunnelClient`:
   - `python3 scripts/bootstrap_conan_deps.py`
3. Build upstream Android backend from source
4. Publish backend to `mavenLocal()` as:
   - `com.adguard.trusttunnel:trusttunnel-client-android:1.0.39`
5. Resolve that artifact from our local `vpn_plugin`
6. Build app APK from `/mnt/d/VPN/trusttunnel-suite/apps/android`

## Important Build Notes

- Upstream repo pins Rust toolchain in:
  - `/tmp/TrustTunnelClient-upstream/rust-toolchain.toml`
- It requires Android Rust target for pinned toolchain `1.85`, not only for `stable`
- Direct file dependency on `.aar` inside Flutter plugin library failed under AGP:
  - `:vpn_plugin:bundleReleaseAar` rejects direct local `.aar`
- Working fix was:
  - publish upstream backend to `mavenLocal()`
  - depend on Maven coordinate instead of `files(...)`
- Temporary upstream speedup used to get backend artifact:
  - arm64-only `abiFilters` in `/tmp/TrustTunnelClient-upstream/platform/android/lib/build.gradle.kts`

## Desktop State

- Desktop fork lives in `/mnt/d/VPN/trusttunnel-suite/apps/desktop`
- Upstream base was taken from:
  - `Meddelin/trusty`
- Fork baseline note:
  - `/mnt/d/VPN/trusttunnel-suite/apps/desktop/FORK_BASELINE.md`
- Already implemented there:
  - `tt://` import
  - QR import flow
  - import from clipboard on main screen
  - RU/EN switch
  - Windows autostart toggle
  - auto-connect on launch toggle
  - launch minimized toggle
  - Linux and Windows builds
- Key desktop files:
  - `/mnt/d/VPN/trusttunnel-suite/apps/desktop/lib/services/trusttunnel_deep_link_service.dart`
  - `/mnt/d/VPN/trusttunnel-suite/apps/desktop/lib/widgets/trusttunnel_import_flow.dart`
  - `/mnt/d/VPN/trusttunnel-suite/apps/desktop/lib/screens/home_screen.dart`
  - `/mnt/d/VPN/trusttunnel-suite/apps/desktop/lib/screens/settings_screen.dart`
  - `/mnt/d/VPN/trusttunnel-suite/apps/desktop/lib/services/locale_service.dart`
- Desktop config model expanded for TrustTunnel fields:
  - certificate
  - client random prefix
  - custom SNI
  - split tunnel settings
- Working Windows portable release:
  - `/mnt/d/VPN/trusttunnel-suite/releases/trusty-windows-x64-portable-0.1.0-20260328.zip`
- Windows release checksum:
  - `31b68a671d21ed51d7fcc4314184dff1c9af1f462783ba72ebc5ae5541aaf294`
- Windows portable extracted bundle:
  - `/mnt/d/VPN/trusttunnel-suite/releases/trusty-windows-x64-portable-0.1.0-20260328`
- Main Windows executable:
  - `/mnt/d/VPN/trusttunnel-suite/releases/trusty-windows-x64-portable-0.1.0-20260328/Trusty.exe`
- Working Windows installer:
  - `/mnt/d/VPN/trusttunnel-suite/releases/trusty-windows-x64-setup-0.1.0-20260328.exe`
- Windows installer checksum:
  - `aa4b999740068f8cf38b6c55401a464f372e8ed49a1b873409c21a27210fca8b`
- Linux desktop build path:
  - `/mnt/d/VPN/trusttunnel-suite/apps/desktop/build/linux/x64/release/bundle/trusty`
- Current Linux portable release:
  - `/mnt/d/VPN/trusttunnel-suite/releases/trusty-linux-x64-portable-0.1.0-20260328.tar.gz`
- Linux portable checksum:
  - `866d75ca79828488b9d2cef1b030a6058a66494b9d2d1da444a7cf5a857efae5`
- Current Linux AppImage release:
  - `/mnt/d/VPN/trusttunnel-suite/releases/trusty-linux-x64-appimage-0.1.0-20260328.AppImage`
- Linux AppImage checksum:
  - `c093602b7a9c4d11519ad50e03f378b1d767a926e7f5c318b09e1b602e4476e3`
- Desktop build note:
  - Linux toolchain and Flutter desktop deps were installed locally
  - Windows build used local Windows-side toolchain helpers under `/mnt/d/VPN/tools/`
  - Windows build requires calling `flutter.bat` through `cmd.exe` from WSL
  - working Windows `PUB_CACHE` path: `D:\VPN\tools\windows_pub_cache`
  - `/mnt/d/VPN/trusttunnel-suite/scripts/build-desktop-windows.sh` now follows the real WSL -> Windows-host build path and repacks portable zip automatically
  - Linux `ConfigService` now resolves `client/` relative to the executable location, and for AppImage relative to the `.AppImage` file location
  - Linux portable now bundles `client/trusttunnel_client`
  - AppImage `AppRun` now auto-extracts `client/` next to the `.AppImage` on first launch
  - Linux `VpnService` now tries to configure `systemd-resolved` automatically via:
    - `resolvectl dns tun0 <dns>`
    - `resolvectl domain tun0 "~."`
  - on disconnect/shutdown it tries:
    - `resolvectl revert tun0`

## WebUI State

- WebUI app lives in `/mnt/d/VPN/trusttunnel-suite/apps/webui`
- Main WebUI files:
  - `/mnt/d/VPN/trusttunnel-suite/apps/webui/cmd/webui/main.go`
  - `/mnt/d/VPN/trusttunnel-suite/apps/webui/internal/web/server.go`
  - `/mnt/d/VPN/trusttunnel-suite/apps/webui/internal/storage/storage.go`
  - `/mnt/d/VPN/trusttunnel-suite/apps/webui/internal/endpoint/live.go`
  - `/mnt/d/VPN/trusttunnel-suite/apps/webui/internal/ttlink/encode.go`
  - `/mnt/d/VPN/trusttunnel-suite/apps/webui/README.md`
- Deployment templates:
  - `/mnt/d/VPN/trusttunnel-suite/apps/webui/deploy/systemd/trusttunnel-webui.service`
  - `/mnt/d/VPN/trusttunnel-suite/apps/webui/deploy/systemd/trusttunnel-webui.env.example`
- Built WebUI binary path:
  - `/mnt/d/VPN/trusttunnel-suite/apps/webui/build/trusttunnel-webui`
- FI panel domain:
  - `http://fin.dsinkerii.com/`
- FI endpoint domain:
  - `fin.dsinkerii.com`
- FI endpoint and panel are already live; see `FI_STAGING.md`
- WebUI is not a mock anymore:
  - it syncs real endpoint/client data against FI server-side TrustTunnel config
- WebUI scope already done:
  - login and cookie session
  - bootstrap admin
  - dashboard
  - client CRUD
  - real `tt://` export
  - QR generation
  - SQLite storage
- Important domain split decision:
  - old `vlaerrrapupkin.linkpc.net` removed from active FI VPN role
  - `fin.dsinkerii.com` is the canonical FI endpoint hostname now
- Current WebUI limitation:
  - panel is still on HTTP, not HTTPS, because `443` is occupied by TrustTunnel endpoint

## Current Gaps

- Desktop:
  - no `.deb` yet for Linux desktop
  - Linux AppImage/portable currently still need one-time capability grant for actual VPN traffic:
    - `sudo setcap cap_net_admin,cap_net_raw+eip client/trusttunnel_client`
  - without that, Linux connects to FI but fails during tunnel setup:
    - `OS_TUNNEL_LINUX setup_if: Failed to set IPv4 address`
    - `Unable to setup routes for linuxtun session`
  - confirmed extra Linux workaround on the user's machine:
    - `sudo resolvectl dns tun0 8.8.8.8`
    - `sudo resolvectl domain tun0 "~."`
  - inference:
    - on some Linux hosts, `systemd-resolved` does not bind DNS handling to `tun0` automatically
    - TrustTunnel then reports a generic Linux tunnel setup/routes error even though endpoint connect itself succeeds
  - log saved at:
    - `/mnt/d/VPN/trusttunnel-suite/docs/trustylogs.txt`
- Android source build is not yet fully scripted end-to-end inside repo
- Backend release path currently relies on locally published Maven artifact
- Current Android backend release is arm64-only, not multi-ABI
- WebUI:
  - no separate HTTPS frontend domain/reverse-proxy layout finalized yet
  - no multi-protocol panel support like `3x-ui` yet
