//
//  ShopView.swift
//  Screen 4b: Penny's shop, where play coins are spent on stickers and on the
//  colour of Penny's scarf (README section 3 rewards, section 6 customization).
//
//  It is deliberately a BUDGETING screen, not a giveaway: the balance is pinned
//  in the top bar, every card carries its price, and a child who can't afford
//  something is told kindly by Penny exactly how many more coins they need and
//  how to earn them. Nothing is ever refused with a cross or a "no".
//
//  Play coins can NEVER be bought with real money. There is no in-app purchase,
//  no price in currency and no store link anywhere in this screen or under it
//  (README section 9, "No purchases for kids").
//
//  What's on the shelves is data: App/Content/shop.json. Adding avatar outfits
//  later — that work belongs to the avatar builder — is a new section in that
//  file plus one case in `ShopItemKind`; this screen renders whatever sections
//  the catalog declares and needs no change.
//

import SwiftUI

struct ShopView: View {
    @EnvironmentObject private var app: AppState

    /// What Penny is saying right now: the balance to begin with, then the
    /// result of whatever the child last tapped.
    @State private var pennyLine: String?
    @State private var pennyMood: PennyMood = .idle
    /// Set when a purchase just happened, so the coins fly once.
    @State private var burst = false

    var body: some View {
        if let kid = app.selectedKid {
            content(for: kid)
        } else {
            Color.clear.onAppear { app.route = .lessonMap }
        }
    }

    private func content(for kid: Kid) -> some View {
        ZStack {
            VStack(spacing: 0) {
                RewardsTopBar(title: "Penny's shop", coins: kid.coins) { app.route = .rewards }

                ScrollView {
                    VStack(spacing: 22) {
                        pennyHeader(for: kid)

                        ForEach(shownSections) { section in
                            shelf(section, kid: kid)
                        }

                        stickerBookLink(for: kid)
                        realMoneyNote
                    }
                    .padding(.horizontal, 20)
                    // Content sits a little lower on screen, not centred in it.
                    .padding(.top, 24)
                    .padding(.bottom, 28)
                    .rewardsContentWidth()
                }
            }
            CoinBurst(isActive: burst).allowsHitTesting(false)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .kidPageBackground()
        .onAppear { applyUITestTap(for: kid) }
    }

    // MARK: Screenshot hooks
    //
    // Absent in normal use. They drive the real tap handler rather than faking a
    // state, so a screenshot shows what a child would actually see, and seeded
    // runs use a throwaway store (see PersistenceController.makeContainer).

    /// `UITEST_SHOP_SECTION=pennys-scarf` — show one shelf, so a shelf further
    /// down the page can be captured without scrolling.
    private var shownSections: [ShopSection] {
        guard let wanted = ProcessInfo.processInfo.environment["UITEST_SHOP_SECTION"] else {
            return app.shop.sections
        }
        let matching = app.shop.sections.filter { $0.id == wanted }
        return matching.isEmpty ? app.shop.sections : matching
    }

    /// `UITEST_SHOP_TAP=sticker-unicorn` — tap that item once on appear, whatever
    /// its state: buying it, wearing it, or hearing how many more coins it needs.
    private func applyUITestTap(for kid: Kid) {
        guard let itemID = ProcessInfo.processInfo.environment["UITEST_SHOP_TAP"],
              let item = app.shop.item(itemID),
              let kind = app.shop.kind(of: itemID) else { return }
        tap(item, kind: kind, kid: kid)
    }

    // MARK: Penny's line

    /// Penny opens with the balance, so the first thing a child reads in the shop
    /// is how much they have to spend.
    private func pennyHeader(for kid: Kid) -> some View {
        VStack(spacing: 12) {
            PennyView(mood: pennyMood, size: 110)
            SpeechBubble(text: pennyLine ?? ShopCopy.balance(kid.coins))
        }
        .onAppear { if pennyLine == nil { pennyMood = .idle } }
    }

    // MARK: One shelf

    private func shelf(_ section: ShopSection, kid: Kid) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            RewardSectionHeader(title: section.title, summary: section.kidSummary)

            LazyVGrid(columns: rewardsItemColumns, spacing: 14) {
                ForEach(section.items) { item in
                    ShopItemCard(item: item,
                                 kind: section.kind,
                                 state: app.shop.state(of: item, kind: section.kind, for: kid)) {
                        tap(item, kind: section.kind, kid: kid)
                    }
                }
            }
        }
    }

    // MARK: Tapping an item

    /// One tap does whatever the item's state allows: buy it, wear it, or hear
    /// kindly how many more coins it needs. It never does nothing silently.
    private func tap(_ item: ShopItem, kind: ShopItemKind, kid: Kid) {
        switch app.shop.state(of: item, kind: kind, for: kid) {
        case .worn, .collected:
            say(ShopCopy.nowWearing(item, name: kid.name), mood: .cheer)

        case .ownedNotWorn:
            app.wear(item, kind: kind)
            say(ShopCopy.nowWearing(item, name: kid.name), mood: .cheer)
            Haptics.rightAnswerTap()

        case .affordable, .free:
            let priceThen = item.price
            guard app.buy(item, kind: kind) else { return }
            let left = (app.selectedKid?.coins ?? kid.coins - priceThen)
            say(ShopCopy.bought(item, kind: kind, name: kid.name, coinsLeft: left), mood: .cheer)
            Haptics.success()
            LessonAudio.play(.celebrate)
            burst = false
            DispatchQueue.main.async { burst = true }

        case .needsMoreCoins(let missing):
            // Not a refusal: Penny says the number and how to get there.
            say(ShopCopy.cannotAffordYet(missing: missing, name: kid.name), mood: .encourage)
        }
    }

    private func say(_ line: String, mood: PennyMood) {
        pennyLine = line
        pennyMood = mood
    }

    // MARK: Footers

    private func stickerBookLink(for kid: Kid) -> some View {
        let stickers = app.shop.ownedStickers(for: kid).count
        return Button(stickers == 0 ? "My sticker book" : "My sticker book (\(stickers))") {
            app.route = .stickerBook
        }
        .buttonStyle(BigButtonStyle(fill: Palette.copper))
        .accessibilityLabel("My sticker book")
        .accessibilityValue(stickers == 1 ? "1 sticker" : "\(stickers) stickers")
    }

    /// Honest, and short enough for a child to read: these coins are pretend.
    private var realMoneyNote: some View {
        Text("Play coins come from learning. Nothing here costs real money.")
            .font(.caption)
            .multilineTextAlignment(.center)
            .foregroundStyle(Palette.textFaint)
            .frame(maxWidth: .infinity)
    }
}

#if DEBUG
#Preview {
    ShopView().environmentObject(AppState.preview())
}
#endif
