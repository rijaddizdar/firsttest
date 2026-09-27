//
//  ShopTests.swift
//  The play-coin shop: that the bundled catalog is usable, that a broken one
//  says why, and that the spending rules hold — a child can never overdraw a
//  balance, never buy the same thing twice, and is always told how many more
//  coins they need.
//

import XCTest
@testable import MoneyPals

final class ShopTests: XCTestCase {

    private var shop: ShopLibrary!

    override func setUpWithError() throws {
        shop = try ShopLibrary.load(from: .main)
    }

    // MARK: The bundled catalog

    func testTheBundledShopLoadsAndValidates() {
        XCTAssertTrue(shop.issues.isEmpty, "shop.json: \(shop.issues)")
        XCTAssertFalse(shop.sections.isEmpty)
        XCTAssertFalse(shop.items(ofKind: .sticker).isEmpty, "a sticker book needs stickers to fill")
        XCTAssertFalse(shop.items(ofKind: .pennyScarf).isEmpty)
    }

    /// Every sticker picture must really be in the asset catalog, or a child
    /// buys a blank square.
    func testEveryStickerHasItsPicture() {
        for item in shop.items(ofKind: .sticker) {
            let icon = try? XCTUnwrap(item.icon)
            XCTAssertNotNil(icon, "\(item.id) has no icon")
            XCTAssertTrue(ContentArt.exists(item.icon ?? ""), "\(item.id): \(item.icon ?? "-") is missing")
        }
    }

    /// README section 7 rule 8 keeps money numbers kid-sized. Nothing may cost
    /// more than a child could plausibly save up for.
    func testPricesAreKidSized() {
        for item in shop.items {
            XCTAssertGreaterThanOrEqual(item.price, 0, "\(item.id) has a negative price")
            XCTAssertLessThanOrEqual(item.price, ShopRules.highestPrice, "\(item.id) costs too much")
        }
    }

    /// Penny's own scarf colour is free, so a child who buys a colour can always
    /// put her back the way she was.
    func testPennysOwnScarfIsAlwaysAvailable() throws {
        let scarf = try XCTUnwrap(shop.defaultScarf)
        XCTAssertEqual(scarf.price, 0)
        XCTAssertNotNil(scarf.color, "a scarf colour must resolve to a design-system colour")
    }

    func testAChildWhoHasChosenNothingIsWearingPennysOwnScarf() throws {
        let kid = Self.kid(coins: 0)
        XCTAssertEqual(shop.wornScarf(for: kid)?.id, shop.defaultScarf?.id)
        XCTAssertEqual(shop.state(of: try XCTUnwrap(shop.defaultScarf), kind: .pennyScarf, for: kid), .worn)
    }

    // MARK: What a child can do with an item

    func testAnItemAChildCannotAffordSaysHowManyMoreCoins() throws {
        let item = ShopItem(id: "x", name: "Kite", price: 25, icon: "balloon", paletteIndex: nil)
        let kid = Self.kid(coins: 18)
        XCTAssertEqual(shop.state(of: item, kind: .sticker, for: kid), .needsMoreCoins(7))
        XCTAssertFalse(shop.canBuy(item, kind: .sticker, for: kid))
    }

    func testAnItemAChildCanExactlyAffordIsBuyable() {
        let item = ShopItem(id: "x", name: "Kite", price: 18, icon: "balloon", paletteIndex: nil)
        let kid = Self.kid(coins: 18)
        XCTAssertEqual(shop.state(of: item, kind: .sticker, for: kid), .affordable)
        XCTAssertTrue(shop.canBuy(item, kind: .sticker, for: kid))
    }

    func testAStickerAlreadyOwnedIsCollectedAndCannotBeBoughtTwice() {
        let item = ShopItem(id: "x", name: "Kite", price: 5, icon: "balloon", paletteIndex: nil)
        let kid = Self.kid(coins: 50, owned: ["x"])
        XCTAssertEqual(shop.state(of: item, kind: .sticker, for: kid), .collected)
        XCTAssertFalse(shop.canBuy(item, kind: .sticker, for: kid))
    }

    /// A worn kind is different from a collected one: owning a scarf colour a
    /// child isn't wearing has to stay tappable, so they can put it on.
    func testAScarfOwnedButNotWornCanStillBePutOn() throws {
        let scarves = shop.items(ofKind: .pennyScarf)
        let paid = try XCTUnwrap(scarves.first { !$0.isFree })
        let other = try XCTUnwrap(scarves.first { !$0.isFree && $0.id != paid.id })

        let kid = Self.kid(coins: 0, owned: [paid.id, other.id], scarf: other.id)
        XCTAssertEqual(shop.state(of: other, kind: .pennyScarf, for: kid), .worn)
        XCTAssertEqual(shop.state(of: paid, kind: .pennyScarf, for: kid), .ownedNotWorn)
        XCTAssertFalse(shop.canBuy(paid, kind: .pennyScarf, for: kid),
                       "nothing more to spend: it is already hers")
    }

    func testTheFreeScarfNeedsNoCoinsEvenWithAnEmptyBalance() throws {
        let free = try XCTUnwrap(shop.defaultScarf)
        let paid = try XCTUnwrap(shop.items(ofKind: .pennyScarf).first { !$0.isFree })
        let kid = Self.kid(coins: 0, owned: [paid.id], scarf: paid.id)
        XCTAssertEqual(shop.state(of: free, kind: .pennyScarf, for: kid), .free)
        XCTAssertTrue(shop.canBuy(free, kind: .pennyScarf, for: kid))
    }

    func testOwnedStickersComeBackInShopOrder() {
        let stickers = shop.items(ofKind: .sticker)
        let picked = [stickers[2].id, stickers[0].id]
        let kid = Self.kid(coins: 0, owned: Set(picked))
        XCTAssertEqual(shop.ownedStickers(for: kid).map(\.id), [stickers[0].id, stickers[2].id],
                       "the book fills in the same order every time")
    }

    // MARK: A broken catalog says why

    func testAMissingStickerPictureIsReported() throws {
        let problems = try Self.problems(in: """
        { "schemaVersion": 1, "sections": [
          { "id": "s", "title": "Stickers", "kidSummary": "Buy one.", "kind": "sticker",
            "items": [ { "id": "a", "name": "Nope", "icon": "not-a-real-picture", "price": 5 } ] } ] }
        """)
        XCTAssertTrue(problems.contains { $0.contains("not-a-real-picture") && $0.contains("Assets.xcassets") },
                      "got: \(problems)")
    }

    func testAPriceOverTheKidSizedLimitIsReported() throws {
        let problems = try Self.problems(in: """
        { "schemaVersion": 1, "sections": [
          { "id": "s", "title": "Stickers", "kidSummary": "Buy one.", "kind": "sticker",
            "items": [ { "id": "a", "name": "Pricey", "icon": "balloon", "price": 500 } ] } ] }
        """)
        XCTAssertTrue(problems.contains { $0.contains("500") && $0.contains("rule 8") }, "got: \(problems)")
    }

    func testAWornSectionWithNothingFreeIsReported() throws {
        let problems = try Self.problems(in: """
        { "schemaVersion": 1, "sections": [
          { "id": "scarves", "title": "Scarf", "kidSummary": "Pick one.", "kind": "pennyScarf",
            "items": [ { "id": "a", "name": "Copper", "paletteIndex": 1, "price": 10 } ] } ] }
        """)
        XCTAssertTrue(problems.contains { $0.contains("0 coins") && $0.contains("change back") },
                      "got: \(problems)")
    }

    func testARepeatedItemIDIsReported() throws {
        let problems = try Self.problems(in: """
        { "schemaVersion": 1, "sections": [
          { "id": "s", "title": "Stickers", "kidSummary": "Buy one.", "kind": "sticker",
            "items": [ { "id": "a", "name": "One", "icon": "balloon", "price": 5 },
                       { "id": "a", "name": "Two", "icon": "star", "price": 5 } ] } ] }
        """)
        XCTAssertTrue(problems.contains { $0.contains("\"a\"") && $0.contains("purchase is saved under") },
                      "got: \(problems)")
    }

    func testAScarfWithNoColourIsReported() throws {
        let problems = try Self.problems(in: """
        { "schemaVersion": 1, "sections": [
          { "id": "scarves", "title": "Scarf", "kidSummary": "Pick one.", "kind": "pennyScarf",
            "items": [ { "id": "a", "name": "Penny's own", "price": 0 } ] } ] }
        """)
        XCTAssertTrue(problems.contains { $0.contains("paletteIndex") }, "got: \(problems)")
    }

    /// A shop file that can't be read must never take the app down with it: the
    /// map and the lessons carry on and the shelves are simply empty.
    func testAnEmptyShopIsUsable() {
        let empty = ShopLibrary.empty
        XCTAssertTrue(empty.sections.isEmpty)
        XCTAssertNil(empty.defaultScarf)
        XCTAssertNil(empty.wornScarf(for: Self.kid(coins: 10)))
        XCTAssertTrue(empty.ownedStickers(for: Self.kid(coins: 10, owned: ["sticker-rainbow"])).isEmpty)
    }

    // MARK: Helpers

    private static func problems(in json: String) throws -> [String] {
        let catalog = try JSONDecoder().decode(ShopCatalog.self, from: Data(json.utf8))
        return catalog.validationProblems()
    }

    private static func kid(coins: Int, owned: Set<String> = [], scarf: String? = nil) -> Kid {
        Kid(id: UUID(), name: "Mia", avatarKind: .girl, avatarColorIndex: 0,
            coins: coins, ownedItemIDs: owned, pennyScarfItemID: scarf)
    }
}
