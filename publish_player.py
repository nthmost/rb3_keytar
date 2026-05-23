#!/usr/bin/env python3
"""Read RB3 keytar -> publish notes + chords to MQTT under the `player` namespace.

Publishes two topics:
  player/keytar/notes   - every note_on / note_off (JSON, not retained)
  player/keytar/chords  - stable chords held >= HOLD_TIME (JSON, not retained)

No MIDI output. Pure capture -> MQTT.

Run:
    sudo MQTT_PASS=... DYLD_LIBRARY_PATH=/opt/homebrew/lib \\
        .venv/bin/python publish_player.py

Env:
    MQTT_HOST   default: homeassistant.local
    MQTT_PORT   default: 1883
    MQTT_USER   default: player
    MQTT_PASS   required
    HOLD_TIME   default: 0.2
"""
import json
import os
import sys
import time

import usb.core
import paho.mqtt.client as mqtt

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from rb3keytar import RB3Keytar
from chord_detector import ChordDetector, KEY_NAMES

MQTT_HOST = os.environ.get("MQTT_HOST", "homeassistant.local")
MQTT_PORT = int(os.environ.get("MQTT_PORT", "1883"))
MQTT_USER = os.environ.get("MQTT_USER", "player")
MQTT_PASS = os.environ.get("MQTT_PASS")
HOLD_TIME = float(os.environ.get("HOLD_TIME", "0.2"))

TOPIC_NOTES = "player/keytar/notes"
TOPIC_CHORDS = "player/keytar/chords"


def main():
    if not MQTT_PASS:
        sys.exit("MQTT_PASS env var is required")

    client = mqtt.Client(mqtt.CallbackAPIVersion.VERSION2, client_id="rb3-keytar-player")
    client.username_pw_set(MQTT_USER, MQTT_PASS)
    client.connect(MQTT_HOST, MQTT_PORT, keepalive=60)
    client.loop_start()
    print(f"MQTT: {MQTT_USER}@{MQTT_HOST}:{MQTT_PORT}")
    print(f"  notes  -> {TOPIC_NOTES}")
    print(f"  chords -> {TOPIC_CHORDS}")

    keytar = RB3Keytar()
    keytar.connect()
    print(f"Keytar connected. Hold chords >={HOLD_TIME}s for chord events. Ctrl+C to quit.\n")

    detector = ChordDetector(hold_time=HOLD_TIME)
    pressed = set()

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

            current = keytar.parse_keys(data)

            for k in current - pressed:
                payload = json.dumps({
                    "event": "note_on",
                    "key": k,
                    "note": KEY_NAMES[k],
                    "ts": time.time(),
                })
                client.publish(TOPIC_NOTES, payload, qos=0, retain=False)
                print(f"on  {KEY_NAMES[k]:4s} (key={k})")

            for k in pressed - current:
                payload = json.dumps({
                    "event": "note_off",
                    "key": k,
                    "note": KEY_NAMES[k],
                    "ts": time.time(),
                })
                client.publish(TOPIC_NOTES, payload, qos=0, retain=False)
                print(f"off {KEY_NAMES[k]:4s} (key={k})")

            pressed = current

            chord_notes, triggered = detector.update(current)
            if triggered and chord_notes:
                payload = json.dumps({"chord": chord_notes, "ts": time.time()})
                client.publish(TOPIC_CHORDS, payload, qos=0, retain=False)
                print(f"  CHORD -> {chord_notes}")

    except KeyboardInterrupt:
        print("\nbye.")
    finally:
        keytar.close()
        client.loop_stop()
        client.disconnect()


if __name__ == "__main__":
    main()
