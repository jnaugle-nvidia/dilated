@testable import DilatedCore

/// Real displays at the default 600 mm (arch.md §7.3).
enum Displays {
    /// 14″ MacBook Pro: 1512 × 982 pt across 302.4 mm, 120 Hz.
    static let macBookPro14 = DisplayGeometry(pointsPerMM: 1512 / 302.4, refreshHz: 120)
    /// Full screen loses the strip beside the notch: 1512 × 945 pt.
    static let macBookPro14Fit = ScreenFit(viewWidthPoints: 1512, viewHeightPoints: 945, geometry: macBookPro14)

    /// 27″ Studio Display: 2560 × 1440 pt across 596.7 mm, 60 Hz.
    static let studioDisplay = DisplayGeometry(pointsPerMM: 2560 / 596.7, refreshHz: 60)
    static let studioDisplayFit = ScreenFit(viewWidthPoints: 2560, viewHeightPoints: 1440, geometry: studioDisplay)

    static let all: [(DisplayGeometry, ScreenFit)] = [
        (macBookPro14, macBookPro14Fit),
        (studioDisplay, studioDisplayFit),
    ]
}

extension PlayerInput {
    static func key(_ action: PlayerAction) -> PlayerInput {
        PlayerInput(action: action, timestamp: 0)
    }
}
