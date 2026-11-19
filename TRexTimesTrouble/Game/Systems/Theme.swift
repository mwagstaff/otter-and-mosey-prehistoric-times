import TimesTroubleCore
import SpriteKit
import UIKit

/// The look of one zone: which art to use and how its ambient effects behave.
struct IslandTheme {
    enum Ambient { case fireflies, bubbles, embers, sparkles, sprinkles, stars }

    let id: String
    let tint: UIColor
    let ambient: Ambient
    /// Little things that pop up as the zone comes to life.
    let blooms: [String]
    /// Art for the egg-hatching mode: what is locked, and who comes out.
    let container: String
    /// Who can come out. Each hatching picks one at random, in a random colour.
    let friends: [String]
    let music: String
    /// True when the heroes swim through this zone's travel levels.
    let underwater: Bool
    let background: String
    let foreground: String
    /// The boss in their normal, chasing, happy and (where there is one) sleeping poses.
    let guardian: String
    let guardianChase: String
    let guardianHappy: String
    let guardianSleep: String?
    /// The boss's roar, played as a chase starts.
    let roar: SFX

    var islandArt: String { "island_\(id)" }

    /// A boss picture facing left (towards the heroes) or right (chasing them). Every boss is
    /// painted facing left, head first, so facing right is a mirror image.
    func boss(_ name: String, facingLeft: Bool) -> SKTexture {
        facingLeft ? Art.texture(name) : Art.mirroredTexture(name)
    }
    var collectible: String {
        switch id { case "swamp": "🪷"; case "peaks": "🪶"; case "ridge": "💎"; default: "🥚" }
    }
    var gateDecoration: String {
        switch id { case "swamp": "🪷"; case "peaks": "🪶"; case "ridge": "🔥"; default: "🌿" }
    }
    var collectInstruction: String { "Tap them to collect them, or steer through them!" }
    var snack: String { "🍓" }
    var snackName: String { "berries" }

    /// Hatchling Hollow and Three-Horn Meadow have their own art. The zones still to come borrow
    /// art until they are built; while locked they are never played.
    static func island(_ id: String) -> IslandTheme {
        let babies = ["reward_pet-pip", "reward_pet-nubbin", "icon_1f996"]
        switch id {
        case "meadow":
            return IslandTheme(id: id, tint: UIColor(hex: "#F2A13C"), ambient: .sparkles, blooms: ["🌼", "🌸", "🌾", "🦋", "🍀"],
                               container: "egg", friends: babies, music: "music_main", underwater: false,
                               background: "bg_meadow", foreground: "fg_hollow", guardian: "boss_trevor", guardianChase: "boss_trevor_chase",
                               guardianHappy: "boss_trevor_happy", guardianSleep: nil, roar: .roarTrevor)
        case "swamp", "peaks", "ridge", "rex":
            let look: (UIColor, Ambient, String, String, Bool) = switch id {
            case "swamp": (UIColor(hex: "#3FA796"), .bubbles, "bay", "music_bay", true)
            case "peaks": (UIColor(hex: "#8FA8FF"), .sparkles, "cloud", "music_cloud", false)
            case "ridge": (UIColor(hex: "#E8643C"), .embers, "dragon", "music_dragon", false)
            default: (UIColor(hex: "#9B5BD6"), .embers, "dragon", "music_dragon", false)
            }
            return IslandTheme(id: id, tint: look.0, ambient: look.1, blooms: ["🌿", "🥚", "🌼", "🦋", "🍃"],
                               container: "egg", friends: babies, music: look.3, underwater: look.4,
                               background: "bg_\(look.2)", foreground: "fg_\(look.2)", guardian: "boss_trevor", guardianChase: "boss_trevor_chase",
                               guardianHappy: "boss_trevor_happy", guardianSleep: nil, roar: id == "rex" ? .roarRex : .roarTrevor)
        default:
            return IslandTheme(id: "hollow", tint: UIColor(hex: "#7BC86C"), ambient: .fireflies, blooms: ["🌿", "🥚", "🌼", "🦋", "🍃"],
                               container: "egg", friends: babies, music: "music_hollow", underwater: false,
                               background: "bg_hollow", foreground: "fg_hollow", guardian: "boss_maia", guardianChase: "boss_maia_chase",
                               guardianHappy: "boss_maia_happy", guardianSleep: "boss_maia_sleep", roar: .roarMaia)
        }
    }

    /// Crash Camp, where the Times Machine is mended in the Fix-It Workshop.
    static let camp = IslandTheme(id: "camp", tint: UIColor(hex: "#E8A13C"), ambient: .embers, blooms: ["🔧", "⚙️", "🔩", "✨", "🔥"],
                                  container: "egg", friends: [], music: "music_main", underwater: false,
                                  background: "bg_camp", foreground: "fg_camp", guardian: "boss_maia", guardianChase: "boss_maia_chase",
                                  guardianHappy: "boss_maia_happy", guardianSleep: nil, roar: .roarMaia)
}

/// Shared type styling for SpriteKit and SwiftUI, including the easy-read option.
enum GameFont {
    static var easyRead = false

    static func ui(_ size: CGFloat, weight: UIFont.Weight = .heavy) -> UIFont {
        if easyRead {
            // Verdana's open letter shapes and wide spacing are a common recommendation for dyslexic readers.
            return UIFont(name: weight >= .bold ? "Verdana-Bold" : "Verdana", size: size * 0.92) ?? .systemFont(ofSize: size, weight: weight)
        }
        let base = UIFont.systemFont(ofSize: size, weight: weight)
        guard let descriptor = base.fontDescriptor.withDesign(.rounded) else { return base }
        return UIFont(descriptor: descriptor, size: size)
    }

    static var kerning: CGFloat { easyRead ? 1.6 : 0.3 }
}

/// A SpriteKit label that uses the game typeface and re-renders when its text changes.
final class GameLabel: SKLabelNode {
    private var pointSize: CGFloat = 24
    private var ink: UIColor = .white
    private var weight: UIFont.Weight = .heavy
    private var tracking: CGFloat?
    /// When set, the label shrinks so its text never spills past this width.
    var fitWidth: CGFloat? { didSet { render() } }

    var string: String = "" { didSet { if string != oldValue { render() } } }
    var colour: UIColor { get { ink } set { ink = newValue; render() } }

    convenience init(_ text: String, size: CGFloat, colour: UIColor = .white, weight: UIFont.Weight = .heavy, tracking: CGFloat? = nil, maxWidth: CGFloat? = nil) {
        self.init()
        pointSize = size
        ink = colour
        self.weight = weight
        self.tracking = tracking
        verticalAlignmentMode = .center
        horizontalAlignmentMode = .center
        if let maxWidth {
            numberOfLines = 0
            preferredMaxLayoutWidth = maxWidth
        }
        string = text
        render()
    }

    private func render() {
        let paragraph = NSMutableParagraphStyle()
        paragraph.alignment = .center
        attributedText = NSAttributedString(string: string, attributes: [
            .font: GameFont.ui(pointSize, weight: weight),
            .foregroundColor: ink,
            .kern: tracking ?? GameFont.kerning,
            .paragraphStyle: paragraph,
        ])
        if let fitWidth {
            setScale(1)
            let width = frame.width
            setScale(width > fitWidth && width > 0 ? fitWidth / width : 1)
        }
    }
}
