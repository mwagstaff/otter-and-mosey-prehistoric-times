import PrehistoricTimesCore
import SpriteKit
import UIKit

/// Dino Dash. Otter and Mosey run from the zone's boss. Three signposts carry answers: tapping the
/// right one is a burst of speed that pulls them further ahead; a wrong one is a stumble and the
/// chaser gains. Nobody is caught for long: a catch is a sniff and a comic tumble, then the chase
/// carries on, so a level can never be failed. The chase pace comes from the grown-ups' settings:
/// calm (the chaser only gains on a wrong answer), exciting (it also creeps up while the child is
/// choosing) or gentle (no chaser at all).
final class DinoDashScene: GameScene {
    private enum Phase { case running, arriving, choosing, dashing }

    private var phase = Phase.running
    /// True while the signposts are in place and can be tapped (read by the play-test probe).
    private var acceptingAnswers = false
    private var gates: [SKNode] = []
    private var pace: CGFloat = 170
    private var targetPace: CGFloat = 170
    private var lane = 1
    /// The runners' feet, easing towards the chosen path; the bounce is added on top.
    private var runY: CGFloat = 0
    private var lastTime: TimeInterval = 0
    private var clock: TimeInterval = 0
    private let chaser = SKSpriteNode()
    private let meter = SKNode()
    private let meterTrack = SKSpriteNode()
    private let meterHeroes = SKSpriteNode(texture: Art.emoji("🦦"))
    private let meterChaser = SKSpriteNode()
    /// How far ahead the heroes are, from 0 (caught) to 1 (well clear).
    private var gap: CGFloat = 0.55
    private var catching = false

    override var scrollsBackdrop: Bool { true }
    private var chasePace: ChasePace { session.settings.chasePace }
    private var hasChaser: Bool { chasePace != .gentle }

    override func build() {
        mosey.restPose = .dash
        mosey.set(.dash, pop: false)
        otter.restPose = .dash
        otter.set(.dash, pop: false)
        mosey.zPosition = 20
        otter.zPosition = 21
        addChild(mosey)
        addChild(otter)
        chaser.texture = theme.boss(theme.guardianChase, facingLeft: false)
        chaser.anchorPoint = CGPoint(x: 0.5, y: 0)
        chaser.zPosition = 18
        chaser.isHidden = !hasChaser
        addChild(chaser)
        meter.zPosition = 60
        meter.isHidden = !hasChaser
        meterTrack.zPosition = 0
        meterChaser.texture = theme.boss(theme.guardianChase, facingLeft: false)
        meterChaser.zPosition = 1
        meterHeroes.zPosition = 2
        meter.addChild(meterTrack)
        meter.addChild(meterChaser)
        meter.addChild(meterHeroes)
        addChild(meter)
    }

    // MARK: - Geometry

    /// Where the runners' feet are on each path, top to bottom.
    private var lanes: [CGFloat] { [0.62, 0.37, 0.12].map { play.minY + play.height * $0 } }
    private var heroX: CGFloat { play.minX + play.width * 0.42 }
    private var gateX: CGFloat { play.maxX - play.width * 0.13 }
    private var gateSize: CGFloat { min(play.height * 0.26, 150) }

    private var chaserX: CGFloat { heroX - mosey.size * 0.7 - gap * play.width * 0.24 }

    override func layout() {
        mosey.resize(min(play.height * 0.4, 220))
        otter.resize(mosey.size * 0.58)
        let texture = chaser.texture?.size() ?? CGSize(width: 1, height: 1)
        let height = min(play.height * 0.52, 300)
        chaser.size = CGSize(width: height * texture.width / texture.height, height: height)
        runY = lanes[lane]
        placeHeroes(y: runY)
        chaser.position = CGPoint(x: chaserX, y: lanes[lane])
        let trackSize = CGSize(width: min(play.width * 0.32, 260), height: 12)
        meterTrack.texture = Art.panel(size: trackSize, fill: UIColor(hex: "#FFF6E0"), radius: 6, lineWidth: 3)
        meterTrack.size = trackSize
        meter.position = CGPoint(x: play.midX, y: play.maxY - 16)
        let icon = trackSize.height * 2.6
        meterHeroes.size = CGSize(width: icon, height: icon)
        let chaserIcon = meterChaser.texture?.size() ?? CGSize(width: 1, height: 1)
        meterChaser.size = CGSize(width: icon * 1.3 * chaserIcon.width / chaserIcon.height, height: icon * 1.3)
        meterChaser.position = CGPoint(x: -trackSize.width / 2, y: 0)
        updateMeter()
        if phase == .choosing {
            for (index, gate) in gates.enumerated() { gate.position = CGPoint(x: gateX, y: lanes[index] + gateSize * 0.45) }
        }
    }

    private func placeHeroes(y: CGFloat) {
        mosey.position = CGPoint(x: heroX, y: y + mosey.footprint.height * 0.42)
        // Otter runs just ahead of Mosey's nose, never on top of him.
        otter.position = CGPoint(x: heroX + mosey.footprint.width * 0.5 + otter.footprint.width * 0.45, y: y)
    }

    private func updateMeter() {
        let width = meterTrack.size.width
        meterHeroes.position = CGPoint(x: -width / 2 + width * (0.15 + 0.85 * gap), y: 0)
    }

    // MARK: - Flow

    override func start() {
        if hasChaser {
            AudioManager.shared.play(theme.roar, volume: 0.85)
            AudioManager.shared.play(.stomp, volume: 0.6)
            otter.react(.scared, hold: 0.9)
        }
        // The roar plays while the first signposts slide in.
        askNext()
    }

    override func caption(for question: Question) -> String { question.prompt }

    override func present(_ question: Question) {
        phase = .arriving
        acceptingAnswers = false
        gates.forEach { $0.removeFromParent() }
        gates = []
        for (index, choice) in question.choices.enumerated() {
            let gate = SKNode()
            gate.name = choice
            for leaf in 0..<5 {
                let decoration = SKSpriteNode(texture: Art.emoji(theme.gateDecoration), size: CGSize(width: gateSize * 0.3, height: gateSize * 0.3))
                let angle = .pi * (0.15 + 0.7 * CGFloat(leaf) / 4)
                decoration.position = CGPoint(x: cos(angle) * gateSize * 0.42, y: sin(angle) * gateSize * 0.32)
                gate.addChild(decoration)
            }
            let plateSize = CGSize(width: gateSize * 0.82, height: gateSize * 0.48)
            let plate = makeSign(text: choice, size: plateSize, fontSize: plateSize.height * 0.64)
            plate.zPosition = 1
            gate.addChild(plate)
            gate.position = CGPoint(x: size.width + gateSize, y: lanes[index] + gateSize * 0.45)
            gate.zPosition = 15
            addChild(gate)
            gates.append(gate)
            let arrive = SKAction.moveTo(x: gateX, duration: Effects.reducedMotion ? 0.3 : 0.9)
            arrive.timingMode = .easeOut
            gate.run(arrive)
        }
        targetPace = 70
        run(.sequence([.wait(forDuration: Effects.reducedMotion ? 0.35 : 0.95), .run { [weak self] in
            guard let self else { return }
            self.phase = .choosing
            self.acceptingAnswers = true
            self.layout()
        }]))
    }

    /// An answer chosen from VoiceOver's buttons rather than by tapping a signpost.
    override func handleChoice(_ choice: String) {
        guard acceptingAnswers, !catching, let index = gates.firstIndex(where: { $0.name == choice }) else { return }
        let question = current
        choose(index)
        noteChoice(choice, for: question)
    }

    #if DEBUG
    override func debugAnswer(_ question: Question) {
        guard acceptingAnswers, !catching, let index = gates.firstIndex(where: { $0.name == question.correctChoice }) else { return }
        choose(index)
    }
    #endif

    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
        guard let point = touches.first?.location(in: self), phase == .choosing, !catching else { return }
        // Forgiving touch: the signpost nearest the tap, anywhere right of the runners.
        guard point.x > heroX, let index = gates.indices.min(by: {
            gates[$0].position.distance(to: point) < gates[$1].position.distance(to: point)
        }) else { return }
        choose(index)
    }

    private func choose(_ index: Int) {
        guard let question = current, gates.indices.contains(index) else { return }
        let gate = gates[index]
        guard gate.alpha == 1, let choice = gate.name else { return }
        if question.isCorrect(choice: choice) {
            dash(to: index, through: gate)
        } else {
            gate.run(.sequence([.wobble(), .fadeAlpha(to: 0.35, duration: 0.2)]))
            Effects.burst(at: gate.position, colour: .white, count: 10, in: self)
            otter.react(.oops, hold: 0.8)
            stumble()
            slip()
        }
    }

    private func dash(to index: Int, through gate: SKNode) {
        phase = .dashing
        acceptingAnswers = false
        lane = index
        targetPace = 760
        pace = 600
        gap = min(1, gap + 0.2)
        AudioManager.shared.play(.whoosh, volume: 0.7)
        let outcome = succeed(at: gate.position)
        Effects.rainbowBurst(at: gate.position, in: self, count: 36)
        cameraPunch()
        for other in gates {
            let exit = SKAction.moveTo(x: -gateSize * 1.5, duration: 0.5)
            exit.timingMode = .easeIn
            other.run(.sequence([other === gate ? exit : .group([exit, .fadeOut(withDuration: 0.3)]), .removeFromParent()]))
        }
        gates = []
        let done = outcome?.isLevelComplete == true
        run(.sequence([
            .wait(forDuration: 0.8),
            .run { [weak self] in
                guard let self else { return }
                self.targetPace = 190
                self.phase = .running
                if done { self.escape() }
            },
            .wait(forDuration: done ? 0 : 1.2),
            .run { [weak self] in if !done { self?.askNext() } },
        ]))
    }

    /// A wrong turn: a stumble, and the chaser gains (never in gentle mode).
    private func stumble() {
        AudioManager.shared.play(.stomp, volume: hasChaser ? 0.7 : 0.3)
        targetPace = 40
        guard hasChaser else { return }
        gap = max(0, gap - 0.24)
        if gap <= 0.01 { caught() }
    }

    /// Caught, but only for a moment: a big sniff, a comic tumble, and off they go again.
    private func caught() {
        guard !catching else { return }
        catching = true
        acceptingAnswers = false
        AudioManager.shared.play(theme.roar, volume: chasePace == .exciting ? 0.7 : 0.5)
        otter.react(.scared, hold: 1.4)
        mosey.react(.scared, hold: 1.4)
        Effects.floatPicture("💨", at: CGPoint(x: heroX - mosey.size * 0.3, y: lanes[lane] + mosey.size * 0.5),
                             size: min(play.height * 0.2, 90), in: self)
        bridge.showToast("Sniff, sniff… phew! Keep running!")
        run(.sequence([.wait(forDuration: 1.5), .run { [weak self] in
            guard let self else { return }
            self.gap = 0.45
            self.catching = false
            if self.phase == .choosing { self.acceptingAnswers = true }
        }]))
    }

    /// The last right answer: a final sprint while the chaser gives up, puffed out.
    private func escape() {
        acceptingAnswers = false
        targetPace = 900
        gap = 1
        if hasChaser {
            chaser.run(.sequence([.wait(forDuration: 0.4), .moveBy(x: -play.width * 0.4, y: 0, duration: 0.8), .fadeOut(withDuration: 0.2)]))
        }
        otter.run(.sequence([.wait(forDuration: 0.6), .run { [weak self] in self?.otter.celebrate() }]))
        finishLevel(after: 1.0)
    }

    // MARK: - Frame loop

    override func update(_ currentTime: TimeInterval) {
        guard isBuilt else { return }
        let delta = CGFloat(min(lastTime == 0 ? 0 : currentTime - lastTime, 1.0 / 20))
        lastTime = currentTime
        clock += Double(delta)
        pace += (targetPace - pace) * min(delta * 3, 1)
        backdrop.scroll(by: pace * delta)
        // Exciting chases creep up while the child is choosing; calm ones only move on mistakes.
        if chasePace == .exciting, phase == .choosing, !catching {
            gap = max(0, gap - 0.03 * delta)
            if gap <= 0.01 { caught() }
        }
        // The runners trot towards their path with a little bounce in their step.
        let bounce = Effects.reducedMotion ? 0 : abs(sin(CGFloat(clock) * 11)) * min(play.height * 0.02, 8)
        let laneY = lanes[lane]
        runY += (laneY - runY) * min(delta * 8, 1)
        placeHeroes(y: runY + bounce)
        if hasChaser {
            let target = CGPoint(x: catching ? heroX - mosey.size * 0.45 : chaserX, y: laneY)
            chaser.position = CGPoint(x: chaser.position.x + (target.x - chaser.position.x) * min(delta * 3, 1),
                                      y: chaser.position.y + (target.y - chaser.position.y) * min(delta * 4, 1) + bounce * 0.2)
            updateMeter()
        }
    }
}
