import DilatedCore
@testable import DilatedEngine

/// Steps a runner frame by frame at a fixed refresh rate: the fake `FrameClock` from arch.md §15.1.
@MainActor
final class Harness<Drill: DrillDefinition> {
    let runner: TrialRunner<Drill>
    let frameDuration: Double
    private(set) var nextIndex = 0
    /// On-glass time of the next frame, system-uptime seconds.
    private(set) var now = 1_000.0
    private(set) var beeps = 0
    /// What every frame so far showed, and its tick.
    private(set) var shown: [Presentation] = []
    private(set) var ticks: [FrameTick] = []
    /// The first visible frame of the most recent probe.
    private(set) var onsetTick: FrameTick?

    init(drill: Drill, geometry: DisplayGeometry, fit: ScreenFit, seed: UInt64 = 1, startDifficulty: Int = 0) {
        runner = TrialRunner(
            drill: drill,
            setup: RunSetup(geometry: geometry, fit: fit, seed: seed, startDifficulty: startDifficulty))
        frameDuration = 1 / geometry.refreshHz
        runner.onBeep = { [unowned self] in self.beeps += 1 }
    }

    func step(_ count: Int = 1) {
        for _ in 0..<count {
            let tick = FrameTick(index: nextIndex, timestamp: now, duration: frameDuration)
            runner.onFrame(tick)
            if case .probe(let index, .visible) = runner.presentation, shown.last != runner.presentation,
               !isSameProbe(shown.last, index) {
                onsetTick = tick
            }
            shown.append(runner.presentation)
            ticks.append(tick)
            nextIndex += 1
            now += frameDuration
        }
    }

    /// Step until the frame just shown matches. False if it never does.
    @discardableResult
    func step(until condition: (Presentation) -> Bool, limit: Int = 200_000) -> Bool {
        for _ in 0..<limit {
            step()
            if condition(runner.presentation) { return true }
        }
        return false
    }

    @discardableResult
    func step(until presentation: Presentation, limit: Int = 200_000) -> Bool {
        step(until: { $0 == presentation }, limit: limit)
    }

    /// Lose `count` frames: the next tick arrives late.
    func drop(_ count: Int) {
        nextIndex += count
        now += Double(count) * frameDuration
    }

    /// Show every frame up to `time`, then deliver the input stamped `time`.
    func press(_ action: PlayerAction, at time: Double) {
        while now <= time { step() }
        runner.onInput(PlayerInput(action: action, timestamp: time))
    }

    /// Press 1 ms after the frame just shown.
    func pressNow(_ action: PlayerAction) {
        runner.onInput(PlayerInput(action: action, timestamp: (ticks.last?.timestamp ?? now) + 0.001))
    }

    /// Answer the current probe `rt` seconds after its estimated onset.
    func answer(_ action: PlayerAction, rt: Double) {
        press(action, at: onsetTick!.timestamp + rt)
    }

    /// Play until `done`. For each probe, `respond` gives the action and RT, or nil to stay silent.
    func play(
        until done: () -> Bool,
        respond: (TrialSpec<Drill.Stimulus, Drill.Response>, Int) -> (PlayerAction, Double)?
    ) {
        var handled: (attempt: Int, probe: Int)?
        while !done(), !runner.isFinished {
            step()
            guard case .probe(let index, _) = runner.presentation, let spec = runner.currentSpec else { continue }
            let attempt = runner.trials.count
            if let handled, handled.attempt == attempt, handled.probe == index { continue }
            handled = (attempt, index)
            guard let (action, rt) = respond(spec, index), let onset = onsetTick else { continue }
            let time = onset.timestamp + rt
            while now <= time, runner.trials.count == attempt, case .probe(index, _) = runner.presentation {
                step()
            }
            if runner.trials.count == attempt, case .probe(index, _) = runner.presentation {
                runner.onInput(PlayerInput(action: action, timestamp: time))
            }
        }
    }

    func count(_ presentation: Presentation) -> Int {
        shown.filter { $0 == presentation }.count
    }

    private func isSameProbe(_ previous: Presentation?, _ index: Int) -> Bool {
        if case .probe(index, _) = previous { true } else { false }
    }
}
