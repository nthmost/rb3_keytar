import SwiftUI

// MARK: - Corners

public struct NDCorners: OptionSet, Sendable {
    public let rawValue: Int
    public init(rawValue: Int) { self.rawValue = rawValue }

    public static let topLeft     = NDCorners(rawValue: 1 << 0)
    public static let topRight    = NDCorners(rawValue: 1 << 1)
    public static let bottomRight = NDCorners(rawValue: 1 << 2)
    public static let bottomLeft  = NDCorners(rawValue: 1 << 3)

    public static let all: NDCorners      = [.topLeft, .topRight, .bottomRight, .bottomLeft]
    /// Deco diagonal accent: cut two opposite corners.
    public static let diagonal: NDCorners = [.topLeft, .bottomRight]
    public static let none: NDCorners     = []
}

// MARK: - Chevron-cut rectangle (the core panel/button shape)

public struct NDCutRect: InsettableShape {
    public var cut: CGFloat
    public var corners: NDCorners
    private var inset: CGFloat = 0

    public init(cut: CGFloat = ND.corner, corners: NDCorners = .all) {
        self.cut = cut
        self.corners = corners
    }

    public func path(in rect: CGRect) -> Path {
        let r = rect.insetBy(dx: inset, dy: inset)
        let c = min(cut, min(r.width, r.height) / 2)
        let tl = corners.contains(.topLeft)     ? c : 0
        let tr = corners.contains(.topRight)    ? c : 0
        let br = corners.contains(.bottomRight) ? c : 0
        let bl = corners.contains(.bottomLeft)  ? c : 0

        var p = Path()
        p.move(to: CGPoint(x: r.minX + tl, y: r.minY))
        p.addLine(to: CGPoint(x: r.maxX - tr, y: r.minY))
        if tr > 0 { p.addLine(to: CGPoint(x: r.maxX, y: r.minY + tr)) }
        p.addLine(to: CGPoint(x: r.maxX, y: r.maxY - br))
        if br > 0 { p.addLine(to: CGPoint(x: r.maxX - br, y: r.maxY)) }
        p.addLine(to: CGPoint(x: r.minX + bl, y: r.maxY))
        if bl > 0 { p.addLine(to: CGPoint(x: r.minX, y: r.maxY - bl)) }
        p.addLine(to: CGPoint(x: r.minX, y: r.minY + tl))
        p.closeSubpath()
        return p
    }

    public func inset(by amount: CGFloat) -> some InsettableShape {
        var s = self
        s.inset += amount
        return s
    }
}

// MARK: - Sunburst (deco radial fan; hero / empty-state ornament)

public struct NDSunburst: Shape {
    public var rays: Int
    public init(rays: Int = 24) { self.rays = rays }

    public func path(in rect: CGRect) -> Path {
        let center = CGPoint(x: rect.midX, y: rect.midY)
        let radius = min(rect.width, rect.height) / 2
        let step = (2 * Double.pi) / Double(rays * 2)
        var p = Path()
        for i in 0..<rays {
            let a0 = Double(i) * 2 * step
            let a1 = a0 + step
            p.move(to: center)
            p.addLine(to: CGPoint(x: center.x + radius * cos(a0), y: center.y + radius * sin(a0)))
            p.addLine(to: CGPoint(x: center.x + radius * cos(a1), y: center.y + radius * sin(a1)))
            p.closeSubpath()
        }
        return p
    }
}
