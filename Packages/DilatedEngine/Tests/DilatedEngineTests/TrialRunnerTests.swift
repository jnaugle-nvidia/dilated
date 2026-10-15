import DilatedCore
import Foundation
import Testing
@testable import DilatedEngine

/// 14″ MacBook Pro at 600 mm, 120 Hz, full screen below the notch.
let geometry = DisplayGeometry(pointsPerMM: 1512 / 302.4, refreshHz: 120)
let fit = ScreenFit(viewWidthPoints: 1512, viewHeightPoints: 945, geometry: geometry)

@MainActor
func flashAcquire(seed: UInt64 = 1, startDifficulty: Int = 0) -> Harness<FlashAcquire> {
    Harness(drill: FlashAcquire(geometry: geometry, fit: fit), geometry: geometry, fit: fit, seed: seed, startDifficulty: startDifficulty)
}

func isFeedback(_ presentation: Presentation) -> Bool {
    if case .feedback = presentation { true } else { false }
}

@MainActor
struct TrialRunnerTests {
    @Test func standbyBeepsOnceThenShowsFixation() {
        let h = flashAcquire()
        h.runner.start()
        h.step()
        #expect(h.runner.presentation == .standby)
        #expect(h.step(until: .fixation))
        #expect(h.beeps == 1)
        #expect((120...360).contains(h.count(.standby)))   // 1–3 s at 120 Hz
    }

    @Test(arguments: [0, 10, 24])
    func exposureAndMaskLastExactlyTheirFrames(difficulty: Int) throws {
        let h = flashAcquire(startDifficulty: difficulty)
        h.runner.start()
        #expect(h.step(until: .probe(index: 0, phase: .visible)))
        let probe = try #require(h.runner.currentSpec?.probes[0])
        #expect(h.step(until: .probe(index: 0, phase: .awaiting)))
        #expect(h.count(.probe(index: 0, phase: .visible)) == probe.exposureFrames)
        #expect(h.count(.probe(index: 0, phase: .masked)) == probe.maskFrames)
        let fixationFrames = h.count(.fixation)
        #expect(fixationFrames == h.runner.currentSpec?.foreperiodFrames)
    }

    @Test func rtIsMeasuredFromTheOnsetFrame() throws {
        let h = flashAcquire()
        h.runner.start()
        h.step(until: .probe(index: 0, phase: .visible))
        let onset = try #require(h.onsetTick)
        let expected = try #require(h.runner.currentSpec?.probes[0].expected)
        h.answer(.direction(expected), rt: 0.42)
        h.step()
        #expect(h.runner.presentation == .feedback([.correct]))
        h.step(until: .fixation)

        let probe = try #require(h.runner.trials.last?.probes.first)
        let rt = try #require(probe.rtSeconds)
        #expect(abs(rt - 0.42) < 1e-9)
        #expect(probe.onsetUptime == onset.timestamp)
        #expect(!probe.onsetConfirmed)
        #expect(probe.outcome == .correct)
        #expect(probe.zone == .alpha)   // par 0.65 s
    }

    @Test func noAnswerEndsExactlyAtTheWindow() throws {
        let h = flashAcquire()
        h.runner.start()
        h.step(until: .probe(index: 0, phase: .visible))
        let window = try #require(h.runner.currentSpec?.probes[0].responseWindowFrames)
        let before = h.shown.count - 1
        h.step(until: isFeedback)
        #expect(h.shown.count - 1 - before == window)
        #expect(h.runner.presentation == .feedback([.noAnswer]))
    }

    @Test func aFalseStartDuringFixationIsReplacedByAFreshTrial() throws {
        let h = flashAcquire()
        h.runner.start()
        h.step(until: .fixation)
        let first = h.runner.currentSpec
        h.pressNow(.direction(.up))
        h.step()
        #expect(h.runner.presentation == .invalid(.falseStart))
        h.step(until: .fixation)

        let record = try #require(h.runner.trials.first)
        #expect(record.invalidReason == .falseStart)
        #expect(record.evaluation == nil)
        #expect(record.probes.allSatisfy { $0.outcome == nil && $0.onsetUptime == nil })
        #expect(h.runner.currentSpec != first)
    }

    @Test func keysTheDrillDoesNotUseAreNotFalseStarts() {
        let h = flashAcquire()
        h.runner.start()
        h.step(until: .fixation)
        h.pressNow(.shoot)   // Space means nothing in D1
        h.step()
        #expect(h.runner.presentation == .fixation)
    }

    @Test func answersFasterThan120msAreAnticipations() throws {
        let h = flashAcquire()
        h.runner.start()
        h.step(until: .probe(index: 0, phase: .visible))
        let expected = try #require(h.runner.currentSpec?.probes[0].expected)
        h.answer(.direction(expected), rt: 0.05)
        h.step()
        #expect(h.runner.presentation == .invalid(.anticipation))
    }

    @Test func aDroppedFrameDuringTheStimulusInvalidatesTheTrial() {
        let h = flashAcquire()   // difficulty 0: 500 ms exposure
        h.runner.start()
        h.step(until: .probe(index: 0, phase: .visible))
        h.step(5)
        h.drop(2)
        h.step()
        #expect(h.runner.presentation == .invalid(.droppedFrame))
    }

    @Test func aDroppedFrameDuringFixationIsHarmless() {
        let h = flashAcquire()
        h.runner.start()
        h.step(until: .fixation)
        h.drop(3)
        h.step()
        #expect(h.runner.presentation == .fixation)
    }

    @Test func aLatePresentedTimeMovesTheOnsetAndTheRT() throws {
        let h = flashAcquire()
        h.runner.start()
        h.step(until: .probe(index: 0, phase: .visible))
        let onset = try #require(h.onsetTick)
        h.runner.onPresented(frameIndex: onset.index, presentedTime: onset.timestamp + 0.004)
        let expected = try #require(h.runner.currentSpec?.probes[0].expected)
        h.press(.direction(expected), at: onset.timestamp + 0.42)
        h.step(until: .fixation)

        let probe = try #require(h.runner.trials.last?.probes.first)
        #expect(probe.onsetConfirmed)
        #expect(probe.onsetUptime == onset.timestamp + 0.004)
        let rt = try #require(probe.rtSeconds)
        #expect(abs(rt - 0.416) < 1e-9)
    }

    @Test func aStimulusFrameThatNeverReachedTheGlassIsADroppedFrame() throws {
        let h = flashAcquire()
        h.runner.start()
        h.step(until: .probe(index: 0, phase: .visible))
        let onset = try #require(h.onsetTick)
        h.runner.onPresented(frameIndex: onset.index, presentedTime: 0)
        h.step()
        #expect(h.runner.presentation == .invalid(.droppedFrame))
    }

    @Test func presentedTimesTooFarApartAreADroppedFrame() throws {
        let h = flashAcquire()
        h.runner.start()
        h.step(until: .probe(index: 0, phase: .visible))
        h.step()
        let first = h.ticks[h.ticks.count - 2]
        let second = h.ticks[h.ticks.count - 1]
        h.runner.onPresented(frameIndex: first.index, presentedTime: first.timestamp)
        h.runner.onPresented(frameIndex: second.index, presentedTime: second.timestamp + 2 * h.frameDuration)
        h.step()
        #expect(h.runner.presentation == .invalid(.droppedFrame))
    }

    @Test func threeInvalidInARowPausesAndResumeCarriesOn() {
        let h = flashAcquire()
        h.runner.start()
        for _ in 0..<3 {
            #expect(h.step(until: .fixation))
            h.pressNow(.direction(.up))
            #expect(h.step(until: .invalid(.falseStart)))
        }
        #expect(h.step(until: .paused(.tooManyInvalid(.falseStart))))
        h.runner.resume()
        h.step()
        #expect(h.runner.presentation == .fixation)
    }

    @Test func tenInvalidTrialsAbortTheRun() {
        let h = flashAcquire()
        h.runner.start()
        while !h.runner.isFinished {
            h.step(until: { $0 == .fixation || $0 == .paused(.tooManyInvalid(.falseStart)) })
            if h.runner.presentation == .fixation {
                h.pressNow(.direction(.up))
                h.step()
            } else {
                h.runner.resume()
            }
        }
        let outcome = h.runner.outcome()
        #expect(outcome.endReason == .aborted)
        #expect(outcome.trials.count == 10)
        #expect(outcome.trials.allSatisfy { $0.invalidReason == .falseStart })
        #expect(outcome.threshold == nil)
    }

    @Test func pauseResumeAndQuit() {
        let h = flashAcquire()
        h.runner.start()
        h.step(until: .probe(index: 0, phase: .visible))
        h.runner.pause()
        h.step()
        #expect(h.runner.presentation == .paused(.player))
        #expect(h.runner.trials.isEmpty)   // the interrupted trial is dropped, not counted
        h.runner.resume()
        h.step()
        #expect(h.runner.presentation == .fixation)
        h.runner.quit()
        #expect(h.runner.isFinished)
        #expect(h.runner.outcome().endReason == .quit)
    }

    @Test func pausingBeforeTheBeepRestartsStandby() {
        let h = flashAcquire()
        h.runner.start()
        h.step(10)
        h.runner.pause()
        h.runner.resume()
        h.step()
        #expect(h.runner.presentation == .standby)
        #expect(h.step(until: .fixation))
        #expect(h.beeps == 1)
    }
}

@MainActor
struct FullRunTests {
    /// A player whose 79%-correct exposure is 80 ms (the same observer as DilatedCore's simulation).
    @Test func d1RunsToTheStopRuleAndReportsAThreshold() throws {
        let h = flashAcquire(seed: 2)
        var player = SeededRNG(seed: 3)
        let alpha = 80 / pow(-log(1 - (0.794 - 0.25) / 0.73), 1.0 / 3)
        h.runner.start()
        h.play(until: { false }) { spec, index in
            let ms = geometry.ms(forFrames: spec.probes[index].exposureFrames)
            let pCorrect = 0.25 + 0.73 * (1 - exp(-pow(ms / alpha, 3)))
            let expected = spec.probes[index].expected!
            let answer = player.unit() < pCorrect ? expected : Direction.cardinal.first { $0 != expected }!
            return (.direction(answer), player.double(in: 0.35...0.9))
        }
        let outcome = h.runner.outcome()
        #expect(outcome.endReason == .finished)
        #expect(outcome.trials.allSatisfy { $0.isValid })
        #expect(outcome.trials.count <= 45)
        let threshold = try #require(outcome.threshold)
        print(String(format: "D1 full run: %d trials, threshold %.0f ms (true 80), hit factor %.4f",
                     outcome.trials.count, threshold, outcome.score.hitFactor))
        #expect((40...160).contains(threshold), "threshold \(threshold) ms")
        let zones = outcome.score.zoneCounts.values.reduce(0, +)
        #expect(zones == outcome.trials.count)
        #expect(outcome.score.timeSeconds > 0)
    }

    @Test func d2RecordsOneRTPerTarget() throws {
        let drill = TransitionLadder(geometry: geometry, fit: fit)
        let h = Harness(drill: drill, geometry: geometry, fit: fit)
        h.runner.start()
        h.play(until: { h.runner.trials.count == 1 }) { spec, index in
            (.direction(spec.probes[index].expected!), 0.3 + 0.01 * Double(index))
        }
        let trial = try #require(h.runner.trials.first)
        #expect(trial.isValid)
        #expect(trial.probes.count == TransitionLadder.allLevels[0].targets)
        for (index, probe) in trial.probes.enumerated() {
            let rt = try #require(probe.rtSeconds)
            #expect(abs(rt - (0.3 + 0.01 * Double(index))) < 1e-9)
            #expect(probe.outcome == .correct)
        }
        // Each E appears on the first frame after the previous answer.
        for (previous, next) in zip(trial.probes, trial.probes.dropFirst()) {
            let onset = try #require(next.onsetUptime)
            let answered = try #require(previous.responseUptime)
            let gap = onset - answered
            #expect(gap > 0 && gap <= h.frameDuration + 1e-9)
        }
        #expect(trial.evaluation?.correctForStaircase == true)
    }

    @Test func d3HoldingFireOnANoShootRunsTheWholeWindow() throws {
        let drill = NoShootDiscriminator(geometry: geometry, fit: fit)
        let h = Harness(drill: drill, geometry: geometry, fit: fit, seed: 4)
        h.runner.start()
        h.play(until: { h.runner.trials.count == 20 }) { spec, _ in
            spec.probes[0].expected == nil ? nil : (.shoot, 0.3)
        }
        let trials = h.runner.trials
        #expect(trials.allSatisfy { $0.isValid })
        let outcomes = trials.map { $0.probes[0].outcome }
        #expect(outcomes.allSatisfy { $0 == .correct || $0 == .withheld })
        #expect(outcomes.contains(.withheld))
        for trial in trials where trial.probes[0].outcome == .withheld {
            #expect(trial.probes[0].rtSeconds == nil)
            #expect(trial.probes[0].zone == .withheld)
        }
    }

    @Test func sameSeedAndInputsGiveTheSameRun() {
        func run() -> [TrialOutcome] {
            let h = flashAcquire(seed: 77)
            h.runner.start()
            h.play(until: { h.runner.trials.count == 10 }) { spec, index in
                (.direction(spec.probes[index].expected!), 0.5)
            }
            return h.runner.trials
        }
        #expect(run() == run())
    }

    @Test func registryBuildsTheMVPDrillsOnly() {
        let setup = RunSetup(geometry: geometry, fit: fit, seed: 1)
        for id in DrillID.allCases {
            let runner = DrillRegistry.makeRunner(for: id, setup: setup)
            #expect((runner != nil) == DrillRegistry.available.contains(id))
            if let runner {
                #expect(runner.drillID == id)
                #expect(runner.fitsScreen)
            }
        }
    }
}
