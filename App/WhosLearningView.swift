//
//  WhosLearningView.swift
//  "Who's learning?" — each child taps their own avatar (README section 6).
//  Also holds the small, out-of-the-way entry to the grown-up area.
//

import SwiftUI

struct WhosLearningView: View {
    @EnvironmentObject private var app: AppState

    private let gridSpacing: CGFloat = 20
    private let gridPadding: CGFloat = 24

    var body: some View {
        GeometryReader { proxy in
            VStack(spacing: 0) {
                grownUpsRow

                // Avatar (and Penny) sizes, largest first. ViewThatFits draws
                // the first candidate that fits the space left under the header,
                // so the grid is never laid out taller than the screen and never
                // ends on a half-cut circle. Penny shrinks and finally drops
                // out before the avatars do: a sliced avatar is a bug, a smaller
                // mascot is not.
                ViewThatFits(in: .vertical) {
                    picker(width: proxy.size.width, avatar: 96, penny: 120)
                    picker(width: proxy.size.width, avatar: 96, penny: 96)
                    picker(width: proxy.size.width, avatar: 84, penny: 88)
                    picker(width: proxy.size.width, avatar: 72, penny: 72)
                    picker(width: proxy.size.width, avatar: 64, penny: 0)
                    picker(width: proxy.size.width, avatar: 56, penny: 0)

                    // Only reached when even 56pt avatars don't fit — an
                    // accessibility Dynamic Type size, or a very large family.
                    // Then the screen scrolls, and says so.
                    ScrollingPicker {
                        picker(width: proxy.size.width, avatar: 56, penny: 0)
                    }
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        }
        .kidPageBackground()
    }

    // MARK: - Header

    private var grownUpsRow: some View {
        HStack {
            Spacer()
            // Parent-area entry. Small and top-corner so a child doesn't
            // wander in; it still leads to the code gate.
            Button {
                app.route = .parentGate
            } label: {
                HStack(spacing: 6) {
                    FluentIcon(name: "gear", size: 20)
                    Text("Grown-ups")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(Palette.teal)
                }
            }
            .buttonStyle(PressableStyle())
        }
        .padding(.horizontal, 20)
        .padding(.top, 12)
    }

    // MARK: - The picker itself

    @ViewBuilder
    private func picker(width: CGFloat, avatar: CGFloat, penny: CGFloat) -> some View {
        let columns = columnCount(width: width, avatar: avatar)
        let rows = slotRows(columns: columns)
        // Every cell is the same width, so the circles line up in even columns
        // whatever the names around them are, and each name wraps inside its own
        // cell instead of stretching the column it happens to sit in.
        let cellWidth = (width - gridPadding * 2 - CGFloat(columns - 1) * gridSpacing) / CGFloat(columns)

        VStack(spacing: 24) {
            Text("Who's learning?")
                .font(.screenTitle)
                .foregroundStyle(Palette.textHeading)
                .multilineTextAlignment(.center)

            if penny > 0 {
                PennyView(mood: .wave, size: penny)
            }

            // A plain Grid, not a LazyVGrid: the tiles are few, and only a
            // non-lazy grid reports the height ViewThatFits needs to measure.
            // `.top` keeps every circle in a row on the same line when one name
            // wraps to two lines and its neighbour does not.
            Grid(alignment: .top, horizontalSpacing: gridSpacing, verticalSpacing: gridSpacing) {
                ForEach(rows.indices, id: \.self) { row in
                    GridRow {
                        ForEach(rows[row], id: \.self) { slot in
                            tile(for: slot, avatar: avatar, cellWidth: cellWidth)
                        }
                    }
                }
            }
            .padding(.horizontal, gridPadding)
        }
        .frame(maxWidth: .infinity)
        // Sits a little below the top of the screen rather than centred.
        .padding(.top, 24)
        // Keeps the last row of avatars clear of the bottom edge and the home
        // indicator instead of ending flush against them.
        .padding(.bottom, 32)
    }

    @ViewBuilder
    private func tile(for slot: AvatarSlot, avatar: CGFloat, cellWidth: CGFloat) -> some View {
        switch slot {
        case .kid(let id):
            if let kid = app.kids.first(where: { $0.id == id }) {
                Button {
                    // A brand-new profile gets its own first time — name,
                    // "Make it yours!", meet Penny — before the map.
                    app.openKid(kid.id)
                } label: {
                    AvatarTile(name: kid.name, tint: Palette.textBody) {
                        AvatarBadge(avatar: kid.avatar, size: avatar)
                    }
                    .frame(width: cellWidth)
                }
                .buttonStyle(PressableStyle())
                .accessibilityLabel(kid.name)
                .accessibilityHint(kid.hasFinishedFirstRun ? "Opens your map" : "Set up your profile")
            }

        case .addKid:
            // Add-another-kid tile routes back through the grown-up gate.
            // Dashed lock-grey ring (Penny Design System, shape-borders).
            Button {
                app.route = .parentGate
            } label: {
                AvatarTile(name: "Add kid", tint: Palette.textSoft, bold: false) {
                    ZStack {
                        Circle().stroke(Palette.lockGrey, style: StrokeStyle(lineWidth: Border.choice, dash: [6]))
                        Image(systemName: "plus")
                            .font(.system(size: avatar * 5 / 12)) // 40pt at the full 96pt avatar
                            .foregroundStyle(Palette.lockGrey)
                    }
                    .frame(width: avatar, height: avatar)
                }
                .frame(width: cellWidth)
            }
            .buttonStyle(PressableStyle())
        }
    }

    // MARK: - Grid shape

    private enum AvatarSlot: Hashable {
        case kid(Kid.ID)
        case addKid
    }

    private var slots: [AvatarSlot] {
        app.kids.map { AvatarSlot.kid($0.id) } + [.addKid]
    }

    /// Roughly three rows of avatars are what an iPhone has room for under the
    /// title and Penny, so a bigger family widens the grid instead of adding
    /// rows the screen can't show. Two columns stay the minimum, which leaves
    /// families of up to five children looking exactly as they always have.
    private func columnCount(width: CGFloat, avatar: CGFloat) -> Int {
        let usable = width - gridPadding * 2
        let fit = max(2, Int((usable + gridSpacing) / (avatar + gridSpacing)))
        let wanted = max(2, Int((Double(slots.count) / 3.0).rounded(.up)))
        return min(fit, wanted)
    }

    private func slotRows(columns: Int) -> [[AvatarSlot]] {
        stride(from: 0, to: slots.count, by: columns).map { start in
            Array(slots[start..<min(start + columns, slots.count)])
        }
    }
}

/// The last-resort scrolling picker, used only when no avatar size small enough
/// to fit the whole family on one screen exists (accessibility Dynamic Type, or
/// a family well past eight children).
///
/// A row cut off by the bottom edge with nothing to explain it is what made the
/// screen read as broken, so while there is anything below the fold this shows a
/// "more below" chevron and keeps the scroll bar visible. Both disappear at the
/// end of the list, and the content reserves room for the chevron so it never
/// sits on top of an avatar.
private struct ScrollingPicker<Content: View>: View {
    @ViewBuilder let content: Content

    @State private var viewportHeight: CGFloat = 0
    @State private var contentBottom: CGFloat = 0

    private var hasMoreBelow: Bool { contentBottom > viewportHeight + 1 }

    var body: some View {
        ScrollView {
            content
                .background(
                    GeometryReader { geo in
                        Color.clear.preference(
                            key: ContentBottomKey.self,
                            value: geo.frame(in: .named(pickerSpace)).maxY
                        )
                    }
                )
                .padding(.bottom, 52) // room for the chevron
        }
        .coordinateSpace(name: pickerSpace)
        .scrollIndicators(hasMoreBelow ? .visible : .automatic)
        .background(
            GeometryReader { geo in
                Color.clear.preference(key: ViewportHeightKey.self, value: geo.size.height)
            }
        )
        .overlay(alignment: .bottom) {
            if hasMoreBelow { MoreBelowChevron().padding(.bottom, 12) }
        }
        .onPreferenceChange(ContentBottomKey.self) { contentBottom = $0 }
        .onPreferenceChange(ViewportHeightKey.self) { viewportHeight = $0 }
    }
}

private let pickerSpace = "whosLearningPicker"

private struct ContentBottomKey: PreferenceKey {
    static var defaultValue: CGFloat = 0
    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
        value = max(value, nextValue())
    }
}

private struct ViewportHeightKey: PreferenceKey {
    static var defaultValue: CGFloat = 0
    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
        value = max(value, nextValue())
    }
}

/// "There are more kids down there." A white capsule with a teal hairline —
/// the same chip shape the reward chips use — so it belongs to the system
/// rather than introducing a new surface.
private struct MoreBelowChevron: View {
    var body: some View {
        Image(systemName: "chevron.down")
            .font(.headline)
            .foregroundStyle(Palette.teal)
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
            .background(.white, in: Capsule())
            .overlay(Capsule().stroke(Palette.teal, lineWidth: Border.hairline))
            .accessibilityLabel("More kids below")
            // Purely a signpost — it must never swallow a scroll or a tap on
            // whatever is behind it.
            .allowsHitTesting(false)
    }
}

/// One avatar tile: the round badge with the name underneath. The name keeps
/// its own line height and may take two lines, shrinking to fit only if two
/// lines still aren't enough — so a long name is always shown in full rather
/// than truncated, at every Dynamic Type size.
private struct AvatarTile<Badge: View>: View {
    let name: String
    let tint: Color
    var bold = true
    @ViewBuilder let badge: Badge

    var body: some View {
        VStack(spacing: 10) {
            badge
            Text(name)
                .font(bold ? .title3.weight(.bold) : .title3)
                .foregroundStyle(tint)
                .multilineTextAlignment(.center)
                .lineLimit(2)
                .minimumScaleFactor(0.6)
                .fixedSize(horizontal: false, vertical: true)
        }
    }
}

#Preview {
    WhosLearningView().environmentObject(AppState.preview())
}
