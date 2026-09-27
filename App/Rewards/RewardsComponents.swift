//
//  RewardsComponents.swift
//  The pieces the three reward screens are built from, so the rewards area
//  looks like the rest of the app: the top bar, the coin balance, the streak
//  card, Penny with her scales and scarf, and the shop item card.
//
//  Everything visual comes from the Penny Design System tokens in Theme.swift —
//  palette, radii, border widths, motion. Nothing here hard-codes a colour or a
//  corner radius, there is no red, green never leads, and the streak icon is a
//  coin rather than a flame.
//

import SwiftUI

// MARK: - Top bar

/// Back button, one screen title, and (where money matters) the child's balance.
/// The balance sits in the bar on the shop and the sticker book so a child can
/// always see what they have while they are deciding what to spend.
struct RewardsTopBar: View {
    let title: String
    /// Nil hides the balance pill.
    var coins: Int?
    let onBack: () -> Void

    var body: some View {
        HStack(spacing: 12) {
            Button(action: onBack) {
                Image(systemName: "chevron.left.circle.fill")
                    .font(.title)
                    .foregroundStyle(Palette.teal)
            }
            .buttonStyle(PressableStyle())
            .accessibilityLabel("Back")

            Text(title)
                .font(.sectionTitle)
                .foregroundStyle(Palette.textHeading)
                .lineLimit(1)
                .minimumScaleFactor(0.8)

            Spacer(minLength: 8)

            if let coins {
                CoinBalancePill(coins: coins)
            }
        }
        .padding(.horizontal, 20)
        .padding(.top, 12)
    }
}

/// How many play coins the child has right now. Always visible while shopping,
/// because seeing the balance next to the price is what makes this budgeting
/// practice rather than a giveaway (README section 3).
struct CoinBalancePill: View {
    let coins: Int

    var body: some View {
        HStack(spacing: 6) {
            FluentIcon(name: "coin", size: 24)
            Text("\(coins)")
                .font(.sectionTitle)
                .foregroundStyle(Palette.textBody)
                .contentTransition(.numericText())
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 8)
        .background(.white, in: Capsule())
        .overlay(Capsule().stroke(Palette.copper, lineWidth: Border.field))
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("You have \(ShopCopy.coins(coins))")
    }
}

// MARK: - Streak

/// Days in a row with a finished lesson. A missed day is greeted, never counted
/// against the child: there is no warning, no countdown and no broken-streak
/// language anywhere on this card (README section 3, section 7 rule 6).
struct StreakCard: View {
    let streak: Int
    let best: Int
    let name: String

    var body: some View {
        RewardCard {
            HStack(spacing: 14) {
                // The streak icon is a coin, never a flame.
                FluentIcon(name: "coin", size: 44)
                VStack(alignment: .leading, spacing: 4) {
                    Text(StreakCopy.headline(streak: streak, best: best, name: name))
                        .font(.rowTitle)
                        .foregroundStyle(Palette.textBody)
                        .fixedSize(horizontal: false, vertical: true)
                    if let detail = StreakCopy.detail(streak: streak, best: best) {
                        Text(detail)
                            .font(.rowSub)
                            .foregroundStyle(Palette.textSoft)
                    }
                }
                Spacer(minLength: 0)
            }
        }
        .accessibilityElement(children: .combine)
    }
}

// MARK: - Penny's scales and scarf

/// Penny, the colour she is wearing, and the shiny scales this child has earned
/// for her by finishing levels.
///
/// **Art note.** Penny's poses are fixed placeholder drawings, so neither the
/// scales nor the scarf colour can be painted onto her yet. Until the
/// commissioned 3D Penny lands (README section 8), the scales are drawn beside
/// her as a counted row and the scarf colour as a swatch. Both read honestly and
/// neither pretends the art is there.
struct PennyScalesCard: View {
    let scales: Int
    let scarf: ShopItem?
    let name: String

    var body: some View {
        RewardCard {
            VStack(spacing: 14) {
                PennyView(mood: .cheer, size: 130)

                if let scarf, let color = scarf.color {
                    HStack(spacing: 8) {
                        Capsule()
                            .fill(color)
                            .frame(width: 34, height: 14)
                            .overlay(Capsule().stroke(Palette.borderBubble, lineWidth: Border.hairline))
                        Text("Scarf: \(scarf.name)")
                            .font(.rowSub)
                            .foregroundStyle(Palette.textSoft)
                    }
                    .accessibilityElement(children: .ignore)
                    .accessibilityLabel("Penny is wearing her \(scarf.name.lowercased()) scarf")
                }

                ScaleRow(scales: scales)

                Text(PennyScales.line(scales: scales, name: name))
                    .font(.rowTitle)
                    .multilineTextAlignment(.center)
                    .foregroundStyle(Palette.textBody)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .frame(maxWidth: .infinity)
        }
    }
}

/// A row of Penny's shiny scales, capped so a long run of levels doesn't stretch
/// off the card. The number is the truth; the row is the picture of it.
struct ScaleRow: View {
    let scales: Int

    var body: some View {
        let shown = min(scales, PennyScales.mostShownAtOnce)
        HStack(spacing: 3) {
            ForEach(0..<max(shown, 1), id: \.self) { index in
                if shown == 0 {
                    // Nothing earned yet: one empty slot, so the row still reads
                    // as a place scales will go.
                    scaleShape.fill(Palette.lockGrey.opacity(0.35))
                } else {
                    scaleShape
                        .fill(index.isMultiple(of: 3) ? Palette.skyTeal : Palette.copper)
                        .overlay(sheen, alignment: .top)
                }
            }
            if scales > shown {
                Text("+\(scales - shown)")
                    .font(.caption.weight(.bold))
                    .foregroundStyle(Palette.copper)
                    .padding(.leading, 4)
            }
        }
        .frame(height: 20)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(scales == 0 ? "No scales yet" : "\(scales) shiny scales")
    }

    /// A shell scale: rounded at the top, flat where it tucks under the next row.
    private var scaleShape: UnevenRoundedRectangle {
        UnevenRoundedRectangle(topLeadingRadius: 8, bottomLeadingRadius: 2,
                               bottomTrailingRadius: 2, topTrailingRadius: 8,
                               style: .continuous)
    }

    /// The gloss the design system asks of Penny's shell, at scale-row size.
    private var sheen: some View {
        Capsule()
            .fill(.white.opacity(0.35))
            .frame(width: 6, height: 4)
            .padding(.top, 3)
    }
}

// MARK: - Shop item card

/// One thing for sale. The price and what the child can do about it are always
/// on the card, and a card a child can't afford yet still responds to a tap so
/// Penny can say — kindly — how many more coins it needs.
struct ShopItemCard: View {
    let item: ShopItem
    let kind: ShopItemKind
    let state: ShopLibrary.ItemState
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: 10) {
                picture
                Text(item.name)
                    .font(.rowTitle)
                    .multilineTextAlignment(.center)
                    .foregroundStyle(Palette.textBody)
                    .fixedSize(horizontal: false, vertical: true)
                statusLine
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 16)
            .padding(.horizontal, 10)
            .background(fill, in: RoundedRectangle(cornerRadius: Radius.button, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: Radius.button, style: .continuous)
                    .stroke(border, lineWidth: borderWidth)
            )
        }
        .buttonStyle(PressableStyle())
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(item.name)
        .accessibilityValue(accessibilityValue)
        .accessibilityHint(accessibilityHint)
    }

    // MARK: Picture

    /// A sticker shows its Fluent Emoji 3D picture; a colour shows its colour.
    @ViewBuilder
    private var picture: some View {
        if let icon = item.icon {
            FluentIcon(name: icon, size: 56)
        } else if let color = item.color {
            Circle()
                .fill(color)
                .frame(width: 56, height: 56)
                .overlay(Circle().stroke(.white.opacity(0.5), lineWidth: Border.bubble))
        } else {
            FluentIcon(name: "sparkles", size: 56)
        }
    }

    // MARK: Status

    /// The price, or what the child already has. Never "no", never a cross.
    @ViewBuilder
    private var statusLine: some View {
        switch state {
        case .worn:
            chip(text: kind == .pennyScarf ? "Penny's wearing it" : "Yours",
                 icon: "check-mark", tint: Palette.teal)
        case .collected:
            chip(text: "Yours", icon: "check-mark", tint: Palette.teal)
        case .ownedNotWorn:
            chip(text: "Tap to wear", icon: "sparkles", tint: Palette.teal)
        case .affordable, .free:
            chip(text: ShopCopy.price(item), icon: "coin", tint: Palette.copper)
        case .needsMoreCoins(let missing):
            VStack(spacing: 3) {
                chip(text: ShopCopy.price(item), icon: "coin", tint: Palette.lockGrey)
                Text(ShopCopy.short(by: missing))
                    .font(.caption.weight(.bold))
                    .foregroundStyle(Palette.copper)
            }
        }
    }

    private func chip(text: String, icon: String, tint: Color) -> some View {
        HStack(spacing: 5) {
            FluentIcon(name: icon, size: 18)
            Text(text)
                .font(.footnote.weight(.bold))
                .foregroundStyle(Palette.textBody)
                .lineLimit(1)
                .minimumScaleFactor(0.8)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 5)
        .background(.white, in: Capsule())
        .overlay(Capsule().stroke(tint, lineWidth: Border.hairline))
    }

    // MARK: Surfaces

    /// Every card is white. An owned one is marked by its teal border, its check
    /// and the word "Yours" — not by a fill, because a grid half-full of mint
    /// would make green lead the screen, which the design system forbids.
    private var fill: Color { Palette.surfaceCard }

    private var border: Color {
        switch state {
        case .worn, .collected: return Palette.stateCorrectBorder
        case .ownedNotWorn:     return Palette.teal
        case .affordable, .free: return Palette.borderField
        case .needsMoreCoins:   return Palette.lockGrey.opacity(0.6)
        }
    }

    private var borderWidth: CGFloat {
        switch state {
        case .worn, .collected, .ownedNotWorn: return Border.bubble
        case .affordable, .free, .needsMoreCoins: return Border.field
        }
    }

    // MARK: VoiceOver

    private var accessibilityValue: String {
        switch state {
        case .worn:        return kind == .pennyScarf ? "Penny is wearing it" : "Yours"
        case .collected:   return "Yours"
        case .ownedNotWorn: return "Yours, not worn"
        case .free:        return "Free"
        case .affordable:  return "Costs \(ShopCopy.coins(item.price))"
        case .needsMoreCoins(let missing):
            return "Costs \(ShopCopy.coins(item.price)). You need \(ShopCopy.coins(missing)) more."
        }
    }

    private var accessibilityHint: String {
        switch state {
        case .worn, .collected:            return ""
        case .ownedNotWorn:                return "Tap to put it on Penny."
        case .affordable, .free:           return "Tap to buy it."
        case .needsMoreCoins:              return "Finish a lesson to earn more coins."
        }
    }
}

// MARK: - Cards and section headers

/// The plain white card the reward screens use. Flat cream page, flat white
/// card, hairline border — the design system keeps its one shadow for Penny's
/// speech bubble.
struct RewardCard<Content: View>: View {
    @ViewBuilder let content: Content

    var body: some View {
        content
            .padding(18)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(.white, in: RoundedRectangle(cornerRadius: Radius.button, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: Radius.button, style: .continuous)
                    .stroke(Palette.borderField, lineWidth: Border.hairline)
            )
    }
}

/// A shelf heading in the shop, with its one kid-sized line.
struct RewardSectionHeader: View {
    let title: String
    let summary: String?

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(title)
                .font(.sectionTitle)
                .foregroundStyle(Palette.textHeading)
            if let summary {
                Text(summary)
                    .font(.rowSub)
                    .foregroundStyle(Palette.textSoft)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .accessibilityElement(children: .combine)
        .accessibilityAddTraits(.isHeader)
    }
}

// MARK: - Layout

extension View {
    /// Reward screens are read and tapped, so they take the same comfortable
    /// measure as a lesson instead of stretching across an iPad.
    func rewardsContentWidth() -> some View {
        frame(maxWidth: 620)
            .frame(maxWidth: .infinity)
    }
}

/// The grid the shop and the sticker book share: as many columns as fit, never
/// so narrow that a 56pt picture and its price crowd each other.
let rewardsItemColumns = [GridItem(.adaptive(minimum: 150, maximum: 210), spacing: 14)]
