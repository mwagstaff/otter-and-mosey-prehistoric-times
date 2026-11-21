import XCTest
import TimesTroubleCore

nonisolated final class PlaythroughTests: XCTestCase {
    @MainActor func testGrownUpKeypadAcceptsTapsAcrossEachKey() {
        continueAfterFailure = false
        XCUIDevice.shared.orientation = .landscapeLeft
        let app = XCUIApplication()
        app.launch()
        let grownUps = app.buttons["Grown-ups"]
        app.buttons["Tap to continue"].tap()
        XCTAssertTrue(grownUps.waitForExistence(timeout: 15))
        grownUps.tap()

        func showsAnswer(_ answer: String) -> Bool {
            app.staticTexts.matching(NSPredicate(format: "label ENDSWITH %@", " = " + answer))
                .firstMatch.waitForExistence(timeout: 3)
        }

        let edge = CGVector(dx: 0.12, dy: 0.15)
        app.buttons["1"].coordinate(withNormalizedOffset: edge).tap()
        XCTAssertTrue(showsAnswer("1"))
        app.buttons["0"].press(forDuration: 1)
        XCTAssertTrue(showsAnswer("10"))
        app.buttons["Delete"].coordinate(withNormalizedOffset: edge).tap()
        XCTAssertTrue(showsAnswer("1"))
    }

    @MainActor func testTwoDigitFocusButtonFitsOnOneLine() throws {
        let app = XCUIApplication()
        let profile = Profile(nickname: "Explorer")
        var save = SaveFile()
        save.profiles = [profile]
        save.activeProfileID = profile.id
        app.launchEnvironment["CAMP_TEST_ID"] = UUID().uuidString
        app.launchEnvironment["CAMP_TEST_SAVE"] = try SaveMigrator.encode(save).base64EncodedString()
        app.launchArguments = ["-debugRoute", "parent"]
        XCUIDevice.shared.orientation = .landscapeLeft
        app.launch()
        app.buttons["Tap to continue"].tap()

        let table = app.buttons.matching(NSPredicate(format: "label == %@ AND value == %@", "10×", "On")).firstMatch
        let focus = app.buttons.matching(NSPredicate(format: "label == %@ AND value == %@", "10×", "Review")).firstMatch
        XCTAssertTrue(focus.waitForExistence(timeout: 10))
        XCTAssertGreaterThan(focus.frame.width, table.frame.width)
        XCTAssertLessThan(focus.frame.height, table.frame.height + 10)
    }

    @MainActor func testCampPetKeepsItsNewRoamingSpot() throws {
        let app = XCUIApplication()
        var profile = Profile(nickname: "Camp explorer")
        profile.rewards = ["pet-pip", "pet-nubbin", "deco-fountain", "deco-campfire", "deco-palm"]
        profile.decorations = [PlacedDecoration(reward: "deco-fountain", x: 0.43, y: 0.83),
                               PlacedDecoration(reward: "deco-campfire", x: 0.57, y: 0.91),
                               PlacedDecoration(reward: "deco-palm", x: 0.70, y: 0.80)]
        profile.campPetSpots = ["pet-pip": CampSpot(x: 0.27, y: 0.91), "pet-nubbin": CampSpot(x: 0.34, y: 0.80)]
        var save = SaveFile()
        save.profiles = [profile]
        save.activeProfileID = profile.id
        app.launchEnvironment["CAMP_TEST_ID"] = UUID().uuidString
        app.launchEnvironment["CAMP_TEST_SAVE"] = try SaveMigrator.encode(save).base64EncodedString()
        app.launchArguments = ["-debugRoute", "home", "-debugAutomation"]
        XCUIDevice.shared.orientation = .landscapeLeft
        app.launch()
        app.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5)).tap()
        let moves = [("Pip the baby Maiasaura", 0.79), ("Nubbin the baby Triceratops", 0.68)]
        for (name, x) in moves {
            let pet = app.buttons[name]
            XCTAssertTrue(pet.waitForExistence(timeout: 20))
            let target = app.coordinate(withNormalizedOffset: CGVector(dx: x, dy: 0.93))
            pet.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5))
                .press(forDuration: 0.2, thenDragTo: target)
            XCTAssertEqual(pet.frame.midX, x * app.frame.width, accuracy: app.frame.width * 0.055)
        }
        app.terminate()
        app.launch()
        for (name, x) in moves {
            let pet = app.buttons[name]
            XCTAssertTrue(pet.waitForExistence(timeout: 20))
            XCTAssertEqual(pet.frame.midX, x * app.frame.width, accuracy: app.frame.width * 0.065)
        }
    }

    /// A short Campfire Sing-Along (three lines, three rounds), then its quiz typed on the number pad.
    @MainActor func testSingAlongThroughControls() throws {
        continueAfterFailure = false
        XCUIDevice.shared.orientation = .landscapeLeft
        let app = XCUIApplication()
        app.launchArguments = ["-debugRoute", "song:3", "-debugShort", "-debugAutomation"]
        app.launch()
        defer { app.terminate() }
        let deadline = Date().addingTimeInterval(150)
        var typed = 0
        while Date() < deadline {
            RunLoop.current.run(until: Date().addingTimeInterval(0.3))
            let skip = app.buttons["Skip"]
            if skip.exists && skip.isHittable { skip.tap(); continue }
            if app.staticTexts["You learned the 3s song!"].exists { break }
            if app.staticTexts["Type the answer. The band will wait!"].exists, typed < 3 {
                typed += 1
                for digit in String(3 * typed) { app.buttons[String(digit)].tap() }
            }
        }
        XCTAssertTrue(app.staticTexts["You learned the 3s song!"].waitForExistence(timeout: 10))
        XCTAssertEqual(typed, 3)
        XCTAssertTrue(app.buttons["Shuffle challenge"].exists)
    }

    /// A level opens with a short piece of its table's song, then goes on into the level.
    @MainActor func testLevelOpensWithItsSong() throws {
        continueAfterFailure = false
        XCUIDevice.shared.orientation = .landscapeLeft
        let app = XCUIApplication()
        app.launchArguments = ["-debugRoute", "levelsong:hollow-1", "-debugShort", "-debugAutomation"]
        app.launch()
        defer { app.terminate() }
        let sing = app.buttons["Let's sing!"]
        XCTAssertTrue(sing.waitForExistence(timeout: 20))
        // Past the dedication, which covers the first screen at launch.
        let deadline = Date().addingTimeInterval(15)
        while !sing.isHittable && Date() < deadline {
            app.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5)).tap()
            RunLoop.current.run(until: Date().addingTimeInterval(0.5))
        }
        sing.tap()
        let onward = app.buttons["On to the level"]
        XCTAssertTrue(onward.waitForExistence(timeout: 60), "one round of three lines, then the level's button")
        onward.tap()
        XCTAssertTrue(app.otherElements["playtest-state"].waitForExistence(timeout: 20), "the level itself starts")
    }

    @MainActor func testHatchlingHollowThroughControls() throws {
        try play(["hollow-1", "hollow-2", "hollow-3", "hollow-4", "hollow-5"])
    }
    @MainActor func testAllLevelsThroughControls() throws {
        try play(Catalog.shared.allLevels.map(\.id))
    }
    @MainActor private func play(_ levels: [String]) throws {
        continueAfterFailure = false
        XCUIDevice.shared.orientation = .landscapeLeft
        for level in levels {
            let app = XCUIApplication()
            app.launchArguments = ["-debugLevel", level, "-debugShort", "-debugAutomation"]
            app.launch()
            defer { app.terminate() }
            let state = app.otherElements["playtest-state"]
            XCTAssertTrue(state.waitForExistence(timeout: 20))
            let deadline = Date().addingTimeInterval(120)
            var typed = -1
            var finished = false
            while Date() < deadline {
                RunLoop.current.run(until: Date().addingTimeInterval(0.15))
                let skip = app.buttons["Skip"]
                if skip.exists && skip.isHittable { skip.tap(); continue }
                guard let raw = state.value as? String, let data = raw.data(using: .utf8),
                      let s = try JSONSerialization.jsonObject(with: data) as? [String: Any] else { continue }
                if s["finished"] as? Bool == true { XCTAssertEqual(s["stars"] as? Int, 3, level); finished = true; break }
                func tap(_ p: [String: Double]) {
                    app.coordinate(withNormalizedOffset: .zero).withOffset(CGVector(dx: p["x"] ?? 0, dy: p["y"] ?? 0)).tap()
                }
                if let p = s["powerButton"] as? [String: Double] { tap(p) }
                else if let p = s["crystal"] as? [String: Double] { tap(p) }
                else if s["ready"] as? Bool == true {
                    let choices = s["choices"] as? [String] ?? []
                    let targets = s["targets"] as? [[String: Double]] ?? []
                    if !choices.isEmpty, let answer = s["choice"] as? String, let index = choices.firstIndex(of: answer),
                       targets.indices.contains(index) { tap(targets[index]) }
                    else if s["format"] as? String == "choice", let answer = s["choice"] as? String,
                            let count = s["completed"] as? Int, typed != count {
                        // Picked answers in pick-or-type modes are buttons below the scene.
                        let button = app.buttons.matching(NSPredicate(format: "label == %@", answer)).firstMatch
                        XCTAssertTrue(button.exists || button.waitForExistence(timeout: 5), "Missing answer button \(answer) in \(level)")
                        button.tap()
                        typed = count
                    }
                    else if s["format"] as? String == "typed", let target = s["typed"] as? String, !target.isEmpty,
                            let count = s["completed"] as? Int, typed != count {
                        for digit in target {
                            let label = String(digit)
                            let key = app.buttons.matching(NSPredicate(format: "label ==[c] %@", label)).firstMatch
                            XCTAssertTrue(key.exists || key.waitForExistence(timeout: 5), "Missing key \(label) in \(level)")
                            key.tap()
                        }
                        typed = count
                    }
                }
            }
            let attachment = XCTAttachment(screenshot: app.screenshot()); attachment.name = level; attachment.lifetime = .keepAlways; add(attachment)
            XCTAssertTrue(finished, "Level did not reach results: \(level)")
        }
    }
}
