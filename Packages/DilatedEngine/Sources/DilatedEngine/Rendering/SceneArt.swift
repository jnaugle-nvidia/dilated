import AppKit
import DilatedCore
import SpriteKit

/// Colors and shapes for every drill scene (arch.md §8.3). Nodes are built once, before the beep.
@MainActor
enum SceneArt {
    static let background = NSColor(white: 0.5, alpha: 1)
    static let cardboard = NSColor(srgbRed: 0.80, green: 0.67, blue: 0.48, alpha: 1)
    static let noShootFill = NSColor.white
    static let hardCover = NSColor.black
    static let ink = NSColor.black
    static let scoringLine = NSColor(white: 0, alpha: 0.3)
    static let hit = NSColor(srgbRed: 0.10, green: 0.75, blue: 0.25, alpha: 1)
    static let miss = NSColor(srgbRed: 0.90, green: 0.15, blue: 0.15, alpha: 1)
    static let text = NSColor.white

    /// USPSA-style outline in inches, 18 wide × 30 tall, centered on (0, 0).
    /// Approximate: confirm against the rulebook, Appendix B1 (arch.md §19 #1).
    private static let silhouetteInches: [CGPoint] = [
        CGPoint(x: -2, y: 15), CGPoint(x: 2, y: 15), CGPoint(x: 3, y: 14), CGPoint(x: 3, y: 9),
        CGPoint(x: 6, y: 9), CGPoint(x: 9, y: 6), CGPoint(x: 9, y: -12), CGPoint(x: 6, y: -15),
        CGPoint(x: -6, y: -15), CGPoint(x: -9, y: -12), CGPoint(x: -9, y: 6), CGPoint(x: -6, y: 9),
        CGPoint(x: -3, y: 9), CGPoint(x: -3, y: 14),
    ]

    static func silhouette(width: CGFloat, height: CGFloat) -> CGPath {
        let path = CGMutablePath()
        path.addLines(between: silhouetteInches.map { CGPoint(x: $0.x * width / 18, y: $0.y * height / 30) })
        path.closeSubpath()
        return path
    }

    /// A target `width` × `height` points. The A-zone (6 × 11 in) is centered, where drills put the E.
    static func target(width: CGFloat, height: CGFloat, noShoot: Bool) -> SKShapeNode {
        let outline = silhouette(width: width, height: height)
        let node = SKShapeNode(path: outline)
        node.fillColor = noShoot ? noShootFill : cardboard
        node.lineWidth = 0
        if noShoot {
            // Shape, not just color: a dashed black border (arch.md §8.3).
            let border = SKShapeNode(path: outline.copy(dashingWithPhase: 0, lengths: [6, 4]))
            border.strokeColor = ink
            border.lineWidth = 2
            node.addChild(border)
        } else {
            let aZone = SKShapeNode(rectOf: CGSize(width: width * 6 / 18, height: height * 11 / 30))
            aZone.strokeColor = scoringLine
            aZone.lineWidth = 1
            node.addChild(aZone)
        }
        return node
    }

    /// A Tumbling E `height` points tall, prongs to the right. Rotate with `Direction.zRotation`.
    static func tumblingE(height: CGFloat) -> SKShapeNode {
        let h = height / 2
        let s = height / 5   // stroke width: the E is 5 strokes tall
        let path = CGMutablePath()
        path.addLines(between: [
            CGPoint(x: -h, y: -h), CGPoint(x: h, y: -h), CGPoint(x: h, y: -h + s), CGPoint(x: -h + s, y: -h + s),
            CGPoint(x: -h + s, y: -s / 2), CGPoint(x: h, y: -s / 2), CGPoint(x: h, y: s / 2), CGPoint(x: -h + s, y: s / 2),
            CGPoint(x: -h + s, y: h - s), CGPoint(x: h, y: h - s), CGPoint(x: h, y: h), CGPoint(x: -h, y: h),
        ])
        path.closeSubpath()
        let node = SKShapeNode(path: path)
        node.fillColor = ink
        node.lineWidth = 0
        return node
    }

    /// A random patch of cells in `colors`, covering `width` × `height` points. Fixed seed: the same patch every time.
    static func mask(width: CGFloat, height: CGFloat, cell: CGFloat, colors: [NSColor], seed: UInt64) -> SKNode {
        let columns = max(1, Int((width / cell).rounded(.up)))
        let rows = max(1, Int((height / cell).rounded(.up)))
        let paths = colors.map { _ in CGMutablePath() }
        var rng = SeededRNG(seed: seed)
        for row in 0..<rows {
            for column in 0..<columns {
                let rect = CGRect(x: -width / 2 + CGFloat(column) * cell, y: -height / 2 + CGFloat(row) * cell, width: cell, height: cell)
                paths[rng.int(in: 0...(colors.count - 1))].addRect(rect)
            }
        }
        let node = SKNode()
        for (color, path) in zip(colors, paths) {
            let layer = SKShapeNode(path: path)
            layer.fillColor = color
            layer.lineWidth = 0
            node.addChild(layer)
        }
        return node
    }

    static func fixationCross(size: CGFloat) -> SKShapeNode {
        let path = CGMutablePath()
        path.move(to: CGPoint(x: -size / 2, y: 0))
        path.addLine(to: CGPoint(x: size / 2, y: 0))
        path.move(to: CGPoint(x: 0, y: -size / 2))
        path.addLine(to: CGPoint(x: 0, y: size / 2))
        let node = SKShapeNode(path: path)
        node.strokeColor = ink
        node.lineWidth = max(2, size / 8)
        return node
    }

    /// Hit feedback: a green ring.
    static func hitRing(radius: CGFloat) -> SKShapeNode {
        let node = SKShapeNode(circleOfRadius: radius)
        node.strokeColor = hit
        node.lineWidth = max(3, radius / 8)
        return node
    }

    /// Miss feedback: a red ✕. Shape, not just color.
    static func missMark(size: CGFloat) -> SKShapeNode {
        let path = CGMutablePath()
        path.move(to: CGPoint(x: -size / 2, y: -size / 2))
        path.addLine(to: CGPoint(x: size / 2, y: size / 2))
        path.move(to: CGPoint(x: -size / 2, y: size / 2))
        path.addLine(to: CGPoint(x: size / 2, y: -size / 2))
        let node = SKShapeNode(path: path)
        node.strokeColor = miss
        node.lineWidth = max(4, size / 8)
        return node
    }

    static func label(fontSize: CGFloat) -> SKLabelNode {
        let node = SKLabelNode(fontNamed: NSFont.systemFont(ofSize: fontSize, weight: .semibold).fontName)
        node.fontSize = fontSize
        node.fontColor = text
        node.verticalAlignmentMode = .center
        node.horizontalAlignmentMode = .center
        return node
    }
}

extension Direction {
    /// Rotation for a node drawn facing right.
    var zRotation: CGFloat {
        switch self {
        case .right: 0
        case .upRight: .pi / 4
        case .up: .pi / 2
        case .upLeft: 3 * .pi / 4
        case .left: .pi
        case .downLeft: -3 * .pi / 4
        case .down: -.pi / 2
        case .downRight: -.pi / 4
        }
    }
}
