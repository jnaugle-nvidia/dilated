import Foundation

/// D2 — Transition Ladder (arch.md §9).
///
/// An array of targets, numbered in shooting order. Each target is one transition away from
/// the one before it, in a random direction. An E appears on each target in turn, the moment
/// the previous one is answered; each answer is one split.
public struct TransitionLadder: DrillDefinition {
    /// One difficulty level.
    public struct Level: Sendable, Codable, Equatable {
        public var targets: Int
        /// Distance from each target to the next.
        public var transitionDeg: Double
        public var exposureMS: Double
    }

    /// Easiest first. `levels` keeps the ones that fit the screen.
    public static let allLevels: [Level] = [
        Level(targets: 3, transitionDeg: 5, exposureMS: 500),
        Level(targets: 3, transitionDeg: 7, exposureMS: 420),
        Level(targets: 4, transitionDeg: 7, exposureMS: 420),
        Level(targets: 4, transitionDeg: 9, exposureMS: 350),
        Level(targets: 5, transitionDeg: 9, exposureMS: 350),
        Level(targets: 5, transitionDeg: 11, exposureMS: 300),
        Level(targets: 6, transitionDeg: 11, exposureMS: 300),
        Level(targets: 6, transitionDeg: 14, exposureMS: 250),
        Level(targets: 7, transitionDeg: 14, exposureMS: 250),
        Level(targets: 7, transitionDeg: 18, exposureMS: 200),
        Level(targets: 8, transitionDeg: 18, exposureMS: 200),
        Level(targets: 8, transitionDeg: 25, exposureMS: 160),
    ]

    public struct Settings: Sendable, Codable, Equatable {
        public var eHeightDeg = 0.25
        public var target = TargetSize.uspsa(atYards: 10)
        /// Minimum clear space between any two targets.
        public var gapDeg = 0.5
        public var maskMS = 100.0
        public var responseWindowMS = 2500.0
        public var arrays = 10
        /// Per split. Placeholder until real data sets it (arch.md §19 #5).
        public var parSeconds = 0.5

        public init() {}
    }

    public struct Stimulus: Sendable, Codable, Equatable {
        /// In shooting order. The fixation cross starts on the first one.
        public var targets: [DegreePoint]
        public var targetSize: TargetSize
        public var eHeightDeg: Double
        /// One per target.
        public var eFacings: [Direction]
    }

    public typealias Response = Direction

    public static let id = DrillID.transitionLadder
    public static let version = 1

    public let geometry: DisplayGeometry
    public let fit: ScreenFit
    public let settings: Settings
    /// The levels that fit this screen, easiest first.
    public let levels: [Level]
    /// One known-good layout per level in `levels`. Used if a random layout can't be found.
    private let fallbackLayouts: [[DegreePoint]]

    public init(geometry: DisplayGeometry, fit: ScreenFit, settings: Settings = Settings()) {
        self.geometry = geometry
        self.fit = fit
        self.settings = settings
        var levels: [Level] = []
        var fallbacks: [[DegreePoint]] = []
        var probeRNG = SeededRNG(seed: 0xD2)
        for level in Self.allLevels {
            if let layout = Self.layout(level, fit: fit, settings: settings, rng: &probeRNG, attempts: 200) {
                levels.append(level)
                fallbacks.append(layout)
            }
        }
        self.levels = levels
        self.fallbackLayouts = fallbacks
    }

    public var policy: AdaptivePolicy {
        .staircase(StaircaseConfig(levelCount: max(1, levels.count), stop: StopRule(maxTrials: settings.arrays)))
    }

    public var fitsScreen: Bool {
        !levels.isEmpty
    }

    public func par(difficulty: Int) -> Double {
        settings.parSeconds
    }

    public func makeTrial(difficulty: Int, rng: inout SeededRNG) -> TrialSpec<Stimulus, Direction> {
        precondition(fitsScreen, "Check fitsScreen before running D2")
        let index = min(max(difficulty, 0), levels.count - 1)
        let level = levels[index]
        let targets = Self.layout(level, fit: fit, settings: settings, rng: &rng, attempts: 20) ?? fallbackLayouts[index]
        let facings = targets.map { _ in rng.pick(Direction.cardinal) }
        let foreperiod = Foreperiod.frames(geometry: geometry, rng: &rng)
        let probes = facings.indices.map { i in
            Probe<Direction>(
                expected: facings[i],
                start: i == 0 ? .afterForeperiod : .afterPreviousProbe,
                exposureFrames: max(geometry.minExposureFrames, geometry.frames(forMS: level.exposureMS)),
                maskFrames: geometry.frames(forMS: settings.maskMS),
                responseWindowFrames: geometry.frames(forMS: settings.responseWindowMS))
        }
        let stimulus = Stimulus(
            targets: targets,
            targetSize: settings.target,
            eHeightDeg: settings.eHeightDeg,
            eFacings: facings)
        return TrialSpec(stimulus: stimulus, foreperiodFrames: foreperiod, probes: probes)
    }

    public func parse(_ inputs: [PlayerInput], for probe: Probe<Direction>) -> AnswerParse<Direction> {
        .firstCardinal(in: inputs)
    }

    /// An array counts as correct for the staircase only if every target was read right.
    public func evaluate(_ spec: TrialSpec<Stimulus, Direction>, answers: [ProbeAnswer<Direction>?]) -> TrialEvaluation {
        let outcomes = spec.probes.indices.map { i in
            ProbeOutcome.grade(i < answers.count ? answers[i]?.response : nil, expected: spec.probes[i].expected)
        }
        return TrialEvaluation(
            outcomes: outcomes,
            countsForStaircase: true,
            correctForStaircase: outcomes.allSatisfy { $0 == .correct })
    }

    /// A random walk: each target one transition from the last, inside the screen, overlapping none.
    /// Restarts up to `attempts` times; nil if none worked.
    static func layout(_ level: Level, fit: ScreenFit, settings: Settings, rng: inout SeededRNG, attempts: Int) -> [DegreePoint]? {
        let size = settings.target
        for _ in 0..<attempts {
            guard let first = fit.randomCenter(halfWidth: size.halfWidth, halfHeight: size.halfHeight, rng: &rng) else {
                return nil
            }
            var targets = [first]
            while targets.count < level.targets {
                guard let next = nextTarget(after: targets, level: level, fit: fit, settings: settings, rng: &rng) else { break }
                targets.append(next)
            }
            if targets.count == level.targets {
                return targets
            }
        }
        return nil
    }

    private static func nextTarget(
        after targets: [DegreePoint],
        level: Level,
        fit: ScreenFit,
        settings: Settings,
        rng: inout SeededRNG
    ) -> DegreePoint? {
        let size = settings.target
        let last = targets[targets.count - 1]
        for _ in 0..<60 {
            let angle = rng.double(in: 0...(2 * Double.pi))
            let candidate = DegreePoint(
                x: last.x + level.transitionDeg * cos(angle),
                y: last.y + level.transitionDeg * sin(angle))
            let clear = targets.allSatisfy { other in
                abs(candidate.x - other.x) >= size.widthDeg + settings.gapDeg
                    || abs(candidate.y - other.y) >= size.heightDeg + settings.gapDeg
            }
            if clear, fit.contains(candidate, halfWidth: size.halfWidth, halfHeight: size.halfHeight) {
                return candidate
            }
        }
        return nil
    }
}
