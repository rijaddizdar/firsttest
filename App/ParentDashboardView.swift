//
//  ParentDashboardView.swift
//  Screen 5: the code-locked parent area.
//    5a. ParentGateView — enter the 6-digit code; wrong codes -> short lockout.
//    5b. ParentDashboardView — per-kid progress, time, streak, and settings.
//
//  A child cannot reach the dashboard without the code (README section 6).
//

import SwiftUI
import Combine

// MARK: - 5a. Parent code gate

struct ParentGateView: View {
    @EnvironmentObject private var app: AppState
    @State private var entry = ""
    @State private var shake = false
    @State private var showError = false
    // Drives the live lockout countdown label.
    @State private var now = Date()
    private let ticker = Timer.publish(every: 1, on: .main, in: .common).autoconnect()

    private let codeLength = 6

    var body: some View {
        VStack(spacing: 24) {
            HStack {
                Button { app.route = .whosLearning } label: {
                    Image(systemName: "chevron.left.circle.fill")
                        .font(.title).foregroundStyle(Palette.teal)
                }
                Spacer()
            }
            .padding(.horizontal, 20).padding(.top, 12)

            Spacer()
            ZStack {
                Circle().fill(Palette.teal.opacity(0.12)).frame(width: 92, height: 92)
                Image(systemName: "lock.fill").font(.system(size: 44)).foregroundStyle(Palette.teal)
            }
            Text("Enter parent code")
                .font(.kidTitle).foregroundStyle(Palette.teal)

            // Six dots showing entry progress.
            HStack(spacing: 16) {
                ForEach(0..<codeLength, id: \.self) { i in
                    Circle()
                        .fill(i < entry.count
                              ? AnyShapeStyle(LinearGradient(colors: [Palette.skyTeal, Palette.teal],
                                                             startPoint: .top, endPoint: .bottom))
                              : AnyShapeStyle(Palette.lockGrey.opacity(0.35)))
                        .frame(width: 18, height: 18)
                        .scaleEffect(i < entry.count ? 1.1 : 1)
                        .animation(.spring(response: 0.25, dampingFraction: 0.5), value: entry.count)
                }
            }
            .rotationEffect(.degrees(shake ? 1.5 : 0))
            .animation(.easeInOut(duration: 0.08).repeatCount(4, autoreverses: true), value: shake)

            if app.isLockedOut {
                Text("Too many tries. Try again in \(max(0, Int(app.lockoutUntil!.timeIntervalSince(now).rounded(.up)))) seconds.")
                    .font(.kidCaption).foregroundStyle(Palette.copper)
                    .multilineTextAlignment(.center).padding(.horizontal, Metric.xl)
            } else if showError {
                Text("That code isn't right. Try again.")
                    .font(.kidCaption).foregroundStyle(Palette.copper)
            } else {
                Text("Demo code: 1234 (padded to 6 not required in mock)")
                    .font(.kidFootnote).foregroundStyle(Palette.ink.opacity(0.4))
            }

            // Number pad.
            keypad
                .disabled(app.isLockedOut)
                .opacity(app.isLockedOut ? 0.4 : 1)

            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .kidPageBackground()
        .onReceive(ticker) { now = $0 }
    }

    private var keypad: some View {
        let keys = ["1","2","3","4","5","6","7","8","9","","0","⌫"]
        return LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 18), count: 3), spacing: 18) {
            ForEach(keys, id: \.self) { key in
                if key.isEmpty {
                    Color.clear.frame(height: 66)
                } else {
                    Button { tap(key) } label: {
                        Text(key)
                            .font(.system(.title, design: .rounded).weight(.semibold))
                            .frame(maxWidth: .infinity, minHeight: 66)
                            .background(
                                RoundedRectangle(cornerRadius: 20, style: .continuous).fill(.white)
                            )
                            .foregroundStyle(Palette.ink)
                            .softShadow()
                    }
                    .buttonStyle(PressableCard())
                }
            }
        }
        .padding(.horizontal, 40)
    }

    private func tap(_ key: String) {
        Haptics.selection()
        showError = false
        if key == "⌫" {
            if !entry.isEmpty { entry.removeLast() }
            return
        }
        // Allow submit at the demo length OR full length. The seeded demo code
        // is "1234"; a real code is always 6 digits.
        guard entry.count < codeLength else { return }
        entry.append(key)
        // Try when we reach the stored code's length.
        if let code = app.parentCode, entry.count == code.count {
            submit()
        }
    }

    private func submit() {
        if app.submitParentCode(entry) {
            entry = ""
            app.route = .parentDashboard
        } else {
            entry = ""
            shake = true
            showError = true
        }
    }
}

// MARK: - 5b. Parent dashboard

struct ParentDashboardView: View {
    @EnvironmentObject private var app: AppState

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 22) {
                header

                // Per-kid progress cards.
                ForEach(app.kids) { kid in
                    KidProgressCard(kid: kid)
                }

                settingsSection
                dataSection
                footer
            }
            .padding(Metric.lg)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .kidPageBackground()
    }

    private var header: some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text("Parent dashboard").font(.kidTitle).foregroundStyle(Palette.teal)
                Text("Only you can see this.").font(.kidCaption).foregroundStyle(Palette.ink.opacity(0.6))
            }
            Spacer()
            Button("Done") {
                Haptics.selection()
                app.route = .whosLearning
            }
                .font(.kidHeadline).foregroundStyle(Palette.teal)
                .padding(.horizontal, 16).padding(.vertical, 8)
                .background(Capsule().fill(Palette.teal.opacity(0.12)))
        }
    }

    private var settingsSection: some View {
        DashCard(title: "Settings", icon: "gearshape.fill") {
            // Daily time limit per kid (README section 6).
            Stepper(value: $app.settings.dailyLimitMinutes, in: 5...120, step: 5) {
                HStack {
                    Text("Daily time limit")
                    Spacer()
                    Text("\(app.settings.dailyLimitMinutes) min")
                        .foregroundStyle(Palette.teal).font(.headline)
                }
            }
            Divider()
            Button {
                // Reset the code: send the grown-up back to create a new one.
                app.parentCode = nil
                app.route = .createParentCode
            } label: {
                Label("Reset parent code", systemImage: "arrow.clockwise")
                    .foregroundStyle(Palette.copper)
            }
        }
    }

    private var dataSection: some View {
        DashCard(title: "Data & privacy", icon: "hand.raised.fill") {
            // These are stubs in the mock — the real app deletes on the backend
            // and honours COPPA (README section 9).
            Text("Delete a child's data, or the whole account, at any time.")
                .font(.footnote).foregroundStyle(Palette.ink.opacity(0.6))
            Text("No ads, no third-party analytics, no tracking. Only the data in README section 9 is kept.")
                .font(.caption).foregroundStyle(Palette.ink.opacity(0.5))
        }
    }

    private var footer: some View {
        Text("Mock-up only — no real accounts, network or storage.")
            .font(.caption2).foregroundStyle(Palette.ink.opacity(0.4))
            .frame(maxWidth: .infinity, alignment: .center)
    }
}

/// One child's progress summary card.
private struct KidProgressCard: View {
    let kid: Kid

    var body: some View {
        DashCard(title: kid.name, icon: nil, leading: {
            AnyView(AvatarBadge(kind: kid.avatarKind, color: kid.avatarColor, size: 40))
        }) {
            HStack(spacing: 10) {
                stat("Stars", "\(kid.totalStars)", "star.fill", .yellow)
                stat("Coins", "\(kid.coins)", "dollarsign.circle.fill", Palette.copper)
                stat("Streak", "\(kid.currentStreak)d", "circle.hexagongrid.fill", Palette.teal)
                stat("Best", "\(kid.bestStreak)d", "trophy.fill", Palette.teal)
            }
            Divider()
            HStack {
                Label("\(kid.minutesToday) min today", systemImage: "clock.fill")
                Spacer()
                Label("\(kid.minutesThisWeek) min this week", systemImage: "calendar")
            }
            .font(.footnote).foregroundStyle(Palette.ink.opacity(0.6))

            Divider()
            // Per-level progress list (README section 6 "Progress per level").
            ForEach(SampleData.levels.prefix(kid.unlockedThrough), id: \.id) { level in
                HStack {
                    Text("\(level.id). \(level.title)").font(.subheadline)
                    Spacer()
                    if let stars = kid.starsByLevel[level.id] {
                        StarRow(earned: stars, size: 13)
                    } else if level.id == kid.unlockedThrough {
                        Text("In progress").font(.caption).foregroundStyle(Palette.teal)
                    }
                }
            }
        }
    }

    private func stat(_ label: String, _ value: String, _ symbol: String, _ tint: Color) -> some View {
        VStack(spacing: 5) {
            Image(systemName: symbol).font(.callout.weight(.bold)).foregroundStyle(tint)
            Text(value).font(.kidHeadline).foregroundStyle(Palette.ink)
            Text(label).font(.kidFootnote).foregroundStyle(Palette.ink.opacity(0.5))
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 10)
        .background(RoundedRectangle(cornerRadius: 16, style: .continuous).fill(tint.opacity(0.08)))
    }
}

/// A rounded card used throughout the dashboard.
private struct DashCard<Content: View>: View {
    let title: String
    let icon: String?
    var leading: (() -> AnyView)? = nil
    @ViewBuilder let content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: Metric.md) {
            HStack(spacing: Metric.sm) {
                if let leading { leading() }
                if let icon {
                    Image(systemName: icon).foregroundStyle(Palette.teal)
                        .font(.headline)
                }
                Text(title).font(.kidHeadline).foregroundStyle(Palette.ink)
            }
            content
        }
        .padding(Metric.lg)
        .frame(maxWidth: .infinity, alignment: .leading)
        .cardSurface()
    }
}

#Preview("Gate") { ParentGateView().environmentObject(AppState()) }
#Preview("Dashboard") { ParentDashboardView().environmentObject(AppState()) }
