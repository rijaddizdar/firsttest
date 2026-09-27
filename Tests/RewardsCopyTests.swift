//
//  RewardsCopyTests.swift
//  The words children read about their rewards, checked against README section 7.
//
//  The rules that matter most here are rule 5 (kind about mistakes), rule 6 (no
//  pressure, "no guilt about streaks") and rule 8 (kid-sized numbers). A missed
//  day in particular must never produce a sentence that scolds, counts a loss or
//  hurries the child back.
//

import XCTest
@testable import MoneyPals

final class RewardsCopyTests: XCTestCase {

    /// Words that would break README section 7 if a child ever read them on a
    /// reward screen.
    private let bannedWords = ["lost", "lose", "broke", "broken", "failed", "fail",
                              "wrong", "bad", "hurry", "don't miss", "missed", "only"]

    // MARK: Streaks

    func testAStreakThatEndedIsGreetedAndNeverScolded() {
        // Came back after a gap: they have a best run, but no current one.
        let line = StreakCopy.headline(streak: 0, best: 4, name: "Mia")
        assertKind(line)
        XCTAssertTrue(line.contains("Mia"))
        XCTAssertTrue(line.lowercased().contains("welcome back"),
                      "README section 7 answers a broken streak with a greeting: \(line)")
    }

    func testAChildWithNoStreakYetIsSimplyInvited() {
        let line = StreakCopy.headline(streak: 0, best: 0, name: "Mia")
        assertKind(line)
        XCTAssertTrue(line.contains("Mia"))
    }

    func testEveryStreakHeadlineIsShortKindAndUsesTheName() {
        for streak in 0...30 {
            for best in [0, streak, streak + 3] {
                let line = StreakCopy.headline(streak: streak, best: best, name: "Mia")
                assertKind(line)
                XCTAssertTrue(line.contains("Mia"), "\(line) never says the child's name")
                assertSentencesAreShort(line)
            }
        }
    }

    func testTheStreakDetailNeverMentionsADayThatWasMissed() {
        XCTAssertNil(StreakCopy.detail(streak: 0, best: 0), "nothing to say yet, so say nothing")
        XCTAssertEqual(StreakCopy.detail(streak: 3, best: 3), "This is your best run yet.")
        XCTAssertEqual(StreakCopy.detail(streak: 2, best: 5), "Your best run is 5 days.")
        XCTAssertEqual(StreakCopy.detail(streak: 0, best: 1), "Your best run is 1 day.",
                       "never \"1 days\"")
    }

    // MARK: Penny's scales

    func testTheScalesLineCountsOneScaleProperly() {
        XCTAssertTrue(PennyScales.line(scales: 1, name: "Mia").contains("1 shiny scale,"))
        XCTAssertTrue(PennyScales.line(scales: 3, name: "Mia").contains("3 shiny scales"))
    }

    func testWithNoScalesYetPennySaysHowToGetThem() {
        let line = PennyScales.line(scales: 0, name: "Mia")
        assertKind(line)
        XCTAssertTrue(line.lowercased().contains("finish a level"))
    }

    func testFinishingALevelIsWorthAKidSizedNumberOfScales() {
        XCTAssertEqual(PennyScales.perLevel, 3)
        let line = PennyScales.justEarnedLine(scales: PennyScales.perLevel, name: "Mia")
        assertKind(line)
        assertSentencesAreShort(line)
    }

    // MARK: Money talk

    func testCoinsAreCountedWithTheRightWord() {
        XCTAssertEqual(ShopCopy.coins(0), "0 coins")
        XCTAssertEqual(ShopCopy.coins(1), "1 coin")
        XCTAssertEqual(ShopCopy.coins(12), "12 coins")
    }

    func testTheBalanceIsAlwaysStatedPlainly() {
        XCTAssertEqual(ShopCopy.balance(0), "You have no coins yet.")
        XCTAssertEqual(ShopCopy.balance(1), "You have 1 coin.")
        XCTAssertEqual(ShopCopy.balance(18), "You have 18 coins.")
    }

    func testPennysOwnColourReadsAsFreeRatherThanZeroCoins() {
        let free = ShopItem(id: "a", name: "Teal", price: 0, icon: nil, paletteIndex: 0)
        let paid = ShopItem(id: "b", name: "Coral", price: 15, icon: nil, paletteIndex: 3)
        XCTAssertEqual(ShopCopy.price(free), "Free")
        XCTAssertEqual(ShopCopy.price(paid), "15 coins")
    }

    /// The whole point of the shop: a child who can't afford something is told
    /// the number and how to get there, never simply refused.
    func testNotAffordingSomethingSaysTheNumberAndHowToEarnMore() {
        let line = ShopCopy.cannotAffordYet(missing: 7, name: "Mia")
        assertKind(line)
        XCTAssertTrue(line.contains("Mia"))
        XCTAssertTrue(line.contains("7 coins"), "the child needs the number: \(line)")
        XCTAssertTrue(line.lowercased().contains("finish a lesson"), "and the way to get it: \(line)")
        assertSentencesAreShort(line)

        XCTAssertTrue(ShopCopy.cannotAffordYet(missing: 1, name: "Mia").contains("1 coin more"),
                      "never \"1 coins\"")
        XCTAssertEqual(ShopCopy.short(by: 1), "1 coin more")
        XCTAssertEqual(ShopCopy.short(by: 4), "4 coins more")
    }

    func testAPurchaseSaysWhatIsLeftSoSpendingTeachesBudgeting() {
        let sticker = ShopItem(id: "a", name: "Rainbow", price: 10, icon: "rainbow", paletteIndex: nil)
        let line = ShopCopy.bought(sticker, kind: .sticker, name: "Mia", coinsLeft: 8)
        assertKind(line)
        XCTAssertTrue(line.contains("Mia"))
        XCTAssertTrue(line.contains("8 coins left"), "got: \(line)")

        let broke = ShopCopy.bought(sticker, kind: .sticker, name: "Mia", coinsLeft: 0)
        XCTAssertTrue(broke.contains("no coins left"), "never \"0 coins left\": \(broke)")
    }

    func testBuyingAScarfTalksAboutPennyWearingIt() {
        let scarf = ShopItem(id: "b", name: "Coral", price: 15, icon: nil, paletteIndex: 3)
        let line = ShopCopy.bought(scarf, kind: .pennyScarf, name: "Mia", coinsLeft: 3)
        assertKind(line)
        XCTAssertTrue(line.lowercased().contains("penny"))
        XCTAssertTrue(line.lowercased().contains("coral"))
    }

    func testTheEmptyStickerBookInvitesRatherThanNags() {
        let line = ShopCopy.emptyStickerBook(name: "Mia")
        assertKind(line)
        XCTAssertTrue(line.contains("Mia"))
        assertSentencesAreShort(line)
    }

    // MARK: Helpers

    /// No banned word, and no exclamation of the scolding kind.
    private func assertKind(_ line: String, file: StaticString = #filePath, line lineNumber: UInt = #line) {
        let lowered = line.lowercased()
        for banned in bannedWords {
            XCTAssertFalse(lowered.contains(banned),
                           "\"\(line)\" uses \"\(banned)\", which README section 7 rules out",
                           file: file, line: lineNumber)
        }
    }

    /// README section 7 rule 1: 12 words or fewer per sentence.
    private func assertSentencesAreShort(_ text: String,
                                        file: StaticString = #filePath,
                                        line lineNumber: UInt = #line) {
        for sentence in text.split(whereSeparator: { ".!?".contains($0) }) {
            let words = sentence.split(whereSeparator: \.isWhitespace).count
            XCTAssertLessThanOrEqual(words, 12,
                                     "\"\(sentence.trimmingCharacters(in: .whitespaces))\" is \(words) words",
                                     file: file, line: lineNumber)
        }
    }
}
