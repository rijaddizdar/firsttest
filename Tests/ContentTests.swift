//
//  ContentTests.swift
//  The bundled content must load, and a broken lesson must fail with a message
//  a writer can act on. These are the two things that decide whether "writers
//  add lessons without code changes" actually holds.
//

import XCTest
@testable import MoneyPals

final class ContentTests: XCTestCase {

    /// Everything in App/Content loads, validates and is reachable.
    func testBundledContentLoadsCleanly() throws {
        let library = try CurriculumLibrary.load(from: .main)
        XCTAssertTrue(library.issues.isEmpty, "content issues: \(library.issues)")
        XCTAssertFalse(library.worlds.isEmpty)
        XCTAssertNotNil(library.lesson("needs-and-wants-1"))
    }

    /// World 1 is written: three levels, five lessons each, and the scaffold
    /// sample from the foundation PR is gone.
    func testWorldOneIsFullyWritten() throws {
        let library = try CurriculumLibrary.load(from: .main)
        XCTAssertNil(library.lesson("sample-screen-types"), "the SAMPLE lesson was replaced")

        for levelID in 1...3 {
            let lessons = library.lessons(inLevel: levelID)
            XCTAssertEqual(lessons.count, 5, "level \(levelID) should have 5 lessons")
            for lesson in lessons {
                XCTAssertFalse(lesson.isSample, "\(lesson.id) is still marked sample")
                XCTAssertEqual(lesson.levelID, levelID)
                XCTAssertTrue((6...8).contains(lesson.screens.count),
                              "\(lesson.id) has \(lesson.screens.count) screens; README section 3 says 6-8")
                XCTAssertGreaterThanOrEqual(lesson.questionScreens.count, 3,
                                            "\(lesson.id) should give a child several goes")
            }
        }
    }

    /// README section 3: "Every screen shows a picture." Nothing in World 1 may
    /// ask for art that is not in the catalog, and every question screen must
    /// carry at least one picture of its own (a Hello or Yay! screen shows
    /// Penny, who is not an icon).
    func testEveryWorldOneScreenHasItsPictures() throws {
        let library = try CurriculumLibrary.load(from: .main)
        for levelID in 1...3 {
            for lesson in library.lessonsAndCheck(inLevel: levelID) {
                for screen in lesson.screens {
                    for icon in screen.iconNames {
                        XCTAssertTrue(ContentArt.exists(icon),
                                      "\(lesson.id): missing picture \"\(icon)\"")
                    }
                    if screen.isQuestion {
                        XCTAssertFalse(screen.iconNames.isEmpty,
                                       "\(lesson.id) screen \(screen.id) has no picture")
                    }
                }
            }
        }
    }

    /// Every lesson uses {name} where Penny speaks first, and no kid-facing
    /// line uses the words README section 7 rule 5 bans.
    func testWorldOneToneRules() throws {
        let library = try CurriculumLibrary.load(from: .main)
        let banned = ["wrong", "fail", "bad ", "hurry", "stupid", "lost your streak"]
        for levelID in 1...3 {
            for lesson in library.lessonsAndCheck(inLevel: levelID) {
                guard case .hello(let hello) = lesson.screens.first else {
                    return XCTFail("\(lesson.id) does not open on a hello screen")
                }
                XCTAssertTrue(hello.penny.contains("{name}"), "\(lesson.id) never says the child's name")

                for screen in lesson.screens {
                    for line in screen.kidFacingText {
                        let lower = line.lowercased()
                        for word in banned {
                            XCTAssertFalse(lower.contains(word),
                                           "\(lesson.id) says \"\(word.trimmingCharacters(in: .whitespaces))\": \(line)")
                        }
                    }
                }
            }
        }
    }

    /// A wrong answer is always encouragement plus a hint, never a bare "no".
    func testEveryQuestionHasAKindWrongAnswer() throws {
        let library = try CurriculumLibrary.load(from: .main)
        for levelID in 1...3 {
            for lesson in library.lessons(inLevel: levelID) {
                for screen in lesson.questionScreens {
                    let message = screen.wrongMessageText ?? ""
                    XCTAssertFalse(message.isEmpty, "\(lesson.id)/\(screen.id) has no try-again line")
                    XCTAssertTrue(message.contains("{name}"),
                                  "\(lesson.id)/\(screen.id) does not use the child's name")
                    // "Good try" / "Nice try" — kind first, hint second.
                    XCTAssertTrue(message.lowercased().hasPrefix("good try")
                                  || message.lowercased().hasPrefix("nice try"),
                                  "\(lesson.id)/\(screen.id) does not open kindly: \(message)")
                }
            }
        }
    }

    /// The ported lesson still says what it said when it was hard-coded.
    func testPortedLessonKeepsItsContent() throws {
        let library = try CurriculumLibrary.load(from: .main)
        let lesson = try XCTUnwrap(library.lesson("needs-and-wants-1"))
        XCTAssertEqual(lesson.levelID, 2)
        XCTAssertFalse(lesson.isSample)
        XCTAssertEqual(lesson.coins, 10)

        guard case .hello(let hello) = lesson.screens.first else {
            return XCTFail("a lesson opens on a hello screen")
        }
        XCTAssertEqual(hello.penny, "Hi, {name}! Today we'll learn about needs and wants!")

        XCTAssertEqual(lesson.questionScreens.count, 3, "plus README section 4's Sort it step")
        guard case .tapToChoose(let question) = lesson.screens[2] else {
            return XCTFail("screen 3 is the coat question")
        }
        XCTAssertEqual(question.prompt, "It's snowing outside. Is a warm coat a need or a want?")
        XCTAssertEqual(question.choices.first(where: \.correct)?.label, "Need")
    }

    /// The brief for World 1 was "use the full mix of screen types", so every
    /// screen type in README section 3 must actually appear in every level.
    func testEveryLevelUsesTheFullMixOfScreenTypes() throws {
        let library = try CurriculumLibrary.load(from: .main)
        for levelID in 1...3 {
            let kinds = Set(library.lessons(inLevel: levelID).flatMap { $0.screens.map(\.kindName) })
            XCTAssertEqual(kinds,
                           ["hello", "learn", "tapToChoose", "sortIt", "storyChoice", "countIt", "yay"],
                           "level \(levelID) is missing a screen type: \(kinds.sorted())")
        }
    }

    // MARK: Validation

    func testQuestionWithNoRightAnswerIsRejected() throws {
        let lesson = try decode(lessonJSON(choices: """
        [{"label": "Need", "icon": "thumbs-up"}, {"label": "Want", "icon": "balloon"}]
        """))
        let problems = lesson.validationProblems(expectedID: "test-lesson", knownLevelIDs: [2])
        XCTAssertTrue(problems.contains { $0.contains("no choice marked") }, "got \(problems)")
    }

    func testUnknownIconIsRejected() throws {
        let lesson = try decode(lessonJSON(choices: """
        [{"label": "Need", "icon": "not-a-real-picture", "correct": true},
         {"label": "Want", "icon": "balloon"}]
        """))
        let problems = lesson.validationProblems(expectedID: "test-lesson", knownLevelIDs: [2])
        XCTAssertTrue(problems.contains { $0.contains("not-a-real-picture") }, "got \(problems)")
    }

    func testLessonMustEndOnACelebration() throws {
        let json = """
        {"id": "test-lesson", "levelID": 2, "title": "Test",
         "screens": [{"type": "hello", "penny": "Hi, {name}!"}]}
        """
        let lesson = try decode(json)
        let problems = lesson.validationProblems(expectedID: "test-lesson", knownLevelIDs: [2])
        XCTAssertTrue(problems.contains { $0.contains("yay screen") }, "got \(problems)")
    }

    func testMismatchedFileNameIsRejected() throws {
        let lesson = try decode(lessonJSON())
        let problems = lesson.validationProblems(expectedID: "some-other-name", knownLevelIDs: [2])
        XCTAssertTrue(problems.contains { $0.contains("they must match") }, "got \(problems)")
    }

    /// The pile and the tray are single rows, so content that would run off a
    /// phone is a load-time problem, not something to discover in a screenshot.
    func testTooManyCoinsForOneRowIsRejected() throws {
        let json = """
        {"id": "test-lesson", "levelID": 2, "title": "Test", "screens": [
          {"type": "hello", "penny": "Hi, {name}!"},
          {"type": "countIt", "prompt": "Count", "pennyHint": "Count, {name}",
           "available": 12, "target": 5, "rightMessage": "Yes", "wrongMessage": "Good try"},
          {"type": "yay"}]}
        """
        let problems = try decode(json).validationProblems(expectedID: "test-lesson", knownLevelIDs: [2])
        XCTAssertTrue(problems.contains { $0.contains("one row") }, "got \(problems)")
    }

    func testTooManyPicturesToSortIsRejected() throws {
        let items = (1...6).map {
            """
            {"id": "i\($0)", "label": "Item \($0)", "icon": "coin", "groupID": "\($0 < 4 ? "a" : "b")"}
            """
        }.joined(separator: ",")
        let json = """
        {"id": "test-lesson", "levelID": 2, "title": "Test", "screens": [
          {"type": "hello", "penny": "Hi, {name}!"},
          {"type": "sortIt", "prompt": "Sort", "pennyHint": "Sort, {name}",
           "groups": [{"id": "a", "title": "A", "tint": "teal"}, {"id": "b", "title": "B", "tint": "copper"}],
           "items": [\(items)],
           "rightMessage": "Yes", "wrongMessage": "Good try", "doneMessage": "Done"},
          {"type": "yay"}]}
        """
        let problems = try decode(json).validationProblems(expectedID: "test-lesson", knownLevelIDs: [2])
        XCTAssertTrue(problems.contains { $0.contains("one row") }, "got \(problems)")
    }

    func testCountItCannotAskForMoreCoinsThanItGives() throws {
        let json = """
        {"id": "test-lesson", "levelID": 2, "title": "Test", "screens": [
          {"type": "hello", "penny": "Hi, {name}!"},
          {"type": "countIt", "prompt": "Count", "pennyHint": "Count, {name}",
           "available": 3, "target": 5, "rightMessage": "Yes", "wrongMessage": "Good try"},
          {"type": "yay"}]}
        """
        let lesson = try decode(json)
        let problems = lesson.validationProblems(expectedID: "test-lesson", knownLevelIDs: [2])
        XCTAssertTrue(problems.contains { $0.contains("only 3 are available") }, "got \(problems)")
    }

    /// A missing field names itself, so a writer knows what to add.
    func testDecodingErrorNamesTheMissingField() {
        let json = """
        {"id": "test-lesson", "levelID": 2, "title": "Test", "screens": [
          {"type": "tapToChoose", "pennyHint": "Look, {name}!", "choices": [],
           "rightMessage": "Yes", "wrongMessage": "Good try"}]}
        """
        XCTAssertThrowsError(try JSONDecoder().decode(Lesson.self, from: Data(json.utf8))) { error in
            guard case DecodingError.keyNotFound(let key, _) = error else {
                return XCTFail("expected a missing-key error, got \(error)")
            }
            XCTAssertEqual(key.stringValue, "prompt")
        }
    }

    /// Screens without an id get a stable one from their position, so progress
    /// and the retry queue always have something to key on.
    func testScreensWithoutIDsGetPositionalOnes() throws {
        let lesson = try decode(lessonJSON())
        XCTAssertEqual(lesson.screens.first?.id, "hello-1")
        XCTAssertEqual(lesson.screens.last?.id, "yay-3")
    }

    // MARK: Helpers

    private func decode(_ json: String) throws -> Lesson {
        try JSONDecoder().decode(Lesson.self, from: Data(json.utf8))
    }

    private func lessonJSON(choices: String = """
    [{"label": "Need", "icon": "thumbs-up", "correct": true}, {"label": "Want", "icon": "balloon"}]
    """) -> String {
        """
        {"id": "test-lesson", "levelID": 2, "title": "Test", "screens": [
          {"type": "hello", "penny": "Hi, {name}!"},
          {"type": "tapToChoose", "id": "q1", "prompt": "Need or want?",
           "pennyHint": "Look, {name}!", "choices": \(choices),
           "rightMessage": "Yes, {name}!", "wrongMessage": "Good try, {name}!"},
          {"type": "yay"}]}
        """
    }
}
