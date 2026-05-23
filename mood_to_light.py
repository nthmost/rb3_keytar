#!/usr/bin/env python3
"""Subscribe to MQTT mood events -> drive SwitchBot RGBIC Neon Light over BLE.

Keeps a continuous BleakScanner running so the device reference stays fresh —
BLE peripherals drop in/out of advertising windows and a one-shot scan handle
goes stale within a minute or two. Each new advertisement updates the
SwitchBot light's internal device reference so subsequent commands use the
latest connection.

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


class LightController:
    """Wraps a SwitchbotRgbicNeonLight with a continuous BLE scanner that
    refreshes the device handle whenever we see a new advertisement."""

    def __init__(self, mac, key_id, enc_key):
        self.mac = mac.lower()
        self.key_id = key_id
        self.enc_key = enc_key
        self._device = None
        self._light = None
        self._scanner = None
        self._first_seen = asyncio.Event()

    def _on_advertisement(self, device, adv_data):
        if device.address.lower() != self.mac:
            return
        self._device = device
        if self._light is not None:
            # Swap in the fresh BLE device so the next command uses it.
            # pySwitchbot stores it as `_device` — internal attribute but
            # stable across versions.
            self._light._device = device
        if not self._first_seen.is_set():
            self._first_seen.set()

    async def start(self):
        self._scanner = BleakScanner(detection_callback=self._on_advertisement)
        await self._scanner.start()
        log.info(f"BLE: continuous scanner started, waiting for {self.mac}...")
        try:
            await asyncio.wait_for(self._first_seen.wait(), timeout=20.0)
        except asyncio.TimeoutError:
            await self._scanner.stop()
            raise RuntimeError(f"Did not see {self.mac} on BLE within 20s")
        log.info(f"BLE: locked on {self._device}")
        self._light = SwitchbotRgbicNeonLight(
            device=self._device, key_id=self.key_id, encryption_key=self.enc_key
        )

    async def stop(self):
        if self._scanner:
            try:
                await self._scanner.stop()
            except Exception:
                pass

    async def apply(self, mood):
        kind = mood.get("kind")
        if kind == "solid":
            await self._light.set_rgb(mood["brightness"], mood["r"], mood["g"], mood["b"])
        elif kind == "effect":
            await self._light.set_effect(mood["effect"])
        elif kind == "power":
            if mood.get("state") == "off":
                await self._light.turn_off()
            else:
                await self._light.turn_on()
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

    controller = LightController(DEVICE_MAC, KEY_ID, ENC_KEY)
    await controller.start()

    log.info(f"Connecting to MQTT {MQTT_USER}@{MQTT_HOST}:{MQTT_PORT}")
    try:
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
                    log.info(f"<- {mood.get('label', '?')}")
                    await controller.apply(mood)
                except Exception as exc:
                    log.warning(f"command failed ({mood.get('label','?')}): {exc}")
    finally:
        await controller.stop()


if __name__ == "__main__":
    try:
        asyncio.run(main())
    except KeyboardInterrupt:
        print("\nbye.")
