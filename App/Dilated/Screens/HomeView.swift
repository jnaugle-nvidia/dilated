import DilatedCore
import DilatedEngine
import SwiftUI

struct HomeView: View {
    @State private var running: SessionChoice? = HomeView.launchChoice()
    @State private var clock = ClockChoice.spriteKit

    /// Developer hook for previews and UI tests: launching with
    /// `-previewDrill flashAcquire -previewClock metal` starts that drill straight away.
    private static func launchChoice() -> SessionChoice? {
        let defaults = UserDefaults.standard
        guard let drill = defaults.string(forKey: "previewDrill").flatMap(DrillID.init(rawValue:)) else { return nil }
        let clock = defaults.string(forKey: "previewClock").flatMap(ClockChoice.init(rawValue:)) ?? .spriteKit
        return SessionChoice(drill: drill, clock: clock)
    }

    var body: some View {
        if let running {
            SessionView(choice: running) { self.running = nil }
        } else {
            // Title on the upper lid, controls along the bottom: the pupil stays clear.
            VStack {
                Text("DILATED")
                    .font(.system(size: 56, weight: .heavy))
                    .tracking(14)
                    .foregroundStyle(.white)
                    .shadow(color: .black.opacity(0.7), radius: 16)
                    .padding(.top, 36)
                Spacer()
                VStack(spacing: 10) {
                    HStack(spacing: 10) {
                        ForEach(DrillRegistry.available, id: \.self) { drill in
                            Button(drill.title) {
                                running = SessionChoice(drill: drill, clock: clock)
                            }
                        }
                    }
                    .controlSize(.large)
                    HStack(spacing: 16) {
                        Picker("Frame clock", selection: $clock) {
                            ForEach(ClockChoice.allCases) { choice in
                                Text(choice.title).tag(choice)
                            }
                        }
                        .pickerStyle(.segmented)
                        .labelsHidden()
                        .fixedSize()
                        Text("Preview: no keyboard input yet; sizes use the display's own estimate.")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
                .padding(16)
                .background(.ultraThinMaterial, in: .rect(cornerRadius: 14))
                .padding(.bottom, 28)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background { TitleBackground() }
            .environment(\.colorScheme, .dark)
        }
    }
}

/// The eye key art, filling the window, darkened at the top and bottom so the text stays readable.
private struct TitleBackground: View {
    var body: some View {
        Image(.titleBackground)
            .resizable()
            .scaledToFill()
            .overlay {
                LinearGradient(
                    stops: [
                        .init(color: .black.opacity(0.55), location: 0),
                        .init(color: .clear, location: 0.25),
                        .init(color: .clear, location: 0.7),
                        .init(color: .black.opacity(0.7), location: 1),
                    ],
                    startPoint: .top,
                    endPoint: .bottom)
            }
            .ignoresSafeArea()
            .accessibilityHidden(true)
    }
}

extension DrillID {
    var title: String {
        switch self {
        case .flashAcquire: "Flash Acquire"
        case .transitionLadder: "Transition Ladder"
        case .noShootDiscriminator: "No-Shoot Discriminator"
        case .peripheralPickup: "Peripheral Pickup"
        case .moverRead: "Mover Read"
        case .stageScan: "Stage Scan"
        case .schulteGrid: "Schulte Grid"
        }
    }
}

#Preview {
    HomeView()
}
