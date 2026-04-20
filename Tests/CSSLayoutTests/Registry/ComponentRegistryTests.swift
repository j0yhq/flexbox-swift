import XCTest
import SwiftUI
@testable import CSSLayout

/// Unit (i) — `ComponentRegistry` stores factories by type name.
///
/// Tests exercise the contract shape only; they don't assert on the actual
/// View output, because inspecting opaque SwiftUI views is brittle. The
/// resolver tests (Unit k) verify that the right factory fires via marker
/// traces.
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
        registry.register("button") { _, _ in AnyView(EmptyView()) }
        XCTAssertNotNil(registry.factory(for: "button"))
    }

    func testLastRegistrationWins() {
        var hit = 0
        registry.register("text") { _, _ in hit = 1; return AnyView(EmptyView()) }
        registry.register("text") { _, _ in hit = 2; return AnyView(EmptyView()) }
        _ = registry.factory(for: "text")?(ComponentProps([:]), ComponentEvents())
        XCTAssertEqual(hit, 2)
    }

    func testUnknownTypeReturnsNil() {
        XCTAssertNil(registry.factory(for: "never-registered"))
    }

    func testRegisterIsChainable() {
        let returned = registry
            .register("a") { _, _ in AnyView(EmptyView()) }
            .register("b") { _, _ in AnyView(EmptyView()) }
        XCTAssertTrue(returned === registry)
        XCTAssertNotNil(registry.factory(for: "a"))
        XCTAssertNotNil(registry.factory(for: "b"))
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
        var received: [(String, [String: String])] = []
        let events = ComponentEvents { name, payload in
            received.append((name, payload))
        }
        events.emit("submit", payload: ["form": "signup"])
        events.emit("tap",    payload: [:])
        XCTAssertEqual(received.count, 2)
        XCTAssertEqual(received[0].0, "submit")
        XCTAssertEqual(received[0].1["form"], "signup")
        XCTAssertEqual(received[1].0, "tap")
    }
}
