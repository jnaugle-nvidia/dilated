/// Applies a drill's `AdaptivePolicy` over one run: the staircase, the false-alarm gate, and the stop rule.
public struct AdaptiveTracker: Sendable, Codable, Equatable {
    private enum Mode: Sendable, Codable, Equatable {
        case staircase(Staircase, StaircaseConfig)
        case fixed(difficulty: Int, stop: StopRule, trials: Int)
    }

    private var mode: Mode
    /// One entry per no-shoot probe so far: true = false alarm.
    private var noShootFalseAlarms: [Bool] = []

    public init(policy: AdaptivePolicy, startDifficulty: Int = 0) {
        switch policy {
        case .staircase(let config):
            mode = .staircase(
                Staircase(levelCount: config.levelCount, stop: config.stop, startDifficulty: startDifficulty),
                config)
        case .fixed(let difficulty, let stop):
            mode = .fixed(difficulty: difficulty, stop: stop, trials: 0)
        }
    }

    public var difficulty: Int {
        switch mode {
        case .staircase(let staircase, _): staircase.difficulty
        case .fixed(let difficulty, _, _): difficulty
        }
    }

    public var isFinished: Bool {
        switch mode {
        case .staircase(let staircase, _): staircase.isFinished
        case .fixed(_, let stop, let trials): trials >= stop.maxTrials
        }
    }

    public var staircase: Staircase? {
        if case .staircase(let staircase, _) = mode { staircase } else { nil }
    }

    /// The run's threshold in ladder units. nil if the drill reports none or the run had too few reversals.
    public var threshold: Double? {
        guard case .staircase(let staircase, let config) = mode, let ladder = config.thresholdLadder else { return nil }
        return staircase.threshold(on: ladder)
    }

    /// Record one valid trial. Trials that don't count for the staircase don't count toward its stop rule either.
    public mutating func record(_ evaluation: TrialEvaluation) {
        for outcome in evaluation.outcomes {
            if outcome == .shotNoShoot { noShootFalseAlarms.append(true) }
            if outcome == .withheld { noShootFalseAlarms.append(false) }
        }
        switch mode {
        case .staircase(var staircase, let config):
            guard evaluation.countsForStaircase else { return }
            staircase.record(correct: evaluation.correctForStaircase, allowHarder: gateAllowsHarder(config.gate))
            mode = .staircase(staircase, config)
        case .fixed(let difficulty, let stop, let trials):
            mode = .fixed(difficulty: difficulty, stop: stop, trials: trials + 1)
        }
    }

    private func gateAllowsHarder(_ gate: FalseAlarmGate?) -> Bool {
        guard let gate, !noShootFalseAlarms.isEmpty else { return true }
        let recent = noShootFalseAlarms.suffix(gate.window)
        let rate = Double(recent.filter { $0 }.count) / Double(recent.count)
        return rate <= gate.maxRate
    }
}
