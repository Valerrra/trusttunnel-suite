# TrustTunnel Suite

Клиентский monorepo вокруг [TrustTunnel](https://github.com/TrustTunnel/TrustTunnel).

Проект сфокусирован на клиентских приложениях и shared-слое:

1. `apps/desktop` — desktop-клиент для Windows/Linux
2. `apps/android` — Android-клиент
3. `packages/*` — общий код, bridge и VPN plugin

## Respect and Credits

Этот проект не появился с нуля.

- [TrustTunnel](https://github.com/TrustTunnel/TrustTunnel) — ядро протокола, endpoint, `tt://` deep-link, setup wizard и общая экосистема.
- [trusty](https://github.com/Meddelin/trusty) от [Meddelin](https://github.com/Meddelin) — исходная база Flutter-клиента, на которой выросли desktop и часть mobile-логики этого репозитория.

`trusttunnel-suite` развивается как самостоятельный репозиторий, но desktop/android часть здесь — это уважительное продолжение и расширение идей `trusty` поверх экосистемы `TrustTunnel`.

## Current State

- `apps/desktop`: есть Linux portable/AppImage, Windows portable и Windows installer
- `apps/android`: есть рабочий APK с реальным TrustTunnel backend
- `packages/vpn_plugin`: локальный plugin-слой для Android backend integration

## Repository Layout

```text
trusttunnel-suite/
├── README.md
├── PROJECT_ARCHITECTURE.md
├── apps/
│   ├── desktop/
│   └── android/
├── packages/
│   ├── config-bridge/
│   ├── flutter-core/
│   └── vpn_plugin/
├── scripts/
└── docs/
```

## Scope

Репозиторий покрывает:

- импорт `tt://`
- QR/deep-link onboarding
- RU/EN локализацию
- desktop packaging
- Android VPN backend integration
- общий формат профилей между платформами

Серверная панель больше не развивается внутри `trusttunnel-suite`. Клиентская часть и серверная панель теперь разведены по разным репозиториям.

## Known Linux Note

Linux portable и AppImage содержат `trusttunnel_client`, но для реального VPN на Linux обычно нужен one-time `setcap` на внешний `client/trusttunnel_client`.

Типовой шаг:

```bash
sudo setcap cap_net_admin,cap_net_raw+eip client/trusttunnel_client
```

## Public Upstreams

- [TrustTunnel / TrustTunnel](https://github.com/TrustTunnel/TrustTunnel)
- [Meddelin / trusty](https://github.com/Meddelin/trusty)
