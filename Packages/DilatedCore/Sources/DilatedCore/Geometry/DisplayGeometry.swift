/// Plain description of the display. DilatedData stores it (arch.md §11); DilatedCore only sees this struct.
public struct DisplayGeometry: Sendable, Codable, Equatable {
    public var pointsPerMM: Double
    public var viewingDistanceMM: Double
    public var refreshHz: Double
    /// Shortest exposure that shows as a distinct flash on this panel (arch.md §15.2).
    public var minExposureFrames: Int

    public init(pointsPerMM: Double, viewingDistanceMM: Double = 600, refreshHz: Double, minExposureFrames: Int = 1) {
        self.pointsPerMM = pointsPerMM
        self.viewingDistanceMM = viewingDistanceMM
        self.refreshHz = refreshHz
        self.minExposureFrames = minExposureFrames
    }

    public var frameMS: Double {
        1000 / refreshHz
    }

    /// Whole frames for a duration. Durations are always whole frames (arch.md §8.4).
    public func frames(forMS ms: Double) -> Int {
        max(0, Int((ms / frameMS).rounded()))
    }

    public func ms(forFrames frames: Int) -> Double {
        Double(frames) * frameMS
    }
}
