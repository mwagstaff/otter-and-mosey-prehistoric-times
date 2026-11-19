import Foundation

/// Whether a fact is being multiplied (`7 × 8`, `? × 8 = 56`) or divided (`56 ÷ 8`).
public enum FactKind: String, Codable, CaseIterable, Sendable {
    case multiply = "mul"
    case divide = "div"
}

/// One times-table fact: `multiplier × table`. It belongs to the `table` times table, so
/// 7 × 8 is in the 8s. Keys follow the Lost Islands convention: `mul:8x7`, `div:8x7`.
public struct Fact: Hashable, Comparable, Codable, Sendable, CustomStringConvertible {
    public let table: Int
    public let multiplier: Int

    public init(table: Int, multiplier: Int) {
        self.table = table
        self.multiplier = multiplier
    }

    /// Reads `mul:8x7`, `div:8x7` or `8x7`.
    public init?(key: String) {
        let pair = key.split(separator: ":").last ?? ""
        let numbers = pair.split(separator: "x").compactMap { Int($0) }
        guard numbers.count == 2, numbers[0] > 0, numbers[1] > 0 else { return nil }
        self.init(table: numbers[0], multiplier: numbers[1])
    }

    public var product: Int { table * multiplier }
    public func key(_ kind: FactKind) -> String { "\(kind.rawValue):\(table)x\(multiplier)" }
    public var description: String { "\(multiplier) × \(table)" }

    /// The same fact seen from the other table: 7 × 8 and 8 × 7.
    public var swapped: Fact { Fact(table: multiplier, multiplier: table) }

    public static func < (lhs: Fact, rhs: Fact) -> Bool {
        (lhs.table, lhs.multiplier) < (rhs.table, rhs.multiplier)
    }

    /// The kind and fact behind a spaced-repetition key such as `div:4x9`.
    public static func parse(_ key: String) -> (FactKind, Fact)? {
        guard let prefix = key.split(separator: ":").first, let kind = FactKind(rawValue: String(prefix)),
              let fact = Fact(key: key) else { return nil }
        return (kind, fact)
    }
}

/// How well a child knows one fact, from never seen to instant recall.
public enum FactState: Int, Codable, Comparable, CaseIterable, Sendable {
    /// Not asked yet.
    case new
    /// Seen, and missed (or answered with a hint) last time.
    case learning
    /// Right first time recently, but not yet often enough to count as known.
    case gettingThere
    /// Right first time `FactStats.secureStreak` times in a row, on at least two different days.
    case secure
    /// Secure, and usually typed in under `FactStats.fluentSeconds` seconds.
    case fluent

    public static func < (lhs: FactState, rhs: FactState) -> Bool { lhs.rawValue < rhs.rawValue }

    public var title: String {
        switch self {
        case .new: "Not yet"
        case .learning: "Learning"
        case .gettingThere: "Getting there"
        case .secure: "Secure"
        case .fluent: "Fluent"
        }
    }
}

/// Everything remembered about one fact (multiplying or dividing).
public struct FactStats: Codable, Equatable, Sendable {
    public static let secureStreak = 3
    public static let secureDays = 2
    /// Typed answers quicker than this (in seconds) count towards fluency.
    public static let fluentSeconds = 4.0
    /// How many quick typed answers are needed before fluency is judged.
    public static let fluentSamples = 3
    static let keptTimings = 5

    public var attempts = 0
    public var rightFirstTime = 0
    /// Right first time without a hint, in a row. A slip or a hint starts it again.
    public var cleanStreak = 0
    /// The days (yyyy-MM-dd) that the current clean streak's answers were given on.
    public var streakDays: [String] = []
    /// Seconds taken on recent clean, typed answers, newest last.
    public var typedSeconds: [Double] = []
    /// The best state ever reached. A bone in the Fossil Museum is never taken back.
    public var best: FactState = .new

    public init() {}

    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        attempts = c.value(.attempts, default: 0)
        rightFirstTime = c.value(.rightFirstTime, default: 0)
        cleanStreak = c.value(.cleanStreak, default: 0)
        streakDays = c.value(.streakDays, default: [])
        typedSeconds = c.value(.typedSeconds, default: [])
        best = c.value(.best, default: .new)
    }

    public var state: FactState {
        if attempts == 0 { return .new }
        if cleanStreak == 0 { return .learning }
        guard cleanStreak >= Self.secureStreak, Set(streakDays).count >= Self.secureDays else { return .gettingThere }
        return isQuick ? .fluent : .secure
    }

    /// Usually typed quickly: the middle of the recent typed times is under the fluency line.
    var isQuick: Bool {
        guard typedSeconds.count >= Self.fluentSamples else { return false }
        let sorted = typedSeconds.sorted()
        return sorted[sorted.count / 2] < Self.fluentSeconds
    }

    /// Records a first attempt at this fact.
    public mutating func record(correct: Bool, usedHint: Bool, seconds: Double, typed: Bool, day: String) {
        attempts += 1
        if correct && !usedHint {
            rightFirstTime += 1
            cleanStreak += 1
            if !streakDays.contains(day) { streakDays.append(day) }
            if typed {
                typedSeconds.append(min(max(seconds, 0), 120))
                if typedSeconds.count > Self.keptTimings { typedSeconds.removeFirst(typedSeconds.count - Self.keptTimings) }
            }
        } else {
            cleanStreak = 0
            streakDays = []
        }
        best = max(best, state)
    }
}

/// The Fossil Museum: one dinosaur skeleton per times table, one bone per fact (× 1 to × 12).
/// A bone goes in when its multiplication fact is first secure and turns gold when it is fluent.
/// Worked out from the learner model, so nothing extra is saved.
public enum Fossils {
    public static let bonesPerSkeleton = 12

    public struct Bone: Equatable, Sendable {
        public let fact: Fact
        public let placed: Bool
        public let gold: Bool
    }

    public static func bones(table: Int, learner: LearnerModel) -> [Bone] {
        (1...bonesPerSkeleton).map { multiplier in
            let fact = Fact(table: table, multiplier: multiplier)
            let best = learner.factStats(fact, .multiply).best
            return Bone(fact: fact, placed: best >= .secure, gold: best >= .fluent)
        }
    }

    /// The bones that count towards finishing a skeleton: those the grown-up's multipliers allow.
    public static func needed(table: Int, multipliers: [Int]) -> [Int] {
        let allowed = multipliers.filter { (1...bonesPerSkeleton).contains($0) }
        return allowed.isEmpty ? Array(1...bonesPerSkeleton) : allowed.sorted()
    }

    public static func placed(table: Int, learner: LearnerModel, multipliers: [Int]) -> Int {
        let wanted = Set(needed(table: table, multipliers: multipliers))
        return bones(table: table, learner: learner).filter { wanted.contains($0.fact.multiplier) && $0.placed }.count
    }

    public static func isComplete(table: Int, learner: LearnerModel, multipliers: [Int]) -> Bool {
        placed(table: table, learner: learner, multipliers: multipliers) == needed(table: table, multipliers: multipliers).count
    }
}
