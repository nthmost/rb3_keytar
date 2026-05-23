#!/usr/bin/env python3
"""Subscribe to MQTT mood events -> drive SwitchBot RGBIC Neon Light over BLE.

Reads mood events from player/keytar/mood and translates each to a single BLE
command on the SwitchBot light. Latency: ~250-450ms per command.

Env (typically from ~/.config/rb3_keytar/env via run_light.sh):
    MQTT_HOST                  default: homeassistant.local
    MQTT_PORT                  default: 1883
    MQTT_USER                  default: player
    MQTT_PASS                  required
    SWITCHBOT_DEVICE_MAC       required
    SWITCHBOT_KEY_ID           required
    SWITCHBOT_ENCRYPTION_KEY   required
"""
import asyncio
import json
import logging
import os
import sys

import aiomqtt
from bleak import BleakScanner
from switchbot import SwitchbotRgbicNeonLight

MQTT_HOST = os.environ.get("MQTT_HOST", "homeassistant.local")
MQTT_PORT = int(os.environ.get("MQTT_PORT", "1883"))
MQTT_USER = os.environ.get("MQTT_USER", "player")
MQTT_PASS = os.environ.get("MQTT_PASS")
TOPIC_MOOD = "player/keytar/mood"

DEVICE_MAC = os.environ.get("SWITCHBOT_DEVICE_MAC")
KEY_ID = os.environ.get("SWITCHBOT_KEY_ID")
ENC_KEY = os.environ.get("SWITCHBOT_ENCRYPTION_KEY")

logging.basicConfig(level=logging.INFO, format="%(asctime)s %(levelname)s %(message)s")
log = logging.getLogger("mood_to_light")


async def apply_mood(light, mood):
    label = mood.get("label", "?")
    kind = mood.get("kind")
    log.info(f"<- {label}")
    if kind == "solid":
        await light.set_rgb(mood["brightness"], mood["r"], mood["g"], mood["b"])
    elif kind == "effect":
        await light.set_effect(mood["effect"])
    elif kind == "power":
        if mood.get("state") == "off":
            await light.turn_off()
        else:
            await light.turn_on()
    else:
        log.warning(f"unknown mood kind: {kind!r}")


async def main():
    for name, val in [
        ("MQTT_PASS", MQTT_PASS),
        ("SWITCHBOT_DEVICE_MAC", DEVICE_MAC),
        ("SWITCHBOT_KEY_ID", KEY_ID),
        ("SWITCHBOT_ENCRYPTION_KEY", ENC_KEY),
    ]:
        if not val:
            sys.exit(f"missing env var: {name}")

    log.info(f"Scanning BLE for {DEVICE_MAC}...")
    device = await BleakScanner.find_device_by_address(DEVICE_MAC, timeout=15.0)
    if not device:
        sys.exit(f"BLE device {DEVICE_MAC} not found in scan")
    log.info(f"Found {device}")

    light = SwitchbotRgbicNeonLight(
        device=device, key_id=KEY_ID, encryption_key=ENC_KEY
    )

    log.info(f"Connecting to MQTT {MQTT_USER}@{MQTT_HOST}:{MQTT_PORT}")
    async with aiomqtt.Client(
        hostname=MQTT_HOST, port=MQTT_PORT,
        username=MQTT_USER, password=MQTT_PASS,
        identifier="mood-to-light",
    ) as client:
        await client.subscribe(TOPIC_MOOD)
        log.info(f"Subscribed to {TOPIC_MOOD}. Listening...")
        async for msg in client.messages:
            try:
                mood = json.loads(msg.payload)
                await apply_mood(light, mood)
            except Exception as exc:
                log.exception(f"failed to handle {msg.payload!r}: {exc}")


if __name__ == "__main__":
    try:
        asyncio.run(main())
    except KeyboardInterrupt:
        print("\nbye.")
