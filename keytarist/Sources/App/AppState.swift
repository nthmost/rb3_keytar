import SwiftUI
import Combine

/// App-wide observable state: owns the HID reader + synth and publishes what the
/// UI draws — which keys are down, the held note names, and the detected chord.
@MainActor
final class AppState: ObservableObject {
    @Published var status: String = "Looking for keytar…"
    @Published var connected: Bool = false

    /// Currently-pressed key indices (0..24).
    @Published var pressedKeys: Set<Int> = []
    /// Held note names, low -> high (e.g. ["C1", "E1", "G1"]).
    @Published var notesHeld: [String] = []
    /// Detected chord / shape label ("" when fewer than two notes held).
    @Published var chord: String = ""

    /// Audio output.
    @Published var soundOn: Bool = true {
        didSet { pushGates() }
    }
    @Published var volume: Double = 0.6 {
        didSet { synth.setVolume(volume) }
    }

    /// Current sound palette.
    @Published var paletteIndex: Int = 0
    var paletteName: String { SynthEngine.palettes[paletteIndex].name }

    private let hid = KeytarHID()
    private let synth = SynthEngine()

    init() {
        synth.setVolume(volume)
        synth.setPalette(paletteIndex)
        synth.start()

        hid.onConnection = { [weak self] up in
            Task { @MainActor in self?.setConnected(up) }
        }
        hid.onKeys = { [weak self] keys in
            Task { @MainActor in self?.apply(keys) }
        }
        hid.onHandleButton = { [weak self] in
            Task { @MainActor in self?.cyclePalette() }
        }
        hid.start()
    }

    func cyclePalette() {
        paletteIndex = (paletteIndex + 1) % SynthEngine.palettes.count
        synth.setPalette(paletteIndex)
    }

    private func setConnected(_ up: Bool) {
        connected = up
        status = up ? "Keytar connected — play!" : "Keytar disconnected"
        if !up { apply([]) }
    }

    private func apply(_ keys: Set<Int>) {
        pressedKeys = keys
        let reading = Music.read(keys)
        notesHeld = reading.notes
        chord = reading.chord
        pushGates()
    }

    /// Translate the pressed-key set into the synth's gate bitmask.
    private func pushGates() {
        var mask: UInt32 = 0
        if soundOn {
            for k in pressedKeys where k >= 0 && k < 25 { mask |= (1 << UInt32(k)) }
        }
        synth.setGates(mask)
    }
}
