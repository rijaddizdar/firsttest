//
//  RewardsRules.swift
//  The reward rules and every word a child reads about them, in one testable
//  place: Penny's scales, the streak, and the shop's money talk.
//
//  All of it follows README section 7. Sentences stay under 12 words, they talk
//  to the child by name, and nothing here ever scolds, hurries or guilt-trips —
//  a missed day is greeted, not counted against anybody (README section 3,
//  "A missed day never scolds or guilt-trips the child").
//
//  Numbers stay kid-sized (rule 8): scales come three at a time, prices are
//  whole play coins, and there are no real prices anywhere.
//

import Foundation

// MARK: - Penny's scales

/// "Finishing a level adds new shiny scales to Penny" (README section 3).
///
/// Penny's current art is a fixed placeholder drawing, so the scales cannot yet
/// appear on her shell. Until the commissioned 3D Penny arrives, the count is
/// recorded per child and shown next to her as a badge and a row of scale
/// shapes. See the note in `PennyScalesCard`.
enum PennyScales {

    /// How many scales one finished level is worth.
    static let perLevel = 3

    /// Penny's shell on the rewards screen, once the art can show them.
    static let mostShownAtOnce = 12

    /// The line under Penny on the rewards screen.
    static func line(scales: Int, name: String) -> String {
        guard scales > 0 else {
            return "Finish a level and Penny gets her first shiny scales."
        }
        return "Penny has \(scales) shiny \(scales == 1 ? "scale" : "scales"), \(name). You did that!"
    }

    /// The line on the Yay! screen when a level was just finished.
    static func justEarnedLine(scales: Int, name: String) -> String {
        "You finished a level, \(name)! Penny got \(scales) new scales."
    }
}

// MARK: - The streak

/// Days in a row with at least one finished lesson. The counting is in
/// `ProgressStore`; the words are here.
enum StreakCopy {

    /// The headline on the streak card.
    static func headline(streak: Int, best: Int, name: String) -> String {
        switch streak {
        case 0 where best == 0:
            return "Finish a lesson to start your streak, \(name)!"
        case 0:
            return "Welcome back, \(name)! Let's start a new streak today."
        case 1:
            return "You learned today, \(name). That's day one!"
        default:
            return "\(streak) days in a row, \(name). Nice going!"
        }
    }

    /// The quiet second line. Nil when there is nothing kind to add — never a
    /// warning, a countdown or a word about a day that was missed.
    static func detail(streak: Int, best: Int) -> String? {
        guard best > 0 else { return nil }
        if streak >= best { return "This is your best run yet." }
        return "Your best run is \(best) \(best == 1 ? "day" : "days")."
    }
}

// MARK: - Money talk

/// The shop's wording. Prices and the balance are always shown together, so a
/// child can see what they have and what a thing costs — which is the point of
/// spending play coins at all (README section 3).
enum ShopCopy {

    /// "5 coins" / "1 coin", so no sentence ever reads "1 coins".
    static func coins(_ count: Int) -> String {
        "\(count) \(count == 1 ? "coin" : "coins")"
    }

    /// The balance, shown at the top of the shop and after every purchase.
    static func balance(_ coins: Int) -> String {
        coins == 0 ? "You have no coins yet." : "You have \(self.coins(coins))."
    }

    /// A price as it appears on an item card. Penny's own colour is free.
    static func price(_ item: ShopItem) -> String {
        item.isFree ? "Free" : coins(item.price)
    }

    /// The short label on a card a child can't afford yet. Kind and factual,
    /// with no "but" and no pressure.
    static func short(by missing: Int) -> String {
        "\(coins(missing)) more"
    }

    /// Penny's line when a child taps something they can't afford yet. It says
    /// exactly how many more coins they need, and how to get them.
    static func cannotAffordYet(missing: Int, name: String) -> String {
        "Almost, \(name)! You need \(coins(missing)) more. Finish a lesson to earn some."
    }

    /// Penny's line right after a purchase.
    static func bought(_ item: ShopItem, kind: ShopItemKind, name: String, coinsLeft: Int) -> String {
        let left = coinsLeft == 0 ? "You have no coins left." : "You have \(coins(coinsLeft)) left."
        switch kind {
        case .sticker:    return "The \(item.name.lowercased()) is yours, \(name)! \(left)"
        case .pennyScarf: return "Penny loves her \(item.name.lowercased()) scarf, \(name)! \(left)"
        }
    }

    /// Penny's line when a child picks a colour they already own.
    static func nowWearing(_ item: ShopItem, name: String) -> String {
        "Penny is wearing \(item.name.lowercased()) now, \(name)."
    }

    /// The line on an empty sticker book.
    static func emptyStickerBook(name: String) -> String {
        "No stickers yet, \(name). Buy one in the shop with your coins."
    }
}
