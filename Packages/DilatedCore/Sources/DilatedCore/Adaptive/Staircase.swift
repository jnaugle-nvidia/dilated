/// 3-down / 1-up staircase with a fast start (arch.md §7.2).
///
/// It works in difficulty levels (0 = easiest). `threshold(on:)` converts back to ladder values.
public struct Staircase: Sendable, Codable, Equatable {
    public enum Move: String, Sendable, Codable {
        case harder
        case easier
    }

    public struct Reversal: Sendable, Codable, Equatable {
        /// The level where the direction changed.
        public var difficulty: Int
        /// The step size in use while approaching it.
        public var stepSize: Int
    }

    public static let bigStep = 4
    public static let smallStep = 1
    /// Reversals made with the big step before switching to the small one.
    public static let bigStepReversals = 2
    /// The threshold averages up to this many of the last small-step reversals...
    public static let thresholdReversals = 6
    /// ...and needs at least this many.
    public static let minThresholdReversals = 4
    /// The next session starts this many levels easier than the last threshold.
    public static let warmUpLevels = 8

    public let levelCount: Int
    public let stop: StopRule
    public private(set) var difficulty: Int
    public private(set) var reversals: [Reversal] = []
    public private(set) var trials = 0
    private var inFastStart = true
    private var streak = 0
    private var lastMove: Move?

    public init(levelCount: Int, stop: StopRule, startDifficulty: Int = 0) {
        precondition(levelCount > 0, "A staircase needs at least one level")
        self.levelCount = levelCount
        self.stop = stop
        self.difficulty = min(max(startDifficulty, 0), levelCount - 1)
    }

    public var stepSize: Int {
        reversals.count < Self.bigStepReversals ? Self.bigStep : Self.smallStep
    }

    public var isFinished: Bool {
        if trials >= stop.maxTrials { return true }
        if let maxReversals = stop.maxReversals, reversals.count >= maxReversals { return true }
        return false
    }

    /// Record one trial. With `allowHarder == false` (D3's gate), a step harder becomes staying put.
    public mutating func record(correct: Bool, allowHarder: Bool = true) {
        trials += 1
        if inFastStart {
            if correct {
                if allowHarder { move(.harder) }
            } else {
                inFastStart = false
                move(.easier)
            }
            return
        }
        guard correct else {
            streak = 0
            move(.easier)
            return
        }
        streak += 1
        if streak == 3 {
            streak = 0
            if allowHarder { move(.harder) }
        }
    }

    private mutating func move(_ direction: Move) {
        if let lastMove, lastMove != direction {
            reversals.append(Reversal(difficulty: difficulty, stepSize: stepSize))
        }
        lastMove = direction
        let step = stepSize   // already the small step right after the second reversal
        let next = direction == .harder ? difficulty + step : difficulty - step
        difficulty = min(max(next, 0), levelCount - 1)
    }

    /// The small-step reversal levels the threshold uses (the last 6), or nil if there are fewer than 4.
    public var thresholdReversalLevels: [Int]? {
        let small = reversals.filter { $0.stepSize == Self.smallStep }.map(\.difficulty)
        guard small.count >= Self.minThresholdReversals else { return nil }
        return Array(small.suffix(Self.thresholdReversals))
    }

    /// Geometric mean of the ladder values at those reversals, or nil.
    public func threshold(on ladder: Ladder) -> Double? {
        thresholdReversalLevels.map { levels in Stats.geometricMean(levels.map(ladder.value(at:))) }
    }

    /// Where the next session starts: `warmUpLevels` easier than the last threshold, on this display's ladder.
    public static func startDifficulty(lastThreshold: Double?, on ladder: Ladder) -> Int {
        guard let lastThreshold else { return 0 }
        return max(0, ladder.difficulty(nearest: lastThreshold) - warmUpLevels)
    }
}
