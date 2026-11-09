import SwiftUI

public extension View {
    /// Chevron-cut panel: surface fill + hairline (or accent) border.
    func decoPanel(
        cut: CGFloat = ND.corner,
        corners: NDCorners = .all,
        fill: Color = ND.surface,
        stroke: Color = ND.hairline,
        lineWidth: CGFloat = ND.hairlineWidth
    ) -> some View {
        self
            .background(NDCutRect(cut: cut, corners: corners).fill(fill))
            .overlay(NDCutRect(cut: cut, corners: corners).strokeBorder(stroke, lineWidth: lineWidth))
    }
}
