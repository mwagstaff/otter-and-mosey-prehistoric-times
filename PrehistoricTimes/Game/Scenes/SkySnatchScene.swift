import PrehistoricTimesCore
import SpriteKit
import UIKit

/// Sky Snatch. The Swoop Squad flies past high above the cliff tops, each pterosaur dangling a
/// number stone. Tap the one carrying the right answer and it drops the stone into Otter's paws.
/// A wrong one squawks, lets go of nothing and flaps off for good; any that are not tapped loop
/// round and come past again, so there is never a rush.
final class SkySnatchScene: GameScene {
    /// Each flyer: a pterosaur and the stone hanging below it. Named after the answer it carries.
    /// Called `gates` so the play-test runner can find them.
    private var gates: [SKNode] = []
    /// How far along the sky each flyer has come, in points. Negative is still waiting to come on.
    private var travelled: [CGFloat] = []
    private var acceptingAnswers = false
    private var lastTime: TimeInterval = 0
    private var clock: TimeInterval = 0
    private var stonesCaught = 0

    override func build() {
        otter.zPosition = 14
        mosey.zPosition = 12
        addChild(mosey)
        addChild(otter)
        otter.facingLeft = false
        mosey.facingLeft = false
    }

    // MARK: - Geometry

    private var heroX: CGFloat { play.minX + play.width * 0.13 }
    private var flyerWidth: CGFloat { min(play.height * 0.42, play.width * 0.2, 230) }
    /// Three heights, so the flyers never overlap however they bunch up.
    private var lanes: [CGFloat] { [0.83, 0.6, 0.37].map { play.minY + play.height * $0 } }
    /// The flight path runs from just off the right of the screen to just off the left.
    private var trackStart: CGFloat { size.width + flyerWidth * 0.7 }
    private var trackLength: CGFloat { size.width + flyerWidth * 1.4 }
    /// A gentle glide: about eight seconds to cross, slower still with calmer motion.
    private var pace: CGFloat { trackLength / (Effects.reducedMotion ? 11 : 8) }

    override func layout() {
        mosey.resize(min(play.height * 0.42, 210))
        otter.resize(min(play.height * 0.3, 140))
        mosey.position = CGPoint(x: heroX + mosey.size * 0.25, y: groundY)
        otter.position = CGPoint(x: heroX, y: groundY + mosey.size * 0.05)
        for (index, flyer) in gates.enumerated() { place(flyer, index: index) }
    }

    // MARK: - Questions

    override func caption(for question: Question) -> String { question.prompt }

    override func present(_ question: Question) {
        gates.forEach { $0.removeFromParent() }
        gates = []
        travelled = []
        let spacing = trackLength / CGFloat(max(question.choices.count, 1))
        // A different lane order each time, so the right answer isn't always on the same height.
        let order = Array(0..<question.choices.count).shuffled()
        for (index, choice) in question.choices.enumerated() {
            let flyer = makeFlyer(carrying: choice)
            flyer.userData = ["lane": order[index] % lanes.count, "phase": CGFloat.random(in: 0...(2 * .pi))]
            addChild(flyer)
            gates.append(flyer)
            // They come on one after another, already spread out along the sky.
            travelled.append(-CGFloat(index) * spacing * 0.55)
            place(flyer, index: gates.count - 1)
        }
        acceptingAnswers = true
        AudioManager.shared.play(.chirp, volume: 0.5)
    }

    private func makeFlyer(carrying choice: String) -> SKNode {
        let flyer = SKNode()
        flyer.name = choice
        flyer.zPosition = 20
        let texture = Art.hasAsset("swoop_flyer") ? Art.texture("swoop_flyer") : Art.texture(theme.guardian)
        let width = flyerWidth
        let body = SKSpriteNode(texture: texture, size: CGSize(width: width, height: width * texture.size().height / max(texture.size().width, 1)))
        body.name = "body"
        // Painted facing left, the way they fly.
        body.position = CGPoint(x: 0, y: body.size.height * 0.3)
        flyer.addChild(body)
        if !Effects.reducedMotion {
            body.run(.repeatForever(.sequence([.scaleY(to: 0.9, duration: 0.22), .scaleY(to: 1.04, duration: 0.22)])))
        }
        let stoneSize = CGSize(width: width * 0.62, height: width * 0.36)
        let rope = SKShapeNode(rectOf: CGSize(width: 3, height: width * 0.22))
        rope.fillColor = UIColor(hex: "#6B4A2B")
        rope.strokeColor = .clear
        rope.position = CGPoint(x: -width * 0.06, y: -width * 0.02)
        flyer.addChild(rope)
        let stone = SKSpriteNode(texture: Art.texture("stone"), size: stoneSize)
        stone.name = "stone"
        stone.position = CGPoint(x: -width * 0.06, y: -width * 0.22)
        flyer.addChild(stone)
        let plate = makeSign(text: choice, size: CGSize(width: stoneSize.width * 0.78, height: stoneSize.height * 0.66),
                             fill: UIColor(hex: "#FFF6E0"), fontSize: stoneSize.height * 0.46)
        plate.zPosition = 1
        stone.addChild(plate)
        return flyer
    }

    private func place(_ flyer: SKNode, index: Int) {
        guard travelled.indices.contains(index), let lane = flyer.userData?["lane"] as? Int else { return }
        let along = travelled[index]
        let x = along < 0 ? trackStart - along : trackStart - along.truncatingRemainder(dividingBy: trackLength)
        let phase = flyer.userData?["phase"] as? CGFloat ?? 0
        let bob = Effects.reducedMotion ? 0 : sin(CGFloat(clock) * 2.2 + phase) * play.height * 0.025
        flyer.position = CGPoint(x: x, y: lanes[min(lane, lanes.count - 1)] + bob)
    }

    // MARK: - Touch

    /// An answer chosen from VoiceOver's buttons rather than by tapping a flyer.
    override func handleChoice(_ choice: String) {
        guard acceptingAnswers, let flyer = gates.first(where: { $0.name == choice }) else { return }
        let question = current
        choose(flyer)
        noteChoice(choice, for: question)
    }

    #if DEBUG
    override func debugAnswer(_ question: Question) {
        guard acceptingAnswers, let flyer = gates.first(where: { $0.name == question.correctChoice }),
              flyer.position.x < play.maxX, flyer.position.x > play.minX else { return }
        choose(flyer)
    }
    #endif

    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
        guard acceptingAnswers, let point = touches.first?.location(in: self) else { return }
        // Generous: the nearest flyer within reach of the finger, body or stone.
        let reach = max(70, flyerWidth * 0.7)
        let nearest = gates.filter { $0.alpha == 1 }.min { $0.position.distance(to: point) < $1.position.distance(to: point) }
        guard let nearest, nearest.position.distance(to: point) < reach else { return }
        choose(nearest)
    }

    private func choose(_ flyer: SKNode) {
        guard let question = current, let choice = flyer.name, flyer.alpha == 1 else { return }
        if question.isCorrect(choice: choice) {
            catchStone(from: flyer)
        } else {
            // A cross squawk, and off it flaps: that answer is gone for this question.
            AudioManager.shared.play(.chirp, volume: 0.8)
            flyer.run(.sequence([.wobble(), .fadeAlpha(to: 0.35, duration: 0.2)]))
            if let index = gates.firstIndex(where: { $0 === flyer }) {
                gates.remove(at: index)
                travelled.remove(at: index)
            }
            let away = SKAction.move(by: CGVector(dx: -play.width * 0.3, dy: play.height * 0.6), duration: Effects.reducedMotion ? 0.4 : 0.9)
            away.timingMode = .easeIn
            flyer.run(.sequence([.wait(forDuration: 0.3), .group([away, .fadeOut(withDuration: 0.8)]), .removeFromParent()]))
            Effects.floatPicture("💫", at: flyer.position, size: min(play.height * 0.12, 50), in: self)
            slip()
        }
    }

    /// The pterosaur lets go and the stone drops, bouncing into Otter's paws.
    private func catchStone(from flyer: SKNode) {
        acceptingAnswers = false
        guard let stone = flyer.childNode(withName: "stone") as? SKSpriteNode else { return }
        let start = convert(stone.position, from: flyer)
        stone.removeFromParent()
        stone.position = start
        stone.zPosition = 40
        addChild(stone)
        let paws = CGPoint(x: otter.position.x + otter.size * 0.1, y: otter.position.y + otter.size * 0.55)
        AudioManager.shared.play(.whoosh, volume: 0.6)
        let fall: SKAction
        if Effects.reducedMotion {
            fall = .move(to: paws, duration: 0.4)
        } else {
            let arc = UIBezierPath()
            arc.move(to: start)
            arc.addQuadCurve(to: paws, controlPoint: CGPoint(x: (start.x + paws.x) / 2, y: max(start.y, paws.y) + play.height * 0.12))
            fall = .group([.follow(arc.cgPath, asOffset: false, orientToPath: false, duration: 0.75), .rotate(byAngle: -.pi * 2, duration: 0.75)])
        }
        fall.timingMode = .easeIn
        stone.run(.sequence([fall, .run { [weak self] in
            guard let self else { return }
            AudioManager.shared.play(.plank, volume: 0.7)
            self.stonesCaught += 1
            let outcome = self.succeed(at: paws)
            self.otter.react(.cheer, hold: 0.8)
            self.pileUp(stone)
            self.flyAway(finishing: outcome?.isLevelComplete == true)
        }]))
        // The flyer flaps up, lighter, with a happy squawk.
        if let index = gates.firstIndex(where: { $0 === flyer }) {
            gates.remove(at: index)
            travelled.remove(at: index)
        }
        AudioManager.shared.play(.chirp, volume: 0.7)
        let up = SKAction.move(by: CGVector(dx: -play.width * 0.2, dy: play.height * 0.7), duration: 1.1)
        up.timingMode = .easeIn
        flyer.run(.sequence([.group([up, .sequence([.wait(forDuration: 0.6), .fadeOut(withDuration: 0.5)])]), .removeFromParent()]))
    }

    /// Caught stones stack up beside the heroes, one for each right answer.
    private func pileUp(_ stone: SKSpriteNode) {
        stone.removeAllActions()
        stone.zRotation = CGFloat.random(in: -0.15...0.15)
        stone.childNode(withName: "label")?.removeFromParent()
        let small = stone.size.width * 0.5
        let row = (stonesCaught - 1) % 4, layer = (stonesCaught - 1) / 4
        let target = CGPoint(x: heroX + mosey.size * 0.9 + CGFloat(row) * small * 0.9 + CGFloat(layer) * small * 0.45,
                             y: groundY + CGFloat(layer) * small * 0.5)
        stone.children.forEach { $0.run(.fadeOut(withDuration: 0.2)) }
        stone.run(.group([.move(to: target, duration: 0.35), .scale(to: 0.5, duration: 0.35)]))
    }

    /// The rest of the squad flaps away; the next lot arrive with the next question.
    private func flyAway(finishing: Bool) {
        for flyer in gates {
            let away = SKAction.move(by: CGVector(dx: -play.width * 0.15, dy: play.height * 0.8), duration: 0.9)
            away.timingMode = .easeIn
            flyer.run(.sequence([.group([away, .fadeOut(withDuration: 0.9)]), .removeFromParent()]))
        }
        gates = []
        travelled = []
        if finishing {
            finishLevel(after: 0.4)
        } else {
            run(.sequence([.wait(forDuration: 1.2), .run { [weak self] in self?.askNext() }]))
        }
    }

    // MARK: - Frame loop

    override func update(_ currentTime: TimeInterval) {
        guard isBuilt else { return }
        let delta = min(lastTime == 0 ? 0 : currentTime - lastTime, 1.0 / 20)
        lastTime = currentTime
        clock += delta
        guard acceptingAnswers else { return }
        for index in travelled.indices {
            travelled[index] += pace * CGFloat(delta)
            place(gates[index], index: index)
        }
    }
}
