import Foundation

/// The v1 default clock: one tick per `SKScene.update(_:)` (arch.md §8.4).
///
/// It can't see when a frame reaches the glass, so the onset estimate is the update time plus
/// the present latency the timing self-test measured (1 frame until then).
@MainActor
public final class SpriteKitFrameClock: FrameClock {
    public var onTick: ((FrameTick) -> Void)?
    public var onPresented: ((_ frameIndex: Int, _ presentedTime: Double) -> Void)?
    public let nominalFrameDuration: Double
    public var presentLatencyFrames: Double
    private var nextIndex = 0

    public init(refreshHz: Double, presentLatencyFrames: Double = 1) {
        nominalFrameDuration = 1 / refreshHz
        self.presentLatencyFrames = presentLatencyFrames
    }

    public func attach(_ scene: DrillScene) {
        scene.onUpdate = { [weak self] currentTime in self?.tick(at: currentTime) }
    }

    /// SpriteKit's own loop runs the clock.
    public func start() {}
    public func stop() {}

    /// One frame. `updateTime` is `SKScene.update`'s `currentTime` (system-uptime seconds).
    public func tick(at updateTime: TimeInterval) {
        let tick = FrameTick(
            index: nextIndex,
            timestamp: updateTime + presentLatencyFrames * nominalFrameDuration,
            duration: nominalFrameDuration)
        nextIndex += 1
        onTick?(tick)
    }
}
