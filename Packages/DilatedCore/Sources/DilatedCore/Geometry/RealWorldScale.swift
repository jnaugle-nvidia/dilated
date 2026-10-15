/// USPSA target sizes in inches. Approximate: confirm against the rulebook, Appendix B1 (arch.md §19 #1).
public enum USPSATarget {
    public static let widthInches = 18.0
    public static let heightInches = 30.0
    public static let aZoneWidthInches = 6.0
}

public enum RealWorldScale {
    /// Visual angle of something `inches` across, seen from `yards` away.
    public static func degrees(inches: Double, atYards yards: Double) -> Double {
        VisualAngle.degrees(size: inches, distance: yards * 36)
    }
}

/// A target silhouette's size on screen, in degrees.
public struct TargetSize: Sendable, Codable, Equatable {
    public var widthDeg: Double
    public var heightDeg: Double

    public init(widthDeg: Double, heightDeg: Double) {
        self.widthDeg = widthDeg
        self.heightDeg = heightDeg
    }

    /// A USPSA target seen from `yards` away. At 10 yd: about 2.86° × 4.77°.
    public static func uspsa(atYards yards: Double) -> TargetSize {
        TargetSize(
            widthDeg: RealWorldScale.degrees(inches: USPSATarget.widthInches, atYards: yards),
            heightDeg: RealWorldScale.degrees(inches: USPSATarget.heightInches, atYards: yards))
    }

    public var halfWidth: Double { widthDeg / 2 }
    public var halfHeight: Double { heightDeg / 2 }
}
