import Foundation
@testable import PrehistoricTimesCore
import Testing

@Suite struct QuickFireTests {
    @Test func timesTablesCheckAsksTwentyFiveDifferentFactsFromTwoToTwelve() {
        for seed in 0..<40 as Range<UInt64> {
            var round = QuickFireRound(kind: .mtc, settings: ParentSettings(), learner: LearnerModel(), seed: seed)
            var pairs = Set<[Int]>()
            var hard = 0
            while let question = round.next() {
                #expect(question.kind == .multiply)
                #expect((2...12).contains(question.fact.table) && (2...12).contains(question.fact.multiplier))
                pairs.insert([min(question.fact.table, question.fact.multiplier), max(question.fact.table, question.fact.multiplier)])
                if !QuickFireRound.mtcHardTables.isDisjoint(with: [question.fact.table, question.fact.multiplier]) { hard += 1 }
                round.answer(question.answer, seconds: 2)
            }
            #expect(round.asked == 25 && round.answers.count == 25)
            #expect(pairs.count == 25, "never both 7 × 8 and 8 × 7")
            #expect(hard >= 12, "about half from the 6, 7, 8, 9 and 12 times tables")
            #expect(round.isFinished && round.right == 25)
        }
    }

    @Test func aTimeOutIsAMissAndIsRemembered() {
        var round = QuickFireRound(kind: .mtc, settings: ParentSettings(), learner: LearnerModel(), seed: 3)
        let question = round.next()!
        #expect(round.answer(nil, seconds: QuickFireRound.mtcSeconds) == false)
        #expect(round.learner.factStats(question.fact, .multiply).attempts == 1)
        #expect(round.learner.factState(question.fact, .multiply) == .learning)
    }

    @Test func raptorRaceUsesTheGrownUpsTablesAndAvoidsRecentRepeats() {
        var settings = ParentSettings()
        settings.apply(.year2)
        var round = QuickFireRound(kind: .raptorRace, settings: settings, learner: LearnerModel(), seed: 9)
        var recent: [[Int]] = []
        for _ in 0..<80 {
            let question = round.next()!
            #expect([2, 5, 10].contains(question.fact.table))
            let pair = [min(question.fact.table, question.fact.multiplier), max(question.fact.table, question.fact.multiplier)]
            #expect(!recent.suffix(QuickFireRound.raceGap).contains(pair))
            recent.append(pair)
            round.answer(question.answer + (recent.count.isMultiple(of: 4) ? 1 : 0), seconds: 1.5)
        }
        #expect(round.right == 60)
        #expect(round.total == nil && !round.isFinished)
    }

    @Test func divisionOnlyWhenTheGrownUpAllowsIt() {
        var settings = ParentSettings()
        settings.questionTypes = [.multiplication]
        var round = QuickFireRound(kind: .raptorRace, settings: settings, learner: LearnerModel(), seed: 1)
        for _ in 0..<40 {
            #expect(round.next()!.kind == .multiply)
            round.answer(0, seconds: 1)
        }
    }

    @Test func finishedGamesAreKeptAndWinTrophies() {
        var profile = Profile(nickname: "Pip")
        #expect(!QuickFireRound.raceUnlocked(profile))
        profile.crystals = ["hollow", "meadow", "swamp", "peaks", "ridge"]
        #expect(QuickFireRound.raceUnlocked(profile))
        var race = QuickFireRound(kind: .raptorRace, settings: profile.parent, learner: profile.learner, seed: 2)
        for _ in 0..<21 { race.answer(race.next()!.answer, seconds: 1) }
        QuickFireRound.finish(race, profile: &profile)
        var check = QuickFireRound(kind: .mtc, settings: profile.parent, learner: profile.learner, seed: 2)
        while let question = check.next() { check.answer(question.answer, seconds: 2) }
        QuickFireRound.finish(check, profile: &profile)
        #expect(profile.bestQuickFire(.raptorRace) == 21 && profile.bestQuickFire(.mtc) == 25)
        #expect(profile.learner.answerCount == 46)
        let won = Trophies.awardOutsideLevel(&profile, limit: 40)
        #expect(won.map(\.id).contains("mtc-ready"))
        #expect(won.map(\.id).contains("raptor-20"), "\(won.map(\.id))")
        #expect(!won.map(\.id).contains("raptor-30"))
    }

    @Test func promptsReadLikeTheCheck() {
        #expect(QuickFireQuestion(fact: Fact(table: 8, multiplier: 7), kind: .multiply).prompt == "7 × 8 =")
        #expect(QuickFireQuestion(fact: Fact(table: 8, multiplier: 7), kind: .divide).prompt == "56 ÷ 8 =")
        #expect(QuickFireQuestion(fact: Fact(table: 8, multiplier: 7), kind: .divide).answer == 7)
        #expect(LearningReport.describe("div:8x7") == "56 ÷ 8")
    }

    @Test func year4PresetSwitchesOnCheckPractice() {
        var settings = ParentSettings()
        #expect(!settings.mtcPractice)
        settings.apply(.year4)
        #expect(settings.mtcPractice)
        let decoded = try? JSONDecoder().decode(ParentSettings.self, from: JSONEncoder().encode(settings))
        #expect(decoded?.mtcPractice == true)
    }
}

@Suite struct LearningReportTests {
    @Test func gridAndTablesFollowTheLearner() {
        var learner = LearnerModel()
        let day1 = Date(timeIntervalSince1970: 1_800_000_000)
        let day2 = day1.addingTimeInterval(86_400)
        for date in [day1, day1, day2] {
            learner.record(key: "mul:3x4", skill: .multiplication, correct: true, seconds: 2, usedHint: false, typed: true, on: date)
        }
        learner.record(key: "mul:3x7", skill: .multiplication, correct: false, seconds: 9, usedHint: false, typed: true, on: day1)
        let grid = LearningReport.grid(learner)
        #expect(grid.count == 12 && grid.allSatisfy { $0.count == 12 })
        #expect(grid[2][3] == .fluent, "three quick typed answers over two days")
        #expect(grid[2][6] == .learning)
        #expect(grid[0][0] == .new)
        let three = LearningReport.table(3, learner: learner, multipliers: Array(1...12))
        #expect(three.secure == 1 && three.facts == 12)
        #expect(three.accuracy == 0.75)
        #expect(three.typicalSeconds == 2)
        #expect(LearningReport.table(5, learner: learner, multipliers: Array(1...10)).accuracy == nil)
    }

    @Test func slowestFactsAreTheSlowTypedOnes() {
        var learner = LearnerModel()
        for seconds in [7.0, 8, 9] {
            learner.record(key: "mul:7x8", skill: .multiplication, correct: true, seconds: seconds, usedHint: false, typed: true)
        }
        for seconds in [1.0, 2] {
            learner.record(key: "mul:2x3", skill: .multiplication, correct: true, seconds: seconds, usedHint: false, typed: true)
        }
        let slow = LearningReport.slowest(learner)
        #expect(slow.map(\.key) == ["mul:7x8"])
        #expect(slow.first?.seconds == 8)
    }
}

@Suite struct RewardsTests {
    let catalog = Catalog.shared

    @Test func everyRewardIsPrehistoricAndInPlace() {
        let pets = catalog.rewards.filter { $0.kind == .pet }
        let hats = catalog.rewards.filter { $0.kind == .accessory }
        let decorations = catalog.rewards.filter { $0.kind == .decoration }
        #expect(pets.count == 12, "the Dino Nursery")
        #expect(hats.count == 9)
        #expect(decorations.count == 11)
        let ids = Set(catalog.rewards.map(\.id))
        for (_, id) in Catalog.starDecorations { #expect(ids.contains(id)) }
        for old in Profile.renamedDecorations.keys { #expect(!ids.contains(old)) }
        let given = catalog.allLevels.compactMap(\.reward) + Catalog.starDecorations.map(\.reward)
        #expect(Set(given) == ids, "every reward can be won, and only once")
        #expect(given.count == ids.count)
    }

    @Test func everyLevelHasADinoFactCard() {
        #expect(catalog.factCards.count == catalog.allLevels.count)
        let script = Catalog.voicedLines
        for (level, fact) in catalog.factCards {
            #expect(fact.speaker == .narrator, "\(level.id)")
            #expect(fact.text.count < 130, "\(level.id) is short enough to read on one card")
            #expect(script[fact.audioKey ?? ""]?.scene == "facts", "\(level.id) is recorded")
        }
    }

    @Test func skySnatchIsInThePeaks() {
        let level = catalog.level("peaks-2")
        #expect(level?.mode == .skySnatch && level?.table == 8)
    }

    @Test func olderSavesGetThePrehistoricDecorations() throws {
        var profile = Profile(nickname: "Pip")
        profile.rewards = ["deco-palm", "deco-castle", "deco-mushroom", "deco-footprints"]
        profile.decorations = [PlacedDecoration(reward: "deco-rainbow", x: 0.2, y: 0.4)]
        let loaded = try JSONDecoder().decode(Profile.self, from: JSONEncoder().encode(profile))
        #expect(loaded.rewards == ["deco-palm", "deco-volcano", "deco-footprints"])
        #expect(loaded.decorations.first?.reward == "deco-fernarch")
    }

    @Test func partsWonBeforeWorkshopTrackingCountAsFitted() throws {
        var old = Profile(nickname: "Pip")
        old.crystals = ["hollow", "meadow"]
        var json = try JSONSerialization.jsonObject(with: JSONEncoder().encode(old)) as! [String: Any]
        var stats = json["stats"] as! [String: Any]
        stats.removeValue(forKey: "workshopsFixed")
        json["stats"] = stats
        let loaded = try JSONDecoder().decode(Profile.self, from: JSONSerialization.data(withJSONObject: json))
        #expect(loaded.stats.workshopsFixed == ["hollow", "meadow"])
        var fresh = Profile(nickname: "Kit")
        fresh.crystals = ["hollow"]
        #expect(try JSONDecoder().decode(Profile.self, from: JSONEncoder().encode(fresh)).stats.workshopsFixed.isEmpty,
                "a save that tracks the workshop keeps what it has")
    }

    @Test func secretAndCollectionTrophies() {
        var profile = Profile(nickname: "Pip")
        profile.trophiesReady = true
        profile.stats.museumAtNight = true
        profile.stats.rexScratches = Trophies.rexScratches
        profile.stats.workshopsFixed = catalog.islands.map(\.id)
        let won = Set(Trophies.awardOutsideLevel(&profile, limit: 20).map(\.id))
        #expect(won.isSuperset(of: ["night-museum", "itchy-back", "fact-family"]))
        #expect(!won.contains("fact-cards") && !won.contains("decorations-all"))

        var cards = Profile(nickname: "Kit")
        cards.trophiesReady = true
        for level in catalog.allLevels { cards.levels[level.id] = LevelRecord() ; cards.levels[level.id]?.stars = 1 }
        cards.rewards = catalog.rewards.filter { $0.kind == .decoration }.map(\.id)
        let more = Set(Trophies.awardOutsideLevel(&cards, limit: 40).map(\.id))
        #expect(more.isSuperset(of: ["fact-cards", "decorations-all"]))
        #expect(Trophies.progress(Trophies.trophy("fact-cards")!, in: cards)! == (30, 30))
    }

    @Test func untouchableNeedsAPerfectDinoDash() {
        let dash = catalog.level("hollow-2")!
        var profile = Profile(nickname: "Pip")
        profile.trophiesReady = true
        var slipped = LevelResult(stars: 3, accuracy: 0.9, score: 100, bestCombo: 3, correctFirstTry: dash.count - 1, total: dash.count)
        Progression.apply(slipped, levelID: dash.id, learner: profile.learner, to: &profile, catalog: catalog)
        #expect(profile.achievements["untouchable"] == nil && !profile.pendingTrophies.contains("untouchable"))
        slipped.correctFirstTry = dash.count
        let summary = Progression.apply(slipped, levelID: dash.id, learner: profile.learner, to: &profile, catalog: catalog)
        #expect(summary.trophies.map(\.id).contains("untouchable") || profile.pendingTrophies.contains("untouchable"))
    }
}
