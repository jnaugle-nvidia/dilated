import Testing
@testable import DilatedCore

struct ScoringTests {
    @Test func zonesFollowTheParTable() {
        let par = 0.5
        #expect(HitFactorScorer.zone(for: .correct, rtSeconds: 0.5, par: par) == .alpha)
        #expect(HitFactorScorer.zone(for: .correct, rtSeconds: 0.75, par: par) == .charlie)
        #expect(HitFactorScorer.zone(for: .correct, rtSeconds: 0.7501, par: par) == .delta)
        #expect(HitFactorScorer.zone(for: .wrong, rtSeconds: 0.3, par: par) == .miss)
        #expect(HitFactorScorer.zone(for: .noAnswer, rtSeconds: nil, par: par) == .miss)
        #expect(HitFactorScorer.zone(for: .shotNoShoot, rtSeconds: 0.3, par: par) == .noShoot)
        #expect(HitFactorScorer.zone(for: .withheld, rtSeconds: nil, par: par) == .withheld)
    }

    @Test func pointsForMinorAndMajor() {
        let minor = HitFactorScorer(powerFactor: .minor)
        let major = HitFactorScorer(powerFactor: .major)
        // A, C, D, M, NS, W
        #expect(ScoreZone.allCases.map(minor.points(for:)) == [5, 3, 1, -10, -10, 0])
        #expect(ScoreZone.allCases.map(major.points(for:)) == [5, 4, 2, -10, -10, 0])
    }

    @Test func hitFactorTruncatesToFourDecimals() {
        #expect(HitFactorScorer.hitFactor(points: 20, timeSeconds: 3) == 6.6666)    // not 6.6667
        #expect(HitFactorScorer.hitFactor(points: 29, timeSeconds: 100) == 0.29)    // 0.29 isn't exact in binary
        #expect(HitFactorScorer.hitFactor(points: 5, timeSeconds: 1.25) == 4)
        #expect(HitFactorScorer.hitFactor(points: -10, timeSeconds: 2) == 0)
        #expect(HitFactorScorer.hitFactor(points: 10, timeSeconds: 0) == 0)
    }

    @Test func scoreAddsZonesPointsAndActiveTime() {
        let score = HitFactorScorer().score([
            ScoredProbe(outcome: .correct, rtSeconds: 0.4, windowSeconds: 2.5, par: 0.5),     // A  +5   0.4 s
            ScoredProbe(outcome: .correct, rtSeconds: 0.7, windowSeconds: 2.5, par: 0.5),     // C  +3   0.7 s
            ScoredProbe(outcome: .correct, rtSeconds: 0.9, windowSeconds: 2.5, par: 0.5),     // D  +1   0.9 s
            ScoredProbe(outcome: .noAnswer, rtSeconds: nil, windowSeconds: 1.0, par: 0.5),    // M  -10  1.0 s
            ScoredProbe(outcome: .withheld, rtSeconds: nil, windowSeconds: 0.6, par: 0.5),    // W  0    0.6 s
        ])
        #expect(score.points == -1)
        #expect(abs(score.timeSeconds - 3.6) < 1e-9)
        #expect(score.hitFactor == 0)
        #expect(score.zoneCounts == [.alpha: 1, .charlie: 1, .delta: 1, .miss: 1, .withheld: 1])
    }
}

struct StatsTests {
    @Test func medianAndInterquartileRange() {
        #expect(Stats.median([3, 1, 2]) == 2)
        #expect(Stats.median([4, 1, 3, 2]) == 2.5)
        #expect(Stats.median([]) == nil)
        #expect(Stats.interquartileRange([1, 2, 3, 4, 5]) == 2)
    }

    @Test func geometricMean() {
        #expect(abs(Stats.geometricMean([200, 400, 200, 400]) - (200.0 * 400).squareRoot()) < 1e-9)
    }

    /// Reference values from Python's statistics.NormalDist().inv_cdf.
    @Test func inverseNormalCDFMatchesReference() {
        let cases: [(p: Double, z: Double)] = [
            (0.5, 0), (0.975, 1.9599639845400534), (0.025, -1.9599639845400538),
            (0.01, -2.3263478740408408), (0.999, 3.090232306167813), (0.8413447460685429, 1),
        ]
        for (p, z) in cases {
            #expect(abs(Stats.inverseNormalCDF(p) - z) < 1e-8, "p = \(p)")
        }
    }

    @Test func dPrimeUsesTheLogLinearFix() {
        let dPrime = Stats.dPrime(hits: 45, misses: 5, falseAlarms: 3, correctRejections: 17)
        #expect(abs(dPrime - 2.205501901648809) < 1e-7)
        #expect(Stats.dPrime(hits: 50, misses: 0, falseAlarms: 0, correctRejections: 20).isFinite)
    }
}
