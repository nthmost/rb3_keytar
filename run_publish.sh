#!/bin/bash
# Wrapper: run publish_player.py with the env it needs.
#
# Reads MQTT_PASS (and any other overrides) from ~/.config/rb3_keytar/env
# if that file exists. Format is plain `KEY=value` lines.
#
# Usage on Linux (with udev rule from sbin/99-rb3-keytar.rules installed):
#     ./run_publish.sh
# Usage on macOS (no udev equivalent, needs sudo for USB HID):
#     sudo -E ./run_publish.sh
set -e
cd "$(dirname "$0")"

CONFIG="${RB3_KEYTAR_ENV:-$HOME/.config/rb3_keytar/env}"
if [ -f "$CONFIG" ]; then
    set -a
    . "$CONFIG"
    set +a
fi

export DYLD_LIBRARY_PATH="${DYLD_LIBRARY_PATH:-/opt/homebrew/lib}"

if [ -z "$MQTT_PASS" ]; then
    echo "MQTT_PASS not set. Put it in $CONFIG or export it before running." >&2
    exit 1
fi

exec .venv/bin/python publish_player.py
