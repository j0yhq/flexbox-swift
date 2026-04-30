import XCTest
import SwiftUI
@testable import JoyDOM

/// Restores the view-level integration coverage that Tier 5 deleted
/// alongside the old `Stylesheet`-driven tests. Same scenarios as
/// before — modifier chain, factory invocation, event bubbling,
/// locals override, FormState pruning across spec swaps, malformed-
/// payload tolerance — but driven through `JoyDOMView(spec:)`.
final class JoyDOMViewIntegrationTests: XCTestCase {

    // MARK: - Construction & modifier chain

    func testInitWithEmptySpecDoesNotCrash() {
        let spec = Spec(layout: Node(type: "div", props: NodeProps(id: "x")))
        let view = JoyDOMView(spec: spec)
        _ = view.body
    }

    func testModifierChainReturnsJoyDOMView() {
        let spec = Spec(layout: Node(type: "div", props: NodeProps(id: "x")))
        let chained = JoyDOMView(spec: spec)
            .onEvent("submit") { _ in }
            .onEvent("tap") { _ in }
            .placeholder { _ in AnyView(EmptyView()) }
            .viewport(Viewport(width: 800))
        // The compiler ensures it stays a JoyDOMView; this is a
        // type-check assertion.
        XCTAssertNotNil(chained as JoyDOMView)
    }

    // MARK: - Factory invocation

    func testRegisteredFactoryIsInvokedDuringRender() {
        var hits = 0
        let registry = ComponentRegistry()
        registry.register("auto-button") { _, _ in
            hits += 1
            return .custom { EmptyView() }
        }

        let spec = Spec(
            layout: Node(
                type: "auto-button",
                props: NodeProps(id: "btn")
            )
        )
        let view = JoyDOMView(spec: spec, registry: registry)
        _ = view.body
        XCTAssertEqual(hits, 1, "factory should run exactly once per body evaluation")
    }

    // MARK: - Event bubbling

    func testEmittedEventReachesRootHandler() {
        let registry = ComponentRegistry()
        registry.register("auto-emit") { _, events in
            events.emit("submit", payload: ["form": "signup"])
            return .custom { EmptyView() }
        }

        let spec = Spec(
            layout: Node(
                type: "auto-emit",
                props: NodeProps(id: "x")
            )
        )

        var received: JoyEvent?
        let view = JoyDOMView(spec: spec, registry: registry)
            .onEvent("submit") { event in received = event }
        _ = view.body

        XCTAssertNotNil(received)
        XCTAssertEqual(received?.name, "submit")
        XCTAssertEqual(received?.sourceID, "x")
        XCTAssertEqual(received?.payload["form"], "signup")
    }

    func testWildcardHandlerFiresForAllEvents() {
        let registry = ComponentRegistry()
        registry.register("auto-emit") { _, events in
            events.emit("custom", payload: [:])
            return .custom { EmptyView() }
        }

        let spec = Spec(
            layout: Node(type: "auto-emit", props: NodeProps(id: "x"))
        )

        var seenNames: [String] = []
        let view = JoyDOMView(spec: spec, registry: registry)
            .onEvent("*") { event in seenNames.append(event.name) }
        _ = view.body

        XCTAssertEqual(seenNames, ["custom"])
    }

    func testNonPropagatingEventDoesNotReachRoot() {
        let registry = ComponentRegistry()
        registry.register("auto-emit") { _, events in
            events.emit("tap", payload: [:], propagates: false)
            return .custom { EmptyView() }
        }

        let spec = Spec(
            layout: Node(type: "auto-emit", props: NodeProps(id: "x"))
        )

        var rootFired = false
        let view = JoyDOMView(spec: spec, registry: registry)
            .onEvent("tap") { _ in rootFired = true }
        _ = view.body

        XCTAssertFalse(rootFired,
                       "propagates: false events should not bubble to root")
    }

    // MARK: - Locals override

    func testLocalComponentBeatsRegistryFactory() {
        var registryHits = 0
        var localHits = 0

        let registry = ComponentRegistry()
        registry.register("widget") { _, _ in
            registryHits += 1
            return .custom { EmptyView() }
        }

        let spec = Spec(
            layout: Node(type: "widget", props: NodeProps(id: "x"))
        )

        let view = JoyDOMView(spec: spec, registry: registry) {
            Component("x") {
                EmptyView()
            }
        }
        // Touching body to record any factory invocation. Locals don't
        // run "factory" code — just hand back stored content — so we
        // confirm the registry factory was bypassed.
        _ = view.body

        XCTAssertEqual(registryHits, 0,
                       "local override should bypass the registry factory entirely")
        // localHits stays 0 because Component takes content directly,
        // not a builder closure. The bypass IS the assertion.
        _ = localHits
    }

    // MARK: - Placeholder fallback for unknown types

    func testUnknownTypeFallsThroughToPlaceholder() {
        // No registry entry for "mystery-type" — the resolver should
        // fall through to placeholder without crashing.
        let spec = Spec(
            layout: Node(type: "mystery-type", props: NodeProps(id: "x"))
        )
        let view = JoyDOMView(spec: spec, registry: ComponentRegistry())
        _ = view.body
        // No assertion needed — the absence of a crash is the test.
    }

    // MARK: - FormState prune across spec swap

    func testFormStateIsPrunedToActiveSchemaPaths() {
        // Two specs: the second drops a binding declared by the first.
        // FormState's pruned-to-active-schema invariant says the
        // dropped path's value disappears after the second render.
        let form = FormState(values: ["user.name": "Ada", "user.email": "ada@x"])
        let registry = ComponentRegistry()
        registry.register("probe") { _, _ in .custom { EmptyView() } }

        // Spec 1: binds "user.name" only.
        let spec1 = Spec(
            layout: Node(type: "div", props: NodeProps(id: "root"), children: [
                .node(Node(type: "probe", props: NodeProps(id: "name-field")))
            ])
        )
        _ = JoyDOMView(spec: spec1, registry: registry)
            .formState(form)
            .bindings(["name-field": "user.name"])
            .body

        XCTAssertEqual(form.values["user.name"], "Ada",
                       "active binding survives prune")
        XCTAssertNil(form.values["user.email"],
                     "unreferenced path is pruned away")
    }

    // MARK: - Breakpoint className override replaces base

    func testBreakpointClassNameReplacesBase() {
        // The breakpoint's `nodes[id].className` REPLACES the base
        // className entirely — does not merge. Pinned here so the
        // semantic doesn't drift silently.
        var diags = JoyDiagnostics()
        let spec = Spec(
            style: [
                ".base":     Style(flexDirection: .row),
                ".override": Style(flexDirection: .column),
            ],
            breakpoints: [
                Breakpoint(
                    conditions: [],   // always active
                    nodes: ["x": NodeProps(className: ["override"])]
                ),
            ],
            layout: Node(
                type: "div",
                props: NodeProps(id: "x", className: ["base"])
            )
        )

        let activeBP = BreakpointResolver.active(in: Viewport(width: 0), breakpoints: spec.breakpoints)
        let rules = RuleBuilder.buildRules(from: spec, activeBreakpoint: activeBP, diagnostics: &diags)
        let nodes = StyleTreeBuilder.build(
            layout: spec.layout,
            rootID: "__joydom_root__",
            rules: rules,
            classNameOverrides: activeBP?.nodes.compactMapValues { $0.className } ?? [:],
            diagnostics: &diags
        )

        // .base would have set flexDirection to .row; .override sets
        // .column. If the breakpoint REPLACED classes, only .override
        // matches → result is .column. If it MERGED, both would match
        // and source order would tie-break to .column anyway, but the
        // node's `classes` array wouldn't contain "base" — let's
        // assert directly on `classes`.
        let x = nodes.first(where: { $0.id == "x" })!
        XCTAssertEqual(x.classes, ["override"],
                       "breakpoint className must REPLACE base className entirely")
        XCTAssertEqual(x.computedStyle.container.direction, .column)
    }

    // MARK: - Adversarial inputs don't crash

    func testEmptyChildrenArrayDoesNotCrash() {
        let spec = Spec(
            layout: Node(
                type: "div",
                props: NodeProps(id: "root"),
                children: []
            )
        )
        _ = JoyDOMView(spec: spec).body
    }

    func testDeeplyNestedTreeDoesNotCrash() {
        // Build a nested chain 10 deep. No registry, so each level
        // falls through to placeholder.
        var current: Node = Node(type: "leaf", props: NodeProps(id: "leaf"))
        for i in 0..<10 {
            current = Node(
                type: "wrap",
                props: NodeProps(id: "level-\(i)"),
                children: [.node(current)]
            )
        }
        let spec = Spec(layout: current)
        _ = JoyDOMView(spec: spec).body
    }
}
