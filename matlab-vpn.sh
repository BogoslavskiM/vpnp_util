#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=common.sh
source "$SCRIPT_DIR/common.sh"

find_matlab_app() {
  if [[ -n "${MATLAB_APP_PATH:-}" && -d "$MATLAB_APP_PATH" ]]; then
    printf '%s\n' "$MATLAB_APP_PATH"
    return 0
  fi

  local candidate
  for candidate in /Applications/MATLAB*.app "$HOME"/Applications/MATLAB*.app; do
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
    done < <(mdfind "kMDItemCFBundleIdentifier == 'com.mathworks.matlab'" 2>/dev/null || true)
  fi

  return 1
}

find_matlab_binary_in_app() {
  local app_path="$1"
  local executable=""

  if [[ -x "$app_path/bin/matlab" ]]; then
    printf '%s\n' "$app_path/bin/matlab"
    return 0
  fi

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

find_matlab_binary() {
  if [[ -n "${MATLAB_BIN_PATH:-}" && -x "$MATLAB_BIN_PATH" ]]; then
    printf '%s\n' "$MATLAB_BIN_PATH"
    return 0
  fi

  local app_path
  app_path="$(find_matlab_app || true)"
  if [[ -n "$app_path" ]]; then
    find_matlab_binary_in_app "$app_path"
    return $?
  fi

  if command -v matlab >/dev/null 2>&1; then
    command -v matlab
    return 0
  fi

  return 1
}

proxy_java_options() {
  if [[ "$VPN_PROXY_SCHEME" == socks* ]]; then
    local options=(
      "-DsocksProxyHost=$VPN_PROXY_HOST"
      "-DsocksProxyPort=$VPN_PROXY_PORT"
    )
  else
    local options=(
      "-Dhttp.proxyHost=$VPN_PROXY_HOST"
      "-Dhttp.proxyPort=$VPN_PROXY_PORT"
      "-Dhttps.proxyHost=$VPN_PROXY_HOST"
      "-Dhttps.proxyPort=$VPN_PROXY_PORT"
    )
  fi

  printf '%s ' "${options[@]}"
}

check_proxy

MATLAB_BIN="$(find_matlab_binary || true)"
if [[ -z "$MATLAB_BIN" ]]; then
  echo "MATLAB executable was not found." >&2
  echo "Set MATLAB_APP_PATH or MATLAB_BIN_PATH in vpn.env if MATLAB is installed elsewhere." >&2
  exit 4
fi

mkdir -p "$SCRIPT_DIR/runtime"

export VPN_MODE="1"
export ALL_PROXY="$VPN_TERMINAL_PROXY_URL"
export all_proxy="$VPN_TERMINAL_PROXY_URL"
export HTTPS_PROXY="$VPN_TERMINAL_PROXY_URL"
export https_proxy="$VPN_TERMINAL_PROXY_URL"
export HTTP_PROXY="$VPN_TERMINAL_PROXY_URL"
export http_proxy="$VPN_TERMINAL_PROXY_URL"
export NO_PROXY
export no_proxy="$NO_PROXY"

JAVA_PROXY_OPTIONS="$(proxy_java_options)"
export JAVA_TOOL_OPTIONS="${JAVA_TOOL_OPTIONS:-} ${JAVA_PROXY_OPTIONS}"

if [[ "$#" -eq 0 || "${MATLAB_BACKGROUND:-0}" == "1" ]]; then
  "$MATLAB_BIN" "$@" > "$SCRIPT_DIR/runtime/matlab-vpn.log" 2>&1 &
  echo "MATLAB started through VPN proxy."
  echo "Log: $SCRIPT_DIR/runtime/matlab-vpn.log"
else
  exec "$MATLAB_BIN" "$@"
fi
