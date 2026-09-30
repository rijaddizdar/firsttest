//
//  LevelCheckTests.swift
//  The friendly end-of-level check (README section 3): it mixes that level's
//  questions, it cannot be failed, and a child retries until they get it.
//
//  The "cannot be failed" part is the one worth pinning down: there is no pass
//  mark anywhere, a wrong answer never advances and never ends the check, and
//  however many goes a child takes they still finish with stars and coins.
//

import XCTest
@testable import MoneyPals

final class LevelCheckTests: XCTestCase {

    private var library: CurriculumLibrary!

    override func setUpWithError() throws {
        library = try CurriculumLibrary.load(from: .main)
    }

    // MARK: Shape

    func testEveryWrittenLevelHasACheckAndEmptyOnesDoNot() throws {
        for levelID in library.levels.filter(\.hasLessons).map(\.id) {
            let check = try XCTUnwrap(library.levelCheck(forLevel: levelID),
                                      "level \(levelID) should have a check")
            XCTAssertEqual(check.id, "level-\(levelID)-check")
            XCTAssertEqual(check.levelID, levelID)
            XCTAssertTrue(check.isLevelCheck)
            XCTAssertFalse(check.isSample)
        }
        // A check exists exactly where lessons do — wherever the written
        // worlds happen to end today.
        for level in library.levels where !level.hasLessons {
            XCTAssertNil(library.levelCheck(forLevel: level.id),
                         "level \(level.id) has no lessons, so it must have no check")
        }
    }

    /// It opens on a hello, ends on a celebration and is a valid lesson in
    /// every other way — it goes through the same player as anything else.
    func testACheckIsAValidPlayableLesson() throws {
        let check = try XCTUnwrap(library.levelCheck(forLevel: 1))
        let problems = check.validationProblems(expectedID: check.id, knownLevelIDs: Set(1...13))
        XCTAssertTrue(problems.isEmpty, "got \(problems)")
        XCTAssertEqual(check.screens.first?.kindName, "hello")
        XCTAssertEqual(check.screens.last?.kindName, "yay")
        XCTAssertEqual(check.questionScreens.count, CurriculumLibrary.levelCheckQuestionCount)
    }

    /// Looked up by id like any lesson, so saved progress and the UITEST hooks
    /// treat it the same.
    func testACheckCanBeLookedUpById() {
        XCTAssertEqual(library.lesson("level-2-check")?.id, "level-2-check")
        XCTAssertNil(library.lesson("level-9-check"), "level 9 has no lessons yet")
        XCTAssertNil(library.lesson("level-two-check"), "not a check id")
        XCTAssertNil(library.lesson("level-2-quiz"))
    }

    // MARK: The mix

    /// "Mixes questions from its lessons" — so it must draw on more than one,
    /// and each question must really come from that level.
    func testTheCheckMixesQuestionsFromSeveralLessons() throws {
        for levelID in library.levels.filter(\.hasLessons).map(\.id) {
            let check = try XCTUnwrap(library.levelCheck(forLevel: levelID))
            let sources = Set(check.questionScreens.compactMap { $0.id.split(separator: "/").first })
            XCTAssertEqual(sources.count, CurriculumLibrary.levelCheckQuestionCount,
                           "level \(levelID) should take one question from each of several lessons")

            let lessonIDs = Set(library.lessons(inLevel: levelID).map(\.id))
            for source in sources {
                XCTAssertTrue(lessonIDs.contains(String(source)),
                              "\(source) is not a lesson of level \(levelID)")
            }
        }
    }

    /// One from each lesson in turn, so the check spreads across the level
    /// rather than re-running its first lesson.
    func testQuestionsAreTakenOneFromEachLessonInTurn() throws {
        let lessons = library.lessons(inLevel: 3)
        let mixed = CurriculumLibrary.mixedQuestions(from: lessons, limit: 4)
        let sources = mixed.map { String($0.id.split(separator: "/")[0]) }
        XCTAssertEqual(sources, lessons.prefix(4).map(\.id))
    }

    /// A second round only starts once every lesson has given one question.
    func testASecondRoundOnlyStartsAfterEveryLessonHasGivenOne() throws {
        let lessons = library.lessons(inLevel: 1)
        let mixed = CurriculumLibrary.mixedQuestions(from: lessons, limit: 7)
        let sources = mixed.map { String($0.id.split(separator: "/")[0]) }
        XCTAssertEqual(Array(sources.prefix(5)), lessons.map(\.id))
        XCTAssertEqual(Array(sources.dropFirst(5)), Array(lessons.prefix(2).map(\.id)))
    }

    /// Two lessons may each name a question "q1", so borrowed ids are
    /// namespaced — otherwise the retry queue would confuse them.
    func testBorrowedQuestionIdsStayUnique() throws {
        for levelID in library.levels.filter(\.hasLessons).map(\.id) {
            let check = try XCTUnwrap(library.levelCheck(forLevel: levelID))
            let ids = check.screens.map(\.id)
            XCTAssertEqual(Set(ids).count, ids.count, "level \(levelID) repeats a screen id")
        }
    }

    /// The same child coming back to the same check meets the same questions.
    func testTheMixIsStableBetweenRuns() throws {
        let first = try XCTUnwrap(library.levelCheck(forLevel: 2)).screens.map(\.id)
        let again = try XCTUnwrap(library.levelCheck(forLevel: 2)).screens.map(\.id)
        XCTAssertEqual(first, again)
    }

    // MARK: It cannot be failed

    /// However badly a check goes, it still finishes, and it still pays out.
    @MainActor
    func testACheckCannotBeFailedHoweverManyGoesItTakes() throws {
        let check = try XCTUnwrap(library.levelCheck(forLevel: 2))
        let runner = LessonRunner(lesson: check, kidName: "Mia")

        runner.advance()   // past the hello
        var guard_ = 0
        while !runner.isFinished, guard_ < 200 {
            guard_ += 1
            if let screen = runner.screen, screen.isQuestion {
                // Get it wrong three times, then right. Nothing ends the check.
                for _ in 0..<3 {
                    runner.wrong(message: "Good try, {name}!")
                    XCTAssertFalse(runner.canAdvance, "a wrong answer never moves a child on")
                    XCTAssertFalse(runner.isFinished, "and never ends the check")
                }
                runner.right(message: "Yes, {name}!")
                XCTAssertTrue(runner.canAdvance)
            }
            runner.advance()
        }

        XCTAssertTrue(runner.isFinished, "the check always reaches the celebration")
        XCTAssertGreaterThanOrEqual(runner.stars, 1, "nobody ever finishes with no stars")
        XCTAssertEqual(runner.coins, 15, "and the play coins are paid out regardless")
    }

    /// A missed question comes back later in the check, exactly as in a lesson.
    @MainActor
    func testAMissedQuestionComesBackInsideTheCheck() throws {
        let check = try XCTUnwrap(library.levelCheck(forLevel: 1))
        let runner = LessonRunner(lesson: check, kidName: "Mia")
        runner.advance()

        let before = runner.plan.count
        let missed = try XCTUnwrap(runner.screen?.id)
        runner.wrong()
        XCTAssertEqual(runner.plan.count, before + 1)

        let ids = runner.plan.map { runner.lesson.screens[$0].id }
        XCTAssertEqual(ids.last, "yay", "the check still ends on the celebration")
        XCTAssertEqual(ids.dropLast().last, missed, "the missed question comes back just before it")
    }

    /// A clean run is worth three stars, like any lesson.
    @MainActor
    func testACleanRunEarnsThreeStars() throws {
        let check = try XCTUnwrap(library.levelCheck(forLevel: 3))
        let runner = LessonRunner(lesson: check, kidName: "Mia")
        XCTAssertEqual(runner.stars, 3)
        XCTAssertEqual(runner.lesson.title, "Earning Money Check")
    }
}
