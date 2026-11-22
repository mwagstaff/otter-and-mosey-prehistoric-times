import Combine
import PrehistoricTimesCore
import SwiftUI

/// The two optional quick-fire games, both typed on the number pad.
///
/// **Raptor Race:** sixty seconds against your own best score. The Snatch Pack runs alongside;
/// every right answer pulls Otter and Mosey further ahead. A slip shows the answer for a moment.
///
/// **Times Tables Check:** practice for the Year 4 check. 25 questions, 6 seconds each and a
/// 3-second pause between, no feedback until the end, exactly like the real thing. The score is
/// kept for the grown-ups' report.
struct QuickFireView: View {
    let kind: QuickFireKind
    @Environment(AppModel.self) private var model

    private enum Stage: Equatable { case intro, countdown(Int), asking, pause, done }
    private enum Flash: Equatable { case right, wrong(String) }

    @State private var stage = Stage.intro
    @State private var round: QuickFireRound?
    @State private var entry = ""
    @State private var flash: Flash?
    @State private var now = Date()
    /// When the race ends, or when the current check question runs out.
    @State private var deadline = Date()
    @State private var asked = Date()
    @State private var won: [Trophy] = []
    @State private var previousBest = 0
    @State private var hardware = InputDetector.hasHardwareKeyboard
    private let clock = Timer.publish(every: 0.05, on: .main, in: .common).autoconnect()

    private var reducedMotion: Bool { model.settings.reducedMotion }

    var body: some View {
        GeometryReader { geometry in
            let compact = ScreenMetrics.isCompact(geometry)
            ZStack {
                VStack(spacing: compact ? 6 : 14) {
                    header(compact: compact)
                    Spacer(minLength: 0)
                    switch stage {
                    case .intro: intro(compact: compact)
                    case .countdown(let count):
                        Text(count > 0 ? "\(count)" : "Go!")
                            .font(.game(compact ? 90 : 150, weight: .black)).foregroundStyle(.white)
                            .shadow(color: .black.opacity(0.4), radius: 6, y: 3)
                            .id(count)
                            .transition(.scale.combined(with: .opacity))
                    case .asking, .pause: question(compact: compact)
                    case .done: results(compact: compact)
                    }
                    Spacer(minLength: 0)
                    if stage == .asking, !hardware {
                        GameKeyboard(kind: .numbers, width: geometry.size.width - 16, onKey: key, onBackspace: backspace)
                    }
                }
                .padding(.horizontal, compact ? 8 : 24)
                .padding(.top, compact ? 6 : 16)
                HardwareKeys(onKey: key, onBackspace: backspace)
                    .frame(width: 1, height: 1).opacity(0.01).allowsHitTesting(false)
            }
            .screenBackground(kind == .raptorRace ? "bg_ridge" : "bg_camp", blur: 4, dim: 0.25)
            .environment(\.compact, compact)
        }
        .animation(reducedMotion ? nil : .spring(duration: 0.3), value: stage)
        .animation(.easeOut(duration: 0.15), value: flash)
        .onReceive(clock) { tick($0) }
        .onAppear { previousBest = model.profile?.bestQuickFire(kind) ?? 0 }
    }

    // MARK: - Pieces

    private func header(compact: Bool) -> some View {
        HStack(spacing: 12) {
            RoundButton(symbol: "chevron.left", label: "Back to the map") { leave() }
            Spacer()
            Text(kind.title).font(.game(compact ? 24 : 38)).foregroundStyle(Palette.ink)
                .padding(.horizontal, 22).padding(.vertical, 6).panel(radius: 20)
            Spacer()
            if let round, stage == .asking || stage == .pause {
                CountChip(emoji: kind == .raptorRace ? "🦖" : "⭐️",
                          text: kind == .raptorRace ? "\(round.right)" : "\(min(round.asked, QuickFireRound.mtcQuestions)) of \(QuickFireRound.mtcQuestions)")
                    .fixedSize()
            } else {
                CountChip(emoji: "🏅", text: "Best \(model.profile?.bestQuickFire(kind) ?? 0)").fixedSize()
            }
        }
    }

    private func intro(compact: Bool) -> some View {
        VStack(spacing: compact ? 8 : 16) {
            HStack(spacing: compact ? 12 : 24) {
                Image(kind == .raptorRace ? "boss_raptors_chase" : "otter_think").resizable().scaledToFit()
                    .frame(height: compact ? 110 : 200)
                    .accessibilityHidden(true)
                VStack(alignment: .leading, spacing: compact ? 4 : 10) {
                    Text(kind == .raptorRace ? "How many can you get right in 60 seconds?" : "Practise for the Times Tables Check")
                        .font(.game(compact ? 20 : 30)).foregroundStyle(Palette.ink)
                    Text(kind == .raptorRace
                         ? "The Snatch Pack wants a race! Type each answer on the number pad. Try to beat your best score. It's just for fun, so there's no rush to play it."
                         : "25 times-tables questions, with 6 seconds for each one, like the real check in Year 4. Don't worry if time runs out: just get ready for the next one.")
                        .font(.game(compact ? 14 : 19, weight: .bold)).foregroundStyle(Palette.ink.opacity(0.75))
                        .fixedSize(horizontal: false, vertical: true)
                    if let best = model.profile?.bestQuickFire(kind), best > 0 {
                        Text(kind == .raptorRace ? "Your best: \(best) right" : "Your best: \(best) out of 25")
                            .font(.game(compact ? 15 : 20)).foregroundStyle(Palette.coral)
                    }
                }
            }
            Button(action: tapped(start)) { IconLabel("Ready, steady…", symbol: "flag.checkered", size: compact ? 22 : 30, trailing: true) }
                .buttonStyle(ChunkyButtonStyle(fill: Palette.teal, ink: .white, size: compact ? 22 : 30))
                .accessibilityIdentifier("quickfire-start")
        }
        .padding(compact ? 14 : 28)
        .frame(maxWidth: 860)
        .panel()
    }

    @ViewBuilder private func question(compact: Bool) -> some View {
        VStack(spacing: compact ? 8 : 16) {
            if kind == .raptorRace { raceTrack(compact: compact) }
            timer(compact: compact)
            HStack(spacing: 14) {
                if stage == .pause {
                    Text(kind == .mtc ? "Get ready…" : "")
                        .font(.game(compact ? 34 : 56)).foregroundStyle(Palette.ink.opacity(0.6))
                } else if let current = round?.current {
                    Text(current.prompt).font(.game(compact ? 44 : 76, weight: .black)).foregroundStyle(Palette.ink).monospacedDigit()
                    Text(entry.isEmpty ? "?" : entry)
                        .font(.game(compact ? 44 : 76, weight: .black)).monospacedDigit()
                        .foregroundStyle(entry.isEmpty ? Palette.ink.opacity(0.3) : Palette.teal)
                        .frame(minWidth: compact ? 90 : 150)
                        .padding(.horizontal, 10)
                        .background(RoundedRectangle(cornerRadius: 16).fill(.white).overlay(RoundedRectangle(cornerRadius: 16).strokeBorder(Palette.ink, lineWidth: 3)))
                }
            }
            .accessibilityElement(children: .combine)
            .frame(minHeight: compact ? 70 : 110)
            .padding(.horizontal, 30).padding(.vertical, compact ? 6 : 14)
            .panel(fill: flashColour)
            if case .wrong(let answer) = flash {
                Text(answer).font(.game(compact ? 20 : 28)).foregroundStyle(.white)
                    .padding(.horizontal, 16).padding(.vertical, 4)
                    .background(Capsule().fill(Palette.coral))
                    .transition(.scale.combined(with: .opacity))
            }
        }
    }

    private var flashColour: Color {
        switch flash {
        case .right: Color(hex: 0xC9F2D9)
        case .wrong: Color(hex: 0xFFD9D3)
        case nil: Palette.cream
        }
    }

    /// The race: Otter and Mosey ahead, the pack behind, and a flag at your best score.
    private func raceTrack(compact: Bool) -> some View {
        let right = round?.right ?? 0
        let goal = max(previousBest + 5, 20)
        return GeometryReader { box in
            let width = box.size.width
            let lead = min(CGFloat(right) / CGFloat(goal), 1)
            let heroX = width * (0.22 + 0.7 * lead)
            ZStack(alignment: .bottomLeading) {
                Capsule().fill(Color(hex: 0xE8C48A)).frame(height: 10).offset(y: -6)
                if previousBest > 0 {
                    VStack(spacing: 0) {
                        Text("Best \(previousBest)").font(.game(compact ? 11 : 14)).foregroundStyle(Palette.ink)
                        Glyph("🏁", size: compact ? 22 : 30)
                    }
                    .offset(x: width * (0.22 + 0.7 * min(CGFloat(previousBest) / CGFloat(goal), 1)) - 15, y: -12)
                }
                Image("boss_raptors_chase").resizable().scaledToFit().scaleEffect(x: -1)
                    .frame(height: compact ? 50 : 80)
                    .offset(x: max(heroX - width * 0.24, 0) - (compact ? 40 : 60))
                // Painted heading right, away from the pack.
                Image("duo_ride").resizable().scaledToFit()
                    .frame(height: compact ? 54 : 90)
                    .offset(x: heroX - (compact ? 30 : 50))
            }
            .animation(reducedMotion ? nil : .spring(duration: 0.4), value: right)
        }
        .frame(height: compact ? 64 : 104)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(right) right so far")
    }

    private func timer(compact: Bool) -> some View {
        let total = kind == .raptorRace ? QuickFireRound.raceSeconds : QuickFireRound.mtcSeconds
        let left = stage == .pause ? total : max(deadline.timeIntervalSince(now), 0)
        return HStack(spacing: 10) {
            Image(systemName: "timer").font(.system(size: compact ? 18 : 24, weight: .heavy)).foregroundStyle(Palette.ink)
            GeometryReader { box in
                ZStack(alignment: .leading) {
                    Capsule().fill(.white.opacity(0.7))
                    Capsule().fill(left < total * 0.2 ? Palette.coral : Palette.teal)
                        .frame(width: box.size.width * CGFloat(left / total))
                }
                .overlay(Capsule().strokeBorder(Palette.ink, lineWidth: 2.5))
            }
            .frame(height: compact ? 14 : 20)
            Text("\(Int(left.rounded(.up)))s").font(.game(compact ? 16 : 22)).foregroundStyle(Palette.ink).monospacedDigit()
                .frame(width: compact ? 40 : 56)
        }
        .padding(.horizontal, 14).padding(.vertical, 6)
        .panel(radius: 16)
        .frame(maxWidth: 700)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(Int(left.rounded(.up))) seconds left")
    }

    private func results(compact: Bool) -> some View {
        let score = round?.right ?? 0
        let isBest = score > previousBest
        let missed = round?.answers.filter { !$0.right }.map(\.question) ?? []
        return VStack(spacing: compact ? 6 : 14) {
            Text(kind == .raptorRace ? (isBest ? "New best score!" : "Great racing!") : (score == 25 ? "25 out of 25!" : "Check complete!"))
                .font(.game(compact ? 28 : 44)).foregroundStyle(Palette.ink).gameTracking()
            Text(kind == .raptorRace ? "\(score) right in 60 seconds" : "\(score) out of \(QuickFireRound.mtcQuestions) right")
                .font(.game(compact ? 20 : 30)).foregroundStyle(Palette.teal)
            if kind == .raptorRace, previousBest > 0, !isBest {
                Text("Your best is \(previousBest). Have another go?").font(.game(compact ? 14 : 18, weight: .bold)).foregroundStyle(Palette.ink.opacity(0.7))
            }
            if !missed.isEmpty {
                VStack(spacing: 4) {
                    Text("Ones to practise").font(.game(compact ? 13 : 17, weight: .bold)).foregroundStyle(Palette.ink.opacity(0.7))
                    Text(missed.prefix(8).map { "\($0.prompt) \($0.answer)" }.joined(separator: "   "))
                        .font(.game(compact ? 14 : 19)).foregroundStyle(Palette.ink).multilineTextAlignment(.center)
                }
            }
            if !won.isEmpty {
                HStack(spacing: 20) {
                    ForEach(won) { trophy in
                        VStack(spacing: 2) {
                            TrophyBadge(trophy: trophy, size: compact ? 48 : 80)
                            Text(trophy.title).font(.game(compact ? 12 : 16)).foregroundStyle(Palette.ink)
                        }
                    }
                }
                Text("New trophies, already in your cabinet!").font(.game(compact ? 12 : 15, weight: .bold)).foregroundStyle(Palette.coral)
            }
            HStack(spacing: 14) {
                Button(action: tapped(start)) { IconLabel("Play again", symbol: "arrow.counterclockwise", size: compact ? 18 : 24) }
                    .buttonStyle(ChunkyButtonStyle(fill: Palette.teal, ink: .white, size: compact ? 18 : 24))
                Button(action: tapped(leave)) { IconLabel("Back to the map", symbol: "map.fill", size: compact ? 18 : 24) }
                    .buttonStyle(ChunkyButtonStyle(fill: Palette.cream, size: compact ? 18 : 24))
            }
        }
        .padding(compact ? 14 : 28)
        .frame(maxWidth: 860)
        .panel()
        .onAppear {
            AudioManager.shared.play(isBest || score == 25 ? .victory : .levelComplete)
            if isBest && kind == .raptorRace { AudioManager.shared.play(.roarRaptors, volume: 0.6) }
        }
    }

    // MARK: - Flow

    private func start() {
        guard let profile = model.profile else { return }
        previousBest = profile.bestQuickFire(kind)
        round = QuickFireRound(kind: kind, settings: profile.parent, learner: profile.learner)
        won = []
        entry = ""
        flash = nil
        Task { @MainActor in
            for count in [3, 2, 1, 0] {
                stage = .countdown(count)
                AudioManager.shared.play(count == 0 ? .whoosh : .key)
                try? await Task.sleep(for: .seconds(count == 0 ? 0.5 : 0.8))
            }
            if kind == .raptorRace {
                deadline = Date().addingTimeInterval(QuickFireRound.raceSeconds)
                AudioManager.shared.play(.roarRaptors, volume: 0.5)
            }
            ask()
        }
    }

    private func ask() {
        guard var current = round, current.next() != nil else { return finish() }
        round = current
        entry = ""
        asked = Date()
        if kind == .mtc { deadline = asked.addingTimeInterval(QuickFireRound.mtcSeconds) }
        stage = .asking
    }

    private func tick(_ date: Date) {
        now = date
        guard stage == .asking || stage == .pause else { return }
        guard date >= deadline else { return }
        switch kind {
        case .raptorRace:
            // Time's up: the question on screen doesn't count against you.
            finish()
        case .mtc:
            guard stage == .asking else { return }
            answer(nil)
        }
    }

    private func key(_ character: Character) {
        guard stage == .asking, flash == nil, character.isNumber, let target = round?.current?.answer else { return }
        let length = String(target).count
        guard entry.count < length else { return }
        entry.append(character)
        AudioManager.shared.play(.key, volume: 0.5)
        if entry.count == length { answer(Int(entry)) }
    }

    private func backspace() {
        guard stage == .asking, !entry.isEmpty else { return }
        entry.removeLast()
    }

    private func answer(_ value: Int?) {
        guard var current = round, let question = current.current else { return }
        let correct = current.answer(value, seconds: Date().timeIntervalSince(asked))
        round = current
        switch kind {
        case .raptorRace:
            if correct {
                flash = .right
                AudioManager.shared.play(.correct, volume: 0.7)
                Haptics.shared.tap()
                after(0.25) { flash = nil; ask() }
            } else {
                flash = .wrong("\(question.prompt) \(question.answer)")
                AudioManager.shared.play(.wrong, volume: 0.5)
                after(1.1) { flash = nil; ask() }
            }
        case .mtc:
            // Like the real check: no right or wrong until the end, then a short pause.
            AudioManager.shared.play(.key, volume: 0.3)
            stage = .pause
            after(QuickFireRound.mtcPause) {
                if round?.asked ?? 0 >= QuickFireRound.mtcQuestions { finish() } else { ask() }
            }
        }
    }

    private func finish() {
        guard stage != .done, let round else { return }
        stage = .done
        entry = ""
        flash = nil
        won = model.finishQuickFire(round)
    }

    private func after(_ seconds: Double, _ action: @escaping @MainActor () -> Void) {
        Task { @MainActor in
            try? await Task.sleep(for: .seconds(seconds))
            guard stage == .asking || stage == .pause else { return }
            action()
        }
    }

    private func leave() {
        if let round, stage == .asking || stage == .pause, round.answers.count > 0 {
            // Leaving mid-race still keeps what was learnt, but not a score.
            model.updateLearner(round.learner)
        }
        model.route = .map
    }
}
