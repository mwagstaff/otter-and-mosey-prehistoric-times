import PrehistoricTimesCore
import SpriteKit
import UIKit

/// Stepping Stones. A fast stream blocks the way. Tapping the right answer (or dragging it into the
/// gap) raises a stepping stone out of the water; Otter and Mosey hop across one stone at a time.
final class BridgeBuilderScene: GameScene {
    private let leftCliff = SKSpriteNode(texture: Art.texture("cliff"))
    private let rightCliff = SKSpriteNode(texture: Art.texture("cliff"))
    private var planks: [SKSpriteNode] = []
    private var tiles: [SKSpriteNode] = []
    private var homes: [CGPoint] = []
    private let slot = SKSpriteNode()
    private let water = SKSpriteNode(texture: BridgeBuilderScene.streamTexture)

    /// A soft stream: pale at the surface, deeper blue below. (Painted ripples stretched into long
    /// white stripes across the whole gap, so there are none.)
    private static let streamTexture: SKTexture = {
        let size = CGSize(width: 96, height: 160)
        let image = UIGraphicsImageRenderer(size: size).image { context in
            let colours = [UIColor(hex: "#A6E8F5").cgColor, UIColor(hex: "#4FB6D8").cgColor, UIColor(hex: "#256F9E").cgColor] as CFArray
            if let gradient = CGGradient(colorsSpace: CGColorSpaceCreateDeviceRGB(), colors: colours, locations: [0, 0.35, 1]) {
                context.cgContext.drawLinearGradient(gradient, start: .zero, end: CGPoint(x: 0, y: size.height), options: [])
            }
        }
        return SKTexture(image: image)
    }()
    private var sign: SKSpriteNode?
    private var dragging: SKSpriteNode?
    private var dragOffset = CGPoint.zero
    private var dragStart = CGPoint.zero
    private var locked = false

    override func build() {
        backdrop.showsForeground = false
        backdrop.resize(to: size, groundY: 0)
        rightCliff.xScale = -1
        for cliff in [leftCliff, rightCliff] {
            cliff.anchorPoint = CGPoint(x: 0.5, y: 1)
            cliff.zPosition = 10
            addChild(cliff)
        }
        water.anchorPoint = CGPoint(x: 0.5, y: 0)
        water.alpha = 0.9
        water.zPosition = 5
        addChild(water)
        slot.zPosition = 11
        addChild(slot)
        otter.zPosition = 14
        addChild(otter)
        mosey.zPosition = 8
        // The stream is too fast to swim, so Mosey hops the stones behind Otter.
        mosey.restPose = .dash
        mosey.set(.dash, pop: false)
        addChild(mosey)
    }

    // MARK: - Geometry

    private var deckY: CGFloat { play.minY + play.height * 0.56 }
    private var cliffWidth: CGFloat { play.width * 0.19 }
    private var gapStart: CGFloat { play.minX + cliffWidth * 0.86 }
    private var gapEnd: CGFloat { play.maxX - cliffWidth * 0.86 }
    private var plankSize: CGSize { CGSize(width: (gapEnd - gapStart) / CGFloat(session.total), height: min(play.height * 0.075, 30)) }

    /// A stone fills most of its share of the gap, so the gaps between stones show.
    private var stoneSize: CGSize {
        let side = min(plankSize.width * 0.86, play.height * 0.17)
        return CGSize(width: side, height: side * 0.62)
    }

    private func plankPosition(_ index: Int) -> CGPoint {
        let fraction = (CGFloat(index) + 0.5) / CGFloat(session.total)
        return CGPoint(x: gapStart + (gapEnd - gapStart) * fraction, y: deckY - plankSize.height / 2 + sin(.pi * fraction) * play.height * 0.045)
    }

    private var tileSize: CGSize { CGSize(width: min(play.width * 0.22, 210), height: min(play.height * 0.2, 84)) }

    override func layout() {
        let texture = leftCliff.texture?.size() ?? CGSize(width: 2, height: 1)
        let cliffSize = CGSize(width: cliffWidth, height: cliffWidth * texture.height / texture.width)
        leftCliff.size = cliffSize
        rightCliff.size = cliffSize
        leftCliff.position = CGPoint(x: play.minX + cliffWidth / 2 - 4, y: deckY + cliffSize.height * 0.12)
        rightCliff.position = CGPoint(x: play.maxX - cliffWidth / 2 + 4, y: deckY + cliffSize.height * 0.12)
        otter.resize(min(play.height * 0.27, 130))
        mosey.resize(min(play.height * 0.3, 150))
        positionHeroes(animated: false)
        water.size = CGSize(width: gapEnd - gapStart + cliffWidth * 0.4, height: max(deckY - play.minY - 6, 10))
        water.position = CGPoint(x: (gapStart + gapEnd) / 2, y: play.minY)
        for (index, plank) in planks.enumerated() {
            plank.size = stoneSize
            plank.position = plankPosition(index)
        }
        slot.texture = Art.panel(size: CGSize(width: 120, height: 40), fill: UIColor.white.withAlphaComponent(0.35), stroke: UIColor(hex: "#FFE066"), radius: 10, lineWidth: 4)
        slot.size = CGSize(width: plankSize.width, height: plankSize.height * 1.3)
        slot.position = plankPosition(min(planks.count, session.total - 1))
        sign?.position = signPosition
    }

    private var signPosition: CGPoint { CGPoint(x: play.midX, y: play.maxY - play.height * 0.1) }

    private func positionHeroes(animated: Bool) {
        let x = planks.isEmpty ? max(play.minX + cliffWidth * 0.42, play.minX + mosey.footprint.width + otter.footprint.width * 0.5 + 4) : plankPosition(planks.count - 1).x
        let otterTarget = CGPoint(x: x, y: deckY)
        // Mosey hops along a stone behind Otter, with room between them; on the bank he waits at the edge.
        let gap = mosey.footprint.width * 0.5 + otter.footprint.width * 0.5 + 4
        let moseyTarget = CGPoint(x: max(x - gap, play.minX + mosey.footprint.width * 0.5), y: deckY + mosey.footprint.height * 0.3)
        guard animated else {
            otter.position = otterTarget
            mosey.position = moseyTarget
            return
        }
        otter.set(.move)
        AudioManager.shared.play(.jump, volume: 0.6)
        otter.run(.sequence([SKAction.move(to: otterTarget, duration: 0.45).eased(), .run { [weak self] in self?.otter.celebrate() }]))
        mosey.run(SKAction.move(to: moseyTarget, duration: 0.6).eased())
    }

    // MARK: - Questions

    override func caption(for question: Question) -> String {
        question.prompt.count <= 22 ? "Tap the right answer to fill the gap" : question.prompt
    }

    override func present(_ question: Question) {
        locked = false
        sign?.removeFromParent()
        let text = question.prompt.count <= 22 ? question.prompt : "?"
        let fontSize = min(play.height * 0.1, 40)
        let width = min(max(CGFloat(text.count) * fontSize * 0.7 + 50, 120), play.width * 0.6)
        let board = makeSign(text: text, size: CGSize(width: width, height: fontSize * 1.7), fontSize: fontSize)
        board.position = signPosition
        board.zPosition = 16
        board.setScale(0)
        board.run(.pop())
        addChild(board)
        sign = board

        tiles.forEach { $0.removeFromParent() }
        tiles = []
        homes = []
        let count = CGFloat(question.choices.count)
        let spacing = min(play.width / (count + 0.6), tileSize.width * 1.35)
        for (index, choice) in question.choices.enumerated() {
            let tile = makeSign(text: choice, size: tileSize, fill: theme.tint.mixed(with: .white, amount: 0.72), fontSize: tileSize.height * 0.5)
            tile.name = choice
            let home = CGPoint(x: play.midX + (CGFloat(index) - (count - 1) / 2) * spacing, y: play.minY + tileSize.height * 0.72)
            tile.position = CGPoint(x: home.x, y: play.minY - tileSize.height)
            tile.zPosition = 25
            addChild(tile)
            tile.run(.sequence([.wait(forDuration: 0.08 * Double(index)), SKAction.move(to: home, duration: 0.3).eased()]))
            tiles.append(tile)
            homes.append(home)
        }
        slot.isHidden = false
        slot.position = plankPosition(planks.count)
        slot.removeAllActions()
        if !Effects.reducedMotion {
            slot.run(.repeatForever(.sequence([.fadeAlpha(to: 0.4, duration: 0.5), .fadeAlpha(to: 1, duration: 0.5)])))
        }
    }

    // MARK: - Dragging

    /// An answer chosen from VoiceOver's buttons rather than by dragging a stone.
    override func handleChoice(_ choice: String) {
        guard !locked, dragging == nil, let tile = tiles.first(where: { $0.name == choice && $0.alpha == 1 }) else { return }
        let question = current
        drop(tile)
        noteChoice(choice, for: question)
    }

    #if DEBUG
    override func debugAnswer(_ question: Question) {
        guard !locked, dragging == nil, let tile = tiles.first(where: { $0.name == question.correctChoice }) else { return }
        drop(tile)
    }
    #endif

    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
        guard !locked, let point = touches.first?.location(in: self) else { return }
        // Generous hit area: the nearest live tile within reach of the finger.
        let reach = tileSize.width * 0.75
        guard let tile = tiles.filter({ $0.alpha == 1 }).min(by: { $0.position.distance(to: point) < $1.position.distance(to: point) }),
              tile.position.distance(to: point) < reach else { return }
        dragging = tile
        dragStart = point
        dragOffset = CGPoint(x: tile.position.x - point.x, y: tile.position.y - point.y)
        tile.zPosition = 40
        tile.run(.scale(to: 1.1, duration: 0.08))
        AudioManager.shared.play(.tap, volume: 0.6)
    }

    override func touchesMoved(_ touches: Set<UITouch>, with event: UIEvent?) {
        guard let tile = dragging, let point = touches.first?.location(in: self) else { return }
        tile.position = CGPoint(x: point.x + dragOffset.x, y: point.y + dragOffset.y)
    }

    override func touchesEnded(_ touches: Set<UITouch>, with event: UIEvent?) {
        guard let tile = dragging, let point = touches.first?.location(in: self) else { return }
        dragging = nil
        let tapped = point.distance(to: dragStart) < 14
        let nearSlot = tile.position.distance(to: slot.position) < max(plankSize.width, 110)
        if tapped || nearSlot { drop(tile) } else { sendHome(tile) }
    }

    override func touchesCancelled(_ touches: Set<UITouch>, with event: UIEvent?) {
        if let tile = dragging { sendHome(tile) }
        dragging = nil
    }

    private func sendHome(_ tile: SKSpriteNode) {
        guard let index = tiles.firstIndex(of: tile) else { return }
        tile.zPosition = 25
        tile.run(.group([SKAction.move(to: homes[index], duration: 0.22).eased(), .scale(to: 1, duration: 0.15)]))
    }

    private func drop(_ tile: SKSpriteNode) {
        guard let question = current, let choice = tile.name else { return }
        if question.isCorrect(choice: choice) {
            locked = true
            let index = planks.count
            let target = plankPosition(index)
            slot.isHidden = true
            tile.run(.sequence([
                .group([SKAction.move(to: target, duration: 0.22).eased(), .scale(to: 0.5, duration: 0.22), .fadeOut(withDuration: 0.22)]),
                .removeFromParent(),
            ]))
            for other in tiles where other !== tile { other.run(.sequence([.fadeOut(withDuration: 0.2), .removeFromParent()])) }
            tiles = []
            // The stone rises out of the stream with a splash.
            let plank = SKSpriteNode(texture: Art.texture("stone"), size: stoneSize)
            plank.position = CGPoint(x: target.x, y: target.y - 50)
            plank.alpha = 0
            plank.zPosition = 12
            addChild(plank)
            planks.append(plank)
            let rise = SKAction.move(to: target, duration: 0.26)
            rise.timingMode = .easeOut
            AudioManager.shared.play(.splash, volume: 0.7)
            plank.run(.sequence([.wait(forDuration: 0.1), .group([rise, .fadeIn(withDuration: 0.15)]), .run { [weak self] in
                AudioManager.shared.play(.plank, volume: 0.5)
                self?.cameraPunch()
            }]))
            let outcome = succeed(at: target)
            run(.sequence([.wait(forDuration: 0.45), .run { [weak self] in self?.positionHeroes(animated: true) }]))
            if outcome?.isLevelComplete == true {
                run(.sequence([.wait(forDuration: 1.2), .run { [weak self] in self?.completeBridge() }]))
            } else {
                run(.sequence([.wait(forDuration: 1.5), .run { [weak self] in self?.askNext() }]))
            }
        } else {
            tile.run(.sequence([.wobble(), .group([.fadeAlpha(to: 0.4, duration: 0.2), .scale(to: 1, duration: 0.2)])]))
            sendHome(tile)
            slip()
        }
    }

    /// The finish: the stones bob in turn with a splash of colour, and both hop to the far bank.
    private func completeBridge() {
        sign?.run(.sequence([.fadeOut(withDuration: 0.3), .removeFromParent()]))
        AudioManager.shared.play(.victory)
        for (index, plank) in planks.enumerated() {
            plank.run(.sequence([.wait(forDuration: 0.06 * Double(index)), .moveBy(x: 0, y: 12, duration: 0.1), .moveBy(x: 0, y: -12, duration: 0.14)]))
            Effects.burst(at: plank.position, colour: Art.rainbow[index % Art.rainbow.count], count: 10, in: self)
        }
        otter.set(.move)
        let far = CGPoint(x: play.maxX - cliffWidth * 0.42, y: deckY)
        otter.run(.sequence([SKAction.move(to: far, duration: 0.9).eased(), .run { [weak self] in self?.otter.celebrate() }]))
        mosey.run(SKAction.move(to: CGPoint(x: play.maxX - cliffWidth * 0.75, y: deckY + mosey.footprint.height * 0.3), duration: 1.0).eased())
        finishLevel(after: 0.9)
    }
}

extension CGPoint {
    func distance(to other: CGPoint) -> CGFloat { hypot(x - other.x, y - other.y) }
}
