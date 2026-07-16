#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=common.sh
source "$SCRIPT_DIR/common.sh"

if launchctl print "gui/$(id -u)/$SING_BOX_LAUNCH_LABEL" >/dev/null 2>&1; then
  echo "VPN service: running"
else
  echo "VPN service: stopped"
fi

if command -v nc >/dev/null 2>&1 && nc -z -w 1 "$VPN_PROXY_HOST" "$VPN_PROXY_PORT" >/dev/null 2>&1; then
  echo "SOCKS proxy: reachable at ${VPN_PROXY_HOST}:${VPN_PROXY_PORT}"
else
  echo "SOCKS proxy: not reachable at ${VPN_PROXY_HOST}:${VPN_PROXY_PORT}"
fi
