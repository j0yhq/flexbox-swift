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

    // MARK: - Event bubbling (Phase 2)

    func testNonPropagatingEventSkipsRootHandler() {
        // Factory emits with `propagates: false` — root handler must NOT
        // fire because the event did not bubble.
        let registry = ComponentRegistry()
        registry.register("silent-button") { _, events in
            events.emit("tap", payload: [:], propagates: false)
            return AnyView(EmptyView())
        }

        let payload = CSSPayload(
            css: "",
            schema: [SchemaEntry(id: "b", type: "silent-button")]
        )

        var rootFired = false
        let layout = CSSLayout(payload: payload, registry: registry)
            .onEvent("tap") { _ in rootFired = true }

        _ = layout.body
        XCTAssertFalse(rootFired)
    }

    func testPropagatingEventCarriesFlagToHandler() {
        // The `propagates` value the factory chose must be observable on the
        // delivered event so handlers can inspect it.
        let registry = ComponentRegistry()
        registry.register("bubbling-button") { _, events in
            events.emit("tap", payload: [:], propagates: true)
            return AnyView(EmptyView())
        }

        let payload = CSSPayload(
            css: "",
            schema: [SchemaEntry(id: "b", type: "bubbling-button")]
        )

        var received: CSSEvent?
        let layout = CSSLayout(payload: payload, registry: registry)
            .onEvent("tap") { event in received = event }

        _ = layout.body
        XCTAssertEqual(received?.propagates, true)
    }

    func testDefaultEmitStillBubbles() {
        // Existing factories that call `emit(name, payload:)` without passing
        // `propagates` must keep bubbling (backwards compatibility).
        let registry = ComponentRegistry()
        registry.register("legacy-button") { _, events in
            events.emit("tap", payload: [:])
            return AnyView(EmptyView())
        }

        let payload = CSSPayload(
            css: "",
            schema: [SchemaEntry(id: "b", type: "legacy-button")]
        )

        var rootFired = false
        let layout = CSSLayout(payload: payload, registry: registry)
            .onEvent("tap") { _ in rootFired = true }

        _ = layout.body
        XCTAssertTrue(rootFired)
    }

    // MARK: - Wildcard handler (Phase 2)

    func testWildcardHandlerReceivesEveryEvent() {
        let registry = ComponentRegistry()
        registry.register("multi") { _, events in
            events.emit("submit", payload: [:])
            events.emit("tap",    payload: [:])
            events.emit("change", payload: [:])
            return AnyView(EmptyView())
        }

        let payload = CSSPayload(
            css: "",
            schema: [SchemaEntry(id: "x", type: "multi")]
        )

        var seen: [String] = []
        let layout = CSSLayout(payload: payload, registry: registry)
            .onEvent("*") { event in seen.append(event.name) }

        _ = layout.body
        XCTAssertEqual(seen, ["submit", "tap", "change"])
    }

    func testWildcardFiresAlongsideNamedHandler() {
        // Named + wildcard both fire; named before wildcard.
        let registry = ComponentRegistry()
        registry.register("one") { _, events in
            events.emit("submit", payload: [:])
            return AnyView(EmptyView())
        }

        let payload = CSSPayload(
            css: "",
            schema: [SchemaEntry(id: "x", type: "one")]
        )

        var order: [String] = []
        let layout = CSSLayout(payload: payload, registry: registry)
            .onEvent("submit") { _ in order.append("named") }
            .onEvent("*")      { _ in order.append("wild")  }

        _ = layout.body
        XCTAssertEqual(order, ["named", "wild"])
    }

    func testWildcardIgnoresNonPropagatingEvents() {
        // `propagates: false` means root-level handlers (including `*`) are
        // skipped — the wildcard is a root-level convenience, not a sniffer.
        let registry = ComponentRegistry()
        registry.register("silent") { _, events in
            events.emit("tap", payload: [:], propagates: false)
            return AnyView(EmptyView())
        }

        let payload = CSSPayload(
            css: "",
            schema: [SchemaEntry(id: "x", type: "silent")]
        )

        var wildFired = false
        let layout = CSSLayout(payload: payload, registry: registry)
            .onEvent("*") { _ in wildFired = true }

        _ = layout.body
        XCTAssertFalse(wildFired)
    }

    // MARK: - Local .onCSSEvent modifier (Phase 2)

    func testLocalOnCSSEventFiresOnAncestorBubble() {
        // "child" emits a bubbling event; its ancestor "parent" is a local
        // with an `.onCSSEvent("tap")` handler — the handler must fire and
        // see the original source id.
        let registry = ComponentRegistry()
        registry.register("emitter") { _, events in
            events.emit("tap", payload: ["from": "child"])
            return AnyView(EmptyView())
        }

        let payload = CSSPayload(
            css: "",
            schema: [
                SchemaEntry(id: "parent"),
                SchemaEntry(id: "child", type: "emitter", parentID: "parent"),
            ]
        )

        var received: CSSEvent?
        let layout = CSSLayout(payload: payload, registry: registry) {
            Component("parent") { EmptyView() }
                .onCSSEvent("tap") { event in received = event }
        }

        _ = layout.body
        XCTAssertEqual(received?.name, "tap")
        XCTAssertEqual(received?.sourceID, "child")
        XCTAssertEqual(received?.payload["from"], "child")
    }

    func testLocalOnCSSEventRespectsNonPropagatingEvent() {
        // `propagates: false` means ancestor handlers are skipped — only the
        // target would fire, and the target here is a registry node with no
        // local handler, so nothing observable happens.
        let registry = ComponentRegistry()
        registry.register("emitter") { _, events in
            events.emit("tap", payload: [:], propagates: false)
            return AnyView(EmptyView())
        }

        let payload = CSSPayload(
            css: "",
            schema: [
                SchemaEntry(id: "parent"),
                SchemaEntry(id: "child", type: "emitter", parentID: "parent"),
            ]
        )

        var ancestorFired = false
        var rootFired = false
        let layout = CSSLayout(payload: payload, registry: registry) {
            Component("parent") { EmptyView() }
                .onCSSEvent("tap") { _ in ancestorFired = true }
        }
        .onEvent("tap") { _ in rootFired = true }

        _ = layout.body
        XCTAssertFalse(ancestorFired)
        XCTAssertFalse(rootFired)
    }

    func testLocalOnCSSEventBubbleReachesRootToo() {
        // Bubble must continue all the way to the root `onEvent` after any
        // intermediate `.onCSSEvent` handlers fire.
        let registry = ComponentRegistry()
        registry.register("emitter") { _, events in
            events.emit("tap", payload: [:])
            return AnyView(EmptyView())
        }

        let payload = CSSPayload(
            css: "",
            schema: [
                SchemaEntry(id: "parent"),
                SchemaEntry(id: "child", type: "emitter", parentID: "parent"),
            ]
        )

        var order: [String] = []
        let layout = CSSLayout(payload: payload, registry: registry) {
            Component("parent") { EmptyView() }
                .onCSSEvent("tap") { _ in order.append("parent") }
        }
        .onEvent("tap") { _ in order.append("root") }

        _ = layout.body
        XCTAssertEqual(order, ["parent", "root"])
    }

    func testLocalOnCSSEventOnlyFiresForMatchingName() {
        // An `.onCSSEvent("tap")` handler must ignore unrelated event names.
        let registry = ComponentRegistry()
        registry.register("emitter") { _, events in
            events.emit("change", payload: [:])
            return AnyView(EmptyView())
        }

        let payload = CSSPayload(
            css: "",
            schema: [
                SchemaEntry(id: "parent"),
                SchemaEntry(id: "child", type: "emitter", parentID: "parent"),
            ]
        )

        var tapFired = false
        let layout = CSSLayout(payload: payload, registry: registry) {
            Component("parent") { EmptyView() }
                .onCSSEvent("tap") { _ in tapFired = true }
        }

        _ = layout.body
        XCTAssertFalse(tapFired)
    }

    // MARK: - Phase 3 — FormState integration

    /// Harness: a factory that captures the `ComponentEvents` it's handed
    /// so tests can read the binding the resolver produced. Also captures
    /// the initial binding value on first render — useful to prove the
    /// factory sees live FormState data the moment it runs.
    private final class BindingCapture {
        var events: ComponentEvents?
        var initialValue: String?
    }

    private func makeBindingCaptureRegistry(
        into cap: BindingCapture,
        type: String = "text-input"
    ) -> ComponentRegistry {
        let r = ComponentRegistry()
        r.register(type) { _, events in
            cap.events = events
            cap.initialValue = events.binding("value").wrappedValue
            return AnyView(EmptyView())
        }
        return r
    }

    /// `.formState(_:)` returns a `CSSLayout` so callers can keep chaining
    /// other modifiers.
    func testFormStateModifierReturnsSelfForChaining() {
        let form = FormState()
        let base = CSSLayout(css: "")
        let chained = base
            .formState(form)
            .onEvent("submit") { _ in }
        _ = chained
    }

    /// A bound factory must see the live FormState value the first time it
    /// renders. This is the wire-up test: if `.formState(_:)` isn't
    /// threaded into `ComponentResolver.resolve(formState:)`, the binding
    /// falls back to the empty-string dead default.
    func testBoundFactorySeesFormStateValueOnFirstRender() {
        let form = FormState(values: ["user.name": "Ada"])
        let cap = BindingCapture()
        let registry = makeBindingCaptureRegistry(into: cap)
        let payload = CSSPayload(
            css: "",
            schema: [SchemaEntry(
                id: "name",
                type: "text-input",
                props: ["binding": "user.name"]
            )]
        )
        let layout = CSSLayout(payload: payload, registry: registry)
            .formState(form)
        _ = layout.body
        XCTAssertEqual(cap.initialValue, "Ada")
    }

    /// Writes through the factory's binding must reach the caller's
    /// FormState. This closes the loop: factory ↔ binding ↔ FormState.
    func testFactoryWriteThroughBindingUpdatesFormState() {
        let form = FormState(values: ["user.name": "Ada"])
        let cap = BindingCapture()
        let registry = makeBindingCaptureRegistry(into: cap)
        let payload = CSSPayload(
            css: "",
            schema: [SchemaEntry(
                id: "name",
                type: "text-input",
                props: ["binding": "user.name"]
            )]
        )
        let layout = CSSLayout(payload: payload, registry: registry)
            .formState(form)
        _ = layout.body
        cap.events!.binding("value").wrappedValue = "Grace"
        XCTAssertEqual(form.get("user.name"), "Grace")
    }

    /// Hot-swap contract: FormState outlives any single CSSLayout
    /// instance. Rendering payload A, mutating FormState, then rendering
    /// payload B (same binding path) must surface the mutated value —
    /// proving the state isn't owned by the view.
    func testHotSwapPreservesValuesAtSharedBindingPath() {
        let form = FormState(values: ["user.name": "initial"])

        // Payload A: bind to user.name via a capturing factory.
        let capA = BindingCapture()
        let registryA = makeBindingCaptureRegistry(into: capA)
        let payloadA = CSSPayload(
            css: "",
            schema: [SchemaEntry(
                id: "name",
                type: "text-input",
                props: ["binding": "user.name"]
            )]
        )
        let layoutA = CSSLayout(payload: payloadA, registry: registryA)
            .formState(form)
        _ = layoutA.body
        // User types a new value.
        capA.events!.binding("value").wrappedValue = "Ada"

        // Payload B: fresh CSSLayout, new factory capture, same path.
        let capB = BindingCapture()
        let registryB = makeBindingCaptureRegistry(into: capB)
        let payloadB = CSSPayload(
            css: "#root { gap: 8px; }",
            schema: [SchemaEntry(
                id: "name",
                type: "text-input",
                props: ["binding": "user.name"]
            )]
        )
        let layoutB = CSSLayout(payload: payloadB, registry: registryB)
            .formState(form)
        _ = layoutB.body
        XCTAssertEqual(capB.initialValue, "Ada",
                       "hot-swapping the payload must preserve FormState values")
    }

    /// Paths referenced by the previous payload but not the next one
    /// should be pruned on render — otherwise stale form data grows
    /// unbounded across repeated server fetches.
    func testOrphanedBindingPathsArePrunedOnRender() {
        let form = FormState(values: [
            "user.name":  "Ada",
            "user.email": "ada@example.com", // orphaned after swap
        ])

        // New payload only declares user.name — email is no longer bound.
        let registry = ComponentRegistry()
        registry.register("text-input") { _, _ in AnyView(EmptyView()) }
        let payload = CSSPayload(
            css: "",
            schema: [SchemaEntry(
                id: "name",
                type: "text-input",
                props: ["binding": "user.name"]
            )]
        )
        let layout = CSSLayout(payload: payload, registry: registry)
            .formState(form)
        _ = layout.body

        XCTAssertEqual(form.get("user.name"), "Ada",
                       "active path must survive prune")
        XCTAssertNil(form.get("user.email"),
                     "orphaned path must be pruned")
    }

    /// Field-scoped binding keys (`binding.<field>`) must be collected
    /// alongside the default `binding` key when computing which paths to
    /// keep — otherwise a row binding both `value` and `checked` would
    /// lose one of them on render.
    func testPruneCollectsFieldScopedBindingPaths() {
        let form = FormState(values: [
            "row.value":   "x",
            "row.checked": "yes",
            "gone":        "should-prune",
        ])
        let registry = ComponentRegistry()
        registry.register("row") { _, _ in AnyView(EmptyView()) }
        let payload = CSSPayload(
            css: "",
            schema: [SchemaEntry(
                id: "r",
                type: "row",
                props: [
                    "binding":         "row.value",
                    "binding.checked": "row.checked",
                ]
            )]
        )
        let layout = CSSLayout(payload: payload, registry: registry)
            .formState(form)
        _ = layout.body
        XCTAssertEqual(form.get("row.value"),   "x")
        XCTAssertEqual(form.get("row.checked"), "yes")
        XCTAssertNil(form.get("gone"))
    }

    /// When no FormState is wired in, CSSLayout must not crash and the
    /// factories must still see dead bindings (empty strings). This is
    /// the preview / schema-without-state path.
    func testNoFormStateKeepsBindingsDead() {
        let cap = BindingCapture()
        let registry = makeBindingCaptureRegistry(into: cap)
        let payload = CSSPayload(
            css: "",
            schema: [SchemaEntry(
                id: "name",
                type: "text-input",
                props: ["binding": "user.name"]
            )]
        )
        let layout = CSSLayout(payload: payload, registry: registry)
        _ = layout.body
        XCTAssertEqual(cap.initialValue, "")
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
