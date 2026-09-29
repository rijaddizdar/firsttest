//
//  ParentDashboardView.swift
//  Screen 5: the code-locked parent area.
//    5a. ParentGateView — enter the parent code; wrong codes -> short lockout.
//    5b. ParentDashboardView — per-kid progress, time, streaks, settings, and
//        deleting data.
//
//  A child cannot reach the dashboard without the code (README section 6).
//
//  Everything shown here is READ FROM THE STORE, not invented: stars, play
//  coins, streaks, lessons finished and minutes per day are the same saved
//  figures the map reads. The only data that exists is what README section 9
//  allows, so there is nothing else to show.
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
                .accessibilityLabel("Back to Who's learning")
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
            .accessibilityElement(children: .ignore)
            .accessibilityLabel("\(entry.count) of \(app.parentCodeLength ?? codeLength) digits entered")

            if app.isLockedOut {
                Text("Too many tries. Try again in \(max(0, Int(app.lockoutUntil!.timeIntervalSince(now).rounded(.up)))) seconds.")
                    .font(.subheadline).foregroundStyle(Palette.copper)
                    .multilineTextAlignment(.center).padding(.horizontal, 30)
            } else if showError {
                Text("That code isn't right. Try again.")
                    .font(.subheadline).foregroundStyle(Palette.copper)
            } else {
                // Never hint at the code itself — a child reads this screen too.
                Text("This keeps the grown-up area private.")
                    .font(.caption).foregroundStyle(Palette.textFaint)
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
                    .accessibilityLabel(key == "⌫" ? "Delete last digit" : key)
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
        guard entry.count < codeLength else { return }
        entry.append(key)
        // Try when we reach the stored code's length. Only the length is known:
        // the code itself is stored as a salted hash (README section 9).
        if let digits = app.parentCodeLength, entry.count == digits {
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

    /// Which panel is open. Only one at a time, so a grown-up is never asked two
    /// questions at once.
    @State private var changingCode = false
    @State private var kidPendingDeletion: Kid?
    @State private var confirmingDeleteAll = false

    /// How many days of the kept window the day bars draw. The store keeps 90
    /// (README section 9); 14 is what reads on a phone, and the card says so.
    private let visibleDays = 14

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 22) {
                header

                if app.kids.isEmpty {
                    emptyState
                } else {
                    ForEach(app.kids) { kid in
                        KidProgressCard(kid: kid,
                                        levels: app.library.levels,
                                        library: app.library,
                                        dailyLimit: app.settings.hasDailyLimit ? app.settings.dailyLimitMinutes : nil,
                                        visibleDays: visibleDays)
                    }
                }

                settingsSection
                dataSection
                footer
            }
            .padding(20)
            // The content sits a little below the top edge rather than flush.
            .padding(.top, 16)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Palette.cream.ignoresSafeArea())
        .sheet(isPresented: $changingCode) { ChangeParentCodeSheet() }
        // Deleting is irreversible and there is no backup anywhere, so each one
        // spells out exactly what goes before it happens (README section 6).
        //
        // No `role: .destructive` on the delete buttons: that renders them red,
        // and "no red anywhere" is a hard brand rule. The warning does the work
        // colour would have done — the button says exactly what it deletes, the
        // message says it can't be undone, and `.cancel` makes Keep the bold
        // default your thumb lands on. Colour was never the only signal here
        // anyway (README section 3).
        .alert("Delete \(kidPendingDeletion?.name ?? "")'s data?",
               isPresented: Binding(get: { kidPendingDeletion != nil },
                                    set: { if !$0 { kidPendingDeletion = nil } }),
               presenting: kidPendingDeletion) { kid in
            Button("Delete \(kid.name)'s data") {
                app.deleteKid(kid.id)
                kidPendingDeletion = nil
            }
            Button("Keep", role: .cancel) { kidPendingDeletion = nil }
        } message: { kid in
            Text(deleteMessage(for: kid))
        }
        .alert("Delete everything?", isPresented: $confirmingDeleteAll) {
            Button("Delete everything") { app.deleteAllData() }
            Button("Keep", role: .cancel) { }
        } message: {
            Text("""
                 This removes every child's profile and progress, and the parent code, from this device. \
                 The app starts again from the beginning. This can't be undone.
                 """)
        }
        .onAppear(perform: applyUITestPanel)
    }

    /// Exactly what a single deletion takes, said plainly — and only mentioning
    /// siblings when there are any.
    private func deleteMessage(for kid: Kid) -> String {
        let siblings = app.kids.count > 1 ? " The other children keep theirs." : ""
        return "This removes \(kid.name)'s profile, stars, play coins, streak and time spent from this device.\(siblings) This can't be undone."
    }

    // MARK: Header

    private var header: some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text("Parent dashboard").font(.screenTitle).foregroundStyle(Palette.textHeading)
                Text("Only you can see this.").font(.subheadline).foregroundStyle(Palette.textSoft)
            }
            Spacer()
            Button("Done") { app.route = .whosLearning }
                .font(.headline).foregroundStyle(Palette.teal)
                .accessibilityLabel("Close the parent dashboard")
        }
    }

    private var emptyState: some View {
        DashCard(title: "No profiles yet", icon: "memo") {
            Text("There is nothing saved on this device. Add a child to start.")
                .font(.footnote).foregroundStyle(Palette.textSoft)
        }
    }

    // MARK: Settings (README section 6)

    private var settingsSection: some View {
        DashCard(title: "Settings", icon: "gear") {
            // Daily time limit. One value for the whole family for now: the
            // store holds a single setting (see ParentSettings).
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Daily time limit").font(.rowTitle)
                    Text("Penny wraps up kindly when the time is used up. A lesson already open always finishes.")
                        .font(.caption).foregroundStyle(Palette.textFaint)
                        .fixedSize(horizontal: false, vertical: true)
                }
                Spacer(minLength: 12)
                Picker("Daily time limit", selection: Binding(get: { app.settings.dailyLimitMinutes },
                                                             set: { app.setDailyLimit($0) })) {
                    ForEach(ParentSettings.dailyLimitChoices, id: \.self) { minutes in
                        Text(minutes == ParentSettings.noDailyLimit ? "No limit" : "\(minutes) min").tag(minutes)
                    }
                }
                .pickerStyle(.menu)
                .tint(Palette.teal)
            }

            Divider()

            // The sound switch the store already had, now with a control.
            Toggle(isOn: Binding(get: { app.settings.soundOn }, set: { app.setSoundOn($0) })) {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Sounds").font(.rowTitle)
                    Text("The happy chime and the soft boop in lessons.")
                        .font(.caption).foregroundStyle(Palette.textFaint)
                }
            }
            .tint(Palette.teal)

            Divider()

            Button { changingCode = true } label: {
                HStack {
                    Label("Change parent code", systemImage: "key.fill")
                        .foregroundStyle(Palette.teal)
                    Spacer()
                    Image(systemName: "chevron.right").font(.footnote).foregroundStyle(Palette.textFaint)
                }
            }
            .buttonStyle(PressableStyle())
            .accessibilityHint("Pick a new 6-digit code for this dashboard")
        }
    }

    // MARK: Data & privacy (README section 6 "Data", section 9)

    private var dataSection: some View {
        DashCard(title: "Data & privacy", icon: "shield") {
            Text("Everything is saved on this device only. Deleting it here deletes it for good — there is no copy anywhere else.")
                .font(.footnote).foregroundStyle(Palette.textSoft)
                .fixedSize(horizontal: false, vertical: true)

            if !app.kids.isEmpty {
                Divider()
                ForEach(app.kids) { kid in
                    HStack {
                        AvatarBadge(avatar: kid.avatar, size: 28, spokenName: kid.name)
                        Text(kid.name).font(.subheadline)
                        Spacer()
                        Button("Delete data") { kidPendingDeletion = kid }
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(Palette.copper)
                            .buttonStyle(PressableStyle())
                            .accessibilityLabel("Delete \(kid.name)'s data")
                    }
                }
            }

            Divider()

            Button { confirmingDeleteAll = true } label: {
                Label("Delete everything on this device", systemImage: "trash")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(Palette.copper)
            }
            .buttonStyle(PressableStyle())
            .accessibilityHint("Removes every profile, all progress and the parent code, and starts the app over")

            Text("No ads, no third-party analytics, no tracking. Only the data in README section 9 is kept, and time spent is kept for \(ProgressStore.usageRetentionDays) days.")
                .font(.caption).foregroundStyle(Palette.textFaint)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private var footer: some View {
        VStack(spacing: 6) {
            // Credit for the bundled MIT-licensed Fluent Emoji 3D icon set.
            Text("Icons: Fluent Emoji 3D by Microsoft, MIT licensed. See FLUENT-EMOJI-LICENSE.txt.")
                .font(.caption2).foregroundStyle(Palette.textFaint)
                .multilineTextAlignment(.center)
            // Honest about what exists: on-device saving works, accounts and
            // sync do not (README section 10).
            Text("No accounts and no network yet. Progress is saved on this device only.")
                .font(.caption2).foregroundStyle(Palette.textFaint)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity, alignment: .center)
    }

    /// Screenshots only: open a panel straight away (`UITEST_DASHBOARD`).
    private func applyUITestPanel() {
        switch app.uiTestDashboardPanel {
        case "changeCode": changingCode = true
        case "deleteKid":  kidPendingDeletion = app.kids.first
        case "deleteAll":  confirmingDeleteAll = true
        default:           break
        }
    }
}

// MARK: - One child's progress

/// Everything saved about one child: rewards, time spent per day, and how far
/// they are level by level (README section 6).
private struct KidProgressCard: View {
    let kid: Kid
    /// The levels from the bundled curriculum, for the per-level list.
    let levels: [LevelSpec]
    let library: CurriculumLibrary
    /// Today's allowance, or nil when there is no limit — drawn on the day bars.
    let dailyLimit: Int?
    let visibleDays: Int

    var body: some View {
        DashCard(title: kid.name, icon: nil, leading: {
            AnyView(AvatarBadge(avatar: kid.avatar, size: 40))
        }) {
            rewards
            Divider()
            timeSpent
            Divider()
            levelList
        }
    }

    // MARK: Rewards

    private var rewards: some View {
        HStack(spacing: 10) {
            stat("Stars", "\(kid.totalStars)", "star", spoken: "\(kid.totalStars) stars")
            stat("Coins", "\(kid.coins)", "coin", spoken: "\(kid.coins) play coins")
            // Streak icon is a coin, never a flame.
            stat("Streak", "\(kid.currentStreak)d", "coin", spoken: "Streak: \(kid.currentStreak) days")
            stat("Best", "\(kid.bestStreak)d", "trophy", spoken: "Best streak: \(kid.bestStreak) days")
        }
    }

    /// `spoken` is what VoiceOver reads instead of the compact label: "4d" is
    /// a space-saving abbreviation on screen, not something to say out loud.
    private func stat(_ label: String, _ value: String, _ icon: String, spoken: String) -> some View {
        VStack(spacing: 4) {
            FluentIcon(name: icon, size: 26)
            Text(value).font(.headline).foregroundStyle(Palette.textBody)
            Text(label).font(.caption2).foregroundStyle(Palette.textFaint)
        }
        .frame(maxWidth: .infinity)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(spoken)
    }

    // MARK: Time spent (README section 6 "Time spent")

    private var days: [DayMinutes] { kid.minutesPerDay(lastDays: visibleDays) }

    private var timeSpent: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Label("\(kid.minutesToday) min today", systemImage: "clock.fill")
                Spacer()
                Label("\(kid.minutesThisWeek) min this week", systemImage: "calendar")
            }
            .font(.footnote).foregroundStyle(Palette.textSoft)

            DayMinutesBars(days: days, limit: dailyLimit)

            Text("Minutes per day, last \(visibleDays) days. Kept for \(ProgressStore.usageRetentionDays) days, then deleted.")
                .font(.caption2).foregroundStyle(Palette.textFaint)
        }
    }

    // MARK: Levels and lessons

    /// Levels worth a row: the ones this child has reached, plus any level whose
    /// lessons are written. The rest are still locked and say so in one line.
    private var visibleLevels: [LevelSpec] {
        levels.filter { $0.id <= kid.unlockedThrough || $0.hasLessons }
    }

    private var lockedCount: Int { levels.count - visibleLevels.count }

    private var lessonsFinishedOfWritten: (done: Int, total: Int) {
        let written = levels.flatMap { library.lessons(inLevel: $0.id) }
        return (written.filter { kid.hasFinished(lessonID: $0.id) }.count, written.count)
    }

    private var levelsCompleted: Int {
        levels.filter { library.isLevelComplete($0.id, starsByLesson: kid.starsByLesson) }.count
    }

    private var levelList: some View {
        VStack(alignment: .leading, spacing: 8) {
            let lessons = lessonsFinishedOfWritten
            Text("\(lessons.done) of \(lessons.total) lessons finished · \(levelsCompleted) of \(levels.count) levels done")
                .font(.footnote.weight(.semibold)).foregroundStyle(Palette.textSoft)

            ForEach(visibleLevels, id: \.id) { level in
                levelRow(level)
            }

            if lockedCount > 0 {
                Text("\(lockedCount) more \(lockedCount == 1 ? "level" : "levels") unlock as \(kid.name) goes.")
                    .font(.caption).foregroundStyle(Palette.textFaint)
            }
        }
    }

    private func levelRow(_ level: LevelSpec) -> some View {
        let lessons = library.lessons(inLevel: level.id)
        let done = lessons.filter { kid.hasFinished(lessonID: $0.id) }.count
        let state = kid.lockState(for: level.id)

        return HStack(alignment: .firstTextBaseline) {
            Text("\(level.id). \(level.title)")
                .font(.subheadline)
                .foregroundStyle(state == .locked ? Palette.textFaint : Palette.textBody)
            Spacer(minLength: 8)
            if lessons.isEmpty {
                Text("Not written yet").font(.caption).foregroundStyle(Palette.textFaint)
            } else {
                HStack(spacing: 8) {
                    Text("\(done)/\(lessons.count)").font(.caption).foregroundStyle(Palette.textSoft)
                    if let stars = kid.starsByLevel[level.id] {
                        StarRow(earned: stars, size: 13)
                    } else if state == .current {
                        Text(done > 0 ? "In progress" : "Next up")
                            .font(.caption).foregroundStyle(Palette.teal)
                    } else if state == .locked {
                        Text("Locked").font(.caption).foregroundStyle(Palette.textFaint)
                    }
                }
            }
        }
        .accessibilityElement(children: .combine)
    }
}

// MARK: - Day bars

/// Minutes per day as a small bar row. Deliberately hand-drawn from the design
/// tokens: teal bars, today in copper, and a hairline where the daily limit sits.
private struct DayMinutesBars: View {
    let days: [DayMinutes]
    /// Today's allowance, or nil when there is no limit.
    let limit: Int?

    private let height: CGFloat = 54

    /// The tallest bar the row has to fit — the busiest day, or the limit if
    /// that is higher, so the limit line is always visible.
    private var scale: Int {
        max(days.map(\.minutes).max() ?? 0, limit ?? 0, 10)
    }

    var body: some View {
        HStack(alignment: .bottom, spacing: 4) {
            ForEach(days) { day in
                RoundedRectangle(cornerRadius: 3, style: .continuous)
                    .fill(isToday(day) ? Palette.copper : Palette.teal.opacity(day.minutes == 0 ? 0.12 : 0.55))
                    .frame(height: max(3, height * CGFloat(day.minutes) / CGFloat(scale)))
                    .frame(maxWidth: .infinity)
            }
        }
        .frame(height: height, alignment: .bottom)
        .overlay(alignment: .bottom) { limitLine }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(summary)
    }

    @ViewBuilder
    private var limitLine: some View {
        if let limit, limit > 0 {
            Rectangle()
                .fill(Palette.skyTeal)
                .frame(height: 1)
                .padding(.bottom, height * CGFloat(limit) / CGFloat(scale))
                .accessibilityHidden(true)
        }
    }

    private func isToday(_ day: DayMinutes) -> Bool {
        Calendar.current.isDateInToday(day.day)
    }

    private var summary: String {
        let total = days.reduce(0) { $0 + $1.minutes }
        let active = days.filter { $0.minutes > 0 }.count
        return "Minutes per day over the last \(days.count) days: \(total) minutes across \(active) days."
    }
}

// MARK: - Changing the parent code

/// Pick a new 6-digit code. The old one is only replaced once the new one is
/// typed twice and matches — so an abandoned change never leaves the dashboard
/// unlocked. Only the salted hash is written (README section 9).
private struct ChangeParentCodeSheet: View {
    @EnvironmentObject private var app: AppState
    @Environment(\.dismiss) private var dismiss

    @State private var code = ""
    @State private var confirm = ""
    @State private var error: String?

    private let codeLength = 6

    var body: some View {
        VStack(spacing: 20) {
            Spacer(minLength: 0)
            FluentIcon(name: "locked", size: 56)
            Text("Change parent code")
                .font(.screenTitle).foregroundStyle(Palette.textHeading)
                .multilineTextAlignment(.center)
            Text("A new 6-digit code — not a birthday. The old one stops working straight away.")
                .font(.body).multilineTextAlignment(.center)
                .foregroundStyle(Palette.textMuted)
                .padding(.horizontal, 30)

            field("New code", text: $code)
            field("Confirm new code", text: $confirm)

            if let error {
                Text(error).font(.subheadline).foregroundStyle(Palette.copper)
            }

            Spacer()

            Button("Save new code") { save() }
                .buttonStyle(BigButtonStyle(fill: Palette.teal))
                .disabled(!isComplete)
                .opacity(isComplete ? 1 : 0.5)
                .padding(.horizontal, 24)

            Button("Cancel") { dismiss() }
                .font(.headline).foregroundStyle(Palette.teal)
                .padding(.bottom, 24)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        // Sits a little below the top of the sheet rather than centred.
        .padding(.top, 28)
        .kidPageBackground()
    }

    private var isComplete: Bool { code.count == codeLength && confirm.count == codeLength }

    private func field(_ title: String, text: Binding<String>) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title).font(.subheadline).foregroundStyle(Palette.textSoft)
            SecureField("••••••", text: text)
                .font(.title2.monospaced())
                .multilineTextAlignment(.center)
                .padding(16)
                .background(.white, in: RoundedRectangle(cornerRadius: Radius.field))
                .overlay(RoundedRectangle(cornerRadius: Radius.field).stroke(Palette.borderField, lineWidth: Border.field))
                #if os(iOS)
                .keyboardType(.numberPad)
                #endif
                .onChange(of: text.wrappedValue) { _, new in
                    let filtered = String(new.filter(\.isNumber).prefix(codeLength))
                    if filtered != new { text.wrappedValue = filtered }
                }
                .accessibilityLabel(title)
        }
        .padding(.horizontal, 24)
    }

    private func save() {
        guard code.count == codeLength else { error = "Use 6 digits."; return }
        guard code == confirm else { error = "The codes don't match."; return }
        app.setParentCode(code)
        dismiss()
    }
}

// MARK: - Card

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

#if DEBUG
#Preview("Gate") { ParentGateView().environmentObject(AppState.preview()) }
#Preview("Dashboard") { ParentDashboardView().environmentObject(AppState.previewDashboard()) }
#endif
