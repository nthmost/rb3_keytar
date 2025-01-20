#!/usr/bin/env python3

import time
import mido
from mido import Message
import paho.mqtt.client as mqtt

import usb.core
import usb.util

import logging
logging.basicConfig(level=logging.DEBUG)

# -------------- RB3 Keytar Class --------------

class RB3Keytar:
    VENDOR_ID = 0x12ba
    PRODUCT_ID = 0x2330
    ENDPOINT_ADDRESS = 0x81
    PACKET_SIZE = 27

    MSG2 = [
        0xE9, 0x00, 0x89, 0x1B, 0x00, 0x00, 0x00, 0x02,
        0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00,
        0x00, 0x00, 0x00, 0x00, 0x00, 0x80, 0x00, 0x00,
        0x00, 0x00, 0x89, 0x00, 0x00, 0x00, 0x00, 0x00,
        0xE9, 0x01, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00
    ]

    def __init__(self):
        self.dev = None
        self.endpoint = None

    def connect(self):
        self.dev = usb.core.find(idVendor=self.VENDOR_ID, idProduct=self.PRODUCT_ID)
        if self.dev is None:
            raise ValueError("RB3 PS3 Keytar not found.")

        if self.dev.is_kernel_driver_active(0):
            self.dev.detach_kernel_driver(0)

        self.dev.set_configuration()
        usb.util.claim_interface(self.dev, 0)

        self.dev.ctrl_transfer(0x21, 0x09, 0x0300, 0, self.MSG2)

        cfg = self.dev.get_active_configuration()
        intf = cfg[(0, 0)]
        for ep in intf.endpoints():
            if ep.bEndpointAddress == self.ENDPOINT_ADDRESS:
                self.endpoint = ep
                break

        if not self.endpoint:
            raise ValueError("Keytar endpoint 0x81 not found.")

    def read_packet(self, timeout=500):
        return self.dev.read(self.endpoint.bEndpointAddress, self.PACKET_SIZE, timeout=timeout)

    @staticmethod
    def parse_keys(data):
        pressed = set()

        b5 = data[5]
        for i in range(8):
            if b5 & (1 << (7 - i)):
                pressed.add(i)

        b6 = data[6]
        for i in range(8):
            if b6 & (1 << (7 - i)):
                pressed.add(8 + i)

        b7 = data[7]
        for i in range(8):
            if b7 & (1 << (7 - i)):
                pressed.add(16 + i)

        b8 = data[8]
        if b8 & 0x80:
            pressed.add(24)

        return pressed

    def close(self):
        if self.dev:
            usb.util.release_interface(self.dev, 0)
            try:
                self.dev.attach_kernel_driver(0)
            except:
                pass


# -------------- MIDI + MQTT Setup --------------

# Let’s map key 0..24 to MIDI note numbers. 
# For example, let's assume key 0 is C2 (MIDI note 48).
BASE_MIDI_NOTE = 48
def key_to_midi_note(key_index):
    return BASE_MIDI_NOTE + key_index

# MQTT settings
MQTT_BROKER = "homeassistant.local"
MQTT_PORT = 1883
MQTT_TOPIC = "keytar/notes"  # We'll publish note_on/note_off events here


def main():
    # 1. Create a MIDI output port (virtual=True on many OSes). 
    #    This means your OS sees "RB3 Keytar Out" as a MIDI device.
    outport = mido.open_output("RB3 Keytar Out", virtual=True)
    print("Created virtual MIDI output: 'RB3 Keytar Out'")
    print("Connect this to a software synth to hear notes.\n")

    # 2. Setup MQTT client
    mqtt_client = mqtt.Client()
    mqtt_client.username_pw_set("keytar", "RB3keytar")
    mqtt_client.connect(MQTT_BROKER, MQTT_PORT, 60)
    mqtt_client.loop_start()

    # 3. Connect to the keytar
    keytar = RB3Keytar()
    keytar.connect()

    # Track which keys are currently pressed
    pressed_keys = set()

    print("Press keys on the keytar to send MIDI + MQTT events. Ctrl+C to quit.")

    try:
        while True:
            data = keytar.read_packet(timeout=500)
            current_pressed = keytar.parse_keys(data)

            newly_pressed = current_pressed - pressed_keys
            newly_released = pressed_keys - current_pressed

            # Send MIDI + MQTT for newly pressed
            for k in newly_pressed:
                midi_note = key_to_midi_note(k)
                # MIDI note_on
                msg_on = Message("note_on", note=midi_note, velocity=100)
                outport.send(msg_on)
                print(f"Note On: key={k}, midi={midi_note}")

                # MQTT publish
                mqtt_payload = {
                    "event": "note_on",
                    "key_index": k,
                    "midi_note": midi_note,
                    "timestamp": time.time()
                }
                mqtt_client.publish(MQTT_TOPIC, str(mqtt_payload))

            # Send MIDI + MQTT for newly released
            for k in newly_released:
                midi_note = key_to_midi_note(k)
                # MIDI note_off
                msg_off = Message("note_off", note=midi_note, velocity=100)
                outport.send(msg_off)
                print(f"Note Off: key={k}, midi={midi_note}")

                # MQTT publish
                mqtt_payload = {
                    "event": "note_off",
                    "key_index": k,
                    "midi_note": midi_note,
                    "timestamp": time.time()
                }
                mqtt_client.publish(MQTT_TOPIC, str(mqtt_payload))

            # Update pressed_keys
            pressed_keys = current_pressed
            time.sleep(0.01)

    except KeyboardInterrupt:
        print("\nExiting...")
    finally:
        keytar.close()
        mqtt_client.loop_stop()
        outport.close()


if __name__ == "__main__":
    main()

