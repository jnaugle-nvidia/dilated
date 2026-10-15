import DilatedCore

/// Everything a run needs besides the drill itself.
public struct RunSetup: Sendable {
    public var geometry: DisplayGeometry
    public var fit: ScreenFit
    public var seed: UInt64
    public var startDifficulty: Int
    public var powerFactor: PowerFactor
    public var timing: RunTiming

    public init(
        geometry: DisplayGeometry,
        fit: ScreenFit,
        seed: UInt64,
        startDifficulty: Int = 0,
        powerFactor: PowerFactor = .minor,
        timing: RunTiming = RunTiming()
    ) {
        self.geometry = geometry
        self.fit = fit
        self.seed = seed
        self.startDifficulty = startDifficulty
        self.powerFactor = powerFactor
        self.timing = timing
    }
}

/// Run-level timing and limits (arch.md §8.1, §8.4).
public struct RunTiming: Sendable, Equatable {
    /// Random wait between "STANDBY" and the beep.
    public var standbyMS: ClosedRange<Double> = 1000...3000
    public var feedbackMS = 150.0
    /// Long enough to read "False start" or "Frames dropped".
    public var invalidFeedbackMS = 800.0
    public var pauseAfterInvalidInARow = 3
    public var abortAfterInvalid = 10
    /// A gap between ticks longer than this many frames during Stimulus or Mask is a dropped frame.
    public var droppedFrameGap = 1.5

    public init() {}
}

/// What the scene draws on the current frame.
public enum Presentation: Sendable, Equatable {
    case blank
    case standby
    case fixation
    case probe(index: Int, phase: ProbePhase)
    case feedback([ProbeOutcome])
    case invalid(InvalidReason)
    case paused(PauseReason)
    case finished
}

public enum ProbePhase: Sendable, Equatable {
    /// The stimulus is on screen.
    case visible
    /// The mask covers it.
    case masked
    /// Mask done; the player can still answer until the window ends.
    case awaiting
}

public enum PauseReason: Sendable, Equatable {
    /// Esc.
    case player
    case tooManyInvalid(InvalidReason)
}
