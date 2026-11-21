import SpriteKit
import UIKit

/// Wildlife uses the same 900 × 600 painting coordinates as the water shader.
final class IslandWildlife: SKNode {
    var atCamp = false
    var campGround: CampGround?

    private enum Swimmer: String, CaseIterable {
        case bottlenose = "lagoon_bottlenose"
        case spottedDolphin = "lagoon_spotted_dolphin"
        case snapper = "lagoon_snapper"
        case flyingFish = "lagoon_flying_fish"

        case mosasaur

        var isDolphin: Bool { self == .bottlenose || self == .spottedDolphin }
    }

    private enum Bird: String, CaseIterable {
        case macaw = "bird_macaw"
        case tropicbird = "bird_tropicbird"
        case beeEater = "bird_bee_eater"

        case pterosaur

        // Canvas width includes padding for the raised and lowered wing poses.
        var flight: (width: CGFloat, beat: TimeInterval, glide: TimeInterval, flock: ClosedRange<Int>) {
            switch self {
            case .pterosaur: (49, 0.19, 2.4, 1...3)
            case .macaw: (44, 0.16, 0.8, 1...4)
            case .tropicbird: (40, 0.13, 2.1, 1...3)
            case .beeEater: (33, 0.09, 0.65, 2...6)
            }
        }

        func frames() -> [SKTexture] {
            IslandWildlife.poses(rawValue)
        }
    }

    private static func poses(_ asset: String) -> [SKTexture] {
        let strip = SKTexture(imageNamed: asset)
        return (0..<3).map { SKTexture(rect: CGRect(x: CGFloat($0) / 3, y: 0, width: 1.0 / 3, height: 1), in: strip) }
    }

    private func campLife() {
        let sparks = SKEmitterNode()
        sparks.position = CGPoint(x: 204, y: 186)
        sparks.particleTexture = Art.glow
        sparks.particleColor = .orange
        sparks.particleColorBlendFactor = 1
        sparks.particleSize = CGSize(width: 2.4, height: 2.4)
        sparks.particleBirthRate = 3
        sparks.particleLifetime = 1.7
        sparks.particleLifetimeRange = 0.9
        sparks.particlePositionRange = CGVector(dx: 12, dy: 3)
        sparks.emissionAngle = 1.38
        sparks.emissionAngleRange = 0.65
        sparks.particleSpeed = 23
        sparks.particleSpeedRange = 12
        sparks.particleAlphaSpeed = -0.5
        sparks.particleBlendMode = .add
        addChild(sparks)
        run(.sequence([.wait(forDuration: 8, withRange: 5), .repeatForever(.sequence([
            .run { [weak self] in self?.runAcrossCamp() }, .wait(forDuration: 31, withRange: 13)
        ]))]))
    }

    private enum Runner: String, CaseIterable {
        case hadrosaur, triceratops, velociraptor, ankylosaur

        var gait: (width: CGFloat, crossing: Double, step: Double, lift: CGFloat, rock: CGFloat) {
            switch self {
            case .hadrosaur: (54, 7, 0.105, 2.6, 0.025)
            case .triceratops: (62, 10, 0.16, 1.4, 0.035)
            case .velociraptor: (43, 5, 0.085, 4.2, 0.045)
            case .ankylosaur: (66, 13, 0.24, 0.8, 0.065)
            }
        }
    }
    private var runners = [Runner]()
    private var lastRunner: Runner?

    private func runAcrossCamp() {
        if runners.isEmpty {
            runners = Runner.allCases.shuffled()
            if runners.last == lastRunner { runners.swapAt(0, runners.count - 1) }
        }
        let species = runners.removeLast()
        lastRunner = species
        let gait = species.gait
        let frames = Self.poses(species.rawValue)
        let runner = SKSpriteNode(texture: frames[0])
        runner.name = "wild-runner"
        runner.setScale(gait.width / runner.size.width)
        let east = Bool.random()
        if !east { runner.xScale *= -1 }
        let height = runner.frame.height
        guard let ground = campGround else { return }
        let area = ground.walkingArea(width: gait.width, height: height)
        let startX: CGFloat = east ? 120 : 820, endX: CGFloat = east ? 820 : 120
        guard let start = area.nearest(CGPoint(x: startX, y: .random(in: 445...540))),
              let end = area.nearest(CGPoint(x: endX, y: .random(in: 445...540))),
              let path = area.route(from: start, to: end), path.length > gait.width else { return }
        let speed = 780 / gait.crossing
        let duration = path.length / speed
        runner.position = CGPoint(x: start.x, y: 600 - start.y)
        runner.alpha = 0
        addChild(runner)
        runner.run(.repeatForever(.animate(with: frames, timePerFrame: gait.step)))
        runner.run(.sequence([.customAction(withDuration: duration) { [weak self] node, elapsed in
            let phase = elapsed * .pi / (gait.step * 1.5)
            let sample = path.sample(speed * elapsed)
            if self?.campGround != ground,
               self?.campGround?.walkingArea(width: gait.width, height: height).contains(sample.point) != true {
                node.removeFromParent()
                return
            }
            node.xScale = abs(node.xScale) * (sample.west ? -1 : 1)
            node.position = CGPoint(x: sample.point.x, y: 600 - sample.point.y + gait.lift * 0.35 * abs(sin(phase)))
            node.alpha = min(1, max(0, min(elapsed, duration - elapsed) / 0.27))
            node.zRotation = gait.rock * sin(phase)
        }, .removeFromParent()]))
    }

    private var remainingBirds = [Bird]()
    private var lastBird: Bird?
    private var remainingSwimmers = [Swimmer]()
    private var lastSwimmer: Swimmer?


    /// Hit-test in painting coordinates, including the smaller, cropped camp swimmers.
    func greet(at point: CGPoint) -> Bool {
        var closest: SKNode?
        var distance = CGFloat.infinity
        enumerateChildNodes(withName: "//wild-*") { animal, _ in
            guard let parent = animal.parent else { return }
            if parent is SKCropNode && (animal.position.y < -4 || parent.convert(point, from: self).y < -5) { return }
            let centre = self.convert(CGPoint.zero, from: animal)
            let delta = hypot(point.x - centre.x, point.y - centre.y)
            if delta < 31 && delta < distance { closest = animal; distance = delta }
        }
        guard let animal = closest else { return false }
        if animal.userData?["greeted"] as? Bool == true { return true }
        animal.userData = ["greeted": true]
        let caption: String
        switch animal.name {
        case "wild-runner":
            caption = "Raar!"
            AudioManager.shared.play(.roarMaia, volume: 0.6)
            animal.isPaused = true
            run(.sequence([.wait(forDuration: 1), .run { [weak animal] in animal?.isPaused = false }]))
        case "wild-bird":
            caption = "Squawk!"
            AudioManager.shared.play(.chirp, volume: 0.75)
        default:
            caption = "Glub glub!"
            AudioManager.shared.play(.glub, volume: 0.85)
        }
        let label = SKLabelNode(fontNamed: "AvenirNext-Bold")
        label.text = caption
        label.fontSize = 17
        label.fontColor = .white
        let shadow = SKLabelNode(fontNamed: label.fontName)
        shadow.text = caption
        shadow.fontSize = label.fontSize
        shadow.fontColor = .black
        shadow.position = CGPoint(x: 0, y: -1.5)
        shadow.zPosition = -1
        label.addChild(shadow)
        let centre = convert(CGPoint.zero, from: animal)
        label.position = CGPoint(x: min(845, max(55, centre.x)), y: centre.y + 18)
        label.zPosition = 8
        addChild(label)
        label.run(.sequence([.moveBy(x: 0, y: 6, duration: 0.3), .wait(forDuration: 0.45),
                             .fadeOut(withDuration: 0.25), .removeFromParent()]))
        return true
    }

    func fit(to painting: SKSpriteNode) {
        setScale(painting.size.width / 900)
        position = CGPoint(x: -painting.size.width / 2, y: -painting.size.height / 2)
    }

    func start() {
        if atCamp { campLife() }
        run(.sequence([
            .wait(forDuration: 4, withRange: 5),
            .repeatForever(.sequence([
                .run { [weak self] in self?.birds() },
                .wait(forDuration: 25, withRange: 14)
            ]))
        ]))
        run(.sequence([
            .wait(forDuration: 10, withRange: 8),
            .repeatForever(.sequence([
                .run { [weak self] in self?.breach() },
                .wait(forDuration: 20, withRange: 13)
            ]))
        ]))
    }

    private func birds() {
        let toRight = Bool.random()
        let speed: CGFloat = toRight ? 1 : -1
        let altitude = CGFloat.random(in: 420...485)
        if remainingBirds.isEmpty {
            remainingBirds = Bird.allCases.shuffled()
            if remainingBirds.last == lastBird {
                remainingBirds.swapAt(0, remainingBirds.count - 1)
            }
        }
        let species = remainingBirds.removeLast()
        lastBird = species
        let flight = species.flight
        let frames = species.frames()
        let count = Int.random(in: flight.flock)
        let duration = Double.random(in: 7.8...12.2)
        let spacing = CGFloat.random(in: 25...39)
        let bank = CGFloat.random(in: -26...26)
        let rise = CGFloat.random(in: 4...21)
        let phase = CGFloat.random(in: 0...(2 * .pi))
        let echelon = CGFloat.random(in: -5...5)
        for i in 0..<count {
            let bird = SKSpriteNode(texture: frames[1])
            let aspect = bird.size.height / bird.size.width
            bird.size = CGSize(width: flight.width, height: flight.width * aspect)
            let flap = SKAction.animate(with: [frames[0], frames[1], frames[2], frames[1]],
                                        timePerFrame: flight.beat * .random(in: 0.87...1.12))
            bird.run(.sequence([.wait(forDuration: .random(in: 0...1)),
                .repeatForever(.sequence([.repeat(flap, count: .random(in: 1...3)),
                                          .wait(forDuration: flight.glide, withRange: flight.glide * 0.7)]))
            ]))
            let scale = CGFloat.random(in: 0.85...1.15)
            bird.xScale = speed * scale
            bird.yScale = scale
            let leadX: CGFloat = toRight ? -18 : 918
            let startX = leadX - speed * (CGFloat(i) * spacing + .random(in: 0...9))
            let y = altitude + CGFloat(i) * echelon + .random(in: -6...6)
            let distance = 950 + CGFloat(count) * spacing
            bird.position = CGPoint(x: startX, y: y)
            bird.name = "wild-bird"
            addChild(bird)
            bird.run(.sequence([.customAction(withDuration: duration) { node, elapsed in
                let u = elapsed / duration
                node.position = CGPoint(x: startX + speed * distance * u,
                                        y: y + bank * u + rise * sin(u * 6 + phase + CGFloat(i) * 0.28))
            }, .removeFromParent()]))
        }
    }

    private func breach() {
        if remainingSwimmers.isEmpty {
            remainingSwimmers = Swimmer.allCases.filter { !atCamp || !$0.isDolphin }.shuffled()
            if remainingSwimmers.last == lastSwimmer {
                remainingSwimmers.swapAt(0, remainingSwimmers.count - 1)
            }
        }
        let swimmer = remainingSwimmers.removeLast()
        lastSwimmer = swimmer
        let large = swimmer.isDolphin || swimmer == .mosasaur
        let direction: CGFloat = Bool.random() ? 1 : -1
        let range = CGFloat.random(in: 32...57)
        let water = SKCropNode()
        water.position = atCamp ? CGPoint(x: .random(in: 416...545), y: .random(in: 245...273)) : CGPoint(x: CGFloat.random(in: 248...622), y: CGFloat.random(in: 191...233))
        let mask = SKSpriteNode(color: .white, size: CGSize(width: 180, height: 110))
        mask.position.y = 55
        if atCamp { water.setScale(0.65) }
        water.maskNode = mask
        addChild(water)
        let animal: SKSpriteNode
        if swimmer == .mosasaur {
            let frames = Self.poses("mosasaur")
            animal = SKSpriteNode(texture: frames[0])
            animal.run(.repeatForever(.animate(with: frames, timePerFrame: 0.18)))
        } else {
            animal = SKSpriteNode(imageNamed: swimmer.rawValue)
        }
        let width = large ? CGFloat.random(in: 38...46) : CGFloat.random(in: 25...32)
        animal.setScale(width / animal.size.width)
        animal.xScale *= swimmer == .mosasaur ? -direction : direction
        let duration = large ? Double.random(in: 1.3...1.65) : Double.random(in: 0.95...1.24)
        let height = large ? CGFloat.random(in: 46...62) : CGFloat.random(in: 34...45)
        animal.name = "wild-swimmer"
        water.addChild(animal)
        animal.position = CGPoint(x: direction * range, y: -24)
        animal.run(.sequence([.customAction(withDuration: duration) { node, elapsed in
            let u = elapsed / duration
            node.position = CGPoint(x: direction * range * (1 - 2 * u), y: -24 + height * 4 * u * (1 - u))
            node.zRotation = direction * 0.8 * (2 * u - 1)
        }, .removeFromParent()]))
        water.run(.sequence([.wait(forDuration: duration * 0.87), .run { [weak self, weak water] in
            guard let self, let water else { return }
            splash(at: CGPoint(x: water.position.x - direction * range * 0.74 * water.xScale, y: water.position.y), large: large)
        }, .wait(forDuration: duration * 0.15), .removeFromParent()]))
    }

    private func splash(at point: CGPoint, large: Bool) {
        let ring = SKShapeNode(ellipseOf: CGSize(width: 12, height: 2.8))
        ring.position = point
        ring.strokeColor = .white
        ring.lineWidth = 0.7
        ring.alpha = 0.78
        addChild(ring)
        ring.run(.sequence([.group([.scale(to: large ? 3 : 2.2, duration: 0.8),
                                    .fadeOut(withDuration: 0.8)]), .removeFromParent()]))
        for _ in 0..<(large ? 10 : 6) {
            let drop = SKShapeNode(ellipseOf: CGSize(width: 1.5, height: 2.5))
            drop.fillColor = .white
            drop.lineWidth = 0
            drop.position = point
            addChild(drop)
            let dx = CGFloat.random(in: -17...17)
            let rise = CGFloat.random(in: 4...13)
            drop.run(.sequence([.customAction(withDuration: 0.48) { node, elapsed in
                let u = elapsed / 0.48
                node.position = CGPoint(x: point.x + dx * u, y: point.y + 4 * rise * u * (1 - u))
                node.alpha = 0.85 * (1 - u)
            }, .removeFromParent()]))
        }
    }
}

/// For a home island whose controls sit above the painting.
final class WildlifePaintingScene: SKScene {
    weak var wildlife: IslandWildlife?
    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
        guard let wildlife, let touch = touches.first else { return }
        _ = wildlife.greet(at: touch.location(in: wildlife))
    }
}
