import Foundation
import AVFoundation

/// A sound palette: an additive harmonic recipe + envelope shape. Additive (sum
/// of sines) keeps every palette band-limited and click-free.
struct Palette {
    let name: String
    /// (frequency multiple of the fundamental, amplitude).
    let harmonics: [(mult: Double, amp: Float)]
    let attack: Double   // seconds
    let release: Double  // seconds
    let gain: Float      // overall level trim so palettes match loudness
}

/// A tiny polyphonic synth for the 25 keytar keys, built on AVAudioEngine +
/// AVAudioSourceNode so it needs no soundfont file (CLT-only friendly).
///
/// One voice per key index (0..24). Key gates + the active palette are passed
/// from the main thread as word-aligned scalars (atomic on arm64); the audio
/// render thread only reads them, so there are no locks on the audio path.
final class SynthEngine {

    static let palettes: [Palette] = [
        Palette(name: "Pad",
                harmonics: [(1, 1), (2, 0.25), (3, 0.12)],
                attack: 0.008, release: 0.22, gain: 0.75),
        Palette(name: "Saw Lead",
                harmonics: [(1, 1), (2, 0.5), (3, 0.33), (4, 0.25), (5, 0.2), (6, 0.16)],
                attack: 0.004, release: 0.12, gain: 0.42),
        Palette(name: "Square Reed",
                harmonics: [(1, 1), (3, 0.33), (5, 0.2), (7, 0.14)],
                attack: 0.004, release: 0.14, gain: 0.52),
        Palette(name: "Bell",
                harmonics: [(1, 1), (2.76, 0.5), (5.4, 0.25)],
                attack: 0.002, release: 0.6, gain: 0.7),
        Palette(name: "Organ",
                harmonics: [(1, 1), (2, 0.8), (4, 0.5)],
                attack: 0.003, release: 0.09, gain: 0.55),
    ]

    /// MIDI note for key index 0.
    var baseMIDI: Int = 48

    private let engine = AVAudioEngine()
    private var srcNode: AVAudioSourceNode?
    private var sampleRate: Double = 48_000

    // Cross-thread: written by main, read by the audio thread.
    private var gateMask: UInt32 = 0
    private var masterVolume: Float = 0.6
    private var paletteIndex: Int = 0

    // Audio-thread-only voice state.
    private var phase = [Double](repeating: 0, count: 25)
    private var env = [Float](repeating: 0, count: 25)
    private var freq = [Double](repeating: 0, count: 25)

    init() {
        for i in 0..<25 {
            let midi = Double(baseMIDI + i)
            freq[i] = 440.0 * pow(2.0, (midi - 69.0) / 12.0)
        }
    }

    // MARK: - Control (main thread)

    func start() {
        let hw = engine.outputNode.outputFormat(forBus: 0)
        sampleRate = hw.sampleRate > 0 ? hw.sampleRate : 48_000

        guard let fmt = AVAudioFormat(standardFormatWithSampleRate: sampleRate, channels: 2) else { return }

        let palettes = Self.palettes
        let attackIncs = palettes.map { Float(1.0 / ($0.attack * sampleRate)) }
        let releaseIncs = palettes.map { Float(1.0 / ($0.release * sampleRate)) }
        let twoPi = 2.0 * Double.pi

        let node = AVAudioSourceNode(format: fmt) { [unowned self] _, _, frameCount, ablPtr in
            let abl = UnsafeMutableAudioBufferListPointer(ablPtr)
            let mask = self.gateMask
            let vol = self.masterVolume
            let pi = min(max(self.paletteIndex, 0), palettes.count - 1)
            let pal = palettes[pi]
            let attackInc = attackIncs[pi]
            let releaseInc = releaseIncs[pi]
            let gain = pal.gain

            for frame in 0..<Int(frameCount) {
                var sample: Float = 0
                for i in 0..<25 {
                    let gated = (mask >> UInt32(i)) & 1 == 1
                    let target: Float = gated ? 1 : 0

                    if self.env[i] < target {
                        self.env[i] = min(target, self.env[i] + attackInc)
                    } else if self.env[i] > target {
                        self.env[i] = max(target, self.env[i] - releaseInc)
                    }
                    if self.env[i] <= 0 { continue }

                    var p = self.phase[i] + (self.freq[i] / self.sampleRate) * twoPi
                    if p >= twoPi { p -= twoPi }
                    self.phase[i] = p

                    var tone: Double = 0
                    for h in pal.harmonics { tone += Double(h.amp) * sin(h.mult * p) }
                    sample += Float(tone) * self.env[i] * gain
                }
                sample = tanhf(sample * 0.2) * vol   // soft clip + master volume

                for buffer in abl {
                    let out = buffer.mData!.assumingMemoryBound(to: Float.self)
                    out[frame] = sample
                }
            }
            return noErr
        }

        self.srcNode = node
        engine.attach(node)
        engine.connect(node, to: engine.mainMixerNode, format: fmt)
        do {
            try engine.start()
        } catch {
            NSLog("SynthEngine failed to start: \(error)")
        }
    }

    /// Set which keys (0..24) are sounding, as a bitmask (bit i == key i).
    func setGates(_ mask: UInt32) { gateMask = mask }

    func setVolume(_ v: Double) { masterVolume = Float(max(0, min(1, v))) }

    func setPalette(_ index: Int) {
        paletteIndex = ((index % Self.palettes.count) + Self.palettes.count) % Self.palettes.count
    }
}
