/// What the player did, after DilatedEngine's `KeyBindings` has turned a key or click into meaning.
public enum PlayerAction: Sendable, Codable, Equatable {
    case direction(Direction)
    case shoot
    case letter(String)
    case click(DegreePoint)
}

public struct PlayerInput: Sendable, Codable, Equatable {
    public var action: PlayerAction
    /// `NSEvent.timestamp`: system-uptime seconds, the same clock as frame times (arch.md §8.4).
    public var timestamp: Double

    public init(action: PlayerAction, timestamp: Double) {
        self.action = action
        self.timestamp = timestamp
    }
}
