/// Every drill makes trials, turns inputs into answers, and grades them. It never draws (arch.md §7.1).
///
/// Drill values are built per run with the display's geometry, the screen fit, and the player's settings.
public protocol DrillDefinition: Sendable {
    associatedtype Stimulus: Sendable & Codable
    associatedtype Response: Sendable & Codable & Equatable

    static var id: DrillID { get }
    /// Bump when trial generation or par changes (arch.md §7.4).
    static var version: Int { get }

    var policy: AdaptivePolicy { get }

    /// False if the drill's easiest setting doesn't fit the screen (arch.md §7.3).
    var fitsScreen: Bool { get }

    /// Par in seconds for a difficulty level (arch.md §7.4).
    func par(difficulty: Int) -> Double

    func makeTrial(difficulty: Int, rng: inout SeededRNG) -> TrialSpec<Stimulus, Response>

    /// Turn the inputs received so far for one probe (newest last) into an answer.
    func parse(_ inputs: [PlayerInput], for probe: Probe<Response>) -> AnswerParse<Response>

    /// Grade one finished trial. `answers[i]` is the answer to probe i, or nil if none came in time.
    func evaluate(_ spec: TrialSpec<Stimulus, Response>, answers: [ProbeAnswer<Response>?]) -> TrialEvaluation
}

/// The random wait before a trial's first probe, so onset can't be predicted (arch.md §8.1).
public enum Foreperiod {
    public static let rangeMS: ClosedRange<Double> = 400...900

    public static func frames(geometry: DisplayGeometry, rng: inout SeededRNG) -> Int {
        rng.int(in: geometry.frames(forMS: rangeMS.lowerBound)...geometry.frames(forMS: rangeMS.upperBound))
    }
}
