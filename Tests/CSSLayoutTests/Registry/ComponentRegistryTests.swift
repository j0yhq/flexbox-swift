import XCTest
import SwiftUI
@testable import CSSLayout

/// `ComponentRegistry` stores factories by type name.
///
/// Tests exercise the contract shape only; they don't assert on the actual
/// View output, because inspecting opaque SwiftUI views is brittle. The
/// resolver tests verify that the right factory fires via marker traces.
///
/// Tier 2 note: these tests previously split coverage across a legacy
/// `AnyView`-returning `register(_:factory:)` and a Tier-2
/// `register(_:body:)` overload. Unit 7 retired the legacy shape, so the
/// two APIs collapsed into a single factory that returns
/// ``ComponentBody``. The old co-existence / shadowing assertions are no
/// longer meaningful and were deleted.
final class ComponentRegistryTests: XCTestCase {

    // MARK: - Test fixture

    /// A fresh registry per test — avoid leaking registrations between tests
    /// via the package-wide singleton.
    private var registry: ComponentRegistry!

    override func setUp() {
        super.setUp()
        registry = ComponentRegistry()
    }

    // MARK: - Registration

    func testRegisterAndLookupByType() {
        registry.register("button") { _, _ in .custom { EmptyView() } }
        XCTAssertNotNil(registry.factory(for: "button"))
    }

    func testLastRegistrationWins() {
        var hit = 0
        registry.register("text") { _, _ in
            hit = 1
            return .custom { EmptyView() }
        }
        registry.register("text") { _, _ in
            hit = 2
            return .custom { EmptyView() }
        }
        _ = registry.factory(for: "text")?(ComponentProps([:]), ComponentEvents())
        XCTAssertEqual(hit, 2)
    }

    func testUnknownTypeReturnsNil() {
        XCTAssertNil(registry.factory(for: "never-registered"))
    }

    func testRegisterIsChainable() {
        let returned = registry
            .register("a") { _, _ in .custom { EmptyView() } }
            .register("b") { _, _ in .custom { EmptyView() } }
        XCTAssertTrue(returned === registry)
        XCTAssertNotNil(registry.factory(for: "a"))
        XCTAssertNotNil(registry.factory(for: "b"))
    }

    // MARK: - ComponentBody round-trip

    /// A factory stored via `register(_:factory:)` round-trips through
    /// `factory(for:)` and, when invoked, runs exactly once per call.
    func testFactoryRoundTripInvokesBuilder() {
        var calls = 0
        registry.register("card") { _, _ -> ComponentBody in
            calls += 1
            return .custom { EmptyView() }
        }
        let retrieved = registry.factory(for: "card")
        XCTAssertNotNil(retrieved, "factory must round-trip through registry")
        _ = retrieved?(ComponentProps([:]), ComponentEvents())
        XCTAssertEqual(calls, 1)
    }

    // MARK: - ComponentProps

    func testPropsStringSubscript() {
        let props = ComponentProps(["label": "Submit", "placeholder": "Name"])
        XCTAssertEqual(props.string("label"), "Submit")
        XCTAssertEqual(props.string("placeholder"), "Name")
    }

    func testPropsStringReturnsNilForMissingKey() {
        let props = ComponentProps([:])
        XCTAssertNil(props.string("missing"))
    }

    func testPropsID() {
        let props = ComponentProps(["label": "Go"], id: "submit")
        XCTAssertEqual(props.id, "submit")
    }

    // MARK: - ComponentEvents

    func testEventsEmitIsANoOpWhenNoSink() {
        // No sink wired — calling emit should not crash.
        let events = ComponentEvents()
        events.emit("tap", payload: ["key": "value"])
    }

    func testEventsSinkReceivesCalls() {
        var received: [(String, [String: String], Bool)] = []
        let events = ComponentEvents { name, payload, propagates in
            received.append((name, payload, propagates))
        }
        events.emit("submit", payload: ["form": "signup"])
        events.emit("tap",    payload: [:],  propagates: false)
        XCTAssertEqual(received.count, 2)
        XCTAssertEqual(received[0].0, "submit")
        XCTAssertEqual(received[0].1["form"], "signup")
        XCTAssertTrue(received[0].2, "default emit bubbles")
        XCTAssertEqual(received[1].0, "tap")
        XCTAssertFalse(received[1].2, "explicit propagates: false respected")
    }
}
