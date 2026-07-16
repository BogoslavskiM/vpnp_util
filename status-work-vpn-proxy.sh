#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=common.sh
source "$SCRIPT_DIR/common.sh"

if launchctl print "gui/$(id -u)/$SING_BOX_LAUNCH_LABEL" >/dev/null 2>&1; then
  echo "loaded: $SING_BOX_LAUNCH_LABEL"
else
  echo "not loaded"
fi

if command -v nc >/dev/null 2>&1 && nc -z -w 1 "$VPN_PROXY_HOST" "$VPN_PROXY_PORT" >/dev/null 2>&1; then
  echo "proxy port: reachable at ${VPN_PROXY_HOST}:${VPN_PROXY_PORT}"
else
  echo "proxy port: not reachable at ${VPN_PROXY_HOST}:${VPN_PROXY_PORT}"
fi
