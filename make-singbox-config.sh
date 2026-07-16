#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=common.sh
source "$SCRIPT_DIR/common.sh"

if [[ ! -f "$WG_CONFIG_PATH" ]]; then
  echo "WireGuard config not found: $WG_CONFIG_PATH" >&2
  exit 6
fi

mkdir -p "$(dirname "$SING_BOX_CONFIG_PATH")"

read_wg_value() {
  local section="$1"
  local key="$2"
  awk -v want_section="$section" -v want_key="$key" '
    function trim(s) {
      sub(/^[ \t\r\n]+/, "", s)
      sub(/[ \t\r\n]+$/, "", s)
      return s
    }
    /^[ \t]*#/ { next }
    /^[ \t]*;/ { next }
    /^[ \t]*\[/ {
      current=$0
      gsub(/^[ \t]*\[/, "", current)
      gsub(/\][ \t]*$/, "", current)
      next
    }
    index($0, "=") > 0 {
      k=trim(substr($0, 1, index($0, "=") - 1))
      v=trim(substr($0, index($0, "=") + 1))
      sub(/[ \t]+[#;].*$/, "", v)
      if (current == want_section && k == want_key) {
        print trim(v)
        exit
      }
    }
  ' "$WG_CONFIG_PATH"
}

json_string_array_from_csv() {
  local raw="$1"
  local normalize_prefix="${2:-0}"
  local IFS=","
  local item
  local out="["
  local first=1

  for item in $raw; do
    item="${item#"${item%%[![:space:]]*}"}"
    item="${item%"${item##*[![:space:]]}"}"
    [[ -z "$item" ]] && continue
    if [[ "$normalize_prefix" == "1" && "$item" != */* ]]; then
      if [[ "$item" == *:* ]]; then
        item="${item}/128"
      else
        item="${item}/32"
      fi
    fi
    if [[ "$first" -eq 0 ]]; then
      out+=", "
    fi
    out+="\"$item\""
    first=0
  done

  out+="]"
  printf '%s\n' "$out"
}

first_csv_item() {
  local raw="$1"
  local item="${raw%%,*}"
  item="${item#"${item%%[![:space:]]*}"}"
  item="${item%"${item##*[![:space:]]}"}"
  printf '%s\n' "$item"
}

json_suffix_array_from_csv() {
  local raw="$1"
  local IFS=","
  local item
  local out="["
  local first=1

  for item in $raw; do
    item="${item#"${item%%[![:space:]]*}"}"
    item="${item%"${item##*[![:space:]]}"}"
    [[ -z "$item" ]] && continue
    if [[ "$item" != .* ]]; then
      item=".$item"
    fi
    if [[ "$first" -eq 0 ]]; then
      out+=", "
    fi
    out+="\"$item\""
    first=0
  done

  out+="]"
  printf '%s\n' "$out"
}

PRIVATE_KEY="$(read_wg_value Interface PrivateKey)"
ADDRESS="$(read_wg_value Interface Address)"
PEER_PUBLIC_KEY="$(read_wg_value Peer PublicKey)"
PRESHARED_KEY="$(read_wg_value Peer PresharedKey || true)"
ALLOWED_IPS="${SING_BOX_ALLOWED_IPS_OVERRIDE:-$(read_wg_value Peer AllowedIPs)}"
ENDPOINT="$(read_wg_value Peer Endpoint)"
MTU="$(read_wg_value Interface MTU || true)"
PERSISTENT_KEEPALIVE="$(read_wg_value Peer PersistentKeepalive || true)"
WG_DNS="$(read_wg_value Interface DNS || true)"

if [[ -z "$PRIVATE_KEY" || -z "$ADDRESS" || -z "$PEER_PUBLIC_KEY" || -z "$ALLOWED_IPS" || -z "$ENDPOINT" ]]; then
  echo "WireGuard config is missing one of: PrivateKey, Address, PublicKey, AllowedIPs, Endpoint" >&2
  exit 7
fi

if [[ "$ENDPOINT" =~ ^\[([^]]+)\]:([0-9]+)$ ]]; then
  WG_SERVER="${BASH_REMATCH[1]}"
  WG_SERVER_PORT="${BASH_REMATCH[2]}"
else
  WG_SERVER="${ENDPOINT%:*}"
  WG_SERVER_PORT="${ENDPOINT##*:}"
fi

if [[ -z "$WG_SERVER" || -z "$WG_SERVER_PORT" || ! "$WG_SERVER_PORT" =~ ^[0-9]+$ ]]; then
  echo "Cannot parse WireGuard Endpoint: $ENDPOINT" >&2
  exit 8
fi

LOCAL_ADDRESS_JSON="$(json_string_array_from_csv "$ADDRESS" 1)"
ALLOWED_IPS_JSON="$(json_string_array_from_csv "$ALLOWED_IPS" 1)"
VPN_DNS_SUFFIXES_JSON="$(json_suffix_array_from_csv "$VPN_DNS_SUFFIXES")"
MTU="${MTU:-1408}"
WORK_DNS_SERVER="${SING_BOX_WORK_DNS_SERVER:-$(first_csv_item "$WG_DNS")}"
if [[ -z "$WORK_DNS_SERVER" ]]; then
  WORK_DNS_SERVER="$SING_BOX_BOOTSTRAP_DNS_SERVER"
fi
DEFAULT_DNS_TAG="bootstrap-dns"
if [[ "$YANDEX_ROUTE_MODE" == "full" ]]; then
  DEFAULT_DNS_TAG="work-dns"
fi

umask 077
{
  cat <<JSON
{
  "log": {
    "level": "info",
    "timestamp": true
  },
  "dns": {
    "servers": [
      {
        "type": "udp",
        "tag": "bootstrap-dns",
        "server": "$SING_BOX_BOOTSTRAP_DNS_SERVER",
        "detour": "direct",
        "server_port": 53
      },
      {
        "type": "udp",
        "tag": "work-dns",
        "server": "$WORK_DNS_SERVER",
        "detour": "work-wg",
        "server_port": 53
      }
    ],
    "rules": [
JSON

  if [[ "$VPN_DNS_SUFFIXES_JSON" != "[]" ]]; then
    cat <<JSON
      {
        "domain_suffix": $VPN_DNS_SUFFIXES_JSON,
        "action": "route",
        "server": "work-dns",
        "strategy": "ipv4_only"
      },
JSON
  fi

  cat <<JSON
      {
        "action": "route",
        "server": "$DEFAULT_DNS_TAG",
        "strategy": "ipv4_only"
      }
    ],
    "final": "$DEFAULT_DNS_TAG"
  },
  "inbounds": [
    {
      "type": "socks",
      "tag": "socks-in",
      "listen": "$VPN_PROXY_HOST",
      "listen_port": $VPN_PROXY_PORT
    }
  ],
  "outbounds": [
    {
      "type": "direct",
      "tag": "direct",
      "bind_interface": "$SING_BOX_BIND_INTERFACE",
      "domain_resolver": "bootstrap-dns"
    }
  ],
  "endpoints": [
    {
      "type": "wireguard",
      "tag": "work-wg",
      "system": false,
      "mtu": $MTU,
      "address": $LOCAL_ADDRESS_JSON,
      "private_key": "$PRIVATE_KEY",
      "domain_resolver": "bootstrap-dns",
      "bind_interface": "$SING_BOX_BIND_INTERFACE",
      "peers": [
        {
          "address": "$WG_SERVER",
          "port": $WG_SERVER_PORT,
          "public_key": "$PEER_PUBLIC_KEY",
JSON

  if [[ -n "$PRESHARED_KEY" ]]; then
    printf '          "pre_shared_key": "%s",\n' "$PRESHARED_KEY"
  fi

  if [[ -n "$PERSISTENT_KEEPALIVE" && "$PERSISTENT_KEEPALIVE" =~ ^[0-9]+$ ]]; then
    printf '          "persistent_keepalive_interval": %s,\n' "$PERSISTENT_KEEPALIVE"
  fi

  cat <<JSON
          "allowed_ips": $ALLOWED_IPS_JSON
        }
      ]
    }
  ],
  "route": {
    "default_domain_resolver": "$DEFAULT_DNS_TAG",
    "rules": [
JSON

  if [[ "$YANDEX_ROUTE_MODE" == "full" ]]; then
    cat <<JSON
      {
        "inbound": "socks-in",
        "action": "route",
        "outbound": "work-wg"
      }
JSON
  else
    if [[ "$VPN_DNS_SUFFIXES_JSON" != "[]" ]]; then
      cat <<JSON
      {
        "inbound": "socks-in",
        "domain_suffix": $VPN_DNS_SUFFIXES_JSON,
        "action": "resolve",
        "server": "work-dns",
        "strategy": "ipv4_only"
      },
      {
        "inbound": "socks-in",
        "domain_suffix": $VPN_DNS_SUFFIXES_JSON,
        "action": "route",
        "outbound": "work-wg"
      },
JSON
    fi

    cat <<JSON
      {
        "inbound": "socks-in",
        "ip_is_private": true,
        "action": "route",
        "outbound": "work-wg"
      },
      {
        "inbound": "socks-in",
        "action": "route",
        "outbound": "direct"
      }
JSON
  fi

  cat <<JSON
    ],
    "final": "$([[ "$YANDEX_ROUTE_MODE" == "full" ]] && printf 'work-wg' || printf 'direct')"
  }
}
JSON
} > "$SING_BOX_CONFIG_PATH"

chmod 600 "$SING_BOX_CONFIG_PATH"
echo "$SING_BOX_CONFIG_PATH"
