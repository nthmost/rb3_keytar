#!/bin/bash
# Wrapper: read keytar, publish mood events to MQTT.
# Reads MQTT_PASS (and any overrides) from ~/.config/rb3_keytar/env.
#
# Linux (with udev rule):  ./run_mood.sh
# macOS:                   sudo -E ./run_mood.sh
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

exec .venv/bin/python publish_mood.py
