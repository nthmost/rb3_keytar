import SwiftUI

// MARK: - Node / Via — dot used as bullet, focus point, status light

public struct NDNode: View {
    public var color: Color
    public var live: Bool
    public var size: CGFloat

    public init(color: Color = ND.teal, live: Bool = true, size: CGFloat = 8) {
        self.color = color
        self.live = live
        self.size = size
    }

    public var body: some View {
        Circle()
            .fill(live ? color : Color.clear)
            .overlay(Circle().strokeBorder(live ? color : ND.hairline, lineWidth: 1))
            .frame(width: size, height: size)
            .neonGlow(color, radius: live ? size * 0.6 : 0, intensity: live ? 0.5 : 0)
    }
}

// MARK: - Trace divider — a rule that bends 45° with a node at the bend

public struct NDTraceDivider: View {
    public var color: Color
    public var bend: CGFloat      // 0...1 horizontal position of the bend
    public var showNode: Bool

    public init(color: Color = ND.hairline, bend: CGFloat = 0.72, showNode: Bool = true) {
        self.color = color
        self.bend = bend
        self.showNode = showNode
    }

    public var body: some View {
        Canvas { ctx, size in
            let drop = size.height * 0.5
            let top = size.height * 0.5 - drop / 2
            let bot = size.height * 0.5 + drop / 2
            let bx = max(drop, min(size.width - drop, size.width * bend))

            var path = Path()
            path.move(to: CGPoint(x: 0, y: top))
            path.addLine(to: CGPoint(x: bx, y: top))
            path.addLine(to: CGPoint(x: bx + drop, y: bot))
            path.addLine(to: CGPoint(x: size.width, y: bot))
            ctx.stroke(path, with: .color(color), lineWidth: ND.hairlineWidth)

            if showNode {
                let n: CGFloat = 5
                let rect = CGRect(x: bx - n / 2, y: top - n / 2, width: n, height: n)
                ctx.fill(Path(ellipseIn: rect), with: .color(color))
            }
        }
        .frame(height: 12)
    }
}

// MARK: - Header — rich chrome: deco title + brass trace rule

public struct NDHeader<Trailing: View>: View {
    private let title: String
    private let systemImage: String?
    private let trailing: Trailing

    public init(
        _ title: String,
        systemImage: String? = nil,
        @ViewBuilder trailing: () -> Trailing
    ) {
        self.title = title
        self.systemImage = systemImage
        self.trailing = trailing()
    }

    public var body: some View {
        VStack(spacing: 8) {
            HStack(spacing: 10) {
                if let systemImage {
                    Image(systemName: systemImage)
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundStyle(ND.brass)
                        .neonGlow(ND.brass, radius: 5, intensity: 0.5)
                }
                Text(title).decoTitle(22).foregroundStyle(ND.ink)
                Spacer(minLength: 12)
                trailing
            }
            NDTraceDivider(color: ND.brass, bend: 0.82)
        }
    }
}

public extension NDHeader where Trailing == EmptyView {
    init(_ title: String, systemImage: String? = nil) {
        self.init(title, systemImage: systemImage, trailing: { EmptyView() })
    }
}

// MARK: - Button — chevron-cut, neon edge, glow on hover

public struct NDButton: View {
    private let title: String
    private let systemImage: String?
    private let tint: Color
    private let action: () -> Void
    @State private var hovering = false

    public init(
        _ title: String,
        systemImage: String? = nil,
        tint: Color = ND.pink,
        action: @escaping () -> Void
    ) {
        self.title = title
        self.systemImage = systemImage
        self.tint = tint
        self.action = action
    }

    public var body: some View {
        Button(action: action) {
            HStack(spacing: 6) {
                if let systemImage { Image(systemName: systemImage) }
                Text(title).decoLabel(11)
            }
            .foregroundStyle(hovering ? ND.ground : tint)
            .padding(.horizontal, 14)
            .padding(.vertical, 8)
            .background(NDCutRect(cut: ND.cornerSmall).fill(hovering ? tint : Color.clear))
            .overlay(NDCutRect(cut: ND.cornerSmall).strokeBorder(tint, lineWidth: 1))
            .neonGlow(tint, radius: hovering ? 9 : 3, intensity: hovering ? 0.85 : 0.35)
        }
        .buttonStyle(.plain)
        .onHover { hovering = $0 }
        .animation(.easeOut(duration: 0.12), value: hovering)
    }
}

// MARK: - Stat card — deco numerals in mono, diagonal chevron panel

public struct NDStatCard: View {
    private let label: String
    private let value: String
    private let tint: Color

    public init(label: String, value: String, tint: Color = ND.teal) {
        self.label = label
        self.value = value
        self.tint = tint
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 6) {
                NDNode(color: tint, size: 6)
                Text(label).decoLabel(10).foregroundStyle(ND.inkDim)
            }
            Text(value)
                .font(.system(size: 26, weight: .semibold, design: .monospaced))
                .foregroundStyle(ND.ink)
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .decoPanel(corners: .diagonal)
    }
}

// MARK: - Empty state — sunburst hero + message (rich chrome)

public struct NDEmptyState: View {
    private let title: String
    private let message: String
    private let systemImage: String

    public init(title: String, message: String, systemImage: String = "sparkles") {
        self.title = title
        self.message = message
        self.systemImage = systemImage
    }

    public var body: some View {
        VStack(spacing: 14) {
            ZStack {
                NDSunburst(rays: 24)
                    .fill(ND.brass.opacity(0.12))
                    .frame(width: 130, height: 130)
                Image(systemName: systemImage)
                    .font(.system(size: 34))
                    .foregroundStyle(ND.brass)
                    .neonGlow(ND.brass, radius: 7, intensity: 0.5)
            }
            Text(title).decoTitle(18).foregroundStyle(ND.ink)
            Text(message)
                .ndBody()
                .foregroundStyle(ND.inkDim)
                .multilineTextAlignment(.center)
                .frame(maxWidth: 320)
        }
        .padding(30)
    }
}
