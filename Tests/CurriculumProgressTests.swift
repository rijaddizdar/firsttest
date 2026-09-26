//
//  CurriculumProgressTests.swift
//  How the map reads a child's progress: which level is current, what a level's
//  star rating is, and the rule that a level with no lessons written yet is
//  shown but never blocks the path.
//

import XCTest
@testable import MoneyPals

final class CurriculumProgressTests: XCTestCase {

    private var library: CurriculumLibrary!

    override func setUpWithError() throws {
        library = try CurriculumLibrary.load(from: .main)
    }

    func testAFreshChildStartsOnTheFirstLevelThatHasLessons() {
        let states = library.levelStates(starsByLesson: [:])
        XCTAssertEqual(library.unlockedThrough(starsByLesson: [:]), 2)
        XCTAssertEqual(states[1], .open, "level 1 isn't written yet: shown, not blocking")
        XCTAssertEqual(states[2], .current)
        XCTAssertEqual(states[3], .locked)
    }

    func testHalfFinishingALevelDoesNotUnlockTheNextOne() {
        let progress = ["needs-and-wants-1": 3]
        XCTAssertFalse(library.isLevelComplete(2, starsByLesson: progress))
        XCTAssertEqual(library.unlockedThrough(starsByLesson: progress), 2)
        XCTAssertEqual(library.stars(forLevel: 2, starsByLesson: progress), 0,
                       "a level is only rated once all of its lessons are done")
    }

    func testFinishingEveryLessonMovesTheFrontierOnByOne() {
        let progress = ["needs-and-wants-1": 3, "sample-screen-types": 3]
        let states = library.levelStates(starsByLesson: progress)
        XCTAssertEqual(states[2], .completed)
        XCTAssertEqual(states[3], .current, "the next level in line, even though it's empty")
        XCTAssertEqual(states[4], .locked, "the path doesn't spring open to the end")
    }

    func testALevelIsRatedByTheAverageOfItsLessons() {
        XCTAssertEqual(library.stars(forLevel: 2,
                                     starsByLesson: ["needs-and-wants-1": 3, "sample-screen-types": 3]), 3)
        XCTAssertEqual(library.stars(forLevel: 2,
                                     starsByLesson: ["needs-and-wants-1": 3, "sample-screen-types": 2]), 2)
        XCTAssertEqual(library.stars(forLevel: 2,
                                     starsByLesson: ["needs-and-wants-1": 1, "sample-screen-types": 1]), 1)
    }

    func testTappingALevelOpensTheFirstUnfinishedLesson() {
        XCTAssertEqual(library.nextLesson(inLevel: 2, starsByLesson: [:])?.id, "needs-and-wants-1")
        XCTAssertEqual(library.nextLesson(inLevel: 2, starsByLesson: ["needs-and-wants-1": 3])?.id,
                       "sample-screen-types")
        XCTAssertEqual(library.nextLesson(inLevel: 2,
                                          starsByLesson: ["needs-and-wants-1": 3, "sample-screen-types": 3])?.id,
                       "needs-and-wants-1", "a finished level replays from the start")
        XCTAssertNil(library.nextLesson(inLevel: 1, starsByLesson: [:]), "nothing written there yet")
    }
}
