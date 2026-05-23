#!/bin/bash
# Wrapper: subscribe to MQTT mood events -> drive SwitchBot light over BLE.
# Reads MQTT + SWITCHBOT_* from ~/.config/rb3_keytar/env.
#
# Linux:  ./run_light.sh
set -e
cd "$(dirname "$0")"

CONFIG="${RB3_KEYTAR_ENV:-$HOME/.config/rb3_keytar/env}"
if [ -f "$CONFIG" ]; then
    set -a
    . "$CONFIG"
    set +a
fi

for v in MQTT_PASS SWITCHBOT_DEVICE_MAC SWITCHBOT_KEY_ID SWITCHBOT_ENCRYPTION_KEY; do
    if [ -z "${!v}" ]; then
        echo "$v not set in $CONFIG" >&2
        exit 1
    fi
done

exec .venv/bin/python mood_to_light.py
