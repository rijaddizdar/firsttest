//
//  LessonMapView.swift
//  Screen 3: the kid's level map — the 13-level path in 4 worlds, with
//  locked / current / completed states, stars, coins and a streak.
//  Streak icon is a COIN, not a flame (README section 2).
//

import SwiftUI

struct LessonMapView: View {
    @EnvironmentObject private var app: AppState

    var body: some View {
        // The map needs a selected kid; fall back to the picker if somehow not.
        if let kid = app.selectedKid {
            content(for: kid)
        } else {
            Color.clear.onAppear { app.route = .whosLearning }
        }
    }

    private func content(for kid: Kid) -> some View {
        VStack(spacing: 0) {
            header(for: kid)
            ScrollView {
                VStack(spacing: 28) {
                    ForEach(SampleData.worlds, id: \.self) { world in
                        worldSection(world, kid: kid)
                    }
                }
                .padding(.vertical, 20)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .kidPageBackground()
    }

    // MARK: Header — greeting + rewards

    private func header(for kid: Kid) -> some View {
        VStack(spacing: 12) {
            HStack {
                Button {
                    app.route = .whosLearning
                } label: {
                    Image(systemName: "chevron.left.circle.fill")
                        .font(.title)
                        .foregroundStyle(Palette.teal)
                }
                Spacer()
                AvatarBadge(kind: kid.avatarKind, color: kid.avatarColor, size: 44)
                Text(kid.name).font(.headline).foregroundStyle(Palette.ink)
            }

            HStack(spacing: 10) {
                RewardChip(icon: "star", value: "\(kid.totalStars)", tint: Palette.star)
                RewardChip(icon: "coin", value: "\(kid.coins)", tint: Palette.copper)
                // Streak uses a coin, never a flame (Penny Design System).
                RewardChip(icon: "coin", value: "\(kid.currentStreak)-day", tint: Palette.teal)
            }
        }
        .padding(.horizontal, 20)
        .padding(.top, 12)
        .padding(.bottom, 14)
        .background(Palette.peach.opacity(0.5))
    }

    // MARK: World section

    private func worldSection(_ world: String, kid: Kid) -> some View {
        VStack(spacing: 16) {
            Text(world.uppercased())
                .font(.caption.weight(.heavy))
                .tracking(1.5)
                .foregroundStyle(Palette.teal.opacity(0.8))

            ForEach(SampleData.levels(in: world)) { level in
                LevelNode(level: level,
                          state: kid.lockState(for: level.id),
                          stars: kid.starsByLevel[level.id] ?? 0) {
                    tap(level, kid: kid)
                }
            }
        }
    }

    private func tap(_ level: MoneyLevel, kid: Kid) {
        let state = kid.lockState(for: level.id)
        guard state != .locked else { return }        // locked levels don't open
        guard level.isPlayable else { return }        // only Needs & Wants plays
        app.route = .lesson
    }
}

/// One level "bubble" on the path.
struct LevelNode: View {
    let level: MoneyLevel
    let state: LevelLockState
    let stars: Int
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 16) {
                ZStack {
                    Circle().fill(bubbleColor)
                        .frame(width: 66, height: 66)
                        // 4px translucent teal ring around the current level bubble.
                        .overlay(Circle().stroke(ringColor, lineWidth: Border.levelRing))
                    FluentIcon(name: state == .locked ? "locked" : level.iconName, size: 34)
                }

                VStack(alignment: .leading, spacing: 4) {
                    HStack(spacing: 8) {
                        Text("\(level.id).").font(.rowTitle).foregroundStyle(Palette.textFaint)
                        Text(level.title).font(.rowTitle).foregroundStyle(Palette.textBody)
                    }
                    Text(level.kidSummary)
                        .font(.rowSub)
                        .foregroundStyle(Palette.textSoft)
                        .fixedSize(horizontal: false, vertical: true)

                    if state == .completed {
                        StarRow(earned: stars, size: 16)
                    } else if state == .current && level.isPlayable {
                        Text("Tap to play ▶").font(.subheadline.weight(.bold)).foregroundStyle(Palette.teal)
                    } else if state == .current {
                        Text("Coming soon").font(.caption).foregroundStyle(Palette.textFaint)
                    }
                }
                Spacer(minLength: 0)
            }
            .padding(14)
            .background(.white, in: RoundedRectangle(cornerRadius: Radius.bubble, style: .continuous))
            .overlay(
                // 2px teal border marks the current level row.
                RoundedRectangle(cornerRadius: Radius.bubble, style: .continuous)
                    .stroke(state == .current ? Palette.teal : .clear, lineWidth: Border.bubble)
            )
            .opacity(state == .locked ? 0.6 : 1)
            .padding(.horizontal, 20)
        }
        .buttonStyle(PressableStyle())
        .disabled(state == .locked)
        .accessibilityHint(accessibilityHint)
    }

    private var bubbleColor: Color {
        switch state {
        case .completed: return Palette.copper
        case .current:   return level.isPlayable ? Palette.teal : Palette.skyTeal
        case .locked:    return Palette.lockGrey
        }
    }

    private var ringColor: Color {
        state == .current ? Palette.teal.opacity(0.35) : .clear
    }

    private var accessibilityHint: String {
        switch state {
        case .locked:    return "Locked. Finish earlier levels first."
        case .current:   return level.isPlayable ? "Current level. Tap to play." : "Current level. Coming soon."
        case .completed: return "Finished, \(stars) of 3 stars."
        }
    }
}

#Preview {
    LessonMapView().environmentObject(AppState())
}
