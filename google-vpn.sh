#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=common.sh
source "$SCRIPT_DIR/common.sh"

find_chrome_app() {
  if [[ -n "${CHROME_APP_PATH:-}" && -d "$CHROME_APP_PATH" ]]; then
    printf '%s\n' "$CHROME_APP_PATH"
    return 0
  fi

  local candidate
  for candidate in \
    "/Applications/Google Chrome.app" \
    "$HOME/Applications/Google Chrome.app"; do
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
    done < <(mdfind "kMDItemCFBundleIdentifier == 'com.google.Chrome'" 2>/dev/null || true)
  fi

  return 1
}

find_app_binary() {
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

if command -v pgrep >/dev/null 2>&1 && pgrep -x "Google Chrome" >/dev/null 2>&1; then
  echo "Google Chrome is already running." >&2
  echo "Quit Chrome first, then run vpn-google again so proxy flags apply to the profile picker." >&2
  exit 6
fi

CHROME_APP="$(find_chrome_app || true)"
if [[ -z "$CHROME_APP" ]]; then
  echo "Google Chrome app was not found." >&2
  echo "Set CHROME_APP_PATH in $CONFIG_FILE, for example:" >&2
  echo '  CHROME_APP_PATH="/Applications/Google Chrome.app"' >&2
  exit 4
fi

CHROME_BIN="$(find_app_binary "$CHROME_APP" || true)"
if [[ -z "$CHROME_BIN" ]]; then
  echo "Google Chrome executable was not found inside: $CHROME_APP" >&2
  exit 5
fi

mkdir -p "$SCRIPT_DIR/runtime"

"$CHROME_BIN" \
  "--proxy-server=$VPN_BROWSER_PROXY" \
  "--proxy-bypass-list=$BROWSER_PROXY_BYPASS_LIST" \
  "--disable-quic" \
  "--dns-prefetch-disable" \
  "--disable-features=AsyncDns,DnsOverHttps" \
  "--no-first-run" \
  "$@" \
  > "$SCRIPT_DIR/runtime/google-vpn.log" 2>&1 &

echo "Google Chrome started through $VPN_BROWSER_PROXY"
echo "  app: $CHROME_APP"
echo "  profile: default Chrome profile"
echo "  log: $SCRIPT_DIR/runtime/google-vpn.log"
