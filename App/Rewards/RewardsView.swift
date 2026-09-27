//
//  RewardsView.swift
//  Screen 4a: everything a child has earned, in one place — stars, play coins,
//  the streak and Penny's shiny scales (README section 3 "Rewards and progress"),
//  with the two doors that lead off it: the shop and the sticker book.
//
//  Reached from the reward chips on the level map. Nothing here can be bought
//  with real money; play coins come from finishing lessons and nowhere else.
//

import SwiftUI

struct RewardsView: View {
    @EnvironmentObject private var app: AppState

    var body: some View {
        if let kid = app.selectedKid {
            content(for: kid)
        } else {
            Color.clear.onAppear { app.route = .lessonMap }
        }
    }

    private func content(for kid: Kid) -> some View {
        VStack(spacing: 0) {
            RewardsTopBar(title: "Your rewards", onBack: { app.route = .lessonMap })

            ScrollView {
                VStack(spacing: 18) {
                    earnedRow(for: kid)
                    StreakCard(streak: kid.currentStreak, best: kid.bestStreak, name: kid.name)
                    PennyScalesCard(scales: kid.pennyScales,
                                    scarf: app.shop.wornScarf(for: kid),
                                    name: kid.name)
                    doors(for: kid)
                }
                .padding(.horizontal, 20)
                // The standing layout preference: content sits a little lower on
                // screen rather than centred in it.
                .padding(.top, 28)
                .padding(.bottom, 28)
                .rewardsContentWidth()
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .kidPageBackground()
    }

    // MARK: What's been earned

    private func earnedRow(for kid: Kid) -> some View {
        HStack(spacing: 12) {
            earned(icon: "star", value: "\(kid.totalStars)", label: "Stars",
                   voice: "\(kid.totalStars) stars")
            earned(icon: "coin", value: "\(kid.coins)", label: "Coins to spend",
                   voice: "\(ShopCopy.coins(kid.coins)) to spend")
            earned(icon: "memo", value: "\(kid.lessonsFinished)", label: "Lessons done",
                   voice: "\(kid.lessonsFinished) lessons done")
        }
    }

    private func earned(icon: String, value: String, label: String, voice: String) -> some View {
        VStack(spacing: 6) {
            FluentIcon(name: icon, size: 34)
            Text(value)
                .font(.sectionTitle)
                .foregroundStyle(Palette.textBody)
            Text(label)
                .font(.caption)
                .multilineTextAlignment(.center)
                .foregroundStyle(Palette.textFaint)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 16)
        .padding(.horizontal, 6)
        .background(.white, in: RoundedRectangle(cornerRadius: Radius.bubble, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: Radius.bubble, style: .continuous)
                .stroke(Palette.borderField, lineWidth: Border.hairline)
        )
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(voice)
    }

    // MARK: Where to go next

    private func doors(for kid: Kid) -> some View {
        let stickers = app.shop.ownedStickers(for: kid).count
        return VStack(spacing: 12) {
            Button("Spend your coins") { app.route = .shop }
                .buttonStyle(BigButtonStyle(fill: Palette.teal))
                .accessibilityHint("Opens Penny's shop. You have \(ShopCopy.coins(kid.coins)).")

            Button(stickers == 0 ? "My sticker book" : "My sticker book (\(stickers))") {
                app.route = .stickerBook
            }
            .buttonStyle(BigButtonStyle(fill: Palette.copper))
            .accessibilityLabel("My sticker book")
            .accessibilityValue(stickers == 1 ? "1 sticker" : "\(stickers) stickers")
        }
    }
}

#if DEBUG
#Preview {
    RewardsView().environmentObject(AppState.preview())
}
#endif
