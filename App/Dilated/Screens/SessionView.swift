import DilatedCore
import DilatedEngine
import MetalKit
import SpriteKit
import SwiftUI

enum ClockChoice: String, CaseIterable, Identifiable {
    case spriteKit
    case metal

    var id: Self { self }

    var title: String {
        switch self {
        case .spriteKit: "SpriteKit clock"
        case .metal: "Metal clock"
        }
    }
}

struct SessionChoice: Equatable {
    var drill: DrillID
    var clock: ClockChoice
}

/// One drill run, filling the window (arch.md §12). No HUD during trials.
struct SessionView: View {
    let choice: SessionChoice
    let onClose: () -> Void
    @State private var session: DrillSession?
    @State private var problem: String?

    var body: some View {
        GeometryReader { proxy in
            ZStack(alignment: .topTrailing) {
                Color(white: 0.5)
                if let session {
                    canvas(for: session)
                }
                if let problem {
                    Text(problem)
                        .font(.title3)
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                }
                Button("Stop") {
                    session?.stop()
                    onClose()
                }
                .padding()
            }
            .onAppear { start(size: proxy.size) }
        }
        .onDisappear { session?.stop() }
    }

    @ViewBuilder
    private func canvas(for session: DrillSession) -> some View {
        if let metal = session.clock as? MetalFrameClock {
            MetalCanvas(view: metal.view)
        } else {
            SpriteView(
                scene: session.scene,
                preferredFramesPerSecond: NSScreen.main?.maximumFramesPerSecond ?? 60,
                debugOptions: [.showsFPS])
        }
    }

    private func start(size: CGSize) {
        guard session == nil else { return }
        guard let screen = NSScreen.main, let geometry = DisplayGeometry.firstGuess(for: screen) else {
            problem = "Couldn't read this display's size."
            return
        }
        let fit = ScreenFit(viewWidthPoints: size.width, viewHeightPoints: size.height, geometry: geometry)
        let setup = RunSetup(geometry: geometry, fit: fit, seed: .random(in: .min ... .max))
        let clock: any FrameClock =
            switch choice.clock {
            case .spriteKit: SpriteKitFrameClock(refreshHz: geometry.refreshHz)
            case .metal: MetalFrameClock(refreshHz: geometry.refreshHz) ?? SpriteKitFrameClock(refreshHz: geometry.refreshHz)
            }
        guard let session = DrillRegistry.makeSession(for: choice.drill, setup: setup, clock: clock, sceneSize: size) else {
            problem = "\(choice.drill.title) isn't built yet."
            return
        }
        guard session.runner.fitsScreen else {
            problem = "\(choice.drill.title) doesn't fit this window. Make it bigger, or sit closer."
            return
        }
        session.start()
        self.session = session
    }
}

/// Hosts `MetalFrameClock`'s view, which draws the scene on its own display link.
struct MetalCanvas: NSViewRepresentable {
    let view: MTKView

    func makeNSView(context: Context) -> MTKView {
        view
    }

    func updateNSView(_ nsView: MTKView, context: Context) {}
}
