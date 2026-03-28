# PROJECT_ARCHITECTURE

## 1. Цель

Собрать экосистему вокруг TrustTunnel, где сервер, desktop и Android используют один и тот же формат подключения и дают быстрый сценарий:

`создать клиента в WebUI -> получить tt:// / QR -> открыть на desktop или Android -> подключиться в 1 действие`

## 2. Что мы уже знаем по upstream

### TrustTunnel

- endpoint умеет экспортировать клиентскую конфигурацию как `tt://` deep-link;
- deep-link подходит для QR и мобильных клиентов;
- есть `setup_wizard`, systemd-template и documented endpoint lifecycle;
- Flutter-клиент у upstream пока ограничен, а self-signed сертификаты для GUI-сценариев не подходят.

### trusty

- проект написан на Flutter;
- уже содержит сервисы подключения, split tunnel, серверный setup через SSH и зачатки l10n;
- текущая реализация жёстко ориентирована на desktop:
  - `tray_manager`;
  - `window_manager`;
  - код с `Platform.isWindows` / `Platform.isMacOS`;
  - прямые ожидания локального CLI-бинаря.

Вывод: `trusty` лучше превращать не в один форк, а в источник общего Flutter-слоя + отдельных platform shells.

## 3. Лицензионная стратегия

- `apps/webui` пишется отдельно;
- `apps/desktop` и `apps/android` строятся на базе `trusty` и TrustTunnel ecosystem;
- shared-слой остаётся под согласованной лицензией форка;
- в публичной архитектуре фиксируем только те источники и решения, которые реально используются в проекте.

## 4. Целевая архитектура репозитория

```text
trusttunnel-suite/
├── apps/
│   ├── webui/
│   ├── desktop/
│   └── android/
├── packages/
│   ├── flutter-core/
│   └── config-bridge/
└── docs/
```

## 5. Компоненты

### `apps/webui`

Назначение: админ-панель TrustTunnel endpoint.

Предлагаемый стек:

- Go;
- Gin или Chi;
- SQLite для панели;
- server-rendered HTML + HTMX/Alpine или лёгкий JS без тяжёлого SPA;
- QR generation;
- systemd deployment на Linux-хосте.

Функции:

- login/session;
- серверный dashboard;
- управление endpoint settings;
- users/credentials CRUD;
- генерация `tt://`;
- QR для desktop/mobile;
- импорт и экспорт конфигов;
- аудит действий;
- health and diagnostics.

### `apps/desktop`

Назначение: основной GUI-клиент для Windows/Linux/macOS с быстрым импортом.

Основа:

- Flutter UI;
- reuse логики `trusty`;
- локальный `trusttunnel_client` как runtime.

Новые функции поверх `trusty`:

- русский язык;
- onboarding "вставил `tt://` -> профиль создался";
- QR-импорт с камеры/скриншота/буфера;
- файловый импорт;
- better profile management;
- простая интеграция с WebUI-полученными конфигами.

### `apps/android`

Назначение: мобильный клиент с минимальным friction.

Основа:

- Flutter mobile shell;
- максимальный reuse `packages/flutter-core`;
- Android-specific integration для:
  - camera QR scan;
  - `tt://` intent filter;
  - secure local profile storage;
  - background/VPN permission flow.

### `packages/flutter-core`

Назначение: общий код для `apps/desktop` и `apps/android`.

Сюда выносятся:

- модели профилей;
- локализация;
- форма редактирования профиля;
- логика импорта;
- валидация;
- экран профилей;
- часть VPN state management, не завязанная на desktop-only API.

### `packages/config-bridge`

Назначение: единый модуль интеграции конфигов.

Функции:

- parse `tt://`;
- serialize/deserialize profile model;
- import from QR payload;
- import from file/TOML;
- normalize server address / username / protocol;
- compatibility adapters between:
  - TrustTunnel endpoint export;
  - trusty-style local config;
  - внутренней profile model.

Это ключ к сценарию "один формат на все клиенты".

## 6. Ключевой поток данных

### Сервер -> клиент

1. Админ создаёт пользователя в WebUI.
2. WebUI вызывает endpoint export или собирает payload по той же спецификации.
3. Получается `tt://` deep-link.
4. WebUI показывает QR и кнопку copy/open.
5. Desktop/Android импортирует link и создаёт профиль.
6. Клиент передаёт нормализованный config в `trusttunnel_client`.

### Ручной импорт

1. Пользователь вставляет `tt://`.
2. `config-bridge` валидирует payload.
3. UI показывает preview:
   - hostname;
   - address;
   - username;
   - protocol;
   - trust settings.
4. Пользователь подтверждает импорт.
5. Профиль сохраняется.

## 7. Локализация

Базовый язык интерфейса: русский.

Целевой подход:

- все новые тексты сразу через `arb`/Flutter l10n;
- серверный WebUI сразу с RU и EN;
- ключевые системные ошибки тоже нормализуются через локализационный слой;
- импорт и wizard-потоки не должны оставаться англоязычными даже если внутренний CLI пишет логи на английском.

## 8. Отличия desktop и Android

### Общие

- профили;
- импорт `tt://`;
- валидация;
- connect/disconnect UX;
- локализация;
- логика хранения метаданных профиля.

### Только desktop

- tray;
- window lifecycle;
- файловый импорт drag-and-drop;
- локальный поиск CLI-бинаря;
- расширенные логи и split tunnel UI.

### Только Android

- intent/deep-link handler;
- camera QR scan;
- permission flow;
- foreground service / VPN permission integration;
- мобильный минималистичный onboarding.

## 9. WebUI: разделы MVP

1. `Overview`
2. `Clients`
3. `Configs / QR`
4. `Server`
5. `Logs`
6. `Settings`

Для первой версии не надо пытаться делать перегруженную панель. Нужен узкий TT-ориентированный MVP.

## 10. Бэкенд WebUI

Предлагаемые модули:

- `auth`
- `server`
- `clients`
- `exports`
- `audit`
- `health`
- `storage`

Хранилище SQLite:

- `users`
- `profiles`
- `exports`
- `audit_log`
- `settings`

Важно: источник истины для реальной endpoint-конфигурации остаётся у TrustTunnel. База панели хранит только метаданные, индексы и audit layer.

## 11. Развёртывание

### Stage 1

- первый Linux-хост используется как dev/staging;
- деплой через systemd;
- домен и TLS настраиваются сразу под реальный public сценарий, потому что GUI-клиенты TrustTunnel плохо сочетаются с self-signed.

### Stage 2

- отдельный prod;
- резервирование и backup SQLite/конфигов;
- release pipeline для desktop и Android.

## 12. Главные технические риски

1. `trusty` пока не разделён на mobile-safe и desktop-only код.
2. Android потребует отдельной интеграции с VPN/runtime flow, а не только Flutter UI.
3. Важно не задублировать и не рассинхронизировать формат профилей между WebUI, desktop и Android.
4. Сертификаты и домен критичны для гладкого UX.

## 13. Ближайший план реализации

### Этап A

- завести форк `trusty` в `apps/desktop`;
- вычленить shared Flutter-слой;
- добавить RU локализацию;
- реализовать импорт `tt://` из буфера.

### Этап B

- поднять mobile shell в `apps/android`;
- подключить `config-bridge`;
- реализовать deep-link open и QR scan.

### Этап C

- поднять `apps/webui`;
- сделать CRUD клиентов и генерацию QR;
- связать с реальным staging-хостом.

## 14. Definition of Done для первой рабочей версии

Система считается собранной в MVP, когда:

- на staging-хосте можно создать клиента из WebUI;
- WebUI выдаёт QR и `tt://`;
- desktop-клиент импортирует ссылку без ручного редактирования;
- Android-клиент импортирует QR и подключается;
- RU интерфейс есть во всех трёх приложениях.
