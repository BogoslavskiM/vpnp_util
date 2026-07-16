#!/usr/bin/env bash

if [[ -n "${BASH_VERSION:-}" ]]; then
  _vpn_env_script="${BASH_SOURCE[0]}"
  if [[ "$_vpn_env_script" == "$0" ]]; then
    echo "Run: eval \"\$(vpn env)\"" >&2
    exit 2
  fi
elif [[ -n "${ZSH_VERSION:-}" ]]; then
  _vpn_env_script="${(%):-%x}"
  if [[ "$ZSH_EVAL_CONTEXT" != *:file* ]]; then
    echo "Run: eval \"\$(vpn env)\"" >&2
    exit 2
  fi
else
  _vpn_env_script="$0"
fi

SCRIPT_DIR="$(cd "$(dirname "$_vpn_env_script")" && pwd)"
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
: "${VPN_TERMINAL_PROXY_URL:=socks5h://${VPN_PROXY_HOST}:${VPN_PROXY_PORT}}"
: "${NO_PROXY:=localhost,127.0.0.1,::1,.local}"

if command -v nc >/dev/null 2>&1; then
  if ! nc -z -w 2 "$VPN_PROXY_HOST" "$VPN_PROXY_PORT" >/dev/null 2>&1; then
    echo "Warning: VPN proxy is not reachable at ${VPN_PROXY_HOST}:${VPN_PROXY_PORT}" >&2
    echo "Run first: vpn up" >&2
  fi
fi

export VPN_MODE="1"
export ALL_PROXY="$VPN_TERMINAL_PROXY_URL"
export all_proxy="$VPN_TERMINAL_PROXY_URL"
export HTTPS_PROXY="$VPN_TERMINAL_PROXY_URL"
export https_proxy="$VPN_TERMINAL_PROXY_URL"
export HTTP_PROXY="$VPN_TERMINAL_PROXY_URL"
export http_proxy="$VPN_TERMINAL_PROXY_URL"
export NO_PROXY
export no_proxy="$NO_PROXY"
export GIT_SSH_COMMAND="ssh -o ProxyCommand='nc -x ${VPN_PROXY_HOST}:${VPN_PROXY_PORT} -X 5 %h %p'"

echo "VPN environment enabled for this shell."
