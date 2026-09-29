//
//  CurriculumProgressTests.swift
//  How the map and the per-level lesson list read a child's progress: which
//  level is current, what a level's star rating is, where the friendly level
//  check sits in the order, and the rule that a level with no lessons written
//  yet is shown but never blocks the path.
//

import XCTest
@testable import MoneyPals

final class CurriculumProgressTests: XCTestCase {

    private var library: CurriculumLibrary!

    /// World 1 level 2, as the content now ships it.
    private let levelTwoLessons = ["needs-and-wants-1", "needs-and-wants-2", "needs-and-wants-3",
                                   "needs-and-wants-4", "needs-and-wants-5"]

    override func setUpWithError() throws {
        library = try CurriculumLibrary.load(from: .main)
    }

    /// Every lesson of a level finished, but not its check.
    private func lessonsDone(_ levelID: Int, stars: Int = 3) -> [String: Int] {
        Dictionary(uniqueKeysWithValues: library.lessons(inLevel: levelID).map { ($0.id, stars) })
    }

    /// Everything in a level finished, check included.
    private func levelDone(_ levelID: Int, stars: Int = 3) -> [String: Int] {
        Dictionary(uniqueKeysWithValues: library.lessonsAndCheck(inLevel: levelID).map { ($0.id, stars) })
    }

    // MARK: The map

    func testAFreshChildStartsOnTheFirstLevel() {
        let states = library.levelStates(starsByLesson: [:])
        XCTAssertEqual(library.unlockedThrough(starsByLesson: [:]), 1,
                       "World 1 is written now, so level 1 is where a child starts")
        XCTAssertEqual(states[1], .current)
        XCTAssertEqual(states[2], .locked)
    }

    func testHalfFinishingALevelDoesNotUnlockTheNextOne() {
        let progress = ["needs-and-wants-1": 3]
        XCTAssertFalse(library.isLevelComplete(2, starsByLesson: progress))
        XCTAssertEqual(library.stars(forLevel: 2, starsByLesson: progress), 0,
                       "a level is only rated once every step in it is done")
    }

    func testFinishingEveryStepMovesTheFrontierOnByOne() {
        let progress = levelDone(1)
        let states = library.levelStates(starsByLesson: progress)
        XCTAssertEqual(states[1], .completed)
        XCTAssertEqual(states[2], .current)
        XCTAssertEqual(states[3], .locked, "the path doesn't spring open to the end")
    }

    /// Level 4 onward has no lessons yet, so finishing World 1 must not
    /// dead-end the map.
    func testAnUnwrittenLevelIsShownButNeverBlocks() {
        var progress: [String: Int] = [:]
        for levelID in 1...3 { progress.merge(levelDone(levelID)) { a, _ in a } }
        let states = library.levelStates(starsByLesson: progress)
        XCTAssertEqual(states[3], .completed)
        XCTAssertEqual(states[4], .current, "shown as Coming soon, not locked")
    }

    func testALevelIsRatedByTheAverageOfItsSteps() {
        XCTAssertEqual(library.stars(forLevel: 2, starsByLesson: levelDone(2, stars: 3)), 3)
        XCTAssertEqual(library.stars(forLevel: 2, starsByLesson: levelDone(2, stars: 1)), 1)

        // One weak result pulls the average down but never below one star.
        var mixed = levelDone(2, stars: 3)
        mixed["needs-and-wants-1"] = 1
        XCTAssertEqual(library.stars(forLevel: 2, starsByLesson: mixed), 2)
    }

    func testStepsFinishedCountsTheCheckToo() {
        let progress = lessonsDone(2)
        let counted = library.stepsFinished(inLevel: 2, starsByLesson: progress)
        XCTAssertEqual(counted.total, 6, "five lessons plus the level check")
        XCTAssertEqual(counted.done, 5, "the check is still to play")
    }

    // MARK: The per-level lesson list

    func testALevelListsItsLessonsInOrderThenTheCheck() {
        let steps = library.lessonsAndCheck(inLevel: 2).map(\.id)
        XCTAssertEqual(steps, levelTwoLessons + ["level-2-check"])
    }

    func testAnUnwrittenLevelHasNoStepsAndNoCheck() {
        XCTAssertTrue(library.lessonsAndCheck(inLevel: 4).isEmpty)
        XCTAssertNil(library.levelCheck(forLevel: 4))
    }

    func testTheNextStepWalksTheLessonsThenTheCheck() {
        XCTAssertEqual(library.nextLesson(inLevel: 2, starsByLesson: [:])?.id, "needs-and-wants-1")
        XCTAssertEqual(library.nextLesson(inLevel: 2, starsByLesson: ["needs-and-wants-1": 3])?.id,
                       "needs-and-wants-2")
        XCTAssertEqual(library.nextLesson(inLevel: 2, starsByLesson: lessonsDone(2))?.id,
                       "level-2-check", "the check is the last step of the level")
        XCTAssertEqual(library.nextLesson(inLevel: 2, starsByLesson: levelDone(2))?.id,
                       "needs-and-wants-1", "a finished level replays from the start")
        XCTAssertNil(library.nextLesson(inLevel: 4, starsByLesson: [:]), "nothing written there yet")
    }

    /// Lessons are always playable in any order. Only the check waits, because
    /// it has nothing to mix until the lessons have been seen.
    func testOnlyTheCheckEverWaits() throws {
        let check = try XCTUnwrap(library.levelCheck(forLevel: 2))
        for lesson in library.lessons(inLevel: 2) {
            XCTAssertTrue(library.isPlayable(lesson, starsByLesson: [:]))
        }
        XCTAssertFalse(library.isPlayable(check, starsByLesson: [:]))
        XCTAssertFalse(library.isPlayable(check, starsByLesson: ["needs-and-wants-1": 3]))
        XCTAssertTrue(library.isPlayable(check, starsByLesson: lessonsDone(2)))
    }
}
