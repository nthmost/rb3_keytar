import Foundation

/// Music theory for the RB3 keytar's 25 keys (C1 .. C3).
///
/// Ported from the Python `rb3_keytar` repo:
///   - key indexing / names  (chord_detector.py)
///   - inversion-aware triad classification + dyad/cluster shapes (mood_map.py)
///
/// Key index 0 == C1, index 24 == C3. Pitch class = index % 12, with 0 == C.
enum Music {

    static let pitchNames = ["C", "C#", "D", "D#", "E", "F", "F#", "G", "G#", "A", "A#", "B"]

    /// Pitch classes that are black keys on a piano (C#, D#, F#, G#, A#).
    static let blackPitchClasses: Set<Int> = [1, 3, 6, 8, 10]

    static let keyCount = 25

    static func pitchClass(_ index: Int) -> Int { ((index % 12) + 12) % 12 }

    static func isBlack(_ index: Int) -> Bool { blackPitchClasses.contains(pitchClass(index)) }

    /// Full note name with octave, e.g. "C1", "F#2".
    static func noteName(_ index: Int) -> String {
        let octave = 1 + index / 12          // 0->1, 12->2, 24->3
        return "\(pitchNames[pitchClass(index)])\(octave)"
    }

    // MARK: - Chord quality (intervals relative to root, mod 12)

    private static let triadQualities: [Set<Int>: String] = [
        [0, 4, 7]: "major",
        [0, 3, 7]: "minor",
        [0, 3, 6]: "diminished",
        [0, 4, 8]: "augmented",
        [0, 2, 7]: "sus2",
        [0, 5, 7]: "sus4",
    ]

    private static let intervalNames = [
        "unison", "minor 2nd", "major 2nd", "minor 3rd", "major 3rd",
        "perfect 4th", "tritone", "perfect 5th", "minor 6th",
        "major 6th", "minor 7th", "major 7th",
    ]

    /// Result of looking at the currently-held keys.
    struct Reading {
        var notes: [String]     // held note names, low -> high
        var chord: String       // human label ("" when nothing / single note handled separately)
    }

    static func read(_ pressed: Set<Int>) -> Reading {
        let sorted = pressed.sorted()
        let notes = sorted.map(noteName)
        return Reading(notes: notes, chord: classify(pressed))
    }

    /// Classify the held keys into a chord / shape label.
    static func classify(_ pressed: Set<Int>) -> String {
        let keys = pressed.sorted()
        guard keys.count >= 2 else { return "" }

        // Two-key shapes: octave or named interval (dyad).
        if keys.count == 2 {
            let a = keys[0], b = keys[1]
            let semis = b - a
            if semis % 12 == 0 {
                return "Octave · \(noteName(a))–\(noteName(b))"
            }
            return "\(intervalNames[semis % 12].capitalized) · \(noteName(a)) + \(noteName(b))"
        }

        // Chromatic cluster (4+ fully adjacent keys).
        if isAdjacentCluster(keys, minSize: 4) {
            return "\(keys.count)-note cluster"
        }

        // Triad-quality lookup, inversion-aware: try each pitch class as root.
        // C-E-G and its inversions all reduce to pitch-class set {0,4,7} = C major.
        let pcs = Set(keys.map(pitchClass)).sorted()
        for root in pcs {
            let intervals = Set(pcs.map { (($0 - root) % 12 + 12) % 12 })
            if let quality = triadQualities[intervals] {
                return "\(pitchNames[root]) \(quality)"
            }
        }

        return "\(keys.count)-note chord"
    }

    /// True when the sorted keys form one fully-contiguous run of >= minSize.
    private static func isAdjacentCluster(_ sortedKeys: [Int], minSize: Int) -> Bool {
        guard sortedKeys.count >= minSize, let first = sortedKeys.first, let last = sortedKeys.last
        else { return false }
        return (last - first) == (sortedKeys.count - 1)
    }
}
