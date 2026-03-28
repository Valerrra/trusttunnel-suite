# TrustTunnel Suite

Monorepo для трёх связанных продуктов вокруг TrustTunnel:

1. `apps/webui` - серверная WebUI-панель по мотивам `3x-ui`, но для управления TrustTunnel endpoint.
2. `apps/desktop` - desktop-клиент на базе `trusty` с быстрым импортом конфигов, QR и русским языком.
3. `apps/android` - Android-клиент на общей Flutter-основе с упором на быстрый onboarding.

## Текущее состояние

- `apps/webui`: live-панель уже работает на FI и привязана к `fin.dsinkerii.com`
- `apps/desktop`: есть Linux portable/AppImage, Windows portable и Windows installer
- `apps/android`: есть рабочий APK с реальным TrustTunnel backend

## Зачем отдельный проект

TrustTunnel сам по себе уже даёт сильное ядро протокола и экспорт `tt://` deep-link, но вокруг него пока не хватает:

- удобной админ-панели уровня `x-ui`;
- desktop-клиента с нормальным импортом конфигов и русской локализацией;
- Android-клиента с входом через QR/deep-link без ручного ввода;
- единого UX между сервером и клиентами.

Этот каталог нужен как чистая стартовая точка под новый стек, не смешанный с текущими скриптами и экспериментами в корне `/mnt/d/VPN`.

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
- `MHSanaei/3x-ui` - референс по UX, IA, i18n и панели управления, но с GPLv3-лицензией.

## Важное ограничение по лицензиям

`3x-ui` находится под GPLv3. Поэтому для `apps/webui` безопаснее брать оттуда идеи по структуре панели, разделам, UX-потокам и i18n-подходу, но не копировать код без осознанного решения лицензировать весь WebUI-слой совместимо с GPLv3.

Для `TrustTunnel` и `trusty` текущая интеграционная стратегия проще: использовать их как основу и развивать поверх.

## Целевой MVP

### 1. WebUI

- логин в панель;
- статус endpoint, домена, TLS, порта и активных клиентов;
- CRUD пользователей TrustTunnel;
- выпуск `tt://` deep-link и QR для клиента;
- импорт/экспорт endpoint-конфигов и credential store;
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

## Рекомендуемый порядок реализации

1. Вынести shared Flutter-логику в `packages/flutter-core`.
2. Реализовать `packages/config-bridge` для разбора `tt://`, TOML и QR payload.
3. Форкнуть/адаптировать `trusty` в `apps/desktop`.
4. Подготовить mobile shell в `apps/android` с reuse shared-слоя.
5. Поднять `apps/webui` на FI-сервере как staging.

## Test / Staging

Тестовый сервер для первой итерации: FI.

- доступы уже лежат в [/mnt/d/VPN/access_list.MD](/mnt/d/VPN/access_list.MD);
- в этот README секреты намеренно не дублируются;
- сервер считаем одновременно `dev` и `staging`, пока не появится отдельный прод.

## Артефакты

- Linux portable: [/mnt/d/VPN/trusttunnel-suite/releases/trusty-linux-x64-portable-0.1.0-20260328.tar.gz](/mnt/d/VPN/trusttunnel-suite/releases/trusty-linux-x64-portable-0.1.0-20260328.tar.gz)
- Linux AppImage: [/mnt/d/VPN/trusttunnel-suite/releases/trusty-linux-x64-appimage-0.1.0-20260328.AppImage](/mnt/d/VPN/trusttunnel-suite/releases/trusty-linux-x64-appimage-0.1.0-20260328.AppImage)
- Windows portable: [/mnt/d/VPN/trusttunnel-suite/releases/trusty-windows-x64-portable-0.1.0-20260328.zip](/mnt/d/VPN/trusttunnel-suite/releases/trusty-windows-x64-portable-0.1.0-20260328.zip)
- Windows installer: [/mnt/d/VPN/trusttunnel-suite/releases/trusty-windows-x64-setup-0.1.0-20260328.exe](/mnt/d/VPN/trusttunnel-suite/releases/trusty-windows-x64-setup-0.1.0-20260328.exe)
- Android backend APK: [/mnt/d/VPN/trusttunnel-suite/releases/trusty-android-arm64-backend-0.1.0-20260328.apk](/mnt/d/VPN/trusttunnel-suite/releases/trusty-android-arm64-backend-0.1.0-20260328.apk)

## Известные ограничения

- Linux AppImage и Linux portable теперь содержат `trusttunnel_client`, но для реального VPN на Linux нужен one-time `setcap` на внешний `client/trusttunnel_client`
- AppImage при первом запуске выкладывает `client/` рядом с самим `.AppImage`, после чего нужно выполнить:
  - `sudo setcap cap_net_admin,cap_net_raw+eip client/trusttunnel_client`
- на Linux с `systemd-resolved` может дополнительно понадобиться:
  - `sudo resolvectl dns tun0 8.8.8.8`
  - `sudo resolvectl domain tun0 "~."`
- исходный проблемный лог сохранён в [/mnt/d/VPN/trusttunnel-suite/docs/trustylogs.txt](/mnt/d/VPN/trusttunnel-suite/docs/trustylogs.txt)
