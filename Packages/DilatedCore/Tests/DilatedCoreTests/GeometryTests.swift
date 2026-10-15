import Testing
@testable import DilatedCore

struct GeometryTests {
    /// arch.md §7.3: 18 in at 10 yd ≈ 2.86° (≈ 30 mm at 60 cm); a 6 in A-zone ≈ 0.95°.
    @Test func uspsaTargetAtTenYards() {
        let size = TargetSize.uspsa(atYards: 10)
        #expect(abs(size.widthDeg - 2.864) < 0.001)
        let millimeters = DisplayGeometry(pointsPerMM: 1, refreshHz: 60)
        #expect(abs(VisualAngle.points(forDegrees: size.widthDeg, geometry: millimeters) - 30) < 0.01)
        #expect(abs(RealWorldScale.degrees(inches: USPSATarget.aZoneWidthInches, atYards: 10) - 0.955) < 0.001)
    }

    /// arch.md §15.1: degrees → points → degrees within 0.001°.
    @Test func degreesAndPointsRoundTrip() {
        let geometry = Displays.macBookPro14
        for degrees in stride(from: 0.1, through: 40, by: 0.7) {
            let size = VisualAngle.points(forDegrees: degrees, geometry: geometry)
            #expect(abs(VisualAngle.degrees(forPoints: size, geometry: geometry) - degrees) < 0.001)
            let offset = VisualAngle.offsetPoints(forDegrees: degrees, geometry: geometry)
            #expect(abs(VisualAngle.degrees(forOffsetPoints: offset, geometry: geometry) - degrees) < 0.001)
        }
    }

    /// arch.md §7.3 table: a 14″ MacBook Pro's whole panel is ±14.1° × ±9.3° at 600 mm.
    @Test func screenFitMatchesTheArchDocTable() {
        let fit = ScreenFit(viewWidthPoints: 1512, viewHeightPoints: 982, geometry: Displays.macBookPro14)
        #expect(abs(fit.halfWidthDeg - 14.1) < 0.05)
        #expect(abs(fit.halfHeightDeg - 9.3) < 0.05)
    }

    @Test func randomCentersStayInside() {
        let fit = Displays.macBookPro14Fit
        let size = TargetSize.uspsa(atYards: 10)
        var rng = SeededRNG(seed: 1)
        for _ in 0..<1_000 {
            let center = try! #require(fit.randomCenter(halfWidth: size.halfWidth, halfHeight: size.halfHeight, rng: &rng))
            #expect(fit.contains(center, halfWidth: size.halfWidth, halfHeight: size.halfHeight))
        }
    }

    @Test func randomCenterIsNilWhenTheBoxCannotFit() {
        var rng = SeededRNG(seed: 1)
        #expect(Displays.macBookPro14Fit.randomCenter(halfWidth: 20, halfHeight: 1, rng: &rng) == nil)
    }
}
