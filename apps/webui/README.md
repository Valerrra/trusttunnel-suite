# WebUI

TrustTunnel WebUI-панель для управления клиентами, выпуска `tt://`-конфигов и QR, плюс отдельная вкладка Dashboard по хосту и endpoint.

## Что уже есть

- логин по сессии;
- bootstrap-admin при первом запуске;
- отдельная вкладка `Dashboard` со сводкой по клиентам и аудит-лентой;
- live-метрики хоста: CPU, RAM, disk, общий RX/TX и TCP-connections;
- CRUD клиентов;
- генерация `tt://` deep-link по официальной спецификации TrustTunnel;
- QR-экспорт для mobile/desktop импорта;
- нижний spoiler для логов панели;
- отображение per-client traffic/connections, если доступен snapshot-файл;
- SQLite-хранилище без внешней БД.

## Текущий UX

- стартовая страница панели: `Clients`
- `Dashboard` вынесен в отдельную вкладку, как отдельный ops-экран
- логи панели закреплены снизу под spoiler и не перегружают основной интерфейс

## Стек

- Go
- `net/http`
- SQLite (`modernc.org/sqlite`)
- server-rendered HTML
- QR generation (`github.com/skip2/go-qrcode`)

## Быстрый старт

```bash
cd /mnt/d/VPN/trusttunnel-suite/apps/webui
source /mnt/d/VPN/tools/go-env.sh
go run ./cmd/webui
```

По умолчанию панель стартует на `http://127.0.0.1:8088`.

Если база пустая, приложение создаст пользователя `admin` и выведет пароль в лог. Чтобы задать свой пароль сразу:

```bash
TT_WEBUI_ADMIN_PASSWORD='your-strong-password' go run ./cmd/webui
```

Чтобы собрать бинарь:

```bash
cd /mnt/d/VPN/trusttunnel-suite/apps/webui
source /mnt/d/VPN/tools/go-env.sh
go build -o build/trusttunnel-webui ./cmd/webui
```

## Переменные окружения

- `TT_WEBUI_ADDR` - адрес прослушивания, по умолчанию `127.0.0.1:8088`
- `TT_WEBUI_DB_PATH` - путь к SQLite-базе, по умолчанию `./data/webui.db`
- `TT_WEBUI_ADMIN_USERNAME` - bootstrap login, по умолчанию `admin`
- `TT_WEBUI_ADMIN_PASSWORD` - bootstrap пароль, если база ещё пустая
- `TT_WEBUI_SECURE_COOKIE` - `true`, если панель работает строго за HTTPS reverse proxy
- `TT_WEBUI_ENDPOINT_LIVE_MODE` - включить работу через реальный `trusttunnel_endpoint`
- `TT_WEBUI_ENDPOINT_DIR` - каталог TrustTunnel, по умолчанию `/opt/trusttunnel`
- `TT_WEBUI_ENDPOINT_BIN` - путь к `trusttunnel_endpoint`
- `TT_WEBUI_ENDPOINT_VPN_CONFIG` - путь к `vpn.toml`
- `TT_WEBUI_ENDPOINT_HOSTS_CONFIG` - путь к `hosts.toml`
- `TT_WEBUI_ENDPOINT_CREDENTIALS_FILE` - путь к `credentials.toml`
- `TT_WEBUI_ENDPOINT_PUBLIC_ADDRESS` - публичный адрес для server-side export
- `TT_WEBUI_ENDPOINT_PORT` - порт endpoint для live TCP metrics, по умолчанию `443`
- `TT_WEBUI_CLIENT_STATS_FILE` - путь к snapshot JSON с per-client traffic/connections
- `TT_WEBUI_METRICS_DISK_PATH` - путь для расчёта disk usage, по умолчанию каталог endpoint

### Формат snapshot-файла

Если есть внешний коллектор, WebUI умеет подхватывать per-client статистику из JSON:

```json
{
  "generated_at": "2026-03-28T12:00:00Z",
  "clients": [
    {
      "username": "premium-user",
      "rx_bytes": 123456789,
      "tx_bytes": 987654321,
      "active_connections": 2,
      "updated_at": "2026-03-28T12:00:00Z"
    }
  ]
}
```

Если snapshot отсутствует, dashboard и client list всё равно показывают честные host-level метрики.

## Ближайшие шаги

- собрать автоматический collector для `TT_WEBUI_CLIENT_STATS_FILE`;
- добавить HTTPS/panel-domain split без конфликтов с endpoint на `443`;
- RU/EN переключение интерфейса;
- роли и более строгий аудит.

## Deployment Templates

В `deploy/systemd/` уже лежат шаблоны:

- `trusttunnel-webui.service`
- `trusttunnel-webui.env.example`

Их можно использовать как основу для Linux deployment через `systemd`.
