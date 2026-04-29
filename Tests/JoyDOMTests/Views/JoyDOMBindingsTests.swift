import XCTest
import SwiftUI
@testable import JoyDOM

/// Phase C1 — `JoyDOMView.bindings(_:)` is the iOS-side bridge between
/// joy-dom's "pre-resolved values" stance and JoyDOMView's live FormState.
/// The modifier records a `[node_id: form_state_path]` map; the resolver
/// consumes it at render time and synthesizes `binding` props on the
/// matching schema entries so registered factories can call
/// `events.binding("value")` exactly as before.
final class CSSLayoutBindingsTests: XCTestCase {

    // MARK: - Probe helper

    /// A reference-typed sink the registered factory writes into so the
    /// test can read the binding's wrapped value and capture its setter.
    private final class BindingProbe {
        var lastReadValue: String = ""
        var setter: ((String) -> Void)?
    }

    private func registerProbe(_ probe: BindingProbe, type: String = "probe") -> ComponentRegistry {
        let r = ComponentRegistry()
        r.register(type) { _, events in
            let binding = events.binding("value")
            probe.lastReadValue = binding.wrappedValue
            probe.setter = { binding.wrappedValue = $0 }
            return .custom { EmptyView() }
        }
        return r
    }

    // MARK: - End-to-end binding round-trip via FormState

    func testBindingMapWiresFactoryThroughToFormStatePath() {
        let form = FormState(values: ["user.name": "Ada"])
        let probe = BindingProbe()
        let registry = registerProbe(probe)

        let spec = JoyDOMSpec(layout: Node(
            type: "div",
            props: NodeProps(id: "root"),
            children: [.node(Node(type: "probe", props: NodeProps(id: "name-field")))]
        ))

        let view = JoyDOMView(spec: spec, registry: registry)
            .formState(form)
            .bindings(["name-field": "user.name"])

        // Mounting reads body once; the factory captures the setter.
        _ = view.body
        XCTAssertEqual(probe.lastReadValue, "Ada",
                       "factory should observe FormState seeded value via .bindings")

        // Writing through the captured setter updates FormState.
        probe.setter?("Grace")
        XCTAssertEqual(form.values["user.name"], "Grace",
                       "writes via events.binding must reach FormState through .bindings")
    }

    func testNodeWithoutBindingMapEntryGetsDeadBinding() {
        let form = FormState(values: ["user.name": "Ada"])
        let probe = BindingProbe()
        let registry = registerProbe(probe)

        let spec = JoyDOMSpec(layout: Node(
            type: "div",
            props: NodeProps(id: "root"),
            children: [.node(Node(type: "probe", props: NodeProps(id: "name-field")))]
        ))

        // No .bindings(...) — binding falls back to dead default.
        // FormState's prune step drops "user.name" because no schema
        // entry references it; that's expected.
        let view = JoyDOMView(spec: spec, registry: registry).formState(form)

        _ = view.body
        XCTAssertEqual(probe.lastReadValue, "",
                       "no bindings map → factory observes empty dead binding")

        // Writes go nowhere (dead binding); FormState's pruned state
        // is unaffected.
        probe.setter?("Grace")
        XCTAssertNil(form.values["user.name"],
                     "with no binding declared the path was pruned away")
    }

    func testMultipleBindingsFireToTheirRespectivePaths() {
        let form = FormState(values: ["a": "alpha", "b": "beta"])
        let pa = BindingProbe()
        let pb = BindingProbe()
        let registry = ComponentRegistry()
        registry.register("probe-a") { _, events in
            let binding = events.binding("value")
            pa.lastReadValue = binding.wrappedValue
            pa.setter = { binding.wrappedValue = $0 }
            return .custom { EmptyView() }
        }
        registry.register("probe-b") { _, events in
            let binding = events.binding("value")
            pb.lastReadValue = binding.wrappedValue
            pb.setter = { binding.wrappedValue = $0 }
            return .custom { EmptyView() }
        }

        let spec = JoyDOMSpec(layout: Node(
            type: "div",
            props: NodeProps(id: "root"),
            children: [
                .node(Node(type: "probe-a", props: NodeProps(id: "field-a"))),
                .node(Node(type: "probe-b", props: NodeProps(id: "field-b"))),
            ]
        ))
        let view = JoyDOMView(spec: spec, registry: registry)
            .formState(form)
            .bindings(["field-a": "a", "field-b": "b"])

        _ = view.body
        XCTAssertEqual(pa.lastReadValue, "alpha")
        XCTAssertEqual(pb.lastReadValue, "beta")
    }

    func testBindingsMergeOnRepeatedModifierCalls() {
        let form = FormState(values: ["a": "alpha", "b": "beta"])
        let pa = BindingProbe()
        let pb = BindingProbe()
        let registry = ComponentRegistry()
        registry.register("probe-a") { _, events in
            pa.lastReadValue = events.binding("value").wrappedValue
            return .custom { EmptyView() }
        }
        registry.register("probe-b") { _, events in
            pb.lastReadValue = events.binding("value").wrappedValue
            return .custom { EmptyView() }
        }

        let spec = JoyDOMSpec(layout: Node(type: "div", props: NodeProps(id: "root"), children: [
            .node(Node(type: "probe-a", props: NodeProps(id: "field-a"))),
            .node(Node(type: "probe-b", props: NodeProps(id: "field-b"))),
        ]))

        // Two .bindings calls — the maps merge across calls.
        let view = JoyDOMView(spec: spec, registry: registry)
            .formState(form)
            .bindings(["field-a": "a"])
            .bindings(["field-b": "b"])

        _ = view.body
        XCTAssertEqual(pa.lastReadValue, "alpha")
        XCTAssertEqual(pb.lastReadValue, "beta")
    }

    func testLaterBindingsCallOverridesEarlierForSameKey() {
        let form = FormState(values: ["x": "first", "y": "second"])
        let probe = BindingProbe()
        let registry = registerProbe(probe)

        let spec = JoyDOMSpec(layout: Node(type: "div", props: NodeProps(id: "root"), children: [
            .node(Node(type: "probe", props: NodeProps(id: "field")))
        ]))

        let view = JoyDOMView(spec: spec, registry: registry)
            .formState(form)
            .bindings(["field": "x"])
            .bindings(["field": "y"])

        _ = view.body
        XCTAssertEqual(probe.lastReadValue, "second")
    }

    func testBindingsMapEntryForUnknownIDIsIgnored() {
        // Wiring a binding to an id that doesn't exist in the schema
        // shouldn't crash or warn — just no-op.
        let form = FormState(values: ["x": "v"])
        let probe = BindingProbe()
        let registry = registerProbe(probe)

        let spec = JoyDOMSpec(layout: Node(type: "div", props: NodeProps(id: "root"), children: [
            .node(Node(type: "probe", props: NodeProps(id: "field")))
        ]))

        // "nonexistent-id" doesn't match any schema entry; "field"
        // doesn't have a binding. Neither should crash.
        let view = JoyDOMView(spec: spec, registry: registry)
            .formState(form)
            .bindings(["nonexistent-id": "x"])

        _ = view.body
        XCTAssertEqual(probe.lastReadValue, "",
                       "field with no matching binding gets dead binding")
    }
}
