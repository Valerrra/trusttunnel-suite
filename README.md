# TrustTunnel Suite

Monorepo для трёх связанных продуктов вокруг TrustTunnel:

1. `apps/webui` - серверная WebUI-панель для управления TrustTunnel endpoint.
2. `apps/desktop` - desktop-клиент на базе `trusty` с быстрым импортом конфигов, QR и русским языком.
3. `apps/android` - Android-клиент на общей Flutter-основе с упором на быстрый onboarding.

## Текущее состояние

- `apps/webui`: есть рабочая WebUI-панель с клиентами, QR, `tt://`, dashboard, routing и cascade management
- `apps/desktop`: есть Linux portable/AppImage, Windows portable и Windows installer
- `apps/android`: есть рабочий APK с реальным TrustTunnel backend

## Зачем отдельный проект

TrustTunnel сам по себе уже даёт сильное ядро протокола и экспорт `tt://` deep-link, но вокруг него пока не хватает:

- удобной админ-панели для управления endpoint и клиентами;
- desktop-клиента с нормальным импортом конфигов и русской локализацией;
- Android-клиента с входом через QR/deep-link без ручного ввода;
- единого UX между сервером и клиентами.

## Структура

```text
trusttunnel-suite/
├── README.md
├── PROJECT_ARCHITECTURE.md
├── apps/
│   ├── webui/
│   ├── desktop/
│   └── android/
├── packages/
│   ├── flutter-core/
│   └── config-bridge/
└── docs/
```

## Базовые upstream-источники

- `TrustTunnel/TrustTunnel` - endpoint, setup wizard, экспорт `tt://` deep-link, документация формата.
- `Meddelin/trusty` - Flutter desktop GUI для TrustTunnel.

Для `TrustTunnel` и `trusty` текущая интеграционная стратегия проще: использовать их как основу и развивать поверх.

## Целевой MVP

### 1. WebUI

- логин в панель;
- статус endpoint, домена, TLS, порта и активных клиентов;
- CRUD пользователей TrustTunnel;
- выпуск `tt://` deep-link и QR для клиента;
- импорт/экспорт endpoint-конфигов и credential store;
- routing rules, datasets `geoip/geosite`, Zapret profiles;
- cascade profiles и подготовка к auto-deploy downstream nodes;
- журнал действий и базовые health checks.

### 2. Desktop

- RU/EN локализация;
- импорт из `tt://`, QR, буфера обмена и файла;
- быстрый профиль "подключиться в 1 клик";
- экран профилей, журналов и split-tunnel;
- автозагрузка на Windows;
- автоподключение при старте;
- запуск свернутым;
- совместимость с текущим CLI `trusttunnel_client`.

### 3. Android

- открытие `tt://` через intent-filter;
- сканирование QR;
- сохранение нескольких профилей;
- быстрый connect/disconnect;
- тот же словарь полей и та же логика валидации, что и в desktop.

## Репозиторий

Проект развивается как отдельный monorepo:

- `apps/webui`
- `apps/desktop`
- `apps/android`
- `packages/vpn_plugin`
- `scripts/`
- `docs/`

## Артефакты

Актуальные build/run инструкции лежат в [`docs/BUILD_RUNBOOK.md`](./docs/BUILD_RUNBOOK.md).

## Известные ограничения

- Linux AppImage и Linux portable содержат `trusttunnel_client`, но для реального VPN на Linux нужен one-time `setcap` на внешний `client/trusttunnel_client`
- AppImage при первом запуске выкладывает `client/` рядом с самим `.AppImage`, после чего обычно нужно выполнить:
  - `sudo setcap cap_net_admin,cap_net_raw+eip client/trusttunnel_client`
- на Linux с `systemd-resolved` может дополнительно понадобиться:
  - `sudo resolvectl dns tun0 8.8.8.8`
  - `sudo resolvectl domain tun0 "~."`
- детали и заметки по сборке вынесены в `docs/`
