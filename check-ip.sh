#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=common.sh
source "$SCRIPT_DIR/common.sh"

if [[ -z "$IP_CHECK_URL" ]]; then
  echo "IP_CHECK_URL is not configured in $CONFIG_FILE" >&2
  exit 2
fi

echo "Direct IP:"
curl -fsS "$IP_CHECK_URL" || true
echo
echo

echo "Proxy/VPN IP:"
curl -fsS --proxy "$VPN_TERMINAL_PROXY_URL" "$IP_CHECK_URL"
echo
