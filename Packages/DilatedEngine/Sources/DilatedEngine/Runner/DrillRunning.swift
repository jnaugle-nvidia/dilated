import DilatedCore

/// What the app holds. Lets one program run D1, D2 and D3 in a row without knowing their types (arch.md §8.2).
@MainActor
public protocol DrillRunning: AnyObject {
    var drillID: DrillID { get }
    var fitsScreen: Bool { get }
    var presentation: Presentation { get }
    var isFinished: Bool { get }
    var onBeep: (() -> Void)? { get set }

    func start()
    func onFrame(_ tick: FrameTick)
    func onPresented(frameIndex: Int, presentedTime: Double)
    func onInput(_ input: PlayerInput)
    func pause()
    func resume()
    func quit()
    /// Call once the run is finished.
    func outcome() -> RunOutcome
}

/// The only `switch` over drill IDs in the app.
@MainActor
public enum DrillRegistry {
    /// Drills that have a runner today. The rest arrive in Phase 2.
    public static let available: [DrillID] = [.flashAcquire, .transitionLadder, .noShootDiscriminator]

    public static func makeRunner(for id: DrillID, setup: RunSetup) -> (any DrillRunning)? {
        switch id {
        case .flashAcquire:
            TrialRunner(drill: FlashAcquire(geometry: setup.geometry, fit: setup.fit), setup: setup)
        case .transitionLadder:
            TrialRunner(drill: TransitionLadder(geometry: setup.geometry, fit: setup.fit), setup: setup)
        case .noShootDiscriminator:
            TrialRunner(drill: NoShootDiscriminator(geometry: setup.geometry, fit: setup.fit), setup: setup)
        case .peripheralPickup, .moverRead, .stageScan, .schulteGrid:
            nil
        }
    }
}
