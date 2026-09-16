//
//  SetupView.swift
//  Screen 2: the grown-up setup flow, in three steps:
//    2a. Grown-up check — press and hold for 3 seconds (README section 6).
//    2b. Create parent code — a 6-digit PIN that locks the dashboard.
//    2c. Add a kid — name + boy/girl + avatar colour.
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
        VStack(spacing: Metric.lg) {
            Spacer()
            PennyView(mood: .idle, size: 140)

            Text("Grown-ups only")
                .font(.kidHero)
                .foregroundStyle(Palette.teal)

            Text("Press and hold the button for 3 seconds.")
                .font(.kidBody)
                .multilineTextAlignment(.center)
                .foregroundStyle(Palette.ink.opacity(0.65))
                .padding(.horizontal, Metric.xl)

            Spacer()

            // Circular hold target with a progress ring.
            ZStack {
                Circle()
                    .fill(.white)
                    .softShadow()
                Circle()
                    .stroke(Palette.lockGrey.opacity(0.35), lineWidth: 14)
                    .padding(10)
                Circle()
                    .trim(from: 0, to: progress)
                    .stroke(
                        AngularGradient(colors: [Palette.skyTeal, Palette.teal], center: .center),
                        style: StrokeStyle(lineWidth: 14, lineCap: .round)
                    )
                    .rotationEffect(.degrees(-90))
                    .padding(10)
                Image(systemName: "hand.tap.fill")
                    .font(.system(size: 46))
                    .foregroundStyle(isHolding ? Palette.teal : Palette.copper)
                    .scaleEffect(isHolding && !reduceMotion ? 0.9 : 1)
                    .animation(.spring(response: 0.3, dampingFraction: 0.6), value: isHolding)
            }
            .frame(width: 180, height: 180)
            .contentShape(Circle())
            // A long press is exactly the "task young children can't easily do".
            .gesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { _ in startHold() }
                    .onEnded { _ in endHold() }
            )
            .accessibilityLabel("Press and hold to continue as a grown-up")

            Text(isHolding ? "Keep holding…" : "Hold to continue")
                .font(.kidCaption)
                .foregroundStyle(Palette.ink.opacity(0.55))

            Spacer()

            Button("Back") { app.route = .welcome }
                .buttonStyle(SoftButtonStyle(tint: Palette.ink.opacity(0.55)))
                .padding(.horizontal, Metric.pagePadding)
                .padding(.bottom, Metric.lg)
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
        VStack(spacing: Metric.lg) {
            Spacer()
            ZStack {
                Circle().fill(Palette.teal.opacity(0.12)).frame(width: 92, height: 92)
                Image(systemName: "lock.fill")
                    .font(.system(size: 44))
                    .foregroundStyle(Palette.teal)
            }

            Text("Create a parent code")
                .font(.kidTitle)
                .foregroundStyle(Palette.teal)

            Text("A 6-digit code — not a birthday. It locks the parent dashboard.")
                .font(.kidBody)
                .multilineTextAlignment(.center)
                .foregroundStyle(Palette.ink.opacity(0.65))
                .padding(.horizontal, Metric.xl)

            codeField("Enter code", text: $code)
            codeField("Confirm code", text: $confirm)

            if let error {
                Text(error).font(.kidCaption).foregroundStyle(Palette.copper)
            }

            Spacer()

            Button("Save code") { save() }
                .buttonStyle(BigButtonStyle(fill: Palette.teal, icon: "checkmark"))
                .disabled(code.count != codeLength || confirm.count != codeLength)
                .padding(.horizontal, Metric.pagePadding)
                .padding(.bottom, Metric.lg)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .kidPageBackground()
    }

    private func codeField(_ title: String, text: Binding<String>) -> some View {
        VStack(alignment: .leading, spacing: Metric.xs) {
            Text(title).font(.kidCaption).foregroundStyle(Palette.ink.opacity(0.55))
            SecureField("••••••", text: text)
                .font(.system(.title2, design: .rounded).monospaced())
                .multilineTextAlignment(.center)
                .padding(16)
                .background(.white, in: RoundedRectangle(cornerRadius: Metric.chipRadius, style: .continuous))
                .overlay(RoundedRectangle(cornerRadius: Metric.chipRadius, style: .continuous).stroke(Palette.skyTeal.opacity(0.4), lineWidth: 1.5))
                .softShadow()
                #if os(iOS)
                .keyboardType(.numberPad)
                #endif
                .onChange(of: text.wrappedValue) { _, new in
                    // Keep it to digits, max length.
                    let filtered = String(new.filter(\.isNumber).prefix(codeLength))
                    if filtered != new { text.wrappedValue = filtered }
                }
        }
        .padding(.horizontal, Metric.pagePadding)
    }

    private func save() {
        guard code.count == codeLength else { error = "Use 6 digits."; return }
        guard code == confirm else { error = "The codes don't match."; return }
        // In the real app this is stored only as a salted hash (README section 9).
        app.parentCode = code
        app.route = .addKid
    }
}

// MARK: - 2c. Add a kid

struct AddKidView: View {
    @EnvironmentObject private var app: AppState
    @State private var name = ""
    @State private var kind: AvatarKind = .girl
    @State private var colorIndex = 0

    var body: some View {
        VStack(spacing: Metric.lg) {
            Spacer()
            // Live preview of the chosen avatar.
            AvatarBadge(kind: kind, color: Palette.avatarChoices[colorIndex], size: 116)
                .animation(.spring(response: 0.35, dampingFraction: 0.6), value: colorIndex)
                .animation(.spring(response: 0.35, dampingFraction: 0.6), value: kind)

            Text("Add a kid")
                .font(.kidTitle)
                .foregroundStyle(Palette.teal)

            // Name — first name / nickname only (README section 6). No last names.
            VStack(alignment: .leading, spacing: Metric.xs) {
                Text("What should we call them?")
                    .font(.kidCaption).foregroundStyle(Palette.ink.opacity(0.55))
                TextField("First name or nickname", text: $name)
                    .font(.kidBody)
                    .padding(16)
                    .background(.white, in: RoundedRectangle(cornerRadius: Metric.chipRadius, style: .continuous))
                    .overlay(RoundedRectangle(cornerRadius: Metric.chipRadius, style: .continuous).stroke(Palette.skyTeal.opacity(0.4), lineWidth: 1.5))
                    .softShadow()
            }
            .padding(.horizontal, Metric.pagePadding)

            // Boy / girl look (README section 6).
            Picker("Avatar", selection: $kind) {
                ForEach(AvatarKind.allCases) { k in Text(k.label).tag(k) }
            }
            .pickerStyle(.segmented)
            .padding(.horizontal, Metric.pagePadding)

            // Avatar colour pick.
            VStack(spacing: Metric.sm) {
                Text("Pick a colour").font(.kidCaption).foregroundStyle(Palette.ink.opacity(0.55))
                HStack(spacing: 14) {
                    ForEach(Palette.avatarChoices.indices, id: \.self) { i in
                        Circle()
                            .fill(Palette.avatarChoices[i])
                            .frame(width: 42, height: 42)
                            .overlay(Circle().stroke(.white, lineWidth: colorIndex == i ? 3 : 0))
                            .overlay(Circle().stroke(Palette.ink.opacity(colorIndex == i ? 0.5 : 0), lineWidth: 2).padding(-3))
                            .scaleEffect(colorIndex == i ? 1.15 : 1)
                            .softShadow()
                            .onTapGesture {
                                Haptics.selection()
                                withAnimation(.spring(response: 0.3, dampingFraction: 0.55)) { colorIndex = i }
                            }
                            .accessibilityLabel("Colour \(i + 1)")
                    }
                }
            }

            Spacer()

            Button("Start learning") {
                Haptics.selection()
                app.addKid(name: name, kind: kind, colorIndex: colorIndex)
                app.route = .whosLearning
            }
            .buttonStyle(BigButtonStyle(fill: Palette.teal, icon: "sparkles"))
            .padding(.horizontal, Metric.pagePadding)
            .padding(.bottom, Metric.lg)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .kidPageBackground()
    }
}

/// A round, glossy avatar badge built from an SF Symbol placeholder + colour.
struct AvatarBadge: View {
    let kind: AvatarKind
    let color: Color
    var size: CGFloat = 64

    var body: some View {
        ZStack {
            Circle()
                .fill(
                    RadialGradient(colors: [color.lighter(0.28), color, color.darker(0.12)],
                                   center: UnitPoint(x: 0.35, y: 0.3),
                                   startRadius: 1, endRadius: size * 0.6)
                )
            // Glossy top highlight.
            Ellipse().fill(.white.opacity(0.3))
                .frame(width: size * 0.5, height: size * 0.28)
                .blur(radius: size * 0.03)
                .offset(y: -size * 0.22)
            Circle().stroke(.white.opacity(0.8), lineWidth: size * 0.03)
            Image(systemName: kind.symbolName)
                .font(.system(size: size * 0.52, weight: .medium))
                .foregroundStyle(.white)
        }
        .frame(width: size, height: size)
        .softShadow()
    }
}

#Preview("Grown-up check") { GrownUpCheckView().environmentObject(AppState()) }
#Preview("Parent code") { CreateParentCodeView().environmentObject(AppState()) }
#Preview("Add kid") { AddKidView().environmentObject(AppState()) }
