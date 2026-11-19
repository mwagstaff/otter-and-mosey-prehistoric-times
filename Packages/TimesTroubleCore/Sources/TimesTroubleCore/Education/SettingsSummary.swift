import Foundation

/// One line of the grown-ups' settings in plain words, for the check before a new player's first adventure.
public struct SettingsLine: Equatable, Sendable {
    public let label: String
    public let value: String
    /// True when it differs from what a new player starts with.
    public let changed: Bool
}

extension ParentSettings {
    /// The learning settings in plain words, in the order the quick setup shows them. "×" and its
    /// number are joined by a non-breaking space so a narrow screen never splits them.
    public var summary: [SettingsLine] {
        let fresh = ParentSettings()
        let tables = usableTables, focus = usableFocus, multipliers = usableMultipliers, types = usableQuestionTypes
        let review = tables.filter { !focus.contains($0) }
        return [
            SettingsLine(label: "Year group", value: yearGroup.title, changed: yearGroup != fresh.yearGroup),
            SettingsLine(label: "Times tables", value: SettingsWording.listed(tables.map(String.init)),
                         changed: tables != fresh.usableTables),
            SettingsLine(label: "Focus on",
                         value: review.isEmpty ? "All of them" : SettingsWording.listed(focus.map { "×\u{00A0}\($0)" }),
                         changed: focus != fresh.usableFocus),
            SettingsLine(label: "Multiply and divide by",
                         value: SettingsWording.describe(multipliers, of: ParentSettings.allMultipliers,
                                                         name: { "×\u{00A0}\($0)" }, everything: "Everything from ×\u{00A0}1 to ×\u{00A0}12",
                                                         range: { "×\u{00A0}\($0) to ×\u{00A0}\($1)" }),
                         changed: multipliers != fresh.usableMultipliers),
            SettingsLine(label: "Question types",
                         value: SettingsWording.describe(types, of: Skill.allCases, name: { $0.title.lowercased() },
                                                         everything: "All \(Skill.allCases.count) kinds"),
                         changed: types != fresh.usableQuestionTypes),
            SettingsLine(label: "Answers",
                         value: answerStyle.title.replacingOccurrences(of: #"\s*\(.*\)$"#, with: "", options: .regularExpression),
                         changed: answerStyle != fresh.answerStyle),
            SettingsLine(label: "Chases",
                         value: chasePace.title.replacingOccurrences(of: #"\s*\(.*\)$"#, with: "", options: .regularExpression),
                         changed: chasePace != fresh.chasePace),
        ]
    }
}

enum SettingsWording {
    /// "a", "a and b", "a, b and c".
    static func listed(_ items: [String], last: String = "and") -> String {
        guard items.count > 1 else { return items.first ?? "" }
        return items.dropLast().joined(separator: ", ") + " \(last) " + items[items.count - 1]
    }

    static func capitalised(_ text: String) -> String { text.prefix(1).uppercased() + text.dropFirst() }

    /// The chosen items in as few words as possible: everything, "Only …", a range, a range or
    /// "All but" with one or two gaps, or else a plain list.
    static func describe<T: Equatable>(_ chosen: [T], of all: [T], name: (T) -> String, everything: String,
                                       range: ((T, T) -> String)? = nil) -> String {
        let picked = all.filter(chosen.contains)
        guard picked.count != all.count else { return everything }
        guard let first = picked.first, let last = picked.last else { return "None" }
        if picked.count == 1 { return "Only \(name(first))" }
        let span: [T]
        if range != nil, let start = all.firstIndex(of: first), let end = all.firstIndex(of: last) {
            span = Array(all[start...end])
        } else {
            span = all
        }
        let missing = span.filter { !picked.contains($0) }
        if let range, missing.isEmpty { return capitalised(range(first, last)) }
        if missing.count <= 2 {
            let gaps = missing.map(name)
            if span.count == all.count { return "All but \(listed(gaps))" }
            if let range { return capitalised("\(range(first, last)), but not \(listed(gaps, last: "or"))") }
        }
        return capitalised(listed(picked.map(name)))
    }
}
