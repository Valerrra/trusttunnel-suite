# Maintainer Notes

Короткая публично-безопасная памятка по `trusttunnel-suite`.

## Workspace

- Root: `/mnt/d/VPN/trusttunnel-suite`
- Desktop app: `/mnt/d/VPN/trusttunnel-suite/apps/desktop`
- Android app: `/mnt/d/VPN/trusttunnel-suite/apps/android`
- WebUI: `/mnt/d/VPN/trusttunnel-suite/apps/webui`
- Local Flutter plugin fork: `/mnt/d/VPN/trusttunnel-suite/packages/vpn_plugin`
- Releases: `/mnt/d/VPN/trusttunnel-suite/releases`

## Tooling

- Flutter SDK: `/home/valerrra/tools/flutter`
- Android SDK: `/home/valerrra/Android/Sdk`
- Rustup home: `/home/valerrra/.rustup`
- Cargo bin: `/home/valerrra/.cargo/bin`
- Conan: `/home/valerrra/.local/bin/conan`
- Go helper: `/mnt/d/VPN/tools/gow`

## Android Backend

- Working app service wiring:
  - `/mnt/d/VPN/trusttunnel-suite/apps/android/lib/services/vpn_service.dart`
- Local plugin fork:
  - `/mnt/d/VPN/trusttunnel-suite/packages/vpn_plugin/android/build.gradle`
- App repositories include `mavenLocal()`:
  - `/mnt/d/VPN/trusttunnel-suite/apps/android/android/build.gradle.kts`
- App `minSdk = 26`:
  - `/mnt/d/VPN/trusttunnel-suite/apps/android/android/app/build.gradle.kts`
- Current backend release artifact:
  - `/mnt/d/VPN/trusttunnel-suite/releases/trusty-android-arm64-backend-0.1.0-20260328.apk`
- Current backend release is `arm64` only

## Desktop State

- Desktop fork lives in:
  - `/mnt/d/VPN/trusttunnel-suite/apps/desktop`
- Upstream base:
  - `Meddelin/trusty`
- Baseline note:
  - `/mnt/d/VPN/trusttunnel-suite/apps/desktop/FORK_BASELINE.md`
- Already implemented:
  - `tt://` import
  - QR import flow
  - import from clipboard on main screen
  - RU/EN switch
  - Windows autostart toggle
  - auto-connect on launch toggle
  - launch minimized toggle
  - Linux and Windows builds

## Linux Runtime Notes

- Linux portable bundles `client/trusttunnel_client`
- AppImage auto-extracts `client/` next to the `.AppImage` on first launch
- Linux app resolves `client/` relative to the executable or `.AppImage` location
- For actual VPN operation on Linux, one-time capability grant is still needed:
  - `sudo setcap cap_net_admin,cap_net_raw+eip client/trusttunnel_client`
- On some `systemd-resolved` hosts an extra DNS workaround may still be needed:
  - `sudo resolvectl dns tun0 8.8.8.8`
  - `sudo resolvectl domain tun0 "~."`

## WebUI State

- Main WebUI files:
  - `/mnt/d/VPN/trusttunnel-suite/apps/webui/cmd/webui/main.go`
  - `/mnt/d/VPN/trusttunnel-suite/apps/webui/internal/web/server.go`
  - `/mnt/d/VPN/trusttunnel-suite/apps/webui/internal/storage/storage.go`
  - `/mnt/d/VPN/trusttunnel-suite/apps/webui/internal/endpoint/live.go`
  - `/mnt/d/VPN/trusttunnel-suite/apps/webui/internal/ttlink/encode.go`
- Built WebUI binary:
  - `/mnt/d/VPN/trusttunnel-suite/apps/webui/build/trusttunnel-webui`
- Deployment templates:
  - `/mnt/d/VPN/trusttunnel-suite/apps/webui/deploy/systemd/trusttunnel-webui.service`
  - `/mnt/d/VPN/trusttunnel-suite/apps/webui/deploy/systemd/trusttunnel-webui.env.example`
- Current WebUI scope already includes:
  - login and cookie session
  - bootstrap admin
  - dashboard
  - client CRUD
  - real `tt://` export
  - QR generation
  - SQLite storage
  - cascades
  - routing rules
  - datasets
  - Zapret profiles

## Current Gaps

- Linux desktop still has no `.deb`
- Android source build is not yet fully scripted end-to-end inside repo
- Backend release path currently relies on locally published Maven artifact
- WebUI live apply for cascades/routing is not finished
- No final multi-protocol panel support yet
