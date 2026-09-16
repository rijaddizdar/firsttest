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
                VStack(spacing: Metric.xl) {
                    ForEach(SampleData.worlds, id: \.self) { world in
                        worldSection(world, kid: kid)
                    }
                }
                .padding(.vertical, Metric.lg)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .kidPageBackground()
    }

    // MARK: Header — greeting + rewards

    private func header(for kid: Kid) -> some View {
        VStack(spacing: Metric.md) {
            HStack {
                Button {
                    Haptics.selection()
                    app.route = .whosLearning
                } label: {
                    Image(systemName: "chevron.left.circle.fill")
                        .font(.title)
                        .foregroundStyle(Palette.teal)
                }
                Spacer()
                AvatarBadge(kind: kid.avatarKind, color: kid.avatarColor, size: 46)
                Text(kid.name).font(.kidHeadline).foregroundStyle(Palette.ink)
            }

            HStack(spacing: Metric.sm) {
                RewardChip(symbol: "star.fill", value: "\(kid.totalStars)", tint: Palette.gold)
                RewardChip(symbol: "dollarsign.circle.fill", value: "\(kid.coins)", tint: Palette.copper)
                // Streak uses a coin, never a flame (README section 2).
                RewardChip(symbol: "circle.hexagongrid.fill", value: "\(kid.currentStreak)-day", tint: Palette.teal)
            }
        }
        .padding(.horizontal, Metric.lg)
        .padding(.top, Metric.md)
        .padding(.bottom, Metric.md)
        .background(
            LinearGradient(colors: [Palette.peach.opacity(0.7), Palette.peach.opacity(0.0)],
                           startPoint: .top, endPoint: .bottom)
                .ignoresSafeArea(edges: .top)
        )
    }

    // MARK: World section

    private func worldSection(_ world: String, kid: Kid) -> some View {
        let tint = Palette.worldTint(world)
        return VStack(spacing: Metric.md) {
            // A soft tinted banner marks each "world" of the path.
            HStack(spacing: 8) {
                Circle().fill(tint.0).frame(width: 10, height: 10)
                Text(world.uppercased())
                    .font(.kidCaption)
                    .tracking(1.5)
                    .foregroundStyle(tint.0)
            }
            .padding(.horizontal, 16).padding(.vertical, 7)
            .background(Capsule().fill(tint.0.opacity(0.12)))

            ForEach(SampleData.levels(in: world)) { level in
                LevelNode(level: level,
                          tint: tint,
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
    var tint: (Color, Color) = (Palette.teal, Palette.skyTeal)
    let state: LevelLockState
    let stars: Int
    let action: () -> Void

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var pulse = false

    var body: some View {
        Button(action: action) {
            HStack(spacing: Metric.md) {
                bubble

                VStack(alignment: .leading, spacing: 5) {
                    HStack(spacing: 8) {
                        Text("\(level.id).").font(.kidHeadline).foregroundStyle(Palette.ink.opacity(0.4))
                        Text(level.title).font(.kidHeadline).foregroundStyle(Palette.ink)
                    }
                    Text(level.kidSummary)
                        .font(.kidCallout)
                        .foregroundStyle(Palette.ink.opacity(0.6))
                        .fixedSize(horizontal: false, vertical: true)

                    if state == .completed {
                        StarRow(earned: stars, size: 16)
                    } else if state == .current && level.isPlayable {
                        Label("Tap to play", systemImage: "play.fill")
                            .font(.kidCaption).foregroundStyle(tint.0)
                    } else if state == .current {
                        Text("Coming soon").font(.kidFootnote).foregroundStyle(Palette.ink.opacity(0.45))
                    }
                }
                Spacer(minLength: 0)
                if state == .completed {
                    Image(systemName: "checkmark.seal.fill")
                        .font(.title3).foregroundStyle(tint.0.opacity(0.85))
                }
            }
            .padding(Metric.md)
            .cardSurface(radius: 22, strong: state == .current)
            .overlay(
                RoundedRectangle(cornerRadius: 22, style: .continuous)
                    .stroke(state == .current ? tint.0 : .clear, lineWidth: 2.5)
            )
            .opacity(state == .locked ? 0.65 : 1)
            .scaleEffect(state == .current && pulse && !reduceMotion ? 1.015 : 1)
            .padding(.horizontal, Metric.lg)
        }
        .buttonStyle(PressableCard())
        .disabled(state == .locked)
        .accessibilityHint(accessibilityHint)
        .onAppear {
            guard state == .current, level.isPlayable, !reduceMotion else { return }
            withAnimation(.easeInOut(duration: 1.3).repeatForever(autoreverses: true)) { pulse = true }
        }
    }

    private var bubble: some View {
        ZStack {
            Circle()
                .fill(
                    state == .locked
                    ? AnyShapeStyle(Palette.lockGrey)
                    : AnyShapeStyle(LinearGradient(colors: [tint.0.lighter(0.12), tint.0, tint.0.darker(0.1)],
                                                   startPoint: .top, endPoint: .bottom))
                )
                .frame(width: 68, height: 68)
                .overlay(
                    Ellipse().fill(.white.opacity(0.3))
                        .frame(width: 34, height: 18).blur(radius: 3).offset(y: -16)
                )
                .overlay(Circle().stroke(.white.opacity(0.7), lineWidth: 2))
            Image(systemName: state == .locked ? "lock.fill" : level.symbolName)
                .font(.system(size: 27, weight: .medium))
                .foregroundStyle(state == .locked ? Palette.ink.opacity(0.4) : .white)
        }
        .softShadow()
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
