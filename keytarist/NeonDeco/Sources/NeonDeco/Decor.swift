import SwiftUI

// Optional atmosphere. Use sparingly — these are the "knobs" we dial in by eye.

// MARK: - Outrun grid floor (perspective grid; hero / footer band only)

public struct NDGridFloor: View {
    public var color: Color
    public init(color: Color = ND.violet) { self.color = color }

    public var body: some View {
        Canvas { ctx, size in
            let vanish = CGPoint(x: size.width / 2, y: -size.height * 0.9)
            let cols = 18
            for i in 0...cols {
                let x = size.width * CGFloat(i) / CGFloat(cols)
                var p = Path()
                p.move(to: CGPoint(x: x, y: size.height))
                p.addLine(to: vanish)
                ctx.stroke(p, with: .color(color.opacity(0.22)), lineWidth: 1)
            }
            let rows = 12
            for i in 0...rows {
                let t = CGFloat(i) / CGFloat(rows)
                let y = size.height - pow(t, 1.9) * size.height
                var p = Path()
                p.move(to: CGPoint(x: 0, y: y))
                p.addLine(to: CGPoint(x: size.width, y: y))
                ctx.stroke(p, with: .color(color.opacity(0.06 + 0.18 * (1 - t))), lineWidth: 1)
            }
        }
        .allowsHitTesting(false)
    }
}

// MARK: - Vignette (darken corners only; center stays bright)

public struct NDVignette: View {
    public var amount: Double   // 0 = none, ~0.8 = strong corner darkening
    public var color: Color
    public var clearTo: Double  // fraction of radius that stays fully clear

    public init(amount: Double = 0.35, color: Color = ND.ground, clearTo: Double = 0.62) {
        self.amount = amount
        self.color = color
        self.clearTo = clearTo
    }

    public var body: some View {
        GeometryReader { geo in
            // Reach the corners so darkening lands at the very edges, not mid-window.
            let corner = hypot(geo.size.width, geo.size.height) / 2
            RadialGradient(
                gradient: Gradient(stops: [
                    .init(color: .clear, location: 0.0),
                    .init(color: .clear, location: clearTo),
                    .init(color: color.opacity(amount), location: 1.0),
                ]),
                center: .center,
                startRadius: 0,
                endRadius: corner
            )
        }
        .allowsHitTesting(false)
    }
}

// MARK: - CRT scanlines (very low opacity overlay)

public struct NDScanlines: View {
    public var opacity: Double
    public var spacing: CGFloat
    public init(opacity: Double = 0.06, spacing: CGFloat = 3) {
        self.opacity = opacity
        self.spacing = spacing
    }

    public var body: some View {
        Canvas { ctx, size in
            var y: CGFloat = 0
            while y < size.height {
                var p = Path()
                p.move(to: CGPoint(x: 0, y: y))
                p.addLine(to: CGPoint(x: size.width, y: y))
                ctx.stroke(p, with: .color(.black.opacity(opacity)), lineWidth: 1)
                y += spacing
            }
        }
        .allowsHitTesting(false)
    }
}
