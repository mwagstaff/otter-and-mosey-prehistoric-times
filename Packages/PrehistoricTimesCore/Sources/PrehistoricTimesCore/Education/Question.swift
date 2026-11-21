import Foundation

/// How a question expects to be answered.
public enum AnswerFormat: String, Codable, Sendable {
    /// Pick one of `choices` (tap, drag, swim through).
    case choice
    /// Type `typingTarget` on the number pad.
    case typed
}

/// One educational challenge, independent of how any game mode presents it.
public struct Question: Identifiable, Equatable, Sendable {
    public let id: UUID
    /// Stable key for spaced repetition, e.g. `mul:7x8` or `div:7x8`.
    public let key: String
    public let skill: Skill
    public let format: AnswerFormat
    /// What to show: `7 × 8 = ?`.
    public let prompt: String
    /// The canonical full answer (`56`).
    public let answer: String
    /// For `.choice`: shuffled options including the right one.
    public let choices: [String]
    /// The right entry in `choices`.
    public let correctChoice: String
    /// For `.typed`: exactly the characters the child must type, in order.
    public let typingTarget: String
    /// A gentle nudge shown on request or after repeated slips.
    public let hint: String
    /// What the narrator should say aloud.
    public let spoken: String
    public let level: Int
    /// The pre-recorded narrator clip that reads this question, if one exists (see narration.json).
    public let audioKey: String?

    public init(
        id: UUID = UUID(), key: String, skill: Skill, format: AnswerFormat, prompt: String,
        answer: String, choices: [String] = [], correctChoice: String? = nil,
        typingTarget: String? = nil, hint: String, spoken: String? = nil, level: Int,
        audioKey: String? = nil
    ) {
        self.id = id
        self.key = key
        self.skill = skill
        self.format = format
        self.prompt = prompt
        self.answer = answer
        self.choices = choices
        self.correctChoice = correctChoice ?? answer
        self.typingTarget = typingTarget ?? answer
        self.hint = hint
        self.spoken = spoken ?? prompt
        self.level = level
        self.audioKey = audioKey
    }

    public func isCorrect(choice: String) -> Bool { choice == correctChoice }

    /// Lenient comparison for typed input: case and surrounding spaces never count against a child.
    public func isCorrect(typed: String) -> Bool {
        Question.normalise(typed) == Question.normalise(typingTarget)
    }

    public static func normalise(_ text: String) -> String {
        text.trimmingCharacters(in: .whitespacesAndNewlines)
            .lowercased()
            .replacingOccurrences(of: "’", with: "'")
    }
}
