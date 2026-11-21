import Foundation

/// The broad subject a skill belongs to. Used for dashboards and accuracy totals.
public enum Subject: String, Codable, CaseIterable, Sendable {
    case maths

    public var title: String { "Maths" }
}

/// A kind of times-tables question. Raw values are stable: they are used as save-data keys.
public enum Skill: String, Codable, CaseIterable, Sendable {
    /// `7 × 8 = ?`
    case multiplication
    /// `? × 8 = 56`
    case missingNumber
    /// `56 ÷ 8 = ?`
    case division
    /// Counting in multiples: `8, 16, 24, ?, 40`
    case sequences
    /// A short dinosaur number story built on one fact.
    case wordProblems

    public var subject: Subject { .maths }

    public var title: String {
        switch self {
        case .multiplication: "Times tables"
        case .missingNumber: "Missing numbers"
        case .division: "Division"
        case .sequences: "Counting in multiples"
        case .wordProblems: "Word problems"
        }
    }

    /// Which kind of fact a question of this kind gives evidence for, if any.
    public var factKind: FactKind? {
        switch self {
        case .multiplication, .missingNumber, .wordProblems: .multiply
        case .division: .divide
        case .sequences: nil
        }
    }

    public static var mathsTopics: [Skill] { allCases }
}

/// How the child is entering answers. On-screen layouts adapt to this.
public enum InputProfile: String, Codable, Sendable {
    /// iPhone-sized touch keys.
    case compactTouch
    /// iPad-sized touch keys.
    case fullTouch
    /// Hardware keyboard attached.
    case hardware
}

/// Deterministic generator so question generation can be tested and replayed.
public struct SeededGenerator: RandomNumberGenerator, Sendable {
    private var state: UInt64

    public init(seed: UInt64) { state = seed &+ 0x9E37_79B9_7F4A_7C15 }

    public mutating func next() -> UInt64 {
        state &+= 0x9E37_79B9_7F4A_7C15
        var z = state
        z = (z ^ (z >> 30)) &* 0xBF58_476D_1CE4_E5B9
        z = (z ^ (z >> 27)) &* 0x94D0_49BB_1331_11EB
        return z ^ (z >> 31)
    }
}
