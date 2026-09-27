//
//  LessonRunnerTests.swift
//  The engine rules from README section 3 that aren't visual: what a right and a
//  wrong answer do, a missed question coming back later in the lesson, and the
//  stars a run is worth.
//

import XCTest
@testable import MoneyPals

@MainActor
final class LessonRunnerTests: XCTestCase {

    // MARK: Walking a lesson

    func testStartsOnTheHelloScreenAndCanMoveOn() throws {
        let runner = try makeRunner()
        XCTAssertEqual(runner.screen?.kindName, "hello")
        XCTAssertTrue(runner.canAdvance, "nothing to answer on a hello screen")
        XCTAssertEqual(runner.pennyLine, "Hi, Mia!", "Penny greets the child by name")
    }

    func testQuestionBlocksUntilItIsAnsweredRight() throws {
        let runner = try makeRunner()
        runner.advance()
        XCTAssertEqual(runner.screen?.id, "q1")
        XCTAssertFalse(runner.canAdvance)

        runner.wrong(message: "Good try, {name}!")
        XCTAssertEqual(runner.outcome, .wrong)
        XCTAssertFalse(runner.canAdvance, "a wrong answer never moves the child on")
        XCTAssertEqual(runner.pennyLine, "Good try, Mia!")

        runner.right(message: "Yes, {name}!")
        XCTAssertEqual(runner.outcome, .right)
        XCTAssertTrue(runner.canAdvance)
        XCTAssertEqual(runner.pennyMood, .cheer)
    }

    // MARK: The retry queue

    func testAMissedQuestionComesBackLaterInTheLesson() throws {
        let runner = try makeRunner()
        let plannedBefore = runner.plan.count
        runner.advance()                       // q1
        runner.wrong()
        XCTAssertEqual(runner.plan.count, plannedBefore + 1, "the question is queued again")
        XCTAssertEqual(runner.questionCount, 3, "and it counts as another question")

        // It lands before the celebration, never after it.
        let ids = runner.plan.map { runner.lesson.screens[$0].id }
        XCTAssertEqual(ids.last, "yay-4")
        XCTAssertEqual(ids.dropLast().last, "q1")
    }

    func testAQuestionOnlyComesBackOnce() throws {
        let runner = try makeRunner()
        runner.advance()
        runner.wrong()
        runner.wrong()
        runner.wrong()
        XCTAssertEqual(runner.plan.count, runner.lesson.screens.count + 1,
                       "three wrong taps still only queue one comeback")
    }

    func testTheComebackIsMarkedAsARepeat() throws {
        let runner = try makeRunner()
        runner.advance()                       // q1
        runner.wrong()
        runner.right()
        runner.advance()                       // q2
        runner.right()
        runner.advance()                       // q1 again
        XCTAssertEqual(runner.screen?.id, "q1")
        XCTAssertTrue(runner.isRepeat)
        XCTAssertEqual(runner.pennyLine, "Here's that one again, Mia. You've got this!")
    }

    // MARK: Stars

    func testCleanRunEarnsThreeStars() throws {
        let runner = try makeRunner()
        runner.advance()
        runner.right()
        XCTAssertEqual(runner.stars, 3)
    }

    func testEveryWrongTapCostsAStarButNeverTheLastOne() throws {
        let runner = try makeRunner()
        runner.advance()
        runner.wrong()
        XCTAssertEqual(runner.stars, 2)
        runner.wrong()
        XCTAssertEqual(runner.stars, 1)
        runner.wrong()
        runner.wrong()
        XCTAssertEqual(runner.stars, 1, "a child never finishes a lesson with no stars")
    }

    func testTimeSpentIsAtLeastAMinute() throws {
        let runner = try makeRunner()
        XCTAssertEqual(runner.minutesSpent, 1)
    }

    // MARK: Question numbering

    func testQuestionNumbersCountOnlyQuestions() throws {
        let runner = try makeRunner()
        XCTAssertNil(runner.questionNumber, "a hello screen isn't question 1")
        XCTAssertEqual(runner.topBarTitle, "Test lesson")
        runner.advance()
        XCTAssertEqual(runner.questionNumber, 1)
        XCTAssertEqual(runner.topBarTitle, "Question 1 of 2")
    }

    // MARK: Helpers

    private func makeRunner(kidName: String = "Mia") throws -> LessonRunner {
        let json = """
        {"id": "test-lesson", "levelID": 2, "title": "Test lesson", "screens": [
          {"type": "hello", "penny": "Hi, {name}!"},
          {"type": "tapToChoose", "id": "q1", "prompt": "Need or want?",
           "pennyHint": "Look, {name}!",
           "choices": [{"label": "Need", "icon": "thumbs-up", "correct": true},
                       {"label": "Want", "icon": "balloon"}],
           "rightMessage": "Yes, {name}!", "wrongMessage": "Good try, {name}!"},
          {"type": "tapToChoose", "id": "q2", "prompt": "Need or want?",
           "pennyHint": "Think, {name}!",
           "choices": [{"label": "Need", "icon": "droplet", "correct": true},
                       {"label": "Want", "icon": "balloon"}],
           "rightMessage": "That's it, {name}!", "wrongMessage": "Good try, {name}!"},
          {"type": "yay"}]}
        """
        let lesson = try JSONDecoder().decode(Lesson.self, from: Data(json.utf8))
        return LessonRunner(lesson: lesson, kidName: kidName)
    }
}
