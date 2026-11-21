import SpriteKit
import SwiftUI

struct CampBackdrop: View {
    let calmerMotion: Bool
    let ground: CampGround
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.scenePhase) private var phase

    var body: some View {
        if !calmerMotion && !reduceMotion {
            CampPainting(paused: phase != .active, ground: ground)
        } else {
            GeometryReader { geometry in
                Image("bg_camp").resizable().scaledToFill()
                    .frame(width: geometry.size.width, height: geometry.size.height)
                    .clipped()
            }
        }
    }
}

// SpriteKit owns the animation clock so scenery updates don't redraw the island controls.
private struct CampPainting: UIViewRepresentable {
    let paused: Bool
    let ground: CampGround

    func makeUIView(context: Context) -> SKView {
        let view = SKView()
        view.preferredFramesPerSecond = 30
        let scene = WildlifePaintingScene(size: CGSize(width: 900, height: 600))
        scene.scaleMode = .aspectFill
        scene.anchorPoint = CGPoint(x: 0.5, y: 0.5)
        let painting = SKSpriteNode(imageNamed: "bg_camp")
        painting.size = scene.size
        painting.shader = SKShader(fileNamed: "CampWater.fsh")
        scene.addChild(painting)
        let wildlife = IslandWildlife()
        wildlife.atCamp = true
        wildlife.campGround = ground
        wildlife.zPosition = 1
        painting.addChild(wildlife)
        wildlife.fit(to: painting)
        scene.wildlife = wildlife
        wildlife.start()
        view.presentScene(scene)
        return view
    }

    func updateUIView(_ view: SKView, context: Context) {
        (view.scene as? WildlifePaintingScene)?.wildlife?.campGround = ground
        view.isPaused = paused
    }

    static func dismantleUIView(_ view: SKView, coordinator: ()) {
        view.isPaused = true
        view.presentScene(nil)
    }
}
