/// D1 — Flash Acquire (arch.md §9).
///
/// A target appears at least 10° from the fixation cross with a Tumbling E in its A-zone.
/// The player names the E's direction. The staircase shortens the exposure.
public struct FlashAcquire: DrillDefinition {
    public struct Settings: Sendable, Codable, Equatable {
        public var eHeightDeg = 0.25
        public var minEccentricityDeg = 10.0
        public var target = TargetSize.uspsa(atYards: 10)
        public var easiestExposureMS = 500.0
        public var maskMS = 100.0
        public var responseWindowMS = 2500.0
        public var trials = 45
        public var maxReversals = 12
        /// Placeholder until real data sets it (arch.md §19 #5).
        public var parSeconds = 0.65

        public init() {}
    }

    public struct Stimulus: Sendable, Codable, Equatable {
        public var fixation: DegreePoint
        /// Target center. The E sits in the A-zone, drawn here.
        public var target: DegreePoint
        public var targetSize: TargetSize
        public var eHeightDeg: Double
        public var eFacing: Direction
    }

    public typealias Response = Direction

    public static let id = DrillID.flashAcquire
    public static let version = 1

    public let geometry: DisplayGeometry
    public let fit: ScreenFit
    public let settings: Settings
    /// Exposure ladder for this display (arch.md §7.2).
    public let ladder: Ladder

    public init(geometry: DisplayGeometry, fit: ScreenFit, settings: Settings = Settings()) {
        self.geometry = geometry
        self.fit = fit
        self.settings = settings
        self.ladder = .exposure(fromMS: settings.easiestExposureMS, geometry: geometry)
    }

    public var policy: AdaptivePolicy {
        .staircase(StaircaseConfig(
            ladder: ladder,
            stop: StopRule(maxTrials: settings.trials, maxReversals: settings.maxReversals)))
    }

    public var fitsScreen: Bool {
        // Farthest apart they can be: target in one corner, fixation in the opposite one.
        let size = settings.target
        let spanX = (fit.usableHalfWidthDeg - size.halfWidth) + fit.usableHalfWidthDeg
        let spanY = (fit.usableHalfHeightDeg - size.halfHeight) + fit.usableHalfHeightDeg
        return fit.usableHalfWidthDeg >= size.halfWidth
            && fit.usableHalfHeightDeg >= size.halfHeight
            && (spanX * spanX + spanY * spanY).squareRoot() >= settings.minEccentricityDeg
    }

    public func par(difficulty: Int) -> Double {
        settings.parSeconds
    }

    public func makeTrial(difficulty: Int, rng: inout SeededRNG) -> TrialSpec<Stimulus, Direction> {
        let size = settings.target
        let target = fit.randomCenter(halfWidth: size.halfWidth, halfHeight: size.halfHeight, rng: &rng) ?? .center
        let fixation = fit.randomPoint(awayFrom: target, atLeast: settings.minEccentricityDeg, rng: &rng)
        let facing = rng.pick(Direction.cardinal)
        let foreperiod = Foreperiod.frames(geometry: geometry, rng: &rng)
        let probe = Probe<Direction>(
            expected: facing,
            start: .afterForeperiod,
            exposureFrames: geometry.frames(forMS: ladder.value(at: difficulty)),
            maskFrames: geometry.frames(forMS: settings.maskMS),
            responseWindowFrames: geometry.frames(forMS: settings.responseWindowMS))
        let stimulus = Stimulus(
            fixation: fixation,
            target: target,
            targetSize: size,
            eHeightDeg: settings.eHeightDeg,
            eFacing: facing)
        return TrialSpec(stimulus: stimulus, foreperiodFrames: foreperiod, probes: [probe])
    }

    public func parse(_ inputs: [PlayerInput], for probe: Probe<Direction>) -> AnswerParse<Direction> {
        .firstCardinal(in: inputs)
    }

    public func evaluate(_ spec: TrialSpec<Stimulus, Direction>, answers: [ProbeAnswer<Direction>?]) -> TrialEvaluation {
        let outcome = ProbeOutcome.grade(answers.first??.response, expected: spec.probes[0].expected)
        return TrialEvaluation(outcomes: [outcome], countsForStaircase: true, correctForStaircase: outcome == .correct)
    }
}
