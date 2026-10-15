import SwiftUI

@main
struct DilatedApp: App {
    var body: some Scene {
        WindowGroup {
            HomeView()
        }
        // Drills need room: D1 places targets 10° or more from fixation (arch.md §7.3).
        .defaultSize(width: 1400, height: 880)
    }
}
