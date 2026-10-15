import DilatedCore
import SpriteKit

/// D3 — a shoot (tan) or no-shoot (white, dashed border) target at a random spot. Harder levels
/// put a no-shoot in front, add black hard cover, and mask the target after a short exposure (arch.md §9).
@MainActor
public final class NoShootScene: DrillScene {
    let runner: TrialRunner<NoShootDiscriminator>
    let shootTarget: SKShapeNode
    let noShootBack: SKShapeNode
    let noShootFront: SKShapeNode
    let hardCover: SKShapeNode
    let mask: SKNode
    let hitRing: SKShapeNode
    let missMark: SKShapeNode
    private let width: CGFloat
    private let height: CGFloat
    /// The stimulus the hard cover was last shaped for.
    private var shapedFor: NoShootDiscriminator.Stimulus?

    public init(runner: TrialRunner<NoShootDiscriminator>, size: CGSize) {
        self.runner = runner
        let geometry = runner.setup.geometry
        let settings = runner.drill.settings
        func points(_ degrees: Double) -> CGFloat { CGFloat(VisualAngle.points(forDegrees: degrees, geometry: geometry)) }
        width = points(settings.target.widthDeg)
        height = points(settings.target.heightDeg)
        shootTarget = SceneArt.target(width: width, height: height, noShoot: false)
        noShootBack = SceneArt.target(width: width, height: height, noShoot: true)
        noShootFront = SceneArt.target(width: width, height: height, noShoot: true)
        hardCover = SKShapeNode()
        hardCover.fillColor = SceneArt.hardCover
        hardCover.lineWidth = 0
        // Wide enough for the widest pair; mixes target colors so the kind can't be read through it.
        mask = SceneArt.mask(
            width: width * 2.2, height: height * 1.2, cell: points(0.25),
            colors: [SceneArt.ink, SceneArt.noShootFill, SceneArt.cardboard, SceneArt.background], seed: 0xD3)
        hitRing = SceneArt.hitRing(radius: width * 0.8)
        missMark = SceneArt.missMark(size: width)
        super.init(size: size, geometry: geometry)
        let layers: [(SKNode, CGFloat)] = [
            (shootTarget, 1), (noShootBack, 1), (noShootFront, 2), (hardCover, 3), (mask, 4), (hitRing, 5), (missMark, 5),
        ]
        for (node, z) in layers {
            node.zPosition = z
            node.isHidden = true
            addChild(node)
        }
    }

    public override func sync() {
        for node in [shootTarget, noShootBack, noShootFront, hardCover, mask, hitRing, missMark] as [SKNode] {
            node.isHidden = true
        }
        let presentation = runner.presentation
        guard !showShared(presentation), let stimulus = runner.currentSpec?.stimulus else { return }
        shapeHardCover(for: stimulus)
        let back = stimulus.kind == .shoot ? shootTarget : noShootBack
        let center = point(stimulus.center)
        switch presentation {
        case .fixation:
            fixation.position = .zero
            fixation.isHidden = false
        case .probe(_, .visible):
            showTargets(back: back, at: center, stimulus: stimulus)
        case .probe(_, .masked):
            mask.position = pairCenter(center, stimulus: stimulus)
            mask.isHidden = false
        case .probe(_, .awaiting):
            break   // after the mask, nothing: the kind must not be readable any more
        case .feedback(let outcomes):
            showTargets(back: back, at: center, stimulus: stimulus)
            let right = outcomes.first == .correct || outcomes.first == .withheld
            hitRing.position = center
            missMark.position = center
            hitRing.isHidden = !right
            missMark.isHidden = right
        default:
            break
        }
    }

    private func showTargets(back: SKShapeNode, at center: CGPoint, stimulus: NoShootDiscriminator.Stimulus) {
        back.position = center
        back.isHidden = false
        if stimulus.overlap > 0 {
            noShootFront.position = CGPoint(x: center.x + frontShift(stimulus), y: center.y)
            noShootFront.isHidden = false
        }
        if stimulus.hardCover > 0 {
            hardCover.position = center
            hardCover.isHidden = false
        }
    }

    /// The front no-shoot sits `width · (1 − overlap)` to one side of the back target.
    private func frontShift(_ stimulus: NoShootDiscriminator.Stimulus) -> CGFloat {
        let shift = width * (1 - stimulus.overlap)
        return stimulus.overlapSide == .right ? shift : -shift
    }

    private func pairCenter(_ center: CGPoint, stimulus: NoShootDiscriminator.Stimulus) -> CGPoint {
        stimulus.overlap > 0 ? CGPoint(x: center.x + frontShift(stimulus) / 2, y: center.y) : center
    }

    /// Reshape the hard cover once per trial, not per frame.
    private func shapeHardCover(for stimulus: NoShootDiscriminator.Stimulus) {
        guard shapedFor != stimulus else { return }
        shapedFor = stimulus
        let pad = width * 0.1
        let share = CGFloat(stimulus.hardCover)
        let rect: CGRect =
            switch stimulus.hardCoverSide {
            case .left:
                CGRect(x: -width / 2 - pad, y: -height / 2 - pad, width: pad + width * share, height: height + 2 * pad)
            case .right:
                CGRect(x: width / 2 - width * share, y: -height / 2 - pad, width: pad + width * share, height: height + 2 * pad)
            default:
                CGRect(x: -width / 2 - pad, y: -height / 2 - pad, width: width + 2 * pad, height: pad + height * share)
            }
        hardCover.path = CGPath(rect: rect, transform: nil)
    }
}
