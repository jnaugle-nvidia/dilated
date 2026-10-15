import Testing
@testable import DilatedCore

struct SeededRNGTests {
    @Test func matchesSplitMix64Reference() {
        var rng = SeededRNG(seed: 1_234_567)
        let expected: [UInt64] = [
            6_457_827_717_110_365_317, 3_203_168_211_198_807_973, 9_817_491_932_198_370_423,
            4_593_380_528_125_082_431, 16_408_922_859_458_223_821,
        ]
        #expect((0..<5).map { _ in rng.next() } == expected)
    }

    @Test func sameSeedSameSequence() {
        var a = SeededRNG(seed: 42)
        var b = SeededRNG(seed: 42)
        #expect((0..<100).map { _ in a.int(in: 0...999) } == (0..<100).map { _ in b.int(in: 0...999) })
    }

    @Test func intCoversItsRangeEvenly() {
        var rng = SeededRNG(seed: 7)
        var counts = [Int](repeating: 0, count: 5)
        for _ in 0..<10_000 {
            counts[rng.int(in: 0...4)] += 1
        }
        #expect(counts.allSatisfy { (1_800...2_200).contains($0) }, "counts: \(counts)")
    }

    @Test func intHandlesNegativeAndSingleValueRanges() {
        var rng = SeededRNG(seed: 9)
        for _ in 0..<1_000 {
            #expect((-3...3).contains(rng.int(in: -3...3)))
            #expect(rng.int(in: 5...5) == 5)
        }
    }

    @Test func unitStaysInHalfOpenInterval() {
        var rng = SeededRNG(seed: 11)
        let values = (0..<10_000).map { _ in rng.unit() }
        #expect(values.allSatisfy { $0 >= 0 && $0 < 1 })
    }

    @Test func shuffleIsADeterministicPermutation() {
        var a = SeededRNG(seed: 3)
        var b = SeededRNG(seed: 3)
        var x = Array(0..<20)
        var y = Array(0..<20)
        a.shuffle(&x)
        b.shuffle(&y)
        #expect(x == y)
        #expect(x.sorted() == Array(0..<20))
        #expect(x != Array(0..<20))
    }
}
