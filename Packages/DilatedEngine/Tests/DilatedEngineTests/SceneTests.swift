import AppKit
import DilatedCore
import SpriteKit
import Testing
@testable import DilatedEngine

let sceneSize = CGSize(width: 1512, height: 945)

/// SpriteKit keeps node positions as 32-bit floats.
func near(_ a: CGPoint, _ b: CGPoint) -> Bool {
    abs(a.x - b.x) < 0.01 && abs(a.y - b.y) < 0.01
}

@MainActor
struct SceneTests {
    @Test func degreesBecomePointsFromScreenCenter() {
        let h = flashAcquire()
        let scene = FlashAcquireScene(runner: h.runner, size: sceneSize)
        // 600 mm away at 5 pt/mm: 10° right is 600 · tan 10° · 5 ≈ 529 pt.
        let spot = scene.point(DegreePoint(x: 10, y: -5))
        #expect(abs(spot.x - 528.98) < 0.01)
        #expect(abs(spot.y + 262.47) < 0.01)
    }

    @Test func flashAcquireShowsTheRightNodesInEachPhase() throws {
        let h = flashAcquire()
        let scene = FlashAcquireScene(runner: h.runner, size: sceneSize)
        h.runner.start()
        h.step()
        scene.sync()
        #expect(scene.message.text == "STANDBY")
        #expect(!scene.message.isHidden)

        h.step(until: .fixation)
        scene.sync()
        let stimulus = try #require(h.runner.currentSpec?.stimulus)
        #expect(!scene.fixation.isHidden)
        #expect(near(scene.fixation.position, scene.point(stimulus.fixation)))
        #expect(scene.target.isHidden)
        #expect(scene.message.isHidden)

        h.step(until: .probe(index: 0, phase: .visible))
        scene.sync()
        #expect(!scene.target.isHidden)
        #expect(!scene.letterE.isHidden)
        #expect(scene.mask.isHidden)
        #expect(scene.fixation.isHidden)
        #expect(near(scene.letterE.position, scene.point(stimulus.target)))
        #expect(scene.letterE.zRotation == stimulus.eFacing.zRotation)

        h.step(until: .probe(index: 0, phase: .masked))
        scene.sync()
        #expect(scene.letterE.isHidden)
        #expect(!scene.mask.isHidden)
        #expect(!scene.target.isHidden)

        h.step(until: isFeedback)   // no answer: a miss
        scene.sync()
        #expect(!scene.missMark.isHidden)
        #expect(scene.hitRing.isHidden)
    }

    @Test func transitionLadderMovesTheEAlongTheArray() throws {
        let h = Harness(drill: TransitionLadder(geometry: geometry, fit: fit), geometry: geometry, fit: fit)
        let scene = TransitionLadderScene(runner: h.runner, size: sceneSize)
        h.runner.start()
        h.step(until: .fixation)
        scene.sync()
        let stimulus = try #require(h.runner.currentSpec?.stimulus)
        let count = stimulus.targets.count
        #expect(scene.targets.prefix(count).allSatisfy { !$0.isHidden })
        #expect(scene.targets.dropFirst(count).allSatisfy { $0.isHidden })
        #expect(scene.numbers.prefix(count).map(\.text) == (1...count).map { "\($0)" })
        #expect(near(scene.fixation.position, scene.point(stimulus.targets[0])))

        h.step(until: .probe(index: 0, phase: .visible))
        h.answer(.direction(stimulus.eFacings[0]), rt: 0.3)
        h.step()
        scene.sync()
        #expect(h.runner.presentation == .probe(index: 1, phase: .visible))
        #expect(near(scene.letterE.position, scene.point(stimulus.targets[1])))
        #expect(scene.letterE.zRotation == stimulus.eFacings[1].zRotation)
        #expect(scene.fixation.isHidden)
    }

    @Test func noShootShowsTheKindOverlapHardCoverAndMask() throws {
        // Level 8: a no-shoot in front, hard cover, 250 ms exposure, then the mask.
        let h = Harness(drill: NoShootDiscriminator(geometry: geometry, fit: fit), geometry: geometry, fit: fit, startDifficulty: 8)
        let scene = NoShootScene(runner: h.runner, size: sceneSize)
        h.runner.start()
        h.step(until: .probe(index: 0, phase: .visible))
        scene.sync()
        let stimulus = try #require(h.runner.currentSpec?.stimulus)
        let shoot = stimulus.kind == .shoot
        #expect(scene.shootTarget.isHidden == !shoot)
        #expect(scene.noShootBack.isHidden == shoot)
        #expect(!scene.noShootFront.isHidden)
        #expect(!scene.hardCover.isHidden)
        #expect(scene.mask.isHidden)

        h.step(until: .probe(index: 0, phase: .masked))
        scene.sync()
        #expect(!scene.mask.isHidden)
        #expect(scene.shootTarget.isHidden && scene.noShootBack.isHidden && scene.noShootFront.isHidden)

        h.step(until: .probe(index: 0, phase: .awaiting))
        scene.sync()
        #expect(scene.mask.isHidden)
        #expect(scene.shootTarget.isHidden && scene.noShootBack.isHidden)
    }
}

@MainActor
struct ClockAndSessionTests {
    @Test func spriteKitClockStampsEachTickWithThePresentLatency() {
        let clock = SpriteKitFrameClock(refreshHz: 120)
        var ticks: [FrameTick] = []
        clock.onTick = { ticks.append($0) }
        clock.tick(at: 100)
        clock.presentLatencyFrames = 2
        clock.tick(at: 100 + 1.0 / 120)
        #expect(ticks.map(\.index) == [0, 1])
        #expect(abs(ticks[0].timestamp - (100 + 1.0 / 120)) < 1e-12)
        #expect(abs(ticks[1].timestamp - (100 + 3.0 / 120)) < 1e-12)
        #expect(ticks.allSatisfy { abs($0.duration - 1.0 / 120) < 1e-12 })
    }

    @Test func sessionAdvancesTheRunnerThenSyncsTheScene() {
        let runner = TrialRunner(drill: FlashAcquire(geometry: geometry, fit: fit), setup: RunSetup(geometry: geometry, fit: fit, seed: 1))
        let scene = FlashAcquireScene(runner: runner, size: sceneSize)
        let session = DrillSession(runner: runner, scene: scene, clock: SpriteKitFrameClock(refreshHz: 120))
        session.start()
        scene.update(1_000)   // what SpriteKit calls once per frame
        #expect(runner.presentation == .standby)
        #expect(!scene.message.isHidden)
        session.stop()
        #expect(runner.isFinished)
    }

    @Test func metalClockBuildsItsViewPausedForTheDisplayLink() throws {
        let clock = try #require(MetalFrameClock(refreshHz: 120))
        #expect(clock.view.isPaused)
        #expect(!clock.view.enableSetNeedsDisplay)
        #expect(clock.view.delegate === clock)
    }

    @Test func registryBuildsASessionForEachMVPDrill() {
        let setup = RunSetup(geometry: geometry, fit: fit, seed: 1)
        for id in DrillID.allCases {
            let session = DrillRegistry.makeSession(for: id, setup: setup, clock: SpriteKitFrameClock(refreshHz: 120), sceneSize: sceneSize)
            #expect((session != nil) == DrillRegistry.available.contains(id))
            #expect(session?.runner.drillID ?? id == id)
        }
    }

    @Test func firstGuessGeometryComesFromTheScreen() throws {
        guard let screen = NSScreen.main else { return }   // no display attached
        let guess = try #require(DisplayGeometry.firstGuess(for: screen))
        #expect((2...10).contains(guess.pointsPerMM))
        #expect(guess.refreshHz >= 60)
        #expect(guess.viewingDistanceMM == 600)
    }
}
