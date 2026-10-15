/// What the screen can show, in degrees from screen center (arch.md §7.3).
///
/// Build it from the drill view's real size, not the panel size: on notched MacBooks,
/// full screen loses the strip beside the notch.
public struct ScreenFit: Sendable, Codable, Equatable {
    public var halfWidthDeg: Double
    public var halfHeightDeg: Double
    public var marginDeg: Double

    public init(halfWidthDeg: Double, halfHeightDeg: Double, marginDeg: Double = 1) {
        self.halfWidthDeg = halfWidthDeg
        self.halfHeightDeg = halfHeightDeg
        self.marginDeg = marginDeg
    }

    public init(viewWidthPoints: Double, viewHeightPoints: Double, geometry: DisplayGeometry, marginDeg: Double = 1) {
        self.init(
            halfWidthDeg: VisualAngle.degrees(forOffsetPoints: viewWidthPoints / 2, geometry: geometry),
            halfHeightDeg: VisualAngle.degrees(forOffsetPoints: viewHeightPoints / 2, geometry: geometry),
            marginDeg: marginDeg)
    }

    /// Half extents of the area drills may draw in.
    public var usableHalfWidthDeg: Double { halfWidthDeg - marginDeg }
    public var usableHalfHeightDeg: Double { halfHeightDeg - marginDeg }

    /// True if a box centered at `center` with these half sizes stays inside the usable area.
    public func contains(_ center: DegreePoint, halfWidth: Double = 0, halfHeight: Double = 0) -> Bool {
        let slack = 1e-9
        return abs(center.x) + halfWidth <= usableHalfWidthDeg + slack
            && abs(center.y) + halfHeight <= usableHalfHeightDeg + slack
    }

    /// A uniformly random center for a box of these half sizes, or nil if the box cannot fit.
    public func randomCenter(halfWidth: Double, halfHeight: Double, rng: inout SeededRNG) -> DegreePoint? {
        let maxX = usableHalfWidthDeg - halfWidth
        let maxY = usableHalfHeightDeg - halfHeight
        guard maxX >= 0, maxY >= 0 else { return nil }
        return DegreePoint(x: rng.double(in: -maxX...maxX), y: rng.double(in: -maxY...maxY))
    }

    /// A random point at least `minDistance` from `anchor`. If none turns up, the usable
    /// corner farthest from `anchor`.
    public func randomPoint(awayFrom anchor: DegreePoint, atLeast minDistance: Double, rng: inout SeededRNG) -> DegreePoint {
        for _ in 0..<100 {
            if let point = randomCenter(halfWidth: 0, halfHeight: 0, rng: &rng), point.distance(to: anchor) >= minDistance {
                return point
            }
        }
        return DegreePoint(
            x: anchor.x > 0 ? -usableHalfWidthDeg : usableHalfWidthDeg,
            y: anchor.y > 0 ? -usableHalfHeightDeg : usableHalfHeightDeg)
    }
}
