#!/usr/bin/env python3

import time
from rb3keytar import RB3Keytar
import mido
from mido import Message

# A simple mapping from key index (0..24) to MIDI note numbers.
# Let's say key 0 is MIDI note 48 (C2).
# Then key 1 is 49, key 2 is 50, etc.
BASE_MIDI_NOTE = 48  # C2
def key_to_midi_note(key_index):
    return BASE_MIDI_NOTE + key_index

def main():
    # 1. Create a virtual MIDI output port
    # On some systems, you might see it appear as "Python MIDI Out".
    outport = mido.open_output('RB3 Keytar Out', virtual=True)
    print("Opened a virtual MIDI output port. Now start a synth or connect it to this port.")

    # 2. Connect to the RB3 Keytar
    keytar = RB3Keytar()
    keytar.connect()

    # Keep track of which keys are pressed so we don't resend Note On repeatedly
    pressed_keys = set()

    print("Press keys on the Keytar; we'll send MIDI notes to the virtual port. Ctrl+C to exit.")
    try:
        while True:
            data = keytar.read_packet(timeout=500)
            current_pressed = keytar.parse_keys(data)

            # figure out newly pressed or released
            newly_pressed = current_pressed - pressed_keys
            newly_released = pressed_keys - current_pressed

            # Send Note On for newly pressed
            for k in newly_pressed:
                midi_note = key_to_midi_note(k)
                msg = Message('note_on', note=midi_note, velocity=100)
                outport.send(msg)
                print(f"Note On: key {k}, midi {midi_note}")

            # Send Note Off for released
            for k in newly_released:
                midi_note = key_to_midi_note(k)
                msg = Message('note_off', note=midi_note, velocity=100)
                outport.send(msg)
                print(f"Note Off: key {k}, midi {midi_note}")

            pressed_keys = current_pressed
            time.sleep(0.01)

    except KeyboardInterrupt:
        print("\nExiting...")

    finally:
        keytar.close()
        outport.close()

if __name__ == "__main__":
    main()

