/// Eight directions. The Tumbling E uses the four cardinal ones; D4 uses all eight.
public enum Direction: String, Sendable, Codable, CaseIterable {
    case up, upRight, right, downRight, down, downLeft, left, upLeft

    public static let cardinal: [Direction] = [.up, .right, .down, .left]

    public var isCardinal: Bool {
        Self.cardinal.contains(self)
    }
}
