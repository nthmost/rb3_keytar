#!/usr/bin/env python3
"""Mac-friendly entry point.

Reads the RB3 keytar via pyusb (requires sudo on macOS), creates a CoreMIDI
virtual source named "RB3 Keytar Out", and sends note_on/note_off events.
Any AU host (GarageBand, Logic, MainStage, AU Lab, SimpleSynth, FluidSynth)
can subscribe to that source to make sound.

MQTT is optional. Enable by setting MQTT_BROKER in the environment.

Run:
    sudo DYLD_LIBRARY_PATH=/opt/homebrew/lib .venv/bin/python play.py
"""
import os
import sys
import time

import usb.core
import mido
from mido import Message

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from rb3keytar import RB3Keytar

BASE_MIDI_NOTE = 48          # key 0 = C3
VELOCITY = 100
MIDI_PORT_NAME = "RB3 Keytar Out"

MQTT_BROKER = os.environ.get("MQTT_BROKER")
MQTT_PORT = int(os.environ.get("MQTT_PORT", "1883"))
MQTT_TOPIC = os.environ.get("MQTT_TOPIC", "keytar/notes")
MQTT_USER = os.environ.get("MQTT_USER")
MQTT_PASS = os.environ.get("MQTT_PASS")


def setup_mqtt():
    if not MQTT_BROKER:
        return None
    import paho.mqtt.client as mqtt
    client = mqtt.Client(mqtt.CallbackAPIVersion.VERSION2)
    if MQTT_USER:
        client.username_pw_set(MQTT_USER, MQTT_PASS or "")
    client.connect(MQTT_BROKER, MQTT_PORT, 60)
    client.loop_start()
    print(f"MQTT: publishing to {MQTT_BROKER}:{MQTT_PORT} topic={MQTT_TOPIC}")
    return client


def main():
    outport = mido.open_output(MIDI_PORT_NAME, virtual=True)
    print(f"MIDI: virtual source '{MIDI_PORT_NAME}' open. Route it to a synth.")

    mqtt_client = setup_mqtt()

    keytar = RB3Keytar()
    keytar.connect()
    print("Keytar connected. Play! (Ctrl+C to quit.)")

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
                note = BASE_MIDI_NOTE + k
                outport.send(Message("note_on", note=note, velocity=VELOCITY))
                print(f"on  key={k:2d} midi={note}")
                if mqtt_client:
                    mqtt_client.publish(
                        MQTT_TOPIC,
                        f'{{"event":"note_on","key":{k},"midi":{note},"t":{time.time()}}}',
                    )
            for k in pressed - current:
                note = BASE_MIDI_NOTE + k
                outport.send(Message("note_off", note=note, velocity=0))
                print(f"off key={k:2d} midi={note}")
                if mqtt_client:
                    mqtt_client.publish(
                        MQTT_TOPIC,
                        f'{{"event":"note_off","key":{k},"midi":{note},"t":{time.time()}}}',
                    )
            pressed = current

    except KeyboardInterrupt:
        print("\nbye.")
    finally:
        for k in pressed:
            outport.send(Message("note_off", note=BASE_MIDI_NOTE + k, velocity=0))
        keytar.close()
        if mqtt_client:
            mqtt_client.loop_stop()
        outport.close()


if __name__ == "__main__":
    main()
