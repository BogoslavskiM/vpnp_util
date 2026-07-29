#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=common.sh
source "$SCRIPT_DIR/common.sh"
# shellcheck source=matlab-common.sh
source "$SCRIPT_DIR/matlab-common.sh"

append_java_proxy_options() {
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

  if [[ -n "${JAVA_TOOL_OPTIONS:-}" ]]; then
    export JAVA_TOOL_OPTIONS="$JAVA_TOOL_OPTIONS ${options[*]}"
  else
    export JAVA_TOOL_OPTIONS="${options[*]}"
  fi
}

check_proxy

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

if [[ "${MATLAB_JAVA_PROXY:-0}" == "1" ]]; then
  append_java_proxy_options
fi

if [[ "$#" -eq 0 ]]; then
  MATLAB_APP="$(find_matlab_gui_app || true)"
  if [[ -z "$MATLAB_APP" ]]; then
    echo "MATLAB app was not found." >&2
    echo "Set MATLAB_APP_PATH in vpn.env if MATLAB is installed elsewhere." >&2
    exit 4
  fi
  MATLAB_EXECUTABLE="$(find_matlab_binary_in_app "$MATLAB_APP" || true)"
  if [[ -z "$MATLAB_EXECUTABLE" ]]; then
    echo "MATLAB app executable was not found." >&2
    exit 4
  fi
  MATLAB_PROCESS_NAME="$(basename "$MATLAB_EXECUTABLE")"
  MATLAB_PROCESS_COUNT_BEFORE="$(process_count "$MATLAB_PROCESS_NAME" "$MATLAB_EXECUTABLE")"

  open_env_args=(
    --env "VPN_MODE=1"
    --env "ALL_PROXY=$ALL_PROXY"
    --env "all_proxy=$all_proxy"
    --env "HTTPS_PROXY=$HTTPS_PROXY"
    --env "https_proxy=$https_proxy"
    --env "HTTP_PROXY=$HTTP_PROXY"
    --env "http_proxy=$http_proxy"
    --env "NO_PROXY=$NO_PROXY"
    --env "no_proxy=$no_proxy"
  )

  if [[ -n "${JAVA_TOOL_OPTIONS:-}" ]]; then
    open_env_args+=(--env "JAVA_TOOL_OPTIONS=$JAVA_TOOL_OPTIONS")
  fi

  open -n \
    --stdout "$SCRIPT_DIR/runtime/matlab-vpn.log" \
    --stderr "$SCRIPT_DIR/runtime/matlab-vpn.log" \
    "${open_env_args[@]}" \
    "$MATLAB_APP"

  if ! wait_for_new_process_stable \
    "$MATLAB_PROCESS_NAME" "$MATLAB_PROCESS_COUNT_BEFORE" "MATLAB" 5 "$VPN_POLL_TIMEOUT" "$MATLAB_EXECUTABLE"; then
    echo "MATLAB did not finish launching. Recent log:" >&2
    tail -n 80 "$SCRIPT_DIR/runtime/matlab-vpn.log" >&2 || true
    exit 7
  fi

  echo "MATLAB started through VPN proxy."
  echo "Log: $SCRIPT_DIR/runtime/matlab-vpn.log"
elif [[ "${MATLAB_BACKGROUND:-0}" == "1" ]]; then
  MATLAB_BIN="$(find_matlab_binary || true)"
  if [[ -z "$MATLAB_BIN" ]]; then
    echo "MATLAB executable was not found." >&2
    echo "Set MATLAB_APP_PATH or MATLAB_BIN_PATH in vpn.env if MATLAB is installed elsewhere." >&2
    exit 4
  fi

  "$MATLAB_BIN" "$@" > "$SCRIPT_DIR/runtime/matlab-vpn.log" 2>&1 &
  matlab_pid="$!"
  if ! wait_for_pid_stable "$matlab_pid" "MATLAB" 5; then
    echo "MATLAB did not finish launching. Recent log:" >&2
    tail -n 80 "$SCRIPT_DIR/runtime/matlab-vpn.log" >&2 || true
    exit 7
  fi

  echo "MATLAB started through VPN proxy."
  echo "Log: $SCRIPT_DIR/runtime/matlab-vpn.log"
else
  MATLAB_BIN="$(find_matlab_binary || true)"
  if [[ -z "$MATLAB_BIN" ]]; then
    echo "MATLAB executable was not found." >&2
    echo "Set MATLAB_APP_PATH or MATLAB_BIN_PATH in vpn.env if MATLAB is installed elsewhere." >&2
    exit 4
  fi

  exec "$MATLAB_BIN" "$@"
fi
