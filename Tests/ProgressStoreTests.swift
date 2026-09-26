//
//  ProgressStoreTests.swift
//  What has to survive quitting the app: kids, their progress, the streak rules
//  and the parent code — the last of which must never be recoverable from the
//  store (README section 9).
//

import XCTest
import SwiftData
@testable import MoneyPals

@MainActor
final class ProgressStoreTests: XCTestCase {

    private var container: ModelContainer!
    private var store: ProgressStore!
    private var library: CurriculumLibrary!

    override func setUpWithError() throws {
        container = PersistenceController.makeContainer(environment: ["UITEST_STORE": "memory"])
        store = ProgressStore(context: container.mainContext)
        library = try CurriculumLibrary.load(from: .main)
    }

    // MARK: Kids and progress

    func testAKidAndTheirProgressAreSaved() throws {
        let id = store.addKid(name: "Mia", kind: .girl, colorIndex: 0)
        store.recordCompletion(kidID: id, lessonID: "needs-and-wants-1", levelID: 2,
                               stars: 3, coins: 10, minutes: 4)

        // A second store over the same data is what a relaunch looks like.
        let reopened = ProgressStore(context: container.mainContext)
        let kid = try XCTUnwrap(reopened.kids(using: library).first)
        XCTAssertEqual(kid.name, "Mia")
        XCTAssertEqual(kid.coins, 10)
        XCTAssertEqual(kid.starsByLesson["needs-and-wants-1"], 3)
        XCTAssertEqual(kid.minutesToday, 4)
        XCTAssertEqual(kid.currentStreak, 1)
    }

    func testReplayingALessonKeepsTheBestStars() throws {
        let id = store.addKid(name: "Mia", kind: .girl, colorIndex: 0)
        store.recordCompletion(kidID: id, lessonID: "needs-and-wants-1", levelID: 2,
                               stars: 3, coins: 10, minutes: 3)
        store.recordCompletion(kidID: id, lessonID: "needs-and-wants-1", levelID: 2,
                               stars: 1, coins: 10, minutes: 3)
        let kid = try XCTUnwrap(store.kids(using: library).first)
        XCTAssertEqual(kid.starsByLesson["needs-and-wants-1"], 3, "a worse replay never takes stars away")
        XCTAssertEqual(kid.coins, 20, "but the play coins are still earned")
    }

    func testFinishingALevelUnlocksTheNextOneAndRatesIt() throws {
        let id = store.addKid(name: "Mia", kind: .girl, colorIndex: 0)
        var kid = try XCTUnwrap(store.kids(using: library).first)
        XCTAssertEqual(kid.lockState(for: 2), .current)
        XCTAssertEqual(kid.lockState(for: 3), .locked)

        for lesson in library.lessons(inLevel: 2) {
            store.recordCompletion(kidID: id, lessonID: lesson.id, levelID: 2,
                                   stars: 3, coins: lesson.coins, minutes: 3)
        }
        kid = try XCTUnwrap(store.kids(using: library).first)
        XCTAssertEqual(kid.lockState(for: 2), .completed)
        XCTAssertEqual(kid.starsByLevel[2], 3)
        XCTAssertEqual(kid.lockState(for: 3), .current, "the next level opens")
    }

    // MARK: Streaks (README section 3: days with at least one finished lesson)

    func testASecondLessonTheSameDayDoesNotBumpTheStreak() throws {
        let id = store.addKid(name: "Mia", kind: .girl, colorIndex: 0)
        store.recordCompletion(kidID: id, lessonID: "a", levelID: 2, stars: 3, coins: 10, minutes: 3)
        store.recordCompletion(kidID: id, lessonID: "b", levelID: 2, stars: 3, coins: 10, minutes: 3)
        XCTAssertEqual(try XCTUnwrap(store.kids(using: library).first).currentStreak, 1)
    }

    func testComingBackTomorrowExtendsTheStreak() throws {
        let id = store.addKid(name: "Mia", kind: .girl, colorIndex: 0)
        store.recordCompletion(kidID: id, lessonID: "a", levelID: 2, stars: 3, coins: 10, minutes: 3)
        try backdateLastFinishedDay(of: id, byDays: 1)
        store.recordCompletion(kidID: id, lessonID: "b", levelID: 2, stars: 3, coins: 10, minutes: 3)

        let kid = try XCTUnwrap(store.kids(using: library).first)
        XCTAssertEqual(kid.currentStreak, 2)
        XCTAssertEqual(kid.bestStreak, 2)
    }

    func testAMissedDayQuietlyStartsANewStreakAndKeepsTheBest() throws {
        let id = store.addKid(name: "Mia", kind: .girl, colorIndex: 0)
        store.recordCompletion(kidID: id, lessonID: "a", levelID: 2, stars: 3, coins: 10, minutes: 3)
        try backdateLastFinishedDay(of: id, byDays: 1)
        store.recordCompletion(kidID: id, lessonID: "b", levelID: 2, stars: 3, coins: 10, minutes: 3)
        try backdateLastFinishedDay(of: id, byDays: 5)
        store.recordCompletion(kidID: id, lessonID: "c", levelID: 2, stars: 3, coins: 10, minutes: 3)

        let kid = try XCTUnwrap(store.kids(using: library).first)
        XCTAssertEqual(kid.currentStreak, 1, "a new streak, with no scolding anywhere")
        XCTAssertEqual(kid.bestStreak, 2)
    }

    // MARK: The parent code

    func testTheParentCodeIsCheckedButNeverStored() throws {
        store.setParentCode("123456")
        XCTAssertTrue(store.parentCodeMatches("123456"))
        XCTAssertFalse(store.parentCodeMatches("123457"))
        XCTAssertEqual(store.settings().parentCodeDigits, 6)

        let record = store.settingsRecord()
        let stored = [record.parentCodeHash, record.parentCodeSalt].compactMap { $0 }.joined()
        XCTAssertFalse(stored.contains("123456"), "the code itself is never written down")
        XCTAssertNotNil(record.parentCodeHash)
    }

    func testClearingTheCodeLocksNothingOut() throws {
        store.setParentCode("123456")
        store.clearParentCode()
        XCTAssertNil(store.settings().parentCodeDigits)
        XCTAssertFalse(store.parentCodeMatches("123456"))
    }

    func testTwoInstallsOfTheSameCodeHashDifferently() throws {
        store.setParentCode("123456")
        let first = store.settingsRecord().parentCodeHash
        store.setParentCode("123456")
        XCTAssertNotEqual(first, store.settingsRecord().parentCodeHash, "each code gets a fresh salt")
    }

    // MARK: Helpers

    /// Pretend the child's last finished lesson was N days ago.
    private func backdateLastFinishedDay(of id: UUID, byDays days: Int) throws {
        let record = try XCTUnwrap(store.records().first { $0.id == id })
        let last = try XCTUnwrap(record.lastFinishedDay)
        record.lastFinishedDay = Calendar.current.date(byAdding: .day, value: -days, to: last)
    }
}
