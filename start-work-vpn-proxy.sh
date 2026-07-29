#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=common.sh
source "$SCRIPT_DIR/common.sh"

mkdir -p "$(dirname "$SING_BOX_PID_PATH")"
mkdir -p "$(dirname "$SING_BOX_LAUNCH_PLIST")"

if ! command -v sing-box >/dev/null 2>&1; then
  echo "sing-box is not installed." >&2
  echo "Install sing-box first, then run: vpnp up" >&2
  exit 9
fi

if is_vpn_service_loaded; then
  if is_proxy_reachable; then
    echo "VPN proxy is already running."
    exit 0
  fi

  echo "VPN proxy looks stuck. Restarting it."
  launchctl bootout "gui/$(id -u)" "$SING_BOX_LAUNCH_PLIST" >/dev/null 2>&1 || true
  wait_for_proxy_port_free 10
fi

if proxy_check_available && is_proxy_reachable; then
  echo "Port ${VPN_PROXY_HOST}:${VPN_PROXY_PORT} is already in use." >&2
  echo "Stop the process using it, or change VPN_PROXY_PORT in vpn.env." >&2
  exit 10
fi

config_path="$("$SCRIPT_DIR/make-singbox-config.sh")"
sing_box_bin="$(command -v sing-box)"

xml_escape() {
  printf '%s' "$1" \
    | sed -e 's/&/\&amp;/g' \
          -e 's/</\&lt;/g' \
          -e 's/>/\&gt;/g' \
          -e 's/"/\&quot;/g' \
          -e "s/'/\&apos;/g"
}

cat > "$SING_BOX_LAUNCH_PLIST" <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<plist version="1.0">
<dict>
  <key>Label</key>
  <string>$(xml_escape "$SING_BOX_LAUNCH_LABEL")</string>

  <key>ProgramArguments</key>
  <array>
    <string>$(xml_escape "$sing_box_bin")</string>
    <string>run</string>
    <string>--config</string>
    <string>$(xml_escape "$config_path")</string>
  </array>

  <key>RunAtLoad</key>
  <true/>

  <key>KeepAlive</key>
  <false/>

  <key>StandardOutPath</key>
  <string>$(xml_escape "$SING_BOX_LOG_PATH")</string>

  <key>StandardErrorPath</key>
  <string>$(xml_escape "$SING_BOX_LOG_PATH")</string>
</dict>
</plist>
PLIST

chmod 600 "$SING_BOX_LAUNCH_PLIST"

launchctl bootstrap "gui/$(id -u)" "$SING_BOX_LAUNCH_PLIST"

if ! wait_for_vpn_service; then
  echo "VPN proxy failed to start. Recent log:" >&2
  tail -n 80 "$SING_BOX_LOG_PATH" >&2 || true
  exit 11
fi

if ! wait_for_proxy_ready; then
  echo "VPN proxy started, but the local SOCKS port is not reachable at ${VPN_PROXY_HOST}:${VPN_PROXY_PORT}." >&2
  echo "Recent log:" >&2
  tail -n 80 "$SING_BOX_LOG_PATH" >&2 || true
  exit 12
fi

echo "VPN proxy started."
echo "SOCKS proxy: ${VPN_PROXY_SCHEME}://${VPN_PROXY_HOST}:${VPN_PROXY_PORT}"
