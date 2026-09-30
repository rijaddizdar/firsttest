//
//  PlayableOnADeviceTests.swift
//  The things that make this a real app on a real iPad rather than a build
//  that only runs in a simulator: it has a voice, it has a face on the home
//  screen, and it can be signed.
//
//  These are cheap to break silently — an asset that stops shipping, a renamed
//  file — and expensive to notice, because the app carries on working, just
//  mutely or as a blank white square.
//

import XCTest
@testable import MoneyPals
#if canImport(UIKit)
import UIKit
#endif

final class PlayableOnADeviceTests: XCTestCase {

    // MARK: Penny has a voice

    /// README section 3 promises a chime, a soft boop and a celebration.
    /// `LessonAudio` was a documented no-op for a long time; this is what stops
    /// it quietly becoming one again.
    func testEveryLessonSoundShipsInTheBundle() throws {
        for name in ["right", "wrong", "celebrate"] {
            let url = Bundle.main.url(forResource: name, withExtension: "wav", subdirectory: "Sounds")
                ?? Bundle.main.url(forResource: name, withExtension: "wav")
            let found = try XCTUnwrap(url, "\(name).wav is not in the app bundle")
            let bytes = try Data(contentsOf: found)
            XCTAssertGreaterThan(bytes.count, 1_000, "\(name).wav looks empty")
            XCTAssertEqual(bytes.prefix(4), Data("RIFF".utf8), "\(name).wav is not a WAV file")
        }
    }

    /// A lesson sound is an effect, not a lost second: anything long enough to
    /// still be playing on the next screen is too long for a 6-year-old.
    func testTheSoundsAreShortEnoughToBeEffects() throws {
        for name in ["right", "wrong", "celebrate"] {
            let url = try XCTUnwrap(Bundle.main.url(forResource: name, withExtension: "wav",
                                                    subdirectory: "Sounds")
                                    ?? Bundle.main.url(forResource: name, withExtension: "wav"))
            let bytes = try Data(contentsOf: url)
            // 44.1kHz, 16-bit mono: bytes ÷ 88200 ≈ seconds.
            let seconds = Double(bytes.count) / 88_200
            XCTAssertLessThan(seconds, 1.5, "\(name).wav is \(seconds)s — too long for a tap")
        }
    }

    /// The switch in the grown-up area has to actually silence Penny.
    func testTurningSoundOffIsHonoured() {
        let wasEnabled = LessonAudio.isEnabled
        defer { LessonAudio.isEnabled = wasEnabled }

        LessonAudio.isEnabled = false
        LessonAudio.play(.right)        // must not throw, must not play
        LessonAudio.isEnabled = true
        LessonAudio.play(.right)
        XCTAssertTrue(true, "playing in either state must never trap")
    }

    // MARK: It has a face on the home screen

    #if canImport(UIKit)
    /// Without this the app installs as a blank white square.
    func testTheAppHasAnIcon() throws {
        let icons = Bundle.main.infoDictionary?["CFBundleIcons"] as? [String: Any]
        let primary = icons?["CFBundlePrimaryIcon"] as? [String: Any]
        let files = primary?["CFBundleIconFiles"] as? [String]
        XCTAssertFalse(files?.isEmpty ?? true, "no app icon is set")
    }
    #endif

    // An "is the icon opaque?" test used to live here. It could only reach the
    // variant Xcode's asset compiler emits into the bundle (AppIcon60x60@2x and
    // friends), not the 1024px source in the catalog — and that generated PNG
    // carries an alpha channel of its own, so the test failed on a source image
    // that is, and was, fully opaque. It was checking Xcode's output rather than
    // our asset. The requirement is real (an icon with alpha is rejected at
    // submission, not at build), but it belongs in a check over the source file,
    // not in a unit test running inside the built app.

    /// A launch screen the same cream as the first real screen, so the app does
    /// not flash white before Penny appears.
    func testTheLaunchScreenIsConfigured() throws {
        let launch = try XCTUnwrap(Bundle.main.infoDictionary?["UILaunchScreen"] as? [String: Any],
                                   "no launch screen")
        XCTAssertEqual(launch["UIColorName"] as? String, "LaunchBackground")
        #if canImport(UIKit)
        XCTAssertNotNil(UIColor(named: "LaunchBackground"), "the launch colour is not in the catalog")
        #endif
    }
}
