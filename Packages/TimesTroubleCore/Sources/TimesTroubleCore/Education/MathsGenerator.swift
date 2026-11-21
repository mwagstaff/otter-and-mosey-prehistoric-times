import Foundation

/// Builds times-tables questions that always have exactly one right answer.
public enum MathsGenerator {
    public static let defaultTables = YearGroup.year3.tables
    /// The numbers a times-table question can multiply or divide by.
    public static let defaultMultipliers = ParentSettings.allMultipliers
    /// The order a table's facts are introduced in: the easy anchors first, the hardest last.
    public static let introductionOrder = [1, 2, 10, 5, 3, 4, 11, 6, 9, 8, 7, 12]

    /// Whether a spaced-repetition fact ("mul:8x3") fits the grown-up's chosen tables and multipliers.
    /// Anything that isn't a times-table or division fact is always allowed.
    public static func allows(factKey key: String, tables: [Int], multipliers: [Int] = defaultMultipliers) -> Bool {
        guard let (_, fact) = Fact.parse(key) else { return true }
        let tables = tables.isEmpty ? defaultTables : tables
        let multipliers = multipliers.isEmpty ? defaultMultipliers : multipliers
        return tables.contains(fact.table) && multipliers.contains(fact.multiplier)
    }

    /// Every fact the chosen tables and multipliers allow, in `tables`.
    public static func facts(tables: [Int], multipliers: [Int]) -> [Fact] {
        tables.flatMap { table in multipliers.map { Fact(table: table, multiplier: $0) } }
    }

    /// A question about one fact. `learner`, when given, lets the hint lean on facts already known.
    public static func question<R: RandomNumberGenerator>(
        for fact: Fact, skill: Skill, format: AnswerFormat = .choice, level: Int = 3,
        learner: LearnerModel? = nil, using rng: inout R
    ) -> Question {
        let draft: Draft
        switch skill {
        case .multiplication: draft = times(fact, learner: learner)
        case .missingNumber: draft = missingNumber(fact)
        case .division: draft = divide(fact, learner: learner)
        case .wordProblems: draft = wordProblem(fact, using: &rng)
        case .sequences: draft = sequence(table: fact.table, level: level, using: &rng)
        }
        return draft.question(skill: skill, level: level, format: format, using: &rng)
    }

    /// A question of `skill` about a random fact from the chosen tables and multipliers.
    public static func make<R: RandomNumberGenerator>(
        skill: Skill, level: Int, tables: [Int] = defaultTables, multipliers: [Int] = defaultMultipliers,
        format: AnswerFormat = .choice, using rng: inout R
    ) -> Question {
        let pool = facts(tables: tables.isEmpty ? defaultTables : tables, multipliers: multipliers.isEmpty ? defaultMultipliers : multipliers)
        let fact = pool.randomElement(using: &rng)!
        return question(for: fact, skill: skill, format: format, level: min(max(level, 1), 5), using: &rng)
    }

    /// Rebuilds a specific times-table or division fact from its spaced-repetition key.
    public static func make<R: RandomNumberGenerator>(
        factKey key: String, level: Int, format: AnswerFormat = .choice, learner: LearnerModel? = nil, using rng: inout R
    ) -> Question? {
        guard let (kind, fact) = Fact.parse(key) else { return nil }
        return question(for: fact, skill: kind == .divide ? .division : .multiplication, format: format, level: level,
                        learner: learner, using: &rng)
    }

    // MARK: - Draft

    struct Draft {
        var key: String?
        var prompt: String
        var answer: Int
        var near: [Int]
        var hint: String
        var spoken: String?
        var audio: String?

        func question<R: RandomNumberGenerator>(
            skill: Skill, level: Int, format: AnswerFormat, using rng: inout R
        ) -> Question {
            let options = MathsGenerator.choices(answer: answer, near: near, using: &rng)
            return Question(
                key: key ?? "\(skill.rawValue):L\(level)", skill: skill, format: format, prompt: prompt,
                answer: String(answer), choices: options.map(String.init), hint: hint,
                spoken: spoken ?? MathsGenerator.speakable(prompt), level: level,
                audioKey: audio ?? "skill_\(skill.rawValue)"
            )
        }
    }

    /// Three distinct, positive options containing the answer. The wrong ones come from the
    /// front of `near` (the likeliest mistakes), shuffled a little so they aren't predictable.
    static func choices<R: RandomNumberGenerator>(answer: Int, near: [Int], using rng: inout R) -> [Int] {
        var pool: [Int] = []
        for candidate in near where candidate > 0 && candidate != answer && !pool.contains(candidate) { pool.append(candidate) }
        var offset = 1
        while pool.count < 2 {
            for candidate in [answer + offset, answer - offset] where candidate > 0 && candidate != answer && !pool.contains(candidate) {
                pool.append(candidate)
            }
            offset += 1
        }
        let likely = Array(pool.prefix(5)).shuffled(using: &rng)
        return ([answer] + likely.prefix(2)).shuffled(using: &rng)
    }

    static func speakable(_ prompt: String) -> String {
        prompt
            .replacingOccurrences(of: "×", with: " times ")
            .replacingOccurrences(of: "÷", with: " divided by ")
            .replacingOccurrences(of: "= ?", with: "")
            .replacingOccurrences(of: "?", with: " what ")
    }

    /// The narrator clip for a times-table fact. Every fact from 1 × 1 to 12 × 12 is recorded.
    static func recordedFact(_ kind: String, _ table: Int, _ other: Int) -> String? {
        (1...12).contains(table) && (1...12).contains(other) ? "\(kind)_\(table)x\(other)" : nil
    }

    /// The digits the other way round (24 for 42), when that is a different two-digit number.
    static func digitsSwapped(_ value: Int) -> Int? {
        guard (10...99).contains(value), value % 10 != 0 else { return nil }
        let swapped = (value % 10) * 10 + value / 10
        return swapped == value ? nil : swapped
    }

    // MARK: - Question kinds

    static func times(_ fact: Fact, learner: LearnerModel?) -> Draft {
        let (table, other, answer) = (fact.table, fact.multiplier, fact.product)
        // Likeliest slips first: a neighbouring multiple, the other table's neighbour, adding
        // instead of multiplying, the digits swapped, one out.
        let near = [answer + table, answer - table, answer + other, answer - other, table + other,
                    digitsSwapped(answer) ?? 0, answer + 1, answer - 1, answer + 10]
        return Draft(key: fact.key(.multiply), prompt: "\(other) × \(table) = ?", answer: answer, near: near,
                     hint: Hints.multiply(fact, learner: learner), audio: recordedFact("mul", table, other))
    }

    static func missingNumber(_ fact: Fact) -> Draft {
        let (table, other, product) = (fact.table, fact.multiplier, fact.product)
        return Draft(key: fact.key(.multiply), prompt: "? × \(table) = \(product)", answer: other,
                     near: [other + 1, other - 1, table, other + 2, other - 2],
                     hint: Hints.missingNumber(fact),
                     spoken: "What times \(table) makes \(product)?", audio: recordedFact("mulq", table, other))
    }

    static func divide(_ fact: Fact, learner: LearnerModel?) -> Draft {
        let (table, quotient, dividend) = (fact.table, fact.multiplier, fact.product)
        return Draft(key: fact.key(.divide), prompt: "\(dividend) ÷ \(table) = ?", answer: quotient,
                     near: [quotient + 1, quotient - 1, table, quotient + 2, quotient * 2, quotient - 2],
                     hint: Hints.divide(fact, learner: learner), audio: recordedFact("div", table, quotient))
    }

    /// Counting in multiples of `table`, with one term missing. The gap is never the first or
    /// second term, so the hint ("they go up by 4") can never give the answer away.
    static func sequence<R: RandomNumberGenerator>(table step: Int, level: Int, using rng: inout R) -> Draft {
        let backwards = level >= 5 && Bool.random(using: &rng)
        let start = step * Int.random(in: (backwards ? 2...6 : 0...6), using: &rng)
        var terms = (0..<5).map { start + step * $0 }
        if backwards { terms.reverse() }
        let hole = level <= 2 ? 4 : Int.random(in: 2...4, using: &rng)
        let answer = terms[hole]
        let shown = terms.enumerated().map { $0.offset == hole ? "?" : String($0.element) }.joined(separator: ", ")
        return Draft(key: "seq:\(step)", prompt: shown, answer: answer,
                     near: [answer + step, answer - step, answer + 1, answer - 1, answer + 2, answer + 10],
                     hint: "The numbers \(backwards ? "go down" : "go up") by \(step) each time.",
                     spoken: "Which number is missing from the pattern?")
    }

    /// A short dinosaur number story: `multiplier` groups of `table`.
    static func wordProblem<R: RandomNumberGenerator>(_ fact: Fact, using rng: inout R) -> Draft {
        let (groups, each, answer) = (fact.multiplier, fact.table, fact.product)
        func count(_ n: Int, _ one: String, _ many: String) -> String { "\(n) \(n == 1 ? one : many)" }
        let stories = [
            "Mama Maia has \(count(groups, "nest", "nests")) with \(count(each, "egg", "eggs")) in each. How many eggs altogether?",
            "\(count(groups, "baby dinosaur finds", "baby dinosaurs each find")) \(count(each, "shiny pebble", "shiny pebbles")). How many pebbles altogether?",
            "Otter fills \(count(groups, "bag", "bags")) with \(count(each, "fern", "ferns")) in each. How many ferns is that?",
            "\(count(groups, "pteranodon catches", "pteranodons each catch")) \(each) fish. How many fish altogether?",
            "Each footprint trail has \(count(each, "footprint", "footprints")). How many footprints are on \(count(groups, "trail", "trails"))?",
        ]
        return Draft(key: fact.key(.multiply), prompt: stories.randomElement(using: &rng)!, answer: answer,
                     near: [answer + each, answer - each, groups + each, answer + groups, answer - groups, answer + 1],
                     hint: Hints.story(fact), spoken: nil, audio: "skill_wordProblems")
    }
}

/// Hints show a way to work the answer out, never the answer itself.
public enum Hints {
    static let timesOne = "Anything times one stays just the same."

    /// For `multiplier × table = ?`.
    public static func multiply(_ fact: Fact, learner: LearnerModel? = nil) -> String {
        let (t, m) = (fact.table, fact.multiplier)
        if t == 1 || m == 1 { return timesOne }
        // The swap: 7 × 8 is the same as 8 × 7, which may already be known.
        if t != m, let learner, learner.factStats(fact.swapped, .multiply).state >= .secure {
            return "You already know \(t) × \(m). Swap them round: it's the same answer!"
        }
        if m == 10 { return "10 lots of \(t): put a 0 on the end of \(t)." }
        if m == 2 { return "2 lots of \(t) is double \(t)." }
        return strategy(table: t, times: m)
    }

    /// The usual way to work out `m` lots of `t`, by table.
    static func strategy(table t: Int, times m: Int) -> String {
        switch t {
        case 2: "Times 2 means double. Double \(m)."
        case 3: "Double \(m) is \(2 * m). Now add one more \(m)."
        case 4: "Times 4 is double, then double again. Double \(m) is \(2 * m)."
        case 5: "Count in 5s, one finger for each jump, until you have \(m) fingers up."
        case 6: "5 × \(m) is \(5 * m). Now add one more \(m)."
        case 7: "5 × \(m) is \(5 * m) and 2 × \(m) is \(2 * m). Add them together."
        case 8: "Double, double, double: \(m) → \(2 * m) → \(4 * m) → ?"
        case 9: "10 × \(m) is \(10 * m). Now take away one \(m)."
        case 10: "Times 10 moves the digits of \(m) one place to the left, with a 0 on the end."
        case 11: m <= 9 ? "Write \(m) twice, side by side." : "10 × \(m) is \(10 * m). Now add one more \(m)."
        case 12: "10 × \(m) is \(10 * m) and 2 × \(m) is \(2 * m). Add them together."
        default: "Make \(m) jumps of \(t) on a number line."
        }
    }

    /// For `? × table = product`.
    public static func missingNumber(_ fact: Fact) -> String {
        if fact.table == 1 { return timesOne }
        if fact.table == fact.multiplier { return square(fact) }
        return "Count in \(fact.table)s until you reach \(fact.product). How many jumps?"
    }

    /// For 144 ÷ 12 or ? × 12 = 144, where naming the table would name the answer.
    static func square(_ fact: Fact) -> String {
        "\(fact.product) is a square number. Which number times itself makes \(fact.product)?"
    }

    /// For `product ÷ table = ?`.
    public static func divide(_ fact: Fact, learner: LearnerModel? = nil) -> String {
        let (t, p) = (fact.table, fact.product)
        if t == 1 { return "Dividing by one leaves a number just the same." }
        if t == fact.multiplier { return square(fact) }
        if let learner, learner.factStats(fact, .multiply).state >= .secure {
            return "Think: ? × \(t) = \(p). You know this one!"
        }
        return "How many \(t)s make \(p)? Count up in \(t)s and count your jumps."
    }

    /// For a number story about `multiplier` groups of `table`.
    public static func story(_ fact: Fact) -> String {
        fact.table == 1 || fact.multiplier == 1 ? timesOne
            : "\(fact.multiplier) lots of \(fact.table) is \(fact.multiplier) × \(fact.table)."
    }
}
