//
//  MoneyPalsApp.swift
//  App entry point + root router for the SwiftUI mock-up.
//
//  "MoneyPals" is a PLACEHOLDER only — the real app name is held pending a
//  trademark search and does not appear anywhere in the UI.
//
//  Target: iOS 17+ (SwiftUI). See docs/RUNNING.md for how to open this in Xcode.
//

import SwiftUI

@main
struct MoneyPalsApp: App {
    @StateObject private var app = AppState()

    var body: some Scene {
        WindowGroup {
            RootView()
                .environmentObject(app)
        }
    }
}

/// Switches between top-level screens based on `AppState.route`.
/// A plain enum-driven flow keeps the mock-up easy to follow; the real app can
/// layer NavigationStack on top where deeper navigation is needed.
struct RootView: View {
    @EnvironmentObject private var app: AppState

    var body: some View {
        Group {
            switch app.route {
            case .welcome:          WelcomeView()
            case .grownUpCheck:     GrownUpCheckView()
            case .createParentCode: CreateParentCodeView()
            case .addKid:           AddKidView()
            case .whosLearning:     WhosLearningView()
            case .lessonMap:        LessonMapView()
            case .lesson:           LessonPlayerView()
            case .parentGate:       ParentGateView()
            case .parentDashboard:  ParentDashboardView()
            }
        }
        // Cross-fade between routes; respects Reduce Motion (opacity only).
        .transition(.opacity)
        .animation(.easeInOut(duration: 0.25), value: app.route)
    }
}
