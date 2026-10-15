import Foundation

/// Why a trial didn't count. The raw value is what DilatedData stores.
public enum InvalidReason: String, Sendable, Codable, CaseIterable {
    case droppedFrame = "dropped_frame"
    case falseStart = "false_start"
    case anticipation
}

public enum EndReason: String, Sendable, Codable, CaseIterable {
    case finished
    /// Too many invalid trials (arch.md §8.1). Saved, but never counts toward thresholds or PBs.
    case aborted
    case quit
}

/// One probe as it happened. Times are system-uptime seconds.
public struct ProbeResult: Sendable, Codable, Equatable {
    public var index: Int
    /// Real on-glass time if the Metal clock confirmed it, else the frame-tick estimate. nil if never shown.
    public var onsetUptime: Double?
    public var onsetConfirmed: Bool
    public var responseUptime: Double?
    public var rtSeconds: Double?
    public var answerJSON: Data?
    /// nil on invalid trials.
    public var outcome: ProbeOutcome?
    public var zone: ScoreZone?
    public var windowSeconds: Double
    public var par: Double

    public init(
        index: Int,
        onsetUptime: Double?,
        onsetConfirmed: Bool,
        responseUptime: Double?,
        rtSeconds: Double?,
        answerJSON: Data?,
        outcome: ProbeOutcome?,
        zone: ScoreZone?,
        windowSeconds: Double,
        par: Double
    ) {
        self.index = index
        self.onsetUptime = onsetUptime
        self.onsetConfirmed = onsetConfirmed
        self.responseUptime = responseUptime
        self.rtSeconds = rtSeconds
        self.answerJSON = answerJSON
        self.outcome = outcome
        self.zone = zone
        self.windowSeconds = windowSeconds
        self.par = par
    }
}

/// One trial attempt, valid or not.
public struct TrialOutcome: Sendable, Codable, Equatable {
    public var index: Int
    public var difficulty: Int
    public var stimulusJSON: Data
    /// nil if the trial was invalid.
    public var evaluation: TrialEvaluation?
    public var invalidReason: InvalidReason?
    public var probes: [ProbeResult]

    public init(
        index: Int,
        difficulty: Int,
        stimulusJSON: Data,
        evaluation: TrialEvaluation?,
        invalidReason: InvalidReason?,
        probes: [ProbeResult]
    ) {
        self.index = index
        self.difficulty = difficulty
        self.stimulusJSON = stimulusJSON
        self.evaluation = evaluation
        self.invalidReason = invalidReason
        self.probes = probes
    }

    public var isValid: Bool {
        invalidReason == nil
    }
}

/// Everything a finished run hands to DilatedData in one call (arch.md §8.2).
/// Plain values, so it can cross from the main actor to `ResultsStore`.
public struct RunOutcome: Sendable {
    public var drillID: DrillID
    public var drillVersion: Int
    public var seed: UInt64
    public var startDifficulty: Int
    public var endDifficulty: Int
    /// Only for finished runs of drills that report one.
    public var threshold: Double?
    public var endReason: EndReason
    public var trials: [TrialOutcome]
    /// From valid trials only.
    public var score: RunScore

    public init(
        drillID: DrillID,
        drillVersion: Int,
        seed: UInt64,
        startDifficulty: Int,
        endDifficulty: Int,
        threshold: Double?,
        endReason: EndReason,
        trials: [TrialOutcome],
        score: RunScore
    ) {
        self.drillID = drillID
        self.drillVersion = drillVersion
        self.seed = seed
        self.startDifficulty = startDifficulty
        self.endDifficulty = endDifficulty
        self.threshold = threshold
        self.endReason = endReason
        self.trials = trials
        self.score = score
    }
}

/// JSON for stored stimuli and answers. Sorted keys keep it stable for replays and diffs.
public enum RecordCoding {
    public static func encode<Value: Encodable>(_ value: Value) -> Data {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys]
        encoder.nonConformingFloatEncodingStrategy = .convertToString(
            positiveInfinity: "inf", negativeInfinity: "-inf", nan: "nan")
        // Plain value types, with non-finite floats handled above: encoding can't fail.
        return try! encoder.encode(value)
    }
}
