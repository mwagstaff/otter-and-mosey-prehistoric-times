import Foundation

extension KeyedDecodingContainer {
    /// Decodes a value, falling back to a default when the key is missing or unreadable.
    /// This is what lets newer builds open older save files.
    func value<T: Decodable>(_ key: Key, default fallback: T) -> T {
        ((try? decodeIfPresent(T.self, forKey: key)) ?? nil) ?? fallback
    }
}

public struct AnswerOutcome: Equatable, Sendable {
    public let points: Int
    public let combo: Int
    public let multiplier: Int
    public let praise: String
    public let isLevelComplete: Bool
}

public struct LevelResult: Codable, Equatable, Sendable {
    public var stars: Int
    public var accuracy: Double
    public var score: Int
    public var bestCombo: Int
    public var correctFirstTry: Int
    public var total: Int
    /// Pearls scooped, and how many there were to scoop (Maths Splash only).
    public var pearls = 0
    public var pearlsOffered = 0
    public var hintsUsed = 0
    /// A question was answered right after at least two wrong tries.
    public var comeback = false
    /// Right-first-time answers per times table, keyed by the table ("3").
    public var tableFirstTry: [String: Int] = [:]

    public init(stars: Int, accuracy: Double, score: Int, bestCombo: Int, correctFirstTry: Int, total: Int) {
        self.stars = stars
        self.accuracy = accuracy
        self.score = score
        self.bestCombo = bestCombo
        self.correctFirstTry = correctFirstTry
        self.total = total
    }

    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        stars = c.value(.stars, default: 1)
        accuracy = c.value(.accuracy, default: 0)
        score = c.value(.score, default: 0)
        bestCombo = c.value(.bestCombo, default: 0)
        correctFirstTry = c.value(.correctFirstTry, default: 0)
        total = c.value(.total, default: 0)
        pearls = c.value(.pearls, default: 0)
        pearlsOffered = c.value(.pearlsOffered, default: 0)
        hintsUsed = c.value(.hintsUsed, default: 0)
        comeback = c.value(.comeback, default: false)
        tableFirstTry = c.value(.tableFirstTry, default: [:])
    }
}

public enum Encouragement {
    public static let praise = [
        "Brilliant!", "Super!", "You did it!", "Fantastic!", "Spot on!", "Wonderful!", "Amazing!", "Great thinking!",
    ]
    public static let retry = [
        "Nearly! Have another go.", "Good try. Try again!", "So close!", "Keep going, you can do it!",
        "Not quite. Take your time.", "Mistakes help us learn!",
    ]
    public static let combo = ["Combo!", "On fire!", "Unstoppable!", "Rainbow streak!"]

    public static func pick<R: RandomNumberGenerator>(_ list: [String], using rng: inout R) -> String {
        list.randomElement(using: &rng) ?? ""
    }
}

/// Runs one level's worth of questions. Pure logic: scenes ask it for questions and tell
/// it what happened, so every game mode shares the same scoring and adaptive behaviour.
public struct ChallengeSession: Sendable {
    public let level: LevelDef
    public let settings: ParentSettings
    public let inputProfile: InputProfile
    /// The times tables this level concentrates on, from the zone plan.
    public let focus: [Int]
    public private(set) var learner: LearnerModel
    public private(set) var asked = 0
    public private(set) var completed = 0
    public private(set) var correctFirstTry = 0
    public private(set) var combo = 0
    public private(set) var bestCombo = 0
    public private(set) var score = 0
    public private(set) var hintsUsed = 0
    public private(set) var comeback = false
    public private(set) var tableFirstTry: [String: Int] = [:]

    /// Wrong attempts on the current question.
    public private(set) var slipsOnQuestion = 0
    /// Questions in a row that needed more than one go.
    public private(set) var trickyStreak = 0
    /// At most one suggestion per question, so it never nags while a child is still trying.
    private var suggestedHelpThisQuestion = false

    /// Wrong attempts on one question before suggesting a grown-up (the hint arrives at two).
    public static let slipsBeforeHelp = 4
    /// Tricky questions in a row after which two slips on the next one are enough.
    public static let trickyStreakBeforeHelp = 3
    /// A missed fact comes back this many questions later, if the level is still going.
    public static let reaskAfter = 2

    private var rng: SeededGenerator
    private var planner: QuestionPlanner
    private var usedTexts: Set<String> = []
    /// Missed facts waiting to come back in this level: the key, its kind of question and when.
    private var reasks: [(key: String, skill: Skill, at: Int)] = []
    private var reasked: Set<String> = []
    /// When answers are recorded; tests set it to check the two-day rule.
    public var clock: Date?

    public init(
        level: LevelDef, learner: LearnerModel, settings: ParentSettings = ParentSettings(),
        inputProfile: InputProfile = .compactTouch, focus: [Int]? = nil, seed: UInt64 = .random(in: 0...UInt64.max),
        questionLimit: Int? = nil, catalog: Catalog = .shared
    ) {
        self.questionLimit = questionLimit
        self.level = level
        self.learner = learner
        self.settings = settings
        self.inputProfile = inputProfile
        let focus = focus ?? ZonePlan.focus(zone: catalog.zoneIndex(of: level.id) ?? 0, settings: settings)
        planner = QuestionPlanner(focus: focus, tables: settings.usableTables, multipliers: settings.usableMultipliers)
        self.focus = planner.focus
        rng = SeededGenerator(seed: seed)
    }

    /// Optional cap on the number of questions, for shorter sessions.
    private let questionLimit: Int?

    public var total: Int { questionLimit.map { max(1, min($0, level.count)) } ?? level.count }
    public var isFinished: Bool { completed >= total }
    public var progress: Double { total == 0 ? 1 : Double(completed) / Double(total) }
    public var multiplier: Int { min(1 + combo / 3, 4) }

    /// The kinds of question this level may ask, after the grown-up's choices.
    var activeSkills: [Skill] {
        let allowed = level.skills.filter(settings.usableQuestionTypes.contains)
        return allowed.isEmpty ? settings.usableQuestionTypes : allowed
    }

    /// The next question, or nil once the level has asked everything.
    public mutating func next() -> Question? {
        guard asked < total else { return nil }
        asked += 1
        slipsOnQuestion = 0
        suggestedHelpThisQuestion = false

        // A fact missed earlier in this level comes back.
        if let index = reasks.firstIndex(where: { $0.at <= asked }) {
            let reask = reasks.remove(at: index)
            if let (_, fact) = Fact.parse(reask.key) {
                planner.noteAsked(fact)
                return make(fact, skill: reask.skill)
            }
        }

        let skills = activeSkills
        let skill = skills[(asked - 1 + Int.random(in: 0..<skills.count, using: &rng)) % skills.count]
        guard let kind = skill.factKind else { return sequence() }
        return make(planner.next(kind: kind, learner: learner, using: &rng), skill: skill)
    }

    private mutating func make(_ fact: Fact, skill: Skill) -> Question {
        let question = MathsGenerator.question(for: fact, skill: skill, format: format(for: skill, fact: fact),
                                               level: learner.level(for: skill), learner: learner, using: &rng)
        usedTexts.insert(question.prompt)
        return question
    }

    /// Counting in multiples of one of the focus tables.
    private mutating func sequence() -> Question {
        var question: Question!
        for _ in 0..<8 {
            let table = focus.randomElement(using: &rng)!
            question = MathsGenerator.question(for: Fact(table: table, multiplier: 1), skill: .sequences,
                                               format: format(for: .sequences, fact: nil), level: learner.level(for: .sequences), using: &rng)
            if !usedTexts.contains(question.prompt) { break }
        }
        usedTexts.insert(question.prompt)
        return question
    }

    /// Picked or typed. Modes that can do both follow the grown-up's choice; adaptively, a fact
    /// is picked while it is new or being learnt and typed once it is getting there, because
    /// recalling an answer builds memory better than recognising it.
    func format(for skill: Skill, fact: Fact?) -> AnswerFormat {
        guard level.mode.answers == .pickOrType else { return .choice }
        switch settings.answerStyle {
        case .alwaysPick: return .choice
        case .alwaysType: return .typed
        case .adaptive:
            if let fact, let kind = skill.factKind { return learner.factState(fact, kind) >= .gettingThere ? .typed : .choice }
            return learner.stats(for: skill).rating >= 2.5 ? .typed : .choice
        }
    }

    /// A wrong attempt. The question stays open; only the combo is lost.
    /// Returns true when the child seems stuck and it's time to suggest asking a grown-up.
    @discardableResult
    public mutating func recordSlip() -> Bool {
        combo = 0
        slipsOnQuestion += 1
        guard !suggestedHelpThisQuestion else { return false }
        let stuckHere = slipsOnQuestion >= Self.slipsBeforeHelp
        let strugglingLately = trickyStreak >= Self.trickyStreakBeforeHelp && slipsOnQuestion >= 2
        guard stuckHere || strugglingLately else { return false }
        suggestedHelpThisQuestion = true
        trickyStreak = 0
        return true
    }

    /// The question has been answered correctly (possibly after slips or a hint).
    public mutating func complete(_ question: Question, firstTry: Bool, seconds: Double, usedHint: Bool) -> AnswerOutcome {
        completed += 1
        trickyStreak = firstTry ? 0 : trickyStreak + 1
        if usedHint { hintsUsed += 1 }
        if !firstTry, slipsOnQuestion >= 2 { comeback = true }
        if firstTry, let table = Self.table(of: question.key) { tableFirstTry[String(table), default: 0] += 1 }
        learner.record(key: question.key, skill: question.skill, correct: firstTry, seconds: seconds, usedHint: usedHint,
                       typed: question.format == .typed, on: clock ?? Date())
        // A missed fact comes back a couple of questions later, once.
        if !firstTry, Fact.parse(question.key) != nil, !reasked.contains(question.key), asked < total {
            reasked.insert(question.key)
            reasks.append((question.key, question.skill, min(asked + Self.reaskAfter, total)))
        }
        let points: Int
        if firstTry {
            correctFirstTry += 1
            combo += 1
            bestCombo = max(bestCombo, combo)
            points = 100 * multiplier + (settings.timedChallenges && seconds < 5 ? 50 : 0)
        } else {
            combo = 0
            points = 40
        }
        score += points
        let praise = combo >= 3 && combo % 3 == 0
            ? Encouragement.pick(Encouragement.combo, using: &rng)
            : Encouragement.pick(Encouragement.praise, using: &rng)
        return AnswerOutcome(points: points, combo: combo, multiplier: multiplier, praise: praise, isLevelComplete: isFinished)
    }

    /// The times table a number fact belongs to: "mul:3x4" and "div:3x4" are both the 3 times table.
    static func table(of key: String) -> Int? {
        guard key.hasPrefix("mul:") || key.hasPrefix("div:") else { return nil }
        return key.dropFirst(4).split(separator: "x").first.flatMap { Int($0) }
    }

    public mutating func retryMessage() -> String { Encouragement.pick(Encouragement.retry, using: &rng) }

    public var result: LevelResult {
        let accuracy = total == 0 ? 1 : Double(correctFirstTry) / Double(total)
        var result = LevelResult(
            stars: Progression.stars(forAccuracy: accuracy), accuracy: accuracy, score: score, bestCombo: bestCombo,
            correctFirstTry: correctFirstTry, total: total
        )
        result.hintsUsed = hintsUsed
        result.comeback = comeback
        result.tableFirstTry = tableFirstTry
        return result
    }
}
