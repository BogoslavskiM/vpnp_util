#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CONFIG_FILE="${VPN_SPLIT_CONFIG:-$SCRIPT_DIR/vpn.env}"

if [[ ! -f "$CONFIG_FILE" ]]; then
  echo "VPN is not configured yet." >&2
  echo "Run: vpn update-config /path/to/wireguard.conf" >&2
  return 2 2>/dev/null || exit 2
fi

# shellcheck source=/dev/null
source "$CONFIG_FILE"

: "${VPN_PROXY_SCHEME:=socks5}"
: "${VPN_PROXY_HOST:=127.0.0.1}"
: "${VPN_PROXY_PORT:=1080}"
: "${WG_CONFIG_PATH:=$SCRIPT_DIR/configs/current.conf}"
: "${SING_BOX_CONFIG_PATH:=$SCRIPT_DIR/runtime/sing-box-work.json}"
: "${SING_BOX_LOG_PATH:=$SCRIPT_DIR/runtime/sing-box-work.log}"
: "${SING_BOX_PID_PATH:=$SCRIPT_DIR/runtime/sing-box-work.pid}"
: "${SING_BOX_LAUNCH_LABEL:=local.makar.work-vpn-singbox}"
: "${SING_BOX_LAUNCH_PLIST:=$HOME/Library/LaunchAgents/${SING_BOX_LAUNCH_LABEL}.plist}"
: "${SING_BOX_BOOTSTRAP_DNS_SERVER:=1.1.1.1}"
: "${SING_BOX_WORK_DNS_SERVER:=}"
: "${SING_BOX_ALLOWED_IPS_OVERRIDE:=}"
: "${SING_BOX_BIND_INTERFACE:=en0}"
: "${YANDEX_ROUTE_MODE:=smart}"
: "${VPN_DNS_SUFFIXES:=}"
: "${IP_CHECK_URL:=}"
: "${NO_PROXY:=localhost,127.0.0.1,::1,.local}"
: "${BROWSER_PROXY_BYPASS_LIST:=localhost;127.0.0.1;::1;*.local}"

if [[ -z "${VPN_TERMINAL_PROXY_URL:-}" ]]; then
  if [[ "$VPN_PROXY_SCHEME" == socks* ]]; then
    VPN_TERMINAL_PROXY_URL="${VPN_PROXY_SCHEME}h://${VPN_PROXY_HOST}:${VPN_PROXY_PORT}"
  else
    VPN_TERMINAL_PROXY_URL="${VPN_PROXY_SCHEME}://${VPN_PROXY_HOST}:${VPN_PROXY_PORT}"
  fi
fi

VPN_BROWSER_PROXY="${VPN_PROXY_SCHEME}://${VPN_PROXY_HOST}:${VPN_PROXY_PORT}"

check_proxy() {
  if [[ "${SKIP_PROXY_CHECK:-0}" == "1" ]]; then
    return 0
  fi

  if command -v nc >/dev/null 2>&1; then
    if ! nc -z -w 2 "$VPN_PROXY_HOST" "$VPN_PROXY_PORT" >/dev/null 2>&1; then
      if [[ -n "$IP_CHECK_URL" ]] \
        && command -v curl >/dev/null 2>&1 \
        && curl -fsS --max-time 30 --proxy "$VPN_TERMINAL_PROXY_URL" "$IP_CHECK_URL" >/dev/null 2>&1; then
        return 0
      fi

      echo "Warning: VPN proxy is not reachable at ${VPN_PROXY_HOST}:${VPN_PROXY_PORT}" >&2
      echo "Run: vpn up" >&2
      if [[ "${STRICT_PROXY_CHECK:-0}" == "1" ]]; then
        return 3
      fi
    fi
  fi
}
