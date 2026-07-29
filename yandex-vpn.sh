#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=common.sh
source "$SCRIPT_DIR/common.sh"

find_yandex_app() {
  if [[ -n "${YANDEX_APP_PATH:-}" && -d "$YANDEX_APP_PATH" ]]; then
    printf '%s\n' "$YANDEX_APP_PATH"
    return 0
  fi

  local candidate
  for candidate in \
    "/Applications/Yandex.app" \
    "/Applications/Yandex Browser.app" \
    "$HOME/Applications/Yandex.app" \
    "$HOME/Applications/Yandex Browser.app"; do
    if [[ -d "$candidate" ]]; then
      printf '%s\n' "$candidate"
      return 0
    fi
  done

  if command -v mdfind >/dev/null 2>&1; then
    while IFS= read -r candidate; do
      if [[ -d "$candidate" ]]; then
        printf '%s\n' "$candidate"
        return 0
      fi
    done < <(mdfind "kMDItemCFBundleIdentifier == 'ru.yandex.desktop.yandex-browser'" 2>/dev/null || true)
  fi

  return 1
}

find_yandex_binary() {
  local app_path="$1"
  local executable=""

  if command -v plutil >/dev/null 2>&1; then
    executable="$(plutil -extract CFBundleExecutable raw -o - "$app_path/Contents/Info.plist" 2>/dev/null || true)"
  fi

  if [[ -n "$executable" && -x "$app_path/Contents/MacOS/$executable" ]]; then
    printf '%s\n' "$app_path/Contents/MacOS/$executable"
    return 0
  fi

  local candidate
  for candidate in "$app_path"/Contents/MacOS/*; do
    if [[ -x "$candidate" && ! -d "$candidate" ]]; then
      printf '%s\n' "$candidate"
      return 0
    fi
  done

  return 1
}

check_proxy

YANDEX_APP="$(find_yandex_app || true)"
if [[ -z "$YANDEX_APP" ]]; then
  echo "Yandex Browser app was not found." >&2
  echo "Set YANDEX_APP_PATH in vpn.env if Yandex Browser is installed elsewhere." >&2
  exit 4
fi

YANDEX_BIN="$(find_yandex_binary "$YANDEX_APP" || true)"
if [[ -z "$YANDEX_BIN" ]]; then
  echo "Yandex Browser executable was not found." >&2
  exit 5
fi

mkdir -p "$SCRIPT_DIR/runtime"

"$YANDEX_BIN" \
  "--proxy-server=$VPN_BROWSER_PROXY" \
  "--proxy-bypass-list=$BROWSER_PROXY_BYPASS_LIST" \
  "--disable-quic" \
  "--dns-prefetch-disable" \
  "--disable-features=AsyncDns,DnsOverHttps" \
  "--no-first-run" \
  "$@" \
  > "$SCRIPT_DIR/runtime/yandex-vpn.log" 2>&1 &

YANDEX_PROCESS_NAME="$(basename "$YANDEX_BIN")"
if ! wait_for_process "$YANDEX_PROCESS_NAME"; then
  echo "Yandex Browser did not finish launching. Recent log:" >&2
  tail -n 80 "$SCRIPT_DIR/runtime/yandex-vpn.log" >&2 || true
  exit 7
fi

echo "Yandex Browser started through VPN proxy."
echo "Profile: default Yandex profile"
