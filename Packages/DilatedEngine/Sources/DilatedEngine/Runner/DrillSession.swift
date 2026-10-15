import AppKit
import DilatedCore
import Foundation

/// Wires a runner, its scene, and a frame clock: each tick advances the runner, then the
/// scene matches it before the frame is drawn.
@MainActor
public final class DrillSession {
    public let runner: any DrillRunning
    public let scene: DrillScene
    public let clock: any FrameClock
    private var activity: NSObjectProtocol?

    public init(runner: any DrillRunning, scene: DrillScene, clock: any FrameClock) {
        self.runner = runner
        self.scene = scene
        self.clock = clock
        clock.attach(scene)
        clock.onTick = { [weak self] tick in
            guard let self else { return }
            self.runner.onFrame(tick)
            self.scene.sync()
        }
        clock.onPresented = { [weak runner] index, time in
            runner?.onPresented(frameIndex: index, presentedTime: time)
        }
    }

    /// Keep the Mac awake and fast (arch.md §8.4), then STANDBY.
    public func start() {
        if activity == nil {
            activity = ProcessInfo.processInfo.beginActivity(
                options: [.userInitiated, .latencyCritical, .idleDisplaySleepDisabled],
                reason: "Training session")
        }
        clock.start()
        runner.start()
    }

    public func stop() {
        clock.stop()
        runner.quit()
        if let activity {
            ProcessInfo.processInfo.endActivity(activity)
            self.activity = nil
        }
    }
}

extension DrillRegistry {
    /// A runner with its scene, driven by `clock`. nil for drills not built yet.
    public static func makeSession(for id: DrillID, setup: RunSetup, clock: any FrameClock, sceneSize: CGSize) -> DrillSession? {
        switch id {
        case .flashAcquire:
            let runner = TrialRunner(drill: FlashAcquire(geometry: setup.geometry, fit: setup.fit), setup: setup)
            return DrillSession(runner: runner, scene: FlashAcquireScene(runner: runner, size: sceneSize), clock: clock)
        case .transitionLadder:
            let runner = TrialRunner(drill: TransitionLadder(geometry: setup.geometry, fit: setup.fit), setup: setup)
            return DrillSession(runner: runner, scene: TransitionLadderScene(runner: runner, size: sceneSize), clock: clock)
        case .noShootDiscriminator:
            let runner = TrialRunner(drill: NoShootDiscriminator(geometry: setup.geometry, fit: setup.fit), setup: setup)
            return DrillSession(runner: runner, scene: NoShootScene(runner: runner, size: sceneSize), clock: clock)
        case .peripheralPickup, .moverRead, .stageScan, .schulteGrid:
            return nil
        }
    }
}

extension DisplayGeometry {
    /// Before calibration (arch.md §7.3 step 1): the display's own size in mm, 600 mm away,
    /// and its fastest refresh rate.
    public static func firstGuess(for screen: NSScreen) -> DisplayGeometry? {
        guard let number = screen.deviceDescription[NSDeviceDescriptionKey("NSScreenNumber")] as? NSNumber else { return nil }
        let millimeters = CGDisplayScreenSize(CGDirectDisplayID(number.uint32Value))
        guard millimeters.width > 0 else { return nil }
        return DisplayGeometry(
            pointsPerMM: screen.frame.width / millimeters.width,
            refreshHz: Double(max(60, screen.maximumFramesPerSecond)))
    }
}
