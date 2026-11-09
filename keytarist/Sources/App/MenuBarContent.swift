import SwiftUI
import NeonDeco

/// The popover shown when the menu bar icon is clicked.
struct MenuBarContent: View {
    @EnvironmentObject var state: AppState

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Keytarist").decoLabel(12).foregroundStyle(ND.brass)

            HStack(spacing: 6) {
                NDNode(color: ND.teal, size: 6)
                Text(state.status).ndBody().foregroundStyle(ND.ink)
            }

            NDTraceDivider(color: ND.hairline)

            NDViewToggles()

            NDTraceDivider(color: ND.hairline, showNode: false)

            NDButton("Quit", systemImage: "power", tint: ND.pink) {
                NSApplication.shared.terminate(nil)
            }
        }
        .padding(14)
        .frame(width: 240)
        .background(ND.surfaceRaised)
    }
}
