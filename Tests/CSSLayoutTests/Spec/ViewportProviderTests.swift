import SwiftUI
import XCTest
@testable import CSSLayout

/// Unit 6 — `ViewportProvider` (the testable seam) and the SwiftUI
/// environment key that lets a host push the current viewport down to
/// CSSLayout's resolver pipeline.
///
/// Live geometry observation (`GeometryReader`, `UITraitCollection`)
/// is a host concern that the end-to-end demo (Unit 11) exercises;
/// these tests cover the data plumbing only.
final class ViewportProviderTests: XCTestCase {

    // MARK: - StaticViewportProvider

    func testStaticProviderReturnsItsStoredViewport() {
        let viewport = Viewport(width: 1024, orientation: .landscape, isPrint: false)
        let provider = StaticViewportProvider(viewport)
        XCTAssertEqual(provider.currentViewport(), viewport)
    }

    func testStaticProviderIsValueCopyable() {
        let original = StaticViewportProvider(Viewport(width: 320))
        let copy     = original
        XCTAssertEqual(original.currentViewport(), copy.currentViewport())
    }

    // MARK: - SwiftUI environment key

    func testEnvironmentDefaultIsNil() {
        let env = EnvironmentValues()
        XCTAssertNil(env.joyViewport,
                     "default joyViewport must be nil so resolvers can detect 'unwired'")
    }

    func testEnvironmentRoundTripsAssignedViewport() {
        var env = EnvironmentValues()
        let viewport = Viewport(width: 768, orientation: .portrait)
        env.joyViewport = viewport
        XCTAssertEqual(env.joyViewport, viewport)
    }

    func testEnvironmentReassignmentReplacesValue() {
        var env = EnvironmentValues()
        env.joyViewport = Viewport(width: 320)
        env.joyViewport = Viewport(width: 1280, orientation: .landscape)
        XCTAssertEqual(env.joyViewport?.width, 1280)
        XCTAssertEqual(env.joyViewport?.orientation, .landscape)
    }

    func testEnvironmentNilingClearsValue() {
        var env = EnvironmentValues()
        env.joyViewport = Viewport(width: 320)
        env.joyViewport = nil
        XCTAssertNil(env.joyViewport)
    }
}
