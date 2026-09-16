//
//  WelcomeView.swift
//  Screen 1: Welcome, with placeholder Penny and a "grown-up sets this up" entry.
//

import SwiftUI

struct WelcomeView: View {
    @EnvironmentObject private var app: AppState
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        VStack(spacing: Metric.lg) {
            Spacer()

            // Penny on a soft halo so she pops off the warm backdrop.
            PennyView(mood: .wave, size: 200)
                .background(
                    Circle().fill(Palette.skyTeal.opacity(0.18))
                        .frame(width: 240, height: 240)
                        .blur(radius: 8)
                )

            VStack(spacing: Metric.sm) {
                // App name is intentionally omitted (held pending a trademark
                // search). "MoneyPals" is only a placeholder — see Theme.swift.
                Text("Learn about money with Penny!")
                    .font(.kidHero)
                    .multilineTextAlignment(.center)
                    .foregroundStyle(Palette.teal)

                Text("Penny the pangolin makes learning about money fun.")
                    .font(.kidBody)
                    .multilineTextAlignment(.center)
                    .foregroundStyle(Palette.ink.opacity(0.65))
            }
            .padding(.horizontal, Metric.lg)

            Spacer()

            VStack(spacing: Metric.md) {
                // Fresh setup path: grown-up check -> parent code -> add a kid.
                Button("A grown-up sets this up") {
                    Haptics.selection()
                    app.route = .grownUpCheck
                }
                .buttonStyle(BigButtonStyle(fill: Palette.teal, icon: "person.fill"))

                // Demo convenience: jump straight to the seeded kid's map.
                if !app.kids.isEmpty {
                    Button("See a demo") {
                        Haptics.selection()
                        app.route = .whosLearning
                    }
                    .buttonStyle(SoftButtonStyle(tint: Palette.copper))
                }
            }
            .padding(.horizontal, Metric.pagePadding)
            .padding(.bottom, Metric.lg)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .kidPageBackground()
    }
}

#Preview {
    WelcomeView().environmentObject(AppState())
}
