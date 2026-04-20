import XCTest
import SwiftUI
@testable import CSSLayout
import FlexLayout

/// Unit (l) — `CSSLayout` is the top-level SwiftUI view that assembles every
/// earlier unit. The tests here cover the *wiring*: initialisers, builder
/// modifiers, and the event pipeline. Layout-geometry correctness is left
/// to the fixture suite.
final class CSSLayoutIntegrationTests: XCTestCase {

    // MARK: - Construction

    func testInitWithPayload() {
        let payload = CSSPayload(
            css: "#root { display: flex; } #a { flex: 1; }",
            schema: [SchemaEntry(id: "a", type: "text")]
        )
        _ = CSSLayout(payload: payload) {
            Component("a") { EmptyView() }
        }
    }

    func testInitWithCSSOnly() {
        // Empty schema + empty locals is a valid (degenerate) construction —
        // useful for previews that just want to see the container.
        _ = CSSLayout(css: "#root { display: flex; }")
    }

    func testMalformedCSSDoesNotCrash() {
        // Adversarial input; must not throw.
        _ = CSSLayout(css: "#a {{{{ garbage")
    }

    // MARK: - Modifier chain

    func testOnEventReturnsSelfForChaining() {
        let base = CSSLayout(css: "")
        let chained = base
            .onEvent("submit") { _ in }
            .onEvent("tap")    { _ in }
        // Type-checks are the assertion; if `onEvent` regresses to returning
        // `some View`, this stops compiling.
        _ = chained
    }

    func testPlaceholderModifierReturnsSelfForChaining() {
        let base = CSSLayout(css: "")
        let chained = base.placeholder { _ in AnyView(EmptyView()) }
        _ = chained
    }

    // MARK: - Event pipeline

    func testSubmitEventReachesRootHandler() {
        // A factory that immediately calls `events.emit("submit")` lets us
        // verify the root `onEvent("submit")` handler fires.
        let registry = ComponentRegistry()
        registry.register("auto-button") { _, events in
            events.emit("submit", payload: ["form": "signup"])
            return AnyView(EmptyView())
        }

        let payload = CSSPayload(
            css: "",
            schema: [SchemaEntry(id: "submit", type: "auto-button")]
        )

        var received: CSSEvent?
        let layout = CSSLayout(payload: payload, registry: registry)
            .onEvent("submit") { event in received = event }

        // Building the body triggers child resolution, which invokes the
        // factory, which emits the event. We don't need to render, just
        // touch `body` once.
        _ = layout.body

        XCTAssertNotNil(received)
        XCTAssertEqual(received?.name, "submit")
        XCTAssertEqual(received?.sourceID, "submit")
        XCTAssertEqual(received?.payload["form"], "signup")
    }

    func testEventsForUnregisteredNamesAreSilentlyIgnored() {
        let registry = ComponentRegistry()
        registry.register("auto-button") { _, events in
            events.emit("change", payload: [:])
            return AnyView(EmptyView())
        }

        let payload = CSSPayload(
            css: "",
            schema: [SchemaEntry(id: "x", type: "auto-button")]
        )

        var submitFired = false
        let layout = CSSLayout(payload: payload, registry: registry)
            .onEvent("submit") { _ in submitFired = true }

        _ = layout.body
        XCTAssertFalse(submitFired)
    }

    // MARK: - Diagnostics hook

    func testOnDiagnosticReceivesWarnings() {
        var diags: [CSSWarning] = []
        let layout = CSSLayout(
            css: "#a { margin: 8px; }"
        )
        .onDiagnostic { w in diags.append(w) }

        _ = layout.body
        XCTAssertTrue(diags.contains { $0.kind == .unsupportedProperty("margin") })
    }
}
