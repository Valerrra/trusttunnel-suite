# Cascade Autodeploy

Черновик архитектуры для следующего большого шага: при создании каскада WebUI должен уметь не только сохранить upstream-профиль, но и сам развернуть новый TrustTunnel-узел по SSH и привязать его к текущему серверу как следующий hop.

## Цель

Сделать сценарий:

1. На сервере 1 в WebUI создаётся новый каскад.
2. Сервер 1 по SSH подключается к серверу 2.
3. На сервере 2 автоматически разворачиваются:
   - `trusttunnel_endpoint`
   - `trusttunnel-webui`
   - systemd units
   - базовые конфиги
   - домен / TLS
4. Между сервером 1 и сервером 2 создаётся каскадное TrustTunnel-подключение.
5. Новый hop получает выделенный порт каскада.

## Портовая схема

Пока принимаем простую детерминированную схему:

- второй сервер в цепочке: `1443`
- третий сервер в цепочке: `2443`
- четвёртый сервер в цепочке: `3443`

Формула:

- `cascade_port = (hop_index * 1000) + 443`

Где:

- `hop_index = 1` для первого downstream hop от основного сервера
- `hop_index = 2` для следующего downstream hop

## Что нужно хранить в WebUI

### 1. Cascade node

- `display_name`
- `ssh_host`
- `ssh_port`
- `ssh_username`
- `ssh_auth_mode` (`password` / `key`)
- `ssh_password` или `ssh_key_path`
- `public_domain`
- `public_ip`
- `cascade_port`
- `hop_index`
- `enabled`
- `notes`

### 2. Cascade deployment status

- `pending`
- `installing`
- `configured`
- `linked`
- `failed`

### 3. Generated linkage data

- upstream TrustTunnel credentials
- generated endpoint hostname/port for the child node
- issued WebUI admin credentials for the child node
- timestamps and last deploy log

## Этапы автодеплоя

### Этап 1. SSH bootstrap

- проверить доступность SSH
- определить ОС / пакетный менеджер
- создать рабочие каталоги

### Этап 2. Install TT

- установить `trusttunnel_endpoint`
- положить `vpn.toml`, `hosts.toml`, `credentials.toml`
- активировать `trusttunnel.service`

### Этап 3. Install WebUI

- установить `trusttunnel-webui`
- создать SQLite data dir
- выпустить bootstrap admin credentials
- активировать `trusttunnel-webui.service`

### Этап 4. TLS / domain

- проверить, что `public_domain` резолвится в `public_ip`
- получить сертификат
- записать live endpoint hostname

### Этап 5. Link parent -> child

- на сервере 1 создать cascade profile на сервер 2
- привязать его к нужному `cascade_port`
- при необходимости обновить routing/split rules

## Минимальный API / UI поток

### В панели

Добавить wizard:

1. `New Cascade Node`
2. `SSH + Domain`
3. `Install TT + WebUI`
4. `Link To Parent`
5. `Review`

### Результат

После успешного мастера WebUI должен показать:

- `child endpoint`
- `child webui url`
- `cascade port`
- `hop index`
- статус линковки

## Практические ограничения

- секреты SSH и WebUI нельзя хранить в открытом виде в git
- для password auth нужны шифрование/маскирование в БД
- нужен rollback, если TT поднялся, а WebUI не поднялся
- нужен idempotent re-run для повторного деплоя

## Ближайшая реализация

### Stage A

- расширить `cascades` до real node deployment model
- добавить SSH поля и deploy status
- добавить server-side deploy log

### Stage B

- реализовать `Deploy Cascade Node` по SSH
- отдельная установка `TT + WebUI`
- автогенерация `cascade_port`

### Stage C

- auto-link parent -> child
- совместить с `Routing`:
  - `action = cascade`
  - `target = child node`

## Что считать готовым

Фича считается рабочей, когда из WebUI на сервере 1 можно:

1. добавить SSH-доступы к серверу 2,
2. нажать deploy,
3. получить живой TT + WebUI на сервере 2,
4. увидеть каскад как готовый hop,
5. использовать его в split rule без ручной правки файлов на сервере.
