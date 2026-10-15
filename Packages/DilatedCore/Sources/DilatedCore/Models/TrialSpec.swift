/// One trial: what is drawn, how long fixation lasts, and the probes to answer (arch.md §7.1).
public struct TrialSpec<Stimulus: Sendable & Codable, Response: Sendable & Codable & Equatable>: Sendable, Codable {
    /// Everything drawn during the trial.
    public var stimulus: Stimulus
    /// Fixation time before the first probe (randomized).
    public var foreperiodFrames: Int
    /// Shown in order.
    public var probes: [Probe<Response>]

    public init(stimulus: Stimulus, foreperiodFrames: Int, probes: [Probe<Response>]) {
        self.stimulus = stimulus
        self.foreperiodFrames = foreperiodFrames
        self.probes = probes
    }
}

extension TrialSpec: Equatable where Stimulus: Equatable {}

/// One thing to answer inside a trial.
public struct Probe<Response: Sendable & Codable & Equatable>: Sendable, Codable, Equatable {
    /// nil = the correct action is "do nothing" (a no-shoot).
    public var expected: Response?
    public var start: ProbeStart
    /// How long this probe is visible.
    public var exposureFrames: Int
    public var maskFrames: Int
    /// Counted from this probe's onset.
    public var responseWindowFrames: Int
    /// Answers faster than this are anticipations, not reactions (arch.md §8.1).
    public var minRTSeconds: Double

    public init(
        expected: Response?,
        start: ProbeStart,
        exposureFrames: Int,
        maskFrames: Int,
        responseWindowFrames: Int,
        minRTSeconds: Double = Probe.defaultMinRTSeconds
    ) {
        self.expected = expected
        self.start = start
        self.exposureFrames = exposureFrames
        self.maskFrames = maskFrames
        self.responseWindowFrames = responseWindowFrames
        self.minRTSeconds = minRTSeconds
    }

    public static var defaultMinRTSeconds: Double { 0.12 }
}

public enum ProbeStart: String, Sendable, Codable {
    /// After the trial's random foreperiod.
    case afterForeperiod
    /// As soon as the previous probe ends, answered or timed out (D2, D7).
    case afterPreviousProbe
}

/// What the inputs received so far for one probe add up to.
public enum AnswerParse<Response: Sendable>: Sendable {
    /// None of the inputs mean anything for this probe. Never a false start.
    case ignored
    /// Part of an answer is in; keep collecting (D4, D6, D7).
    case incomplete
    case complete(Response)
}

extension AnswerParse: Equatable where Response: Equatable {}

extension AnswerParse where Response == Direction {
    /// The first cardinal direction completes the answer; other inputs mean nothing.
    public static func firstCardinal(in inputs: [PlayerInput]) -> AnswerParse<Direction> {
        for input in inputs {
            if case .direction(let direction) = input.action, direction.isCardinal {
                return .complete(direction)
            }
        }
        return .ignored
    }
}

public struct ProbeAnswer<Response: Sendable & Codable & Equatable>: Sendable, Codable, Equatable {
    public var response: Response
    /// This probe's onset → the input that completed the answer.
    public var rtSeconds: Double

    public init(response: Response, rtSeconds: Double) {
        self.response = response
        self.rtSeconds = rtSeconds
    }
}
