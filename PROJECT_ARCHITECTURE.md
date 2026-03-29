# PROJECT_ARCHITECTURE

## 1. Goal

`trusttunnel-suite` — это клиентский слой вокруг [TrustTunnel](https://github.com/TrustTunnel/TrustTunnel), где desktop и Android используют один и тот же сценарий:

`получить tt:// / QR -> импортировать профиль -> подключиться в 1 действие`

## 2. Upstream Base

### TrustTunnel

Используется как базовая экосистема:

- endpoint
- setup wizard
- `tt://` deep-link
- клиентский CLI/backend

### trusty

[Meddelin/trusty](https://github.com/Meddelin/trusty) использован как отправная точка для Flutter-клиента.

Что из него важно для этого репозитория:

- Flutter UI foundation
- profile/config model
- desktop shell ideas
- server setup groundwork

## 3. Repository Positioning

`trusttunnel-suite` не является просто форком `trusty`.

Это отдельный client-focused monorepo, в котором:

- `apps/desktop` и `apps/android` развиваются как собственные приложения
- `packages/*` выносят shared-логику
- серверная панель больше не живёт в этом репозитории

## 4. Repository Layout

```text
trusttunnel-suite/
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

## 5. Components

### `apps/desktop`

Назначение:

- основной GUI-клиент для Windows/Linux
- импорт `tt://`
- clipboard/QR onboarding
- profile management
- split tunnel
- desktop-specific lifecycle и packaging

### `apps/android`

Назначение:

- Android-клиент с быстрым onboarding
- deep-link / QR import
- хранение профилей
- реальный Android VPN backend

### `packages/flutter-core`

Shared-слой для Flutter-кода:

- модели профилей
- базовая UI-логика
- локализация
- валидация

### `packages/config-bridge`

Shared-logic для конфигов:

- parse `tt://`
- normalize profile fields
- bridge между endpoint export и локальной profile model

### `packages/vpn_plugin`

Native/plugin слой для Android backend integration.

## 6. Data Flow

### Import flow

1. Пользователь получает `tt://` или QR.
2. Клиент импортирует payload.
3. `config-bridge` нормализует данные.
4. Профиль сохраняется локально.
5. Runtime получает конфиг и поднимает VPN.

### Shared model

Один и тот же словарь полей должен использоваться между:

- desktop
- Android
- deep-link import
- endpoint export compatibility

## 7. Localization

Основной язык UX — русский.

Подход:

- новые строки сразу через l10n
- RU/EN переключение
- onboarding и import flow без англоязычных тупиков

## 8. Platform Split

### Shared

- profile model
- `tt://` import
- validation
- connect/disconnect flow
- localization

### Desktop only

- tray
- window lifecycle
- packaging
- local CLI/runtime handling

### Android only

- mobile permission flow
- QR scanning
- intent/deep-link handling
- Android VPN backend

## 9. Strategic Note

Серверная панель больше не является частью `trusttunnel-suite`.

Это решение принято, потому что клиентский стек и серверная панель теперь развиваются отдельно:

- `trusttunnel-suite` — клиентские приложения
- отдельный `3x-ui_plus`-based repo — серверная панель

## 10. Principles

- уважать upstream `TrustTunnel`
- уважать вклад `Meddelin/trusty`
- не дублировать формат профилей между платформами
- держать клиентские приложения согласованными по UX и import flow
