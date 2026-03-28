#!/usr/bin/env bash
set -euo pipefail

cd /mnt/d/VPN/trusttunnel-suite/apps/webui
source /mnt/d/VPN/tools/go-env.sh
go run ./cmd/webui
