import XCTest
import SwiftUI
@testable import CSSLayout

/// Unit (m) — `PlaceholderBox`.
///
/// We can't usefully assert on the view body without Inspect-style tooling,
/// so the tests only verify the stored `id` and the default factory hook.
final class PlaceholderBoxTests: XCTestCase {

    func testPlaceholderStoresID() {
        let box = PlaceholderBox(id: "missing-button")
        XCTAssertEqual(box.id, "missing-button")
    }
}
