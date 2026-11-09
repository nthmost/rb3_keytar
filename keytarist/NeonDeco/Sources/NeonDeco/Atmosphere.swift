import SwiftUI

// Atmosphere = the optional "knobs" (outrun grid / scanlines / vignette). They
// persist per-app via UserDefaults, and the SAME keys back both the screen
// backdrop (`ndScreen`) and the in-app menu toggles (`NDViewCommands` for
// windowed apps, `NDViewToggles` for menu-bar popovers) — so flipping one place
// updates everywhere automatically.

public enum NDAtmosphereKey {
    public static let grid           = "nd.atmosphere.grid"
    public static let scanlines      = "nd.atmosphere.scanlines"
    public static let vignette       = "nd.atmosphere.vignette"
    public static let vignetteAmount = "nd.atmosphere.vignetteAmount"
}

// Defaults: grid ON (per design decision), vignette ON but light, scanlines faint.
public enum NDAtmosphereDefault {
    public static let vignetteAmount = 0.32
    public static let vignetteMax    = 0.8
}

// MARK: - Screen backdrop

public struct NDScreenModifier: ViewModifier {
    @AppStorage(NDAtmosphereKey.grid)           private var grid = true
    @AppStorage(NDAtmosphereKey.scanlines)      private var scanlines = true
    @AppStorage(NDAtmosphereKey.vignette)       private var vignette = true
    @AppStorage(NDAtmosphereKey.vignetteAmount) private var vignetteAmount = NDAtmosphereDefault.vignetteAmount

    public func body(content: Content) -> some View {
        ZStack {
            ND.ground.ignoresSafeArea()

            if grid {
                VStack { Spacer(); NDGridFloor(color: ND.violet).frame(height: 200) }
                    .ignoresSafeArea()
            }

            content

            if vignette && vignetteAmount > 0 {
                NDVignette(amount: vignetteAmount).ignoresSafeArea()
            }
            if scanlines {
                NDScanlines(opacity: 0.05).ignoresSafeArea()
            }
        }
        .foregroundStyle(ND.ink)
    }
}

public extension View {
    /// Standard app window backdrop: the night, default ink, and whatever
    /// atmosphere layers the user has enabled. Wrap your top-level window view.
    func ndScreen() -> some View {
        modifier(NDScreenModifier())
    }
}

// MARK: - Menu toggles (windowed apps)

/// Adds a "View" menu with atmosphere toggles. Attach to a Scene:
/// `WindowGroup { ... }.commands { NDViewCommands() }`
public struct NDViewCommands: Commands {
    @AppStorage(NDAtmosphereKey.grid)      private var grid = true
    @AppStorage(NDAtmosphereKey.scanlines) private var scanlines = true
    @AppStorage(NDAtmosphereKey.vignette)  private var vignette = true

    public init() {}

    public var body: some Commands {
        // Merge into the standard "View" menu (don't create a duplicate).
        CommandGroup(after: .toolbar) {
            Divider()
            Toggle("Outrun Grid", isOn: $grid)
            Toggle("Scanlines", isOn: $scanlines)
            Toggle("Vignette", isOn: $vignette)
        }
    }
}

// MARK: - Toggles view (menu-bar popovers)

/// Drop-in atmosphere toggles for a MenuBarExtra popover (menu-bar-only apps
/// have no standard menu bar to host `NDViewCommands`).
public struct NDViewToggles: View {
    @AppStorage(NDAtmosphereKey.grid)           private var grid = true
    @AppStorage(NDAtmosphereKey.scanlines)      private var scanlines = true
    @AppStorage(NDAtmosphereKey.vignette)       private var vignette = true
    @AppStorage(NDAtmosphereKey.vignetteAmount) private var vignetteAmount = NDAtmosphereDefault.vignetteAmount

    public init() {}

    public var body: some View {
        VStack(alignment: .leading, spacing: 5) {
            Text("View").decoLabel(9).foregroundStyle(ND.inkDim)
            Toggle("Outrun Grid", isOn: $grid).toggleStyle(.checkbox)
            Toggle("Scanlines", isOn: $scanlines).toggleStyle(.checkbox)
            Toggle("Vignette", isOn: $vignette).toggleStyle(.checkbox)
            HStack(spacing: 8) {
                Slider(value: $vignetteAmount, in: 0...NDAtmosphereDefault.vignetteMax)
                Text("\(Int(vignetteAmount * 100))%").ndMono(10).foregroundStyle(ND.inkDim)
                    .frame(width: 34, alignment: .trailing)
            }
            .disabled(!vignette)
        }
        .font(.system(size: 11))
        .foregroundStyle(ND.ink)
    }
}

// MARK: - Settings panel (windowed apps: Settings { NDAppearanceSettings() })

/// A native Settings/Preferences pane (opens with ⌘,) exposing the atmosphere
/// controls, including the vignette amount slider that a menu can't host.
public struct NDAppearanceSettings: View {
    @AppStorage(NDAtmosphereKey.grid)           private var grid = true
    @AppStorage(NDAtmosphereKey.scanlines)      private var scanlines = true
    @AppStorage(NDAtmosphereKey.vignette)       private var vignette = true
    @AppStorage(NDAtmosphereKey.vignetteAmount) private var vignetteAmount = NDAtmosphereDefault.vignetteAmount

    public init() {}

    public var body: some View {
        Form {
            Section("Atmosphere") {
                Toggle("Outrun Grid", isOn: $grid)
                Toggle("Scanlines", isOn: $scanlines)
                Toggle("Vignette", isOn: $vignette)
                VStack(alignment: .leading, spacing: 4) {
                    HStack {
                        Text("Vignette Amount")
                        Spacer()
                        Text("\(Int(vignetteAmount * 100))%")
                            .font(.system(size: 11, design: .monospaced))
                            .foregroundStyle(.secondary)
                    }
                    Slider(value: $vignetteAmount, in: 0...NDAtmosphereDefault.vignetteMax)
                }
                .disabled(!vignette)
            }
        }
        .formStyle(.grouped)
        .frame(width: 380, height: 220)
    }
}
