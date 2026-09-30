//
//  StickerBookView.swift
//  Screen 4c: the sticker book — the stickers this child has bought with play
//  coins (README section 3: "Kids spend it on stickers and outfits").
//
//  The stickers they own are bright and named. The ones still in the shop are
//  shown as ghosts with their price, so a child can see what saving up would get
//  them — the budgeting half of the reward. It is a shelf, not a scoreboard:
//  there is no completion bar, no percentage and no nudge to buy.
//

import SwiftUI

struct StickerBookView: View {
    @EnvironmentObject private var app: AppState

    var body: some View {
        if let kid = app.selectedKid {
            content(for: kid)
        } else {
            Color.clear.onAppear { app.route = .lessonMap }
        }
    }

    private func content(for kid: Kid) -> some View {
        let all = app.shop.items(ofKind: .sticker)
        let mine = all.filter { kid.owns($0.id) }
        let rest = all.filter { !kid.owns($0.id) }

        return VStack(spacing: 0) {
            RewardsTopBar(title: "My stickers", coins: kid.coins) { app.route = .rewards }

            ScrollView {
                VStack(spacing: 22) {
                    if mine.isEmpty {
                        emptyBook(for: kid)
                    } else {
                        myStickers(mine)
                    }

                    if !rest.isEmpty {
                        stillInTheShop(rest, kid: kid)
                    }

                    Button("Go to the shop") { app.route = .shop }
                        .buttonStyle(BigButtonStyle(fill: Palette.teal))
                        .accessibilityHint("You have \(ShopCopy.coins(kid.coins)).")
                }
                .padding(.horizontal, 20)
                // Content sits a little lower on screen, not centred in it.
                .padding(.top, 24)
                .padding(.bottom, 28)
                .rewardsContentWidth()
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .kidPageBackground()
    }

    // MARK: The book

    private func myStickers(_ items: [ShopItem]) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            RewardSectionHeader(title: items.count == 1 ? "1 sticker" : "\(items.count) stickers",
                                summary: nil)
            LazyVGrid(columns: rewardsItemColumns, spacing: 14) {
                ForEach(items) { StickerTile(item: $0) }
            }
        }
    }

    /// Nothing bought yet. Penny says so warmly and points at the shop; no
    /// empty grid staring back at the child.
    private func emptyBook(for kid: Kid) -> some View {
        VStack(spacing: 14) {
            PennyView(mood: .idle, size: 130)
            SpeechBubble(text: ShopCopy.emptyStickerBook(name: kid.name))
        }
    }

    // MARK: Still to come

    private func stillInTheShop(_ items: [ShopItem], kid: Kid) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            RewardSectionHeader(title: "Still in the shop",
                                summary: "Save up your coins for these.")
            LazyVGrid(columns: rewardsItemColumns, spacing: 14) {
                ForEach(items) { item in
                    StickerGhost(item: item,
                                 state: app.shop.state(of: item, kind: .sticker, for: kid)) {
                        app.route = .shop
                    }
                }
            }
        }
    }
}

// MARK: - Tiles

/// A sticker the child owns: full colour, named, on a white page.
struct StickerTile: View {
    let item: ShopItem

    var body: some View {
        VStack(spacing: 8) {
            FluentIcon(name: item.icon ?? "sparkles", size: 64)
            Text(item.name)
                .font(.rowTitle)
                .multilineTextAlignment(.center)
                .foregroundStyle(Palette.textBody)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 18)
        .padding(.horizontal, 8)
        .background(.white, in: RoundedRectangle(cornerRadius: Radius.button, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: Radius.button, style: .continuous)
                .stroke(Palette.stateCorrectBorder, lineWidth: Border.bubble)
        )
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(item.name) sticker")
        .accessibilityValue("Yours")
    }
}

/// A sticker still in the shop: the picture greyed back, with its price. It
/// shows what is possible without ever telling the child to hurry up.
struct StickerGhost: View {
    let item: ShopItem
    let state: ShopLibrary.ItemState
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: 8) {
                FluentIcon(name: item.icon ?? "sparkles", size: 56)
                    .grayscale(1)
                    .opacity(0.35)
                Text(item.name)
                    .font(.rowSub)
                    .multilineTextAlignment(.center)
                    .foregroundStyle(Palette.textFaint)
                    .fixedSize(horizontal: false, vertical: true)
                HStack(spacing: 5) {
                    FluentIcon(name: "coin", size: 16)
                    Text(ShopCopy.price(item))
                        .font(.caption.weight(.bold))
                        .foregroundStyle(Palette.textSoft)
                }
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 16)
            .padding(.horizontal, 8)
            .background(.white, in: RoundedRectangle(cornerRadius: Radius.button, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: Radius.button, style: .continuous)
                    .stroke(Palette.lockGrey.opacity(0.5),
                            style: StrokeStyle(lineWidth: Border.field, dash: [5]))
            )
        }
        .buttonStyle(PressableStyle())
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(item.name) sticker")
        .accessibilityValue(value)
        .accessibilityHint("Tap to open the shop.")
    }

    private var value: String {
        switch state {
        case .needsMoreCoins(let missing):
            return "Costs \(ShopCopy.coins(item.price)). You need \(ShopCopy.coins(missing)) more."
        default:
            return "Costs \(ShopCopy.coins(item.price)). You can buy it now."
        }
    }
}

#if DEBUG
#Preview {
    StickerBookView().environmentObject(AppState.preview())
}
#endif
