#!/usr/bin/env bash

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

find_matlab_cli_binary_in_app() {
  local app_path="$1"

  if [[ -x "$app_path/bin/matlab" ]]; then
    printf '%s\n' "$app_path/bin/matlab"
    return 0
  fi

  find_matlab_binary_in_app "$app_path"
}

find_matlab_binary() {
  if [[ -n "${MATLAB_BIN_PATH:-}" && -x "$MATLAB_BIN_PATH" ]]; then
    printf '%s\n' "$MATLAB_BIN_PATH"
    return 0
  fi

  local app_path
  app_path="$(find_matlab_app || true)"
  if [[ -n "$app_path" ]]; then
    find_matlab_cli_binary_in_app "$app_path"
    return $?
  fi

  if command -v matlab >/dev/null 2>&1; then
    command -v matlab
    return 0
  fi

  return 1
}

find_matlab_gui_app() {
  find_matlab_app
}

matlab_gui_executable() {
  local app_path
  app_path="$(find_matlab_gui_app || true)"
  [[ -n "$app_path" ]] || return 1
  find_matlab_binary_in_app "$app_path"
}

matlab_gui_is_running() {
  local executable
  executable="$(matlab_gui_executable || true)"
  [[ -n "$executable" ]] || return 1

  command -v lsof >/dev/null 2>&1 \
    && lsof -t "$executable" 2>/dev/null | read -r _
}
