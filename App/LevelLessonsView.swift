//
//  LevelLessonsView.swift
//  The per-level lesson list: what a child sees after tapping a level on the
//  map. A level holds about five lessons plus its friendly check, so tapping a
//  level can't just launch one lesson and hide the rest.
//
//  It answers three questions a six-year-old actually asks:
//    "Where was I?"      — one big Continue button on the next unfinished step.
//    "What have I done?"  — stars on finished rows, never a cross on the others.
//    "What's next?"       — the level check sits last, and says what it is.
//
//  Nothing here can be failed and nothing is hidden: every lesson is tappable
//  in any order, and only the level check waits, because it needs the level's
//  questions to exist before it can mix them. A waiting row explains itself
//  ("Play the lessons first") rather than showing a lock and no reason.
//
//  Visuals are the Penny Design System tokens in Theme.swift — the same white
//  rows, radii and borders as the map, so this reads as one app.
//

import SwiftUI

struct LevelLessonsView: View {
    @EnvironmentObject private var app: AppState

    var body: some View {
        if let kid = app.selectedKid, let level = app.activeLevel {
            content(for: kid, level: level)
        } else {
            Color.clear.onAppear { app.route = .lessonMap }
        }
    }

    private func content(for kid: Kid, level: LevelSpec) -> some View {
        let steps = app.library.lessonsAndCheck(inLevel: level.id)
        let next = app.nextLesson(inLevel: level.id)

        return VStack(spacing: 0) {
            header(level, kid: kid)

            ScrollView {
                VStack(spacing: 12) {
                    ForEach(Array(steps.enumerated()), id: \.element.id) { index, lesson in
                        LessonRow(number: index + 1,
                                  lesson: lesson,
                                  stars: kid.starsByLesson[lesson.id],
                                  isNext: lesson.id == next?.id,
                                  isWaiting: !app.library.isPlayable(lesson, starsByLesson: kid.starsByLesson)) {
                            app.startLesson(id: lesson.id)
                        }
                    }
                }
                .padding(.horizontal, 20)
                // The content area sits a little lower on screen rather than
                // centred, which is the standing layout preference.
                .padding(.top, 18)
                .padding(.bottom, 20)
            }

            footer(next: next, kid: kid)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .kidPageBackground()
    }

    // MARK: Header

    /// The level's own picture, name and kid summary, plus how far along we are.
    private func header(_ level: LevelSpec, kid: Kid) -> some View {
        let progress = app.library.stepsFinished(inLevel: level.id,
                                                 starsByLesson: kid.starsByLesson)
        return VStack(spacing: 12) {
            HStack {
                Button {
                    app.route = .lessonMap
                } label: {
                    Image(systemName: "chevron.left.circle.fill")
                        .font(.title)
                        .foregroundStyle(Palette.teal)
                }
                .accessibilityLabel("Back to the map")
                Spacer()
                RewardChip(icon: "star", value: "\(kid.totalStars)", tint: Palette.star)
                RewardChip(icon: "coin", value: "\(kid.coins)", tint: Palette.copper)
            }

            FluentIcon(name: level.icon, size: 56)

            Text(level.title)
                .font(.screenTitle)
                .foregroundStyle(Palette.textHeading)
                .multilineTextAlignment(.center)

            Text(level.kidSummary)
                .font(.rowSub)
                .foregroundStyle(Palette.textSoft)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)

            Text("\(progress.done) of \(progress.total) done")
                .font(.caption.weight(.heavy))
                .tracking(1)
                .foregroundStyle(Palette.teal.opacity(0.8))
                .accessibilityLabel("\(progress.done) of \(progress.total) finished")
        }
        .padding(.horizontal, 20)
        .padding(.top, 12)
        .padding(.bottom, 16)
        .background(Palette.surfaceBand)
    }

    // MARK: Footer

    /// One button: carry on where we left off. It says which step that is, so a
    /// child isn't guessing what Continue will open.
    @ViewBuilder
    private func footer(next: Lesson?, kid: Kid) -> some View {
        if let next {
            let started = kid.starsByLesson[next.id] != nil
            Button(started ? "Play again" : "Continue") {
                app.startLesson(id: next.id)
            }
            .buttonStyle(BigButtonStyle(fill: Palette.teal))
            .padding(.horizontal, 24)
            .padding(.bottom, 24)
            .accessibilityHint("Opens \(next.title).")
        }
    }
}

// MARK: - One row

/// A lesson (or the level check) in the list: its number, its name, and either
/// the stars it earned or what it is. Never a cross and never a red mark — an
/// unplayed lesson simply has no stars yet.
struct LessonRow: View {
    let number: Int
    let lesson: Lesson
    /// Best stars earned, or nil if this one hasn't been finished yet.
    let stars: Int?
    /// The step the Continue button would open.
    let isNext: Bool
    /// The level check, before the level's lessons are all finished.
    let isWaiting: Bool
    let action: () -> Void

    private var isFinished: Bool { stars != nil }

    var body: some View {
        Button(action: action) {
            HStack(spacing: 14) {
                badge

                VStack(alignment: .leading, spacing: 4) {
                    Text(lesson.title)
                        .font(.rowTitle)
                        .foregroundStyle(Palette.textBody)
                        .multilineTextAlignment(.leading)
                        .fixedSize(horizontal: false, vertical: true)

                    if let stars {
                        StarRow(earned: stars, size: 16)
                    } else if isWaiting {
                        Text("Play the lessons first")
                            .font(.caption)
                            .foregroundStyle(Palette.textFaint)
                    } else if lesson.isLevelCheck {
                        Text("A few questions again. You can't get it wrong.")
                            .font(.caption)
                            .foregroundStyle(Palette.textSoft)
                            .fixedSize(horizontal: false, vertical: true)
                    } else if isNext {
                        Text("Tap to play ▶")
                            .font(.subheadline.weight(.bold))
                            .foregroundStyle(Palette.teal)
                    } else {
                        Text("\(lesson.estimatedMinutes) minutes")
                            .font(.caption)
                            .foregroundStyle(Palette.textFaint)
                    }
                }

                Spacer(minLength: 0)
            }
            .padding(14)
            .background(.white, in: RoundedRectangle(cornerRadius: Radius.bubble, style: .continuous))
            .overlay(
                // The same 2px teal border the map uses for "you are here".
                RoundedRectangle(cornerRadius: Radius.bubble, style: .continuous)
                    .stroke(isNext ? Palette.teal : .clear, lineWidth: Border.bubble)
            )
            .opacity(isWaiting ? 0.6 : 1)
        }
        .buttonStyle(PressableStyle())
        .disabled(isWaiting)
        .accessibilityLabel(accessibilityLabel)
        .accessibilityHint(accessibilityHint)
    }

    /// The level check gets a trophy; a finished lesson a check mark; anything
    /// else its number, so the list reads as a path.
    private var badge: some View {
        ZStack {
            Circle()
                .fill(circleColor)
                .frame(width: 52, height: 52)
                .overlay(Circle().stroke(isNext ? Palette.teal.opacity(0.35) : .clear,
                                         lineWidth: Border.levelRing))
            if lesson.isLevelCheck {
                FluentIcon(name: "trophy", size: 28)
            } else if isFinished {
                FluentIcon(name: "check-mark", size: 26)
            } else {
                Text("\(number)")
                    .font(.sectionTitle)
                    .foregroundStyle(.white)
            }
        }
    }

    private var circleColor: Color {
        if isWaiting { return Palette.lockGrey }
        if isFinished { return Palette.copper }
        return isNext ? Palette.teal : Palette.skyTeal
    }

    private var accessibilityLabel: String {
        let kind = lesson.isLevelCheck ? "Level check" : "Lesson \(number)"
        return "\(kind), \(lesson.title)"
    }

    private var accessibilityHint: String {
        if isWaiting { return "Finish the lessons in this level first." }
        if let stars { return "Finished, \(stars) of 3 stars. Tap to play it again." }
        if lesson.isLevelCheck { return "A few questions from this level. Tap to play." }
        return "Tap to play."
    }
}

#if DEBUG
#Preview {
    let app = AppState.preview()
    app.openLevel(2)
    return LevelLessonsView().environmentObject(app)
}
#endif
