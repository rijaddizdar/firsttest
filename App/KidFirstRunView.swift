//
//  KidFirstRunView.swift
//  A child's own first time, in the three steps of README section 6
//  ("Each child's first time"):
//
//      1. "What should I call you?"  — a first name or nickname, nothing else
//      2. "Make it yours!"           — the avatar builder
//      3. Meet Penny                 — who she is, and why her shell is coins
//      → the map, where Penny starts using the child's name
//
//  It runs the first time a child taps their own face on "Who's learning?", and
//  starts from whatever the grown-up already typed and picked, so a child can
//  keep it all and tap straight through.
//
//  Nothing new is stored: the name and the avatar choices are the same two
//  things README section 9 already allows.
//

import SwiftUI

struct KidFirstRunView: View {
    @EnvironmentObject private var app: AppState

    enum Step: String, CaseIterable {
        case name, look, penny
    }

    @State private var step: Step = .name
    @State private var name = ""
    @State private var avatar = Avatar()
    @State private var loaded = false

    var body: some View {
        Group {
            if app.selectedKid == nil {
                // No profile to set up — somebody deep-linked here.
                Color.clear.onAppear { app.route = .whosLearning }
            } else {
                steps
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .lessonContentWidth()
        .kidPageBackground()
        .animation(.easeInOut(duration: Motion.step), value: step)
        .onAppear(perform: load)
    }

    @ViewBuilder
    private var steps: some View {
        switch step {
        case .name:  nameStep
        case .look:  lookStep
        case .penny: pennyStep
        }
    }

    // MARK: 1. What should I call you?

    private var nameStep: some View {
        VStack(spacing: 22) {
            PennyView(mood: .wave, size: 150)

            SpeechBubble(text: "Hi! What should I call you?")
                .padding(.horizontal, 24)

            Text("Just your first name, or a nickname you like.")
                .font(.title3)
                .multilineTextAlignment(.center)
                .foregroundStyle(Palette.textMuted)
                .padding(.horizontal, 30)

            // First name or nickname ONLY (README section 6). There is nowhere
            // in this app to type a last name, a birthday or anything else.
            TextField("Your name", text: $name)
                .font(.title2)
                .multilineTextAlignment(.center)
                .padding(16)
                .background(.white, in: RoundedRectangle(cornerRadius: Radius.field))
                .overlay(RoundedRectangle(cornerRadius: Radius.field)
                    .stroke(Palette.borderField, lineWidth: Border.field))
                .padding(.horizontal, 24)
                #if os(iOS)
                .textInputAutocapitalization(.words)
                #endif
                .autocorrectionDisabled()
                .accessibilityLabel("Your first name or nickname")
                .onChange(of: name) { _, new in name = Self.trimToNameLength(new) }

            Spacer(minLength: 0)

            Button("That's me!") {
                save(name: name)
                step = .look
            }
            .buttonStyle(BigButtonStyle(fill: Palette.teal))
            .disabled(trimmedName.isEmpty)
            .opacity(trimmedName.isEmpty ? 0.5 : 1)
            .padding(.horizontal, 24)
            .padding(.bottom, 24)
        }
        // Sits a little below the top of the screen rather than centred.
        .padding(.top, 24)
    }

    // MARK: 2. Make it yours!

    private var lookStep: some View {
        VStack(spacing: 0) {
            ScrollView {
                VStack(spacing: 22) {
                    Text("Make it yours!")
                        .font(.screenTitle)
                        .foregroundStyle(Palette.textHeading)
                        .multilineTextAlignment(.center)

                    Text("Pick a look you like. You can change it any time.")
                        .font(.body)
                        .multilineTextAlignment(.center)
                        .foregroundStyle(Palette.textMuted)
                        .padding(.horizontal, 30)

                    AvatarBuilderView(avatar: $avatar)
                }
                .padding(.top, 24)
                .padding(.bottom, 24)
            }

            Button("I like it!") {
                save(avatar: avatar)
                step = .penny
            }
            .buttonStyle(BigButtonStyle(fill: Palette.teal))
            .padding(.horizontal, 24)
            .padding(.bottom, 24)
        }
    }

    // MARK: 3. Meet Penny

    /// The short intro README section 2 calls for: some children have never
    /// heard of an armadillo, so Penny says what she is before the first lesson.
    private var pennyStep: some View {
        VStack(spacing: 22) {
            PennyView(mood: .idle, size: 170)

            SpeechBubble(text: "Hi, \(trimmedName)! I'm Penny.")
                .padding(.horizontal, 24)

            VStack(spacing: 14) {
                Text("I'm an armadillo. That's an animal with a shell.")
                Text("Look — my shell is made of shiny coins!")
                Text("We'll learn about money together.")
            }
            .font(.title3)
            .multilineTextAlignment(.center)
            .foregroundStyle(Palette.textMuted)
            .padding(.horizontal, 28)

            Spacer(minLength: 0)

            Button("Let's go!") {
                if let id = app.selectedKidID {
                    app.finishKidFirstRun(id)
                }
                app.route = .lessonMap
            }
            .buttonStyle(BigButtonStyle(fill: Palette.teal))
            .padding(.horizontal, 24)
            .padding(.bottom, 24)
        }
        .padding(.top, 24)
    }

    // MARK: Saving

    private var trimmedName: String {
        name.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    /// Each step writes as it is finished, so a child who closes the app half
    /// way through keeps what they already chose and picks up from there.
    private func save(name: String? = nil, avatar: Avatar? = nil) {
        guard let id = app.selectedKidID else { return }
        app.updateKid(id, name: name, avatar: avatar)
    }

    private func load() {
        guard !loaded, let kid = app.selectedKid else { return }
        loaded = true
        name = kid.name
        avatar = kid.avatar
        if let raw = app.uiTestFirstRunStep, let step = Step(rawValue: raw) {
            self.step = step
        }
    }

    /// A nickname, not an essay. Long enough for any real first name, short
    /// enough that the name still fits in Penny's speech bubbles.
    static func trimToNameLength(_ raw: String) -> String {
        let oneLine = raw.replacingOccurrences(of: "\n", with: " ")
        return String(oneLine.prefix(20))
    }
}

#if DEBUG
#Preview("First time") {
    KidFirstRunView().environmentObject(AppState.preview())
}
#endif
