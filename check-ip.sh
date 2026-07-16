#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=common.sh
source "$SCRIPT_DIR/common.sh"

if [[ -z "$IP_CHECK_URL" ]]; then
  echo "IP check is not configured." >&2
  echo "Set IP_CHECK_URL in vpn.env, then run: vpnp ip" >&2
  exit 2
fi

echo "Direct connection:"
curl -fsS "$IP_CHECK_URL" || true
echo
echo

echo "VPN proxy connection:"
curl -fsS --proxy "$VPN_TERMINAL_PROXY_URL" "$IP_CHECK_URL"
echo
