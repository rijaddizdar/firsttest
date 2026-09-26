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
            FluentIcon(name: "locked", size: 64)
            Text("Enter parent code")
                .font(.screenTitle).foregroundStyle(Palette.textHeading)

            // Six dots showing entry progress.
            HStack(spacing: 14) {
                ForEach(0..<codeLength, id: \.self) { i in
                    Circle()
                        .fill(i < entry.count ? Palette.teal : Palette.lockGrey.opacity(0.4))
                        .frame(width: 18, height: 18)
                }
            }
            .rotationEffect(.degrees(shake ? 1.5 : 0))
            .animation(.easeInOut(duration: 0.08).repeatCount(4, autoreverses: true), value: shake)

            if app.isLockedOut {
                Text("Too many tries. Try again in \(max(0, Int(app.lockoutUntil!.timeIntervalSince(now).rounded(.up)))) seconds.")
                    .font(.subheadline).foregroundStyle(Palette.copper)
                    .multilineTextAlignment(.center).padding(.horizontal, 30)
            } else if showError {
                Text("That code isn't right. Try again.")
                    .font(.subheadline).foregroundStyle(Palette.copper)
            } else {
                Text("Demo code: 1234 (padded to 6 not required in mock)")
                    .font(.caption).foregroundStyle(Palette.ink.opacity(0.4))
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
                    Color.clear.frame(height: 64)
                } else {
                    Button { tap(key) } label: {
                        Text(key)
                            .font(.title.weight(.semibold))
                            .frame(maxWidth: .infinity, minHeight: 64)
                            .background(.white, in: RoundedRectangle(cornerRadius: Radius.key))
                            .foregroundStyle(Palette.textBody)
                    }
                    .buttonStyle(PressableStyle())
                }
            }
        }
        .padding(.horizontal, 40)
    }

    private func tap(_ key: String) {
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
            .padding(20)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Palette.cream.ignoresSafeArea())
    }

    private var header: some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text("Parent dashboard").font(.screenTitle).foregroundStyle(Palette.textHeading)
                Text("Only you can see this.").font(.subheadline).foregroundStyle(Palette.textSoft)
            }
            Spacer()
            Button("Done") { app.route = .whosLearning }
                .font(.headline).foregroundStyle(Palette.teal)
        }
    }

    private var settingsSection: some View {
        DashCard(title: "Settings", icon: "gear") {
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
        DashCard(title: "Data & privacy", icon: "shield") {
            // These are stubs in the mock — the real app deletes on the backend
            // and honours COPPA (README section 9).
            Text("Delete a child's data, or the whole account, at any time.")
                .font(.footnote).foregroundStyle(Palette.textSoft)
            Text("No ads, no third-party analytics, no tracking. Only the data in README section 9 is kept.")
                .font(.caption).foregroundStyle(Palette.textFaint)
        }
    }

    private var footer: some View {
        VStack(spacing: 6) {
            // Credit for the bundled MIT-licensed Fluent Emoji 3D icon set.
            Text("Icons: Fluent Emoji 3D by Microsoft, MIT licensed. See FLUENT-EMOJI-LICENSE.txt.")
                .font(.caption2).foregroundStyle(Palette.textFaint)
                .multilineTextAlignment(.center)
            Text("Mock-up only — no real accounts, network or storage.")
                .font(.caption2).foregroundStyle(Palette.textFaint)
        }
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
                stat("Stars", "\(kid.totalStars)", "star")
                stat("Coins", "\(kid.coins)", "coin")
                // Streak icon is a coin, never a flame.
                stat("Streak", "\(kid.currentStreak)d", "coin")
                stat("Best", "\(kid.bestStreak)d", "trophy")
            }
            Divider()
            HStack {
                Label("\(kid.minutesToday) min today", systemImage: "clock.fill")
                Spacer()
                Label("\(kid.minutesThisWeek) min this week", systemImage: "calendar")
            }
            .font(.footnote).foregroundStyle(Palette.textSoft)

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

    private func stat(_ label: String, _ value: String, _ icon: String) -> some View {
        VStack(spacing: 4) {
            FluentIcon(name: icon, size: 26)
            Text(value).font(.headline).foregroundStyle(Palette.textBody)
            Text(label).font(.caption2).foregroundStyle(Palette.textFaint)
        }
        .frame(maxWidth: .infinity)
    }
}

/// A rounded card used throughout the dashboard.
private struct DashCard<Content: View>: View {
    let title: String
    let icon: String?
    var leading: (() -> AnyView)? = nil
    @ViewBuilder let content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 10) {
                if let leading { leading() }
                if let icon { FluentIcon(name: icon, size: 24) }
                Text(title).font(.sectionTitle).foregroundStyle(Palette.textBody)
            }
            content
        }
        .padding(18)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.white, in: RoundedRectangle(cornerRadius: Radius.button, style: .continuous))
    }
}

#Preview("Gate") { ParentGateView().environmentObject(AppState()) }
#Preview("Dashboard") { ParentDashboardView().environmentObject(AppState()) }
