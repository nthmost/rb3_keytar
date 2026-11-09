import SwiftUI
import NeonDeco

@main
struct AppMain: App {
    @StateObject private var state = AppState()

    var body: some Scene {

        // >>>WINDOW  (removed by new-app.sh for menubar-only apps)
        WindowGroup("Keytarist") {
            MainWindow()
                .environmentObject(state)
        }
        .windowResizability(.contentSize)
        .commands { NDViewCommands() }   // View menu: atmosphere toggles

        Settings { NDAppearanceSettings() }   // ⌘, → atmosphere + vignette slider
        // <<<WINDOW
    }
}
