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
}
