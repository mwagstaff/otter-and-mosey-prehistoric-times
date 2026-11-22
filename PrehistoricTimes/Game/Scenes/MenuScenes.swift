import PrehistoricTimesCore
import SpriteKit
import UIKit

/// A scene that fills the screen with one painted background and keeps it covering on resize.
class CoverScene: SKScene {
    let cover = SKSpriteNode()
    let greyCover = SKSpriteNode()
    private(set) var isBuilt = false
    var insets = UIEdgeInsets.zero { didSet { if isBuilt, insets != oldValue { layout() } } }

    init(background: String) {
        super.init(size: CGSize(width: 844, height: 390))
        scaleMode = .resizeFill
        cover.texture = Art.texture(background)
        greyCover.texture = Art.greyTexture(background)
        greyCover.alpha = 0
        cover.zPosition = -100
        greyCover.zPosition = -99
        addChild(cover)
        addChild(greyCover)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) { fatalError("not used") }

    var play: CGRect {
        CGRect(x: insets.left, y: insets.bottom, width: max(size.width - insets.left - insets.right, 10),
               height: max(size.height - insets.top - insets.bottom, 10))
    }

    override func didMove(to view: SKView) {
        view.ignoresSiblingOrder = true
        buildIfReady()
    }

    override func didChangeSize(_ oldSize: CGSize) {
        buildIfReady()
        if isBuilt { fit(); layout() }
    }

    private func buildIfReady() {
        guard !isBuilt, view != nil, size.width > 100, size.height > 100 else { return }
        isBuilt = true
        fit()
        build()
        layout()
    }

    private func fit() {
        guard let texture = cover.texture?.size() else { return }
        let scale = max(size.width / texture.width, size.height / texture.height)
        for sprite in [cover, greyCover] {
            sprite.size = CGSize(width: texture.width * scale, height: texture.height * scale)
            sprite.position = CGPoint(x: size.width / 2, y: size.height / 2)
        }
    }

    /// Swaps the painted background, keeping it covering the screen.
    func changeBackground(to name: String) {
        cover.texture = Art.texture(name)
        greyCover.texture = Art.greyTexture(name)
        fit()
    }

    func build() {}
    func layout() {}
}

/// The animated title screen: the home lagoon with Otter and Mosey, who react when tapped.
final class TitleScene: CoverScene {
    private let otter = CharacterNode(kind: .otter, size: 120)
    private let mosey = CharacterNode(kind: .mosey, size: 200)

    init() { super.init(background: "bg_title") }

    private var wildlife: IslandWildlife?

    func setSceneryMotion(_ enabled: Bool) {
        cover.shader = enabled ? SKShader(fileNamed: "RainbowIslandWater.fsh") : nil
        cover.shader?.uniforms = [SKUniform(name: "u_saturation", float: 1)]
        wildlife?.removeFromParent()
        wildlife = nil
        if enabled {
            let layer = IslandWildlife()
            layer.zPosition = 1
            cover.addChild(layer)
            layer.fit(to: cover)
            layer.start()
            wildlife = layer
        }
    }

    override func build() {
        addChild(Effects.ambient(.sparkles, size: size))
        addChild(otter)
        addChild(mosey)
        mosey.facingLeft = true
        otter.startIdle()
        mosey.startIdle()
        // Light glinting on the lagoon.
        let glints = Effects.ambient(.fireflies, size: CGSize(width: size.width, height: size.height * 0.3))
        glints.position = CGPoint(x: size.width / 2, y: size.height * 0.2)
        glints.particleBirthRate = 3
        addChild(glints)
    }

    override func layout() {
        wildlife?.fit(to: cover)
        otter.resize(min(play.height * 0.5, 300))
        mosey.resize(min(play.height * 0.72, 420))
        otter.position = CGPoint(x: play.minX + play.width * 0.13, y: play.minY + play.height * 0.04)
        mosey.position = CGPoint(x: play.maxX - play.width * 0.16, y: play.minY + play.height * 0.3)
    }

    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
        guard let point = touches.first?.location(in: self) else { return }
        for character in [otter, mosey] where character.calculateAccumulatedFrame().contains(point) {
            character.celebrate()
            AudioManager.shared.play(character.kind == .otter ? .jump : .swim)
            Effects.rainbowBurst(at: point, in: self, count: 30)
            Haptics.shared.tap()
            return
        }
        if let wildlife, wildlife.greet(at: wildlife.convert(point, from: self)) { return }
        Effects.burst(at: point, colour: .white, count: 10, in: self)
    }
}

/// What the map needs to know about one island.
struct IslandState: Equatable {
    var id: String
    var name: String
    var unlocked: Bool
    /// False for a zone still being built: it shows as "Coming soon".
    var ready: Bool
    /// The Times Machine part won back here, and whether it has been.
    var part: String
    var hasCrystal: Bool
    /// 0 = grey, 1 = fully restored.
    var restoration: CGFloat
    var isCurrent: Bool
}

/// The valley map: Crash Camp in the middle, with the wrecked Times Machine and a slot for each of
/// its six parts, and the six zones ringed around it. Locked zones are grey; finished ones glow.
final class WorldMapScene: CoverScene {
    var onSelect: ((String) -> Void)?
    private var states: [IslandState] = []
    private var islands: [String: SKNode] = [:]
    private var selected: String?
    private let boat = SKSpriteNode(texture: Art.texture("duo_ride"))
    /// The newest baby dinosaurs from the Dino Nursery, trotting along behind Otter and Mosey.
    private let followers = SKNode()
    var pets: [String] = [] {
        didSet { if pets != oldValue, isBuilt { layoutFollowers() } }
    }
    private let pathLayer = SKNode()
    private let camp = SKNode()

    /// Zone positions as fractions of the play area, in a ring around Crash Camp.
    private let spots: [CGPoint] = [
        CGPoint(x: 0.12, y: 0.22), CGPoint(x: 0.16, y: 0.7), CGPoint(x: 0.34, y: 0.8),
        CGPoint(x: 0.66, y: 0.8), CGPoint(x: 0.84, y: 0.7), CGPoint(x: 0.88, y: 0.22),
    ]
    private var campCentre: CGPoint { CGPoint(x: play.midX, y: play.minY + play.height * 0.3) }

    init() { super.init(background: "bg_map") }

    func configure(_ states: [IslandState]) {
        guard states != self.states else { return }
        self.states = states
        if isBuilt { rebuild() }
    }

    override func build() {
        addChild(pathLayer)
        camp.zPosition = 8
        addChild(camp)
        boat.zPosition = 30
        addChild(boat)
        followers.zPosition = 29
        addChild(followers)
        let glints = Effects.ambient(.sparkles, size: size)
        glints.particleBirthRate = 4
        addChild(glints)
        rebuild()
    }

    private func point(_ index: Int) -> CGPoint {
        let spot = spots[index % spots.count]
        return CGPoint(x: play.minX + play.width * spot.x, y: play.minY + play.height * spot.y)
    }

    private var islandSize: CGFloat { min(play.width * 0.14, play.height * 0.34) }

    private func rebuild() {
        islands.values.forEach { $0.removeFromParent() }
        islands = [:]
        pathLayer.removeAllChildren()
        for (index, state) in states.enumerated() {
            let node = SKNode()
            node.name = state.id
            let art = "island_\(state.id)"
            let texture = Art.texture(art).size()
            let spriteSize = CGSize(width: islandSize, height: islandSize * texture.height / texture.width)
            let colour = SKSpriteNode(texture: Art.texture(art), size: spriteSize)
            let grey = SKSpriteNode(texture: Art.greyTexture(art), size: spriteSize)
            // Unlocked islands always keep a hint of colour, so they never look like the locked ones.
            // Zones you can play are in full colour; locked and coming-soon ones are grey.
            grey.alpha = state.unlocked && state.ready ? 0 : 1
            grey.zPosition = 1
            node.addChild(colour)
            node.addChild(grey)
            let isNext = state.isCurrent && state.unlocked && state.ready
            if state.hasCrystal {
                let glow = SKSpriteNode(texture: Art.glow, size: CGSize(width: islandSize * 1.5, height: islandSize * 1.5))
                glow.color = UIColor(hex: Catalog.shared.island(state.id)?.colour ?? "#FFFFFF")
                glow.colorBlendFactor = 1
                glow.blendMode = .add
                glow.alpha = 0.55
                glow.zPosition = -1
                node.addChild(glow)
                // The part won back here.
                let partTexture = Art.texture("part_\(state.part)")
                let side = islandSize * 0.3
                let part = SKSpriteNode(texture: partTexture, size: CGSize(width: side * partTexture.size().width / max(partTexture.size().height, 1), height: side))
                part.position = CGPoint(x: spriteSize.width * 0.36, y: spriteSize.height * 0.4)
                part.zPosition = 3
                node.addChild(part)
            }
            if !state.unlocked || !state.ready {
                let lock = SKSpriteNode(texture: Art.emoji("🔒"), size: CGSize(width: islandSize * 0.34, height: islandSize * 0.34))
                lock.zPosition = 3
                node.addChild(lock)
            }
            let fontSize = max(12, islandSize * 0.11)
            // The plate is cut to the measured name, so every typeface gets the same margin.
            let label = GameLabel(state.name, size: fontSize, colour: UIColor(hex: "#0E3B43"))
            let plateSize = CGSize(width: label.frame.width + fontSize * 2.2, height: fontSize * 2.1)
            let plate = SKSpriteNode(texture: Art.panel(size: plateSize, fill: UIColor(hex: isNext ? "#FFC83D" : "#FFF6E0"), radius: 10, lineWidth: 3), size: plateSize)
            plate.position = CGPoint(x: 0, y: -spriteSize.height * 0.58)
            plate.zPosition = 4
            label.zPosition = 1
            plate.addChild(label)
            node.addChild(plate)
            if !state.ready {
                let soonSize = max(10, fontSize * 0.8)
                let soon = GameLabel("Coming soon", size: soonSize, colour: .white)
                let soonPlate = SKSpriteNode(texture: Art.panel(size: CGSize(width: soon.frame.width + soonSize * 1.6, height: soonSize * 1.9),
                                                                fill: UIColor(hex: "#0E3B43"), stroke: .white, radius: 8, lineWidth: 2),
                                             size: CGSize(width: soon.frame.width + soonSize * 1.6, height: soonSize * 1.9))
                soonPlate.position = CGPoint(x: 0, y: plate.position.y - plateSize.height * 0.5 - soonSize)
                soonPlate.zPosition = 4
                soon.zPosition = 1
                soonPlate.addChild(soon)
                node.addChild(soonPlate)
            }
            if isNext {
                addPlayHereMarker(to: node, at: point(index), spriteSize: spriteSize)
            }
            node.position = point(index)
            node.zPosition = 10
            addChild(node)
            islands[state.id] = node
            if !Effects.reducedMotion {
                let bob = SKAction.sequence([.moveBy(x: 0, y: 6, duration: 1.6 + Double(index) * 0.15), .moveBy(x: 0, y: -6, duration: 1.6 + Double(index) * 0.15)]).eased()
                colour.run(.repeatForever(bob))
                grey.run(.repeatForever(bob))
            }
            if index > 0 {
                // A dotted sea route from the previous island.
                let from = point(index - 1), to = point(index)
                let steps = max(Int(from.distance(to: to) / 26), 2)
                for step in 1..<steps {
                    let fraction = CGFloat(step) / CGFloat(steps)
                    let dot = SKSpriteNode(texture: Art.circle(diameter: 24, fill: .white, stroke: UIColor(hex: "#0E3B43"), lineWidth: 3), size: CGSize(width: 9, height: 9))
                    dot.alpha = state.unlocked ? 0.95 : 0.45
                    dot.position = CGPoint(x: from.x + (to.x - from.x) * fraction, y: from.y + (to.y - from.y) * fraction)
                    pathLayer.addChild(dot)
                }
            }
        }
        buildCamp()
        layoutBoat(animated: false)
        if let selected { highlight(selected) }
    }

    override func layout() {
        if !states.isEmpty { rebuild() }
    }

    /// Crash Camp: the Times Machine (wrecked until every part is back) with its six parts around it,
    /// bright once won back and faint until then.
    private func buildCamp() {
        camp.removeAllChildren()
        camp.position = campCentre
        let whole = !states.isEmpty && states.allSatisfy(\.hasCrystal)
        let art = whole ? "machine_whole" : "machine_wrecked"
        let texture = Art.texture(art).size()
        let height = islandSize * 0.95
        let machine = SKSpriteNode(texture: Art.texture(art), size: CGSize(width: height * texture.width / texture.height, height: height))
        camp.addChild(machine)
        if !Effects.reducedMotion, whole {
            machine.run(.repeatForever(.sequence([.moveBy(x: 0, y: 5, duration: 0.9), .moveBy(x: 0, y: -5, duration: 0.9)]).eased()))
        }
        for (index, state) in states.enumerated() {
            let partArt = "part_\(state.part)"
            let partTexture = state.hasCrystal ? Art.texture(partArt) : Art.greyTexture(partArt)
            let side = islandSize * 0.22
            let part = SKSpriteNode(texture: partTexture, size: CGSize(width: side * partTexture.size().width / max(partTexture.size().height, 1), height: side))
            let angle = .pi * (0.95 - 0.9 * CGFloat(index) / CGFloat(max(states.count - 1, 1)))
            part.position = CGPoint(x: cos(angle) * height * 0.9, y: sin(angle) * height * 0.62 + height * 0.12)
            part.alpha = state.hasCrystal ? 1 : 0.55
            camp.addChild(part)
        }
        let fontSize = max(12, islandSize * 0.11)
        let label = GameLabel("Crash Camp", size: fontSize, colour: UIColor(hex: "#0E3B43"))
        let plateSize = CGSize(width: label.frame.width + fontSize * 2.2, height: fontSize * 2.1)
        let plate = SKSpriteNode(texture: Art.panel(size: plateSize, fill: UIColor(hex: "#FFF6E0"), radius: 10, lineWidth: 3), size: plateSize)
        plate.position = CGPoint(x: 0, y: -height * 0.58)
        label.zPosition = 1
        plate.addChild(label)
        camp.addChild(plate)
    }

    /// Picks out the zone to play next: a pulsing gold glow and a bobbing "Play here!" sign beside it.
    private func addPlayHereMarker(to node: SKNode, at position: CGPoint, spriteSize: CGSize) {
        let glow = SKSpriteNode(texture: Art.glow, size: CGSize(width: islandSize * 1.7, height: islandSize * 1.7))
        glow.color = UIColor(hex: "#FFC83D")
        glow.colorBlendFactor = 1
        glow.blendMode = .add
        glow.alpha = 0.75
        glow.zPosition = -2
        node.addChild(glow)

        let ink = UIColor(hex: "#0E3B43")
        let fontSize = max(13, islandSize * 0.12)
        let label = GameLabel("Play here!", size: fontSize, colour: ink)
        label.zPosition = 1
        let signSize = CGSize(width: label.frame.width + fontSize * 1.8, height: fontSize * 2.1)
        let sign = SKSpriteNode(texture: Art.panel(size: signSize, fill: UIColor(hex: "#FFC83D"), stroke: ink, radius: 12, lineWidth: 3), size: signSize)
        sign.addChild(label)
        // A little pointer on the sign's near edge, aimed back at the zone. The sign sits beside the
        // zone (to the right, or to the left near the right-hand edge) so it never covers a neighbour.
        let tip = fontSize * 0.7
        let onRight = position.x + spriteSize.width * 0.55 + signSize.width + tip * 2 < play.maxX
        let side: CGFloat = onRight ? 1 : -1
        let path = CGMutablePath()
        path.move(to: CGPoint(x: 0, y: -tip))
        path.addLine(to: CGPoint(x: 0, y: tip))
        path.addLine(to: CGPoint(x: -tip * side, y: 0))
        path.closeSubpath()
        let pointer = SKShapeNode(path: path)
        pointer.fillColor = UIColor(hex: "#FFC83D")
        pointer.strokeColor = ink
        pointer.lineWidth = 3
        pointer.position = CGPoint(x: -(signSize.width / 2 - 1.5) * side, y: 0)
        pointer.zPosition = -1
        sign.addChild(pointer)

        let marker = SKNode()
        marker.position = CGPoint(x: side * (spriteSize.width * 0.5 + tip + signSize.width * 0.5), y: spriteSize.height * 0.08)
        marker.zPosition = 6
        marker.addChild(sign)
        node.addChild(marker)

        guard !Effects.reducedMotion else { return }
        glow.run(.repeatForever(.sequence([
            .group([.scale(to: 1.12, duration: 0.8), .fadeAlpha(to: 0.95, duration: 0.8)]),
            .group([.scale(to: 0.94, duration: 0.8), .fadeAlpha(to: 0.6, duration: 0.8)]),
        ]).eased()))
        marker.run(.repeatForever(.sequence([.moveBy(x: -8 * side, y: 0, duration: 0.45), .moveBy(x: 8 * side, y: 0, duration: 0.45)]).eased()))
    }

    private func layoutBoat(animated: Bool) {
        guard let index = states.firstIndex(where: { $0.isCurrent }) else {
            boat.isHidden = true
            return
        }
        boat.isHidden = false
        let texture = boat.texture?.size() ?? CGSize(width: 2, height: 1)
        boat.size = CGSize(width: islandSize * 0.62, height: islandSize * 0.62 * texture.height / texture.width)
        let target = CGPoint(x: point(index).x - islandSize * 0.5, y: point(index).y - islandSize * 0.3)
        layoutFollowers()
        if animated {
            boat.run(SKAction.move(to: target, duration: 0.8).eased())
            followers.run(SKAction.move(to: target, duration: 0.95).eased())
        } else {
            followers.position = target
            boat.position = target
            boat.removeAction(forKey: "bob")
            if !Effects.reducedMotion {
                boat.run(.repeatForever(SKAction.sequence([.moveBy(x: 0, y: 5, duration: 0.9), .moveBy(x: 0, y: -5, duration: 0.9)]).eased()), withKey: "bob")
            }
        }
    }

    /// Up to three pets in a little line behind the heroes, each hopping on its own beat.
    private func layoutFollowers() {
        followers.removeAllChildren()
        followers.isHidden = boat.isHidden
        let side = islandSize * 0.2
        for (index, art) in pets.suffix(3).reversed().enumerated() {
            let pet = SKSpriteNode(texture: Art.emoji(art, size: 96), size: CGSize(width: side, height: side))
            pet.position = CGPoint(x: -boat.size.width * 0.45 - CGFloat(index) * side * 0.85, y: -boat.size.height * 0.28 + CGFloat(index % 2) * side * 0.12)
            followers.addChild(pet)
            guard !Effects.reducedMotion else { continue }
            pet.run(.sequence([.wait(forDuration: 0.2 * Double(index)), .repeatForever(.sequence([
                SKAction.moveBy(x: 0, y: side * 0.18, duration: 0.25).eased(), SKAction.moveBy(x: 0, y: -side * 0.18, duration: 0.25).eased(),
                .wait(forDuration: 1.1 + 0.2 * Double(index)),
            ]))]))
        }
    }

    private func highlight(_ id: String) {
        for (key, node) in islands {
            node.removeAction(forKey: "select")
            node.run(SKAction.scale(to: key == id ? 1.14 : 1, duration: 0.2).eased(), withKey: "select")
            node.zPosition = key == id ? 12 : 10
        }
    }

    func select(_ id: String?) {
        selected = id
        highlight(id ?? "")
    }

    /// The moment a newly unlocked island comes into play: it is picked out and sparkles.
    func celebrateUnlock(_ id: String) {
        select(id)
        guard let node = islands[id] else { return }
        AudioManager.shared.play(.unlock)
        Haptics.shared.success()
        let colour = UIColor(hex: Catalog.shared.island(id)?.colour ?? "#FFC83D")
        Effects.burst(at: node.position, colour: colour, count: 26, in: self)
        Effects.burst(at: node.position, colour: UIColor(hex: "#FFE066"), count: 18, in: self)
        guard !Effects.reducedMotion else { return }
        node.run(.sequence([SKAction.scale(to: 1.3, duration: 0.25).eased(), SKAction.scale(to: 1.14, duration: 0.3).eased()]))
    }

    /// The id `onSelect` reports when Crash Camp itself is tapped.
    static let campID = "camp"

    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
        guard let point = touches.first?.location(in: self) else { return }
        // Crash Camp in the middle opens too.
        if camp.position.distance(to: point) < islandSize * 0.75 {
            AudioManager.shared.play(.tap)
            Haptics.shared.tap()
            Effects.burst(at: camp.position, colour: .white, count: 12, in: self)
            select(nil)
            camp.run(.sequence([SKAction.scale(to: 1.12, duration: 0.12).eased(), SKAction.scale(to: 1, duration: 0.2).eased()]))
            onSelect?(Self.campID)
            return
        }
        // Forgiving touch: the nearest zone within a generous radius.
        let nearest = islands.min { $0.value.position.distance(to: point) < $1.value.position.distance(to: point) }
        guard let nearest, nearest.value.position.distance(to: point) < islandSize * 0.75 else { return }
        AudioManager.shared.play(.tap)
        Haptics.shared.tap()
        Effects.burst(at: nearest.value.position, colour: .white, count: 12, in: self)
        select(nearest.key)
        onSelect?(nearest.key)
    }
}

struct PracticeQuestion {
    var prompt: String
    var answer: String
    /// Tapped from a few choices, as in the maths levels.
    var choices: [String]
    var instruction: String
    var speechKey: String
    var speech: String
}

final class IntroScene: CoverScene {
    /// The practice round: three easy times-tables questions, each already recorded.
    /// Each right answer winds the Times Machine up a little more.
    static let practice: [PracticeQuestion] = [
        PracticeQuestion(prompt: "3 × 2 = ?", answer: "6", choices: ["5", "6", "8"],
                         instruction: "Tap the right answer to wind up the Times Machine!",
                         speechKey: "mul_2x3", speech: "3 times 2."),
        PracticeQuestion(prompt: "2 × 10 = ?", answer: "20", choices: ["12", "20", "22"],
                         instruction: "Another turn! Tap the right answer.",
                         speechKey: "mul_10x2", speech: "2 times 10."),
        PracticeQuestion(prompt: "5 × 2 = ?", answer: "10", choices: ["7", "10", "12"],
                         instruction: "One last turn! Tap the right answer.",
                         speechKey: "mul_2x5", speech: "5 times 2."),
    ]

    /// Called as each practice question appears, with its index.
    var onQuestion: ((Int) -> Void)?
    var onTutorialDone: (() -> Void)?
    private let otter = CharacterNode(kind: .otter, size: 120)
    private let mosey = CharacterNode(kind: .mosey, size: 200)
    private let machine = SKSpriteNode(texture: Art.texture("machine_whole"))
    private let flash = SKSpriteNode(color: .white, size: CGSize(width: 10, height: 10))
    private var bubble: SKNode?
    private var question = 0
    private var started = false
    private var tutorialActive = false
    private var travelled = false
    private var crashed = false

    init() { super.init(background: "bg_title") }

    override func build() {
        addChild(otter)
        addChild(mosey)
        mosey.facingLeft = true
        otter.startIdle()
        mosey.startIdle()
        machine.zPosition = 5
        addChild(machine)
        flash.alpha = 0
        flash.zPosition = 90
        addChild(flash)
        if !Effects.reducedMotion {
            machine.run(.repeatForever(SKAction.sequence([.moveBy(x: 0, y: 4, duration: 1.3), .moveBy(x: 0, y: -4, duration: 1.3)]).eased()), withKey: "bob")
        }
    }

    override func layout() {
        otter.resize(min(play.height * 0.44, 260))
        mosey.resize(min(play.height * 0.6, 360))
        otter.position = CGPoint(x: play.minX + play.width * 0.14, y: play.minY + play.height * 0.05)
        mosey.position = CGPoint(x: play.maxX - play.width * 0.17, y: play.minY + play.height * 0.3)
        let texture = machine.texture?.size() ?? CGSize(width: 1, height: 1)
        let height = min(play.height * 0.42, 260)
        machine.size = CGSize(width: height * texture.width / texture.height, height: height)
        if machine.action(forKey: "crash") == nil { machine.position = machineHome }
        flash.size = size
        flash.position = CGPoint(x: size.width / 2, y: size.height / 2)
        bubble?.position = bubblePosition
    }

    private var machineHome: CGPoint { CGPoint(x: play.minX + play.width * 0.58, y: play.minY + play.height * 0.26) }
    private var bubblePosition: CGPoint { CGPoint(x: play.minX + play.width * 0.36, y: play.minY + play.height * 0.56) }

    /// "Ta-da!": the machine shows off.
    func showOff() {
        AudioManager.shared.play(.unlock, volume: 0.6)
        machine.run(.pop(to: 1.12))
        Effects.burst(at: machine.position, colour: UIColor(hex: "#FFC83D"), count: 20, in: self)
        otter.celebrate()
    }

    /// The first practice question.
    func startTutorial() {
        guard !started else { return }
        started = true
        present(0)
    }

    /// A question bubble for practice question `index`.
    private func present(_ index: Int) {
        question = index
        let item = Self.practice[index]
        let ink = UIColor(hex: "#0E3B43")
        let node = SKNode()
        let diameter = min(play.height * 0.42, 210)
        node.addChild(SKSpriteNode(texture: Art.bubble(), size: CGSize(width: diameter * 1.25, height: diameter)))
        let letterWidth = diameter * 0.24
        let plateSize = CGSize(width: diameter * 0.95, height: letterWidth * 1.75)
        node.addChild(plate(size: plateSize, y: 0))
        let label = GameLabel(item.prompt, size: letterWidth * 0.95, colour: ink, tracking: 0)
        label.fitWidth = plateSize.width - 20
        label.zPosition = 2
        node.addChild(label)
        node.position = bubblePosition
        node.zPosition = 15
        node.setScale(0)
        addChild(node)
        node.run(.pop())
        bubble = node
        AudioManager.shared.play(.whoosh, volume: 0.5)
        tutorialActive = true
        onQuestion?(index)
    }

    private func plate(size: CGSize, y: CGFloat) -> SKSpriteNode {
        let plate = SKSpriteNode(texture: Art.panel(size: size, fill: UIColor(hex: "#FFFDF3"), radius: 16, lineWidth: 3), size: size)
        plate.zPosition = 1
        plate.position.y = y
        return plate
    }

    /// Answers the current practice question. Returns whether `choice` was right.
    func choose(_ choice: String) -> Bool {
        guard tutorialActive else { return false }
        if choice == Self.practice[question].answer {
            complete()
            return true
        }
        bubble?.run(.wobble())
        AudioManager.shared.play(.wrong, volume: 0.5)
        return false
    }

    private func complete() {
        tutorialActive = false
        guard let node = bubble else { return }
        AudioManager.shared.play(.correct)
        AudioManager.shared.play(.pop)
        Haptics.shared.success()
        Effects.rainbowBurst(at: node.position, in: self, count: 50)
        node.run(.sequence([.wait(forDuration: 0.3), .group([.scale(to: 1.4, duration: 0.16), .fadeOut(withDuration: 0.16)]), .removeFromParent()]))
        bubble = nil
        otter.celebrate()
        mosey.celebrate()
        windUp(question + 1)
        let last = question == Self.practice.count - 1
        run(.sequence([.wait(forDuration: last ? 1.6 : 1.4), .run { [weak self] in
            guard let self else { return }
            if last { self.onTutorialDone?() } else { self.present(self.question + 1) }
        }]))
    }

    /// Each right answer winds the machine up a notch: a ratchet, a wobble and more sparkle.
    private func windUp(_ turns: Int) {
        AudioManager.shared.play(.ratchet, volume: 0.8)
        let colour = [UIColor(hex: "#FFE066"), UIColor(hex: "#FFC83D"), UIColor(hex: "#FF9F1C")][min(turns - 1, 2)]
        Effects.burst(at: machine.position, colour: colour, count: 12 * turns, in: self)
        guard !Effects.reducedMotion else { return }
        machine.run(.sequence([.rotate(toAngle: 0.05, duration: 0.08), .rotate(toAngle: -0.05, duration: 0.12), .rotate(toAngle: 0, duration: 0.08)]))
    }

    /// Whoosh: a flash of light, and they are 66 million years in the past.
    func timeTravel() {
        guard !travelled else { return }
        travelled = true
        bubble?.removeFromParent()
        AudioManager.shared.play(.machineWhirr)
        AudioManager.shared.playMusic("music_hollow")
        Haptics.shared.crescendo()
        machine.removeAction(forKey: "bob")
        if !Effects.reducedMotion {
            machine.run(.repeat(.sequence([.moveBy(x: 6, y: 0, duration: 0.04), .moveBy(x: -12, y: 0, duration: 0.08), .moveBy(x: 6, y: 0, duration: 0.04)]), count: 8))
        }
        Effects.rainbowBurst(at: machine.position, in: self, count: 120)
        flash.run(.sequence([
            .wait(forDuration: 0.6),
            .fadeAlpha(to: 1, duration: Effects.reducedMotion ? 0.2 : 0.45),
            .run { [weak self] in
                guard let self else { return }
                // While the screen is white: a new time, and everyone is up in the air.
                self.changeBackground(to: "bg_hollow")
                self.machine.isHidden = true
                self.otter.isHidden = true
                self.mosey.isHidden = true
            },
            .wait(forDuration: 0.2),
            .fadeAlpha(to: 0, duration: 0.6),
        ]))
    }

    /// Clang: the machine crash-lands and its six parts fly off in every direction.
    func crash() {
        guard !crashed else { return }
        crashed = true
        if !travelled {
            travelled = true
            changeBackground(to: "bg_hollow")
        }
        machine.texture = Art.texture("machine_wrecked")
        layout()
        machine.isHidden = false
        machine.removeAllActions()
        let landing = machineHome
        machine.position = CGPoint(x: landing.x, y: size.height + machine.size.height)
        machine.zRotation = -0.3
        let fall = SKAction.move(to: landing, duration: Effects.reducedMotion ? 0.2 : 0.5)
        fall.timingMode = .easeIn
        machine.run(.sequence([.group([fall, .rotate(toAngle: 0.08, duration: 0.5)]), .run { [weak self] in self?.landed() }]), withKey: "crash")
    }

    private func landed() {
        AudioManager.shared.play(.machineCrash)
        Haptics.shared.crescendo()
        let centre = machine.position
        Effects.burst(at: CGPoint(x: centre.x, y: centre.y - machine.size.height * 0.4), colour: UIColor(hex: "#C9B79C"), count: 40, in: self)
        if !Effects.reducedMotion {
            cover.run(.sequence([.moveBy(x: 0, y: -10, duration: 0.05), .moveBy(x: 0, y: 14, duration: 0.08), .moveBy(x: 0, y: -4, duration: 0.06)]))
        }
        for (index, island) in Catalog.shared.islands.enumerated() {
            let texture = Art.texture("part_\(island.part)")
            let side = min(play.height * 0.16, 90)
            let part = SKSpriteNode(texture: texture, size: CGSize(width: side * texture.size().width / max(texture.size().height, 1), height: side))
            part.position = centre
            part.zPosition = 20
            addChild(part)
            let angle = CGFloat(index) / 6 * .pi * 2 + 0.4
            let far = CGPoint(x: centre.x + cos(angle) * size.width, y: centre.y + abs(sin(angle)) * size.height * 0.9 + 40)
            part.run(.sequence([
                .wait(forDuration: 0.05 * Double(index)),
                .group([SKAction.move(to: far, duration: 1.2), .rotate(byAngle: 8, duration: 1.2)]),
                .removeFromParent(),
            ]))
        }
        // Otter and Mosey tumble out beside the wreck, dazed but fine.
        for hero in [otter, mosey] {
            hero.isHidden = false
            hero.alpha = 0
            hero.run(.fadeIn(withDuration: 0.3))
            hero.react(.oops, hold: 2.5)
        }
    }

    /// Far away, but getting closer: ROAR.
    func roar() {
        AudioManager.shared.play(.roarRex, volume: 0.8)
        otter.react(.scared, hold: 2.5)
        mosey.react(.scared, hold: 2.5)
        guard !Effects.reducedMotion else { return }
        cover.run(.repeat(.sequence([.moveBy(x: 5, y: 0, duration: 0.05), .moveBy(x: -10, y: 0, duration: 0.1), .moveBy(x: 5, y: 0, duration: 0.05)]), count: 4))
    }
}
