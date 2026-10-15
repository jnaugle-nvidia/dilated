/// One screen refresh (arch.md §8.4).
public struct FrameTick: Sendable, Equatable {
    public var index: Int
    /// Expected on-glass time of this frame, system-uptime seconds.
    public var timestamp: Double
    /// Seconds per frame.
    public var duration: Double

    public init(index: Int, timestamp: Double, duration: Double) {
        self.index = index
        self.timestamp = timestamp
        self.duration = duration
    }
}

/// Drives a runner once per frame. `SpriteKitFrameClock` and `MetalFrameClock` implement it (arch.md §8.4).
@MainActor
public protocol FrameClock: AnyObject {
    var onTick: ((FrameTick) -> Void)? { get set }
    /// Real on-glass time for a frame, delivered after the fact. Only `MetalFrameClock` calls it.
    var onPresented: ((_ frameIndex: Int, _ presentedTime: Double) -> Void)? { get set }
    var nominalFrameDuration: Double { get }
}
