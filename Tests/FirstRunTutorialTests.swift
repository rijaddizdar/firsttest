//
//  FirstRunTutorialTests.swift
//  The "how it works" step a child sees once, before their first question.
//
//  The copy is the point of this step, so the copy is what is tested: README
//  section 7's rules are not a style preference here, they are the product.
//

import XCTest
@testable import MoneyPals

final class FirstRunTutorialTests: XCTestCase {

    private var points: [(icon: String, text: String)] { KidFirstRunView.howItWorks }

    /// The step exists, and comes after meeting Penny rather than before it —
    /// a child is told who Penny is, then how the learning works.
    func testTheTutorialIsTheLastStepOfTheFirstRun() {
        let steps = KidFirstRunView.Step.allCases
        XCTAssertEqual(steps.last, .howItWorks)
        XCTAssertEqual(steps, [.name, .look, .penny, .howItWorks])
    }

    func testItTeachesTheThreeThingsAChildNeeds() {
        XCTAssertEqual(points.count, 3)
        let all = points.map(\.text).joined(separator: " ").lowercased()
        XCTAssertTrue(all.contains("levels open"), "that levels unlock in order")
        XCTAssertTrue(all.contains("try again"), "that a wrong answer is safe")
        XCTAssertTrue(all.contains("pretend"), "that the coins are not real money")
    }

    /// README section 7, rule 1: short sentences, one idea each.
    func testEverySentenceIsShortEnoughForASixYearOld() {
        for point in points {
            for sentence in point.text.split(whereSeparator: { ".!?".contains($0) }) {
                let words = sentence.split(separator: " ").count
                XCTAssertLessThanOrEqual(words, 12, "too long for a 6-year-old: '\(sentence)'")
            }
        }
    }

    /// README section 7, rules 5 and 6: kind about mistakes, and no pressure.
    /// "wrong", "fail" and "hurry" are exactly the words the product forbids.
    func testTheCopyNeverScoldsOrRushes() {
        let all = points.map(\.text).joined(separator: " ").lowercased()
        for banned in ["wrong", "fail", "bad", "hurry", "quick", "fast",
                       "don't miss", "lose", "lost", "must"] {
            XCTAssertFalse(all.contains(banned), "'\(banned)' has no place in Penny's voice")
        }
    }

    /// Rule 4: talk TO the child.
    func testItTalksToTheChild() {
        let all = points.map(\.text).joined(separator: " ").lowercased()
        XCTAssertTrue(all.contains("you"))
        XCTAssertTrue(all.contains("we"))
    }

    /// Every point shows a picture, never words alone (rule 3), and each icon
    /// is really in the catalog — a missing name would render as nothing.
    func testEveryPointHasARealPicture() {
        for point in points {
            XCTAssertFalse(point.icon.isEmpty)
            #if canImport(UIKit)
            XCTAssertNotNil(UIImage(named: point.icon),
                            "'\(point.icon)' is not in Assets.xcassets/Icons")
            #endif
        }
    }

    // MARK: Actually reaching it

    /// The whole point: a grown-up adds a profile, the child taps their own
    /// face, and the first run — tutorial included — is what they get.
    @MainActor
    func testAChildAddedByAGrownUpGetsTheFirstRun() throws {
        let container = PersistenceController.makeContainer(environment: ["UITEST_STORE": "memory"])
        let app = AppState(container: container,
                           library: try CurriculumLibrary.load(from: .main),
                           environment: [:])
        app.addKid(name: "Mia", avatar: .defaultLook(kind: .girl, outfitColorIndex: 0))
        let kid = try XCTUnwrap(app.kids.first)
        XCTAssertFalse(kid.hasFinishedFirstRun, "a brand-new profile has not been through it")

        app.openKid(kid.id)
        XCTAssertEqual(app.route, .kidFirstRun, "tapping the face opens the first run")

        // ...and only once.
        app.finishKidFirstRun(kid.id)
        app.openKid(kid.id)
        XCTAssertEqual(app.route, .lessonMap)
    }

    /// A profile saved before the first run existed is deliberately treated as
    /// already done, so an update never drags an established child back through
    /// setup. That is also why an OLD install shows no tutorial: the profiles
    /// pre-date the field. A fresh install is what exercises it.
    @MainActor
    func testAProfileFromAnOlderInstallIsLeftAlone() throws {
        let container = PersistenceController.makeContainer(environment: ["UITEST_STORE": "memory"])
        let store = ProgressStore(context: container.mainContext)
        let id = store.addKid(name: "Mia", avatar: .defaultLook(kind: .girl, outfitColorIndex: 0))
        // Exactly what an upgraded record looks like: the field was never written.
        try XCTUnwrap(store.records().first { $0.id == id }).hasFinishedFirstRun = nil

        let kid = try XCTUnwrap(store.kids(using: try CurriculumLibrary.load(from: .main)).first)
        XCTAssertTrue(kid.hasFinishedFirstRun,
                      "an existing child is not sent back through setup by an update")
    }

    // MARK: A child always has a name

    /// The store used to quietly name an unnamed child "Friend". Both screens
    /// now refuse an empty name instead, so that fallback should never fire —
    /// but it is still the last line of defence, so it is pinned too.
    @MainActor
    func testANameOfOnlySpacesIsNotAName() throws {
        let container = PersistenceController.makeContainer(environment: ["UITEST_STORE": "memory"])
        let store = ProgressStore(context: container.mainContext)
        let library = try CurriculumLibrary.load(from: .main)

        // What the screens now send: already trimmed, and never empty.
        _ = store.addKid(name: "Mia", avatar: .defaultLook(kind: .girl, outfitColorIndex: 0))
        XCTAssertEqual(store.kids(using: library).first?.name, "Mia")

        // And the safety net, if anything ever slips past the UI.
        _ = store.addKid(name: "", avatar: .defaultLook(kind: .boy, outfitColorIndex: 1))
        let unnamed = store.kids(using: library).first { $0.name != "Mia" }
        XCTAssertFalse(unnamed?.name.isEmpty ?? true,
                       "a child must never end up with a blank face on Who's learning?")
    }
}
