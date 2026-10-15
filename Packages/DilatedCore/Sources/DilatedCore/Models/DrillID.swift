/// Every drill in arch.md §2. The raw value is what DilatedData stores.
public enum DrillID: String, Sendable, Codable, CaseIterable {
    case flashAcquire
    case transitionLadder
    case noShootDiscriminator
    case peripheralPickup
    case moverRead
    case stageScan
    case schulteGrid
}
