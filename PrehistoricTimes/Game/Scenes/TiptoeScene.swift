import PrehistoricTimesCore
import SpriteKit
import UIKit

/// Tiptoe Past. The zone's boss is fast asleep. Every right answer is one tiptoe step closer to the
/// Times Machine part she is sleeping on; a wrong answer makes her snore louder and stir. She never
/// wakes up here (the chase is saved for the Big Escape): if she gets too restless she rolls over
/// and settles again. New facts are answered with buttons, familiar ones on the number pad.
final class TiptoeScene: GameScene {
    private let sleeper = SKSpriteNode()
    private var sign: SKSpriteNode?
    /// The sign's full size. Its `size` reads small while it pops in, so it is remembered here.
    private var signSize = CGSize.zero
    private var entryBoxes: [SKSpriteNode] = []
    private var entry = ""
    private var busy = false
    private var steps = 0
    /// How restless the sleeper is, from 0 (deeply asleep) to 1 (about to roll over).
    private var stir: CGFloat = 0

    override func build() {
        sleeper.texture = Art.texture(theme.guardianSleep ?? theme.guardian)
        sleeper.anchorPoint = CGPoint(x: 0.5, y: 0)
        sleeper.zPosition = 9
        addChild(sleeper)
        mosey.restPose = .dash
        mosey.set(.dash, pop: false)
        mosey.zPosition = 12
        otter.zPosition = 13
        addChild(mosey)
        addChild(otter)
        if !Effects.reducedMotion {
            sleeper.run(.repeatForever(SKAction.sequence([.scaleY(to: 1.025, duration: 1.6), .scaleY(to: 1, duration: 1.6)]).eased()))
        }
        // Snores and floating Zs while she sleeps; louder and bigger as she stirs.
        run(.repeatForever(.sequence([.wait(forDuration: 2.4), .run { [weak self] in self?.breathe() }])), withKey: "snoring")
    }

    // MARK: - Geometry

    private var sleeperHeight: CGFloat { min(play.height * 0.56, 360) }
    /// Otter starts far enough in for Mosey to fit behind him.
    private var startX: CGFloat { play.minX + mosey.footprint.width * 1.05 + otter.footprint.width * 0.5 }
    /// How far behind Otter Mosey walks, so they never overlap.
    private var followGap: CGFloat { mosey.footprint.width * 0.5 + otter.footprint.width * 0.5 + 6 }
    /// Where Otter stops: just short of the nest.
    private var endX: CGFloat { sleeper.position.x - sleeper.size.width * 0.5 - otter.size * 0.15 }
    private var signPosition: CGPoint { CGPoint(x: play.minX + play.width * 0.4, y: play.maxY - play.height * 0.14) }

    private func otterX(after steps: Int) -> CGFloat {
        startX + (endX - startX) * CGFloat(steps) / CGFloat(max(session.total, 1))
    }

    override func layout() {
        let texture = sleeper.texture?.size() ?? CGSize(width: 1, height: 1)
        sleeper.size = CGSize(width: sleeperHeight * texture.width / texture.height, height: sleeperHeight)
        sleeper.position = CGPoint(x: play.maxX - sleeper.size.width * 0.5, y: groundY)
        otter.resize(min(play.height * 0.3, 200))
        mosey.resize(min(play.height * 0.36, 230))
        placeHeroes()
        sign?.position = signPosition
        layoutEntry()
    }

    private func placeHeroes() {
        let x = otterX(after: steps)
        otter.position = CGPoint(x: x, y: groundY)
        mosey.position = CGPoint(x: x - followGap, y: groundY + mosey.footprint.height * 0.38)
    }

    // MARK: - Questions

    override func caption(for question: Question) -> String {
        guard question.prompt.count <= 22 else { return question.prompt }
        return question.format == .typed ? "Type the answer to tiptoe closer!" : "Tap the answer to tiptoe closer!"
    }

    override func present(_ question: Question) {
        busy = false
        entry = ""
        sign?.removeFromParent()
        let text = question.prompt.count <= 22 ? question.prompt : "?"
        let fontSize = min(play.height * 0.1, 42)
        signSize = CGSize(width: min(CGFloat(text.count) * fontSize * 0.68 + 56, play.width * 0.5), height: fontSize * 1.7)
        let board = makeSign(text: text, size: signSize, fontSize: fontSize)
        board.position = signPosition
        board.zPosition = 16
        board.setScale(0)
        board.run(.pop())
        addChild(board)
        sign = board
        buildEntry(length: question.format == .typed ? question.typingTarget.count : 0)
    }

    private func buildEntry(length: Int) {
        entryBoxes.forEach { $0.removeFromParent() }
        entryBoxes = []
        let side = min(play.height * 0.14, 58)
        for _ in 0..<length {
            let box = makeSign(text: "", size: CGSize(width: side, height: side * 1.1), fontSize: side * 0.7, radius: 10)
            box.zPosition = 18
            addChild(box)
            entryBoxes.append(box)
        }
        layoutEntry()
    }

    private func layoutEntry() {
        guard let first = entryBoxes.first else { return }
        let step = first.size.width * 1.12
        let centre = sign?.position ?? signPosition
        for (index, box) in entryBoxes.enumerated() {
            box.position = CGPoint(x: centre.x + (CGFloat(index) - CGFloat(entryBoxes.count - 1) / 2) * step,
                                   y: centre.y - signSize.height * 0.5 - first.size.height * 0.75)
        }
    }

    private func showEntry() {
        let digits = Array(entry)
        for (index, box) in entryBoxes.enumerated() {
            signLabel(box)?.string = index < digits.count ? String(digits[index]) : ""
        }
    }

    // MARK: - Input

    override func handleKey(_ character: Character) {
        guard let question = current, question.format == .typed, !busy, character.isNumber,
              entry.count < question.typingTarget.count else { return }
        entry.append(character)
        showEntry()
        AudioManager.shared.play(.key, volume: 0.5)
        guard entry.count == question.typingTarget.count else { return }
        busy = true
        if question.isCorrect(typed: entry) {
            tiptoe()
        } else {
            entryBoxes.forEach { $0.run(.wobble(distance: 5)) }
            restless()
            run(.sequence([.wait(forDuration: 0.5), .run { [weak self] in
                self?.entry = ""
                self?.showEntry()
                self?.busy = false
            }]))
        }
    }

    override func handleBackspace() {
        guard !busy, !entry.isEmpty else { return }
        entry.removeLast()
        showEntry()
    }

    override func handleChoice(_ choice: String) {
        guard let question = current, question.format == .choice, !busy, !bridge.ruledOut.contains(choice) else { return }
        busy = true
        if question.isCorrect(choice: choice) {
            tiptoe()
        } else {
            bridge.ruledOut.insert(choice)
            restless()
            run(.sequence([.wait(forDuration: 0.4), .run { [weak self] in self?.busy = false }]))
        }
    }

    // MARK: - Moments

    /// One careful step closer.
    private func tiptoe() {
        steps += 1
        AudioManager.shared.play(.tiptoe, volume: 0.8)
        let outcome = succeed(at: sign?.position ?? signPosition)
        sign?.run(.sequence([.fadeOut(withDuration: 0.2), .removeFromParent()]))
        sign = nil
        entryBoxes.forEach { $0.run(.sequence([.fadeOut(withDuration: 0.2), .removeFromParent()])) }
        entryBoxes = []
        stir = max(0, stir - 0.15)
        let x = otterX(after: steps)
        otter.set(.dash)
        otter.run(.sequence([SKAction.moveTo(x: x, duration: Effects.reducedMotion ? 0.2 : 0.7).eased(), .run { [weak self] in
            self?.otter.set(.idle)
        }]))
        mosey.run(SKAction.moveTo(x: x - followGap, duration: Effects.reducedMotion ? 0.2 : 0.8).eased())
        if outcome?.isLevelComplete == true {
            run(.sequence([.wait(forDuration: 1.0), .run { [weak self] in self?.reachNest() }]))
        } else {
            run(.sequence([.wait(forDuration: 1.3), .run { [weak self] in self?.askNext() }]))
        }
    }

    /// A wrong answer: she snores louder and shuffles. Too restless, and she rolls over.
    private func restless() {
        stir = min(1, stir + 0.35)
        slip()
        otter.react(.scared, hold: 0.8)
        breathe(loud: true)
        if !Effects.reducedMotion {
            sleeper.run(.sequence([.rotate(toAngle: 0.04, duration: 0.1), .rotate(toAngle: -0.04, duration: 0.14), .rotate(toAngle: 0, duration: 0.1)]))
        }
        Effects.floatPicture("❗", at: CGPoint(x: sleeper.position.x, y: sleeper.position.y + sleeper.size.height * 0.9),
                             size: min(play.height * 0.14, 60), in: self)
        guard stir >= 1 else { return }
        stir = 0
        bridge.showToast("Phew! She rolled over and went back to sleep.")
        if !Effects.reducedMotion {
            sleeper.run(.sequence([.scaleX(to: 1.08, y: 0.9, duration: 0.2), .scaleX(to: 1, y: 1, duration: 0.3)]))
        }
    }

    /// A snore and a floating Z, bigger as she stirs.
    private func breathe(loud: Bool = false) {
        AudioManager.shared.play(.snore, volume: Float(loud ? 0.75 : 0.25 + 0.35 * stir))
        let size = min(play.height * 0.12, 54) * (1 + stir * 0.8)
        Effects.floatPicture("💤", at: CGPoint(x: sleeper.position.x - sleeper.size.width * 0.2, y: sleeper.position.y + sleeper.size.height * 0.75),
                             size: size, in: self)
    }

    /// Made it: Otter peeks at the part under her and the two creep away to plan the escape.
    private func reachNest() {
        removeAction(forKey: "snoring")
        otter.celebrate()
        Effects.floatPicture("⚙️", at: CGPoint(x: sleeper.position.x - sleeper.size.width * 0.1, y: sleeper.position.y + sleeper.size.height * 0.4),
                             size: min(play.height * 0.18, 80), in: self)
        finishLevel(after: 0.8)
    }
}
