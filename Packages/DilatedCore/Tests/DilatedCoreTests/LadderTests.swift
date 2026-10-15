import Testing
@testable import DilatedCore

struct LadderTests {
    /// arch.md §7.2: D1's ladder has about 25 levels at 120 Hz and 19 at 60 Hz.
    @Test(arguments: zip([120.0, 60.0], [25, 19]))
    func flashAcquireLadder(refreshHz: Double, levels: Int) {
        let geometry = DisplayGeometry(pointsPerMM: 5, refreshHz: refreshHz)
        let ladder = Ladder.exposure(fromMS: 500, geometry: geometry)
        #expect(ladder.values.count == levels)
        #expect(abs(ladder.values[0] - 500) < 1e-9)
        #expect(abs(ladder.values[ladder.hardest] - geometry.frameMS) < 1e-9)
        #expect(zip(ladder.values, ladder.values.dropFirst()).allSatisfy { $1 < $0 })
        for value in ladder.values {
            let frames = value / geometry.frameMS
            #expect(abs(frames - frames.rounded()) < 1e-9, "\(value) ms is not a whole frame")
        }
    }

    @Test func stopsAtTheDisplaysShortestExposure() {
        let geometry = DisplayGeometry(pointsPerMM: 5, refreshHz: 120, minExposureFrames: 3)
        let ladder = Ladder.exposure(fromMS: 500, geometry: geometry)
        #expect(geometry.frames(forMS: ladder.values[ladder.hardest]) == 3)
    }

    @Test func nearestDifficultyRoundTrips() {
        let ladder = Ladder.exposure(fromMS: 500, geometry: Displays.macBookPro14)
        for level in ladder.values.indices {
            #expect(ladder.difficulty(nearest: ladder.value(at: level)) == level)
        }
    }

    @Test func valueClampsToTheEnds() {
        let ladder = Ladder(values: [400, 200, 100], unit: .milliseconds)
        #expect(ladder.value(at: -5) == 400)
        #expect(ladder.value(at: 99) == 100)
    }
}
