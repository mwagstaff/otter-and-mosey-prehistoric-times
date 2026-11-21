import Foundation

// The Campfire Sing-Along (docs/PLAN.md, section 14): Otter and Mosey chant a times table over a
// beat, three rounds that leave more for the child to sing each time, then a quiz that fills the
// table in on the number pad. Everything here is plain rules and timings; the app only plays them.

/// One round of the song. Each is a little faster and leaves more for the child to sing.
public enum SongRound: Int, CaseIterable, Codable, Comparable, Sendable {
    /// Otter calls every line and Mosey answers.
    case together = 1
    /// Otter calls; the child sings the answer before the egg hatches.
    case finish
    /// Beat only: the child sings the whole line before it appears.
    case whole

    public static func < (lhs: SongRound, rhs: SongRound) -> Bool { lhs.rawValue < rhs.rawValue }

    /// Beats a minute, with the speed-up on.
    public var bpm: Double {
        switch self {
        case .together: 88
        case .finish: 100
        case .whole: 112
        }
    }

    public var title: String {
        switch self {
        case .together: "Sing with us!"
        case .finish: "You finish it!"
        case .whole: "Rex speed!"
        }
    }

    public var emoji: String {
        switch self {
        case .together: "🐢"
        case .finish: "🦕"
        case .whole: "🦖"
        }
    }
}

/// What is happening at one moment of a round.
public struct SongMoment: Equatable, Sendable {
    public enum Phase: Equatable, Sendable {
        /// The bar of beat before the first line.
        case countIn
        /// Otter is calling the line (or, in the last round, the child is singing it).
        case call
        /// The child's turn to sing the answer.
        case yourTurn
        /// The answer is sung and shown.
        case answer
        /// The bar of beat after the last line.
        case finished
    }

    public var phase: Phase
    /// The line being sung, from 0; nil before the first and after the last.
    public var line: Int?
    /// The beat within the bar, 0 to 3.
    public var beatInBar: Int
    /// How many words of the call have been sung, for lighting them up one by one.
    public var wordsSung: Int
    /// Whether the line's question part ("4 × 3") is shown.
    public var showsCall: Bool
    /// Whether the line's answer is shown.
    public var showsAnswer: Bool
}

/// Something to play at a moment of a round, in beats from the round's start.
public struct SongCue: Equatable, Sendable {
    public enum Sound: Equatable, Sendable {
        /// Otter's "Four times three is…".
        case call(String)
        /// Mosey's "twelve!".
        case answer(String)
        /// The egg cracking, just before the answer when the child has sung it.
        case crack
    }

    public let beat: Double
    public let sound: Sound
    /// The line it belongs to, from 0.
    public let line: Int
    /// 0 to 1.
    public let volume: Float
}

/// The whole song for one times table: its lines, rounds and timings.
public struct SongPlan: Equatable, Sendable {
    public static let beatsPerBar = 4
    /// Each line takes two bars: the call, then the answer.
    public static let beatsPerLine = 8
    /// The beat of the answer bar on which the answer is sung when the child has had a turn.
    public static let revealBeat = 2
    /// The bpm the backing loop is recorded at. Rounds play it faster or slower.
    public static let loopBPM = 100.0
    /// The speed of every round when the grown-up has switched the speed-up off.
    public static let steadyBPM = 88.0

    public let table: Int
    /// The multipliers sung, in order: 1 up to the highest the grown-up allows.
    public let multipliers: [Int]
    public let rounds: [SongRound]
    public let speedUp: Bool

    public init(table: Int, maxMultiplier: Int, rounds: Int = 3, speedUp: Bool = true) {
        self.table = min(max(table, 1), 12)
        multipliers = Array(1...min(max(maxMultiplier, 1), 12))
        self.rounds = Array(SongRound.allCases.prefix(min(max(rounds, 1), SongRound.allCases.count)))
        self.speedUp = speedUp
    }

    /// The song for a table under a grown-up's settings: up to their highest multiplier.
    public init(table: Int, settings: ParentSettings) {
        self.init(table: table, maxMultiplier: settings.usableMultipliers.max() ?? 12, rounds: settings.songRounds,
                  speedUp: settings.songSpeedUp)
    }

    public var lineCount: Int { multipliers.count }

    public func bpm(_ round: SongRound) -> Double { speedUp ? round.bpm : Self.steadyBPM }
    /// How much faster than the backing loop's own speed a round plays it.
    public func rate(_ round: SongRound) -> Double { bpm(round) / Self.loopBPM }
    public func secondsPerBeat(_ round: SongRound) -> Double { 60 / bpm(round) }

    /// A bar to count in, two bars a line, and a bar to finish.
    public var beatsPerRound: Int { Self.beatsPerBar + lineCount * Self.beatsPerLine + Self.beatsPerBar }
    public func seconds(_ round: SongRound) -> Double { Double(beatsPerRound) * secondsPerBeat(round) }

    // MARK: Lines

    public func product(line: Int) -> Int { table * multipliers[line] }
    public func fact(line: Int) -> Fact { Fact(table: table, multiplier: multipliers[line]) }

    /// "Four times three is…", as Otter sings it.
    public func callWords(line: Int) -> [String] {
        [Self.words(multipliers[line]).capitalizedFirst, "times", Self.words(table), "is…"]
    }

    /// "twelve!", as Mosey sings it.
    public func answerWords(line: Int) -> String { Self.words(product(line: line)) + "!" }

    /// The recorded clip of Otter's call for a fact (table, multiplier).
    public static func callKey(table: Int, multiplier: Int) -> String { "singq_\(table)x\(multiplier)" }
    /// The recorded clip of Mosey singing a number.
    public static func answerKey(_ number: Int) -> String { "singa_\(number)" }

    /// Every product in the 12 × 12 table: the answers that need recording.
    public static let allAnswers: [Int] = Array(Set((1...12).flatMap { a in (1...12).map { a * $0 } })).sorted()

    // MARK: Timeline

    /// Everything played in a round, in time order.
    public func cues(_ round: SongRound) -> [SongCue] {
        var cues: [SongCue] = []
        for line in 0..<lineCount {
            let start = Double(Self.beatsPerBar + line * Self.beatsPerLine)
            let answerBar = start + Double(Self.beatsPerBar)
            let callKey = Self.callKey(table: table, multiplier: multipliers[line])
            let answerKey = Self.answerKey(product(line: line))
            switch round {
            case .together:
                cues.append(SongCue(beat: start, sound: .call(callKey), line: line, volume: 1))
                cues.append(SongCue(beat: answerBar, sound: .answer(answerKey), line: line, volume: 1))
            case .finish, .whole:
                if round == .finish { cues.append(SongCue(beat: start, sound: .call(callKey), line: line, volume: 1)) }
                let reveal = answerBar + Double(Self.revealBeat)
                cues.append(SongCue(beat: reveal - 0.1, sound: .crack, line: line, volume: 0.5))
                cues.append(SongCue(beat: reveal, sound: .answer(answerKey), line: line, volume: 0.85))
            }
        }
        return cues
    }

    /// What is happening `beat` beats into a round.
    public func moment(atBeat beat: Double, in round: SongRound) -> SongMoment {
        let whole = Int(beat.rounded(.down))
        let beatInBar = ((whole % Self.beatsPerBar) + Self.beatsPerBar) % Self.beatsPerBar
        let intoLines = beat - Double(Self.beatsPerBar)
        guard intoLines >= 0 else {
            return SongMoment(phase: .countIn, line: nil, beatInBar: beatInBar, wordsSung: 0, showsCall: false, showsAnswer: false)
        }
        let line = Int(intoLines / Double(Self.beatsPerLine))
        guard line < lineCount else {
            return SongMoment(phase: .finished, line: nil, beatInBar: beatInBar, wordsSung: 0, showsCall: false, showsAnswer: false)
        }
        let inLine = intoLines - Double(line * Self.beatsPerLine)
        let inCall = inLine < Double(Self.beatsPerBar)
        let revealed = inLine >= Double(Self.beatsPerBar + Self.revealBeat)
        switch round {
        case .together:
            return SongMoment(phase: inCall ? .call : .answer, line: line, beatInBar: beatInBar,
                              wordsSung: inCall ? min(Int(inLine) + 1, 4) : 4, showsCall: true, showsAnswer: !inCall)
        case .finish:
            return SongMoment(phase: inCall ? .call : (revealed ? .answer : .yourTurn), line: line, beatInBar: beatInBar,
                              wordsSung: inCall ? min(Int(inLine) + 1, 4) : 4, showsCall: true, showsAnswer: revealed)
        case .whole:
            // The question stays on screen; only the answer is the child's to find.
            return SongMoment(phase: inCall ? .call : (revealed ? .answer : .yourTurn), line: line, beatInBar: beatInBar,
                              wordsSung: revealed ? 4 : 0, showsCall: true, showsAnswer: revealed)
        }
    }

    static func words(_ number: Int) -> String {
        let small = ["zero", "one", "two", "three", "four", "five", "six", "seven", "eight", "nine", "ten", "eleven", "twelve",
                     "thirteen", "fourteen", "fifteen", "sixteen", "seventeen", "eighteen", "nineteen"]
        let tens = ["", "", "twenty", "thirty", "forty", "fifty", "sixty", "seventy", "eighty", "ninety"]
        if number < 20 { return small[number] }
        if number < 100 { return tens[number / 10] + (number % 10 == 0 ? "" : "-" + small[number % 10]) }
        let rest = number % 100
        return small[number / 100] + " hundred" + (rest == 0 ? "" : " and " + words(rest))
    }
}

/// The quiz after the song: the same lines typed on the number pad, in order ("Fill the ladder"),
/// or a few of them mixed up (the shuffle challenge).
public struct SongQuiz: Equatable, Sendable {
    public enum Order: Equatable, Sendable {
        /// Every line in order. Easier, so its answers only count as practice.
        case inOrder
        /// A handful of the lines in a random order. Recorded like any level.
        case shuffled
    }

    public enum Outcome: Equatable, Sendable {
        case correct
        /// First miss: the band sings the line again, then the child tries again.
        case tryAgain
        /// Second miss: the answer is shown, and the line comes back at the end.
        case shown(Int)
    }

    /// How many lines the shuffle challenge asks.
    public static let shuffleCount = 6

    public let table: Int
    public let order: Order
    /// The multipliers asked, in the order asked. Lines missed twice are added again at the end.
    public private(set) var queue: [Int]
    public private(set) var position = 0
    /// Lines answered right first time, and how many lines there were (re-asks don't count).
    public private(set) var rightFirstTime = 0
    public let total: Int
    /// Which lines in the queue are re-asks, so they don't count twice.
    private var reasks: Set<Int> = []
    private var missesOnCurrent = 0
    /// The multipliers answered so far, for filling the ladder.
    public private(set) var answered: Set<Int> = []

    public init<R: RandomNumberGenerator>(plan: SongPlan, order: Order, using rng: inout R) {
        table = plan.table
        self.order = order
        switch order {
        case .inOrder: queue = plan.multipliers
        case .shuffled: queue = Array(plan.multipliers.shuffled(using: &rng).prefix(Self.shuffleCount))
        }
        total = queue.count
    }

    public init(plan: SongPlan, order: Order) {
        var rng = SystemRandomNumberGenerator()
        self.init(plan: plan, order: order, using: &rng)
    }

    /// The multiplier being asked, or nil when the quiz is over.
    public var current: Int? { queue.indices.contains(position) ? queue[position] : nil }
    public var isFinished: Bool { current == nil }
    public var isReask: Bool { reasks.contains(position) }
    public var fact: Fact? { current.map { Fact(table: table, multiplier: $0) } }
    /// Lines done, for the progress count.
    public var done: Int { min(position, total) }

    public var accuracy: Double { total == 0 ? 1 : Double(rightFirstTime) / Double(total) }
    public var stars: Int { Progression.stars(forAccuracy: accuracy) }

    /// Answers the current line, recording it in the learner model: as practice when in order,
    /// in full when shuffled. Only the first try at a line is recorded.
    public mutating func answer(_ value: Int, seconds: Double, learner: inout LearnerModel, on date: Date = Date()) -> Outcome {
        guard let fact else { return .correct }
        let correct = value == fact.product
        if missesOnCurrent == 0, !isReask {
            switch order {
            case .inOrder: learner.recordPractice(fact, correct: correct, on: date)
            case .shuffled: learner.record(key: fact.key(.multiply), skill: .multiplication, correct: correct, seconds: seconds,
                                           usedHint: false, typed: true, on: date)
            }
            if correct { rightFirstTime += 1 }
        }
        if correct {
            advance()
            return .correct
        }
        missesOnCurrent += 1
        if missesOnCurrent >= 2 {
            if !isReask {
                queue.append(fact.multiplier)
                reasks.insert(queue.count - 1)
            }
            advance()
            return .shown(fact.product)
        }
        return .tryAgain
    }

    private mutating func advance() {
        if let current { answered.insert(current) }
        missesOnCurrent = 0
        position += 1
    }
}

extension String {
    var capitalizedFirst: String { prefix(1).uppercased() + dropFirst() }
}

/// What the song shelf shows for a table's record.
public enum SongRecordLevel: Int, Comparable, Sendable {
    /// Not sung and quizzed yet.
    case none
    /// Sung and quizzed.
    case silver
    /// The table's skeleton in the Fossil Museum is complete: every fact secure.
    case gold

    public static func < (lhs: SongRecordLevel, rhs: SongRecordLevel) -> Bool { lhs.rawValue < rhs.rawValue }
}

/// One table's song in the save file.
public struct SongRecord: Codable, Equatable, Sendable {
    /// Times the song was sung to the end.
    public var sung = 0
    /// The furthest round reached in any singing, 0 to 3.
    public var bestRound = 0
    /// Times its quiz was finished.
    public var quizzes = 0
    public var bestStars = 0
    public var shuffles = 0
    public var bestShuffle = 0

    public init() {}

    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        sung = c.value(.sung, default: 0)
        bestRound = c.value(.bestRound, default: 0)
        quizzes = c.value(.quizzes, default: 0)
        bestStars = c.value(.bestStars, default: 0)
        shuffles = c.value(.shuffles, default: 0)
        bestShuffle = c.value(.bestShuffle, default: 0)
    }
}

/// One piece of a song: a single round, filling the ladder in order, or the shuffle challenge.
/// Every level opens with one, about a minute long.
public enum SongSegment: Equatable, Sendable {
    case round(SongRound)
    case ladder
    case shuffle
}

/// The song a level opens with: which table, and which piece of its song.
public struct LevelSong: Equatable, Sendable {
    public let table: Int
    public let segment: SongSegment
}

/// The sing-along's rules that touch the player's profile.
public enum SingAlong {
    /// The tables with songs on the shelf: every table the grown-up has switched on, easiest first.
    public static func shelf(_ settings: ParentSettings) -> [Int] { ZonePlan.ordered(settings.usableTables) }

    public static func record(_ table: Int, in profile: Profile) -> SongRecord { profile.songs[String(table)] ?? SongRecord() }

    public static func level(_ table: Int, in profile: Profile) -> SongRecordLevel {
        if Fossils.isComplete(table: table, learner: profile.learner, multipliers: profile.parent.usableMultipliers) { return .gold }
        return record(table, in: profile).bestStars > 0 ? .silver : .none
    }

    /// The song suggested next on the shelf: the easiest table not yet sung and quizzed.
    public static func nextUp(_ profile: Profile) -> Int? {
        shelf(profile.parent).first { record($0, in: profile).quizzes == 0 }
    }

    /// The song a level opens with, or nil when the grown-up has switched level songs off. The
    /// table is the level's own (if switched on) or one of the zone's, taking turns level by level.
    /// The piece sung moves on as the child does: each round in turn, then filling the ladder,
    /// then a mix of the fastest round, the shuffle challenge and the ladder, so nothing gets stale.
    public static func levelSong(_ levelID: String, profile: Profile, catalog: Catalog = .shared) -> LevelSong? {
        guard profile.parent.levelSongs, let island = catalog.island(containing: levelID),
              let zone = catalog.islands.firstIndex(where: { $0.id == island.id }),
              let index = island.levels.firstIndex(where: { $0.id == levelID }) else { return nil }
        let settings = profile.parent
        let table: Int
        if let own = island.levels[index].table, settings.usableTables.contains(own) {
            table = own
        } else {
            let tables = ZonePlan.focus(zone: zone, settings: settings)
            guard !tables.isEmpty else { return nil }
            table = tables[index % tables.count]
        }
        return LevelSong(table: table, segment: nextSegment(table, profile: profile))
    }

    /// What to sing next of a table's song.
    public static func nextSegment(_ table: Int, profile: Profile) -> SongSegment {
        let record = record(table, in: profile)
        let rounds = min(max(profile.parent.songRounds, 1), 3)
        if record.bestRound < rounds, let next = SongRound(rawValue: record.bestRound + 1) { return .round(next) }
        if record.quizzes == 0 { return .ladder }
        let top = SongRound(rawValue: rounds) ?? .whole
        let mix: [SongSegment] = [.round(top), .shuffle, .ladder]
        return mix[(record.sung + record.quizzes + record.shuffles) % mix.count]
    }

    /// Notes that the song was sung through `round`. Called as each round finishes.
    public static func sang(_ table: Int, through round: SongRound, finished: Bool, profile: inout Profile) {
        var record = record(table, in: profile)
        record.bestRound = max(record.bestRound, round.rawValue)
        if finished { record.sung += 1 }
        profile.songs[String(table)] = record
    }

    /// What finishing a quiz earned.
    public struct QuizSummary: Equatable, Sendable {
        public var stars = 0
        public var isNewBest = false
        public var level = SongRecordLevel.none
        public var trophies: [Trophy] = []

        public init(stars: Int = 0) { self.stars = stars }
    }

    /// Saves a finished quiz and hands out any trophies it won.
    public static func finish(_ quiz: SongQuiz, learner: LearnerModel, profile: inout Profile, catalog: Catalog = .shared,
                              now: Date = Date()) -> QuizSummary {
        profile.learner = learner
        var record = record(quiz.table, in: profile)
        var summary = QuizSummary(stars: quiz.stars)
        switch quiz.order {
        case .inOrder:
            summary.isNewBest = quiz.stars > record.bestStars
            record.quizzes += 1
            record.bestStars = max(record.bestStars, quiz.stars)
        case .shuffled:
            summary.isNewBest = quiz.rightFirstTime > record.bestShuffle
            record.shuffles += 1
            record.bestShuffle = max(record.bestShuffle, quiz.rightFirstTime)
        }
        profile.songs[String(quiz.table)] = record
        summary.level = level(quiz.table, in: profile)
        summary.trophies = Trophies.awardOutsideLevel(&profile, catalog: catalog, now: now)
        return summary
    }
}

extension LearnerModel {
    /// Records an in-order sing-along answer as practice: it can move a fact from new to getting
    /// there, never further, and adds no streak days or timings. A miss counts as a normal miss.
    public mutating func recordPractice(_ fact: Fact, correct: Bool, on date: Date = Date()) {
        var stats = factStats(fact, .multiply)
        stats.recordPractice(correct: correct)
        setFactStats(stats, for: fact.key(.multiply))
    }
}

extension FactStats {
    public mutating func recordPractice(correct: Bool) {
        attempts += 1
        if correct {
            if cleanStreak == 0 { cleanStreak = 1 }
        } else {
            cleanStreak = 0
            streakDays = []
        }
        best = max(best, state)
    }
}
