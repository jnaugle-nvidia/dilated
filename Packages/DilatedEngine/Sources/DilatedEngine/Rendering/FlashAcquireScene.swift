import DilatedCore
import SpriteKit

/// D1 — a target appears away from the fixation cross with a Tumbling E in its A-zone.
/// After the exposure the E is masked; the silhouette stays (arch.md §9).
@MainActor
public final class FlashAcquireScene: DrillScene {
    let runner: TrialRunner<FlashAcquire>
    let target: SKShapeNode
    let letterE: SKShapeNode
    let mask: SKNode
    let hitRing: SKShapeNode
    let missMark: SKShapeNode

    public init(runner: TrialRunner<FlashAcquire>, size: CGSize) {
        self.runner = runner
        let geometry = runner.setup.geometry
        let settings = runner.drill.settings
        func points(_ degrees: Double) -> CGFloat { CGFloat(VisualAngle.points(forDegrees: degrees, geometry: geometry)) }
        let width = points(settings.target.widthDeg)
        let eHeight = points(settings.eHeightDeg)
        target = SceneArt.target(width: width, height: points(settings.target.heightDeg), noShoot: false)
        letterE = SceneArt.tumblingE(height: eHeight)
        mask = SceneArt.mask(
            width: eHeight * 1.4, height: eHeight * 1.4, cell: eHeight / 5,
            colors: [SceneArt.ink, SceneArt.cardboard], seed: 0xD1)
        hitRing = SceneArt.hitRing(radius: width * 0.7)
        missMark = SceneArt.missMark(size: width)
        super.init(size: size, geometry: geometry)
        for (node, z) in [(target, 1.0), (letterE, 2), (mask, 3), (hitRing, 4), (missMark, 4)] as [(SKNode, CGFloat)] {
            node.zPosition = z
            node.isHidden = true
            addChild(node)
        }
    }

    public override func sync() {
        for node in [target, letterE, mask, hitRing, missMark] as [SKNode] {
            node.isHidden = true
        }
        let presentation = runner.presentation
        guard !showShared(presentation), let stimulus = runner.currentSpec?.stimulus else { return }
        let center = point(stimulus.target)
        switch presentation {
        case .fixation:
            fixation.position = point(stimulus.fixation)
            fixation.isHidden = false
        case .probe(_, let phase):
            target.position = center
            target.isHidden = false
            letterE.position = center
            letterE.zRotation = stimulus.eFacing.zRotation
            letterE.isHidden = phase != .visible
            mask.position = center
            mask.isHidden = phase != .masked
        case .feedback(let outcomes):
            target.position = center
            target.isHidden = false
            let hit = outcomes.first == .correct
            hitRing.position = center
            missMark.position = center
            hitRing.isHidden = !hit
            missMark.isHidden = hit
        default:
            break
        }
    }
}
