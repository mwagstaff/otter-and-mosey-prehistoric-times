import Foundation

/// The two quick-fire games, played on the number pad away from the zones. Both are optional:
/// nothing in the adventure needs speed.
public enum QuickFireKind: String, Codable, CaseIterable, Sendable {
    /// Sixty seconds of quick-fire facts from the switched-on tables, against your own best.
    /// Unlocks once Raptor Ridge's Dial is back.
    case raptorRace
    /// Practice for the Year 4 Multiplication Tables Check: 25 questions from the 2 to 12 times
    /// tables, 6 seconds each. A grown-up switches it on.
    case mtc

    public var title: String {
        switch self {
        case .raptorRace: "Raptor Race"
        case .mtc: "Times Tables Check"
        }
    }
}

/// One finished quick-fire game, kept for the best score and the grown-ups' report.
public struct QuickFireScore: Codable, Equatable, Sendable {
    public var kind: QuickFireKind
    public var date: Date
    /// Right answers.
    public var score: Int
    /// Questions asked.
    public var total: Int

    public init(kind: QuickFireKind, date: Date, score: Int, total: Int) {
        self.kind = kind
        self.date = date
        self.score = score
        self.total = total
    }
}

/// One quick-fire question: a times-table or division fact, always typed.
public struct QuickFireQuestion: Equatable, Sendable {
    public let fact: Fact
    public let kind: FactKind

    public init(fact: Fact, kind: FactKind) {
        self.fact = fact
        self.kind = kind
    }

    /// "7 × 8 =" or "56 ÷ 8 =".
    public var prompt: String {
        kind == .multiply ? "\(fact.multiplier) × \(fact.table) =" : "\(fact.product) ÷ \(fact.table) ="
    }

    public var answer: Int { kind == .multiply ? fact.product : fact.multiplier }
    public var key: String { fact.key(kind) }
    public var skill: Skill { kind == .multiply ? .multiplication : .division }
}

/// Runs one quick-fire game. Pure logic: the screen keeps the time and says what was typed.
public struct QuickFireRound: Sendable {
    /// How long a Raptor Race lasts.
    public static let raceSeconds = 60.0
    /// The Multiplication Tables Check: 25 questions, 6 seconds each, 3 seconds between them.
    public static let mtcQuestions = 25
    public static let mtcSeconds = 6.0
    public static let mtcPause = 3.0
    /// The check covers the 2 to 12 times tables.
    public static let mtcTables = Array(2...12)
    /// The tables the real check asks most about.
    static let mtcHardTables: Set<Int> = [6, 7, 8, 9, 12]
    /// How many questions pass before a fact may come back in a Raptor Race.
    static let raceGap = 8

    public let kind: QuickFireKind
    public private(set) var learner: LearnerModel
    public private(set) var asked = 0
    public private(set) var right = 0
    public private(set) var current: QuickFireQuestion?
    /// Every question asked, with whether it was answered right, for the summary.
    public private(set) var answers: [(question: QuickFireQuestion, right: Bool)] = []
    /// When answers are recorded; tests set it.
    public var clock: Date?

    private var rng: SeededGenerator
    private let pool: [QuickFireQuestion]
    /// The Times Tables Check's questions, drawn up front so none repeat.
    private var planned: [QuickFireQuestion] = []

    public init(kind: QuickFireKind, settings: ParentSettings, learner: LearnerModel, seed: UInt64 = .random(in: 0...UInt64.max)) {
        self.kind = kind
        self.learner = learner
        rng = SeededGenerator(seed: seed)
        switch kind {
        case .mtc:
            pool = Self.mtcTables.flatMap { table in Self.mtcTables.map { QuickFireQuestion(fact: Fact(table: table, multiplier: $0), kind: .multiply) } }
            planned = Self.mtcPlan(from: pool, using: &rng)
        case .raptorRace:
            let kinds: [FactKind] = settings.usableQuestionTypes.contains(.division) ? [.multiply, .divide] : [.multiply]
            pool = settings.usableTables.flatMap { table in
                settings.usableMultipliers.flatMap { multiplier in kinds.map { QuickFireQuestion(fact: Fact(table: table, multiplier: multiplier), kind: $0) } }
            }
        }
    }

    /// The questions there will be: 25 for the check, open-ended for a race.
    public var total: Int? { kind == .mtc ? Self.mtcQuestions : nil }
    public var isFinished: Bool { kind == .mtc && asked >= Self.mtcQuestions && current == nil }

    /// 25 different facts, never both 7 × 8 and 8 × 7, about half from the harder tables.
    static func mtcPlan<R: RandomNumberGenerator>(from pool: [QuickFireQuestion], using rng: inout R) -> [QuickFireQuestion] {
        let unique = Dictionary(grouping: pool) { [min($0.fact.table, $0.fact.multiplier), max($0.fact.table, $0.fact.multiplier)] }
            .values.compactMap { $0.randomElement(using: &rng) }
            .sorted { ($0.fact.table, $0.fact.multiplier) < ($1.fact.table, $1.fact.multiplier) }
        let hard = unique.filter { mtcHardTables.contains($0.fact.table) || mtcHardTables.contains($0.fact.multiplier) }.shuffled(using: &rng)
        let easy = unique.filter { !(mtcHardTables.contains($0.fact.table) || mtcHardTables.contains($0.fact.multiplier)) }.shuffled(using: &rng)
        let hardCount = mtcQuestions / 2 + 1
        let chosen = Array(hard.prefix(hardCount)) + Array(easy.prefix(mtcQuestions - min(hardCount, hard.count)))
        // Show each fact with the larger number first or second, at random, as the real check does.
        return chosen.prefix(mtcQuestions).map { question in
            Bool.random(using: &rng) ? question : QuickFireQuestion(fact: question.fact.swapped, kind: .multiply)
        }.shuffled(using: &rng)
    }

    /// The next question, or nil once the check has asked all 25.
    public mutating func next() -> QuickFireQuestion? {
        switch kind {
        case .mtc:
            guard asked < planned.count else { current = nil; return nil }
            current = planned[asked]
        case .raptorRace:
            let recent = Set(answers.suffix(Self.raceGap).map { [min($0.question.fact.table, $0.question.fact.multiplier), max($0.question.fact.table, $0.question.fact.multiplier)] })
            let fresh = pool.filter { !recent.contains([min($0.fact.table, $0.fact.multiplier), max($0.fact.table, $0.fact.multiplier)]) }
            current = (fresh.isEmpty ? pool : fresh).randomElement(using: &rng)
        }
        asked += 1
        return current
    }

    /// Records the answer to the current question. `value` is nil when time ran out.
    @discardableResult
    public mutating func answer(_ value: Int?, seconds: Double) -> Bool {
        guard let question = current else { return false }
        let correct = value == question.answer
        if correct { right += 1 }
        answers.append((question, correct))
        learner.record(key: question.key, skill: question.skill, correct: correct, seconds: seconds, usedHint: false,
                       typed: true, on: clock ?? Date())
        current = nil
        return correct
    }

    /// The finished game, to keep.
    public func score(on date: Date = Date()) -> QuickFireScore {
        QuickFireScore(kind: kind, date: date, score: right, total: answers.count)
    }

    /// Saves a finished game: the learning it gave, and its score.
    public static func finish(_ round: QuickFireRound, profile: inout Profile, now: Date = Date()) {
        profile.learner = round.learner
        profile.quickFire.append(round.score(on: now))
        // Keep the newest 60 of each kind.
        for kind in QuickFireKind.allCases {
            let mine = profile.quickFire.filter { $0.kind == kind }
            if mine.count > 60 {
                let dropped = Set(mine.prefix(mine.count - 60).map(\.date))
                profile.quickFire.removeAll { $0.kind == kind && dropped.contains($0.date) }
            }
        }
    }

    /// The Raptor Race opens once the Snatch Pack has given back the Dial.
    public static func raceUnlocked(_ profile: Profile) -> Bool { profile.crystals.contains("ridge") }
}

extension QuickFireRound {
    /// What the grown-ups' report says about one times table.
    public struct TableReport: Equatable, Sendable {
        public let table: Int
        /// Multiplication facts secure or fluent, out of the multipliers in use.
        public let secure: Int
        public let facts: Int
        /// Right first time, out of every attempt, for this table's multiplying and dividing facts.
        public let accuracy: Double?
        /// The middle of recent quick typed answers, in seconds.
        public let typicalSeconds: Double?
    }
}

/// The grown-ups' progress report, worked out from the learner model.
public enum LearningReport {
    /// The state of every multiplication fact, `table` × `multiplier`.
    public static func grid(_ learner: LearnerModel) -> [[FactState]] {
        (1...12).map { table in (1...12).map { learner.factState(Fact(table: table, multiplier: $0), .multiply) } }
    }

    public static func table(_ table: Int, learner: LearnerModel, multipliers: [Int]) -> QuickFireRound.TableReport {
        let facts = multipliers.map { Fact(table: table, multiplier: $0) }
        let secure = facts.filter { learner.factState($0, .multiply) >= .secure }.count
        let stats = facts.flatMap { [learner.factStats($0, .multiply), learner.factStats($0, .divide)] }
        let attempts = stats.reduce(0) { $0 + $1.attempts }
        let first = stats.reduce(0) { $0 + $1.rightFirstTime }
        let times = stats.flatMap(\.typedSeconds).sorted()
        return QuickFireRound.TableReport(table: table, secure: secure, facts: facts.count,
                                          accuracy: attempts == 0 ? nil : Double(first) / Double(attempts),
                                          typicalSeconds: times.isEmpty ? nil : times[times.count / 2])
    }

    /// Facts typed right but slowly: the middle of their recent times, slowest first.
    public static func slowest(_ learner: LearnerModel, limit: Int = 8, over seconds: Double = FactStats.fluentSeconds) -> [(key: String, seconds: Double)] {
        learner.facts.compactMap { key, stats -> (String, Double)? in
            guard stats.typedSeconds.count >= 2 else { return nil }
            let sorted = stats.typedSeconds.sorted()
            let middle = sorted[sorted.count / 2]
            return middle > seconds ? (key, middle) : nil
        }
        .sorted { $0.1 != $1.1 ? $0.1 > $1.1 : $0.0 < $1.0 }
        .prefix(limit)
        .map { (key: $0.0, seconds: $0.1) }
    }

    /// "7 × 8" or "56 ÷ 8" for a fact key such as `mul:8x7`.
    public static func describe(_ key: String) -> String {
        guard let (kind, fact) = Fact.parse(key) else { return key }
        return QuickFireQuestion(fact: fact, kind: kind).prompt.replacingOccurrences(of: " =", with: "")
    }
}
