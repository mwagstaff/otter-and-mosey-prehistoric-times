import Foundation
import Testing
@testable import PrehistoricTimesCore

@Suite struct SongPlanTests {
    @Test func singsUpToTheHighestMultiplier() {
        #expect(SongPlan(table: 3, maxMultiplier: 12).multipliers == Array(1...12))
        #expect(SongPlan(table: 3, maxMultiplier: 10).lineCount == 10)
        var settings = ParentSettings()
        settings.multipliers = [2, 5, 7]
        #expect(SongPlan(table: 4, settings: settings).multipliers == Array(1...7))
        #expect(SongPlan(table: 20, maxMultiplier: 40).table == 12)
        #expect(SongPlan(table: 3, maxMultiplier: 40).lineCount == 12)
    }

    @Test func roundsFollowTheGrownUpsSettings() {
        var settings = ParentSettings()
        #expect(SongPlan(table: 3, settings: settings).rounds == [.together, .finish, .whole])
        settings.songRounds = 1
        settings.songSpeedUp = false
        let plan = SongPlan(table: 3, settings: settings)
        #expect(plan.rounds == [.together])
        #expect(plan.bpm(.whole) == SongPlan.steadyBPM)
    }

    @Test func eachRoundIsFaster() {
        let plan = SongPlan(table: 3, maxMultiplier: 12)
        #expect(plan.bpm(.together) < plan.bpm(.finish))
        #expect(plan.bpm(.finish) < plan.bpm(.whole))
        #expect(plan.rate(.finish) == 1)
        // About a minute a round for twelve lines.
        #expect((50...70).contains(plan.seconds(.finish)))
    }

    @Test func wordsAreSungAsSpoken() {
        let plan = SongPlan(table: 3, maxMultiplier: 12)
        #expect(plan.callWords(line: 3) == ["Four", "times", "three", "is…"])
        #expect(plan.answerWords(line: 3) == "twelve!")
        #expect(plan.answerWords(line: 6) == "twenty-one!")
        #expect(SongPlan.words(144) == "one hundred and forty-four")
        #expect(SongPlan.words(100) == "one hundred")
        #expect(SongPlan.words(90) == "ninety")
    }

    @Test func togetherRoundCallsThenAnswersEveryLine() {
        let plan = SongPlan(table: 3, maxMultiplier: 4)
        let cues = plan.cues(.together)
        #expect(cues.count == 8)
        #expect(cues[0] == SongCue(beat: 4, sound: .call("singq_3x1"), line: 0, volume: 1))
        #expect(cues[1] == SongCue(beat: 8, sound: .answer("singa_3"), line: 0, volume: 1))
        #expect(cues.last?.sound == .answer("singa_12"))
    }

    @Test func laterRoundsLeaveTheChildATurn() {
        let plan = SongPlan(table: 3, maxMultiplier: 4)
        let finish = plan.cues(.finish)
        #expect(finish.filter { if case .call = $0.sound { true } else { false } }.count == 4)
        #expect(finish.contains { $0.sound == .answer("singa_6") && $0.beat == 12 + 4 + 2 })
        // Rex speed sings every line through, cracking each egg as its answer is sung.
        let whole = plan.cues(.whole)
        #expect(whole.filter { if case .call = $0.sound { true } else { false } }.count == 4)
        #expect(whole.filter { $0.sound == .crack }.count == 4)
        #expect(whole.contains { $0.sound == .answer("singa_6") && $0.beat == 12 + 4 })
    }

    @Test func cuesOnlyMoveForwardAndFitTheRound() {
        let plan = SongPlan(table: 7, maxMultiplier: 12)
        for round in SongRound.allCases {
            let beats = plan.cues(round).map(\.beat)
            #expect(beats == beats.sorted())
            #expect(beats.allSatisfy { $0 >= 4 && $0 < Double(plan.beatsPerRound - SongPlan.beatsPerBar) })
        }
    }

    @Test func momentsShowWhatIsSung() {
        let plan = SongPlan(table: 3, maxMultiplier: 12)
        #expect(plan.moment(atBeat: 1, in: .together).phase == .countIn)
        let calling = plan.moment(atBeat: 4 + 8 * 3 + 2.5, in: .together)
        #expect(calling.line == 3)
        #expect(calling.phase == .call)
        #expect(calling.wordsSung == 3)
        #expect(!calling.showsAnswer)
        #expect(plan.moment(atBeat: 4 + 8 * 3 + 4.2, in: .together).showsAnswer)

        let turn = plan.moment(atBeat: 4 + 8 * 6 + 5, in: .finish)
        #expect(turn.phase == .yourTurn)
        #expect(turn.showsCall && !turn.showsAnswer)
        #expect(plan.moment(atBeat: 4 + 8 * 6 + 6.1, in: .finish).showsAnswer)

        let whole = plan.moment(atBeat: 4 + 8 * 8 + 1, in: .whole)
        #expect(whole.phase == .call && whole.showsCall && !whole.showsAnswer, "only the answer is hidden")
        #expect(plan.moment(atBeat: 4 + 8 * 8 + 4.1, in: .whole).showsAnswer)
        #expect(plan.moment(atBeat: Double(plan.beatsPerRound) - 1, in: .whole).phase == .finished)
    }

    @Test func everyAnswerHasARecording() {
        #expect(SongPlan.allAnswers.count == 59)
        for table in 1...12 {
            let plan = SongPlan(table: table, maxMultiplier: 12)
            for line in 0..<plan.lineCount { #expect(SongPlan.allAnswers.contains(plan.product(line: line))) }
        }
    }
}

@Suite struct SongQuizTests {
    let plan = SongPlan(table: 3, maxMultiplier: 12)

    @Test func asksEveryLineInOrder() {
        var quiz = SongQuiz(plan: plan, order: .inOrder)
        var learner = LearnerModel()
        var asked: [Int] = []
        while let current = quiz.current {
            asked.append(current)
            #expect(quiz.answer(current * 3, seconds: 2, learner: &learner) == .correct)
        }
        #expect(asked == Array(1...12))
        #expect(quiz.stars == 3)
        #expect(quiz.answered == Set(1...12))
    }

    @Test func aMissIsTriedAgainThenShownAndAskedAgainAtTheEnd() {
        var quiz = SongQuiz(plan: SongPlan(table: 3, maxMultiplier: 3), order: .inOrder)
        var learner = LearnerModel()
        #expect(quiz.answer(4, seconds: 2, learner: &learner) == .tryAgain)
        #expect(quiz.current == 1)
        #expect(quiz.answer(5, seconds: 2, learner: &learner) == .shown(3))
        #expect(quiz.answer(6, seconds: 2, learner: &learner) == .correct)
        #expect(quiz.answer(9, seconds: 2, learner: &learner) == .correct)
        #expect(quiz.current == 1)
        #expect(quiz.isReask)
        #expect(quiz.answer(3, seconds: 2, learner: &learner) == .correct)
        #expect(quiz.isFinished)
        #expect(quiz.rightFirstTime == 2)
        #expect(quiz.total == 3)
        #expect(quiz.stars == 2)
    }

    @Test func inOrderAnswersAreOnlyPractice() {
        var learner = LearnerModel()
        for _ in 0..<5 {
            for date in [monday, tuesday] {
                var quiz = SongQuiz(plan: plan, order: .inOrder)
                while let current = quiz.current { _ = quiz.answer(current * 3, seconds: 1, learner: &learner, on: date) }
            }
        }
        let fact = Fact(table: 3, multiplier: 4)
        #expect(learner.factState(fact, .multiply) == .gettingThere)
        #expect(learner.answerCount == 0)
        #expect(learner.lightningAnswers == 0)
    }

    @Test func aPracticeMissIsANormalMiss() {
        var learner = LearnerModel()
        let fact = Fact(table: 3, multiplier: 4)
        learner.recordPractice(fact, correct: true)
        #expect(learner.factState(fact, .multiply) == .gettingThere)
        learner.recordPractice(fact, correct: false)
        #expect(learner.factState(fact, .multiply) == .learning)
    }

    @Test func shuffledAnswersCountInFull() {
        var rng = SeededGenerator(seed: 5)
        var learner = LearnerModel()
        var quiz = SongQuiz(plan: plan, order: .shuffled, using: &rng)
        #expect(quiz.total == SongQuiz.shuffleCount)
        #expect(quiz.queue != Array(quiz.queue).sorted())
        while let current = quiz.current { _ = quiz.answer(current * 3, seconds: 2, learner: &learner) }
        #expect(learner.answerCount == SongQuiz.shuffleCount)
    }
}

@Suite struct SingAlongProfileTests {
    @Test func shelfHoldsTheSwitchedOnTablesEasiestFirst() {
        let profile = Profile(nickname: "Sky")
        #expect(SingAlong.shelf(profile.parent) == [2, 3, 4, 5, 8, 10], "in number order")
        #expect(SingAlong.nextUp(profile) == 10, "the easiest one still to sing is suggested")
    }

    @Test func onlyEachZonesFirstLevelOpensWithASongByDefault() {
        var profile = Profile(nickname: "Sky")
        let catalog = Catalog.shared
        #expect(profile.parent.levelSongs == .zoneOpeners)
        let opening = catalog.allLevels.filter { SingAlong.levelSong($0.id, profile: profile) != nil }.map(\.id)
        #expect(opening == catalog.islands.map { $0.levels[0].id }, "six songs in the whole adventure")
        #expect(SingAlong.levelSong("hollow-1", profile: profile) == LevelSong(table: 10, segment: .round(.together)))
        profile.levels["hollow-1", default: LevelRecord()].stars = 2
        #expect(SingAlong.levelSong("hollow-1", profile: profile) == nil, "no song when replaying a cleared level")
    }

    @Test func everyLevelOpensWithItsTablesSongWhenChosen() {
        var profile = Profile(nickname: "Sky")
        profile.parent.levelSongs = .everyLevel
        let catalog = Catalog.shared
        for level in catalog.allLevels { #expect(SingAlong.levelSong(level.id, profile: profile) != nil, "\(level.id)") }
        // Hatchling Hollow's tables (10, 2, 5) take turns; Counting Stones in the meadow sings its own 3s.
        #expect(SingAlong.levelSong("hollow-1", profile: profile) == LevelSong(table: 10, segment: .round(.together)))
        #expect(SingAlong.levelSong("hollow-2", profile: profile)?.table == 2)
        #expect(SingAlong.levelSong("hollow-4", profile: profile)?.table == 10)
        #expect(SingAlong.levelSong("meadow-2", profile: profile)?.table == 3)
        profile.parent.levelSongs = .never
        #expect(SingAlong.levelSong("hollow-1", profile: profile) == nil)
    }

    @Test func theOldOnOffSwitchCarriesOver() throws {
        for (old, new) in [(true, LevelSongs.zoneOpeners), (false, .never)] {
            var json = try JSONSerialization.jsonObject(with: JSONEncoder().encode(ParentSettings())) as! [String: Any]
            json["levelSongs"] = old
            let settings = try JSONDecoder().decode(ParentSettings.self, from: JSONSerialization.data(withJSONObject: json))
            #expect(settings.levelSongs == new)
        }
        var settings = ParentSettings()
        settings.levelSongs = .everyLevel
        #expect(try JSONDecoder().decode(ParentSettings.self, from: JSONEncoder().encode(settings)).levelSongs == .everyLevel)
    }

    @Test func theSongMovesOnLevelByLevel() {
        var profile = Profile(nickname: "Sky")
        #expect(SingAlong.nextSegment(3, profile: profile) == .round(.together))
        SingAlong.sang(3, through: .together, finished: false, profile: &profile)
        #expect(SingAlong.nextSegment(3, profile: profile) == .round(.finish))
        SingAlong.sang(3, through: .finish, finished: false, profile: &profile)
        #expect(SingAlong.nextSegment(3, profile: profile) == .round(.whole))
        SingAlong.sang(3, through: .whole, finished: true, profile: &profile)
        #expect(SingAlong.nextSegment(3, profile: profile) == .ladder)
        var record = SingAlong.record(3, in: profile)
        record.quizzes = 1
        profile.songs["3"] = record
        var seen: Set<String> = []
        for extra in 0..<3 {
            record.shuffles = extra
            profile.songs["3"] = record
            seen.insert("\(SingAlong.nextSegment(3, profile: profile))")
        }
        #expect(seen.count == 3, "the fastest round, the shuffle and the ladder take turns")
        profile.parent.songRounds = 1
        #expect(SingAlong.nextSegment(4, profile: profile) == .round(.together))
        SingAlong.sang(4, through: .together, finished: true, profile: &profile)
        #expect(SingAlong.nextSegment(4, profile: profile) == .ladder)
    }

    @Test func finishingAQuizSavesTheRecordAndWinsTrophies() {
        var profile = Profile(nickname: "Sky")
        profile.trophiesReady = true
        let plan = SongPlan(table: 3, settings: profile.parent)
        SingAlong.sang(3, through: .whole, finished: true, profile: &profile)
        var quiz = SongQuiz(plan: plan, order: .inOrder)
        var learner = profile.learner
        while let current = quiz.current { _ = quiz.answer(current * 3, seconds: 2, learner: &learner) }
        let summary = SingAlong.finish(quiz, learner: learner, profile: &profile)
        #expect(summary.stars == 3)
        #expect(summary.isNewBest)
        #expect(summary.level == .silver)
        #expect(SingAlong.record(3, in: profile).quizzes == 1)
        let won = Set(summary.trophies.map(\.id) + profile.pendingTrophies)
        #expect(won.contains("songs-1"))
        #expect(won.contains("rex-speed"))
        #expect(profile.stats.trophyDayIslands.isEmpty)
    }

    @Test func aSongsOwnTrophiesComeBeforeWaitingOnes() {
        var profile = Profile(nickname: "Sky")
        profile.trophiesReady = true
        profile.pendingTrophies = ["days-2", "days-5"]
        SingAlong.sang(3, through: .whole, finished: true, profile: &profile)
        var quiz = SongQuiz(plan: SongPlan(table: 3, maxMultiplier: 3), order: .inOrder)
        var learner = profile.learner
        while let current = quiz.current { _ = quiz.answer(current * 3, seconds: 2, learner: &learner) }
        let summary = SingAlong.finish(quiz, learner: learner, profile: &profile)
        #expect(Set(summary.trophies.map(\.id)) == ["songs-1", "rex-speed"])
        #expect(profile.pendingTrophies.starts(with: ["days-2", "days-5"]))
    }

    @Test func eachSongHasItsOwnFriendWhoGrowsWithReplays() {
        #expect(SongFriend.all.map(\.table) == Array(1...12))
        #expect(Set(SongFriend.all.map(\.name)).count == 12 && Set(SongFriend.all.map(\.instrument)).count == 12)
        var profile = Profile(nickname: "Sky")
        #expect(SingAlong.friendTier(3, in: profile) == .unmet)
        SingAlong.sang(3, through: .together, finished: false, profile: &profile)
        #expect(SingAlong.friendTier(3, in: profile) == .unmet, "met when the song is sung right through")
        SingAlong.sang(3, through: .whole, finished: true, profile: &profile)
        #expect(SingAlong.friendTier(3, in: profile) == .met)
        #expect(SongFriendTier.playsToNext(SingAlong.record(3, in: profile)) == 3)
        #expect(SingAlong.friendsMet(profile).map(\.name) == ["Tambo"])
        var record = SingAlong.record(3, in: profile)
        record.quizzes = 2
        record.shuffles = 1
        profile.songs["3"] = record
        #expect(SingAlong.friendTier(3, in: profile) == .sparkling)
        record.quizzes = 6
        profile.songs["3"] = record
        #expect(SingAlong.friendTier(3, in: profile) == .crowned)
        #expect(SongFriendTier.playsToNext(record) == nil)
        profile.trophiesReady = true
        let won = Trophies.awardOutsideLevel(&profile).map(\.id) + profile.pendingTrophies
        #expect(won.contains("crowned-friend"))
    }

    @Test func goldRecordWhenTheTableIsSecure() {
        var profile = Profile(nickname: "Sky")
        for multiplier in 1...12 {
            for date in [monday, monday, tuesday] {
                profile.learner.record(key: Fact(table: 2, multiplier: multiplier).key(.multiply), skill: .multiplication,
                                       correct: true, seconds: 5, usedHint: false, typed: true, on: date)
            }
        }
        #expect(SingAlong.level(2, in: profile) == .gold)
        #expect(SingAlong.level(3, in: profile) == .none)
    }

    @Test func oldSavesLoadWithoutSongs() throws {
        let profile = Profile(nickname: "Sky")
        var json = try JSONSerialization.jsonObject(with: JSONEncoder().encode(profile)) as! [String: Any]
        json["songs"] = nil
        var parent = json["parent"] as! [String: Any]
        parent["songRounds"] = nil
        json["parent"] = parent
        let loaded = try JSONDecoder().decode(Profile.self, from: JSONSerialization.data(withJSONObject: json))
        #expect(loaded.songs.isEmpty)
        #expect(loaded.parent.songRounds == 3)
        var sung = Profile(nickname: "Sky")
        SingAlong.sang(4, through: .finish, finished: false, profile: &sung)
        let back = try JSONDecoder().decode(Profile.self, from: JSONEncoder().encode(sung))
        #expect(back.songs["4"]?.bestRound == 2)
    }
}
