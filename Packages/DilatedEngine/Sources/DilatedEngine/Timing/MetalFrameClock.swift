import Metal
import MetalKit
import QuartzCore
import SpriteKit

/// Renders the scene itself with `SKRenderer` into an `MTKView`, on its own `CADisplayLink`
/// (arch.md §8.4). It knows each frame's target time up front, and its real on-glass time
/// a frame or two later. The timing self-test always uses it.
@MainActor
public final class MetalFrameClock: NSObject, FrameClock {
    public var onTick: ((FrameTick) -> Void)?
    public var onPresented: ((_ frameIndex: Int, _ presentedTime: Double) -> Void)?
    public let nominalFrameDuration: Double
    /// Put this in the window.
    public let view: MTKView

    private let renderer: SKRenderer
    private let commandQueue: MTLCommandQueue
    private let refreshHz: Double
    private var displayLink: CADisplayLink?
    private var scene: SKScene?
    private var nextIndex = 0
    /// The frame `draw(in:)` is about to render.
    private var pending: (index: Int, time: CFTimeInterval)?

    public init?(refreshHz: Double, device: MTLDevice? = MTLCreateSystemDefaultDevice()) {
        guard let device, let queue = device.makeCommandQueue() else { return nil }
        self.refreshHz = refreshHz
        nominalFrameDuration = 1 / refreshHz
        commandQueue = queue
        renderer = SKRenderer(device: device)
        view = MTKView(frame: .zero, device: device)
        view.isPaused = true                  // the display link below decides when to draw
        view.enableSetNeedsDisplay = false
        view.colorPixelFormat = .bgra8Unorm
        view.clearColor = MTLClearColor(red: 0.5, green: 0.5, blue: 0.5, alpha: 1)
        super.init()
        view.delegate = self
    }

    public func attach(_ scene: DrillScene) {
        self.scene = scene
        renderer.scene = scene
    }

    public func start() {
        guard displayLink == nil else { return }
        let link = view.displayLink(target: self, selector: #selector(step(_:)))
        let rate = Float(refreshHz)
        link.preferredFrameRateRange = CAFrameRateRange(minimum: rate, maximum: rate, preferred: rate)
        link.add(to: .main, forMode: .common)
        displayLink = link
    }

    public func stop() {
        displayLink?.invalidate()
        displayLink = nil
    }

    @objc private func step(_ link: CADisplayLink) {
        let index = nextIndex
        nextIndex += 1
        onTick?(FrameTick(index: index, timestamp: link.targetTimestamp, duration: link.targetTimestamp - link.timestamp))
        pending = (index, link.timestamp)
        view.draw()
    }
}

extension MetalFrameClock: MTKViewDelegate {
    public func mtkView(_ view: MTKView, drawableSizeWillChange size: CGSize) {}

    public func draw(in view: MTKView) {
        guard let pending, let scene,
              let drawable = view.currentDrawable,
              let pass = view.currentRenderPassDescriptor,
              let commands = commandQueue.makeCommandBuffer()
        else { return }
        self.pending = nil
        if scene.size != view.bounds.size {
            scene.size = view.bounds.size
        }
        renderer.update(atTime: pending.time)
        renderer.render(
            withViewport: CGRect(origin: .zero, size: view.drawableSize),
            commandBuffer: commands,
            renderPassDescriptor: pass)
        let frameIndex = pending.index
        drawable.addPresentedHandler { [weak self] drawable in
            let presentedTime = drawable.presentedTime   // a background thread; 0 = never shown
            Task { @MainActor in self?.onPresented?(frameIndex, presentedTime) }
        }
        commands.present(drawable)
        commands.commit()
    }
}
