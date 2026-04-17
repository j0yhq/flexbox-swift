import XCTest
@testable import CSSLayout

/// Unit (Phase 2) — the `CSSEvent` envelope gains a `propagates` flag so
/// handlers can stop bubbling. This test suite covers the struct itself;
/// the actual bubbling semantics live in `CSSLayoutIntegrationTests`.
final class CSSEventTests: XCTestCase {

    func testDefaultPropagatesIsTrue() {
        // Events bubble by default — this mirrors the DOM convention and keeps
        // the Phase 1 contract (one handler, single node) valid: with no
        // ancestor handlers registered, the default has no observable effect.
        let event = CSSEvent(name: "submit", sourceID: "a")
        XCTAssertTrue(event.propagates)
    }

    func testExplicitNonPropagatingEvent() {
        let event = CSSEvent(
            name: "submit", sourceID: "a", payload: [:], propagates: false
        )
        XCTAssertFalse(event.propagates)
    }

    func testEqualityConsidersPropagatesFlag() {
        let bubbling = CSSEvent(name: "x", sourceID: "a")
        let stopped  = CSSEvent(name: "x", sourceID: "a", propagates: false)
        XCTAssertNotEqual(bubbling, stopped)
    }

    func testPayloadDefaultIsEmpty() {
        // Sanity check that the new parameter hasn't displaced the existing
        // default argument for `payload`.
        let event = CSSEvent(name: "x", sourceID: "a")
        XCTAssertEqual(event.payload, [:])
    }
}
