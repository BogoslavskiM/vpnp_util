# VPN helpers for Yandex and terminal workflows.

_vpn_dir="${${(%):-%x}:A:h}"

vpn-up() {
  "$_vpn_dir/start-work-vpn-proxy.sh"
}

vpn-down() {
  "$_vpn_dir/stop-work-vpn-proxy.sh"
}

vpn-status() {
  "$_vpn_dir/status-work-vpn-proxy.sh"
}

vpn-ip() {
  "$_vpn_dir/check-ip.sh"
}

vpn-shell() {
  "$_vpn_dir/vpnp" shell
}

vpn-log() {
  tail -n "${1:-80}" "$_vpn_dir/runtime/sing-box-work.log"
}

vpn-yandex() {
  "$_vpn_dir/start-work-vpn-proxy.sh" >/dev/null
  "$_vpn_dir/yandex-vpn.sh" "$@"
}

vpn-google() {
  "$_vpn_dir/start-work-vpn-proxy.sh" >/dev/null
  "$_vpn_dir/google-vpn.sh" "$@"
}

update_config() {
  "$_vpn_dir/update_config" "$@"
}

vpn-help() {
  cat <<'EOF'
VPN commands:
  vpn-up       start local VPN/SOCKS proxy
  vpn-down     stop local VPN/SOCKS proxy
  vpn-status   show proxy status
  vpn-ip       show direct/proxy IP check
  vpn-shell    open a terminal shell through VPN proxy

  vpn-log      tail sing-box log, default 80 lines
  vpn-yandex   open Yandex via VPN routing
  vpn-google   open Google Chrome via VPN routing
  vpnp update-config copy WireGuard config into this project
  vpnp uninstall remove global vpnp command

Examples:
  vpn-yandex
  vpn-google
  vpn-yandex <url>
  vpn-google <url>
  vpn-shell
  vpnp update-config ~/Downloads/work-vpn.conf
  vpnp uninstall
EOF
}
