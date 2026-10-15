import Foundation

public enum LadderUnit: String, Sendable, Codable {
    case milliseconds
    case degreesPerSecond
}

/// The values a drill steps through, easiest first (arch.md §7.2). `difficulty` is an index into it.
public struct Ladder: Sendable, Codable, Equatable {
    public let values: [Double]
    public let unit: LadderUnit

    public init(values: [Double], unit: LadderUnit) {
        precondition(!values.isEmpty, "A ladder needs at least one value")
        self.values = values
        self.unit = unit
    }

    /// 0.05 log₁₀ units: each level is about 11% harder than the one before.
    public static let defaultStepLog10 = 0.05

    public var hardest: Int {
        values.count - 1
    }

    public func value(at difficulty: Int) -> Double {
        values[min(max(difficulty, 0), hardest)]
    }

    /// The level whose value is closest to `value`, in log terms.
    public func difficulty(nearest value: Double) -> Int {
        let target = log10(value)
        var best = 0
        for index in values.indices where abs(log10(values[index]) - target) < abs(log10(values[best]) - target) {
            best = index
        }
        return best
    }

    /// Exposure ladder for one display: log-spaced down from `fromMS`, rounded to whole frames,
    /// duplicates dropped, ending at the display's `minExposureFrames`.
    public static func exposure(
        fromMS: Double,
        geometry: DisplayGeometry,
        stepLog10: Double = defaultStepLog10
    ) -> Ladder {
        let minFrames = max(1, geometry.minExposureFrames)
        var frames: [Int] = []
        var level = 0.0
        while frames.last != minFrames {
            let ms = fromMS * pow(10, -stepLog10 * level)
            let next = max(minFrames, geometry.frames(forMS: ms))
            if next != frames.last {
                frames.append(next)
            }
            level += 1
        }
        return Ladder(values: frames.map(geometry.ms(forFrames:)), unit: .milliseconds)
    }
}
