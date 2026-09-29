//
//  LessonMapView.swift
//  Screen 3: the kid's level map — the level path in its worlds, with
//  locked / current / completed states, stars, coins and a streak.
//  Streak icon is a COIN, not a flame (README section 2).
//
//  The worlds and levels come from App/Content/curriculum.json, and the states
//  and stars come from this child's SAVED progress, so what a kid sees here is
//  what the store holds. A level whose lessons aren't written yet shows "Coming
//  soon" and never blocks the levels after it.
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
                    if app.hasReachedDailyLimit(kid) {
                        timeIsUp(for: kid)
                    }
                    ForEach(app.library.worlds) { world in
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
                // The child's own face, and the way back into "Make it yours!"
                // — README section 6: they can change their look at any time.
                Button {
                    app.route = .editAvatar
                } label: {
                    HStack(spacing: 8) {
                        AvatarBadge(avatar: kid.avatar, size: 44)
                            .overlay(alignment: .bottomTrailing) {
                                ZStack {
                                    Circle().fill(.white)
                                    Circle().stroke(Palette.teal, lineWidth: Border.hairline)
                                    FluentIcon(name: "sparkles", size: 11)
                                }
                                .frame(width: 18, height: 18)
                                .offset(x: 2, y: 2)
                            }
                        Text(kid.name).font(.headline).foregroundStyle(Palette.ink)
                    }
                }
                .buttonStyle(PressableStyle())
                .accessibilityLabel(kid.name)
                .accessibilityHint("Change how you look")
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

    // MARK: Time's up for today

    /// The grown-up's daily time limit, said the way Penny says it: a kind
    /// wrap-up and nothing else. No countdown, no "hurry", no guilt, and never a
    /// lock icon over the levels (README sections 6 and 7).
    private func timeIsUp(for kid: Kid) -> some View {
        VStack(spacing: 14) {
            PennyView(mood: .wave, size: 110)
            SpeechBubble(text: app.dailyLimitMessage(for: kid))
            Text("Come back tomorrow for more.")
                .font(.rowSub).foregroundStyle(Palette.textSoft)
        }
        .padding(.horizontal, 20)
        .accessibilityElement(children: .combine)
    }

    // MARK: World section

    private func worldSection(_ world: WorldSpec, kid: Kid) -> some View {
        VStack(spacing: 16) {
            Text(world.title.uppercased())
                .font(.caption.weight(.heavy))
                .tracking(1.5)
                .foregroundStyle(Palette.teal.opacity(0.8))

            ForEach(world.levels) { level in
                LevelNode(level: level,
                          state: kid.lockState(for: level.id),
                          stars: kid.starsByLevel[level.id] ?? 0,
                          progress: app.library.stepsFinished(inLevel: level.id,
                                                              starsByLesson: kid.starsByLesson),
                          timeIsUp: app.hasReachedDailyLimit(kid)) {
                    // A level holds about five lessons plus its check, so it
                    // opens a lesson list rather than launching one lesson.
                    app.openLevel(level.id)
                }
            }
        }
    }
}

/// One level "bubble" on the path.
struct LevelNode: View {
    let level: LevelSpec
    let state: LevelLockState
    let stars: Int
    /// How many of the level's steps (its lessons plus the check) are done, so
    /// a part-finished level says "2 of 6 done" instead of looking untouched.
    var progress: (done: Int, total: Int) = (0, 0)
    /// The grown-up's daily time limit is used up for today. The level still
    /// looks exactly as it did — it just waits until tomorrow.
    var timeIsUp = false
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 16) {
                ZStack {
                    Circle().fill(bubbleColor)
                        .frame(width: 66, height: 66)
                        // 4px translucent teal ring around the current level bubble.
                        .overlay(Circle().stroke(ringColor, lineWidth: Border.levelRing))
                    FluentIcon(name: state == .locked ? "locked" : level.icon, size: 34)
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
                    } else if level.hasLessons && progress.done > 0 {
                        Text("\(progress.done) of \(progress.total) done")
                            .font(.subheadline.weight(.bold)).foregroundStyle(Palette.teal)
                    } else if state == .current && level.hasLessons {
                        Text(timeIsUp ? "More tomorrow" : "Tap to play ▶")
                            .font(.subheadline.weight(.bold))
                            .foregroundStyle(timeIsUp ? Palette.textSoft : Palette.teal)
                    } else if state == .current || state == .open {
                        // Unlocked, but this level's lessons aren't written yet.
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
        .disabled(state == .locked || timeIsUp)
        .accessibilityHint(accessibilityHint)
    }

    private var bubbleColor: Color {
        switch state {
        case .completed: return Palette.copper
        case .current:   return level.hasLessons ? Palette.teal : Palette.skyTeal
        case .open:      return Palette.skyTeal
        case .locked:    return Palette.lockGrey
        }
    }

    private var ringColor: Color {
        state == .current ? Palette.teal.opacity(0.35) : .clear
    }

    private var accessibilityHint: String {
        if timeIsUp, state != .locked { return "That's all for today. More tomorrow." }
        switch state {
        case .locked:    return "Locked. Finish earlier levels first."
        case .current:
            guard level.hasLessons else { return "Current level. Coming soon." }
            return progress.done > 0
                ? "Current level, \(progress.done) of \(progress.total) finished. Tap to see its lessons."
                : "Current level. Tap to see its lessons."
        case .open:
            return level.hasLessons ? "Unlocked. Tap to see its lessons." : "Unlocked. Coming soon."
        case .completed: return "Finished, \(stars) of 3 stars."
        }
    }
}


#if DEBUG
#Preview {
    LessonMapView().environmentObject(AppState.preview())
}
#endif
