//
//  ShopContent.swift
//  The play-coin shop's content schema: the Swift side of App/Content/shop.json.
//
//  Like lessons, the shop is DATA. What is for sale, what it costs and what it
//  is called all live in the JSON, so pricing and wording can be tuned without
//  a Swift change (App/Content is a folder reference, so no `xcodegen generate`
//  either).
//
//  Play coins are pretend money earned by learning. They can NEVER be bought
//  with real money: there is no in-app purchase anywhere in this file or in the
//  screens that use it, and there never will be (README section 9, "No
//  purchases for kids").
//
//  Adding a new KIND of item later — avatar outfits are the next one, and belong
//  to the avatar-builder work — takes three steps and no new screen:
//    1. add a case to `ShopItemKind` and say whether it is worn or collected;
//    2. give `Kid` the "which one is worn" field if it is worn (stickers just
//       accumulate, so they need nothing);
//    3. add the section to shop.json.
//  The shop and the collection render whatever sections the JSON declares.
//

import SwiftUI

// MARK: - Catalog

/// Everything on sale, as read from Content/shop.json.
struct ShopCatalog: Decodable {
    let schemaVersion: Int
    let sections: [ShopSection]

    /// The schema version this build understands. Bump it (and migrate) only if
    /// a change is not backwards compatible.
    static let supportedSchemaVersion = 1

    static let empty = ShopCatalog(schemaVersion: supportedSchemaVersion, sections: [])

    var items: [ShopItem] { sections.flatMap(\.items) }
}

/// One shelf in the shop: a title, a kid-sized line about it, and its items.
/// Every item in a section is of the section's kind.
struct ShopSection: Decodable, Identifiable, Hashable {
    let id: String
    let title: String
    /// One short line for children (README section 7: 12 words or fewer).
    let kidSummary: String
    let kind: ShopItemKind
    let items: [ShopItem]
}

/// What a bought item does for the child.
///
/// `sticker`s are **collected**: buying one adds it to the sticker book, and a
/// child can own every one of them. A `pennyScarf` is **worn**: a child can own
/// several colours but Penny wears one at a time, so buying is followed by
/// choosing. Avatar outfits will be worn too (see the file header).
enum ShopItemKind: String, Decodable, CaseIterable {
    case sticker
    case pennyScarf

    /// True when only one item of this kind can be in use at a time, so the
    /// shop offers "Wear it" after a purchase instead of just a check.
    var isWorn: Bool {
        switch self {
        case .sticker:    return false
        case .pennyScarf: return true
        }
    }
}

/// One thing a child can buy with play coins.
///
/// A sticker carries an `icon` (a Fluent Emoji 3D picture in Assets.xcassets);
/// a scarf carries a `paletteIndex` into `Palette.avatarChoices`, so colours
/// stay inside the Penny Design System instead of arriving as loose hex in a
/// content file.
struct ShopItem: Decodable, Identifiable, Hashable {
    let id: String
    let name: String
    /// Play coins. 0 means it is Penny's own colour — always available, so a
    /// child can never get stuck with a scarf they don't like.
    let price: Int
    let icon: String?
    let paletteIndex: Int?

    var isFree: Bool { price == 0 }

    /// The swatch colour for a worn colour item.
    var color: Color? {
        guard let paletteIndex, Palette.avatarChoices.indices.contains(paletteIndex) else { return nil }
        return Palette.avatarChoices[paletteIndex]
    }
}

// MARK: - Validation

extension ShopCatalog {

    /// Every problem in the file at once, written for whoever edits the JSON.
    /// An empty array means the catalog is usable.
    func validationProblems() -> [String] {
        var problems: [String] = []

        if sections.isEmpty { problems.append("shop.json has no sections, so the shop would be empty.") }

        let sectionIDs = sections.map(\.id)
        for duplicate in Set(sectionIDs.filter { id in sectionIDs.filter { $0 == id }.count > 1 }).sorted() {
            problems.append("shop.json repeats the section id \"\(duplicate)\".")
        }

        let itemIDs = items.map(\.id)
        for duplicate in Set(itemIDs.filter { id in itemIDs.filter { $0 == id }.count > 1 }).sorted() {
            problems.append("shop.json repeats the item id \"\(duplicate)\"; ids are what a purchase is saved under.")
        }

        for section in sections {
            problems += section.validationProblems()
        }
        return problems
    }
}

extension ShopSection {

    func validationProblems() -> [String] {
        var problems: [String] = []
        let place = "shop.json section \"\(id)\""

        if items.isEmpty { problems.append("\(place) has no items.") }
        if kidSummary.isEmpty { problems.append("\(place) has no \"kidSummary\" line.") }

        for item in items {
            let itemPlace = "\(place), item \"\(item.id)\""
            if item.name.isEmpty { problems.append("\(itemPlace) has no \"name\".") }
            if item.price < 0 {
                problems.append("\(itemPlace) has a negative price; play coins are only ever earned and spent.")
            }
            // README section 7 rule 8: kid-sized whole numbers, up to 100.
            if item.price > ShopRules.highestPrice {
                problems.append("\(itemPlace) costs \(item.price) coins; keep prices at \(ShopRules.highestPrice) or under (README section 7 rule 8).")
            }

            switch kind {
            case .sticker:
                guard let icon = item.icon else {
                    problems.append("\(itemPlace) is a sticker, so it needs an \"icon\".")
                    continue
                }
                if !ContentArt.exists(icon) {
                    problems.append("\(itemPlace) asks for the picture \"\(icon)\", which is not in Assets.xcassets/Icons.")
                }
            case .pennyScarf:
                guard let index = item.paletteIndex else {
                    problems.append("\(itemPlace) is a scarf colour, so it needs a \"paletteIndex\".")
                    continue
                }
                if !Palette.avatarChoices.indices.contains(index) {
                    problems.append("\(itemPlace) has paletteIndex \(index); Palette.avatarChoices only has \(Palette.avatarChoices.count) colours.")
                }
            }
        }

        // A worn kind needs one item a child always has, or they could buy a
        // colour and never be able to go back to Penny's own.
        if kind.isWorn, !items.contains(where: \.isFree) {
            problems.append("\(place) is worn, so one item must cost 0 coins for a child to always be able to change back.")
        }
        return problems
    }
}

/// The few shop numbers that are rules rather than content.
enum ShopRules {
    /// README section 7 rule 8 keeps money numbers kid-sized.
    static let highestPrice = 100
}

// MARK: - Errors

/// Anything that can go wrong loading shop.json. Messages always name the file,
/// because a typo there must be obvious to whoever priced the shop.
enum ShopContentError: LocalizedError {
    case missingFile
    case unsupportedSchemaVersion(found: Int, supported: Int)
    case decoding(detail: String)
    case invalid(problems: [String])

    var errorDescription: String? {
        switch self {
        case .missingFile:
            return "Content/shop.json is missing from the app bundle."
        case .unsupportedSchemaVersion(let found, let supported):
            return "shop.json has schemaVersion \(found); this build understands \(supported)."
        case .decoding(let detail):
            return "shop.json could not be read: \(detail)"
        case .invalid(let problems):
            return "shop.json is not a valid shop:\n" + problems.map { "  • \($0)" }.joined(separator: "\n")
        }
    }
}
