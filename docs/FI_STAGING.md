# FI Staging

FI-сервер используется как первый staging-стенд для TrustTunnel Suite.

## Роль окружения

- `dev` для серверной части WebUI;
- `staging` для end-to-end сценария:
  - создать клиента;
  - сгенерировать `tt://`;
  - показать QR;
  - импортировать в desktop/Android.

## Правила

- секреты не дублируем в документации проекта;
- фактические доступы читаются из [/mnt/d/VPN/access_list.MD](/mnt/d/VPN/access_list.MD);
- self-signed сценарий считаем нежелательным для GUI-клиентов;
- домен и валидный TLS нужны с самого начала MVP.

## Что должно появиться на FI

- TrustTunnel endpoint;
- systemd unit для endpoint;
- WebUI service;
- SQLite data directory для WebUI;
- каталог для backup конфигов и audit data.

## Текущее состояние на 2026-03-28

- TrustTunnel endpoint установлен в `/opt/trusttunnel`
- systemd unit: `trusttunnel.service`
- endpoint слушает `443/tcp` и `443/udp`
- домен `fin.dsinkerii.com` выпущен через Let's Encrypt
- сертификат лежит в `/etc/letsencrypt/live/fin.dsinkerii.com/`
- expiry текущего сертификата: `2026-06-25`

- WebUI развернут в `/opt/trusttunnel-suite/apps/webui`
- systemd unit: `trusttunnel-webui.service`
- SQLite база: `/opt/trusttunnel-suite/apps/webui/data/webui.db`
- WebUI работает в live-режиме против `/opt/trusttunnel`
- source of truth для реального доступа: `/opt/trusttunnel/credentials.toml`
- server-side export использует реальный `trusttunnel_endpoint`

## Актуальная схема доступа

- Endpoint для клиентов: `fin.dsinkerii.com:443`
- WebUI для staging: `http://fin.dsinkerii.com/`

## Ограничение текущей схемы

- внешний `8443` на FI сейчас недоступен, поэтому WebUI временно вынесен на `80/tcp`
- `443` оставлен TrustTunnel endpoint, чтобы desktop/Android могли подключаться по боевой схеме
- из-за этого WebUI staging сейчас без HTTPS
- старый `http://vlaerrrapupkin.linkpc.net/` редиректит на `http://fin.dsinkerii.com/`
- старые VPN-конфиги на `vlaerrrapupkin.linkpc.net` считаем устаревшими

## Что нужно для HTTPS WebUI

- либо отдельный домен/поддомен под панель
- либо отдельный IP
- либо аккуратная интеграция через `reverse_proxy` возможности TrustTunnel на `443`

## Секреты

- пароль WebUI admin хранится только на сервере
- путь: `/root/trusttunnel-secrets/webui-admin-password.txt`
- в репозиторий и документацию сам пароль не дублируем
