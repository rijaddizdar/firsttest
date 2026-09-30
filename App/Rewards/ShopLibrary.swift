//
//  ShopLibrary.swift
//  Loads Content/shop.json, validates it, and answers the one question the shop
//  screens ask about an item: what can this child do with it right now?
//
//  The answer is a pure function of the item, the child's coin balance and what
//  they already own, so the budgeting rules — the price is always visible, the
//  balance is always visible, and a child who can't afford something is told
//  kindly how many more coins they need — are unit-testable without a screen.
//
//  There is no in-app purchase and no real-money path of any kind here. Coins
//  come from finishing lessons and nowhere else.
//

import Foundation
import OSLog

struct ShopLibrary {

    let catalog: ShopCatalog
    /// Problems found while loading. Empty on a healthy bundle.
    let issues: [String]

    static let empty = ShopLibrary(catalog: .empty, issues: [])

    private static let log = Logger(subsystem: "app.rewards", category: "shop")

    // MARK: - Lookups

    var sections: [ShopSection] { catalog.sections }
    var items: [ShopItem] { catalog.items }

    func item(_ id: String) -> ShopItem? { items.first { $0.id == id } }

    func section(containing itemID: String) -> ShopSection? {
        sections.first { $0.items.contains { $0.id == itemID } }
    }

    func kind(of itemID: String) -> ShopItemKind? { section(containing: itemID)?.kind }

    func items(ofKind kind: ShopItemKind) -> [ShopItem] {
        sections.filter { $0.kind == kind }.flatMap(\.items)
    }

    /// Penny's own scarf — the free one every child starts with and can always
    /// go back to.
    var defaultScarf: ShopItem? {
        items(ofKind: .pennyScarf).first(where: \.isFree)
    }

    /// The scarf Penny is actually wearing for this child: the one they chose,
    /// or her own colour when they haven't chosen.
    func wornScarf(for kid: Kid) -> ShopItem? {
        wornItem(ofKind: .pennyScarf, for: kid)
    }

    /// The item of a worn kind that is actually in use. A child who has chosen
    /// nothing wears the kind's free item — Penny's own scarf colour — so there
    /// is always exactly one answer.
    func wornItem(ofKind kind: ShopItemKind, for kid: Kid) -> ShopItem? {
        guard kind.isWorn else { return nil }
        if let chosen = kid.chosenItemID(for: kind), let item = item(chosen) { return item }
        return items(ofKind: kind).first(where: \.isFree)
    }

    /// The stickers this child has bought, in shop order so the book fills up
    /// left to right the same way every time.
    func ownedStickers(for kid: Kid) -> [ShopItem] {
        items(ofKind: .sticker).filter { kid.owns($0.id) }
    }

    // MARK: - What a child can do with an item

    /// Everything a shop card needs to know, in one value.
    enum ItemState: Equatable {
        /// Penny is wearing it / it is the chosen one of its kind.
        case worn
        /// Bought, and this kind is worn one at a time — so it can be put on.
        case ownedNotWorn
        /// Bought, and this kind just collects (stickers).
        case collected
        /// Affordable right now.
        case affordable
        /// Free, and not chosen yet — Penny's own scarf colour.
        case free
        /// Short by this many coins.
        case needsMoreCoins(Int)
    }

    /// The state of one item for one child. `kind` comes from the item's
    /// section, so a caller iterating a section already has it.
    func state(of item: ShopItem, kind: ShopItemKind, for kid: Kid) -> ItemState {
        if kind.isWorn, wornItem(ofKind: kind, for: kid)?.id == item.id { return .worn }
        if kid.owns(item.id) { return kind.isWorn ? .ownedNotWorn : .collected }
        // A free item needs no purchase: Penny's own colour is always there.
        if item.isFree { return kind.isWorn ? .free : .affordable }
        let short = item.price - kid.coins
        return short > 0 ? .needsMoreCoins(short) : .affordable
    }

    /// True when buying this item should go through. The store checks the same
    /// thing, so a stale screen can never spend coins a child doesn't have.
    func canBuy(_ item: ShopItem, kind: ShopItemKind, for kid: Kid) -> Bool {
        switch state(of: item, kind: kind, for: kid) {
        case .affordable, .free:                        return true
        case .worn, .ownedNotWorn, .collected,
             .needsMoreCoins:                           return false
        }
    }

    // MARK: - Loading

    /// Load and validate the bundled shop. Throws on an unusable file.
    static func load(from bundle: Bundle = .main) throws -> ShopLibrary {
        guard let url = bundle.url(forResource: "shop", withExtension: "json", subdirectory: "Content")
            ?? bundle.url(forResource: "shop", withExtension: "json") else {
            throw ShopContentError.missingFile
        }

        let data: Data
        do { data = try Data(contentsOf: url) } catch {
            throw ShopContentError.decoding(detail: error.localizedDescription)
        }

        let catalog: ShopCatalog
        do { catalog = try JSONDecoder().decode(ShopCatalog.self, from: data) } catch {
            throw ShopContentError.decoding(detail: error.localizedDescription)
        }

        guard catalog.schemaVersion == ShopCatalog.supportedSchemaVersion else {
            throw ShopContentError.unsupportedSchemaVersion(found: catalog.schemaVersion,
                                                            supported: ShopCatalog.supportedSchemaVersion)
        }

        let problems = catalog.validationProblems()
        guard problems.isEmpty else { throw ShopContentError.invalid(problems: problems) }

        return ShopLibrary(catalog: catalog, issues: [])
    }

    /// Load, or fall back to an empty shop. A bad shop file must never stop a
    /// child from using the app: the map and the lessons carry on and the shop
    /// simply has nothing on its shelves. DEBUG trips an assertion instead, so
    /// whoever edited the JSON sees it.
    static func loadOrEmpty(from bundle: Bundle = .main) -> ShopLibrary {
        do {
            return try load(from: bundle)
        } catch {
            let message = (error as? LocalizedError)?.errorDescription ?? String(describing: error)
            log.error("shop failed to load: \(message, privacy: .public)")
            assertionFailure("Shop content failed to load.\n\(message)")
            return ShopLibrary(catalog: .empty, issues: [message])
        }
    }
}
