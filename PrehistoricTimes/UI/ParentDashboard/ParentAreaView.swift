import PrehistoricTimesCore
import SwiftUI

/// The grown-ups' area. Kept behind a gate and styled plainly so it reads as separate from play.
struct ParentAreaView: View {
    @Environment(AppModel.self) private var model

    var body: some View {
        ZStack {
            Color(red: 0.95, green: 0.96, blue: 0.97).ignoresSafeArea()
            if model.parentUnlocked {
                ParentDashboardView()
            } else {
                ParentGateView(onPass: { model.parentUnlocked = true }, onCancel: { model.leaveParentArea() })
            }
        }
    }
}

/// The grown-ups' gate. A child practising times tables could work out a two-digit × one-digit
/// sum, so the gate asks a three-digit subtraction with exchanging, well beyond Year 3 or 4 mental
/// maths, and then wants the Continue button held down for a moment, which small children rarely
/// do by accident.
struct ParentGateView: View {
    /// A line above the sum saying what the gate leads to, such as which player is being set up.
    var context: String?
    var onPass: () -> Void
    var onCancel: () -> Void
    @State private var sum = GateSum()
    @State private var entry = ""
    @State private var wrong = false
    /// How far the press-and-hold has got, from 0 to 1.
    @State private var hold: CGFloat = 0
    @State private var holding = false
    static let holdSeconds = 1.5

    var body: some View {
        VStack(spacing: 14) {
            if let context {
                Text(context)
                    .font(.system(size: 15, design: .rounded))
                    .foregroundStyle(.secondary)
                    .padding(.horizontal, 14).padding(.vertical, 6)
                    .background(Capsule().fill(.white).stroke(Color(white: 0.85)))
            }
            Text("Grown-ups only").font(.system(size: 30, weight: .bold, design: .rounded))
            Text("To continue, please answer, then press and hold Continue:").font(.system(size: 18, design: .rounded)).foregroundStyle(.secondary)
            Text("\(sum.a) − \(sum.b) = \(entry.isEmpty ? "?" : entry)").font(.system(size: 38, weight: .heavy, design: .rounded)).monospacedDigit()
            if wrong { Text("That's not right. Here's a new one.").font(.system(size: 15, design: .rounded)).foregroundStyle(.red) }
            HStack(spacing: 8) {
                ForEach(Array("1234567890"), id: \.self) { digit in
                    Button(String(digit)) { if entry.count < 3 { entry.append(digit) } }
                }
                Button { if !entry.isEmpty { entry.removeLast() } } label: { Image(systemName: "delete.left") }
                    .accessibilityLabel("Delete")
            }
            .buttonStyle(ParentKeyStyle())
            HStack(spacing: 16) {
                Button("Back", action: onCancel).buttonStyle(.bordered)
                continueButton
            }
            .controlSize(.large)
        }
        .padding(30)
    }

    /// Fills up while it is held; lets go early and it empties again.
    private var continueButton: some View {
        Text(holding ? "Keep holding…" : "Hold to continue")
            .font(.system(size: 17, weight: .semibold, design: .rounded))
            .foregroundStyle(.white)
            .padding(.horizontal, 20).frame(height: 50)
            .background {
                GeometryReader { box in
                    ZStack(alignment: .leading) {
                        Capsule().fill(Color.accentColor.opacity(entry.isEmpty ? 0.35 : 0.75))
                        Capsule().fill(Color.accentColor).frame(width: box.size.width * hold)
                    }
                }
            }
            .clipShape(Capsule())
            .opacity(entry.isEmpty ? 0.6 : 1)
            .onLongPressGesture(minimumDuration: Self.holdSeconds, maximumDistance: 40) {
                holding = false
                check()
            } onPressingChanged: { pressing in
                guard !entry.isEmpty else { return }
                holding = pressing
                withAnimation(pressing ? .linear(duration: Self.holdSeconds) : .easeOut(duration: 0.2)) { hold = pressing ? 1 : 0 }
            }
            .accessibilityElement()
            .accessibilityLabel("Continue")
            .accessibilityHint("Press and hold")
            .accessibilityAddTraits(.isButton)
            .accessibilityAction { check() }
            .accessibilityIdentifier("gate-continue")
            .disabled(entry.isEmpty)
    }

    private func check() {
        hold = 0
        guard !entry.isEmpty else { return }
        if Int(entry) == sum.answer {
            onPass()
        } else {
            wrong = true
            entry = ""
            sum = GateSum()
        }
    }
}

/// A three-digit subtraction that needs exchanging in the ones: 623 − 278.
struct GateSum: Equatable {
    let a: Int
    let b: Int
    var answer: Int { a - b }

    init() {
        var a = 0, b = 0
        repeat {
            a = Int.random(in: 412...968)
            b = Int.random(in: 127...(a - 105))
        } while a % 10 >= b % 10 || b % 100 == 0
        self.a = a
        self.b = b
    }
}

private struct ParentKeyStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 22, weight: .bold, design: .rounded))
            .foregroundStyle(configuration.isPressed ? Color(uiColor: .systemBackground) : .primary)
            .frame(width: 48, height: 48)
            .background {
                RoundedRectangle(cornerRadius: 10)
                    .fill(configuration.isPressed ? Color.primary : Color(uiColor: .secondarySystemGroupedBackground))
                    .shadow(radius: 1)
            }
            .contentShape(Rectangle())
            .animation(configuration.isPressed ? nil : .easeOut(duration: 0.15), value: configuration.isPressed)
    }
}

struct ParentDashboardView: View {
    @Environment(AppModel.self) private var model
    @State private var confirmReset = false
    @State private var keepRewards = true
    @State private var confirmDelete = false

    private var profile: Profile? {
        model.save.profiles.first { $0.id == model.dashboardProfileID }
            ?? model.save.profiles.first { $0.id == model.save.activeProfileID }
            ?? model.save.profiles.first
    }

    var body: some View {
        NavigationStack {
            Group {
                if let profile {
                    List {
                        if model.save.profiles.count > 1 {
                            Picker("Child", selection: Binding(get: { profile.id }, set: { model.dashboardProfileID = $0 })) {
                                ForEach(model.save.profiles) { Text("\($0.avatar) \($0.nickname)").tag($0.id) }
                            }
                        }
                        learning(profile)
                        overview(profile)
                        TimesTablesReport(profile: profile)
                        skills(profile)
                        practice(profile)
                        achievements(profile)
                        playtest(profile)
                        ending(profile)
                        Section("Sound and accessibility") {
                            SettingsControls(compact: true).listRowInsets(EdgeInsets(top: 8, leading: 12, bottom: 8, trailing: 12))
                        }
                        Section {
                            Toggle("Keep trophies and treasures", isOn: $keepRewards)
                            Button("Restart \(profile.nickname)'s adventure", role: .destructive) { confirmReset = true }
                            Button("Delete \(profile.nickname)", role: .destructive) { confirmDelete = true }
                        } header: {
                            Text("Player")
                        } footer: {
                            Text("Restarting returns to the opening story and clears levels, stars, machine parts, playtime and learning history. Keep trophies and treasures to save achievements, accessories and home decorations. The player and settings are always kept. Deleting removes the player completely. Everything is stored on this device only. The game has no accounts, adverts or purchases and collects no personal information.")
                        }
                    }
                } else {
                    List {
                        ContentUnavailableView("No players yet", systemImage: "person.crop.circle.badge.plus", description: Text("Create a player from the title screen to see their progress here."))
                        playtest(nil)
                        Section("Sound and accessibility") {
                            SettingsControls(compact: true)
                        }
                    }
                }
            }
            .navigationTitle("Parent dashboard")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) { Button("Done") { model.leaveParentArea() } }
            }
            .confirmationDialog("Restart \(profile?.nickname ?? "this child")'s adventure?", isPresented: $confirmReset, titleVisibility: .visible) {
                Button("Restart adventure", role: .destructive) { if let profile { model.resetProgress(profile.id, keepRewards: keepRewards) } }
                Button("Keep progress", role: .cancel) {}
            } message: {
                Text("The story, levels, stars, machine parts, playtime and learning history will start again. " + (keepRewards
                    ? "Trophies, achievements, treasures, accessories and Crash Camp decorations will be kept. "
                    : "Trophies, achievements, treasures, accessories and Crash Camp decorations will also be cleared. ")
                     + "The player and settings will be kept. This can't be undone.")
            }
            .alert("Delete \(profile?.nickname ?? "this player")?", isPresented: $confirmDelete, presenting: profile) { doomed in
                Button("Delete", role: .destructive) {
                    model.deleteProfile(doomed.id)
                    model.dashboardProfileID = nil
                }
                Button("Cancel", role: .cancel) {}
            } message: { doomed in
                Text("\(doomed.nickname) and all their progress will be removed from this device. This can't be undone.")
            }
        }
        .environment(\.colorScheme, .light)
    }

    private func percent(_ value: Double?) -> String { value.map { "\(Int(($0 * 100).rounded()))%" } ?? "No data yet" }

    /// "1 hour, 5 minutes", "12 minutes" or "0 minutes".
    private func duration(_ seconds: Double) -> String {
        let minutes = Int(seconds / 60)
        let hours = minutes / 60
        func plural(_ count: Int, _ unit: String) -> String { "\(count) \(unit)\(count == 1 ? "" : "s")" }
        return hours > 0 ? "\(plural(hours, "hour")), \(plural(minutes % 60, "minute"))" : plural(minutes, "minute")
    }

    private func overview(_ profile: Profile) -> some View {
        Section {
            LabeledContent("Playtime today", value: duration(profile.playSeconds(overLast: 1)))
            LabeledContent("Playtime, last 7 days", value: duration(profile.playSeconds(overLast: 7)))
            LabeledContent("Total playtime", value: duration(profile.playSeconds))
            LabeledContent("Stars and machine parts", value: "\(profile.totalStars) stars, \(profile.crystals.count) of 6 parts")
            LabeledContent("Maths accuracy", value: percent(profile.learner.accuracy(for: .maths)))
        } header: {
            Text("Overview")
        }
    }

    private func skills(_ profile: Profile) -> some View {
        Section("Skills practised") {
            if profile.learner.practisedSkills.isEmpty { Text("Nothing practised yet.").foregroundStyle(.secondary) }
            ForEach(profile.learner.practisedSkills, id: \.self) { skill in
                let stats = profile.learner.stats(for: skill)
                VStack(alignment: .leading, spacing: 4) {
                    HStack {
                        Text(skill.title).font(.headline)
                        Spacer()
                        Text("Level \(profile.learner.level(for: skill)) of 5 · \(stats.correct)/\(stats.attempts) right first time")
                            .font(.subheadline).foregroundStyle(.secondary)
                    }
                    ProgressView(value: stats.accuracy).tint(stats.accuracy >= 0.8 ? .green : stats.accuracy >= 0.6 ? .orange : .red)
                    Text("Average answer time \(stats.averageSeconds.formatted(.number.precision(.fractionLength(1)))) s").font(.caption).foregroundStyle(.secondary)
                }
                .padding(.vertical, 2)
            }
        }
    }

    private func practice(_ profile: Profile) -> some View {
        Section("Areas needing practice") {
            let weak = profile.learner.skillsNeedingPractice
            let tricky = profile.learner.troublesomeItems.prefix(12)
            let slow = LearningReport.slowest(profile.learner)
            if weak.isEmpty, tricky.isEmpty, slow.isEmpty { Text("Nothing stands out yet. The game brings back anything missed automatically.").foregroundStyle(.secondary) }
            ForEach(weak, id: \.self) { Label($0.title, systemImage: "arrow.up.right.circle") }
            if !tricky.isEmpty {
                LabeledContent("Trickiest facts (missed more than once)") {
                    Text(tricky.map { LearningReport.describe($0.key) }.joined(separator: ", ")).multilineTextAlignment(.trailing)
                }
            }
            if !slow.isEmpty {
                LabeledContent("Slowest facts (typed right, but slowly)") {
                    Text(slow.map { "\(LearningReport.describe($0.key)) (\($0.seconds.formatted(.number.precision(.fractionLength(0)))) s)" }.joined(separator: ", "))
                        .multilineTextAlignment(.trailing)
                }
            }
        }
    }

    private func achievements(_ profile: Profile) -> some View {
        Section("Recent trophies") {
            let count = Trophies.count(in: profile, catalog: model.catalog)
            LabeledContent("Trophy cabinet", value: "\(count.won) of \(count.total)")
            let recent = profile.achievements.sorted { $0.value > $1.value }.compactMap { entry in
                Trophies.trophy(entry.key, catalog: model.catalog).map { ($0, entry.value) }
            }.prefix(5)
            if recent.isEmpty { Text("None yet.").foregroundStyle(.secondary) }
            ForEach(Array(recent), id: \.0.id) { trophy, date in
                LabeledContent(trophy.levelID.flatMap { model.catalog.level($0) }.map { "\(trophy.title): \($0.title)" } ?? trophy.title,
                               value: date.formatted(date: .abbreviated, time: .omitted))
            }
        }
    }

    /// Any level, locked or not, for a grown-up to try. Nothing played here is saved.
    private func playtest(_ profile: Profile?) -> some View {
        Section {
            ForEach(model.catalog.islands) { island in
                DisclosureGroup(island.name) {
                    ForEach(island.levels) { level in
                        Button { model.startPlaytest(levelID: level.id, as: profile?.id) } label: {
                            HStack {
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(level.title).foregroundStyle(.primary)
                                    Text("\(level.mode.title) · \(level.count) questions · " + level.skills.map(\.title).joined(separator: ", "))
                                        .font(.caption).foregroundStyle(.secondary)
                                }
                                Spacer()
                                if let profile, profile.stars(for: level.id) > 0 {
                                    Text(String(repeating: "★", count: profile.stars(for: level.id))).foregroundStyle(.orange)
                                }
                                Image(systemName: "play.circle.fill").font(.title2).foregroundStyle(.teal)
                            }
                            .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel("Play-test \(level.title)")
                    }
                }
            }
        } header: {
            Text("Play-test a level")
        } footer: {
            Text((profile.map { "Opens any level, even a locked one, with \($0.nickname)'s learning settings and current skill levels, so you see the questions they would get. " }
                  ?? "Opens any level, even a locked one, as a new player would see it. ")
                 + "Nothing is saved: no stars, treasures, playtime or learning progress.")
        }
    }

    /// Replays the finale for this child, for anyone who missed a bit of it.
    private func ending(_ profile: Profile) -> some View {
        Section {
            Button { model.watchEnding(for: profile.id) } label: {
                HStack {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Watch the ending").foregroundStyle(.primary)
                        Text("Nothing is saved or changed.").font(.caption).foregroundStyle(.secondary)
                    }
                    Spacer()
                    Image(systemName: "play.circle.fill").font(.title2).foregroundStyle(.teal)
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Watch the ending with \(profile.nickname)")
        } header: {
            Text("The ending")
        } footer: {
            Text(profile.crystals.count == model.catalog.islands.count
                 ? "Plays the end-of-game celebration again, with \(profile.nickname)'s name and totals. Watch it as often as you like."
                 : "\(profile.nickname) hasn't won back all six Times Machine parts yet, so this will show how the story ends before they get there.")
        }
    }

    private func learning(_ profile: Profile) -> some View {
        Section {
            MathsSettingsRows(profile: profile)
            PlaySettingsRows(profile: profile)
        } header: {
            Text("Learning settings")
        } footer: {
            Text(learningHelp)
        }
    }
}

let learningHelp = "Year groups set up the tables in one tap; changing a table makes them custom. Starred focus tables come up most and the other switched-on tables keep coming back for review. \"Multiply and divide by\" picks the other number: switch off × 11 and × 12 to keep things gentler. Adaptive answers let a child pick from three while a fact is new and type it once it's getting there, because typing an answer from memory builds recall. Chases (in the dinosaur levels): calm dinosaurs only get closer after a wrong answer, and no level can ever be failed. Timed bonus points only add extra score for quick answers; nothing in the adventure ever runs out of time. Times Tables Check practice adds a button at Crash Camp for 25 questions with 6 seconds each, like the Year 4 Multiplication Tables Check; scores appear in the report below. The Raptor Race (60 seconds against your own best) opens after Raptor Ridge."

/// Saves a change to one player's learning settings straight away.
private func parentBinding(_ profile: Profile, _ model: AppModel) -> Binding<ParentSettings> {
    Binding(get: { profile.parent }, set: { value in model.updateProfile(profile.id) { $0.parent = value } })
}

/// The list with `value` switched on or off, kept sorted. At least one value always stays on.
private func toggled(_ value: Int, in values: [Int]) -> [Int] {
    let next = values.contains(value) ? values.filter { $0 != value } : (values + [value]).sorted()
    return next.isEmpty ? values : next
}

/// Year group, times tables, focus, multipliers, question kinds, answers and chases, as rows of a list section.
struct MathsSettingsRows: View {
    @Environment(AppModel.self) private var model
    let profile: Profile

    @ScaledMetric(relativeTo: .body) private var numberColumnWidth: CGFloat = 64
    @ScaledMetric(relativeTo: .body) private var starredColumnWidth: CGFloat = 100

    private func columns(minimum: CGFloat) -> [GridItem] {
        [GridItem(.adaptive(minimum: minimum), alignment: .leading)]
    }

    var body: some View {
        let parent = parentBinding(profile, model)
        let settings = profile.parent
        Picker("Year group", selection: Binding(get: { settings.yearGroup }, set: { group in
            var changed = settings
            changed.apply(group)
            parent.wrappedValue = changed
        })) {
            ForEach(YearGroup.allCases.filter { $0 != .custom || settings.yearGroup == .custom }, id: \.self) { Text($0.title).tag($0) }
        }
        VStack(alignment: .leading) {
            Text("Times tables")
            LazyVGrid(columns: columns(minimum: numberColumnWidth), alignment: .leading) {
                ForEach(ParentSettings.allTables, id: \.self) { table in
                    let on = settings.tables.contains(table)
                    Button("\(table)×") {
                        var changed = settings
                        changed.toggle(table: table)
                        parent.wrappedValue = changed
                    }
                    .buttonStyle(.bordered)
                    .tint(on ? .teal : .gray)
                    .accessibilityValue(on ? "On" : "Off")
                }
            }
        }
        VStack(alignment: .leading) {
            Text("Focus on")
            LazyVGrid(columns: columns(minimum: starredColumnWidth), alignment: .leading) {
                ForEach(settings.usableTables, id: \.self) { table in
                    let focus = settings.focusTables.contains(table)
                    Button {
                        var changed = settings
                        changed.toggle(focus: table)
                        parent.wrappedValue = changed
                    } label: {
                        Label("\(table)×", systemImage: focus ? "star.fill" : "star")
                    }
                    .buttonStyle(.bordered)
                    .tint(focus ? .orange : .gray)
                    .accessibilityValue(focus ? "Focus" : "Review")
                }
            }
        }
        VStack(alignment: .leading) {
            Text("Multiply and divide by")
            LazyVGrid(columns: columns(minimum: numberColumnWidth), alignment: .leading) {
                ForEach(ParentSettings.allMultipliers, id: \.self) { value in
                    let on = settings.multipliers.contains(value)
                    Button("× \(value)") {
                        parent.wrappedValue.multipliers = toggled(value, in: settings.multipliers)
                    }
                    .buttonStyle(.bordered)
                    .tint(on ? .teal : .gray)
                    .accessibilityValue(on ? "On" : "Off")
                }
            }
        }
        VStack(alignment: .leading) {
            Text("Question types")
            ForEach(Skill.allCases, id: \.self) { skill in
                Toggle(skill.title, isOn: Binding(get: { settings.questionTypes.contains(skill) }, set: { isOn in
                    var kinds = settings.questionTypes.filter { $0 != skill }
                    if isOn { kinds.append(skill) }
                    // At least one kind always stays on.
                    if !kinds.isEmpty { parent.wrappedValue.questionTypes = Skill.allCases.filter(kinds.contains) }
                }))
            }
        }
        Picker("Answers", selection: parent.answerStyle) {
            ForEach(AnswerStyle.allCases, id: \.self) { Text($0.title).tag($0) }
        }
        Picker("Chases", selection: parent.chasePace) {
            ForEach(ChasePace.allCases, id: \.self) { Text($0.title).tag($0) }
        }
    }
}

/// Break reminders and timed bonus points.
struct PlaySettingsRows: View {
    @Environment(AppModel.self) private var model
    let profile: Profile

    var body: some View {
        let parent = parentBinding(profile, model)
        Picker("Suggest a break after", selection: parent.sessionMinutes) {
            Text("Never").tag(0)
            ForEach([10, 15, 20, 30, 45], id: \.self) { Text("\($0) minutes").tag($0) }
        }
        Toggle("Timed bonus points", isOn: parent.timedChallenges)
        Toggle("Times Tables Check practice (Year 4)", isOn: parent.mtcPractice)
        Picker("Sing-along rounds", selection: parent.songRounds) {
            Text("1 (sing together)").tag(1)
            Text("2 (and finish the line)").tag(2)
            Text("3 (and sing it all)").tag(3)
        }
        Toggle("Sing-along gets faster each round", isOn: parent.songSpeedUp)
        Toggle("A times-table song before every level", isOn: parent.levelSongs)
    }
}

/// The times-tables report: every fact from 1 × 1 to 12 × 12 coloured by how well it is known,
/// then each switched-on table, and the quick-fire scores.
struct TimesTablesReport: View {
    let profile: Profile

    static func colour(_ state: FactState) -> Color {
        switch state {
        case .new: Color(white: 0.9)
        case .learning: Color(red: 0.98, green: 0.62, blue: 0.55)
        case .gettingThere: Color(red: 1.0, green: 0.84, blue: 0.4)
        case .secure: Color(red: 0.55, green: 0.82, blue: 0.6)
        case .fluent: Color(red: 0.16, green: 0.6, blue: 0.42)
        }
    }

    var body: some View {
        let settings = profile.parent
        let grid = LearningReport.grid(profile.learner)
        Section {
            VStack(alignment: .leading, spacing: 8) {
                Text("Each square is one multiplication fact: the row is the times table, the column what it is multiplied by.")
                    .font(.caption).foregroundStyle(.secondary)
                FactGrid(grid: grid, tables: settings.usableTables, multipliers: settings.usableMultipliers)
                HStack(spacing: 12) {
                    ForEach(FactState.allCases, id: \.self) { state in
                        HStack(spacing: 4) {
                            RoundedRectangle(cornerRadius: 3).fill(Self.colour(state)).frame(width: 14, height: 14)
                            Text(state.title).font(.caption)
                        }
                    }
                }
                .accessibilityElement(children: .combine)
            }
            .padding(.vertical, 4)
            ForEach(ZonePlan.ordered(settings.usableTables), id: \.self) { table in
                let report = LearningReport.table(table, learner: profile.learner, multipliers: settings.usableMultipliers)
                LabeledContent("\(table) times table\(settings.usableFocus.contains(table) ? " ★" : "")") {
                    Text([
                        "\(report.secure) of \(report.facts) secure",
                        report.accuracy.map { "\(Int(($0 * 100).rounded()))% right first time" },
                        report.typicalSeconds.map { "\($0.formatted(.number.precision(.fractionLength(1)))) s typical" },
                    ].compactMap { $0 }.joined(separator: " · "))
                    .multilineTextAlignment(.trailing)
                }
            }
            quickFire
        } header: {
            Text("Times tables report")
        } footer: {
            Text("Secure: right first time three times in a row, on at least two different days. Fluent: secure, and usually typed in under 4 seconds. Bones in the Fossil Museum follow the same rules, and are never taken away.")
        }
    }

    @ViewBuilder private var quickFire: some View {
        let checks = profile.quickFireScores(.mtc)
        let races = profile.quickFireScores(.raptorRace)
        if checks.isEmpty {
            LabeledContent("Times Tables Check practice", value: profile.parent.mtcPractice ? "Not tried yet" : "Switched off")
        } else {
            LabeledContent("Times Tables Check practice") {
                Text("Best \(profile.bestQuickFire(.mtc)) of 25 · " + checks.suffix(6).reversed()
                    .map { "\($0.score) (\($0.date.formatted(.dateTime.day().month(.abbreviated))))" }.joined(separator: ", "))
                    .multilineTextAlignment(.trailing)
            }
        }
        if !races.isEmpty {
            LabeledContent("Raptor Race", value: "Best \(profile.bestQuickFire(.raptorRace)) in 60 s · \(races.count) races")
        }
    }
}

/// The 12 × 12 grid of facts. Tables or multipliers that are switched off are faded.
struct FactGrid: View {
    let grid: [[FactState]]
    let tables: [Int]
    let multipliers: [Int]

    var body: some View {
        Grid(horizontalSpacing: 3, verticalSpacing: 3) {
            GridRow {
                Text("×").font(.caption.bold()).foregroundStyle(.secondary)
                ForEach(1...12, id: \.self) { Text("\($0)").font(.caption2.bold()).foregroundStyle(.secondary).frame(maxWidth: .infinity) }
            }
            ForEach(1...12, id: \.self) { table in
                GridRow {
                    Text("\(table)").font(.caption2.bold()).foregroundStyle(.secondary)
                    ForEach(1...12, id: \.self) { multiplier in
                        let state = grid[table - 1][multiplier - 1]
                        let on = tables.contains(table) && multipliers.contains(multiplier)
                        RoundedRectangle(cornerRadius: 3)
                            .fill(TimesTablesReport.colour(state))
                            .opacity(on ? 1 : 0.3)
                            .frame(maxWidth: .infinity, minHeight: 16, maxHeight: 22)
                            .accessibilityLabel("\(multiplier) times \(table): \(state.title)")
                    }
                }
            }
        }
        .frame(maxWidth: 520)
    }
}
