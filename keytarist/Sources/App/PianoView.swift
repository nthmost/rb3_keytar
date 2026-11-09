import SwiftUI
import NeonDeco

/// A 25-key piano (C1 .. C3) that lights up the keys currently held.
struct PianoView: View {
    let pressed: Set<Int>

    private let whiteW: CGFloat = 36
    private let whiteH: CGFloat = 168
    private let blackW: CGFloat = 23
    private let blackH: CGFloat = 104

    private var whiteIndices: [Int] { (0..<Music.keyCount).filter { !Music.isBlack($0) } }
    private var blackIndices: [Int] { (0..<Music.keyCount).filter { Music.isBlack($0) } }

    /// How many white keys precede `index` (used to place black keys on the seam).
    private func whitesBefore(_ index: Int) -> Int {
        whiteIndices.filter { $0 < index }.count
    }

    var body: some View {
        ZStack(alignment: .topLeading) {
            // White keys
            HStack(spacing: 1) {
                ForEach(whiteIndices, id: \.self) { idx in
                    whiteKey(idx)
                }
            }
            // Black keys, positioned on the seams between white keys
            ForEach(blackIndices, id: \.self) { idx in
                blackKey(idx)
                    .offset(x: CGFloat(whitesBefore(idx)) * (whiteW + 1) - blackW / 2 - 0.5)
            }
        }
        .frame(width: CGFloat(whiteIndices.count) * (whiteW + 1) - 1, height: whiteH)
    }

    @ViewBuilder
    private func whiteKey(_ idx: Int) -> some View {
        let isDown = pressed.contains(idx)
        RoundedRectangle(cornerRadius: 4)
            .fill(isDown ? ND.teal : Color(white: 0.88))
            .overlay(
                RoundedRectangle(cornerRadius: 4).stroke(ND.ground, lineWidth: 1)
            )
            .overlay(alignment: .bottom) {
                if isDown {
                    Text(Music.noteName(idx))
                        .ndMono(11)
                        .foregroundStyle(ND.ground)
                        .padding(.bottom, 8)
                }
            }
            .frame(width: whiteW, height: whiteH)
            .neonGlow(ND.teal, radius: isDown ? 12 : 0, intensity: isDown ? 0.9 : 0)
    }

    @ViewBuilder
    private func blackKey(_ idx: Int) -> some View {
        let isDown = pressed.contains(idx)
        RoundedRectangle(cornerRadius: 3)
            .fill(isDown ? ND.pink : Color(white: 0.08))
            .overlay(
                RoundedRectangle(cornerRadius: 3).stroke(Color.black, lineWidth: 1)
            )
            .overlay(alignment: .bottom) {
                if isDown {
                    Text(Music.pitchNames[Music.pitchClass(idx)])
                        .ndMono(9)
                        .foregroundStyle(.white)
                        .padding(.bottom, 6)
                }
            }
            .frame(width: blackW, height: blackH)
            .neonGlow(ND.pink, radius: isDown ? 12 : 0, intensity: isDown ? 0.9 : 0)
    }
}
