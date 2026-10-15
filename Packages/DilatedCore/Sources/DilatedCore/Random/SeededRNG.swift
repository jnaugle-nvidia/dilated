/// SplitMix64: small, fast, and fully determined by its seed (arch.md §7.5).
///
/// Drills draw numbers through the helpers below, not `Int.random(in:using:)`. The standard
/// library does not promise the same numbers across Swift versions, and replays need that.
public struct SeededRNG: RandomNumberGenerator, Sendable, Codable, Equatable {
    public private(set) var state: UInt64

    public init(seed: UInt64) {
        state = seed
    }

    public mutating func next() -> UInt64 {
        state &+= 0x9E37_79B9_7F4A_7C15
        var z = state
        z = (z ^ (z >> 30)) &* 0xBF58_476D_1CE4_E5B9
        z = (z ^ (z >> 27)) &* 0x94D0_49BB_1331_11EB
        return z ^ (z >> 31)
    }

    /// Uniform in [0, 1), from the top 53 bits.
    public mutating func unit() -> Double {
        Double(next() >> 11) * 0x1p-53
    }

    /// Uniform in `range`.
    public mutating func double(in range: ClosedRange<Double>) -> Double {
        range.lowerBound + unit() * (range.upperBound - range.lowerBound)
    }

    /// Uniform in `range`, without modulo bias (Lemire's method).
    public mutating func int(in range: ClosedRange<Int>) -> Int {
        let span = UInt64(bitPattern: Int64(range.upperBound &- range.lowerBound)) &+ 1
        if span == 0 { return Int(truncatingIfNeeded: next()) }   // the full 64-bit range
        var product = next().multipliedFullWidth(by: span)
        if product.low < span {
            let threshold = (0 &- span) % span
            while product.low < threshold {
                product = next().multipliedFullWidth(by: span)
            }
        }
        return range.lowerBound &+ Int(truncatingIfNeeded: product.high)
    }

    /// True with probability `p`.
    public mutating func chance(_ p: Double) -> Bool {
        unit() < p
    }

    /// A uniformly chosen element. `items` must not be empty.
    public mutating func pick<T>(_ items: [T]) -> T {
        items[int(in: 0...(items.count - 1))]
    }

    /// Fisher–Yates shuffle.
    public mutating func shuffle<T>(_ items: inout [T]) {
        guard items.count > 1 else { return }
        for i in stride(from: items.count - 1, to: 0, by: -1) {
            items.swapAt(i, int(in: 0...i))
        }
    }
}
