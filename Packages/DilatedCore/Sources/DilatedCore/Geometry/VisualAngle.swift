import Foundation

/// A spot on screen in degrees from screen center: x to the right, y up.
public struct DegreePoint: Sendable, Codable, Equatable {
    public var x: Double
    public var y: Double

    public init(x: Double, y: Double) {
        self.x = x
        self.y = y
    }

    public static let center = DegreePoint(x: 0, y: 0)

    public func distance(to other: DegreePoint) -> Double {
        hypot(x - other.x, y - other.y)
    }
}

/// Converts between visual angle and screen points (arch.md §7.3). Drills work only in degrees.
public enum VisualAngle {
    /// Size on screen (points) of something `degrees` across, centered on the line of sight.
    /// points = 2 · distanceMM · tan(degrees / 2) · pointsPerMM
    public static func points(forDegrees degrees: Double, geometry: DisplayGeometry) -> Double {
        2 * geometry.viewingDistanceMM * tan(degrees * .pi / 360) * geometry.pointsPerMM
    }

    public static func degrees(forPoints points: Double, geometry: DisplayGeometry) -> Double {
        2 * atan(points / geometry.pointsPerMM / (2 * geometry.viewingDistanceMM)) * 180 / .pi
    }

    /// Distance from screen center (points) of a spot `degrees` off the line of sight.
    /// points = distanceMM · tan(degrees) · pointsPerMM
    public static func offsetPoints(forDegrees degrees: Double, geometry: DisplayGeometry) -> Double {
        geometry.viewingDistanceMM * tan(degrees * .pi / 180) * geometry.pointsPerMM
    }

    public static func degrees(forOffsetPoints points: Double, geometry: DisplayGeometry) -> Double {
        atan(points / geometry.pointsPerMM / geometry.viewingDistanceMM) * 180 / .pi
    }

    /// Angle something `size` across subtends from `distance` away (same unit for both).
    /// angle = 2 · atan((size / 2) / distance)
    public static func degrees(size: Double, distance: Double) -> Double {
        2 * atan(size / 2 / distance) * 180 / .pi
    }
}
