#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=common.sh
source "$SCRIPT_DIR/common.sh"

if ! launchctl print "gui/$(id -u)/$SING_BOX_LAUNCH_LABEL" >/dev/null 2>&1; then
  echo "Work VPN proxy is not running"
  exit 0
fi

launchctl bootout "gui/$(id -u)" "$SING_BOX_LAUNCH_PLIST"
echo "Stopped work VPN proxy: $SING_BOX_LAUNCH_LABEL"
