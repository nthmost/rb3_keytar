#!/usr/bin/env python3
"""Read RB3 keytar -> publish mood events to MQTT topic player/keytar/mood.

Uses the ChordDetector's stable-hold debounce (default 0.2s) so quick melodic
noodling doesn't trigger moods. Single-key holds AND chord holds both fire.

Publishes with retain=True so any late-subscribing bridge picks up the last
mood immediately on connect.

Env (typically from ~/.config/rb3_keytar/env via run_mood.sh):
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
from chord_detector import ChordDetector
from mood_map import keys_to_mood

MQTT_HOST = os.environ.get("MQTT_HOST", "homeassistant.local")
MQTT_PORT = int(os.environ.get("MQTT_PORT", "1883"))
MQTT_USER = os.environ.get("MQTT_USER", "player")
MQTT_PASS = os.environ.get("MQTT_PASS")
HOLD_TIME = float(os.environ.get("HOLD_TIME", "0.2"))
TOPIC_MOOD = "player/keytar/mood"


def main():
    if not MQTT_PASS:
        sys.exit("MQTT_PASS env var is required")

    client = mqtt.Client(mqtt.CallbackAPIVersion.VERSION2, client_id="rb3-keytar-mood")
    client.username_pw_set(MQTT_USER, MQTT_PASS)
    client.connect(MQTT_HOST, MQTT_PORT, keepalive=60)
    client.loop_start()
    print(f"MQTT: {MQTT_USER}@{MQTT_HOST}:{MQTT_PORT} topic={TOPIC_MOOD}")

    keytar = RB3Keytar()
    keytar.connect()
    print(f"Hold keys >={HOLD_TIME}s for moods. Ctrl+C to quit.\n")

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
            _, triggered = detector.update(pressed)
            if triggered:
                mood = keys_to_mood(pressed)
                if mood:
                    payload = json.dumps({**mood, "ts": time.time()})
                    client.publish(TOPIC_MOOD, payload, qos=0, retain=True)
                    print(f"-> {mood.get('label', '?')}")

    except KeyboardInterrupt:
        print("\nbye.")
    finally:
        keytar.close()
        client.loop_stop()
        client.disconnect()


if __name__ == "__main__":
    main()
