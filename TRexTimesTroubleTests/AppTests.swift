import Foundation
import TimesTroubleCore
import SpriteKit
import Testing
@testable import TRexTimesTrouble

/// Checks that need the app bundle: bundled art and audio, and the app-level save flow.
/// Run one at a time: several tests use the shared narrator, and would cut each other off.
@MainActor
@Suite(.serialized) struct AppTests {
    @Test func everyArtAssetTheGameNamesIsBundled() {
        var names = ["logo", "bg_title", "bg_map", "bg_camp", "fg_camp", "bg_ending", "duo_ride", "pearl", "ring", "cliff",
                     "machine_whole", "machine_wrecked", "stone", "bolt", "bone", "otter_fix", "otter_scared", "mosey_dash", "mosey_scared"]
        for kind in ["otter", "mosey"] {
            for pose in ["idle", "blink", "cheer", "think", "oops"] { names.append("\(kind)_\(pose)") }
        }
        names += ["otter_run", "mosey_swim", "otter_talk", "mosey_talk"]
        names += (1...12).map { "fossil_\($0)" }
        for island in Catalog.shared.islands {
            let theme = IslandTheme.island(island.id)
            names += [theme.background, theme.foreground, theme.guardian, theme.guardianChase, theme.guardianHappy, theme.islandArt,
                      theme.container, "part_\(island.part)"] + theme.friends + [theme.guardianSleep].compactMap { $0 }
        }
        for name in names { #expect(Art.hasAsset(name), "missing art: \(name)") }
    }

    @Test func everyZoneHasAThemeAndBossesFaceTheRightWay() {
        let themes = Catalog.shared.islands.map { IslandTheme.island($0.id) }
        #expect(themes.map(\.id) == ["hollow", "meadow", "swamp", "peaks", "ridge", "rex"])
        #expect(themes[0].guardianSleep == "boss_maia_sleep", "Mama Maia sleeps on the Cog in Tiptoe Past")
        for theme in themes {
            #expect(!theme.snackName.isEmpty && !theme.snack.isEmpty && !theme.collectible.isEmpty)
            #expect(theme.collectInstruction.contains("Tap"))
        }
        // Every boss is painted facing left, towards the heroes in Big Escape; Dino Dash mirrors them.
        #expect(themes[0].boss("boss_maia", facingLeft: true) === Art.texture("boss_maia"))
        #expect(themes[0].boss("boss_maia", facingLeft: false) !== Art.texture("boss_maia"))
        #expect(themes[1].boss("boss_trevor", facingLeft: true) === Art.texture("boss_trevor"))
        #expect(Art.fishBiscuits.size() == CGSize(width: 160, height: 200))
    }

    @Test func everySoundEffectAndMusicTrackIsBundled() {
        for effect in SFX.allCases {
            #expect(Bundle.main.url(forResource: effect.rawValue, withExtension: "m4a") != nil, "missing sound: \(effect.rawValue)")
        }
        for track in ["music_main", "music_hollow", "music_chase", "music_title", "music_bay", "music_dragon", "music_cloud"] {
            #expect(Bundle.main.url(forResource: track, withExtension: "m4a") != nil, "missing music: \(track)")
        }
    }

    @Test func everyNarrationLineHasARecording() {
        let missing = Narration.clips.keys.filter { Narrator.clipURL($0) == nil }.sorted()
        #expect(missing.isEmpty, "\(missing.count) narrator clips missing, e.g. \(missing.prefix(5))")
        #expect(Narrator.shared.canSay(key: "mul_8x7", fallback: ""))
        Narrator.shared.deviceVoice = false
        #expect(!Narrator.shared.canSay(key: nil, fallback: "anything"), "no recording and no device voice means silence")
    }

    @Test func everyCharacterLineHasARecording() {
        let missing = Catalog.voicedLines.filter { Narrator.clipURL($0.key) == nil }.map(\.value.text).sorted()
        #expect(Catalog.voicedLines.count == 53, "the opening, the workshop, Hatchling Hollow and the grown-up lines")
        #expect(missing.isEmpty, "\(missing.count) character lines missing a recording, e.g. \(missing.prefix(3))")
    }

    @Test func speakingALineDrivesTheSpeechStage() async throws {
        let stage = SpeechStage.shared
        let voicedLine = Catalog.shared.intro.first { $0.speaker == .otter }!
        #expect(Narrator.clipURL(voicedLine.audioKey ?? "") != nil, "the opening Otter line has a recording")

        // A recorded line: the speaker is set and the mouth moves with the clip.
        Narrator.shared.volume = 0.9
        Narrator.shared.speakLine(voicedLine, voiced: true)
        #expect(stage.speaker == .otter)
        var peak = 0.0
        var opened = false
        for _ in 0..<40 {
            try await Task.sleep(for: .milliseconds(50))
            peak = max(peak, stage.level)
            opened = opened || stage.mouthOpen
        }
        #expect(peak > 0.3 && opened, "level peaked at \(peak)")

        // A line with no recording: the made-up rhythm still marks the speaker, then ends.
        let silent = DialogueLine(speaker: .guardian, text: "Harrumph!")
        Narrator.shared.speakLine(silent, voiced: true)
        #expect(stage.speaker == .guardian)
        opened = false
        for _ in 0..<12 {
            try await Task.sleep(for: .milliseconds(50))
            opened = opened || stage.mouthOpen
        }
        #expect(opened)
        try await Task.sleep(for: .milliseconds(700))
        #expect(stage.speaker == nil && !stage.mouthOpen, "the cue clears when the line is over")

        // Story lines have no speaker to mark.
        Narrator.shared.speakLine(DialogueLine(speaker: .narrator, text: "Once upon a time"), voiced: true)
        #expect(stage.speaker == nil)
        Narrator.shared.stop()
    }

    @Test func progressSurvivesARelaunch() {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent("app-test-\(UUID().uuidString)")
        let store = SaveStore(directory: directory)
        let first = AppModel(store: store)
        first.createProfile(nickname: "  Pip the Very Long Name ", avatar: "🐬")
        #expect(first.profile?.nickname.count == 12, "nicknames are trimmed and capped")
        first.finishIntro()
        let level = Catalog.shared.level("hollow-1")!
        let result = LevelResult(stars: 3, accuracy: 1, score: 600, bestCombo: 6, correctFirstTry: 6, total: 6)
        let summary = first.complete(levelID: level.id, result: result, learner: LearnerModel(), friendshipUses: 0)
        #expect(summary.reward?.id == "pet-pip")
        first.persistNow()

        let second = AppModel(store: store)
        #expect(second.profile?.stars(for: "hollow-1") == 3)
        #expect(second.profile?.seenIntro == true)
        #expect(second.restoration(of: Catalog.shared.island("hollow")!) == 0.2)
        second.continueGame()
        #expect(second.route == .island("hollow"))
    }

    @Test func restartAdventureCanKeepRewards() throws {
        for keep in [true, false] {
            let directory = FileManager.default.temporaryDirectory.appendingPathComponent("reset-test-\(UUID().uuidString)")
            defer { try? FileManager.default.removeItem(at: directory) }
            let store = SaveStore(directory: directory)
            let model = AppModel(store: store)
            model.createProfile(nickname: "Pip", avatar: "🦦")
            let id = try #require(model.profile?.id)
            model.finishIntro()
            _ = model.complete(levelID: "hollow-1", result: LevelResult(stars: 3, accuracy: 1, score: 600, bestCombo: 6, correctFirstTry: 6, total: 6), learner: LearnerModel(), friendshipUses: 1)
            model.updateProfile(id) {
                $0.achievements = $0.achievements.mapValues { Date(timeIntervalSince1970: floor($0.timeIntervalSince1970)) }
                $0.crystals = ["hollow"]
                $0.parent.sessionMinutes = 15
                $0.playSeconds = 120
                $0.grownUpChecked = true
            }
            let old = try #require(model.profile)
            model.createProfile(nickname: "Nova", avatar: "🐬")
            model.updateProfile(try #require(model.profile?.id)) { $0.trophiesReady = true }
            let other = try #require(model.profile)
            model.selectProfile(id)
            model.sessionSeconds = 120
            model.resetProgress(id, keepRewards: keep)
            model.persistNow()
            let loaded = AppModel(store: store)
            let fresh = try #require(loaded.profile)
            #expect(fresh.id == id && fresh.nickname == old.nickname && fresh.parent == old.parent)
            #expect(fresh.levels.isEmpty && fresh.crystals.isEmpty && fresh.lastLevelID == nil)
            #expect(!fresh.seenIntro && !fresh.grownUpChecked && fresh.playSeconds == 0)
            #expect(fresh.bestCombo == 0 && fresh.friendshipPowers == 0)
            #expect(fresh.rewards == (keep ? old.rewards : ["deco-palm"]))
            #expect(fresh.achievements == (keep ? old.achievements : [:]))
            #expect(fresh.pendingTrophies == (keep ? old.pendingTrophies : []))
            #expect(model.sessionSeconds == 0)
            #expect(loaded.save.profiles.first { $0.id == other.id } == other)
            loaded.continueGame()
            #expect(loaded.route == .grownUpCheck)
        }
    }

    @Test func everyModeBuildsASceneAndAsksAQuestion() {
        for id in ["hollow-1", "hollow-2", "hollow-3", "hollow-4", "hollow-5", "swamp-1"] {
            let level = Catalog.shared.level(id)!
            let island = Catalog.shared.island(containing: id)!
            let bridge = GameBridge()
            let options = SceneOptions(settings: AppSettings(), accessory: nil, island: island,
                                       inputProfile: .compactTouch, startRestoration: 0, endRestoration: 0.4)
            let session = ChallengeSession(level: level, learner: LearnerModel(), seed: 3)
            let scene: GameScene
            switch level.mode {
            case .mathsSplash: scene = MathsSplashScene(session: session, bridge: bridge, options: options)
            case .bridgeBuilder: scene = BridgeBuilderScene(session: session, bridge: bridge, options: options)
            case .eggRescue: scene = EggRescueScene(session: session, bridge: bridge, options: options)
            case .guardian: scene = GuardianScene(session: session, bridge: bridge, options: options)
            case .dinoDash: scene = DinoDashScene(session: session, bridge: bridge, options: options)
            case .tiptoe: scene = TiptoeScene(session: session, bridge: bridge, options: options)
            }
            let view = SKView(frame: CGRect(x: 0, y: 0, width: 874, height: 402))
            scene.size = view.frame.size
            view.presentScene(scene)
            scene.begin()
            #expect(scene.isBuilt, "\(id)")
            #expect(bridge.total == level.count)
            if level.mode == .guardian {
                #expect(!bridge.dialogue.isEmpty, "guardians open with a line of dialogue")
            } else {
                #expect(scene.current != nil && !bridge.caption.isEmpty, "\(id) should have asked a question")
            }
        }
    }
}
