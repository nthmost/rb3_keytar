#!/usr/bin/env python3
"""Read keytar chords -> publish stable chords to MQTT.

Default: publishes directly to mosquitto on homeassistant.local using shared
community user `nb`/`nb` (ACL-restricted to topic prefix `nb/#`).

Run:
    sudo .venv/bin/python play_chords.py

Env overrides:
    MQTT_HOST       default: homeassistant.local
    MQTT_PORT       default: 1883
    MQTT_USER       default: nb
    MQTT_PASS       default: nb
    MQTT_TOPIC      default: nb/keytar/chords
    HOLD_TIME       default: 0.2 (seconds chord must be stable)
"""
import json
import os
import sys
import time

import usb.core
import paho.mqtt.client as mqtt

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from rb3keytar import RB3Keytar
from chord_detector import ChordDetector

MQTT_HOST = os.environ.get("MQTT_HOST", "homeassistant.local")
MQTT_PORT = int(os.environ.get("MQTT_PORT", "1883"))
MQTT_USER = os.environ.get("MQTT_USER", "nb")
MQTT_PASS = os.environ.get("MQTT_PASS", "nb")
MQTT_TOPIC = os.environ.get("MQTT_TOPIC", "nb/keytar/chords")
HOLD_TIME = float(os.environ.get("HOLD_TIME", "0.2"))


def main():
    client = mqtt.Client(mqtt.CallbackAPIVersion.VERSION2, client_id="rb3-keytar")
    client.username_pw_set(MQTT_USER, MQTT_PASS)
    client.connect(MQTT_HOST, MQTT_PORT, keepalive=60)
    client.loop_start()
    print(f"MQTT: {MQTT_USER}@{MQTT_HOST}:{MQTT_PORT}  topic={MQTT_TOPIC}")

    keytar = RB3Keytar()
    keytar.connect()
    print(f"Keytar connected. Hold chords for {HOLD_TIME}s to publish. Ctrl+C to quit.")

    detector = ChordDetector(hold_time=HOLD_TIME)
    try:
        while True:
            try:
                data = keytar.read_packet(timeout=200)
            except usb.core.USBTimeoutError:
                continue
            except usb.core.USBError as e:
                if "timed out" in str(e).lower():
                    continue
                raise

            pressed = keytar.parse_keys(data)
            chord_notes, triggered = detector.update(pressed)
            if triggered and chord_notes:
                payload = json.dumps({"chord": chord_notes, "ts": time.time()})
                client.publish(MQTT_TOPIC, payload, qos=0, retain=False)
                print(f"-> {payload}")

    except KeyboardInterrupt:
        print("\nbye.")
    finally:
        keytar.close()
        client.loop_stop()
        client.disconnect()


if __name__ == "__main__":
    main()
