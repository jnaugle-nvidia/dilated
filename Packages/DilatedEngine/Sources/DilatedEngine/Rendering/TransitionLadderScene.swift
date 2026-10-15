import DilatedCore
import SpriteKit

/// D2 — an array of numbered targets. The E appears on each target in turn (arch.md §9).
@MainActor
public final class TransitionLadderScene: DrillScene {
    static let maxTargets = TransitionLadder.allLevels.map(\.targets).max() ?? 8

    let runner: TrialRunner<TransitionLadder>
    let targets: [SKShapeNode]
    let numbers: [SKLabelNode]
    let letterE: SKShapeNode
    let mask: SKNode
    let hitRings: [SKShapeNode]
    let missMarks: [SKShapeNode]
    /// Gap between a target's top and its number.
    private let numberOffset: CGFloat

    public init(runner: TrialRunner<TransitionLadder>, size: CGSize) {
        self.runner = runner
        let geometry = runner.setup.geometry
        let settings = runner.drill.settings
        func points(_ degrees: Double) -> CGFloat { CGFloat(VisualAngle.points(forDegrees: degrees, geometry: geometry)) }
        let width = points(settings.target.widthDeg)
        let height = points(settings.target.heightDeg)
        let eHeight = points(settings.eHeightDeg)
        let count = Self.maxTargets
        targets = (0..<count).map { _ in SceneArt.target(width: width, height: height, noShoot: false) }
        numbers = (0..<count).map { index in
            let label = SceneArt.label(fontSize: max(14, points(0.6)))
            label.text = "\(index + 1)"
            return label
        }
        letterE = SceneArt.tumblingE(height: eHeight)
        mask = SceneArt.mask(
            width: eHeight * 1.4, height: eHeight * 1.4, cell: eHeight / 5,
            colors: [SceneArt.ink, SceneArt.cardboard], seed: 0xD2)
        hitRings = (0..<count).map { _ in SceneArt.hitRing(radius: width * 0.7) }
        missMarks = (0..<count).map { _ in SceneArt.missMark(size: width) }
        numberOffset = height / 2 + points(0.5)
        super.init(size: size, geometry: geometry)
        let layers: [([SKNode], CGFloat)] = [(targets, 1), (numbers, 1), ([letterE], 2), ([mask], 3), (hitRings, 4), (missMarks, 4)]
        for (nodes, z) in layers {
            for node in nodes {
                node.zPosition = z
                node.isHidden = true
                addChild(node)
            }
        }
    }

    public override func sync() {
        for node in targets + numbers + hitRings + missMarks + [letterE, mask] as [SKNode] {
            node.isHidden = true
        }
        let presentation = runner.presentation
        guard !showShared(presentation), let stimulus = runner.currentSpec?.stimulus else { return }
        let centers = stimulus.targets.map(point)
        for (index, center) in centers.enumerated() {
            targets[index].position = center
            targets[index].isHidden = false
            numbers[index].position = CGPoint(x: center.x, y: center.y + numberOffset)
            numbers[index].isHidden = false
        }
        switch presentation {
        case .fixation:
            fixation.position = centers[0]
            fixation.isHidden = false
        case .probe(let index, let phase):
            letterE.position = centers[index]
            letterE.zRotation = stimulus.eFacings[index].zRotation
            letterE.isHidden = phase != .visible
            mask.position = centers[index]
            mask.isHidden = phase != .masked
        case .feedback(let outcomes):
            for (index, outcome) in outcomes.enumerated() where index < centers.count {
                let hit = outcome == .correct
                hitRings[index].position = centers[index]
                missMarks[index].position = centers[index]
                hitRings[index].isHidden = !hit
                missMarks[index].isHidden = hit
            }
        default:
            break
        }
    }
}
