/// One graded probe, ready to score.
public struct ScoredProbe: Sendable, Codable, Equatable {
    public var outcome: ProbeOutcome
    public var rtSeconds: Double?
    /// Length of the response window: the probe's active time when no answer came.
    public var windowSeconds: Double
    public var par: Double

    public init(outcome: ProbeOutcome, rtSeconds: Double?, windowSeconds: Double, par: Double) {
        self.outcome = outcome
        self.rtSeconds = rtSeconds
        self.windowSeconds = windowSeconds
        self.par = par
    }
}

public struct RunScore: Sendable, Equatable {
    public var zoneCounts: [ScoreZone: Int]
    public var points: Int
    public var timeSeconds: Double
    public var hitFactor: Double
}

/// USPSA-style game score (arch.md §7.4). Not an official USPSA score.
public struct HitFactorScorer: Sendable {
    public var powerFactor: PowerFactor

    public init(powerFactor: PowerFactor = .minor) {
        self.powerFactor = powerFactor
    }

    public static func zone(for outcome: ProbeOutcome, rtSeconds: Double?, par: Double) -> ScoreZone {
        switch outcome {
        case .correct:
            let rt = rtSeconds ?? .infinity
            if rt <= par { return .alpha }
            if rt <= 1.5 * par { return .charlie }
            return .delta
        case .wrong, .noAnswer:
            return .miss
        case .shotNoShoot:
            return .noShoot
        case .withheld:
            return .withheld
        }
    }

    public func points(for zone: ScoreZone) -> Int {
        switch zone {
        case .alpha: 5
        case .charlie: powerFactor == .major ? 4 : 3
        case .delta: powerFactor == .major ? 2 : 1
        case .miss, .noShoot: -10
        case .withheld: 0
        }
    }

    /// max(0, points) / time, truncated (not rounded) to 4 decimals. 0 if no time passed.
    public static func hitFactor(points: Int, timeSeconds: Double) -> Double {
        guard timeSeconds > 0 else { return 0 }
        let raw = Double(max(0, points)) / timeSeconds
        // The nudge keeps values like 4.0, stored as 3.99999…, from truncating down a step.
        return (raw * 10_000 + 1e-9).rounded(.down) / 10_000
    }

    /// Time = each probe's active time: onset → answer, or onset → window end.
    public func score(_ probes: [ScoredProbe]) -> RunScore {
        var zoneCounts: [ScoreZone: Int] = [:]
        var points = 0
        var time = 0.0
        for probe in probes {
            let zone = Self.zone(for: probe.outcome, rtSeconds: probe.rtSeconds, par: probe.par)
            zoneCounts[zone, default: 0] += 1
            points += self.points(for: zone)
            time += probe.rtSeconds ?? probe.windowSeconds
        }
        return RunScore(
            zoneCounts: zoneCounts,
            points: points,
            timeSeconds: time,
            hitFactor: Self.hitFactor(points: points, timeSeconds: time))
    }
}
