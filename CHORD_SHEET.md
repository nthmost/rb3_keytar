# Neon Wire Keytar — Player's Guide

The keytar drives a SwitchBot Neon Wire light over MQTT + Bluetooth.
**Hold a key (or chord) for a half-second** to trigger the mood. The light
stays that way until you play something new. Quick noodling is ignored.

---

## SINGLE KEYS → SOLID COLORS

Each pitch class maps to a different color on the rainbow. **Low octave =
dim. High octave = bright.** The lone top key (C3) is pure white.

```
          ┌──┬──┐  ┌──┬──┬──┐  ┌──┬──┐  ┌──┬──┬──┐  ┌──
          │C#│D#│  │F#│G#│A#│  │C#│D#│  │F#│G#│A#│  │
       ┌──┴┬─┴┬─┘  ├──┴┬─┴┬─┴┐ ├──┴┬─┴┬─┘  ├──┴┬─┴┬─┴┐ │ C3
       │ C │ D │ E │ F │ G │ A │ B │ C │ D │ E │ F │ G │ A │ B │WHITE│
       └───┴───┴───┴───┴───┴───┴───┴───┴───┴───┴───┴───┴───┴───┴───┘
           octave 1 (dim 50%)            octave 2 (bright 100%)
```

| Note | Color           | Note | Color          |
|------|-----------------|------|----------------|
| C    | red             | F#   | green          |
| C#   | red-orange      | G    | teal           |
| D    | orange          | G#   | cyan           |
| D#   | amber           | A    | blue           |
| E    | yellow          | A#   | violet         |
| F    | yellow-green    | B    | magenta        |

---

## CHORDS → ANIMATED EFFECTS

Build a chord by holding 2 or more keys together. The **shape** of the chord
picks the effect — the actual root note doesn't matter for which effect fires.

| Chord shape         | Built from              | Effect          |
|---------------------|-------------------------|-----------------|
| **Major triad**     | root + 4 + 3 semitones  | 🌈 rainbow      |
| **Minor triad**     | root + 3 + 4 semitones  | 🌊 meditation   |
| **Diminished**      | root + 3 + 3 semitones  | ⚡ lightning    |
| **Augmented**       | root + 4 + 4 semitones  | 🔮 mystery      |
| **Sus chord**       | root + 2 + 5  (or 5 + 2)| 💓 heartbeat    |
| **Two notes, same letter, different octaves** | e.g. C1 + C2 | 💭 dream     |
| **Any other two notes**            | any pair                | 🌊 waves      |
| **Four adjacent keys** (cluster)   | e.g. C C# D D#          | 🎆 fireworks  |
| **All 7 white keys, low octave**   | C D E F G A B (oct 1)   | 🎉 party      |
| **Lowest key + highest key**       | C1 + C3 (extreme reach) | ⚪ warm-white reset |

### Concrete chord examples to try

```
C major          C  E  G        🌈 rainbow
D minor          D  F  A        🌊 meditation
G major          G  B  D        🌈 rainbow
A minor          A  C  E        🌊 meditation
B diminished     B  D  F        ⚡ lightning
C augmented      C  E  G#       🔮 mystery
Dsus4            D  G  A        💓 heartbeat
Esus2            E  F# B        💓 heartbeat
C octave         C1 + C2        💭 dream
C + G fifth      C  + G         🌊 waves
```

Inversions count the same — `E G C` is still a C major chord and still
triggers rainbow.

---

## SUGGESTED PROGRESSIONS

Try these to feel the personality of each effect:

- **Joyful**: C major → F major → G major → C major  (rainbows in sequence)
- **Melancholy**: A minor → D minor → E minor → A minor  (gentle meditations)
- **Tension**: B diminished → C augmented → C major  (lightning → mystery → rainbow)
- **Dreamy**: hold C1+C2, then C2+C3, then C1+C3  (dream → dream → reset)

---

## TIPS

- **Wait for it.** Effects take a moment to reach the light (Bluetooth lag).
  Play the chord, hold it, then watch the wire.
- **Sticky.** Whatever you played last keeps glowing until you play something
  new. The light remembers between songs.
- **Reset trick.** Stretch from C1 (lowest key) to C3 (highest key) — both
  hands! — to wipe back to warm white.
- **Noodle freely.** Single notes have to be held for a half-second to count.
  Fast melody runs leave the light alone.
