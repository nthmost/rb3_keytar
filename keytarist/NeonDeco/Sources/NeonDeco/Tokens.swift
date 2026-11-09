import SwiftUI

// MARK: - Color from hex

public extension Color {
    /// `Color(hex: 0xff3d81)` — sRGB, optional opacity.
    init(hex: UInt, opacity: Double = 1) {
        self.init(
            .sRGB,
            red: Double((hex >> 16) & 0xff) / 255,
            green: Double((hex >> 8) & 0xff) / 255,
            blue: Double(hex & 0xff) / 255,
            opacity: opacity
        )
    }
}

// MARK: - Design tokens
//
// "Synthwave Art Deco Circuits" — grounded in the bladerunner.vim palette so
// apps rhyme with the editor across every host.
//
//   Deco = structure & restraint.  Circuits = connection.  Synthwave = light.

public enum ND {
    // Ground & surfaces (the night, and the marble)
    public static let ground        = Color(hex: 0x0d0b1a)  // window background
    public static let surface       = Color(hex: 0x141127)  // panels / cards
    public static let surfaceRaised = Color(hex: 0x1b1733)  // headers / popovers
    public static let selection     = Color(hex: 0x241a45)  // hover / selected wash

    // Ink
    public static let ink    = Color(hex: 0xd6d2e8)         // primary text
    public static let inkDim = Color(hex: 0x8b88ad)         // secondary text

    // Structure
    public static let hairline = Color(hex: 0x3a3556)       // quiet dividers/borders

    // Neon — used as LINES and LIGHT, never as fields
    public static let pink   = Color(hex: 0xff3d81)         // primary / active trace
    public static let teal   = Color(hex: 0x2ee6e6)         // secondary / positive
    public static let violet = Color(hex: 0xc77dff)         // focus glow / highlight

    // The deco metal
    public static let brass  = Color(hex: 0xffb454)         // structural inlay

    // Technical voice
    public static let mono   = Color(hex: 0xb3cdf0)         // monospaced readouts

    // Semantic
    public static let success = Color(hex: 0x8fe388)
    public static let warning = Color(hex: 0xffd166)
    public static let danger  = Color(hex: 0xff5370)

    // Metrics
    public static let corner: CGFloat      = 8   // chevron cut size (panels)
    public static let cornerSmall: CGFloat = 5   // chevron cut size (controls)
    public static let hairlineWidth: CGFloat = 1
}

// MARK: - Typography (system-first; deco voice from caps + tracking)

public extension View {
    /// Monumental deco title: caps + wide tracking. Titles & hero text.
    func decoTitle(_ size: CGFloat = 30, weight: Font.Weight = .bold) -> some View {
        self.font(.system(size: size, weight: weight))
            .textCase(.uppercase)
            .tracking(size * 0.11)
    }

    /// Small structural label: caps + very wide tracking. Section labels, buttons.
    func decoLabel(_ size: CGFloat = 12, weight: Font.Weight = .semibold) -> some View {
        self.font(.system(size: size, weight: weight))
            .textCase(.uppercase)
            .tracking(size * 0.18)
    }

    /// Neutral body/UI text.
    func ndBody(_ size: CGFloat = 13, weight: Font.Weight = .regular) -> some View {
        self.font(.system(size: size, weight: weight))
    }

    /// The circuit voice: monospaced digits & technical readouts.
    func ndMono(_ size: CGFloat = 12, weight: Font.Weight = .medium) -> some View {
        self.font(.system(size: size, weight: weight, design: .monospaced))
    }
}

// MARK: - Light (glow only on live/interactive things)

public extension View {
    /// Layered neon bloom. Default is intentionally SUBTLE — the resting state.
    /// Turn it up (radius/intensity) for hover, active-press, or attention.
    func neonGlow(_ color: Color, radius: CGFloat = 4, intensity: Double = 0.4) -> some View {
        self
            .shadow(color: color.opacity(intensity), radius: radius)
            .shadow(color: color.opacity(intensity * 0.45), radius: radius * 2)
    }

    /// Attention pulse: a dramatic breath between nearly-dark and hot. Use to
    /// draw the eye to a live/critical element. Set `active: false` to hold steady.
    func pulseGlow(_ color: Color, active: Bool = true, radius: CGFloat = 16) -> some View {
        modifier(NDPulseGlow(color: color, active: active, radius: radius))
    }
}

struct NDPulseGlow: ViewModifier {
    let color: Color
    let active: Bool
    let radius: CGFloat
    @State private var lit = false

    func body(content: Content) -> some View {
        content
            // Trough: dimmer than the resting glow (nearly off).
            // Peak: hotter than the bold glow — full opacity + wide radius.
            .neonGlow(color, radius: lit ? radius : radius * 0.1, intensity: lit ? 1.0 : 0.06)
            .onAppear {
                guard active else { return }
                withAnimation(.easeInOut(duration: 1.1).repeatForever(autoreverses: true)) {
                    lit = true
                }
            }
    }
}
