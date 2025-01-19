# chord_detector.py
import time

# Example note names, but you can alter them as needed
KEY_NAMES = [
    "C1",  "C#1", "D1",  "D#1", "E1",  "F1",  "F#1", "G1",
    "G#1", "A1",  "A#1", "B1",  "C2",  "C#2", "D2",  "D#2",
    "E2",  "F2",  "F#2", "G2",  "G#2", "A2",  "A#2", "B2",
    "C3"
]

class ChordDetector:
    """
    Detects stable chord sets (keys pressed) that haven't changed for a set hold_time.
    Once triggered, the same chord won't be triggered again until it changes.
    """
    def __init__(self, hold_time=0.2):
        self.hold_time = hold_time
        self.current_set = frozenset()
        self.set_start_time = 0.0
        self.announced = False

    def update(self, pressed_keys):
        """
        Pass the *current* set of pressed keys (as a set of indices).
        Returns: (chord_notes, triggered) if a chord is newly detected, else (None, False).
        """
        s = frozenset(pressed_keys)
        now = time.time()

        if s != self.current_set:
            # The set changed
            self.current_set = s
            self.set_start_time = now
            self.announced = False
            return (None, False)
        else:
            # It's the same set as before
            duration = now - self.set_start_time
            if not self.announced and duration >= self.hold_time and s:
                # We have a stable chord
                chord_notes = [KEY_NAMES[i] for i in sorted(s)]
                self.announced = True
                return (chord_notes, True)
            else:
                return (None, False)
