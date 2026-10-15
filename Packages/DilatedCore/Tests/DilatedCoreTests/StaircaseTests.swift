import Testing
@testable import DilatedCore

struct StaircaseTests {
    let longRun = StopRule(maxTrials: 1_000)

    /// "T" = correct, "F" = wrong.
    func answer(_ staircase: inout Staircase, _ pattern: String) {
        for character in pattern {
            staircase.record(correct: character == "T")
        }
    }

    @Test func fastStartStepsFourPerCorrectAnswer() {
        var staircase = Staircase(levelCount: 25, stop: longRun)
        answer(&staircase, "TT")
        #expect(staircase.difficulty == 8)
        #expect(staircase.reversals.isEmpty)
    }

    @Test func switchesToSmallStepsAfterTwoReversals() {
        var staircase = Staircase(levelCount: 25, stop: longRun)
        answer(&staircase, "TTF")                     // reversal 1 at 8, back to 4
        #expect(staircase.difficulty == 4)
        #expect(staircase.reversals == [.init(difficulty: 8, stepSize: 4)])

        answer(&staircase, "TT")                      // 3-down: two right isn't enough
        #expect(staircase.difficulty == 4)
        answer(&staircase, "T")                       // reversal 2 at 4, then the small step
        #expect(staircase.reversals.last == .init(difficulty: 4, stepSize: 4))
        #expect(staircase.difficulty == 5)

        answer(&staircase, "F")                       // reversal 3 is a small-step one
        #expect(staircase.reversals.last == .init(difficulty: 5, stepSize: 1))
        #expect(staircase.difficulty == 4)
    }

    @Test func aWrongAnswerResetsTheStreak() {
        var staircase = Staircase(levelCount: 25, stop: longRun, startDifficulty: 10)
        answer(&staircase, "F")                       // ends the fast start: 10 → 6
        answer(&staircase, "TTF")                     // 6 → 2, no reversal (still going easier)
        #expect(staircase.difficulty == 2)
        #expect(staircase.reversals.isEmpty)
        answer(&staircase, "TT")
        #expect(staircase.difficulty == 2)
    }

    @Test func clampsAtBothEnds() {
        var top = Staircase(levelCount: 5, stop: longRun)
        answer(&top, "TTTTT")
        #expect(top.difficulty == 4)
        var bottom = Staircase(levelCount: 5, stop: longRun)
        answer(&bottom, "F")
        #expect(bottom.difficulty == 0)
    }

    @Test func blockedGateHoldsTheLevel() {
        var staircase = Staircase(levelCount: 25, stop: longRun)
        staircase.record(correct: true, allowHarder: false)
        #expect(staircase.difficulty == 0)
    }

    @Test func stopsAtTheTrialOrReversalLimit() {
        var byTrials = Staircase(levelCount: 25, stop: StopRule(maxTrials: 3))
        answer(&byTrials, "TT")
        #expect(!byTrials.isFinished)
        answer(&byTrials, "T")
        #expect(byTrials.isFinished)

        var byReversals = Staircase(levelCount: 25, stop: StopRule(maxTrials: 1_000, maxReversals: 2))
        answer(&byReversals, "TF")
        #expect(!byReversals.isFinished)
        answer(&byReversals, "TTT")
        #expect(byReversals.isFinished)
    }

    @Test func thresholdIsTheGeometricMeanOfSmallStepReversals() {
        let ladder = Ladder(values: [400, 200, 100, 50, 25], unit: .milliseconds)
        var staircase = Staircase(levelCount: 5, stop: longRun)
        answer(&staircase, "TF")                      // big reversal at 4, back to 0
        answer(&staircase, "TTT")                     // big reversal at 0, up to 1
        answer(&staircase, "FTTTF")                   // small reversals at 1, 0, 1
        #expect(staircase.thresholdReversalLevels == nil)
        #expect(staircase.threshold(on: ladder) == nil)

        answer(&staircase, "TTT")                     // fourth small reversal, at 0
        #expect(staircase.thresholdReversalLevels == [1, 0, 1, 0])
        let threshold = try! #require(staircase.threshold(on: ladder))
        #expect(abs(threshold - (200.0 * 400).squareRoot()) < 1e-9)

        answer(&staircase, "FTTTFTTT")                // eight small reversals: keep the last six
        #expect(staircase.thresholdReversalLevels?.count == 6)
    }

    @Test func nextSessionStartsEightLevelsEasier() {
        let ladder = Ladder.exposure(fromMS: 500, geometry: Displays.macBookPro14)
        #expect(Staircase.startDifficulty(lastThreshold: nil, on: ladder) == 0)
        #expect(Staircase.startDifficulty(lastThreshold: ladder.value(at: 12), on: ladder) == 4)
        #expect(Staircase.startDifficulty(lastThreshold: ladder.value(at: 3), on: ladder) == 0)
    }
}

struct AdaptiveTrackerTests {
    let gated = AdaptivePolicy.staircase(StaircaseConfig(
        levelCount: 25,
        stop: StopRule(maxTrials: 1_000),
        gate: FalseAlarmGate(maxRate: 0.2, window: 10)))

    func trial(_ outcome: ProbeOutcome) -> TrialEvaluation {
        TrialEvaluation(
            outcomes: [outcome],
            countsForStaircase: true,
            correctForStaircase: outcome == .correct || outcome == .withheld)
    }

    @Test func falseAlarmsBlockSteppingHarder() {
        var tracker = AdaptiveTracker(policy: gated)
        tracker.record(trial(.shotNoShoot))           // 1 of 1 no-shoots fired on
        for _ in 0..<3 { tracker.record(trial(.correct)) }
        #expect(tracker.difficulty == 0)

        for _ in 0..<4 { tracker.record(trial(.withheld)) }
        #expect(tracker.difficulty == 0)              // 1 of 4 is 25%: still blocked

        for _ in 0..<2 { tracker.record(trial(.correct)) }
        #expect(tracker.difficulty == 4)              // 1 of 5 is 20%: allowed
    }

    @Test func gateOnlyLooksAtTheLastWindow() {
        var tracker = AdaptiveTracker(policy: gated)
        tracker.record(trial(.shotNoShoot))
        for _ in 0..<10 { tracker.record(trial(.withheld)) }
        let before = tracker.difficulty
        for _ in 0..<3 { tracker.record(trial(.correct)) }
        #expect(tracker.difficulty > before)
    }

    @Test func fixedPolicyNeverMoves() {
        var tracker = AdaptiveTracker(policy: .fixed(difficulty: 2, stop: StopRule(maxTrials: 3)))
        for _ in 0..<3 { tracker.record(trial(.correct)) }
        #expect(tracker.difficulty == 2)
        #expect(tracker.isFinished)
        #expect(tracker.threshold == nil)
    }

    @Test func uncountedTrialsDoNotAdvanceTheRun() {
        var tracker = AdaptiveTracker(policy: .staircase(StaircaseConfig(levelCount: 10, stop: StopRule(maxTrials: 1))))
        tracker.record(TrialEvaluation(outcomes: [.correct], countsForStaircase: false, correctForStaircase: true))
        #expect(!tracker.isFinished)
        #expect(tracker.difficulty == 0)
    }
}
