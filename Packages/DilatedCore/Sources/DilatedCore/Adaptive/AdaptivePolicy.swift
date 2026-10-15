/// How a drill picks difficulty during a run (arch.md §7.2).
public enum AdaptivePolicy: Sendable, Codable, Equatable {
    case staircase(StaircaseConfig)
    /// No adaptation: D7, warm-ups.
    case fixed(difficulty: Int, stop: StopRule)
}

public struct StaircaseConfig: Sendable, Codable, Equatable {
    public var levelCount: Int
    /// Values the threshold is reported in. nil = the drill does not report one (D2, D3).
    public var thresholdLadder: Ladder?
    public var stop: StopRule
    public var gate: FalseAlarmGate?

    public init(levelCount: Int, thresholdLadder: Ladder? = nil, stop: StopRule, gate: FalseAlarmGate? = nil) {
        self.levelCount = levelCount
        self.thresholdLadder = thresholdLadder
        self.stop = stop
        self.gate = gate
    }

    /// A drill that ladders one value and reports a threshold in it.
    public init(ladder: Ladder, stop: StopRule) {
        self.init(levelCount: ladder.values.count, thresholdLadder: ladder, stop: stop)
    }
}

/// When a run stops.
public struct StopRule: Sendable, Codable, Equatable {
    public var maxTrials: Int
    /// nil = trials only.
    public var maxReversals: Int?

    public init(maxTrials: Int, maxReversals: Int? = nil) {
        self.maxTrials = maxTrials
        self.maxReversals = maxReversals
    }
}

/// The staircase may only step harder while the false-alarm rate over the last `window`
/// no-shoot probes (or all so far, if fewer) is at most `maxRate`. Used by D3 (arch.md §9).
public struct FalseAlarmGate: Sendable, Codable, Equatable {
    public var maxRate: Double
    public var window: Int

    public init(maxRate: Double, window: Int) {
        self.maxRate = maxRate
        self.window = window
    }
}
