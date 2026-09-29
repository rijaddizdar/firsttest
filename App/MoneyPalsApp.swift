//
//  MoneyPalsApp.swift
//  App entry point + root router for the SwiftUI app.
//
//  "MoneyPals" is a PLACEHOLDER only — the real app name is held pending a
//  trademark search and does not appear anywhere in the UI.
//
//  At launch: open the on-device SwiftData store, load and validate the bundled
//  lesson content, and hand both to `AppState`. Target iOS 17+, iPhone and iPad.
//  See docs/RUNNING.md.
//

import SwiftUI
import SwiftData

@main
struct MoneyPalsApp: App {
    @StateObject private var app: AppState

    init() {
        // Progress lives on the device only — no backend, no network.
        let container = PersistenceController.makeContainer()
        _app = StateObject(wrappedValue: AppState(container: container))
    }

    var body: some Scene {
        WindowGroup {
            RootView()
                .environmentObject(app)
        }
    }
}

/// Switches between top-level screens based on `AppState.route`.
/// A plain enum-driven flow keeps the app easy to follow; deeper navigation can
/// layer NavigationStack on top where it's needed.
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
            case .kidFirstRun:      KidFirstRunView()
            case .editAvatar:       EditAvatarView()
            case .lessonMap:        LessonMapView()
            case .levelLessons:     LevelLessonsView()
            case .lesson:           lessonPlayer
            case .parentGate:       ParentGateView()
            case .parentDashboard:  ParentDashboardView()
            }
        }
        // Cross-fade between routes; respects Reduce Motion (opacity only).
        .transition(.opacity)
        .animation(.easeInOut(duration: 0.25), value: app.route)
    }

    /// The lesson engine plays whichever lesson the map opened. Keyed by lesson
    /// id so starting a different one begins with a fresh run.
    @ViewBuilder
    private var lessonPlayer: some View {
        if let lesson = app.activeLesson {
            LessonPlayerView(lesson: lesson,
                             kidName: app.selectedKid?.name ?? "friend",
                             startScreen: app.uiTestLessonScreen,
                             testFeedback: app.uiTestLessonFeedback)
                .id(lesson.id)
        } else {
            // No lesson to play (content changed, or a stale deep link).
            Color.clear.onAppear { app.route = .lessonMap }
        }
    }
}
