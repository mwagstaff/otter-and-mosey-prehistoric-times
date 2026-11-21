import SwiftUI
import PrehistoricTimesCore

/// The Campfire Sing-Along (docs/PLAN.md, section 14). Otter and Mosey chant a times table over a
/// beat, three rounds that leave more for the child to sing each time; then the child fills in the
/// table on the number pad ("Fill the ladder"), and can try the same table mixed up.
struct SingAlongView: View {
    let table: Int
    /// Set when the song opens a level: one piece of the song (about a minute), then on to the level.
    var level: String? = nil
    @Environment(AppModel.self) private var model
    @State private var player = SongPlayer()
    @State private var plan: SongPlan?
    @State private var stage = Stage.intro
    @State private var round = SongRound.together
    @State private var beat = -1.0
    @State private var clock: Task<Void, Never>?
    // The quiz.
    @State private var quiz: SongQuiz?
    @State private var learner = LearnerModel()
    @State private var entry = ""
    @State private var asked = Date()
    @State private var feedback: Feedback?
    @State private var busy = false
    @State private var summary: SingAlong.QuizSummary?
    /// The ladder's result, kept while the shuffle challenge that follows it is played.
    @State private var ladderSummary: SingAlong.QuizSummary?
    /// The screen's shake and the crowd's hop when the stomp drum is hit.
    @State private var shake: CGFloat = 0
    @State private var hop = false
    @State private var stomps = 0
    @State private var onBeat = false
    /// The piece of the song a level opens with.
    @State private var segment: SongSegment?
    /// Friends who have come to sing along: one more for every line sung and every right answer.
    @State private var crowd = 0
    @State private var revealedLine = -1
    /// A short celebration across the screen, such as at the end of a round.
    @State private var cheer: String?
    /// The question just answered, shown with its feedback until the next one is asked.
    @State private var answered: Fact?

    enum Stage: Equatable { case intro, levelStart, singing, between, quizIntro, quiz, shuffleIntro, reward, levelDone }
    enum Feedback: Equatable { case right, listen, shown(Int) }

    /// Who comes to join in, in the order they arrive: the song friends already met, then these.
    @State private var crowdArt: [String] = SingAlongView.pets
    /// How far this song's friend had come before this visit, to celebrate any step up.
    @State private var startTier = SongFriendTier.unmet
    private static let pets = ["reward_pet-pip", "reward_pet-nubbin", "reward_pet-spike", "reward_pet-flap", "reward_pet-scoot",
                                  "reward_pet-chomp", "icon_1f996", "reward_pet-turtle", "reward_pet-bunny", "reward_pet-owl",
                                  "reward_pet-crab", "reward_pet-squirrel", "reward_pet-butterfly", "reward_pet-bee"]

    private var reducedMotion: Bool { model.settings.reducedMotion }
    private var song: SongPlan { plan ?? SongPlan(table: table, settings: model.profile?.parent ?? ParentSettings()) }
    private var moment: SongMoment { song.moment(atBeat: beat, in: round) }

    var body: some View {
        GeometryReader { geometry in
            let compact = geometry.size.height < 480
            let scale = ScreenMetrics.scale(geometry)
            ZStack {
                stageView(size: geometry.size, compact: compact)
                    .padding(compact ? 8 : 18)
                    .offset(x: shake, y: shake * 0.6)
                dialogue
                if let cheer {
                    cheerBanner(cheer, compact: compact)
                        .transition(.scale(scale: 0.4).combined(with: .opacity))
                }
            }
            .animation(reducedMotion ? nil : .spring(duration: 0.45, bounce: 0.45), value: cheer)
            .screenBackground("bg_camp", dim: stage == .quiz || stage == .reward ? 0.25 : 0.08)
            .environment(\.uiScale, scale)
            .environment(\.compact, compact)
        }
        .background(HardwareKeys(onKey: key, onBackspace: backspace).frame(width: 0, height: 0))
        .onAppear {
            let settings = model.profile?.parent ?? ParentSettings()
            var made = SongPlan(table: table, settings: settings)
            #if DEBUG
            // `-debugCrowd 30` starts with a crowd already singing, to check the rows fill properly.
            let arguments = ProcessInfo.processInfo.arguments
            if let index = arguments.firstIndex(of: "-debugCrowd"), index + 1 < arguments.count, let start = Int(arguments[index + 1]) {
                crowd = start
            }
            if ProcessInfo.processInfo.arguments.contains("-debugShort") {
                made = SongPlan(table: table, maxMultiplier: 3, rounds: settings.songRounds, speedUp: settings.songSpeedUp)
            }
            #endif
            plan = made
            player.apply(model.settings)
            player.prepare(made)
            if let profile = model.profile {
                crowdArt = SingAlong.friendsMet(profile).map(\.art) + Self.pets
                startTier = SingAlong.friendTier(table, in: profile)
            }
            if level != nil, let profile = model.profile {
                segment = SingAlong.nextSegment(table, profile: profile)
                stage = .levelStart
            }
            #if DEBUG
            // `-debugQuiz` goes straight to filling the ladder, to check its layout.
            if ProcessInfo.processInfo.arguments.contains("-debugQuiz") { startQuiz(.inOrder) }
            #endif
        }
        .onDisappear {
            clock?.cancel()
            player.shutDown()
        }
    }

    // MARK: - Stages

    @ViewBuilder private func stageView(size: CGSize, compact: Bool) -> some View {
        switch stage {
        case .intro, .singing, .between, .quizIntro:
            singing(size: size, compact: compact)
        case .quiz, .shuffleIntro:
            quizView(size: size, compact: compact)
        case .reward:
            reward(compact: compact)
        case .levelStart:
            levelStart(size: size, compact: compact)
        case .levelDone:
            levelDone(size: size, compact: compact)
        }
    }

    @ViewBuilder private var dialogue: some View {
        if let lines = model.catalog.singAlong {
            switch stage {
            case .intro:
                DialogueView(lines: lines.intro) { startRound(.together) }
            case .between:
                DialogueView(lines: round == .finish ? lines.round2 : lines.round3) { startRound(round) }
            case .quizIntro:
                DialogueView(lines: lines.quiz) { startQuiz(.inOrder) }
            case .shuffleIntro:
                DialogueView(lines: lines.shuffle) { startQuiz(.shuffled) }
            default:
                EmptyView()
            }
        }
    }

    // MARK: - Singing

    private func singing(size: CGSize, compact: Bool) -> some View {
        let ladderWidth = compact ? 170.0 : 250.0
        let talking = stage != .singing
        return VStack(spacing: compact ? 4 : 10) {
            topBar(compact: compact)
            HStack(alignment: .top, spacing: compact ? 8 : 16) {
                VStack(spacing: compact ? 4 : 10) {
                    stageScene(size: CGSize(width: size.width - ladderWidth, height: size.height), compact: compact)
                    if !talking {
                        HStack(alignment: .bottom, spacing: compact ? 8 : 16) {
                            stompDrum(compact: compact).zIndex(1)
                            lyricCard(compact: compact)
                        }
                    }
                }
                .padding(.bottom, talking ? DialogueView.reservedHeight(compact: compact) : 0)
                ladder(width: ladderWidth, compact: compact, quiz: false)
            }
        }
    }

    private func topBar(compact: Bool) -> some View {
        HStack(spacing: compact ? 8 : 12) {
            RoundButton(symbol: "chevron.left", size: compact ? 48 : 58, label: "Leave the song") { leave() }
            if stage == .shuffleIntro {
                chip("Ladder done! Shuffle challenge next", fill: Palette.gold, compact: compact)
            } else if stage == .quiz {
                chip(quiz?.order == .shuffled ? "Shuffle challenge: \(quiz?.done ?? 0) of \(quiz?.total ?? 0)"
                     : "Fill the ladder: \(quiz?.done ?? 0) of \(quiz?.total ?? 0)", fill: Palette.gold, compact: compact)
            } else if stage == .reward || stage == .levelStart || stage == .levelDone {
                chip(level == nil ? "Campfire Sing-Along" : "Warm-up song", fill: Palette.gold, compact: compact)
            } else if level != nil {
                chip("The \(table)s song · \(round.title)", fill: round == .whole ? Palette.coral : Palette.gold,
                     ink: round == .whole ? .white : Palette.ink, compact: compact)
            } else {
                chip("Round \(round.rawValue) of \(song.rounds.count) · \(round.title)", fill: round == .whole ? Palette.coral : Palette.gold,
                     ink: round == .whole ? .white : Palette.ink, compact: compact)
            }
            Spacer()
            if crowd > 0 {
                HStack(spacing: 6) {
                    Image(crowdArt[0]).resizable().scaledToFit().frame(height: compact ? 22 : 32)
                    Text("\(crowd) singing").font(.game(compact ? 14 : 19))
                }
                .foregroundStyle(Palette.ink)
                .padding(.horizontal, 12).padding(.vertical, 4).panel(radius: 30)
                .accessibilityLabel("\(crowd) friends singing along")
            }
            if let level, stage == .singing || stage == .quiz, (model.profile?.stars(for: level) ?? 0) > 0 {
                Button(action: tapped(goToLevel)) { IconLabel("Skip", symbol: "forward.end.fill", size: compact ? 14 : 18, trailing: true) }
                    .buttonStyle(ChunkyButtonStyle(fill: Palette.cream, size: compact ? 14 : 18))
            }
            if stage == .singing || stage == .between || stage == .intro, level == nil || stage == .singing {
                HStack(spacing: 4) {
                    Text("Speed").font(.game(compact ? 14 : 19))
                    ForEach(SongRound.allCases.prefix(song.rounds.count), id: \.self) { item in
                        Glyph(item.emoji, size: item == round ? (compact ? 26 : 36) : (compact ? 18 : 24))
                            .opacity(item == round ? 1 : 0.3)
                    }
                }
                .foregroundStyle(Palette.ink)
                .padding(.horizontal, 14).padding(.vertical, 4).panel(radius: 30)
            }
        }
    }

    private func chip(_ text: String, fill: Color, ink: Color = Palette.ink, compact: Bool) -> some View {
        Text(text).font(.game(compact ? 15 : 21)).foregroundStyle(ink).lineLimit(1).minimumScaleFactor(0.6)
            .padding(.horizontal, 16).padding(.vertical, compact ? 6 : 9)
            .background(Capsule().fill(fill).overlay(Capsule().strokeBorder(Palette.ink, lineWidth: 3.5)))
    }

    /// Otter, Mosey and the band of befriended dinosaurs, bobbing on the beat.
    private func stageScene(size: CGSize, compact: Bool) -> some View {
        let moment = self.moment
        let singing = stage == .singing
        let bob = singing && !reducedMotion ? abs(sin(beat * .pi)) : 0
        let otter: String = if !singing { "otter_talk" } else {
            switch moment.phase {
            case .call: "otter_sing"
            case .yourTurn: "otter_listen"
            case .answer: "otter_cheer"
            default: "otter_idle"
            }
        }
        let mosey = singing && moment.phase == .answer ? "mosey_sing" : (moment.phase == .finished ? "mosey_cheer" : "mosey_idle")
        let height = size.height * (compact ? 0.36 : 0.34)
        return ZStack(alignment: .bottom) {
            // The band stands further back, spread out behind Otter and Mosey.
            HStack(alignment: .bottom, spacing: 0) {
                ForEach(Array(band.enumerated()), id: \.element.art) { index, member in
                    ZStack(alignment: .topTrailing) {
                        Image(member.art).resizable().scaledToFit().frame(height: height * 0.42)
                        Glyph(member.instrument, size: height * 0.13)
                            .rotationEffect(.degrees(singing && !reducedMotion ? (beat.truncatingRemainder(dividingBy: 2) < 1 ? -14 : 14) : 0))
                    }
                    .offset(y: -bob * height * 0.03 - (index.isMultiple(of: 2) ? height * 0.32 : height * 0.22))
                    .frame(maxWidth: .infinity)
                }
            }
            .opacity(0.95)
            // Once the front row is full, more friends fill rows further back.
            crowdRow(2, height: height * 0.34, bob: bob).offset(y: -height * 0.3)
            crowdRow(1, height: height * 0.34, bob: bob).offset(y: -height * 0.13)
            HStack(alignment: .bottom, spacing: 0) {
                Image(otter).resizable().scaledToFit().frame(height: height).offset(y: -bob * height * 0.05)
                if singing && moment.phase == .yourTurn {
                    Text("Your turn! 🎤").font(.game(compact ? 16 : 24)).foregroundStyle(Palette.ink)
                        .padding(.horizontal, 12).padding(.vertical, 6).panel(fill: Palette.gold, radius: 16)
                        .offset(y: -height * 0.75)
                }
                Image(mosey).resizable().scaledToFit().frame(height: height * 0.8).offset(y: -bob * height * 0.04)
            }
            // The friends who come to sing stand in a front row, filling in from both ends.
            crowdRow(0, height: height * 0.34, bob: bob)
                .offset(y: height * 0.06)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottom)
        .accessibilityHidden(true)
    }

    /// Friends a row of the crowd holds. Three rows: front, middle and back.
    private static let rowSlots = 14
    private static let crowdRows = 3
    /// Every friend who has come to sing is on screen, up to the three full rows; any more are a "+N".
    private var crowdOnScreen: Int { min(crowd, Self.rowSlots * Self.crowdRows) }

    /// One row of the crowd (0 front, 1 middle, 2 back), filling in from both ends. Rows further
    /// back are smaller. When the faces run out they come round again, facing the other way.
    private func crowdRow(_ row: Int, height: CGFloat, bob: Double) -> some View {
        let slots = Self.rowSlots
        let first = row * slots
        let inRow = max(0, min(crowdOnScreen - first, slots))
        // Which arrival stands in each slot: the first ones at the two ends, then inwards.
        let order = (0..<slots).map { $0.isMultiple(of: 2) ? $0 / 2 : slots - 1 - $0 / 2 }
        let scale = [1.0, 0.82, 0.68][min(row, 2)]
        return HStack(alignment: .bottom, spacing: 0) {
            ForEach(0..<slots, id: \.self) { slot in
                let arrival = order.firstIndex(of: slot) ?? 0
                Group {
                    if arrival < inRow {
                        friendFace(first + arrival, height: height * scale, bob: bob)
                    } else {
                        Color.clear.frame(height: 1)
                    }
                }
                .frame(maxWidth: .infinity)
            }
        }
        .overlay(alignment: .trailing) {
            if row == 0, crowd > crowdOnScreen {
                Text("+\(crowd - crowdOnScreen)").font(.game(height * 0.3)).foregroundStyle(.white)
                    .padding(.horizontal, 10).padding(.vertical, 4)
                    .background(Capsule().fill(Palette.coral).overlay(Capsule().strokeBorder(Palette.ink, lineWidth: 3)))
                    .offset(y: -height * 0.5)
            }
        }
        .animation(reducedMotion ? nil : .spring(duration: 0.5, bounce: 0.55), value: inRow)
        .frame(maxWidth: .infinity)
        .accessibilityHidden(true)
    }

    private func friendFace(_ arrival: Int, height: CGFloat, bob: Double) -> some View {
        let art = crowdArt[arrival % crowdArt.count]
        let flipped = !(arrival / crowdArt.count).isMultiple(of: 2)
        return Image(art).resizable().scaledToFit()
            .frame(height: height * (arrival.isMultiple(of: 2) ? 1 : 0.86))
            .scaleEffect(x: flipped ? -1 : 1)
            .offset(y: -(arrival.isMultiple(of: 2) ? bob : 1 - bob) * height * 0.15 - (hop ? height * (0.35 + Double(arrival % 3) * 0.08) : 0))
            .transition(.scale(scale: 0.1, anchor: .bottom).combined(with: .opacity))
    }

    /// The whole crowd, front to back, for the quiz and the end of a level's song.
    private func crowdStack(height: CGFloat) -> some View {
        ZStack(alignment: .bottom) {
            crowdRow(2, height: height, bob: 0).offset(y: -height * 0.55)
            crowdRow(1, height: height, bob: 0).offset(y: -height * 0.28)
            crowdRow(0, height: height, bob: 0)
        }
        .frame(height: height * (crowd > Self.rowSlots ? 1.6 : 1.05), alignment: .bottom)
    }

    private func cheerBanner(_ text: String, compact: Bool) -> some View {
        VStack(spacing: compact ? 4 : 10) {
            HStack(spacing: compact ? 6 : 12) {
                Image("icon_2b50").resizable().scaledToFit().frame(height: compact ? 34 : 60)
                Text(text).font(.game(compact ? 24 : 44)).foregroundStyle(.white).multilineTextAlignment(.center)
                Image("icon_2b50").resizable().scaledToFit().frame(height: compact ? 34 : 60)
            }
            if crowd > 0 {
                Text(crowd == 1 ? "A friend has come to sing with you!" : "\(crowd) friends are singing with you!")
                    .font(.game(compact ? 15 : 24, weight: .bold)).foregroundStyle(Palette.ink)
                    .padding(.horizontal, 14).padding(.vertical, 6).panel(fill: Palette.gold, radius: 16)
            }
        }
        .padding(.horizontal, compact ? 20 : 40).padding(.vertical, compact ? 12 : 22)
        .background(RoundedRectangle(cornerRadius: 26).fill(Palette.coral).overlay(RoundedRectangle(cornerRadius: 26).strokeBorder(Palette.ink, lineWidth: 4)))
        .shadow(color: .black.opacity(0.3), radius: 0, y: 6)
        .allowsHitTesting(false)
    }

    private struct BandMember { let art: String; let instrument: String }

    /// Each befriended boss joins the band once their zone's part is back.
    private var band: [BandMember] {
        let instruments = ["hollow": "🪇", "meadow": "🥁", "swamp": "🎶", "peaks": "🎤", "ridge": "🪘", "rex": "🥁"]
        guard let profile = model.profile else { return [] }
        return model.catalog.islands.filter { profile.crystals.contains($0.id) }.map {
            BandMember(art: IslandTheme.island($0.id).guardianHappy, instrument: instruments[$0.id] ?? "🎵")
        }
    }

    /// The big line: "4 × 3 = 12", with eggs for the parts the child sings.
    private func lyricCard(compact: Bool) -> some View {
        let moment = self.moment
        let big: CGFloat = compact ? 40 : 72
        return VStack(spacing: compact ? 2 : 8) {
            if let line = moment.line {
                HStack(spacing: compact ? 8 : 16) {
                    Text("\(song.multipliers[line]) ×")
                    Text("\(table)")
                    Text("=")
                    if moment.showsAnswer {
                        Text("\(song.product(line: line))").foregroundStyle(Palette.coral)
                            .transition(.scale.combined(with: .opacity))
                    } else {
                        egg(big).rotationEffect(.degrees(moment.phase == .yourTurn && !reducedMotion ? sin(beat * .pi * 4) * 12 : 0))
                    }
                }
                .font(.game(big))
                HStack(spacing: compact ? 6 : 10) {
                    let words = song.callWords(line: line)
                    ForEach(Array(words.enumerated()), id: \.offset) { index, word in
                        Text(word).opacity(index < moment.wordsSung ? 1 : 0.3)
                            .foregroundStyle(index == moment.wordsSung - 1 && moment.phase == .call ? Palette.coral : Palette.ink)
                    }
                    Text(moment.showsAnswer ? song.answerWords(line: line) : (moment.phase == .yourTurn ? "(you sing!)" : "…"))
                        .foregroundStyle(moment.phase == .yourTurn ? Palette.coral : Palette.ink)
                        .opacity(moment.showsAnswer || moment.phase == .yourTurn ? 1 : 0.3)
                }
                .font(.game(compact ? 16 : 28, weight: .bold))
            } else {
                Text(moment.phase == .finished ? "🎉 Great singing!" : "Get ready…").font(.game(big * 0.7))
            }
            HStack(spacing: compact ? 10 : 16) {
                ForEach(0..<4, id: \.self) { index in
                    Image(systemName: "pawprint.fill").font(.system(size: index == moment.beatInBar ? (compact ? 22 : 34) : (compact ? 14 : 22)))
                        .foregroundStyle(index == moment.beatInBar ? Palette.coral : Palette.ink)
                        .opacity(stage == .singing && index == moment.beatInBar ? 1 : 0.25)
                        .frame(width: compact ? 24 : 36, height: compact ? 24 : 36)
                }
            }
        }
        .foregroundStyle(Palette.ink)
        .padding(.horizontal, compact ? 12 : 24).padding(.vertical, compact ? 6 : 12)
        .frame(maxWidth: .infinity)
        .panel()
        .animation(reducedMotion ? nil : .spring(duration: 0.25), value: moment.showsAnswer)
        .accessibilityElement(children: .combine)
    }

    private func egg(_ size: CGFloat) -> some View {
        Image("egg").resizable().scaledToFit().frame(height: size * 1.05)
    }

    /// Tap along to the beat. A tap on the beat gets a sparkle; nothing is scored.
    private func stompDrum(compact: Bool) -> some View {
        let size: CGFloat = compact ? 76 : 120
        return Button {
            stomp()
        } label: {
            ZStack {
                Circle().fill(Palette.ink).offset(y: 6)
                Circle().fill(round == .whole ? Palette.gold : Palette.coral)
                Circle().strokeBorder(Palette.ink, lineWidth: 4)
                VStack(spacing: 0) {
                    Glyph("🥁", size: size * 0.46)
                    Text("Stomp!").font(.game(size * 0.17)).foregroundStyle(round == .whole ? Palette.ink : .white)
                }
                if stomps > 0 {
                    Text(onBeat ? "BOOM!" : "Boom!").font(.game(size * (onBeat ? 0.3 : 0.22))).foregroundStyle(onBeat ? Palette.coral : Palette.ink)
                        .shadow(color: .white, radius: 0, x: 2, y: 2)
                        .rotationEffect(.degrees(-10))
                        .fixedSize()
                        .offset(x: size * 0.1, y: -size * 0.75)
                        .id(stomps).transition(.scale(scale: 0.2).combined(with: .opacity))
                    Glyph("💨", size: size * 0.32).offset(x: -size * 0.5, y: size * 0.35).id(stomps * 10 + 1)
                        .transition(.scale(scale: 0.2).combined(with: .opacity))
                }
                if onBeat {
                    Glyph("✨", size: size * 0.45).offset(x: size * 0.42, y: -size * 0.42)
                        .id(stomps).transition(.scale.combined(with: .opacity))
                }
            }
            .frame(width: size, height: size)
            .scaleEffect(hop ? 0.9 : 1)
        }
        .buttonStyle(.plain)
        .animation(.spring(duration: 0.2), value: stomps)
        .accessibilityLabel("Stomp along to the beat")
    }

    /// A big stomp: a heavy thud, the screen shakes, and every friend hops. A stomp on the beat gets
    /// a sparkle and a bigger "BOOM!". Nothing is scored.
    private func stomp() {
        stomps += 1
        onBeat = abs(beat - beat.rounded()) < 0.18
        AudioManager.shared.play(.stompBig)
        Haptics.shared.thump()
        guard !reducedMotion else { return }
        Task { @MainActor in
            for dx: CGFloat in [16, -13, 10, -7, 4, -2, 0] {
                withAnimation(.linear(duration: 0.035)) { shake = dx * (onBeat ? 1.3 : 1) }
                try? await Task.sleep(for: .milliseconds(35))
            }
        }
        withAnimation(.spring(duration: 0.2, bounce: 0.5)) { hop = true }
        after(0.16) { withAnimation(.spring(duration: 0.45, bounce: 0.55)) { hop = false } }
    }

    /// The whole table, building up as it is sung. Lines still to come keep their answers hidden
    /// once the child is singing them.
    private func ladder(width: CGFloat, compact: Bool, quiz: Bool, maxHeight: CGFloat = .infinity) -> some View {
        let lines = song.lineCount
        let current = quiz ? self.quiz.flatMap { q in q.current.map { $0 - 1 } } : moment.line
        let preferred: CGFloat = compact ? (lines > 10 ? 13 : 15) : (lines > 10 ? 22 : 25)
        // Shrink the rows if the ladder would otherwise be taller than the room it has.
        let rowFont = max(9, min(preferred, (maxHeight - (compact ? 30 : 50)) / CGFloat(lines + 1) / 1.3))
        return VStack(spacing: compact ? 0 : 2) {
            Text(quiz ? "The \(table)s ladder" : "The \(table)s song").font(.game(compact ? 13 : 20)).padding(.bottom, compact ? 0 : 4)
            ForEach(0..<lines, id: \.self) { line in
                let multiplier = song.multipliers[line]
                let isNow = line == current
                let past = current.map { line < $0 } ?? (stage == .reward || moment.phase == .finished)
                HStack(spacing: 4) {
                    Text(callText(line: line, isNow: isNow, past: past, quiz: quiz))
                        .frame(maxWidth: .infinity, alignment: .leading)
                    Text("=").opacity(0.5)
                    answerText(line: line, multiplier: multiplier, isNow: isNow, past: past, quiz: quiz, size: rowFont)
                        .frame(maxWidth: .infinity, alignment: .trailing)
                }
                .font(.game(rowFont))
                .padding(.horizontal, 8)
                .padding(.vertical, compact ? 0 : 1)
                .background(RoundedRectangle(cornerRadius: 10).fill(isNow ? Palette.gold : .clear)
                    .overlay(RoundedRectangle(cornerRadius: 10).strokeBorder(isNow ? Palette.ink : .clear, lineWidth: 2.5)))
                .opacity(isNow || past ? 1 : 0.4)
            }
        }
        .foregroundStyle(Palette.ink)
        .padding(compact ? 6 : 12)
        .frame(width: width)
        .panel(radius: 18)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("The \(table) times table")
    }

    private func callText(line: Int, isNow: Bool, past: Bool, quiz: Bool) -> String {
        let multiplier = song.multipliers[line]
        return "\(multiplier) × \(table)"
    }

    @ViewBuilder private func answerText(line: Int, multiplier: Int, isNow: Bool, past: Bool, quiz: Bool, size: CGFloat) -> some View {
        let product = table * multiplier
        if quiz {
            if self.quiz?.answered.contains(multiplier) == true && !isNow {
                Text("\(product) ✓").foregroundStyle(Palette.leaf)
            } else if isNow {
                Text(entry.isEmpty || feedback != nil ? "?" : entry).foregroundStyle(Palette.coral)
            } else {
                Text("?")
            }
        } else if past || round == .together || (isNow && moment.showsAnswer) || stage != .singing && stage != .between {
            Text("\(product)").foregroundStyle(past ? Palette.leaf : Palette.ink)
        } else {
            Image("egg").resizable().scaledToFit().frame(height: size * 1.1)
        }
    }

    // MARK: - Quiz

    private func quizView(size: CGSize, compact: Bool) -> some View {
        let ladderWidth = compact ? 170.0 : 270.0
        // The number pad always gets its room; the ladder fits into what's left above it.
        let padHeight = stage == .quiz && !InputDetector.hasHardwareKeyboard ? KeyMetrics.numberHeight(compact: compact) + 14 : 0
        let ladderHeight = size.height - padHeight - (compact ? 70 : 110)
        return VStack(spacing: 0) {
            topBar(compact: compact)
            HStack(alignment: .top, spacing: compact ? 8 : 20) {
                ladder(width: ladderWidth, compact: compact, quiz: quiz?.order == .inOrder, maxHeight: ladderHeight)
                    .opacity(quiz?.order == .shuffled ? 0.35 : 1)
                VStack(spacing: compact ? 6 : 14) {
                    if let fact = feedback == nil ? quiz?.fact : (answered ?? quiz?.fact), stage == .quiz {
                        HStack(spacing: compact ? 10 : 18) {
                            Text("\(fact.multiplier) × \(fact.table) =")
                            Text(answerShown(fact)).foregroundStyle(feedback == .right ? Palette.leaf : Palette.coral)
                                .frame(minWidth: compact ? 60 : 110)
                                .padding(.horizontal, 10)
                                .background(RoundedRectangle(cornerRadius: 14).fill(.white)
                                    .overlay(RoundedRectangle(cornerRadius: 14).strokeBorder(Palette.ink, lineWidth: 3)))
                        }
                        .font(.game(compact ? 38 : 70))
                        .foregroundStyle(Palette.ink)
                        .padding(.horizontal, compact ? 16 : 30).padding(.vertical, compact ? 8 : 16)
                        .panel()
                        Text(feedbackText(fact)).font(.game(compact ? 16 : 24, weight: .bold)).foregroundStyle(Palette.ink)
                            .padding(.horizontal, 16).padding(.vertical, 6).panel(fill: feedback == nil ? Palette.cream : Palette.gold, radius: 16)
                        HStack(spacing: 16) {
                            RoundButton(symbol: "music.note", fill: Palette.gold, size: compact ? 48 : 60, label: "Sing this line") {
                                if let line = song.multipliers.firstIndex(of: fact.multiplier) { player.singLine(song, line: line) }
                            }
                            RoundButton(symbol: "speaker.wave.2.fill", size: compact ? 48 : 60, label: "Hear the question") { speak() }
                        }
                    }
                    Spacer(minLength: 0)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                // Otter, Mosey and the crowd stand behind as scenery, so they never push the
                // number pad down; on a small screen they simply sit lower.
                .background(alignment: .bottom) {
                    VStack(spacing: 0) {
                        crowdStack(height: size.height * (compact ? 0.08 : 0.09))
                        HStack(alignment: .bottom) {
                            Image(feedback == .right ? "otter_cheer" : "otter_idle").resizable().scaledToFit().frame(height: size.height * (compact ? 0.2 : 0.24))
                            Image(feedback == .right ? "mosey_cheer" : "mosey_idle").resizable().scaledToFit().frame(height: size.height * (compact ? 0.15 : 0.19))
                        }
                    }
                    .opacity(compact ? 0.9 : 1)
                    .accessibilityHidden(true)
                    .allowsHitTesting(false)
                }
            }
            .frame(maxHeight: .infinity)
            .padding(.top, compact ? 4 : 10)
            .padding(.bottom, stage == .shuffleIntro ? DialogueView.reservedHeight(compact: compact) : 0)
            if stage == .quiz, !InputDetector.hasHardwareKeyboard {
                GameKeyboard(kind: .numbers, width: size.width - 16, onKey: key, onBackspace: backspace, embedded: true)
                    .fixedSize(horizontal: false, vertical: true)
                    .layoutPriority(1)
            }
        }
    }

    private func answerShown(_ fact: Fact) -> String {
        if case .shown(let answer) = feedback { return "\(answer)" }
        return entry.isEmpty ? " " : entry
    }

    private func feedbackText(_ fact: Fact) -> String {
        #if DEBUG
        if AppModel.debugAnswers, feedback == nil { return "Answer: " + String(fact.product) }
        #endif
        return switch feedback {
        case .right: "Yes! \(fact.multiplier) × \(fact.table) = \(fact.product)"
        case .listen: "Listen to the song, then try again!"
        case .shown(let answer): "It's \(answer). We'll come back to it."
        case nil: quiz?.order == .shuffled ? "All mixed up! Take your time." : "Type the answer. The band will wait!"
        }
    }

    // MARK: - Reward

    private func reward(compact: Bool) -> some View {
        let level = summary?.level ?? .none
        let trophies = (ladderSummary?.trophies ?? []) + (summary?.trophies ?? [])
        return VStack(spacing: compact ? 6 : 16) {
            Text("You learned the \(table)s song!")
                .font(.game(compact ? 24 : 40)).foregroundStyle(.white)
                .padding(.horizontal, 28).padding(.vertical, 8)
                .background(RoundedRectangle(cornerRadius: 20).fill(Palette.coral).overlay(RoundedRectangle(cornerRadius: 20).strokeBorder(Palette.ink, lineWidth: 4)))
            HStack(spacing: compact ? 10 : 20) {
                StarRow(stars: ladderSummary?.stars ?? summary?.stars ?? 0, size: compact ? 30 : 54)
                if let quiz, quiz.order == .shuffled {
                    IconLabel("Mixed up: \(quiz.rightFirstTime) of \(quiz.total)", emoji: "🎲", size: compact ? 14 : 20)
                        .font(.game(compact ? 14 : 20)).foregroundStyle(Palette.ink)
                        .padding(.horizontal, 12).padding(.vertical, 6).panel(fill: Palette.gold, radius: 16)
                }
            }
            HStack(alignment: .center, spacing: compact ? 16 : 40) {
                Image("fossil_\(table)").resizable().scaledToFit().frame(height: compact ? 70 : 150)
                    .rotationEffect(.degrees(reducedMotion ? 0 : -6))
                RecordDisc(table: table, level: level, size: compact ? 110 : 240)
                HStack(alignment: .bottom, spacing: -20) {
                    Image("otter_cheer").resizable().scaledToFit().frame(height: compact ? 90 : 190)
                    Image("mosey_cheer").resizable().scaledToFit().frame(height: compact ? 70 : 150)
                }
            }
            friendNews(compact: compact)
            HStack(spacing: 12) {
                if level == .gold { IconLabel("Gold record: you know the \(table)s!", emoji: "🏆", size: compact ? 14 : 20).font(.game(compact ? 14 : 20)).padding(8).panel(fill: Palette.gold, radius: 14) }
                ForEach(trophies.prefix(3), id: \.id) { trophy in
                    HStack(spacing: 8) {
                        Image(trophy.art).resizable().scaledToFit().frame(height: compact ? 26 : 44)
                        Text("New trophy: \(trophy.title)")
                    }
                    .font(.game(compact ? 14 : 20)).padding(.horizontal, 10).padding(.vertical, 4).panel(radius: 14)
                }
            }
            .foregroundStyle(Palette.ink)
            HStack(spacing: compact ? 10 : 20) {
                Button(action: tapped { startRound(.together) }) { IconLabel("Sing again", symbol: "arrow.clockwise", size: compact ? 18 : 24) }
                    .buttonStyle(ChunkyButtonStyle(fill: Palette.gold, size: compact ? 18 : 24))
                Button(action: tapped(leave)) {
                    IconLabel("Back to the campfire", symbol: "play.fill", size: compact ? 18 : 24, trailing: true)
                }
                .buttonStyle(ChunkyButtonStyle(fill: Palette.cream, size: compact ? 18 : 24))
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    // MARK: - Song friends

    /// The song friend stepping up after this song, if they did: met, sparkling or crowned.
    @ViewBuilder private func friendNews(compact: Bool) -> some View {
        if let profile = model.profile, let friend = SongFriend.of(table) {
            let tier = SingAlong.friendTier(table, in: profile)
            if tier > startTier {
                HStack(spacing: compact ? 10 : 18) {
                    FriendBadge(table: table, tier: tier, size: compact ? 64 : 120)
                    VStack(alignment: .leading, spacing: 4) {
                        let (headline, detail): (String, String) = switch tier {
                        case .met: ("You met \(friend.name)!", "The \(friend.kind) plays the \(friend.instrument), and will sing with you from now on.")
                        case .sparkling: ("\(friend.name) is sparkling!",
                                          "Sing the \(table)s \(SongFriendTier.crownAt - SingAlong.record(table, in: profile).plays) more times for a crown!")
                        default: ("\(friend.name) got a crown!", "The best \(friend.instrument) in the whole band!")
                        }
                        Text(headline).font(.game(compact ? 20 : 32))
                        Text(detail).font(.game(compact ? 13 : 19, weight: .bold))
                    }
                    .foregroundStyle(Palette.ink)
                }
                .padding(.horizontal, compact ? 14 : 24).padding(.vertical, compact ? 8 : 12)
                .panel(fill: Palette.hex("#FFF3C4"), radius: 20)
                .onAppear {
                    AudioManager.shared.play(.unlock)
                    Haptics.shared.crescendo()
                }
            }
        }
    }

    // MARK: - Level songs

    /// Before a level: which table and which piece of its song, and a big button to start.
    private func levelStart(size: CGSize, compact: Bool) -> some View {
        let (title, detail): (String, String) = switch segment ?? .round(.together) {
        case .round(.together): ("Sing with us!", "Otter and Mosey sing the \(table)s. Sing along!")
        case .round(.finish): ("You finish it!", "We sing the start, you sing the answer.")
        case .round(.whole): ("Rex speed!", "Sing it with us, super fast!")
        case .ladder: ("Fill the ladder!", "Type the \(table)s answers, in order.")
        case .shuffle: ("Shuffle challenge!", "The \(table)s, all mixed up!")
        }
        let levelTitle = level.flatMap { model.catalog.level($0)?.title } ?? ""
        return VStack(spacing: compact ? 8 : 18) {
            topBar(compact: compact)
            Spacer(minLength: 0)
            HStack(spacing: compact ? 14 : 36) {
                RecordDisc(table: table, level: model.profile.map { SingAlong.level(table, in: $0) } ?? .none, size: compact ? 100 : 200)
                    .overlay(alignment: .bottomTrailing) {
                        FriendBadge(table: table, tier: startTier, size: compact ? 60 : 120).offset(x: compact ? 24 : 50, y: compact ? 10 : 20)
                    }
                VStack(alignment: .leading, spacing: compact ? 4 : 10) {
                    Text("Warm-up: the \(table)s song").font(.game(compact ? 16 : 24, weight: .bold)).opacity(0.7)
                    Text(title).font(.game(compact ? 30 : 54))
                    Text(detail).font(.game(compact ? 15 : 24, weight: .bold))
                    if let friend = SongFriend.of(table) {
                        Text(FriendBadge.goal(friend, record: model.profile.map { SingAlong.record(table, in: $0) } ?? SongRecord()))
                            .font(.game(compact ? 13 : 19, weight: .bold)).foregroundStyle(Palette.coral)
                    }
                    Text("Then on to \(levelTitle)").font(.game(compact ? 13 : 18, weight: .bold)).opacity(0.6)
                }
                .foregroundStyle(Palette.ink)
            }
            .padding(compact ? 14 : 28)
            .panel()
            Button(action: tapped(startSegment)) { IconLabel("Let's sing!", emoji: "🎵", size: compact ? 22 : 32) }
                .buttonStyle(ChunkyButtonStyle(fill: Palette.gold, size: compact ? 22 : 32))
                .accessibilityLabel("Let's sing!")
            HStack(alignment: .bottom) {
                Image("otter_sing").resizable().scaledToFit().frame(height: size.height * 0.24)
                Image("mosey_sing").resizable().scaledToFit().frame(height: size.height * 0.2)
            }
            .accessibilityHidden(true)
            Spacer(minLength: 0)
        }
    }

    /// After a level's song: everyone who came to sing, and on to the level.
    private func levelDone(size: CGSize, compact: Bool) -> some View {
        let levelTitle = level.flatMap { model.catalog.level($0)?.title } ?? "the level"
        return VStack(spacing: compact ? 8 : 16) {
            topBar(compact: compact)
            Spacer(minLength: 0)
            Text(crowd > 0 ? "\(crowd) friends sang with you!" : "Great singing!")
                .font(.game(compact ? 24 : 42)).foregroundStyle(.white)
                .padding(.horizontal, 28).padding(.vertical, 8)
                .background(RoundedRectangle(cornerRadius: 20).fill(Palette.coral).overlay(RoundedRectangle(cornerRadius: 20).strokeBorder(Palette.ink, lineWidth: 4)))
            if let summary { StarRow(stars: summary.stars, size: compact ? 28 : 48) }
            crowdStack(height: size.height * (compact ? 0.13 : 0.12))
            friendNews(compact: compact)
            HStack(spacing: 12) {
                ForEach(summary?.trophies ?? [], id: \.id) { trophy in
                    HStack(spacing: 8) {
                        Image(trophy.art).resizable().scaledToFit().frame(height: compact ? 26 : 44)
                        Text("New trophy: \(trophy.title)")
                    }
                    .font(.game(compact ? 14 : 20)).foregroundStyle(Palette.ink).padding(.horizontal, 10).padding(.vertical, 4).panel(radius: 14)
                }
            }
            HStack(alignment: .bottom, spacing: -10) {
                Image("otter_cheer").resizable().scaledToFit().frame(height: size.height * 0.24)
                Image("mosey_cheer").resizable().scaledToFit().frame(height: size.height * 0.19)
            }
            .accessibilityHidden(true)
            Button(action: tapped(goToLevel)) { IconLabel("On to \(levelTitle)!", symbol: "play.fill", size: compact ? 20 : 28, trailing: true) }
                .buttonStyle(ChunkyButtonStyle(fill: Palette.teal, ink: .white, size: compact ? 20 : 28))
                .accessibilityLabel("On to the level")
            Spacer(minLength: 0)
        }
    }

    // MARK: - Actions

    private func startRound(_ next: SongRound) {
        clock?.cancel()
        quiz = nil
        summary = nil
        ladderSummary = nil
        feedback = nil
        cheer = nil
        round = next
        beat = -1
        revealedLine = -1
        stage = .singing
        AudioManager.shared.playMusic("none")
        player.apply(model.settings)
        player.play(song, round: next)
        let length = Double(song.beatsPerRound)
        clock = Task { @MainActor in
            while !Task.isCancelled {
                if let now = player.currentBeat { beat = now }
                // Each line sung brings another friend along to sing.
                let moment = song.moment(atBeat: beat, in: round)
                if moment.showsAnswer, let line = moment.line, line > revealedLine {
                    revealedLine = line
                    joinCrowd()
                }
                if beat >= length {
                    roundFinished()
                    return
                }
                try? await Task.sleep(for: .milliseconds(30))
            }
        }
    }

    private func roundFinished() {
        player.stop()
        let last = round.rawValue >= song.rounds.count
        model.sangSong(table, through: round, finished: last)
        AudioManager.shared.play(.star)
        Haptics.shared.success()
        if level != nil {
            celebrate("Great singing!") { stage = .levelDone }
        } else if last {
            celebrate("You sang the whole song!") { stage = .quizIntro }
        } else if let next = SongRound(rawValue: round.rawValue + 1) {
            celebrate("Round \(round.rawValue) done!") {
                round = next
                beat = -1
                stage = .between
            }
        }
    }

    /// A banner for a couple of seconds, then on to what's next.
    private func celebrate(_ text: String, then: @escaping @MainActor () -> Void) {
        cheer = text
        after(2.4) {
            cheer = nil
            then()
        }
    }

    private func joinCrowd() {
        crowd += 1
        if crowd <= crowdArt.count { AudioManager.shared.play(.pop, volume: 0.35) }
    }

    private func startSegment() {
        switch segment ?? .round(.together) {
        case .round(let round): startRound(round)
        case .ladder: startQuiz(.inOrder)
        case .shuffle: startQuiz(.shuffled)
        }
    }

    private func goToLevel() {
        clock?.cancel()
        player.shutDown()
        if let level { model.route = .play(level) }
    }

    private func startQuiz(_ order: SongQuiz.Order) {
        clock?.cancel()
        quiz = SongQuiz(plan: song, order: order)
        learner = model.profile?.learner ?? LearnerModel()
        entry = ""
        feedback = nil
        busy = false
        stage = .quiz
        player.vamp(song)
        ask()
    }

    private func ask() {
        asked = Date()
        speak()
    }

    private func speak() {
        guard model.settings.spokenInstructions, let fact = quiz?.fact else { return }
        Narrator.shared.say(key: "mul_\(fact.table)x\(fact.multiplier)", fallback: "\(fact.multiplier) times \(fact.table)")
    }

    private func key(_ character: Character) {
        guard stage == .quiz, !busy, character.isNumber, let fact = quiz?.fact else { return }
        let target = String(fact.product).count
        guard entry.count < target else { return }
        entry.append(character)
        feedback = nil
        AudioManager.shared.play(.key, volume: 0.6)
        if entry.count == target { submit() }
    }

    private func backspace() {
        guard stage == .quiz, !busy, !entry.isEmpty else { return }
        entry.removeLast()
    }

    private func submit() {
        guard var current = quiz, let fact = current.fact, let value = Int(entry) else { return }
        busy = true
        answered = fact
        let outcome = current.answer(value, seconds: Date().timeIntervalSince(asked), learner: &learner)
        quiz = current
        model.updateLearner(learner)
        switch outcome {
        case .correct:
            feedback = .right
            joinCrowd()
            AudioManager.shared.play(.correct)
            Haptics.shared.success()
            after(0.9) { next() }
        case .tryAgain:
            feedback = .listen
            AudioManager.shared.play(.wrong, volume: 0.5)
            if let line = song.multipliers.firstIndex(of: fact.multiplier) { player.singLine(song, line: line) }
            after(0.6) {
                entry = ""
                busy = false
            }
        case .shown(let answer):
            feedback = .shown(answer)
            AudioManager.shared.play(.wrong, volume: 0.4)
            after(2.2) { next() }
        }
    }

    private func next() {
        entry = ""
        busy = false
        if quiz?.isFinished == true {
            finishQuiz()
        } else {
            feedback = nil
            ask()
        }
    }

    private func finishQuiz() {
        guard let quiz else { return }
        player.stop()
        let result = model.finishSong(quiz, learner: learner)
        // The full song's ladder goes straight on into the shuffle challenge.
        if level == nil, quiz.order == .inOrder {
            ladderSummary = result
            AudioManager.shared.play(.star)
            // Mosey introduces the shuffle challenge, and it starts when the child taps on.
            celebrate("Ladder done!") { stage = .shuffleIntro }
            return
        }
        summary = result
        stage = level == nil ? .reward : .levelDone
        AudioManager.shared.play(.levelComplete)
        Haptics.shared.crescendo()
        if let lines = model.catalog.singAlong?.done, level == nil || quiz.order == .inOrder {
            Task { @MainActor in
                for line in lines {
                    Narrator.shared.speakLine(line, voiced: model.settings.characterVoices)
                    try? await Task.sleep(for: .seconds(2.6))
                    guard stage == .reward || stage == .levelDone else { return }
                }
            }
        }
    }

    private func after(_ seconds: Double, _ action: @escaping @MainActor () -> Void) {
        Task { @MainActor in
            try? await Task.sleep(for: .seconds(seconds))
            action()
        }
    }

    private func leave() {
        clock?.cancel()
        player.shutDown()
        if let level { model.route = .island(model.catalog.island(containing: level)?.id ?? "hollow") } else { model.route = .songShelf }
    }
}

/// A record for the song shelf: black until sung and quizzed, then silver, then gold once the
/// table is known (its skeleton in the Fossil Museum is complete).
struct RecordDisc: View {
    let table: Int
    let level: SongRecordLevel
    var size: CGFloat = 140

    private static let colours = [1: "#B0B8C0", 2: "#3DB8FF", 3: "#F2A13C", 4: "#3FA796", 5: "#FF7EB6", 6: "#9B5BD6",
                                  7: "#E8643C", 8: "#8FA8FF", 9: "#1E9E52", 10: "#17B8A6", 11: "#C9A227", 12: "#FF6B5E"]

    var body: some View {
        let grooves: [Color] = switch level {
        case .gold: [Palette.hex("#F6C445"), Palette.hex("#DCA021")]
        case .silver: [Palette.hex("#E3E8EA"), Palette.hex("#B9C3C7")]
        case .none: [Palette.hex("#2D3436"), Palette.hex("#3D4648")]
        }
        ZStack {
            Circle().fill(Palette.ink).offset(y: size * 0.035)
            Circle().fill(grooves[0])
            ForEach(1..<9, id: \.self) { ring in
                Circle().strokeBorder(grooves[1], lineWidth: size * 0.012).padding(CGFloat(ring) * size * 0.035)
            }
            Circle().fill(AngularGradient(colors: [.clear, .white.opacity(0.35), .clear, .clear, .white.opacity(0.25), .clear], center: .center))
            Circle().fill(Palette.hex(Self.colours[table] ?? "#F2A13C")).frame(width: size * 0.42)
                .overlay(Circle().strokeBorder(Palette.ink, lineWidth: max(2, size * 0.02)).frame(width: size * 0.42))
            Text("×\(table)").font(.game(size * 0.16)).foregroundStyle(.white).shadow(color: .black.opacity(0.3), radius: 0, y: 2)
            Circle().strokeBorder(Palette.ink, lineWidth: max(2.5, size * 0.025))
        }
        .frame(width: size, height: size)
        .accessibilityLabel(level == .gold ? "Gold record" : level == .silver ? "Silver record" : "Record not sung yet")
    }
}

/// The song shelf at Crash Camp: a record for each times table the grown-up has switched on.
struct SongShelfView: View {
    @Environment(AppModel.self) private var model

    var body: some View {
        GeometryReader { geometry in
            let compact = geometry.size.height < 480
            let profile = model.profile ?? Profile(nickname: "")
            let tables = SingAlong.shelf(profile.parent)
            let next = SingAlong.nextUp(profile)
            let columns = tables.count > 8 ? 4 : 3
            let cardHeight = (geometry.size.height - (compact ? 90 : 160)) / CGFloat((tables.count + columns - 1) / columns) - (compact ? 8 : 16)
            VStack(spacing: compact ? 6 : 14) {
                HStack(spacing: 12) {
                    RoundButton(symbol: "map.fill", size: compact ? 48 : 58, label: "Crash Camp map") { model.route = .map }
                    IconLabel("Campfire Sing-Along", emoji: "🔥", size: compact ? 17 : 24).font(.game(compact ? 17 : 24)).foregroundStyle(Palette.ink)
                        .padding(.horizontal, 16).padding(.vertical, compact ? 6 : 9)
                        .background(Capsule().fill(Palette.gold).overlay(Capsule().strokeBorder(Palette.ink, lineWidth: 3.5)))
                    Spacer()
                    let golds = tables.filter { SingAlong.level($0, in: profile) == .gold }.count
                    CountChip(emoji: "💿", text: "\(golds) gold").fixedSize()
                }
                HStack(alignment: .bottom, spacing: compact ? 8 : 20) {
                    VStack(spacing: 6) {
                        Text("Pick a song! The band's all warmed up.")
                            .font(.game(compact ? 14 : 21, weight: .bold)).foregroundStyle(Palette.ink)
                            .padding(12).panel(radius: 18)
                        Image("otter_talk").resizable().scaledToFit().frame(height: geometry.size.height * 0.4)
                    }
                    .frame(width: compact ? 150 : 260)
                    LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: compact ? 8 : 18), count: columns), spacing: compact ? 8 : 18) {
                        ForEach(tables, id: \.self) { table in
                            card(table, profile: profile, isNext: table == next, height: max(cardHeight, compact ? 96 : 150), compact: compact)
                        }
                    }
                    .frame(maxWidth: .infinity)
                }
                Spacer(minLength: 0)
            }
            .padding(compact ? 8 : 20)
            .screenBackground("bg_camp", dim: 0.15)
            .environment(\.compact, compact)
        }
    }

    private func card(_ table: Int, profile: Profile, isNext: Bool, height: CGFloat, compact: Bool) -> some View {
        let record = SingAlong.record(table, in: profile)
        let level = SingAlong.level(table, in: profile)
        return Button(action: tapped { model.route = .song(table) }) {
            VStack(spacing: compact ? 2 : 6) {
                RecordDisc(table: table, level: level, size: min(height * 0.55, compact ? 60 : 130))
                    .overlay(alignment: .bottomTrailing) {
                        FriendBadge(table: table, tier: SongFriendTier.of(record), size: min(height * 0.42, compact ? 46 : 100))
                            .offset(x: min(height * 0.32, compact ? 34 : 76), y: min(height * 0.06, 8))
                    }
                Text("The \(table)s Song").font(.game(compact ? 15 : 24)).lineLimit(1).minimumScaleFactor(0.6)
                if record.bestStars > 0 {
                    StarRow(stars: record.bestStars, size: compact ? 13 : 20)
                } else {
                    Text("▶ Sing it!").font(.game(compact ? 13 : 19)).foregroundStyle(Palette.coral)
                }
                if let friend = SongFriend.of(table) {
                    Text(FriendBadge.goal(friend, record: record))
                        .font(.game(compact ? 10 : 15, weight: .bold)).opacity(0.75)
                        .multilineTextAlignment(.center).lineLimit(2).minimumScaleFactor(0.7)
                        .padding(.horizontal, 6)
                }
            }
            .foregroundStyle(Palette.ink)
            .frame(maxWidth: .infinity)
            .frame(height: height)
            .panel(fill: isNext ? Palette.hex("#FFF3C4") : Palette.cream, radius: 18, stroke: isNext ? Palette.gold : Palette.ink)
            .overlay(alignment: .topTrailing) {
                if isNext {
                    Text("Next up!").font(.game(compact ? 11 : 16)).foregroundStyle(.white)
                        .padding(.horizontal, 8).padding(.vertical, 3)
                        .background(RoundedRectangle(cornerRadius: 8).fill(Palette.coral).overlay(RoundedRectangle(cornerRadius: 8).strokeBorder(Palette.ink, lineWidth: 2.5)))
                        .rotationEffect(.degrees(8)).offset(x: 6, y: -8)
                }
            }
        }
        .buttonStyle(.plain)
        .accessibilityLabel("The \(table)s song. \(record.bestStars) stars. \(level == .gold ? "Gold record." : "")")
    }
}

/// A song's friend: a dark shape until met, then the baby dinosaur with its instrument; sparkling
/// after four sings and wearing a crown after eight.
struct FriendBadge: View {
    let table: Int
    let tier: SongFriendTier
    var size: CGFloat = 100
    @Environment(AppModel.self) private var model
    @State private var twinkle = false

    var body: some View {
        if let friend = SongFriend.of(table) {
            ZStack(alignment: .top) {
                Image(friend.art).resizable().scaledToFit()
                    .frame(width: size, height: size)
                    .brightness(tier == .unmet ? -1 : 0)
                    .opacity(tier == .unmet ? 0.35 : 1)
                    .shadow(color: tier >= .sparkling ? Palette.gold : .clear, radius: tier >= .sparkling ? size * 0.12 : 0)
                if tier >= .sparkling {
                    Image("icon_2728").resizable().scaledToFit().frame(width: size * 0.3)
                        .offset(x: size * 0.38, y: size * 0.05)
                        .scaleEffect(twinkle ? 1.15 : 0.85)
                    Image("icon_2728").resizable().scaledToFit().frame(width: size * 0.2)
                        .offset(x: -size * 0.4, y: size * 0.45)
                        .scaleEffect(twinkle ? 0.85 : 1.15)
                }
                if tier == .crowned {
                    Image("icon_1f451").resizable().scaledToFit().frame(width: size * 0.42)
                        .offset(y: -size * 0.18)
                        .rotationEffect(.degrees(-8))
                }
            }
            .frame(width: size, height: size)
            .onAppear {
                guard tier >= .sparkling, !model.settings.reducedMotion else { return }
                withAnimation(.easeInOut(duration: 0.9).repeatForever()) { twinkle = true }
            }
            .accessibilityElement(children: .ignore)
            .accessibilityLabel(tier == .unmet ? "A friend still to meet" : "\(friend.name) the \(friend.kind)")
        }
    }

    /// What singing the song (again) will do for its friend, for the shelf and the start card.
    static func goal(_ friend: SongFriend, record: SongRecord) -> String {
        let left = SongFriendTier.playsToNext(record) ?? 0
        return switch SongFriendTier.of(record) {
        case .unmet: "Sing it through to meet a friend!"
        case .met: "\(left) more to make \(friend.name) sparkle"
        case .sparkling: "\(left) more for \(friend.name)'s crown"
        case .crowned: "\(friend.name) is a superstar!"
        }
    }
}
