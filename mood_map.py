"""Map RB3 keytar key presses to mood events for lighting control.

Single keys -> solid colors (pitch class -> hue, octave -> brightness).
Chord shapes -> native SwitchBot firmware effects.

Mood event shapes (published as JSON to player/keytar/mood):
    {"kind": "solid",  "r": 255, "g": 0, "b": 0, "brightness": 100, "label": "..."}
    {"kind": "effect", "effect": "rainbow", "label": "..."}
"""
import colorsys

PITCH_NAMES = ["C", "C#", "D", "D#", "E", "F", "F#", "G", "G#", "A", "A#", "B"]
WHITE_KEYS_OCTAVE_1 = frozenset({0, 2, 4, 5, 7, 9, 11})  # C1 D1 E1 F1 G1 A1 B1

# Chord-quality interval sets (relative to root, mod 12) -> (name, effect)
CHORD_QUALITY_EFFECT = {
    frozenset({0, 4, 7}): ("major",      "rainbow"),
    frozenset({0, 3, 7}): ("minor",      "meditation"),
    frozenset({0, 3, 6}): ("diminished", "lightning"),
    frozenset({0, 4, 8}): ("augmented",  "mystery"),
    frozenset({0, 2, 7}): ("sus2",       "heartbeat"),
    frozenset({0, 5, 7}): ("sus4",       "heartbeat"),
}


def key_to_pitch_class(k):
    return k % 12


def key_to_octave(k):
    return 1 + k // 12  # 1, 2, or 3 (only key 24)


def label_for_key(k):
    return f"{PITCH_NAMES[key_to_pitch_class(k)]}{key_to_octave(k)}"


def pitch_to_rgb(pitch_class):
    """Map pitch class 0-11 to a vivid RGB on the chromatic color wheel."""
    h = pitch_class / 12.0
    r, g, b = colorsys.hsv_to_rgb(h, 1.0, 1.0)
    return (round(r * 255), round(g * 255), round(b * 255))


def is_adjacent_cluster(keys, min_size=4):
    if len(keys) < min_size:
        return False
    sorted_keys = sorted(keys)
    return all(b - a == 1 for a, b in zip(sorted_keys, sorted_keys[1:]))


def single_key_mood(k):
    if k == 24:  # the lone C3
        return {
            "kind": "solid",
            "r": 255, "g": 255, "b": 255,
            "brightness": 100,
            "label": "C3 = pure white",
        }
    pc = key_to_pitch_class(k)
    octave = key_to_octave(k)
    r, g, b = pitch_to_rgb(pc)
    brightness = 50 if octave == 1 else 100
    return {
        "kind": "solid",
        "r": r, "g": g, "b": b,
        "brightness": brightness,
        "label": f"{label_for_key(k)} solid",
    }


def chord_mood(pressed):
    keys = frozenset(pressed)

    # Special shapes (checked before chord-quality classification)
    if keys == frozenset({0, 24}):
        return {
            "kind": "solid",
            "r": 255, "g": 200, "b": 150,
            "brightness": 60,
            "label": "C1+C3 = reset to warm white",
        }

    if keys == WHITE_KEYS_OCTAVE_1:
        return {
            "kind": "effect",
            "effect": "party",
            "label": "all-white-keys cluster = party",
        }

    if is_adjacent_cluster(keys, min_size=4):
        return {
            "kind": "effect",
            "effect": "fireworks",
            "label": f"{len(keys)}-key chromatic cluster = fireworks",
        }

    # 2-key shapes
    if len(keys) == 2:
        a, b = sorted(keys)
        if (b - a) % 12 == 0:
            return {
                "kind": "effect",
                "effect": "dream",
                "label": f"octave {label_for_key(a)}-{label_for_key(b)} = dream",
            }
        return {
            "kind": "effect",
            "effect": "waves",
            "label": f"dyad {label_for_key(a)}+{label_for_key(b)} = waves",
        }

    # Triad-quality lookup, inversion-aware: try each pitch class as the
    # potential root. C-E-G (root pos) and E-G-C (1st inv) both classify
    # as C major because both have pitch-class set {0,4,7}.
    pcs = sorted({k % 12 for k in keys})
    for root_pc in pcs:
        intervals = frozenset((p - root_pc) % 12 for p in pcs)
        if intervals in CHORD_QUALITY_EFFECT:
            quality, effect = CHORD_QUALITY_EFFECT[intervals]
            return {
                "kind": "effect",
                "effect": effect,
                "label": f"{PITCH_NAMES[root_pc]} {quality} = {effect}",
            }

    return {
        "kind": "effect",
        "effect": "dynamic",
        "label": f"{len(keys)}-note unrecognized chord = dynamic",
    }


def keys_to_mood(pressed):
    """Top-level dispatch: empty -> None, single -> color, multi -> effect."""
    keys = frozenset(pressed)
    if not keys:
        return None
    if len(keys) == 1:
        return single_key_mood(next(iter(keys)))
    return chord_mood(keys)
