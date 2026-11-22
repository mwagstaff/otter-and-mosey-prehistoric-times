import Foundation

/// A starting point for the times tables, by school year in England.
public enum YearGroup: String, Codable, CaseIterable, Sendable {
    /// 2, 5 and 10.
    case year2
    /// Focus on 3, 4 and 8; keep 2, 5 and 10 going. The default.
    case year3
    /// Everything from 2 to 12, ready for the Multiplication Tables Check; focus on the new ones.
    case year4
    /// Every table from 1 to 12.
    case all
    /// Tables picked by hand.
    case custom

    public var title: String {
        switch self {
        case .year2: "Year 2"
        case .year3: "Year 3"
        case .year4: "Year 4"
        case .all: "All tables"
        case .custom: "Custom"
        }
    }

    public var tables: [Int] {
        switch self {
        case .year2: [2, 5, 10]
        case .year3, .custom: [2, 3, 4, 5, 8, 10]
        case .year4: Array(2...12)
        case .all: Array(1...12)
        }
    }

    /// The tables to concentrate on. The rest are kept going as review.
    public var focusTables: [Int] {
        switch self {
        case .year2: [2, 5, 10]
        case .year3, .custom: [3, 4, 8]
        case .year4: [6, 7, 9, 11, 12]
        case .all: Array(1...12)
        }
    }
}

/// Whether answers are picked from a few choices or typed on the number pad.
public enum AnswerStyle: String, Codable, CaseIterable, Sendable {
    /// Pick while a fact is new, type once it is getting there. Typing builds memory better.
    case adaptive
    case alwaysPick
    case alwaysType

    public var title: String {
        switch self {
        case .adaptive: "Adaptive (recommended)"
        case .alwaysPick: "Always pick"
        case .alwaysType: "Always type"
        }
    }
}

/// How much a chasing dinosaur presses. Whichever is chosen, a level can never be failed.
public enum ChasePace: String, Codable, CaseIterable, Sendable {
    /// The chaser only gets closer after a wrong answer.
    case calm
    /// The chaser slowly creeps closer, so quick answers help.
    case exciting
    /// No chasers, softer roars and no screen shake.
    case gentle

    public var title: String {
        switch self {
        case .calm: "Calm (recommended)"
        case .exciting: "Exciting"
        case .gentle: "Gentle dinosaurs"
        }
    }
}

/// Parent-controlled limits on what a session may ask.
public struct ParentSettings: Codable, Equatable, Sendable {
    public static let allTables = Array(1...12)
    public static let allMultipliers = Array(1...12)

    public var yearGroup: YearGroup = .year3
    /// The tables switched on.
    public var tables: [Int] = YearGroup.year3.tables
    /// The switched-on tables to concentrate on; the others are review.
    public var focusTables: [Int] = YearGroup.year3.focusTables
    /// The numbers times-table and division questions may multiply or divide by.
    public var multipliers: [Int] = ParentSettings.allMultipliers
    /// The kinds of question that may come up.
    public var questionTypes: [Skill] = Skill.allCases
    public var answerStyle: AnswerStyle = .adaptive
    public var chasePace: ChasePace = .calm
    /// Suggested play time in minutes before a gentle break reminder. 0 means no reminder.
    public var sessionMinutes = 0
    /// Optional speed bonuses. Off by default: nothing in the game requires speed.
    public var timedChallenges = false
    /// How many rounds of each sing-along song, 1 to 3.
    public var songRounds = 3
    /// Each round of a song a little faster than the one before.
    public var songSpeedUp = true
    /// Every level opens with about a minute of its table's song.
    public var levelSongs = true
    /// Times Tables Check practice at Crash Camp: 25 questions, 6 seconds each, like the Year 4 check.
    public var mtcPractice = false

    public init() {}

    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        yearGroup = c.value(.yearGroup, default: .year3)
        tables = c.value(.tables, default: YearGroup.year3.tables)
        focusTables = c.value(.focusTables, default: YearGroup.year3.focusTables)
        multipliers = c.value(.multipliers, default: Self.allMultipliers)
        questionTypes = c.value(.questionTypes, default: Skill.allCases)
        answerStyle = c.value(.answerStyle, default: .adaptive)
        chasePace = c.value(.chasePace, default: .calm)
        sessionMinutes = c.value(.sessionMinutes, default: 0)
        timedChallenges = c.value(.timedChallenges, default: false)
        songRounds = min(max(c.value(.songRounds, default: 3), 1), 3)
        songSpeedUp = c.value(.songSpeedUp, default: true)
        levelSongs = c.value(.levelSongs, default: true)
        mtcPractice = c.value(.mtcPractice, default: false)
    }

    /// Switches to a year group's tables and focus.
    public mutating func apply(_ group: YearGroup) {
        yearGroup = group
        guard group != .custom else { return }
        tables = group.tables
        focusTables = group.focusTables
        // The Year 4 preset is the one that prepares for the Multiplication Tables Check.
        if group == .year4 { mtcPractice = true }
    }

    /// The tables actually in use: never empty, always within 1 to 12, sorted.
    public var usableTables: [Int] {
        let chosen = Set(tables.filter { Self.allTables.contains($0) })
        return chosen.isEmpty ? YearGroup.year3.tables : chosen.sorted()
    }

    /// The multipliers actually in use: never empty, always within 1 to 12, sorted.
    public var usableMultipliers: [Int] {
        let chosen = Set(multipliers.filter { Self.allMultipliers.contains($0) })
        return chosen.isEmpty ? Self.allMultipliers : chosen.sorted()
    }

    /// The focus tables actually in use: switched-on ones only, or every table if none is marked.
    public var usableFocus: [Int] {
        let focus = focusTables.filter(usableTables.contains)
        return focus.isEmpty ? usableTables : focus.sorted()
    }

    /// The question kinds actually in use, never empty.
    public var usableQuestionTypes: [Skill] {
        let chosen = Skill.allCases.filter(questionTypes.contains)
        return chosen.isEmpty ? [.multiplication] : chosen
    }

    /// Switches a table on or off, keeping at least one on. Hand-picking makes the year group custom.
    public mutating func toggle(table: Int) {
        if tables.contains(table) {
            guard tables.count > 1 else { return }
            tables.removeAll { $0 == table }
            focusTables.removeAll { $0 == table }
        } else {
            tables = (tables + [table]).sorted()
        }
        yearGroup = matchingGroup
    }

    /// Marks a switched-on table as focus or review.
    public mutating func toggle(focus table: Int) {
        guard tables.contains(table) else { return }
        if focusTables.contains(table) { focusTables.removeAll { $0 == table } } else { focusTables = (focusTables + [table]).sorted() }
        yearGroup = matchingGroup
    }

    /// The preset these tables and focus match, or custom.
    var matchingGroup: YearGroup {
        YearGroup.allCases.first {
            $0 != .custom && Set($0.tables) == Set(tables) && Set($0.focusTables) == Set(focusTables)
        } ?? .custom
    }
}

/// Shares the chosen tables out across the six zones, easiest first. Zone 1 warms up with the
/// review tables, zones 2 to 4 take the focus tables a few at a time, zone 5 mixes every focus
/// table and zone 6 (the T-Rex) mixes everything.
public enum ZonePlan {
    public static let zoneCount = 6
    /// Roughly how hard each table is to learn, easiest first.
    public static let difficultyOrder = [1, 10, 2, 5, 11, 3, 4, 9, 6, 8, 12, 7]

    public static func ordered(_ tables: [Int]) -> [Int] {
        difficultyOrder.filter(tables.contains)
    }

    /// The focus tables of every zone, in zone order. Always `zoneCount` non-empty lists.
    public static func focus(for settings: ParentSettings) -> [[Int]] {
        let enabled = ordered(settings.usableTables)
        let focus = ordered(settings.usableFocus)
        let review = enabled.filter { !focus.contains($0) }
        var zones: [[Int]] = review.isEmpty ? [] : [review]
        zones += split(focus, into: 4 - zones.count)
        zones.append(focus)
        zones.append(enabled)
        return zones
    }

    /// The focus tables for one zone (0-based). Zones past the last use everything.
    public static func focus(zone: Int, settings: ParentSettings) -> [Int] {
        let zones = focus(for: settings)
        return zones.indices.contains(zone) ? zones[zone] : zones[zones.count - 1]
    }

    /// Ordered groups, one per slot. With fewer tables than slots, each table gets a slot of its
    /// own and the rest mix them all; with more, the later (harder) slots take the extra.
    static func split(_ tables: [Int], into slots: Int) -> [[Int]] {
        guard slots > 0 else { return [] }
        if tables.count <= slots {
            return tables.map { [$0] } + Array(repeating: tables, count: slots - tables.count)
        }
        let base = tables.count / slots, extra = tables.count % slots
        var groups: [[Int]] = [], start = 0
        for slot in 0..<slots {
            let size = base + (slot >= slots - extra ? 1 : 0)
            groups.append(Array(tables[start..<start + size]))
            start += size
        }
        return groups
    }
}
