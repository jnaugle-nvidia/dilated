import DilatedCore
import Observation

/// Drives one drill run, one frame and one input at a time (arch.md §8.1–§8.2).
///
/// It never uses timers: every duration is counted in frames. Each `onFrame` decides what that
/// frame shows (`presentation`); the scene reads it and draws. A probe's onset is the tick time
/// of its first visible frame, replaced by the real on-glass time if `onPresented` reports it.
@MainActor @Observable
public final class TrialRunner<Drill: DrillDefinition>: DrillRunning {
    public let drill: Drill
    public let setup: RunSetup

    /// What the scene draws on the current frame.
    public private(set) var presentation: Presentation = .blank
    /// The trial being shown, for drawing.
    public private(set) var currentSpec: TrialSpec<Drill.Stimulus, Drill.Response>?
    /// Every attempt so far, valid or not, in order.
    public private(set) var trials: [TrialOutcome] = []
    public private(set) var endReason: EndReason?

    @ObservationIgnored public var onBeep: (() -> Void)?

    @ObservationIgnored private var state: State = .idle
    @ObservationIgnored private var frameInState = 0
    @ObservationIgnored private var tracker: AdaptiveTracker
    @ObservationIgnored private let startDifficulty: Int
    @ObservationIgnored private var rng: SeededRNG
    /// Separate from `rng`, so pausing before the beep doesn't change which trials come.
    @ObservationIgnored private var standbyRNG: SeededRNG
    @ObservationIgnored private var trial: TrialInProgress?
    @ObservationIgnored private var trialSerial = 0
    @ObservationIgnored private var hasBeeped = false
    @ObservationIgnored private var lastTick: FrameTick?
    /// Set while the frame just shown was a probe's stimulus or mask.
    @ObservationIgnored private var lastStimulusFrame: FrameRole?
    /// Stimulus and mask frames still waiting for a presented time.
    @ObservationIgnored private var pendingFrames: [Int: FrameRole] = [:]
    @ObservationIgnored private var invalidInARow = 0
    @ObservationIgnored private var invalidTotal = 0

    private enum State: Equatable {
        case idle
        case standby(frames: Int)
        case fixation(frames: Int)
        case probe(Int)
        case feedback(frames: Int)
        case paused(PauseReason)
        case finished
    }

    private struct TrialInProgress {
        let serial: Int
        let difficulty: Int
        let spec: TrialSpec<Drill.Stimulus, Drill.Response>
        var probes: [ProbeProgress]
        var invalidReason: InvalidReason?
        /// Set when feedback starts. Correctness doesn't depend on onset, so it can't change later.
        var evaluation: TrialEvaluation?
    }

    private struct ProbeProgress {
        var estimatedOnset: Double?
        var presentedOnset: Double?
        var lastPresented: Double?
        var inputs: [PlayerInput] = []
        var answer: Drill.Response?
        var answerTime: Double?

        var onset: Double? {
            presentedOnset ?? estimatedOnset
        }
    }

    private struct FrameRole {
        let serial: Int
        let probe: Int
        let isOnset: Bool
    }

    public init(drill: Drill, setup: RunSetup) {
        self.drill = drill
        self.setup = setup
        let tracker = AdaptiveTracker(policy: drill.policy, startDifficulty: setup.startDifficulty)
        self.tracker = tracker
        self.startDifficulty = tracker.difficulty
        self.rng = SeededRNG(seed: setup.seed)
        self.standbyRNG = SeededRNG(seed: setup.seed ^ 0x5354_414E_4442_5900)
    }

    public var drillID: DrillID {
        Drill.id
    }

    public var fitsScreen: Bool {
        drill.fitsScreen
    }

    public var isFinished: Bool {
        state == .finished
    }

    /// The current probe's onset: the real on-glass time if known, else the estimate.
    var currentProbeOnset: Double? {
        guard case .probe(let index) = state else { return nil }
        return trial?.probes[index].onset
    }

    // MARK: Run control

    public func start() {
        guard state == .idle else { return }
        enter(.standby(frames: standbyFrames()))
    }

    public func pause() {
        switch state {
        case .idle, .paused, .finished:
            return
        case .feedback:
            // The trial is done: keep it, then pause before the next one.
            finishTrial()
            guard case .fixation = state else { return }
            abandonTrial()
            enter(.paused(.player))
        case .standby, .fixation, .probe:
            abandonTrial()
            enter(.paused(.player))
        }
    }

    public func resume() {
        guard case .paused = state else { return }
        invalidInARow = 0
        if hasBeeped {
            beginTrial()
        } else {
            enter(.standby(frames: standbyFrames()))
        }
    }

    public func quit() {
        guard !isFinished else { return }
        abandonTrial()
        finish(.quit)
    }

    public func outcome() -> RunOutcome {
        precondition(isFinished, "Ask for the outcome once the run has finished")
        let scorer = HitFactorScorer(powerFactor: setup.powerFactor)
        let scored = trials.filter(\.isValid).flatMap { trial in
            trial.probes.compactMap { probe in
                probe.outcome.map {
                    ScoredProbe(outcome: $0, rtSeconds: probe.rtSeconds, windowSeconds: probe.windowSeconds, par: probe.par)
                }
            }
        }
        let reason = endReason ?? .quit
        return RunOutcome(
            drillID: Drill.id,
            drillVersion: Drill.version,
            seed: setup.seed,
            startDifficulty: startDifficulty,
            endDifficulty: tracker.difficulty,
            threshold: reason == .finished ? tracker.threshold : nil,
            endReason: reason,
            trials: trials,
            score: scorer.score(scored))
    }

    // MARK: Frames and input

    public func onFrame(_ tick: FrameTick) {
        checkForDroppedFrame(tick)
        advance()
        present(tick)
        frameInState += 1
        lastTick = tick
    }

    public func onInput(_ input: PlayerInput) {
        guard var current = trial else { return }
        switch state {
        case .fixation:
            if case .ignored = drill.parse([input], for: current.spec.probes[0]) { return }
            invalidate(.falseStart)
        case .probe(let index):
            let probe = current.spec.probes[index]
            let inputs = current.probes[index].inputs + [input]
            let parse = drill.parse(inputs, for: probe)
            if case .ignored = parse { return }
            // Pressed before the probe reached the screen, or faster than anyone can react: a guess.
            guard let onset = current.probes[index].onset, input.timestamp - onset >= probe.minRTSeconds else {
                invalidate(.anticipation)
                return
            }
            current.probes[index].inputs = inputs
            if case .complete(let response) = parse {
                current.probes[index].answer = response
                current.probes[index].answerTime = input.timestamp
                trial = current
                endProbe(index)
            } else {
                trial = current
            }
        case .idle, .standby, .feedback, .paused, .finished:
            return
        }
    }

    public func onPresented(frameIndex: Int, presentedTime: Double) {
        guard let role = pendingFrames.removeValue(forKey: frameIndex),
              var current = trial, current.serial == role.serial
        else { return }
        guard presentedTime > 0 else {
            invalidate(.droppedFrame)   // that stimulus or mask frame never reached the glass
            return
        }
        var progress = current.probes[role.probe]
        if role.isOnset {
            progress.presentedOnset = presentedTime
        }
        let maxGap = setup.timing.droppedFrameGap * frameSeconds
        let gapTooLong = progress.lastPresented.map { presentedTime - $0 > maxGap } ?? false
        progress.lastPresented = presentedTime
        current.probes[role.probe] = progress
        trial = current
        if gapTooLong {
            invalidate(.droppedFrame)
        }
    }

    // MARK: State machine

    private var frameSeconds: Double {
        setup.geometry.frameMS / 1000
    }

    private func enter(_ next: State) {
        state = next
        frameInState = 0
    }

    private func duration(of state: State) -> Int {
        switch state {
        case .standby(let frames), .fixation(let frames), .feedback(let frames):
            frames
        case .probe(let index):
            trial?.spec.probes[index].responseWindowFrames ?? 0
        case .idle, .paused, .finished:
            .max
        }
    }

    /// Leave every state whose frames are used up. Runs before the frame is presented.
    private func advance() {
        while frameInState >= duration(of: state) {
            switch state {
            case .standby:
                hasBeeped = true
                onBeep?()
                beginTrial()
            case .fixation:
                enter(.probe(0))
            case .probe(let index):
                endProbe(index)   // the window ran out
            case .feedback:
                finishTrial()
            case .idle, .paused, .finished:
                return
            }
        }
    }

    private func present(_ tick: FrameTick) {
        lastStimulusFrame = nil
        switch state {
        case .idle:
            show(.blank)
        case .standby:
            show(.standby)
        case .fixation:
            show(.fixation)
        case .probe(let index):
            guard var current = trial else { return }
            let probe = current.spec.probes[index]
            let phase: ProbePhase =
                if frameInState < probe.exposureFrames { .visible }
                else if frameInState < probe.exposureFrames + probe.maskFrames { .masked }
                else { .awaiting }
            if frameInState == 0 {
                current.probes[index].estimatedOnset = tick.timestamp
                trial = current
            }
            if phase != .awaiting {
                let role = FrameRole(serial: current.serial, probe: index, isOnset: frameInState == 0)
                lastStimulusFrame = role
                pendingFrames[tick.index] = role
            }
            show(.probe(index: index, phase: phase))
        case .feedback:
            if let reason = trial?.invalidReason {
                show(.invalid(reason))
            } else {
                show(.feedback(trial?.evaluation?.outcomes ?? []))
            }
        case .paused(let reason):
            show(.paused(reason))
        case .finished:
            show(.finished)
        }
        if pendingFrames.count > 240 {
            pendingFrames = pendingFrames.filter { $0.key > tick.index - 120 }
        }
    }

    /// Only publish changes, so SwiftUI isn't invalidated every frame.
    private func show(_ next: Presentation) {
        if presentation != next {
            presentation = next
        }
    }

    /// A late tick while the stimulus or mask was up means it stayed on screen too long.
    private func checkForDroppedFrame(_ tick: FrameTick) {
        guard let lastTick, let last = lastStimulusFrame,
              let current = trial, current.serial == last.serial,
              case .probe(let index) = state, index == last.probe,
              tick.timestamp - lastTick.timestamp > setup.timing.droppedFrameGap * tick.duration
        else { return }
        invalidate(.droppedFrame)
    }

    private func standbyFrames() -> Int {
        setup.geometry.frames(forMS: standbyRNG.double(in: setup.timing.standbyMS))
    }

    private func beginTrial() {
        let difficulty = tracker.difficulty
        let spec = drill.makeTrial(difficulty: difficulty, rng: &rng)
        trialSerial += 1
        trial = TrialInProgress(
            serial: trialSerial,
            difficulty: difficulty,
            spec: spec,
            probes: Array(repeating: ProbeProgress(), count: spec.probes.count))
        currentSpec = spec
        enter(.fixation(frames: spec.foreperiodFrames))
    }

    private func endProbe(_ index: Int) {
        guard var current = trial else { return }
        if index + 1 < current.spec.probes.count {
            enter(.probe(index + 1))
            return
        }
        let answers = current.probes.map { progress -> ProbeAnswer<Drill.Response>? in
            guard let answer = progress.answer, let time = progress.answerTime, let onset = progress.onset else { return nil }
            return ProbeAnswer(response: answer, rtSeconds: time - onset)
        }
        current.evaluation = drill.evaluate(current.spec, answers: answers)
        trial = current
        enter(.feedback(frames: setup.geometry.frames(forMS: setup.timing.feedbackMS)))
    }

    private func invalidate(_ reason: InvalidReason) {
        guard var current = trial, current.invalidReason == nil else { return }
        current.invalidReason = reason
        trial = current
        // Already in feedback (a late presented time): the record will still say invalid.
        if case .feedback = state { return }
        enter(.feedback(frames: setup.geometry.frames(forMS: setup.timing.invalidFeedbackMS)))
    }

    /// Record the trial, then start the next one, pause, or end the run.
    private func finishTrial() {
        guard let current = trial else { return }
        trial = nil
        pendingFrames.removeAll()
        trials.append(record(current))

        if let reason = current.invalidReason {
            invalidInARow += 1
            invalidTotal += 1
            if invalidTotal >= setup.timing.abortAfterInvalid {
                finish(.aborted)
                return
            }
            if invalidInARow >= setup.timing.pauseAfterInvalidInARow {
                enter(.paused(.tooManyInvalid(reason)))
                return
            }
        } else {
            invalidInARow = 0
            if let evaluation = current.evaluation {
                tracker.record(evaluation)
            }
            if tracker.isFinished {
                finish(.finished)
                return
            }
        }
        beginTrial()   // an invalid trial is replaced by a fresh one at the same difficulty
    }

    private func record(_ trial: TrialInProgress) -> TrialOutcome {
        let valid = trial.invalidReason == nil
        let par = drill.par(difficulty: trial.difficulty)
        let probes = trial.spec.probes.indices.map { index -> ProbeResult in
            let progress = trial.probes[index]
            var rt: Double?
            if let time = progress.answerTime, let onset = progress.onset {
                rt = time - onset
            }
            let outcome = valid ? trial.evaluation?.outcomes[index] : nil
            return ProbeResult(
                index: index,
                onsetUptime: progress.onset,
                onsetConfirmed: progress.presentedOnset != nil,
                responseUptime: progress.answerTime,
                rtSeconds: rt,
                answerJSON: progress.answer.map { RecordCoding.encode($0) },
                outcome: outcome,
                zone: outcome.map { HitFactorScorer.zone(for: $0, rtSeconds: rt, par: par) },
                windowSeconds: setup.geometry.ms(forFrames: trial.spec.probes[index].responseWindowFrames) / 1000,
                par: par)
        }
        return TrialOutcome(
            index: trials.count,
            difficulty: trial.difficulty,
            stimulusJSON: RecordCoding.encode(trial.spec.stimulus),
            evaluation: valid ? trial.evaluation : nil,
            invalidReason: trial.invalidReason,
            probes: probes)
    }

    private func abandonTrial() {
        trial = nil
        pendingFrames.removeAll()
        lastStimulusFrame = nil
    }

    private func finish(_ reason: EndReason) {
        endReason = reason
        enter(.finished)
        show(.finished)
    }
}
