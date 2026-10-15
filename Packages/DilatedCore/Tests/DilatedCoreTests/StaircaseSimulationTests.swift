import Foundation
import Testing
@testable import DilatedCore

/// arch.md §15.1: run D1's staircase against a simulated player whose true threshold is known.
struct StaircaseSimulationTests {
    /// Weibull observer for a 4-choice task: 25% guess rate, 2% lapses, slope 3.
    struct Observer {
        static let guess = 0.25
        static let lapse = 0.02
        static let slope = 3.0
        let alphaMS: Double

        /// `thresholdMS` is where this player is right 79.4% of the time.
        init(thresholdMS: Double) {
            let share = (0.794 - Self.guess) / (1 - Self.guess - Self.lapse)
            alphaMS = thresholdMS / pow(-log(1 - share), 1 / Self.slope)
        }

        func pCorrect(ms: Double) -> Double {
            Self.guess + (1 - Self.guess - Self.lapse) * (1 - exp(-pow(ms / alphaMS, Self.slope)))
        }
    }

    struct Summary: CustomStringConvertible {
        var meanError: Double
        var sdError: Double
        var thresholdRate: Double

        var description: String {
            String(format: "mean error %+.2f levels, SD %.2f, threshold in %.0f%% of runs",
                   meanError, sdError, thresholdRate * 100)
        }
    }

    /// Where `value` sits on the ladder, interpolated in log space (0 = easiest).
    static func fractionalLevel(of value: Double, on ladder: Ladder) -> Double {
        let values = ladder.values
        if value >= values[0] { return 0 }
        if value <= values[ladder.hardest] { return Double(ladder.hardest) }
        let i = values.indices.last { values[$0] >= value }!
        return Double(i) + log(values[i] / value) / log(values[i] / values[i + 1])
    }

    static func simulate(refreshHz: Double, thresholdMS: Double, warmStart: Bool, runs: Int = 500) -> Summary {
        let geometry = DisplayGeometry(pointsPerMM: 5, refreshHz: refreshHz)
        let drill = FlashAcquire(geometry: geometry, fit: Displays.macBookPro14Fit)
        let ladder = drill.ladder
        guard case .staircase(let config) = drill.policy else { fatalError("D1 uses a staircase") }
        let observer = Observer(thresholdMS: thresholdMS)
        let trueLevel = fractionalLevel(of: thresholdMS, on: ladder)
        let start = warmStart ? Staircase.startDifficulty(lastThreshold: thresholdMS, on: ladder) : 0

        var rng = SeededRNG(seed: UInt64(refreshHz) &* 1_000 &+ UInt64(thresholdMS))
        var errors: [Double] = []
        for _ in 0..<runs {
            var staircase = Staircase(levelCount: config.levelCount, stop: config.stop, startDifficulty: start)
            while !staircase.isFinished {
                staircase.record(correct: rng.unit() < observer.pCorrect(ms: ladder.value(at: staircase.difficulty)))
            }
            if let threshold = staircase.threshold(on: ladder) {
                errors.append(fractionalLevel(of: threshold, on: ladder) - trueLevel)
            }
        }
        let mean = errors.reduce(0, +) / Double(errors.count)
        let variance = errors.map { ($0 - mean) * ($0 - mean) }.reduce(0, +) / Double(errors.count - 1)
        return Summary(meanError: mean, sdError: variance.squareRoot(), thresholdRate: Double(errors.count) / Double(runs))
    }

    @Test(arguments: [120.0, 60.0], [40.0, 80.0, 160.0])
    func firstSession(refreshHz: Double, thresholdMS: Double) {
        let summary = Self.simulate(refreshHz: refreshHz, thresholdMS: thresholdMS, warmStart: false)
        print("D1 first session, \(Int(refreshHz)) Hz, true threshold \(Int(thresholdMS)) ms: \(summary)")
        #expect(abs(summary.meanError) <= 1)
        #expect(summary.thresholdRate >= 0.9)
    }

    @Test(arguments: [120.0, 60.0], [40.0, 80.0, 160.0])
    func laterSession(refreshHz: Double, thresholdMS: Double) {
        let summary = Self.simulate(refreshHz: refreshHz, thresholdMS: thresholdMS, warmStart: true)
        print("D1 later session, \(Int(refreshHz)) Hz, true threshold \(Int(thresholdMS)) ms: \(summary)")
        #expect(abs(summary.meanError) <= 1)
        #expect(summary.thresholdRate >= 0.9)
    }
}
