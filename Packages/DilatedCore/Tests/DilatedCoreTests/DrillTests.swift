import Testing
@testable import DilatedCore

struct FlashAcquireTests {
    let drill = FlashAcquire(geometry: Displays.macBookPro14, fit: Displays.macBookPro14Fit)

    @Test func sameSeedSameTrials() {
        var a = SeededRNG(seed: 99)
        var b = SeededRNG(seed: 99)
        for difficulty in drill.ladder.values.indices {
            #expect(drill.makeTrial(difficulty: difficulty, rng: &a) == drill.makeTrial(difficulty: difficulty, rng: &b))
        }
    }

    @Test func targetsFitAndSitTenDegreesFromFixation() {
        for (geometry, fit) in Displays.all {
            let drill = FlashAcquire(geometry: geometry, fit: fit)
            #expect(drill.fitsScreen)
            var rng = SeededRNG(seed: 1)
            for _ in 0..<1_000 {
                let stimulus = drill.makeTrial(difficulty: 0, rng: &rng).stimulus
                let size = stimulus.targetSize
                #expect(fit.contains(stimulus.target, halfWidth: size.halfWidth, halfHeight: size.halfHeight))
                #expect(fit.contains(stimulus.fixation))
                #expect(stimulus.fixation.distance(to: stimulus.target) >= 10)
            }
        }
    }

    @Test func exposureFollowsTheLadderAndForeperiodIsRandom() {
        let geometry = Displays.macBookPro14
        var rng = SeededRNG(seed: 2)
        var foreperiods = Set<Int>()
        for difficulty in drill.ladder.values.indices {
            let spec = drill.makeTrial(difficulty: difficulty, rng: &rng)
            #expect(spec.probes.count == 1)
            #expect(spec.probes[0].exposureFrames == geometry.frames(forMS: drill.ladder.value(at: difficulty)))
            #expect(spec.probes[0].start == .afterForeperiod)
            #expect((48...108).contains(spec.foreperiodFrames))        // 400–900 ms at 120 Hz
            foreperiods.insert(spec.foreperiodFrames)
        }
        #expect(foreperiods.count > 5)
    }

    @Test func parsesArrowsAndIgnoresOtherKeys() {
        var rng = SeededRNG(seed: 3)
        let probe = drill.makeTrial(difficulty: 0, rng: &rng).probes[0]
        #expect(drill.parse([.key(.shoot)], for: probe) == .ignored)
        #expect(drill.parse([.key(.direction(.upRight))], for: probe) == .ignored)
        #expect(drill.parse([.key(.shoot), .key(.direction(.left))], for: probe) == .complete(.left))
    }

    @Test func grades() throws {
        var rng = SeededRNG(seed: 4)
        let spec = drill.makeTrial(difficulty: 3, rng: &rng)
        let right = try #require(spec.probes[0].expected)
        let wrong = try #require(Direction.cardinal.first { $0 != right })

        let hit = drill.evaluate(spec, answers: [ProbeAnswer(response: right, rtSeconds: 0.5)])
        #expect(hit.outcomes == [.correct])
        #expect(hit.correctForStaircase)
        #expect(drill.evaluate(spec, answers: [ProbeAnswer(response: wrong, rtSeconds: 0.5)]).outcomes == [.wrong])
        let none = drill.evaluate(spec, answers: [nil])
        #expect(none.outcomes == [.noAnswer])
        #expect(!none.correctForStaircase)
    }

    @Test func refusesAScreenTooSmallForTenDegrees() {
        let tiny = ScreenFit(halfWidthDeg: 5, halfHeightDeg: 4)
        #expect(!FlashAcquire(geometry: Displays.macBookPro14, fit: tiny).fitsScreen)
    }
}

struct TransitionLadderTests {
    @Test func arraysKeepTheTransitionStayOnScreenAndDoNotOverlap() {
        for (geometry, fit) in Displays.all {
            let drill = TransitionLadder(geometry: geometry, fit: fit)
            let size = drill.settings.target
            var rng = SeededRNG(seed: 5)
            for (difficulty, level) in drill.levels.enumerated() {
                for _ in 0..<50 {
                    let spec = drill.makeTrial(difficulty: difficulty, rng: &rng)
                    let targets = spec.stimulus.targets
                    #expect(targets.count == level.targets)
                    #expect(spec.probes.count == level.targets)
                    #expect(spec.stimulus.eFacings == spec.probes.map(\.expected))
                    for (a, b) in zip(targets, targets.dropFirst()) {
                        #expect(abs(a.distance(to: b) - level.transitionDeg) < 1e-9)
                    }
                    for (i, a) in targets.enumerated() {
                        #expect(fit.contains(a, halfWidth: size.halfWidth, halfHeight: size.halfHeight))
                        for b in targets[(i + 1)...] {
                            let apart = abs(a.x - b.x) >= size.widthDeg || abs(a.y - b.y) >= size.heightDeg
                            #expect(apart)
                        }
                    }
                    #expect(spec.probes[0].start == .afterForeperiod)
                    #expect(spec.probes.dropFirst().allSatisfy { $0.start == .afterPreviousProbe })
                }
            }
        }
    }

    @Test func smallScreensDropTheWidestLevels() throws {
        let laptop = TransitionLadder(geometry: Displays.macBookPro14, fit: Displays.macBookPro14Fit)
        let studio = TransitionLadder(geometry: Displays.studioDisplay, fit: Displays.studioDisplayFit)
        let laptopHardest = try #require(laptop.levels.last)
        let studioHardest = try #require(studio.levels.last)
        print("D2 levels that fit at 600 mm — 14″ MacBook Pro: \(laptop.levels.count) of \(TransitionLadder.allLevels.count), "
            + "hardest \(laptopHardest.targets) targets × \(laptopHardest.transitionDeg)°; "
            + "27″ Studio Display: \(studio.levels.count), hardest \(studioHardest.targets) × \(studioHardest.transitionDeg)°")
        #expect(laptop.fitsScreen)
        #expect(laptop.levels.count < TransitionLadder.allLevels.count)
        #expect(studio.levels.count >= laptop.levels.count)
    }

    @Test func sameSeedSameArrays() {
        let drill = TransitionLadder(geometry: Displays.macBookPro14, fit: Displays.macBookPro14Fit)
        var a = SeededRNG(seed: 8)
        var b = SeededRNG(seed: 8)
        for difficulty in drill.levels.indices {
            #expect(drill.makeTrial(difficulty: difficulty, rng: &a) == drill.makeTrial(difficulty: difficulty, rng: &b))
        }
    }

    @Test func anArrayIsCorrectOnlyIfEveryTargetIs() throws {
        let drill = TransitionLadder(geometry: Displays.macBookPro14, fit: Displays.macBookPro14Fit)
        var rng = SeededRNG(seed: 9)
        let spec = drill.makeTrial(difficulty: 2, rng: &rng)
        let rightAnswers = spec.probes.map { ProbeAnswer(response: $0.expected!, rtSeconds: 0.3) }
        let clean = drill.evaluate(spec, answers: rightAnswers)
        #expect(clean.outcomes.allSatisfy { $0 == .correct })
        #expect(clean.correctForStaircase)

        var oneMissed: [ProbeAnswer<Direction>?] = rightAnswers
        oneMissed[1] = nil
        let missed = drill.evaluate(spec, answers: oneMissed)
        #expect(missed.outcomes[1] == .noAnswer)
        #expect(!missed.correctForStaircase)
    }
}

struct NoShootDiscriminatorTests {
    let geometry = Displays.macBookPro14
    let drill = NoShootDiscriminator(geometry: Displays.macBookPro14, fit: Displays.macBookPro14Fit)

    @Test func aboutSeventyPercentShootTargets() {
        var rng = SeededRNG(seed: 6)
        let trials = 4_000
        let shoots = (0..<trials).filter { _ in drill.makeTrial(difficulty: 0, rng: &rng).stimulus.kind == .shoot }.count
        #expect(abs(Double(shoots) / Double(trials) - 0.7) < 0.025)
    }

    @Test func levelsSetWindowOverlapHardCoverAndExposure() {
        var rng = SeededRNG(seed: 7)
        for (difficulty, level) in NoShootDiscriminator.levels.enumerated() {
            let spec = drill.makeTrial(difficulty: difficulty, rng: &rng)
            let probe = spec.probes[0]
            #expect(probe.responseWindowFrames == geometry.frames(forMS: level.windowMS))
            #expect(spec.stimulus.overlap == level.overlap)
            #expect(spec.stimulus.hardCover == level.hardCover)
            if let exposureMS = level.exposureMS {
                #expect(probe.exposureFrames == geometry.frames(forMS: exposureMS))
                #expect(probe.maskFrames > 0)
            } else {
                #expect(probe.exposureFrames == probe.responseWindowFrames)
                #expect(probe.maskFrames == 0)
            }
            #expect(probe.expected == (spec.stimulus.kind == .shoot ? .shoot : nil))
        }
    }

    @Test func bothTargetsOfAPairStayOnScreen() {
        for (geometry, fit) in Displays.all {
            let drill = NoShootDiscriminator(geometry: geometry, fit: fit)
            #expect(drill.fitsScreen)
            var rng = SeededRNG(seed: 10)
            for difficulty in NoShootDiscriminator.levels.indices {
                for _ in 0..<200 {
                    let stimulus = drill.makeTrial(difficulty: difficulty, rng: &rng).stimulus
                    let size = stimulus.size
                    #expect(fit.contains(stimulus.center, halfWidth: size.halfWidth, halfHeight: size.halfHeight))
                    if stimulus.overlap > 0 {
                        let shift = size.widthDeg * (1 - stimulus.overlap)
                        let front = DegreePoint(
                            x: stimulus.center.x + (stimulus.overlapSide == .right ? shift : -shift),
                            y: stimulus.center.y)
                        #expect(fit.contains(front, halfWidth: size.halfWidth, halfHeight: size.halfHeight))
                    }
                }
            }
        }
    }

    @Test func gradesShootAndNoShootTrials() throws {
        var rng = SeededRNG(seed: 11)
        var specs: [NoShootDiscriminator.Kind: TrialSpec<NoShootDiscriminator.Stimulus, NoShootDiscriminator.Response>] = [:]
        while specs.count < 2 {
            let spec = drill.makeTrial(difficulty: 0, rng: &rng)
            specs[spec.stimulus.kind] = spec
        }
        let shoot = try #require(specs[.shoot])
        let noShoot = try #require(specs[.noShoot])
        let press = ProbeAnswer(response: NoShootDiscriminator.Response.shoot, rtSeconds: 0.35)

        let cases: [(TrialEvaluation, ProbeOutcome, Bool)] = [
            (drill.evaluate(shoot, answers: [press]), .correct, true),
            (drill.evaluate(shoot, answers: [nil]), .noAnswer, false),
            (drill.evaluate(noShoot, answers: [press]), .shotNoShoot, false),
            (drill.evaluate(noShoot, answers: [nil]), .withheld, true),
        ]
        for (evaluation, outcome, correct) in cases {
            #expect(evaluation.outcomes == [outcome])
            #expect(evaluation.correctForStaircase == correct)
        }
    }

    @Test func parsesSpaceOnly() {
        var rng = SeededRNG(seed: 12)
        let probe = drill.makeTrial(difficulty: 0, rng: &rng).probes[0]
        #expect(drill.parse([.key(.direction(.left))], for: probe) == .ignored)
        #expect(drill.parse([.key(.shoot)], for: probe) == .complete(.shoot))
    }

    @Test func policyHasTheFalseAlarmGateAndNoThreshold() throws {
        guard case .staircase(let config) = drill.policy else {
            Issue.record("D3 should use a staircase")
            return
        }
        #expect(config.gate == FalseAlarmGate(maxRate: 0.2, window: 10))
        #expect(config.thresholdLadder == nil)
        #expect(config.stop.maxTrials == 60)
        #expect(config.levelCount == NoShootDiscriminator.levels.count)
    }
}
