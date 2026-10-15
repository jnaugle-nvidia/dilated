import DilatedCore
import SpriteKit

/// Base scene for every drill (arch.md §8.3).
///
/// Every node is built in `init`, before the beep. During a run, `sync()` only moves, rotates,
/// and shows or hides them to match the runner's `presentation`. (0, 0) is screen center.
@MainActor
open class DrillScene: SKScene {
    public let geometry: DisplayGeometry
    /// Set by `SpriteKitFrameClock.attach(_:)`.
    public var onUpdate: ((TimeInterval) -> Void)?

    let fixation: SKShapeNode
    let message: SKLabelNode

    public init(size: CGSize, geometry: DisplayGeometry) {
        self.geometry = geometry
        fixation = SceneArt.fixationCross(size: CGFloat(VisualAngle.points(forDegrees: 0.6, geometry: geometry)))
        message = SceneArt.label(fontSize: 40)
        super.init(size: size)
        anchorPoint = CGPoint(x: 0.5, y: 0.5)
        scaleMode = .resizeFill
        backgroundColor = SceneArt.background
        fixation.zPosition = 10
        message.zPosition = 20
        for node in [fixation, message] as [SKNode] {
            node.isHidden = true
            addChild(node)
        }
    }

    @available(*, unavailable)
    public required init?(coder: NSCoder) {
        fatalError("DrillScene is built in code")
    }

    open override func update(_ currentTime: TimeInterval) {
        onUpdate?(currentTime)
    }

    /// Match the nodes to the runner's current frame. Called right after `runner.onFrame`.
    open func sync() {}

    /// Screen position (points from center) of a spot in degrees.
    func point(_ spot: DegreePoint) -> CGPoint {
        CGPoint(
            x: VisualAngle.offsetPoints(forDegrees: spot.x, geometry: geometry),
            y: VisualAngle.offsetPoints(forDegrees: spot.y, geometry: geometry))
    }

    /// Size on screen (points) of something `degrees` across.
    func points(_ degrees: Double) -> CGFloat {
        CGFloat(VisualAngle.points(forDegrees: degrees, geometry: geometry))
    }

    /// Draws the frames every drill shows the same way. Returns false for the drill's own frames
    /// (fixation, probe, feedback), which the subclass draws.
    func showShared(_ presentation: Presentation) -> Bool {
        fixation.isHidden = true
        let text: String? =
            switch presentation {
            case .blank: ""
            case .standby: "STANDBY"
            case .invalid(.falseStart): "False start — wait for the target"
            case .invalid(.anticipation): "Too fast — wait for the target"
            case .invalid(.droppedFrame): "Frames dropped — close other apps"
            case .paused(.player): "Paused"
            case .paused(.tooManyInvalid): "Paused — too many trials didn't count"
            case .finished: "Done"
            case .fixation, .probe, .feedback: nil
            }
        message.isHidden = text?.isEmpty ?? true
        if let text, message.text != text {
            message.text = text
        }
        return text != nil
    }
}
