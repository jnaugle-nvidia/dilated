/// How one probe went. Scoring turns it into a zone (arch.md §7.4).
public enum ProbeOutcome: String, Sendable, Codable, CaseIterable {
    case correct
    case wrong
    case noAnswer = "no_answer"
    case shotNoShoot = "shot_no_shoot"
    case withheld

    /// Grade one probe. `expected == nil` means a no-shoot, where doing nothing is right.
    public static func grade<Response: Equatable>(_ answer: Response?, expected: Response?) -> ProbeOutcome {
        switch (expected, answer) {
        case (nil, nil): .withheld
        case (nil, _?): .shotNoShoot
        case (_?, nil): .noAnswer
        case let (expected?, answer?): answer == expected ? .correct : .wrong
        }
    }
}

public struct TrialEvaluation: Sendable, Codable, Equatable {
    /// One per probe.
    public var outcomes: [ProbeOutcome]
    public var countsForStaircase: Bool
    public var correctForStaircase: Bool

    public init(outcomes: [ProbeOutcome], countsForStaircase: Bool, correctForStaircase: Bool) {
        self.outcomes = outcomes
        self.countsForStaircase = countsForStaircase
        self.correctForStaircase = correctForStaircase
    }
}
