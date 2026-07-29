#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CONFIG_FILE="${VPN_SPLIT_CONFIG:-$SCRIPT_DIR/vpn.env}"

if [[ ! -f "$CONFIG_FILE" ]]; then
  echo "VPN is not configured yet." >&2
  echo "Run: vpnp update-config /path/to/wireguard.conf" >&2
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
: "${VPN_POLL_TIMEOUT:=30}"
: "${VPN_POLL_INTERVAL:=1}"

if [[ -z "${VPN_TERMINAL_PROXY_URL:-}" ]]; then
  if [[ "$VPN_PROXY_SCHEME" == socks* ]]; then
    VPN_TERMINAL_PROXY_URL="${VPN_PROXY_SCHEME}h://${VPN_PROXY_HOST}:${VPN_PROXY_PORT}"
  else
    VPN_TERMINAL_PROXY_URL="${VPN_PROXY_SCHEME}://${VPN_PROXY_HOST}:${VPN_PROXY_PORT}"
  fi
fi

VPN_BROWSER_PROXY="${VPN_PROXY_SCHEME}://${VPN_PROXY_HOST}:${VPN_PROXY_PORT}"

is_vpn_service_loaded() {
  launchctl print "gui/$(id -u)/$SING_BOX_LAUNCH_LABEL" >/dev/null 2>&1
}

is_proxy_reachable() {
  command -v nc >/dev/null 2>&1 && nc -z -w 1 "$VPN_PROXY_HOST" "$VPN_PROXY_PORT" >/dev/null 2>&1
}

poll_until() {
  local message="$1"
  local timeout="${2:-$VPN_POLL_TIMEOUT}"
  shift 2

  local started_at
  local now
  started_at="$(date +%s)"

  printf '%s' "$message" >&2
  while true; do
    if "$@"; then
      printf ' done\n' >&2
      return 0
    fi

    now="$(date +%s)"
    if ((now - started_at >= timeout)); then
      printf ' timeout\n' >&2
      return 1
    fi

    printf '.' >&2
    sleep "$VPN_POLL_INTERVAL"
  done
}

wait_for_vpn_service() {
  poll_until "Waiting for VPN service" "${1:-$VPN_POLL_TIMEOUT}" is_vpn_service_loaded
}

wait_for_proxy_ready() {
  if command -v nc >/dev/null 2>&1; then
    poll_until "Waiting for SOCKS proxy at ${VPN_PROXY_HOST}:${VPN_PROXY_PORT}" "${1:-$VPN_POLL_TIMEOUT}" is_proxy_reachable
  fi
}

wait_for_proxy_port_free() {
  if command -v nc >/dev/null 2>&1; then
    poll_until "Waiting for SOCKS port ${VPN_PROXY_HOST}:${VPN_PROXY_PORT} to be released" "${1:-$VPN_POLL_TIMEOUT}" proxy_port_is_free
  fi
}

proxy_port_is_free() {
  ! is_proxy_reachable
}

process_is_running() {
  local process_name="$1"
  command -v pgrep >/dev/null 2>&1 && pgrep -x "$process_name" >/dev/null 2>&1
}

wait_for_process() {
  local process_name="$1"
  if ! command -v pgrep >/dev/null 2>&1; then
    return 0
  fi

  poll_until "Waiting for $process_name to launch" "${2:-$VPN_POLL_TIMEOUT}" process_is_running "$process_name"
}

pid_is_running() {
  local pid="$1"
  kill -0 "$pid" >/dev/null 2>&1
}

wait_for_pid() {
  local pid="$1"
  local label="${2:-process}"
  poll_until "Waiting for $label to launch" "${3:-$VPN_POLL_TIMEOUT}" pid_is_running "$pid"
}

check_proxy() {
  if [[ "${SKIP_PROXY_CHECK:-0}" == "1" ]]; then
    return 0
  fi

  if command -v nc >/dev/null 2>&1; then
    if ! is_proxy_reachable; then
      if [[ -n "$IP_CHECK_URL" ]] \
        && command -v curl >/dev/null 2>&1 \
        && curl -fsS --max-time 30 --proxy "$VPN_TERMINAL_PROXY_URL" "$IP_CHECK_URL" >/dev/null 2>&1; then
        return 0
      fi

      echo "Warning: VPN proxy is not reachable at ${VPN_PROXY_HOST}:${VPN_PROXY_PORT}" >&2
      echo "Run: vpnp up" >&2
      if [[ "${STRICT_PROXY_CHECK:-0}" == "1" ]]; then
        return 3
      fi
    fi
  fi
}
