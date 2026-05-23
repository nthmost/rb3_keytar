#!/usr/bin/env python3
"""Minimal RB3 keytar capture verifier. No MIDI, no MQTT.

Prints raw pressed-key indices on every change, and announces stable
chords detected by ChordDetector. Use this to confirm USB handshake +
key parsing + chord detection are all working before wiring anything up.

Run:
    sudo .venv/bin/python verify_capture.py
"""
import os
import sys
import time

import usb.core

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from rb3keytar import RB3Keytar
from chord_detector import ChordDetector, KEY_NAMES


def fmt_keys(pressed):
    if not pressed:
        return "(none)"
    items = sorted(pressed)
    names = " ".join(KEY_NAMES[i] for i in items)
    return f"{items}  [{names}]"


def main():
    keytar = RB3Keytar()
    keytar.connect()
    print("Keytar connected. Press keys. Hold a chord >=0.2s to trigger chord event. Ctrl+C to quit.\n")

    detector = ChordDetector(hold_time=0.2)
    last_pressed = frozenset()

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
            pressed_fs = frozenset(pressed)

            if pressed_fs != last_pressed:
                print(f"keys -> {fmt_keys(pressed)}")
                last_pressed = pressed_fs

            chord_notes, triggered = detector.update(pressed)
            if triggered and chord_notes:
                print(f"  CHORD: {chord_notes}")

    except KeyboardInterrupt:
        print("\nbye.")
    finally:
        keytar.close()


if __name__ == "__main__":
    main()
