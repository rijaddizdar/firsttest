//
//  SetupView.swift
//  Screen 2: the grown-up setup flow, in three steps:
//    2a. Grown-up check — press and hold for 3 seconds (README section 6).
//    2b. Create parent code — a 6-digit PIN that locks the dashboard.
//    2c. Add a kid — first name plus the avatar builder (Avatar/).
//

import SwiftUI

// MARK: - 2a. Grown-up check (press-and-hold gate)

struct GrownUpCheckView: View {
    @EnvironmentObject private var app: AppState
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private let holdDuration: TimeInterval = 3.0
    @State private var progress: CGFloat = 0
    @State private var isHolding = false
    @State private var timer: Timer?

    var body: some View {
        VStack(spacing: 28) {
            Spacer()
            PennyView(mood: .idle, size: 130)

            Text("Grown-ups only")
                .font(.screenTitle)
                .foregroundStyle(Palette.textHeading)

            Text("Press and hold the button for 3 seconds.")
                .font(.title3)
                .multilineTextAlignment(.center)
                .foregroundStyle(Palette.textMuted)
                .padding(.horizontal, 30)

            Spacer()

            // Circular hold target with a progress ring.
            ZStack {
                Circle()
                    .stroke(Palette.lockGrey.opacity(0.4), lineWidth: Border.holdRing)
                Circle()
                    .trim(from: 0, to: progress)
                    .stroke(Palette.teal, style: StrokeStyle(lineWidth: Border.holdRing, lineCap: .round))
                    .rotationEffect(.degrees(-90))
                // UI chrome (a hand-tap prompt): kept as an SF Symbol, which has
                // no Fluent 3D equivalent (Penny Design System, "Iconography").
                Image(systemName: "hand.tap.fill")
                    .font(.system(size: 46))
                    .foregroundStyle(isHolding ? Palette.teal : Palette.copper)
            }
            .frame(width: 170, height: 170)
            .contentShape(Circle())
            // A long press is exactly the "task young children can't easily do".
            .gesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { _ in startHold() }
                    .onEnded { _ in endHold() }
            )
            .accessibilityLabel("Press and hold to continue as a grown-up")

            Text(isHolding ? "Keep holding…" : "Hold to continue")
                .font(.headline)
                .foregroundStyle(Palette.ink.opacity(0.6))

            Spacer()

            Button("Back") { app.route = .welcome }
                .buttonStyle(BigButtonStyle(fill: Palette.lockGrey, textColor: Palette.ink))
                .padding(.horizontal, 24)
                .padding(.bottom, 24)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .kidPageBackground()
    }

    private func startHold() {
        guard !isHolding else { return }
        isHolding = true
        let step = 0.02
        timer = Timer.scheduledTimer(withTimeInterval: step, repeats: true) { _ in
            progress += CGFloat(step / holdDuration)
            if progress >= 1 {
                finish()
            }
        }
    }

    private func endHold() {
        isHolding = false
        timer?.invalidate()
        timer = nil
        // Reset unless already complete.
        if progress < 1 {
            withAnimation(.easeOut(duration: 0.3)) { progress = 0 }
        }
    }

    private func finish() {
        timer?.invalidate(); timer = nil
        isHolding = false
        progress = 1
        // If a code already exists this gate leads to the parent dashboard;
        // otherwise it continues the first-time setup.
        app.route = app.hasParentCode ? .parentDashboard : .createParentCode
    }
}

// MARK: - 2b. Create parent code

struct CreateParentCodeView: View {
    @EnvironmentObject private var app: AppState
    @State private var code = ""
    @State private var confirm = ""
    @State private var error: String?

    private let codeLength = 6

    var body: some View {
        VStack(spacing: 22) {
            Spacer()
            FluentIcon(name: "locked", size: 64)

            Text("Create a parent code")
                .font(.screenTitle)
                .foregroundStyle(Palette.textHeading)

            Text("A 6-digit code — not a birthday. It locks the parent dashboard.")
                .font(.body)
                .multilineTextAlignment(.center)
                .foregroundStyle(Palette.textMuted)
                .padding(.horizontal, 30)

            codeField("Enter code", text: $code)
            codeField("Confirm code", text: $confirm)

            if let error {
                Text(error).font(.subheadline).foregroundStyle(Palette.copper)
            }

            Spacer()

            Button("Save code") { save() }
                .buttonStyle(BigButtonStyle(fill: Palette.teal))
                .disabled(code.count != codeLength || confirm.count != codeLength)
                .opacity(code.count == codeLength && confirm.count == codeLength ? 1 : 0.5)
                .padding(.horizontal, 24)
                .padding(.bottom, 24)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .kidPageBackground()
    }

    private func codeField(_ title: String, text: Binding<String>) -> some View {
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
                    // Keep it to digits, max length.
                    let filtered = String(new.filter(\.isNumber).prefix(codeLength))
                    if filtered != new { text.wrappedValue = filtered }
                }
        }
        .padding(.horizontal, 24)
    }

    private func save() {
        guard code.count == codeLength else { error = "Use 6 digits."; return }
        guard code == confirm else { error = "The codes don't match."; return }
        // Stored only as a salted hash, never in plain text (README section 9).
        app.setParentCode(code)
        app.route = .addKid
    }
}

// MARK: - 2c. Add a kid

/// The grown-up's quick path: type the child's first name and make a first
/// look with the SAME builder the child uses, so what is made here is exactly
/// what the child sees on "Who's learning?".
///
/// The child still gets their own first time (`KidFirstRunView`) when they
/// first tap their face — it opens with whatever was chosen here, so they can
/// keep all of it with one tap.
struct AddKidView: View {
    @EnvironmentObject private var app: AppState
    @State private var name = ""
    @State private var avatar = Avatar()

    var body: some View {
        VStack(spacing: 0) {
            ScrollView {
                VStack(spacing: 22) {
                    Text("Add a kid")
                        .font(.screenTitle)
                        .foregroundStyle(Palette.textHeading)

                    // Name — first name / nickname only (README section 6).
                    // No last names.
                    VStack(alignment: .leading, spacing: 6) {
                        Text("What should we call them?")
                            .font(.subheadline).foregroundStyle(Palette.textSoft)
                        TextField("First name or nickname", text: $name)
                            .font(.title3)
                            .padding(16)
                            .background(.white, in: RoundedRectangle(cornerRadius: Radius.field))
                            .overlay(RoundedRectangle(cornerRadius: Radius.field)
                                .stroke(Palette.borderField, lineWidth: Border.field))
                            .autocorrectionDisabled()
                            .onChange(of: name) { _, new in
                                name = KidFirstRunView.trimToNameLength(new)
                            }
                    }
                    .padding(.horizontal, 24)

                    // The avatar builder itself (README section 6).
                    AvatarBuilderView(avatar: $avatar, previewSize: 96)

                    Text("Your child can change all of this the first time they tap their own face.")
                        .font(.footnote)
                        .multilineTextAlignment(.center)
                        .foregroundStyle(Palette.textFaint)
                        .padding(.horizontal, 30)
                }
                // Sits a little below the top of the screen rather than centred.
                .padding(.top, 24)
                .padding(.bottom, 24)
            }

            Button("Start learning") {
                app.addKid(name: name, avatar: avatar)
                app.route = .whosLearning
            }
            .buttonStyle(BigButtonStyle(fill: Palette.teal))
            .padding(.horizontal, 24)
            .padding(.bottom, 24)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .lessonContentWidth()
        .kidPageBackground()
    }
}

#Preview("Grown-up check") { GrownUpCheckView().environmentObject(AppState.preview()) }
#Preview("Parent code") { CreateParentCodeView().environmentObject(AppState.preview()) }
#Preview("Add kid") { AddKidView().environmentObject(AppState.preview()) }
