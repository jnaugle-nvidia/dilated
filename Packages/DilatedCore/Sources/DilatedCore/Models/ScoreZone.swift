/// USPSA-style zones for the game score (arch.md §7.4). The raw value is what DilatedData stores.
public enum ScoreZone: String, Sendable, Codable, CaseIterable {
    case alpha = "A"
    case charlie = "C"
    case delta = "D"
    case miss = "M"
    case noShoot = "NS"
    case withheld = "W"
}

public enum PowerFactor: String, Sendable, Codable, CaseIterable {
    case minor
    case major
}
