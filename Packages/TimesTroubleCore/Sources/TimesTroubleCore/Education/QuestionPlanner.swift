import Foundation

/// Chooses which fact each question in a level is about.
///
/// Roughly a quarter of questions revisit facts that are due for spaced review, about one in
/// seven keeps a secure fact warm, and the rest practise the zone's focus tables: facts still
/// being learnt first, with no more than `newFactsPerLevel` brand-new facts brought in a level
/// (easiest first). A fact is asked at most once in a level, so no question repeats; it only
/// comes round again when the level asks more questions than there are facts to choose from.
public struct QuestionPlanner: Sendable {
    public static let newFactsPerLevel = 3
    public static let reviewShare = 0.25
    public static let secureShare = 0.15
    public static let maxPerLevel = 1

    public let focus: [Int]
    public let tables: [Int]
    public let multipliers: [Int]
    public private(set) var newIntroduced = 0
    private var askedCount: [Fact: Int] = [:]
    private var last: Fact?

    public init(focus: [Int], tables: [Int], multipliers: [Int]) {
        self.tables = tables.isEmpty ? MathsGenerator.defaultTables : tables
        let focus = focus.filter(self.tables.contains)
        self.focus = focus.isEmpty ? self.tables : focus
        self.multipliers = multipliers.isEmpty ? MathsGenerator.defaultMultipliers : multipliers
    }

    /// The fact for the next question of `kind`.
    public mutating func next<R: RandomNumberGenerator>(kind: FactKind, learner: LearnerModel, using rng: inout R) -> Fact {
        let everything = MathsGenerator.facts(tables: tables, multipliers: multipliers)
        let allowed = Set(everything)
        let roll = Double.random(in: 0..<1, using: &rng)
        var pick: Fact?
        if roll < Self.reviewShare {
            pick = learner.dueFacts(kind).first { allowed.contains($0) && available($0) }
        } else if roll < Self.reviewShare + Self.secureShare {
            pick = everything.filter { available($0) && learner.factState($0, kind) >= .secure }.randomElement(using: &rng)
        }
        if pick == nil { pick = practise(kind: kind, learner: learner, using: &rng) }
        let fact = pick
            ?? everything.filter(available).randomElement(using: &rng)
            ?? leastAsked(everything).randomElement(using: &rng) ?? everything[0]
        noteAsked(fact)
        return fact
    }

    /// Records a fact asked outside the planner, such as a missed one coming back.
    public mutating func noteAsked(_ fact: Fact) {
        askedCount[fact, default: 0] += 1
        last = fact
    }

    /// Every fact has had its turn: the ones asked least, other than the last.
    private func leastAsked(_ facts: [Fact]) -> [Fact] {
        let others = facts.count > 1 ? facts.filter { $0 != last } : facts
        let fewest = others.map { askedCount[$0, default: 0] }.min() ?? 0
        return others.filter { askedCount[$0, default: 0] == fewest }
    }

    func available(_ fact: Fact) -> Bool { fact != last && askedCount[fact, default: 0] < Self.maxPerLevel }

    /// A focus fact: something still being learnt, or a new one while there is room for it.
    private mutating func practise<R: RandomNumberGenerator>(kind: FactKind, learner: LearnerModel, using rng: inout R) -> Fact? {
        let focusFacts = MathsGenerator.facts(tables: focus, multipliers: multipliers).filter(available)
        let working = focusFacts.filter { [.learning, .gettingThere].contains(learner.factState($0, kind)) }
        let unseen = focusFacts.filter { learner.factState($0, kind) == .new }.sorted(by: Self.easierFirst)
        let notYetThisLevel = working.filter { askedCount[$0, default: 0] == 0 }
        if newIntroduced < Self.newFactsPerLevel, let first = unseen.first,
           notYetThisLevel.isEmpty || Bool.random(using: &rng) {
            newIntroduced += 1
            return first
        }
        if let fact = notYetThisLevel.randomElement(using: &rng) ?? working.randomElement(using: &rng) { return fact }
        // Nothing left to practise: the next new fact after all, then anything in focus.
        if let first = unseen.first { return first }
        return focusFacts.randomElement(using: &rng)
    }

    /// Introduction order: easy multipliers first (× 1, × 2, × 10, × 5 …), then easier tables.
    static func easierFirst(_ a: Fact, _ b: Fact) -> Bool {
        func rank(_ value: Int, in order: [Int]) -> Int { order.firstIndex(of: value) ?? order.count }
        let ma = rank(a.multiplier, in: MathsGenerator.introductionOrder), mb = rank(b.multiplier, in: MathsGenerator.introductionOrder)
        if ma != mb { return ma < mb }
        return rank(a.table, in: ZonePlan.difficultyOrder) < rank(b.table, in: ZonePlan.difficultyOrder)
    }
}
