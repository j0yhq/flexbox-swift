import XCTest
@testable import JoyDOM

/// Unit (Phase 2) — the `JoyEvent` envelope gains a `propagates` flag so
/// handlers can stop bubbling. This test suite covers the struct itself;
/// the actual bubbling semantics live in `CSSLayoutIntegrationTests`.
final class CSSEventTests: XCTestCase {

    func testDefaultPropagatesIsTrue() {
        // Events bubble by default — this mirrors the DOM convention and keeps
        // the Phase 1 contract (one handler, single node) valid: with no
        // ancestor handlers registered, the default has no observable effect.
        let event = JoyEvent(name: "submit", sourceID: "a")
        XCTAssertTrue(event.propagates)
    }

    func testExplicitNonPropagatingEvent() {
        let event = JoyEvent(
            name: "submit", sourceID: "a", payload: [:], propagates: false
        )
        XCTAssertFalse(event.propagates)
    }

    func testEqualityConsidersPropagatesFlag() {
        let bubbling = JoyEvent(name: "x", sourceID: "a")
        let stopped  = JoyEvent(name: "x", sourceID: "a", propagates: false)
        XCTAssertNotEqual(bubbling, stopped)
    }

    func testPayloadDefaultIsEmpty() {
        // Sanity check that the new parameter hasn't displaced the existing
        // default argument for `payload`.
        let event = JoyEvent(name: "x", sourceID: "a")
        XCTAssertEqual(event.payload, [:])
    }
}
