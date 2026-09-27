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

    /// Finish everything still to do in a level — its lessons and then the level
    /// check — which is what "completing a level" now means. Steps this child has
    /// already finished are left alone, so a caller can set up a partly-done
    /// level first and not have it overwritten.
    private func finish(level levelID: Int, kidID: UUID, stars: Int) {
        let done = store.kids(using: library).first { $0.id == kidID }?.starsByLesson ?? [:]
        for lesson in library.lessonsAndCheck(inLevel: levelID) where done[lesson.id] == nil {
            store.recordCompletion(kidID: kidID, lessonID: lesson.id, levelID: levelID,
                                   stars: stars, coins: lesson.coins, minutes: 3)
        }
    }

    // MARK: Kids and progress

    func testAKidAndTheirProgressAreSaved() throws {
        let id = store.addKid(name: "Mia", avatar: Avatar())
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

    /// The map header counts stars the moment they are won. Finishing one lesson
    /// of a level earns its stars, even though the LEVEL is not rated until
    /// every step in it is done — a child who just earned three stars must never
    /// be shown 0.
    func testStarsShowOnTheHeaderAsSoonAsALessonIsFinished() throws {
        let id = store.addKid(name: "Mia", avatar: Avatar())
        store.recordCompletion(kidID: id, lessonID: "needs-and-wants-1", levelID: 2,
                               stars: 3, coins: 10, minutes: 3)

        var kid = try XCTUnwrap(ProgressStore(context: container.mainContext).kids(using: library).first)
        XCTAssertEqual(kid.totalStars, 3, "the header counts earned stars, not rated levels")
        XCTAssertNil(kid.starsByLevel[2], "the level itself is not rated until every step is done")

        // A second lesson adds its stars on top, and the level is still not rated.
        store.recordCompletion(kidID: id, lessonID: "needs-and-wants-2", levelID: 2,
                               stars: 2, coins: 10, minutes: 3)
        kid = try XCTUnwrap(store.kids(using: library).first)
        XCTAssertEqual(kid.totalStars, 5)
        XCTAssertNil(kid.starsByLevel[2], "three lessons and the check still to go")

        // Every step, check included: now the level gets its rating.
        finish(level: 2, kidID: id, stars: 3)
        kid = try XCTUnwrap(store.kids(using: library).first)
        XCTAssertEqual(kid.starsByLevel[2], 2, "the average of its steps, rounded down")
    }

    func testAReplayThatEarnsMoreStarsRaisesTheTotalOnlyByTheDifference() throws {
        let id = store.addKid(name: "Mia", avatar: Avatar())
        store.recordCompletion(kidID: id, lessonID: "needs-and-wants-1", levelID: 2,
                               stars: 1, coins: 10, minutes: 3)
        XCTAssertEqual(try XCTUnwrap(store.kids(using: library).first).totalStars, 1)

        store.recordCompletion(kidID: id, lessonID: "needs-and-wants-1", levelID: 2,
                               stars: 3, coins: 10, minutes: 3)
        XCTAssertEqual(try XCTUnwrap(store.kids(using: library).first).totalStars, 3,
                       "a better replay raises the total; it never stacks a second time")
    }

    func testReplayingALessonKeepsTheBestStars() throws {
        let id = store.addKid(name: "Mia", avatar: Avatar())
        store.recordCompletion(kidID: id, lessonID: "needs-and-wants-1", levelID: 2,
                               stars: 3, coins: 10, minutes: 3)
        store.recordCompletion(kidID: id, lessonID: "needs-and-wants-1", levelID: 2,
                               stars: 1, coins: 10, minutes: 3)
        let kid = try XCTUnwrap(store.kids(using: library).first)
        XCTAssertEqual(kid.starsByLesson["needs-and-wants-1"], 3, "a worse replay never takes stars away")
        XCTAssertEqual(kid.coins, 20, "but the play coins are still earned")
    }

    func testFinishingALevelUnlocksTheNextOneAndRatesIt() throws {
        let id = store.addKid(name: "Mia", avatar: Avatar())
        var kid = try XCTUnwrap(store.kids(using: library).first)
        XCTAssertEqual(kid.lockState(for: 1), .current)
        XCTAssertEqual(kid.lockState(for: 2), .locked)

        finish(level: 1, kidID: id, stars: 3)
        kid = try XCTUnwrap(store.kids(using: library).first)
        XCTAssertEqual(kid.lockState(for: 1), .completed)
        XCTAssertEqual(kid.starsByLevel[1], 3)
        XCTAssertEqual(kid.lockState(for: 2), .current, "the next level opens")
    }

    /// A level's lessons alone do not finish it: the friendly level check is the
    /// last step, so the next level stays shut until the check is played.
    func testTheLevelCheckIsTheLastStepOfALevel() throws {
        let id = store.addKid(name: "Mia", avatar: .defaultLook(kind: .girl, outfitColorIndex: 0))
        for lesson in library.lessons(inLevel: 1) {
            store.recordCompletion(kidID: id, lessonID: lesson.id, levelID: 1,
                                   stars: 3, coins: lesson.coins, minutes: 3)
        }
        var kid = try XCTUnwrap(store.kids(using: library).first)
        XCTAssertNotEqual(kid.lockState(for: 1), .completed, "the check is still to play")
        XCTAssertEqual(kid.lockState(for: 2), .locked)

        let check = try XCTUnwrap(library.levelCheck(forLevel: 1))
        store.recordCompletion(kidID: id, lessonID: check.id, levelID: 1,
                               stars: 3, coins: check.coins, minutes: 3)
        kid = try XCTUnwrap(store.kids(using: library).first)
        XCTAssertEqual(kid.lockState(for: 1), .completed)
        XCTAssertEqual(kid.lockState(for: 2), .current)
    }

    // MARK: Streaks (README section 3: days with at least one finished lesson)

    func testASecondLessonTheSameDayDoesNotBumpTheStreak() throws {
        let id = store.addKid(name: "Mia", avatar: Avatar())
        store.recordCompletion(kidID: id, lessonID: "a", levelID: 2, stars: 3, coins: 10, minutes: 3)
        store.recordCompletion(kidID: id, lessonID: "b", levelID: 2, stars: 3, coins: 10, minutes: 3)
        XCTAssertEqual(try XCTUnwrap(store.kids(using: library).first).currentStreak, 1)
    }

    func testComingBackTomorrowExtendsTheStreak() throws {
        let id = store.addKid(name: "Mia", avatar: Avatar())
        store.recordCompletion(kidID: id, lessonID: "a", levelID: 2, stars: 3, coins: 10, minutes: 3)
        try backdateLastFinishedDay(of: id, byDays: 1)
        store.recordCompletion(kidID: id, lessonID: "b", levelID: 2, stars: 3, coins: 10, minutes: 3)

        let kid = try XCTUnwrap(store.kids(using: library).first)
        XCTAssertEqual(kid.currentStreak, 2)
        XCTAssertEqual(kid.bestStreak, 2)
    }

    func testAMissedDayQuietlyStartsANewStreakAndKeepsTheBest() throws {
        let id = store.addKid(name: "Mia", avatar: Avatar())
        store.recordCompletion(kidID: id, lessonID: "a", levelID: 2, stars: 3, coins: 10, minutes: 3)
        try backdateLastFinishedDay(of: id, byDays: 1)
        store.recordCompletion(kidID: id, lessonID: "b", levelID: 2, stars: 3, coins: 10, minutes: 3)
        try backdateLastFinishedDay(of: id, byDays: 5)
        store.recordCompletion(kidID: id, lessonID: "c", levelID: 2, stars: 3, coins: 10, minutes: 3)

        let kid = try XCTUnwrap(store.kids(using: library).first)
        XCTAssertEqual(kid.currentStreak, 1, "a new streak, with no scolding anywhere")
        XCTAssertEqual(kid.bestStreak, 2)
    }

    // MARK: Penny's scales (README section 3: a finished LEVEL, not a lesson)

    func testFinishingALevelGivesPennyNewScalesOnceAndOnlyOnce() throws {
        let id = store.addKid(name: "Mia", kind: .girl, colorIndex: 0)
        let lessons = library.lessons(inLevel: 2)
        XCTAssertGreaterThan(lessons.count, 1, "this test needs a level with more than one lesson")

        // Part-way through the level: no scales yet.
        store.recordCompletion(kidID: id, lessonID: lessons[0].id, levelID: 2,
                               stars: 3, coins: 10, minutes: 3)
        XCTAssertEqual(store.awardScalesIfLevelFinished(kidID: id, levelID: 2,
                                                        wasCompleteBefore: false, library: library), 0)
        XCTAssertEqual(try XCTUnwrap(store.kids(using: library).first).pennyScales, 0)

        // The lesson that finishes the level earns the batch.
        store.recordCompletion(kidID: id, lessonID: lessons[1].id, levelID: 2,
                               stars: 3, coins: 10, minutes: 3)
        XCTAssertEqual(store.awardScalesIfLevelFinished(kidID: id, levelID: 2,
                                                        wasCompleteBefore: false, library: library),
                       PennyScales.perLevel)
        XCTAssertEqual(try XCTUnwrap(store.kids(using: library).first).pennyScales, PennyScales.perLevel)

        // Replaying the finished level hands out nothing more.
        store.recordCompletion(kidID: id, lessonID: lessons[0].id, levelID: 2,
                               stars: 3, coins: 10, minutes: 3)
        XCTAssertEqual(store.awardScalesIfLevelFinished(kidID: id, levelID: 2,
                                                        wasCompleteBefore: true, library: library), 0)
        XCTAssertEqual(try XCTUnwrap(store.kids(using: library).first).pennyScales, PennyScales.perLevel,
                       "a replay never hands out a second batch of scales")
    }

    // MARK: Spending play coins

    func testBuyingAStickerSpendsTheCoinsAndKeepsTheSticker() throws {
        let id = store.addKid(name: "Mia", kind: .girl, colorIndex: 0)
        store.recordCompletion(kidID: id, lessonID: "a", levelID: 2, stars: 3, coins: 20, minutes: 3)

        XCTAssertTrue(store.buy(itemID: "sticker-rainbow", price: 10, kidID: id))

        // A second store over the same data is what a relaunch looks like.
        let kid = try XCTUnwrap(ProgressStore(context: container.mainContext).kids(using: library).first)
        XCTAssertEqual(kid.coins, 10, "the price came off the balance")
        XCTAssertTrue(kid.owns("sticker-rainbow"), "and the sticker is still hers after a relaunch")
    }

    func testTheSameStickerCannotBeBoughtTwice() throws {
        let id = store.addKid(name: "Mia", kind: .girl, colorIndex: 0)
        store.recordCompletion(kidID: id, lessonID: "a", levelID: 2, stars: 3, coins: 30, minutes: 3)

        XCTAssertTrue(store.buy(itemID: "sticker-rainbow", price: 10, kidID: id))
        XCTAssertFalse(store.buy(itemID: "sticker-rainbow", price: 10, kidID: id))
        let kid = try XCTUnwrap(store.kids(using: library).first)
        XCTAssertEqual(kid.coins, 20, "the second tap spent nothing")
        XCTAssertEqual(kid.ownedItemIDs.count, 1)
    }

    /// The balance can never go negative: play coins are earned by learning, and
    /// there is no way to get more of them (certainly not with real money).
    func testAChildCannotSpendCoinsTheyDoNotHave() throws {
        let id = store.addKid(name: "Mia", kind: .girl, colorIndex: 0)
        store.recordCompletion(kidID: id, lessonID: "a", levelID: 2, stars: 3, coins: 10, minutes: 3)

        XCTAssertFalse(store.buy(itemID: "sticker-unicorn", price: 25, kidID: id))
        let kid = try XCTUnwrap(store.kids(using: library).first)
        XCTAssertEqual(kid.coins, 10, "nothing was spent")
        XCTAssertFalse(kid.owns("sticker-unicorn"))
    }

    func testPennysScarfColourIsRememberedAndCanGoBack() throws {
        let id = store.addKid(name: "Mia", kind: .girl, colorIndex: 0)
        XCTAssertNil(try XCTUnwrap(store.kids(using: library).first).pennyScarfItemID,
                     "a new child gets Penny's own colour")

        store.setPennyScarf(itemID: "scarf-coral", kidID: id)
        XCTAssertEqual(try XCTUnwrap(ProgressStore(context: container.mainContext)
            .kids(using: library).first).pennyScarfItemID, "scarf-coral")

        store.setPennyScarf(itemID: "scarf-teal", kidID: id)
        XCTAssertEqual(try XCTUnwrap(store.kids(using: library).first).pennyScarfItemID, "scarf-teal")
    }

    func testDeletingAChildTakesTheirPurchasesWithThem() throws {
        let id = store.addKid(name: "Mia", kind: .girl, colorIndex: 0)
        store.recordCompletion(kidID: id, lessonID: "a", levelID: 2, stars: 3, coins: 20, minutes: 3)
        XCTAssertTrue(store.buy(itemID: "sticker-rainbow", price: 10, kidID: id))

        store.deleteKid(id)
        XCTAssertTrue(store.kids(using: library).isEmpty)
        let leftover = try container.mainContext.fetch(FetchDescriptor<ShopPurchaseRecord>())
        XCTAssertTrue(leftover.isEmpty, "README section 9: deleting a child deletes their data")
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
