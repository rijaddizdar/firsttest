//
//  WelcomeView.swift
//  Screen 1: Welcome, with placeholder Penny and a "grown-up sets this up" entry.
//

import SwiftUI

struct WelcomeView: View {
    @EnvironmentObject private var app: AppState
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        VStack(spacing: 28) {
            Spacer()

            PennyView(mood: .wave, size: 190)

            VStack(spacing: 10) {
                // App name is intentionally omitted (held pending a trademark
                // search). "MoneyPals" is only a placeholder — see Theme.swift.
                Text("Learn about money with Penny!")
                    .font(.screenTitle)
                    .multilineTextAlignment(.center)
                    .foregroundStyle(Palette.textHeading)

                Text("Penny the armadillo makes learning about money fun.")
                    .font(.title3)
                    .multilineTextAlignment(.center)
                    .foregroundStyle(Palette.textMuted)
            }
            .padding(.horizontal, 24)

            Spacer()

            VStack(spacing: 14) {
                // Fresh setup path: grown-up check -> parent code -> add a kid.
                Button("A grown-up sets this up") {
                    app.route = .grownUpCheck
                }
                .buttonStyle(BigButtonStyle(fill: Palette.teal))

                // Demo convenience: jump straight to the seeded kid's map.
                if !app.kids.isEmpty {
                    Button("See a demo (skip setup)") {
                        app.route = .whosLearning
                    }
                    .buttonStyle(BigButtonStyle(fill: Palette.copper))
                }
            }
            .padding(.horizontal, 24)
            .padding(.bottom, 24)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .kidPageBackground()
    }
}

#Preview {
    WelcomeView().environmentObject(AppState())
}
