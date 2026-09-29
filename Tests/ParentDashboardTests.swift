//
//  ParentDashboardTests.swift
//  The grown-up area's rules: the figures the dashboard shows, the daily time
//  limit, and deleting data.
//
//  Deleting is the one action in this app that cannot be undone and has no
//  backup anywhere, so it is tested from both ends: that the right data goes,
//  and that nothing else does.
//

import XCTest
import SwiftData
@testable import MoneyPals

@MainActor
final class ParentDashboardTests: XCTestCase {

    private var container: ModelContainer!
    private var store: ProgressStore!
    private var library: CurriculumLibrary!
    private let calendar = Calendar.current

    override func setUpWithError() throws {
        container = PersistenceController.makeContainer(environment: ["UITEST_STORE": "memory"])
        store = ProgressStore(context: container.mainContext)
        library = try CurriculumLibrary.load(from: .main)
    }

    // MARK: Deleting one child (README section 6, "Data")

    func testDeletingOneChildLeavesTheOthersUntouched() throws {
        let mia = store.addKid(name: "Mia", avatar: .defaultLook(kind: .girl, outfitColorIndex: 0))
        let jayden = store.addKid(name: "Jayden", avatar: .defaultLook(kind: .boy, outfitColorIndex: 1))
        store.recordCompletion(kidID: mia, lessonID: "needs-and-wants-1", levelID: 2,
                               stars: 3, coins: 10, minutes: 5)
        store.recordCompletion(kidID: jayden, lessonID: "needs-and-wants-1", levelID: 2,
                               stars: 2, coins: 7, minutes: 4)

        store.deleteKid(mia)

        // A second store over the same data is what a relaunch looks like.
        let kids = ProgressStore(context: container.mainContext).kids(using: library)
        XCTAssertEqual(kids.map(\.name), ["Jayden"])
        XCTAssertEqual(kids.first?.coins, 7)
        XCTAssertEqual(kids.first?.starsByLesson["needs-and-wants-1"], 2)
    }

    /// The child's lesson results and day records are attached to them and must
    /// go too — a deleted child must leave nothing behind in the store.
    func testDeletingAChildAlsoDeletesTheirProgressAndDayRecords() throws {
        let mia = store.addKid(name: "Mia", avatar: .defaultLook(kind: .girl, outfitColorIndex: 0))
        store.recordCompletion(kidID: mia, lessonID: "needs-and-wants-1", levelID: 2,
                               stars: 3, coins: 10, minutes: 5)
        XCTAssertFalse(try container.mainContext.fetch(FetchDescriptor<LessonResultRecord>()).isEmpty)

        store.deleteKid(mia)

        XCTAssertTrue(try container.mainContext.fetch(FetchDescriptor<LessonResultRecord>()).isEmpty,
                      "lesson results go with the child")
        XCTAssertTrue(try container.mainContext.fetch(FetchDescriptor<DailyUsageRecord>()).isEmpty,
                      "so do the minutes-per-day records")
    }

    func testDeletingAChildKeepsTheParentCodeAndSettings() throws {
        let mia = store.addKid(name: "Mia", avatar: .defaultLook(kind: .girl, outfitColorIndex: 0))
        store.setParentCode("123456")
        store.setDailyLimit(30)

        store.deleteKid(mia)

        XCTAssertTrue(store.parentCodeMatches("123456"), "the grown-up is not locked out by a deletion")
        XCTAssertEqual(store.settings().dailyLimitMinutes, 30)
    }

    // MARK: Deleting everything

    func testDeletingEverythingEmptiesTheStoreIncludingTheParentCode() throws {
        let mia = store.addKid(name: "Mia", avatar: .defaultLook(kind: .girl, outfitColorIndex: 0))
        _ = store.addKid(name: "Jayden", avatar: .defaultLook(kind: .boy, outfitColorIndex: 1))
        store.recordCompletion(kidID: mia, lessonID: "needs-and-wants-1", levelID: 2,
                               stars: 3, coins: 10, minutes: 5)
        store.setParentCode("123456")

        store.deleteAllData()

        let reopened = ProgressStore(context: container.mainContext)
        XCTAssertTrue(reopened.kids(using: library).isEmpty)
        XCTAssertNil(reopened.settings().parentCodeDigits, "the code goes too")
        XCTAssertFalse(reopened.parentCodeMatches("123456"))
        XCTAssertTrue(try container.mainContext.fetch(FetchDescriptor<LessonResultRecord>()).isEmpty)
        XCTAssertTrue(try container.mainContext.fetch(FetchDescriptor<DailyUsageRecord>()).isEmpty)
    }

    /// An empty store IS first launch, so the app has to go back to Welcome —
    /// that is what "the app starts again from the beginning" means.
    func testDeletingEverythingSendsTheAppBackToFirstLaunch() throws {
        let app = AppState(container: container, library: library, environment: [:])
        app.addKid(name: "Mia", avatar: .defaultLook(kind: .girl, outfitColorIndex: 0))
        app.setParentCode("123456")
        app.route = .parentDashboard

        app.deleteAllData()

        XCTAssertEqual(app.route, .welcome)
        XCTAssertTrue(app.kids.isEmpty)
        XCTAssertNil(app.selectedKidID)
        XCTAssertFalse(app.hasParentCode)
    }

    func testDeletingTheSelectedChildClearsTheSelection() throws {
        let app = AppState(container: container, library: library, environment: [:])
        app.addKid(name: "Mia", avatar: .defaultLook(kind: .girl, outfitColorIndex: 0))
        app.addKid(name: "Jayden", avatar: .defaultLook(kind: .boy, outfitColorIndex: 1))
        let jayden = try XCTUnwrap(app.selectedKidID)

        app.deleteKid(jayden)

        XCTAssertEqual(app.kids.map(\.name), ["Mia"])
        XCTAssertEqual(app.selectedKidID, app.kids.first?.id, "the app falls back to a child that still exists")
    }

    // MARK: Time spent per day (README section 6, "Time spent")

    func testMinutesPerDayFillsInTheQuietDays() throws {
        let id = store.addKid(name: "Mia", avatar: .defaultLook(kind: .girl, outfitColorIndex: 0))
        store.recordCompletion(kidID: id, lessonID: "a", levelID: 2, stars: 3, coins: 10, minutes: 6)

        let kid = try XCTUnwrap(store.kids(using: library).first)
        let week = kid.minutesPerDay(lastDays: 7)
        XCTAssertEqual(week.count, 7, "a bar per day, busy or not")
        XCTAssertEqual(week.last?.minutes, 6, "today is the last one")
        XCTAssertEqual(week.dropLast().map(\.minutes), Array(repeating: 0, count: 6))
        XCTAssertEqual(week.map(\.day), week.map(\.day).sorted(), "oldest day first")
    }

    func testTheDaySeriesSurvivesARelaunchAndSumsToTheWeekTotal() throws {
        let id = store.addKid(name: "Mia", avatar: .defaultLook(kind: .girl, outfitColorIndex: 0))
        store.recordCompletion(kidID: id, lessonID: "a", levelID: 2, stars: 3, coins: 10, minutes: 4)
        store.recordCompletion(kidID: id, lessonID: "b", levelID: 2, stars: 3, coins: 10, minutes: 3)

        let kid = try XCTUnwrap(ProgressStore(context: container.mainContext).kids(using: library).first)
        XCTAssertEqual(kid.dailyMinutes.map(\.minutes), [7], "the same day is one record, not two")
        XCTAssertEqual(kid.minutesThisWeek, 7)
        XCTAssertEqual(kid.minutesPerDay(lastDays: 14).reduce(0) { $0 + $1.minutes }, 7)
    }

    // MARK: The daily time limit (README section 6)

    func testAChildUnderTheLimitCanStartALesson() throws {
        let app = AppState(container: container, library: library, environment: [:])
        app.addKid(name: "Mia", avatar: .defaultLook(kind: .girl, outfitColorIndex: 0))
        app.setDailyLimit(20)

        let kid = try XCTUnwrap(app.selectedKid)
        XCTAssertFalse(app.hasReachedDailyLimit(kid))
        XCTAssertEqual(app.minutesLeftToday(kid), 20)

        // Both ways into a lesson are open: the level's list, and a lesson in it.
        app.openLevel(1)
        XCTAssertEqual(app.route, .levelLessons)
        let lesson = try XCTUnwrap(app.nextLesson(inLevel: 1))
        app.startLesson(id: lesson.id)
        XCTAssertEqual(app.route, .lesson)
    }

    func testTheLimitStopsTheNEXTLessonOpening() throws {
        let app = AppState(container: container, library: library, environment: [:])
        app.addKid(name: "Mia", avatar: .defaultLook(kind: .girl, outfitColorIndex: 0))
        app.setDailyLimit(10)
        let lesson = try XCTUnwrap(app.nextLesson(inLevel: 1))
        // Finishing this one writes the minutes — and a finished lesson is never
        // interrupted, so the limit only bites the next time around.
        app.completeLesson(lessonID: lesson.id, stars: 3, coins: 10, minutes: 12)
        app.route = .lessonMap

        let kid = try XCTUnwrap(app.selectedKid)
        XCTAssertTrue(app.hasReachedDailyLimit(kid))
        XCTAssertEqual(app.minutesLeftToday(kid), 0)

        // Neither door opens: not the level's lesson list, and not a lesson in it.
        app.openLevel(1)
        XCTAssertEqual(app.route, .lessonMap, "the map stays put instead of opening the lesson list")
        let next = try XCTUnwrap(app.nextLesson(inLevel: 1))
        app.startLesson(id: next.id)
        XCTAssertEqual(app.route, .lessonMap, "and no lesson starts either")
    }

    func testNoLimitNeverStopsAChild() throws {
        let app = AppState(container: container, library: library, environment: [:])
        app.addKid(name: "Mia", avatar: .defaultLook(kind: .girl, outfitColorIndex: 0))
        app.setDailyLimit(ParentSettings.noDailyLimit)
        let lesson = try XCTUnwrap(app.nextLesson(inLevel: 1))
        app.completeLesson(lessonID: lesson.id, stars: 3, coins: 10, minutes: 300)

        let kid = try XCTUnwrap(app.selectedKid)
        XCTAssertFalse(app.settings.hasDailyLimit)
        XCTAssertFalse(app.hasReachedDailyLimit(kid))
        XCTAssertNil(app.minutesLeftToday(kid))
        XCTAssertEqual(app.settings.dailyLimitLabel, "No limit")
    }

    /// Penny's wrap-up uses the child's name and never scolds (README section 7).
    func testTheWrapUpLineUsesTheChildsNameAndStaysKind() throws {
        let app = AppState(container: container, library: library, environment: [:])
        app.addKid(name: "Mia", avatar: .defaultLook(kind: .girl, outfitColorIndex: 0))
        let message = app.dailyLimitMessage(for: try XCTUnwrap(app.selectedKid))

        XCTAssertTrue(message.contains("Mia"))
        for unkind in ["hurry", "lost", "wrong", "fail", "out of time", "no more"] {
            XCTAssertFalse(message.lowercased().contains(unkind), "'\(unkind)' has no place in Penny's voice")
        }
    }

    /// The limit setting is shared by the whole family for now (the store holds
    /// one value), but the MINUTES are each child's own: one child running out
    /// never stops their sibling.
    func testOneChildRunningOutOfTimeDoesNotStopTheirSibling() throws {
        let app = AppState(container: container, library: library, environment: [:])
        app.addKid(name: "Mia", avatar: .defaultLook(kind: .girl, outfitColorIndex: 0))
        let mia = try XCTUnwrap(app.selectedKidID)
        app.addKid(name: "Jayden", avatar: .defaultLook(kind: .boy, outfitColorIndex: 1))
        app.setDailyLimit(15)

        app.selectedKidID = mia
        let lesson = try XCTUnwrap(app.nextLesson(inLevel: 1))
        app.completeLesson(lessonID: lesson.id, stars: 3, coins: 10, minutes: 20)

        let kids = Dictionary(uniqueKeysWithValues: app.kids.map { ($0.name, $0) })
        XCTAssertTrue(app.hasReachedDailyLimit(try XCTUnwrap(kids["Mia"])))
        XCTAssertFalse(app.hasReachedDailyLimit(try XCTUnwrap(kids["Jayden"])))
        XCTAssertEqual(app.settings.dailyLimitLabel, "15 min")
    }

    // MARK: Changing the parent code

    func testChangingTheCodeReplacesTheOldOneAndStillStoresOnlyAHash() throws {
        store.setParentCode("123456")
        store.setParentCode("654321")

        XCTAssertFalse(store.parentCodeMatches("123456"), "the old code stops working")
        XCTAssertTrue(store.parentCodeMatches("654321"))

        let record = store.settingsRecord()
        let stored = [record.parentCodeHash, record.parentCodeSalt].compactMap { $0 }.joined()
        XCTAssertFalse(stored.contains("654321"), "the new code is not written down either")
    }

    // MARK: The dashboard's own seed

    func testTheDashboardSeedGivesTheScreenSomethingRealToDraw() throws {
        store.seedDashboardFamily(library: library)
        let kids = store.kids(using: library)

        XCTAssertEqual(kids.map(\.name), ["Mia", "Jayden"])
        let mia = try XCTUnwrap(kids.first)
        XCTAssertGreaterThan(mia.totalStars, 0)
        XCTAssertGreaterThan(mia.dailyMinutes.count, 1, "more than one day of history")
        XCTAssertTrue(store.parentCodeMatches("123456"))
    }
}
