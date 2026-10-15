/// D3 — No-Shoot Discriminator (arch.md §9).
///
/// A target flashes at a random spot: shoot (tan) or no-shoot (white). Space for a shoot
/// target; nothing for a no-shoot. Harder levels shrink the window, then overlap a no-shoot
/// in front, then add hard cover and a short exposure.
public struct NoShootDiscriminator: DrillDefinition {
    /// One difficulty level.
    public struct Level: Sendable, Codable, Equatable {
        public var windowMS: Double
        /// Share of the back target's width hidden by a no-shoot in front. 0 = no second target.
        public var overlap: Double
        /// Share of the target hidden by black hard cover. 0 = none.
        public var hardCover: Double
        /// nil = visible for the whole window; otherwise shown this long, then masked.
        public var exposureMS: Double?
    }

    /// Easiest first. Levels 0–3 shrink the window, 4–6 overlap, 7+ hard cover (arch.md §9).
    public static let levels: [Level] = [
        Level(windowMS: 1000, overlap: 0, hardCover: 0, exposureMS: nil),
        Level(windowMS: 850, overlap: 0, hardCover: 0, exposureMS: nil),
        Level(windowMS: 725, overlap: 0, hardCover: 0, exposureMS: nil),
        Level(windowMS: 625, overlap: 0, hardCover: 0, exposureMS: nil),
        Level(windowMS: 625, overlap: 0.25, hardCover: 0, exposureMS: nil),
        Level(windowMS: 625, overlap: 0.40, hardCover: 0, exposureMS: nil),
        Level(windowMS: 625, overlap: 0.55, hardCover: 0, exposureMS: nil),
        Level(windowMS: 625, overlap: 0.40, hardCover: 0.25, exposureMS: 300),
        Level(windowMS: 625, overlap: 0.40, hardCover: 0.35, exposureMS: 250),
        Level(windowMS: 625, overlap: 0.40, hardCover: 0.45, exposureMS: 200),
    ]

    public struct Settings: Sendable, Codable, Equatable {
        public var shootShare = 0.7
        public var target = TargetSize.uspsa(atYards: 10)
        public var maskMS = 100.0
        public var trials = 60
        public var gate = FalseAlarmGate(maxRate: 0.2, window: 10)
        /// Placeholder until real data sets it (arch.md §19 #5).
        public var parSeconds = 0.45

        public init() {}
    }

    public enum Kind: String, Sendable, Codable {
        case shoot
        case noShoot
    }

    public struct Stimulus: Sendable, Codable, Equatable {
        /// Center of the back target: the one that decides shoot or no-shoot.
        public var center: DegreePoint
        public var size: TargetSize
        public var kind: Kind
        /// See `Level.overlap`. On a shoot trial the front target is a no-shoot; on a no-shoot trial both are.
        public var overlap: Double
        /// `.left` or `.right`: where the front no-shoot sits.
        public var overlapSide: Direction
        public var hardCover: Double
        /// `.left`, `.right` or `.down`: where the hard cover comes in from.
        public var hardCoverSide: Direction
    }

    public enum Response: String, Sendable, Codable {
        case shoot
    }

    public static let id = DrillID.noShootDiscriminator
    public static let version = 1

    public let geometry: DisplayGeometry
    public let fit: ScreenFit
    public let settings: Settings

    public init(geometry: DisplayGeometry, fit: ScreenFit, settings: Settings = Settings()) {
        self.geometry = geometry
        self.fit = fit
        self.settings = settings
    }

    public var policy: AdaptivePolicy {
        .staircase(StaircaseConfig(
            levelCount: Self.levels.count,
            stop: StopRule(maxTrials: settings.trials),
            gate: settings.gate))
    }

    public var fitsScreen: Bool {
        let widest = Self.levels.map { pairWidth(overlap: $0.overlap) }.max() ?? settings.target.widthDeg
        return fit.usableHalfWidthDeg >= widest / 2 && fit.usableHalfHeightDeg >= settings.target.halfHeight
    }

    public func par(difficulty: Int) -> Double {
        settings.parSeconds
    }

    public func makeTrial(difficulty: Int, rng: inout SeededRNG) -> TrialSpec<Stimulus, Response> {
        let level = Self.levels[min(max(difficulty, 0), Self.levels.count - 1)]
        let size = settings.target
        let kind: Kind = rng.chance(settings.shootShare) ? .shoot : .noShoot
        let overlapSide = rng.pick([Direction.left, .right])
        let hardCoverSide = rng.pick([Direction.left, .right, .down])

        // Place the pair's bounding box, then the back target inside it, away from the front one.
        let width = pairWidth(overlap: level.overlap)
        let box = fit.randomCenter(halfWidth: width / 2, halfHeight: size.halfHeight, rng: &rng) ?? .center
        let shift = (width - size.widthDeg) / 2
        let center = DegreePoint(x: overlapSide == .right ? box.x - shift : box.x + shift, y: box.y)

        let foreperiod = Foreperiod.frames(geometry: geometry, rng: &rng)
        let windowFrames = geometry.frames(forMS: level.windowMS)
        let probe = Probe<Response>(
            expected: kind == .shoot ? .shoot : nil,
            start: .afterForeperiod,
            exposureFrames: level.exposureMS.map { max(geometry.minExposureFrames, geometry.frames(forMS: $0)) } ?? windowFrames,
            maskFrames: level.exposureMS == nil ? 0 : geometry.frames(forMS: settings.maskMS),
            responseWindowFrames: windowFrames)
        let stimulus = Stimulus(
            center: center,
            size: size,
            kind: kind,
            overlap: level.overlap,
            overlapSide: overlapSide,
            hardCover: level.hardCover,
            hardCoverSide: hardCoverSide)
        return TrialSpec(stimulus: stimulus, foreperiodFrames: foreperiod, probes: [probe])
    }

    public func parse(_ inputs: [PlayerInput], for probe: Probe<Response>) -> AnswerParse<Response> {
        inputs.contains { $0.action == .shoot } ? .complete(.shoot) : .ignored
    }

    /// Correct for the staircase = a hit on a shoot target, or holding fire on a no-shoot.
    public func evaluate(_ spec: TrialSpec<Stimulus, Response>, answers: [ProbeAnswer<Response>?]) -> TrialEvaluation {
        let outcome = ProbeOutcome.grade(answers.first??.response, expected: spec.probes[0].expected)
        return TrialEvaluation(
            outcomes: [outcome],
            countsForStaircase: true,
            correctForStaircase: outcome == .correct || outcome == .withheld)
    }

    /// Width of the back target plus an overlapping front one.
    private func pairWidth(overlap: Double) -> Double {
        overlap > 0 ? settings.target.widthDeg * (2 - overlap) : settings.target.widthDeg
    }
}
