import Foundation
import Testing
@testable import PrehistoricTimesCore

/// Whether `text` contains `number` as a number of its own (so "24" is not found in "240" or "4s").
func mentions(_ text: String, _ number: Int) -> Bool {
    text.split(whereSeparator: { !$0.isNumber }).contains { Int($0) == number }
}

let monday = Calendar(identifier: .gregorian).date(from: DateComponents(year: 2026, month: 11, day: 16, hour: 10))!
let tuesday = Calendar(identifier: .gregorian).date(from: DateComponents(year: 2026, month: 11, day: 17, hour: 10))!

@Suite struct MathsGeneratorTests {
    /// The right answer worked out independently of the generator.
    func expected(_ fact: Fact, _ skill: Skill) -> Int {
        switch skill {
        case .multiplication, .wordProblems: fact.product
        case .missingNumber, .division: fact.multiplier
        case .sequences: -1
        }
    }

    @Test func everyFactAndKindIsWellFormed() {
        var rng = SeededGenerator(seed: 42)
        let narration = Narration.clips
        for table in 1...12 {
            for multiplier in 1...12 {
                let fact = Fact(table: table, multiplier: multiplier)
                for skill in [Skill.multiplication, .missingNumber, .division, .wordProblems] {
                    for _ in 0..<4 {
                        let question = MathsGenerator.question(for: fact, skill: skill, using: &rng)
                        let answer = expected(fact, skill)
                        #expect(question.answer == String(answer), "\(question.prompt)")
                        #expect(question.choices.count == 3 && Set(question.choices).count == 3, "\(question.prompt) \(question.choices)")
                        #expect(question.choices.filter { question.isCorrect(choice: $0) }.count == 1)
                        #expect(question.choices.allSatisfy { (Int($0) ?? 0) > 0 }, "\(question.choices)")
                        #expect(question.key == fact.key(skill.factKind!), "\(question.key)")
                        #expect(!question.hint.isEmpty && !mentions(question.hint, answer), "hint gives away \(answer): \(question.hint)")
                        #expect(narration[question.audioKey ?? ""] != nil, "no narration for \(question.prompt)")
                    }
                }
            }
        }
    }

    @Test func promptsAreIndependentlyCheckable() {
        var rng = SeededGenerator(seed: 7)
        for _ in 0..<600 {
            let skill = [Skill.multiplication, .missingNumber, .division].randomElement(using: &rng)!
            let question = MathsGenerator.make(skill: skill, level: 3, tables: Array(1...12), using: &rng)
            let parts = question.prompt.split(separator: " ").map(String.init)
            let answer = Int(question.answer)!
            switch parts[1] {
            case "×" where parts[0] == "?": #expect(answer * Int(parts[2])! == Int(parts[4])!, "\(question.prompt)")
            case "×": #expect(Int(parts[0])! * Int(parts[2])! == answer, "\(question.prompt)")
            case "÷": #expect(Int(parts[0])! == Int(parts[2])! * answer, "\(question.prompt)")
            default: Issue.record("unexpected prompt \(question.prompt)")
            }
        }
    }

    @Test func sequencesCountInTheTable() {
        var rng = SeededGenerator(seed: 9)
        for table in 1...12 {
            for level in 1...5 {
                for _ in 0..<40 {
                    let question = MathsGenerator.question(for: Fact(table: table, multiplier: 1), skill: .sequences, level: level, using: &rng)
                    let terms = question.prompt.components(separatedBy: ", ")
                    #expect(terms.count == 5 && terms.filter { $0 == "?" }.count == 1, "\(question.prompt)")
                    let filled = terms.map { $0 == "?" ? Int(question.answer)! : Int($0)! }
                    let steps = Set(zip(filled, filled.dropFirst()).map { abs($1 - $0) })
                    #expect(steps == [table], "\(question.prompt) = \(question.answer)")
                    #expect(filled.allSatisfy { $0 % table == 0 && $0 >= 0 })
                    #expect(!mentions(question.hint, Int(question.answer)!), "\(question.hint)")
                    #expect(question.key == "seq:\(table)")
                }
            }
        }
    }

    @Test func wrongChoicesAreLikelySlips() {
        var rng = SeededGenerator(seed: 3)
        let likely: Set<String> = ["48", "64", "49", "63", "15", "65", "57", "55", "66"]
        for _ in 0..<200 {
            let question = MathsGenerator.question(for: Fact(table: 8, multiplier: 7), skill: .multiplication, using: &rng)
            #expect(Set(question.choices).subtracting(["56"]).isSubset(of: likely), "\(question.choices)")
        }
        #expect(MathsGenerator.digitsSwapped(42) == 24 && MathsGenerator.digitsSwapped(44) == nil && MathsGenerator.digitsSwapped(40) == nil)
    }

    @Test func chosenTablesAndMultipliersAreTheOnlyOnesUsed() {
        var rng = SeededGenerator(seed: 22)
        for _ in 0..<300 {
            let question = MathsGenerator.make(skill: .division, level: 3, tables: [6, 7], multipliers: [2, 5, 11], using: &rng)
            let fact = Fact(key: question.key)!
            #expect([6, 7].contains(fact.table) && [2, 5, 11].contains(fact.multiplier), "\(question.prompt)")
        }
    }

    @Test func reviewFactsRespectTablesAndMultipliers() {
        #expect(MathsGenerator.allows(factKey: "mul:3x7", tables: [2, 3]))
        #expect(MathsGenerator.allows(factKey: "mul:3x8", tables: [2, 3]), "8 lots of 3 is in the 3 times table")
        #expect(!MathsGenerator.allows(factKey: "mul:8x3", tables: [2, 3]))
        #expect(!MathsGenerator.allows(factKey: "div:3x11", tables: [2, 3], multipliers: Array(1...10)))
        #expect(MathsGenerator.allows(factKey: "seq:4", tables: [2], multipliers: [5]))
    }

    @Test func factKeysRebuildTheSameFact() {
        var rng = SeededGenerator(seed: 1)
        #expect(MathsGenerator.make(factKey: "mul:8x7", level: 3, using: &rng)?.answer == "56")
        let divide = MathsGenerator.make(factKey: "div:4x9", level: 3, using: &rng)
        #expect(divide?.prompt == "36 ÷ 4 = ?" && divide?.answer == "9")
        #expect(MathsGenerator.make(factKey: "seq:4", level: 3, using: &rng) == nil)
        #expect(Fact(key: "mul:8x7") == Fact(table: 8, multiplier: 7) && Fact(key: "8x7")?.swapped == Fact(table: 7, multiplier: 8))
        #expect(Fact(key: "seq:4") == nil && Fact.parse("div:3x4")?.0 == .divide)
    }

    @Test func typedFormatUsesTheAnswerDigits() {
        var rng = SeededGenerator(seed: 9)
        let question = MathsGenerator.question(for: Fact(table: 6, multiplier: 7), skill: .multiplication, format: .typed, using: &rng)
        #expect(question.format == .typed && question.typingTarget == "42")
        #expect(question.isCorrect(typed: " 42 "))
    }

    @Test func olderSettingsFillInTheRest() throws {
        let decoded = try JSONDecoder().decode(ParentSettings.self, from: Data(#"{"tables":[2,5]}"#.utf8))
        #expect(decoded.tables == [2, 5] && decoded.multipliers == Array(1...12))
        #expect(decoded.yearGroup == .year3 && decoded.answerStyle == .adaptive && decoded.chasePace == .calm)
        #expect(decoded.usableFocus == [2, 5], "no focus table switched on means every table is focus")
    }
}

@Suite struct HintTests {
    @Test func hintsLeanOnKnownFacts() {
        var learner = LearnerModel()
        let fact = Fact(table: 8, multiplier: 7)
        #expect(!Hints.multiply(fact, learner: learner).contains("Swap"))
        for date in [monday, monday, tuesday] {
            learner.record(key: "mul:7x8", skill: .multiplication, correct: true, seconds: 5, usedHint: false, on: date)
        }
        #expect(Hints.multiply(fact, learner: learner).contains("Swap"), "8 × 7 is known, so 7 × 8 can lean on it")
        #expect(!Hints.divide(Fact(table: 7, multiplier: 8)).contains("know"))
        #expect(Hints.divide(Fact(table: 7, multiplier: 8), learner: learner).contains("You know this one"))
    }

    @Test func everyTableHasItsOwnStrategy() {
        let hints = (2...12).map { Hints.strategy(table: $0, times: 7) }
        #expect(Set(hints).count == hints.count)
        #expect(Hints.multiply(Fact(table: 9, multiplier: 1)) == Hints.multiply(Fact(table: 1, multiplier: 9)))
    }
}

@Suite struct FactTests {
    @Test func factsClimbTheLadderAndNeedTwoDays() {
        var stats = FactStats()
        #expect(stats.state == .new)
        stats.record(correct: false, usedHint: false, seconds: 9, typed: false, day: "2026-11-16")
        #expect(stats.state == .learning)
        stats.record(correct: true, usedHint: false, seconds: 5, typed: false, day: "2026-11-16")
        #expect(stats.state == .gettingThere)
        stats.record(correct: true, usedHint: false, seconds: 5, typed: false, day: "2026-11-16")
        stats.record(correct: true, usedHint: false, seconds: 5, typed: false, day: "2026-11-16")
        #expect(stats.state == .gettingThere, "three right on one day is not enough")
        stats.record(correct: true, usedHint: false, seconds: 5, typed: false, day: "2026-11-17")
        #expect(stats.state == .secure)
        for _ in 0..<3 { stats.record(correct: true, usedHint: false, seconds: 2.5, typed: true, day: "2026-11-17") }
        #expect(stats.state == .fluent)
        stats.record(correct: false, usedHint: false, seconds: 9, typed: true, day: "2026-11-18")
        #expect(stats.state == .learning && stats.best == .fluent, "a slip resets the state but never the best")
    }

    @Test func hintsAndPickingNeverMakeAFactFluent() {
        var hinted = FactStats(), picked = FactStats()
        for day in ["2026-11-16", "2026-11-17", "2026-11-18"] {
            hinted.record(correct: true, usedHint: true, seconds: 1, typed: true, day: day)
            picked.record(correct: true, usedHint: false, seconds: 1, typed: false, day: day)
        }
        #expect(hinted.state == .learning)
        #expect(picked.state == .secure, "picking quickly shows knowing, but fluency means typing")
    }

    @Test func slowTypingStaysSecure() {
        var stats = FactStats()
        for day in ["2026-11-16", "2026-11-17", "2026-11-17", "2026-11-17"] {
            stats.record(correct: true, usedHint: false, seconds: 7, typed: true, day: day)
        }
        #expect(stats.state == .secure)
    }

    @Test func learnerTracksFactsAndLightningAnswers() {
        var learner = LearnerModel()
        learner.record(key: "mul:8x7", skill: .multiplication, correct: true, seconds: 2, usedHint: false, typed: true, on: monday)
        learner.record(key: "div:8x7", skill: .division, correct: true, seconds: 2, usedHint: false, typed: false, on: monday)
        learner.record(key: "mul:8x7", skill: .missingNumber, correct: true, seconds: 5, usedHint: false, typed: true, on: monday)
        learner.record(key: "seq:8", skill: .sequences, correct: true, seconds: 1, usedHint: false, typed: true, on: monday)
        #expect(learner.factStats(Fact(table: 8, multiplier: 7), .multiply).attempts == 2)
        #expect(learner.factStats(Fact(table: 8, multiplier: 7), .divide).attempts == 1)
        #expect(learner.facts.count == 2, "counting in 8s is not a single fact")
        #expect(learner.lightningAnswers == 1, "only typed, right first time and under three seconds")
    }

    @Test func fossilBonesGoInAndStay() {
        var learner = LearnerModel()
        func secure(_ multiplier: Int) {
            for date in [monday, monday, tuesday] {
                learner.record(key: "mul:4x\(multiplier)", skill: .multiplication, correct: true, seconds: 5, usedHint: false, on: date)
            }
        }
        #expect(Fossils.bones(table: 4, learner: learner).allSatisfy { !$0.placed })
        secure(3)
        #expect(Fossils.bones(table: 4, learner: learner).filter(\.placed).map(\.fact.multiplier) == [3])
        learner.record(key: "mul:4x3", skill: .multiplication, correct: false, seconds: 5, usedHint: false, on: tuesday)
        #expect(Fossils.placed(table: 4, learner: learner, multipliers: Array(1...12)) == 1, "a slip never takes a bone back")
        for multiplier in 1...10 where multiplier != 3 { secure(multiplier) }
        #expect(!Fossils.isComplete(table: 4, learner: learner, multipliers: Array(1...12)))
        #expect(Fossils.isComplete(table: 4, learner: learner, multipliers: Array(1...10)), "× 11 and × 12 switched off")
    }
}

@Suite struct ZonePlanTests {
    func plan(_ group: YearGroup) -> [[Int]] {
        var settings = ParentSettings()
        settings.apply(group)
        return ZonePlan.focus(for: settings)
    }

    @Test func year3WarmsUpThenTakesOneNewTableAtATime() {
        #expect(plan(.year3) == [[10, 2, 5], [3], [4], [8], [3, 4, 8], [10, 2, 5, 3, 4, 8]])
    }

    @Test func otherYearGroups() {
        #expect(plan(.year2) == [[10], [2], [5], [10, 2, 5], [10, 2, 5], [10, 2, 5]])
        #expect(plan(.year4) == [[10, 2, 5, 3, 4, 8], [11], [9, 6], [12, 7], [11, 9, 6, 12, 7], [10, 2, 5, 11, 3, 4, 9, 6, 8, 12, 7]])
        let all = plan(.all)
        #expect(all.count == 6 && all[0] == [1, 10, 2] && all[5].count == 12)
    }

    @Test func oddChoicesStillFillEveryZone() {
        var settings = ParentSettings()
        settings.tables = [7]
        settings.focusTables = []
        #expect(ZonePlan.focus(for: settings) == Array(repeating: [7], count: 6))
        settings.tables = [2, 7]
        settings.focusTables = [7]
        #expect(ZonePlan.focus(for: settings) == [[2], [7], [7], [7], [7], [2, 7]])
        settings.tables = []
        #expect(ZonePlan.focus(for: settings).allSatisfy { !$0.isEmpty })
        #expect(ZonePlan.focus(zone: 9, settings: ParentSettings()) == [10, 2, 5, 3, 4, 8])
    }
}

@Suite struct PlannerTests {
    let catalog = Catalog.shared

    /// Plays a level answering everything right first time, returning the facts asked.
    func play(_ levelID: String, learner: LearnerModel = LearnerModel(), settings: ParentSettings = ParentSettings(), seed: UInt64) -> (keys: [String], learner: LearnerModel) {
        var session = ChallengeSession(level: catalog.level(levelID)!, learner: learner, settings: settings, seed: seed)
        session.clock = monday
        var keys: [String] = []
        while let question = session.next() {
            keys.append(question.key)
            _ = session.complete(question, firstTry: true, seconds: 4, usedHint: false)
        }
        return (keys, session.learner)
    }

    @Test func aFirstLevelStartsWithTheEasiestFacts() {
        let keys = play("hollow-1", seed: 1).keys
        #expect(Fact(key: keys[0])?.multiplier == 1, "\(keys)")
        #expect(keys.allSatisfy { [10, 2, 5].contains(Fact(key: $0)?.table ?? 0) }, "zone 1 warms up with 2, 5 and 10")
    }

    @Test func newFactsArriveEasiestFirst() {
        for seed in 0..<30 {
            let keys = play("hollow-1", seed: UInt64(seed)).keys
            let early = keys.prefix(QuestionPlanner.newFactsPerLevel).compactMap { Fact(key: $0)?.multiplier }
            #expect(early.allSatisfy { [1, 2, 10].contains($0) }, "seed \(seed): \(keys)")
        }
    }

    @Test func noQuestionRepeatsInALevel() {
        for seed in 0..<40 {
            for id in ["hollow-4", "meadow-1", "meadow-2", "swamp-1", "ridge-1", "rex-5"] {
                var session = ChallengeSession(level: catalog.level(id)!, learner: LearnerModel(), seed: UInt64(seed))
                var prompts: [String] = [], facts: [String] = []
                while let question = session.next() {
                    prompts.append(question.prompt)
                    if Fact(key: question.key) != nil { facts.append(question.key) }
                    _ = session.complete(question, firstTry: true, seconds: 4, usedHint: false)
                }
                #expect(Set(prompts).count == prompts.count, "\(id) seed \(seed): \(prompts)")
                #expect(Set(facts).count == facts.count, "\(id) seed \(seed): \(facts)")
            }
        }
    }

    @Test func eachZoneConcentratesOnItsTables() {
        for (zone, id) in ["hollow-1", "meadow-1", "swamp-1", "peaks-1"].enumerated() {
            let wanted = ZonePlan.focus(zone: zone, settings: ParentSettings())
            let keys = play(id, seed: 3).keys
            #expect(keys.compactMap(Fact.init(key:)).allSatisfy { wanted.contains($0.table) }, "\(id): \(keys)")
        }
    }

    @Test func secureAndDueFactsFromOtherTablesComeBack() {
        var learner = LearnerModel()
        learner.record(key: "mul:8x7", skill: .multiplication, correct: false, seconds: 9, usedHint: false, on: monday)
        for _ in 0..<5 { learner.record(key: "seq:3", skill: .sequences, correct: true, seconds: 2, usedHint: false, on: monday) }
        var found = 0
        for seed in 0..<40 where play("meadow-1", learner: learner, seed: UInt64(seed)).keys.contains("mul:8x7") { found += 1 }
        #expect(found >= 15, "the due 8 × 7 should often come back in the 3s zone (\(found)/40)")
    }

    @Test func aMissedFactIsNotAskedAgainInTheSameLevel() {
        var session = ChallengeSession(level: catalog.level("hollow-4")!, learner: LearnerModel(), seed: 4)
        let first = session.next()!
        session.recordSlip()
        _ = session.complete(first, firstTry: false, seconds: 9, usedHint: false)
        var later: [String] = []
        while let question = session.next() {
            later.append(question.key)
            _ = session.complete(question, firstTry: true, seconds: 3, usedHint: false)
        }
        #expect(!later.contains(first.key))
    }

    @Test func aCountingLevelSticksToItsTable() {
        for (id, table) in [("meadow-2", 3), ("swamp-2", 4), ("peaks-2", 8)] {
            var learner = LearnerModel()
            learner.record(key: "mul:5x7", skill: .multiplication, correct: false, seconds: 9, usedHint: false, on: monday)
            for seed in 0..<20 {
                let keys = play(id, learner: learner, seed: UInt64(seed)).keys
                #expect(keys.allSatisfy { $0 == "seq:\(table)" || Fact(key: $0)?.table == table }, "\(id): \(keys)")
            }
        }
    }

    @Test func answersArePickedThenTyped() {
        let egg = catalog.level("hollow-1")!
        var session = ChallengeSession(level: egg, learner: LearnerModel(), seed: 2)
        #expect(session.next()?.format == .choice, "new facts are picked")
        var learner = LearnerModel()
        for multiplier in 1...12 { for table in [10, 2, 5] {
            learner.record(key: "mul:\(table)x\(multiplier)", skill: .multiplication, correct: true, seconds: 3, usedHint: false, on: monday)
        } }
        session = ChallengeSession(level: egg, learner: learner, seed: 2)
        #expect(session.next()?.format == .typed, "facts getting there are typed")
        var settings = ParentSettings()
        settings.answerStyle = .alwaysPick
        session = ChallengeSession(level: egg, learner: learner, settings: settings, seed: 2)
        #expect(session.next()?.format == .choice)
        settings.answerStyle = .alwaysType
        session = ChallengeSession(level: egg, learner: LearnerModel(), settings: settings, seed: 2)
        #expect(session.next()?.format == .typed)
        session = ChallengeSession(level: catalog.level("hollow-2")!, learner: learner, settings: settings, seed: 2)
        #expect(session.next()?.format == .choice, "Dino Dash is always tapped")
    }

    @Test func switchedOffQuestionKindsAreLeftOut() {
        var settings = ParentSettings()
        settings.questionTypes = [.multiplication, .division]
        for seed in 0..<10 {
            var session = ChallengeSession(level: catalog.level("rex-5")!, learner: LearnerModel(), settings: settings, seed: UInt64(seed))
            while let question = session.next() {
                #expect([.multiplication, .division].contains(question.skill))
                _ = session.complete(question, firstTry: true, seconds: 3, usedHint: false)
            }
        }
    }
}

@Suite struct NarrationTests {
    @Test func everyFactIsRecordedInEveryForm() {
        let narration = Narration.clips
        #expect(narration.count == 12 * 12 * 3 + 5)
        #expect(narration["mul_8x7"] == "7 times 8." && narration["mulq_8x7"] == "What times 8 makes 56?")
        #expect(narration["div_4x9"] == "36 divided by 4." && narration["mul_12x12"] == "12 times 12.")
        for skill in Skill.allCases { #expect(narration["skill_\(skill.rawValue)"] != nil, "\(skill)") }
    }
}

@Suite struct LearnerTests {
    @Test func ratingRisesWithSuccessAndEasesWithMistakes() {
        var learner = LearnerModel()
        #expect(learner.level(for: .sequences) == 1)
        for _ in 0..<12 { learner.record(key: "seq:3", skill: .sequences, correct: true, seconds: 3, usedHint: false) }
        let raised = learner.level(for: .sequences)
        #expect(raised >= 3)
        for _ in 0..<6 { learner.record(key: "seq:3", skill: .sequences, correct: false, seconds: 10, usedHint: false) }
        #expect(learner.level(for: .sequences) < raised)
        for _ in 0..<100 { learner.record(key: "x", skill: .sequences, correct: false, seconds: 1, usedHint: false) }
        #expect(learner.stats(for: .sequences).rating == 1.0)
        for _ in 0..<100 { learner.record(key: "x", skill: .sequences, correct: true, seconds: 1, usedHint: false) }
        #expect(learner.stats(for: .sequences).rating == 5.0)
    }

    @Test func hintsCountAsLearningNotMastery() {
        var hinted = LearnerModel(), clean = LearnerModel()
        for _ in 0..<5 {
            hinted.record(key: "k", skill: .division, correct: true, seconds: 3, usedHint: true)
            clean.record(key: "k", skill: .division, correct: true, seconds: 3, usedHint: false)
        }
        #expect(hinted.stats(for: .division).rating < clean.stats(for: .division).rating)
    }

    @Test func troublesomeItemsComeBackAfterAGap() {
        var learner = LearnerModel()
        learner.record(key: "mul:8x7", skill: .multiplication, correct: false, seconds: 9, usedHint: false)
        #expect(learner.dueFacts(.multiply).isEmpty, "not due straight away")
        for _ in 0..<3 { learner.record(key: "seq:3", skill: .sequences, correct: true, seconds: 2, usedHint: false) }
        #expect(learner.dueFacts(.multiply) == [Fact(table: 8, multiplier: 7)])
        #expect(learner.dueFacts(.divide).isEmpty)
        #expect(learner.dueKeys(for: [.multiplication]) == ["mul:8x7"])
    }

    @Test func itemsAreRetiredOnceSecure() {
        var learner = LearnerModel()
        learner.record(key: "mul:7x8", skill: .multiplication, correct: false, seconds: 9, usedHint: false)
        for _ in 0..<LearnerModel.intervals.count {
            learner.record(key: "mul:7x8", skill: .multiplication, correct: true, seconds: 4, usedHint: false)
        }
        #expect(learner.items["mul:7x8"] == nil)
    }

    @Test func gapsGrowAfterEachSuccess() {
        var learner = LearnerModel()
        learner.record(key: "div:4x6", skill: .division, correct: false, seconds: 9, usedHint: false)
        let first = learner.items["div:4x6"]!.dueAt - learner.answerCount
        learner.record(key: "div:4x6", skill: .division, correct: true, seconds: 4, usedHint: false)
        let second = learner.items["div:4x6"]!.dueAt - learner.answerCount
        #expect(second > first)
    }

    @Test func dashboardSummaries() {
        var learner = LearnerModel()
        #expect(learner.accuracy(for: .maths) == nil)
        for index in 0..<10 { learner.record(key: "k", skill: .division, correct: index < 3, seconds: 5, usedHint: false) }
        #expect(learner.accuracy(for: .maths) == 0.3)
        #expect(learner.skillsNeedingPractice == [.division])
        #expect(learner.practisedSkills == [.division])
    }
}

@Suite struct SpeechTests {
    @Test func mouthOpensOnLoudAndClosesOnQuiet() {
        var gate = MouthGate()
        let quiet = gate.update(level: 0.1, at: 0)
        let loud = gate.update(level: 0.8, at: 0.1)
        let between = gate.update(level: 0.25, at: 0.3)
        let silent = gate.update(level: 0.05, at: 0.5)
        #expect(!quiet && loud)
        #expect(between, "between the thresholds it stays as it was")
        #expect(!silent)
    }

    @Test func mouthDoesNotFlickerOnNoisyInput() {
        var gate = MouthGate()
        var changes = 0
        var last = false
        // Loudness that jumps above and below the thresholds on every 1/30 s reading.
        for step in 0..<60 {
            let open = gate.update(level: step.isMultiple(of: 2) ? 0.9 : 0.0, at: Double(step) / 30)
            if open != last { changes += 1 }
            last = open
        }
        #expect(Double(changes) <= 2.0 / 0.07 + 1, "state changes are limited by the hold time")
        #expect(changes < 30, "far fewer changes than readings")
    }

    @Test func chatterLastsForTheLineAndThenStops() {
        #expect(Chatter.duration(forTextLength: 3) == 1.0)
        #expect(abs(Chatter.duration(forTextLength: 30) - 1.8) < 0.0001)
        #expect(Chatter.duration(forTextLength: 500) == 4.0)
        let duration = Chatter.duration(forTextLength: 40)
        var gate = MouthGate()
        var opens = 0
        var last = false
        var peak = 0.0
        for step in 0..<Int(duration * 30) {
            let time = Double(step) / 30
            let level = Chatter.level(at: time, duration: duration)
            #expect((0...1).contains(level))
            peak = max(peak, level)
            let open = gate.update(level: level, at: time)
            if open, !last { opens += 1 }
            last = open
        }
        #expect(peak > 0.6)
        #expect(opens >= 6, "the mouth opens several times over a line (\(opens))")
        #expect(Chatter.level(at: duration, duration: duration) == 0)
        #expect(Chatter.level(at: duration + 1, duration: duration) == 0)
    }
}

@Suite struct SettingsTests {
    private func values(_ settings: ParentSettings) -> [String: String] {
        Dictionary(uniqueKeysWithValues: settings.summary.map { ($0.label, $0.value.replacingOccurrences(of: "\u{00A0}", with: " ")) })
    }

    private func changed(_ settings: ParentSettings) -> [String] {
        settings.summary.filter(\.changed).map(\.label)
    }

    @Test func newPlayersStartOnYear3() {
        let fresh = ParentSettings()
        #expect(values(fresh) == [
            "Year group": "Year 3",
            "Times tables": "2, 3, 4, 5, 8 and 10",
            "Focus on": "× 3, × 4 and × 8",
            "Multiply and divide by": "Everything from × 1 to × 12",
            "Question types": "All 5 kinds",
            "Answers": "Adaptive",
            "Chases": "Calm",
        ])
        #expect(changed(fresh).isEmpty)
    }

    @Test func presetsAndHandPicking() {
        var settings = ParentSettings()
        settings.apply(.year4)
        #expect(settings.tables == Array(2...12) && settings.focusTables == [6, 7, 9, 11, 12])
        #expect(values(settings)["Year group"] == "Year 4")
        settings.toggle(table: 12)
        #expect(settings.yearGroup == .custom && !settings.focusTables.contains(12), "a switched-off table is no longer focus")
        settings.toggle(table: 12)
        settings.toggle(focus: 12)
        #expect(settings.yearGroup == .year4, "back to exactly the preset")
        settings.apply(.year2)
        settings.toggle(table: 2); settings.toggle(table: 5); settings.toggle(table: 10)
        #expect(settings.tables == [10], "the last table always stays on")
        settings.toggle(focus: 7)
        #expect(!settings.focusTables.contains(7), "only switched-on tables can be focus")
    }

    @Test func multipliersAndKindsReadNaturally() {
        var settings = ParentSettings()
        settings.multipliers = Array(1...10)
        #expect(values(settings)["Multiply and divide by"] == "× 1 to × 10")
        settings.multipliers = [2, 5, 10]
        #expect(values(settings)["Multiply and divide by"] == "× 2, × 5 and × 10")
        settings.questionTypes = [.multiplication, .missingNumber, .division, .sequences]
        #expect(values(settings)["Question types"] == "All but word problems")
        settings.answerStyle = .alwaysType
        settings.chasePace = .gentle
        #expect(values(settings)["Answers"] == "Always type" && values(settings)["Chases"] == "Gentle dinosaurs")
        #expect(changed(settings) == ["Multiply and divide by", "Question types", "Answers", "Chases"])
    }

    @Test func olderSavesHaveNotBeenChecked() throws {
        let profile = try JSONDecoder().decode(Profile.self, from: Data(#"{"nickname":"Skyla"}"#.utf8))
        #expect(!profile.grownUpChecked)
    }
}
