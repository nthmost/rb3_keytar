import SwiftUI
import NeonDeco

/// The main application window: live keytar visualizer + chord readout.
struct MainWindow: View {
    @EnvironmentObject var state: AppState

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            NDHeader("Keytarist", systemImage: "pianokeys") {
                HStack(spacing: 8) {
                    NDNode(color: state.connected ? ND.teal : ND.warning,
                           live: state.connected, size: 8)
                    Text(state.status).ndBody(12).foregroundStyle(ND.inkDim)
                }
            }

            // Chord + held notes readout
            HStack(alignment: .top, spacing: 16) {
                NDStatCard(label: "Chord",
                           value: state.chord.isEmpty ? "—" : state.chord,
                           tint: ND.pink)
                NDStatCard(label: "Notes",
                           value: state.notesHeld.isEmpty ? "—" : state.notesHeld.joined(separator: " · "),
                           tint: ND.teal)
            }

            // Sound controls
            HStack(spacing: 16) {
                NDButton(state.soundOn ? "Sound: On" : "Sound: Off",
                         systemImage: state.soundOn ? "speaker.wave.2.fill" : "speaker.slash.fill",
                         tint: state.soundOn ? ND.teal : ND.inkDim) {
                    state.soundOn.toggle()
                }
                HStack(spacing: 8) {
                    Image(systemName: "dial.low").foregroundStyle(ND.inkDim)
                    Slider(value: $state.volume, in: 0...1)
                        .tint(ND.pink)
                        .frame(width: 160)
                        .disabled(!state.soundOn)
                }
                NDButton("Palette: \(state.paletteName)", systemImage: "waveform", tint: ND.violet) {
                    state.cyclePalette()
                }
                Spacer()
            }

            // The keyboard
            HStack {
                Spacer(minLength: 0)
                PianoView(pressed: state.pressedKeys)
                Spacer(minLength: 0)
            }
            .padding(.vertical, 8)

            if !state.connected {
                NDEmptyState(
                    title: "Waiting for the keytar",
                    message: "Plug in the Rock Band 3 keyboard (USB). If it stays dark, grant Keytarist access under System Settings → Privacy & Security → Input Monitoring.",
                    systemImage: "cable.connector"
                )
            }

            Spacer(minLength: 0)
        }
        .padding(24)
        .frame(minWidth: 720, minHeight: 420, alignment: .topLeading)
        .ndScreen()
    }
}
