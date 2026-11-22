import SwiftUI
import PrehistoricTimesCore

/// One calm Fix-It Workshop puzzle, built from a times-table fact: `rows` rows of `table` bolts.
struct WorkshopPuzzle: Equatable {
    enum Kind: Equatable {
        /// Fill an array of bolts a row at a time, counting up in the table, then say how many.
        case array
        /// The other side of the same fact: share the bolts back out.
        case family
    }

    let kind: Kind
    let question: Question
    let table: Int
    let rows: Int
    var total: Int { table * rows }

    /// Two arrays from the zone's focus tables (small enough to fill by hand), then a division
    /// that undoes the second one.
    static func make(tables: [Int]) -> [WorkshopPuzzle] {
        var rng = SystemRandomNumberGenerator()
        let tables = tables.isEmpty ? [2] : tables
        var puzzles: [WorkshopPuzzle] = []
        for _ in 0..<2 {
            let fact = Fact(table: tables.randomElement(using: &rng)!, multiplier: Int.random(in: 2...4, using: &rng))
            puzzles.append(WorkshopPuzzle(kind: .array, question: MathsGenerator.question(for: fact, skill: .multiplication, using: &rng),
                                          table: fact.table, rows: fact.multiplier))
        }
        let last = puzzles[1]
        let fact = Fact(table: last.table, multiplier: last.rows)
        puzzles.append(WorkshopPuzzle(kind: .family, question: MathsGenerator.question(for: fact, skill: .division, using: &rng),
                                      table: fact.table, rows: fact.multiplier))
        return puzzles
    }
}

/// The Fix-It Workshop at Crash Camp. After each Big Escape, Otter fits the part back on the Times
/// Machine. Three calm puzzles with no clock and no stars, then the part clicks into place and the
/// next zone opens.
struct WorkshopView: View {
    let island: Island
    @Environment(AppModel.self) private var model
    @State private var stage = Stage.intro
    @State private var puzzles: [WorkshopPuzzle] = []
    @State private var index = 0
    @State private var rowsFilled = 0
    @State private var ruledOut: Set<String> = []
    @State private var solved = false
    @State private var fitted = false

    enum Stage { case intro, puzzles, done, fitted }

    private var puzzle: WorkshopPuzzle? { puzzles.indices.contains(index) ? puzzles[index] : nil }
    private var talking: Bool { stage == .intro || stage == .done }
    private var zone: Int { model.catalog.islands.firstIndex { $0.id == island.id } ?? 0 }
    /// True once every part is back: fitting this one completes the Times Machine.
    private var lastPart: Bool { (model.profile?.crystals.count ?? 0) >= model.catalog.islands.count }

    var body: some View {
        GeometryReader { geometry in
            let compact = geometry.size.height < 480
            ZStack {
                HStack(alignment: .bottom, spacing: 0) {
                    Image("otter_fix").resizable().scaledToFit().frame(height: geometry.size.height * (compact ? 0.42 : 0.36))
                    Spacer()
                    Image("mosey_think").resizable().scaledToFit().frame(height: geometry.size.height * (compact ? 0.3 : 0.26))
                }
                .padding(.horizontal, compact ? 8 : 30)
                // Otter and Mosey step up above the speech panel while one of them is talking.
                .padding(.bottom, talking ? DialogueView.reservedHeight(compact: compact) : (compact ? 6 : 24))
                .frame(maxHeight: .infinity, alignment: .bottom)
                .animation(model.settings.reducedMotion ? nil : .spring(duration: 0.4), value: talking)
                .accessibilityHidden(true)

                VStack(spacing: compact ? 6 : 14) {
                    header(compact: compact)
                    Spacer(minLength: 0)
                    switch stage {
                    case .intro, .done:
                        machine(compact: compact)
                    case .puzzles:
                        if let puzzle {
                            board(puzzle, size: geometry.size, compact: compact)
                                #if DEBUG
                                .task(id: index) {
                                    guard AppModel.debugAutoAnswer else { return }
                                    do { try await Task.sleep(for: .milliseconds(350)) } catch { return }
                                    guard !solved else { return }
                                    rowsFilled = puzzle.rows
                                    choose(puzzle.question.correctChoice, in: puzzle)
                                }
                                #endif
                        }
                    case .fitted:
                        machine(compact: compact)
                        if lastPart {
                            Button(action: tapped { model.route = .ending }) { IconLabel("Time to go home!", emoji: "🌈", size: compact ? 20 : 26) }
                                .buttonStyle(ChunkyButtonStyle(fill: Palette.teal, ink: .white, size: compact ? 20 : 26))
                        } else {
                            Button(action: tapped(leave)) { IconLabel("Back to Crash Camp", symbol: "map.fill", size: compact ? 20 : 26, trailing: true) }
                                .buttonStyle(ChunkyButtonStyle(fill: Palette.teal, ink: .white, size: compact ? 20 : 26))
                        }
                    }
                    Spacer(minLength: 0)
                }
                .padding(compact ? 8 : 24)

                if stage == .intro, let lines = model.catalog.workshop?.intro {
                    DialogueView(lines: lines) { start() }
                }
                if stage == .done, let lines = model.catalog.workshop?.done {
                    DialogueView(lines: lines) { fit() }
                }
            }
            .screenBackground("bg_camp")
            .environment(\.uiScale, ScreenMetrics.scale(geometry))
            .environment(\.compact, compact)
        }
        .onAppear {
            if puzzles.isEmpty { puzzles = WorkshopPuzzle.make(tables: ZonePlan.focus(zone: zone, settings: model.profile?.parent ?? ParentSettings())) }
        }
    }

    // MARK: - Pieces

    private func header(compact: Bool) -> some View {
        HStack {
            RoundButton(symbol: "map.fill", label: "Crash Camp map") { leave() }
            Spacer()
            VStack(spacing: 0) {
                Text("Fix-It Workshop").font(.game(compact ? 22 : 34)).foregroundStyle(Palette.ink)
                Text(stage == .puzzles ? "Puzzle \(index + 1) of \(puzzles.count)" : "Fitting the \(island.partName)")
                    .font(.game(compact ? 13 : 18, weight: .bold)).foregroundStyle(Palette.ink.opacity(0.7))
            }
            .padding(.horizontal, 22).padding(.vertical, 6).panel(radius: 20)
            Spacer()
            Image("part_\(island.part)").resizable().scaledToFit().frame(width: compact ? 44 : 70, height: compact ? 44 : 70)
                .accessibilityLabel(island.partName)
        }
    }

    /// The Times Machine, with the part flying into place once every puzzle is done.
    private func machine(compact: Bool) -> some View {
        ZStack {
            Image(fitted && lastPart ? "machine_whole" : "machine_wrecked").resizable().scaledToFit().frame(height: compact ? 150 : 300)
                .animation(.easeInOut(duration: 0.6).delay(0.7), value: fitted)
            Image("part_\(island.part)").resizable().scaledToFit()
                .opacity(fitted && lastPart ? 0 : 1)
                .frame(width: compact ? 56 : 110, height: compact ? 56 : 110)
                .offset(x: fitted ? 0 : (compact ? 160 : 320), y: fitted ? 0 : (compact ? -80 : -160))
                .scaleEffect(fitted ? 1 : 1.3)
                .animation(model.settings.reducedMotion ? nil : .spring(duration: 0.7, bounce: 0.4), value: fitted)
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(fitted ? "The \(island.partName) is back on the Times Machine" : "The Times Machine")
    }

    /// The bolt board: tap to add a row at a time (counting up in the table), then answer.
    private func board(_ puzzle: WorkshopPuzzle, size: CGSize, compact: Bool) -> some View {
        let full = rowsFilled >= puzzle.rows || puzzle.kind == .family
        let cell = min(size.width * 0.5 / CGFloat(puzzle.table), size.height * (compact ? 0.24 : 0.3) / CGFloat(puzzle.rows), compact ? 30 : 46)
        return VStack(spacing: compact ? 6 : 12) {
            Text(instruction(puzzle, full: full))
                .font(.game(compact ? 18 : 28, weight: .bold)).foregroundStyle(Palette.ink)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 18).padding(.vertical, 8).panel(radius: 18)
            Button(action: tapped { addRow(puzzle) }) {
                VStack(spacing: cell * 0.15) {
                    ForEach(0..<puzzle.rows, id: \.self) { row in
                        HStack(spacing: cell * 0.15) {
                            ForEach(0..<puzzle.table, id: \.self) { _ in
                                if row < rowsFilled || puzzle.kind == .family {
                                    Image("bolt").resizable().scaledToFit().frame(width: cell, height: cell)
                                } else {
                                    Circle().strokeBorder(Palette.ink.opacity(0.45), style: StrokeStyle(lineWidth: 2, dash: [4, 3]))
                                        .frame(width: cell * 0.8, height: cell * 0.8).frame(width: cell, height: cell)
                                }
                            }
                        }
                    }
                }
                .padding(cell * 0.4)
                .panel(fill: Palette.cream.opacity(0.92), radius: 16)
            }
            .buttonStyle(.plain)
            .disabled(full)
            .accessibilityLabel(full ? "\(puzzle.total) bolts" : "Add a row of \(puzzle.table) bolts. \(rowsFilled * puzzle.table) so far")
            if full { answers(puzzle, compact: compact) }
        }
    }

    private func instruction(_ puzzle: WorkshopPuzzle, full: Bool) -> String {
        #if DEBUG
        if AppModel.debugAnswers, !solved, full || puzzle.kind == .family {
            return "Answer: " + puzzle.question.correctChoice
        }
        #endif
        switch puzzle.kind {
        case .array:
            if !full {
                let counted = (1...max(rowsFilled, 1)).map { String($0 * puzzle.table) }.joined(separator: "… ")
                return rowsFilled == 0 ? "Tap to add \(puzzle.rows) rows of \(puzzle.table) bolts" : "\(counted)… keep going!"
            }
            return solved ? "\(puzzle.rows) × \(puzzle.table) = \(puzzle.total). Perfect fit!" : "\(puzzle.rows) rows of \(puzzle.table). How many bolts?"
        case .family:
            return solved ? "\(puzzle.total) ÷ \(puzzle.table) = \(puzzle.rows). Perfect fit!"
                : "\(puzzle.rows) × \(puzzle.table) = \(puzzle.total). So \(puzzle.question.prompt)"
        }
    }

    private func answers(_ puzzle: WorkshopPuzzle, compact: Bool) -> some View {
        HStack(spacing: compact ? 12 : 20) {
            ForEach(puzzle.question.choices, id: \.self) { choice in
                Button(action: tapped { choose(choice, in: puzzle) }) { Text(choice).frame(minWidth: compact ? 64 : 96) }
                    .buttonStyle(ChunkyButtonStyle(fill: Palette.cream, size: compact ? 24 : 34))
                    .opacity(ruledOut.contains(choice) ? 0.35 : 1)
                    .disabled(ruledOut.contains(choice) || solved)
            }
        }
    }

    // MARK: - Actions

    private func start() {
        stage = .puzzles
        speak()
    }

    private func speak() {
        guard let puzzle, model.settings.spokenInstructions, puzzle.kind == .family || rowsFilled >= puzzle.rows else { return }
        Narrator.shared.say(key: puzzle.question.audioKey, fallback: puzzle.question.spoken)
    }

    private func addRow(_ puzzle: WorkshopPuzzle) {
        guard rowsFilled < puzzle.rows else { return }
        rowsFilled += 1
        AudioManager.shared.play(.ratchet, volume: 0.8)
        Haptics.shared.tap()
        if rowsFilled == puzzle.rows { speak() }
    }

    private func choose(_ choice: String, in puzzle: WorkshopPuzzle) {
        guard !solved else { return }
        if puzzle.question.isCorrect(choice: choice) {
            solved = true
            AudioManager.shared.play(.correct)
            Haptics.shared.success()
            Task { @MainActor in
                try? await Task.sleep(for: .seconds(1.6))
                next()
            }
        } else {
            ruledOut.insert(choice)
            AudioManager.shared.play(.wrong, volume: 0.5)
        }
    }

    private func next() {
        solved = false
        ruledOut = []
        rowsFilled = 0
        if index + 1 < puzzles.count {
            index += 1
            speak()
        } else {
            stage = .done
        }
    }

    private func fit() {
        stage = .fitted
        model.fixedPart(island.id)
        AudioManager.shared.play(.ratchet)
        AudioManager.shared.play(.crystal)
        Haptics.shared.crescendo()
        fitted = true
    }

    /// Back to the map, where the next zone (if it is ready) is shown off.
    private func leave() {
        if let index = model.catalog.islands.firstIndex(where: { $0.id == island.id }), index + 1 < model.catalog.islands.count,
           model.catalog.islands[index + 1].ready {
            model.unlockedIsland = model.catalog.islands[index + 1].id
        }
        model.route = .map
    }
}
