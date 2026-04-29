import XCTest
import SwiftUI
@testable import JoyDOM
import FlexLayout

/// Unit (k) — `ComponentResolver` picks the right view source per node.
///
/// Priority per node: `locals[id]` > `registry[schema[id].type]` > placeholder.
/// Tests assert on the emitted `Resolution` tag and the id stream, never on
/// actual SwiftUI view identity (which is opaque).
final class ComponentResolverTests: XCTestCase {

    // MARK: - Fixtures

    private func styleNode(
        id: String,
        parentID: String? = nil,
        schemaType: String? = nil,
        props: [String: String] = [:]
    ) -> StyleNode {
        StyleNode(
            id: id,
            parentID: parentID,
            schemaType: schemaType,
            props: props,
            computedStyle: ComputedStyle()
        )
    }

    private func rootNode() -> StyleNode {
        StyleNode(id: "root", schemaType: nil, computedStyle: ComputedStyle())
    }

    private func resolve(
        nodes: [StyleNode],
        locals: [Component] = [],
        registry: ComponentRegistry = ComponentRegistry(),
        formState: FormState? = nil,
        valueStore: ValueStore? = nil
    ) -> (result: ComponentResolver.Resolved, diagnostics: JoyDiagnostics) {
        var diags = JoyDiagnostics()
        let result = ComponentResolver.resolve(
            nodes: nodes,
            locals: locals,
            registry: registry,
            placeholder: { _ in AnyView(EmptyView()) },
            formState: formState,
            valueStore: valueStore,
            diagnostics: &diags
        )
        return (result, diags)
    }

    // MARK: - Structure

    func testRootIsFirstNodeAndChildrenFollow() {
        let (res, _) = resolve(nodes: [
            rootNode(),
            styleNode(id: "a"),
            styleNode(id: "b"),
        ])
        XCTAssertEqual(res.children.map(\.id), ["a", "b"])
    }

    func testEmptySchemaProducesNoChildren() {
        let (res, _) = resolve(nodes: [rootNode()])
        XCTAssertEqual(res.children.count, 0)
    }

    // MARK: - Priority

    func testLocalComponentWinsOverRegistry() {
        let registry = ComponentRegistry()
            .register("button") { _, _ in .custom { Text("registry") } }
        let locals = [Component("submit") { Text("local") }]
        let (res, _) = resolve(
            nodes: [rootNode(), styleNode(id: "submit", schemaType: "button")],
            locals: locals,
            registry: registry
        )
        XCTAssertEqual(res.children.first?.resolution, .local)
    }

    func testFallsBackToRegistry() {
        let registry = ComponentRegistry()
            .register("button") { _, _ in .custom { Text("registry") } }
        let (res, _) = resolve(
            nodes: [rootNode(), styleNode(id: "submit", schemaType: "button")],
            registry: registry
        )
        XCTAssertEqual(res.children.first?.resolution, .registry)
    }

    func testUnknownIDFiresPlaceholder() {
        // No locals, no schemaType — nothing can match → placeholder.
        let (res, _) = resolve(
            nodes: [rootNode(), styleNode(id: "mystery")]
        )
        XCTAssertEqual(res.children.first?.resolution, .placeholder)
    }

    func testUnregisteredSchemaTypeFiresPlaceholderPlusDiagnostic() {
        // schemaType is set but the registry doesn't know it. We still fall
        // back to placeholder AND emit a diagnostic so the caller can catch
        // typos at runtime.
        let (res, diags) = resolve(
            nodes: [rootNode(), styleNode(id: "x", schemaType: "widget")]
        )
        XCTAssertEqual(res.children.first?.resolution, .placeholder)
        XCTAssertEqual(diags.count(of: .other), 1)
        XCTAssertTrue(diags.warnings.contains {
            if case .other = $0.kind { return $0.detail.contains("widget") }
            return false
        })
    }

    // MARK: - Tier 2: ComponentBody + ValueStore plumb-through

    /// A factory registered through the (now unified) ComponentFactory
    /// surface runs through the resolver and surfaces as `.registry`.
    /// The returned view is materialised via `ComponentBody.makeView()`
    /// under the hood.
    func testResolverInvokesBodyFactory() {
        var calls = 0
        let registry = ComponentRegistry()
        registry.register("card") { _, _ -> ComponentBody in
            calls += 1
            return .custom { EmptyView() }
        }
        let (res, _) = resolve(
            nodes: [rootNode(), styleNode(id: "hero", schemaType: "card")],
            registry: registry
        )
        XCTAssertEqual(res.children.first?.resolution, .registry)
        XCTAssertEqual(calls, 1, "body factory must fire exactly once per resolve")
    }

    /// When a `ValueStore` is handed to the resolver it must be woven
    /// into every factory's `ComponentEvents`, so the factory's
    /// `setValue` calls route through to the injected store.
    func testResolverThreadsValueStoreIntoComponentEvents() {
        final class CaptureStore {
            var writes: [(field: String, value: String)] = []
        }
        let store = CaptureStore()
        let valueStore = ValueStore(
            get: { _ in nil },
            set: { value, field in store.writes.append((field, value)) },
            observe: { _, _ in NoopCancellableStub() }
        )
        let registry = ComponentRegistry()
        registry.register("input") { _, events -> ComponentBody in
            events.setValue("hello", for: "name")
            return .custom { EmptyView() }
        }
        _ = resolve(
            nodes: [rootNode(), styleNode(id: "n", schemaType: "input")],
            registry: registry,
            valueStore: valueStore
        )
        XCTAssertEqual(store.writes.count, 1)
        XCTAssertEqual(store.writes.first?.field, "name")
        XCTAssertEqual(store.writes.first?.value, "hello")
    }

    // MARK: - Root style propagation

    func testRootStyleIsReturned() {
        var rootStyle = ComputedStyle()
        rootStyle.container.direction = .column
        rootStyle.container.gap = 16
        let (res, _) = resolve(
            nodes: [
                StyleNode(id: "root", schemaType: nil, computedStyle: rootStyle),
                styleNode(id: "a"),
            ]
        )
        XCTAssertEqual(res.rootStyle.container.direction, .column)
        XCTAssertEqual(res.rootStyle.container.gap, 16)
    }

    // MARK: - Item-style forwarding

    func testChildrenCarryTheirComputedItemStyle() {
        var aStyle = ComputedStyle()
        aStyle.item.grow = 2
        let (res, _) = resolve(
            nodes: [
                rootNode(),
                StyleNode(id: "a", schemaType: nil, computedStyle: aStyle),
            ]
        )
        XCTAssertEqual(res.children.first?.itemStyle.grow, 2)
    }

    // MARK: - Duplicate-id tolerance (robustness)

    func testDuplicateLocalIDsDoNotCrashAndLastWins() {
        // Author mistake: two `Component("a")` in the locals block. We want
        // graceful handling — last declaration wins, no trap.
        var marker = 0
        let locals: [Component] = [
            Component("a") { Color.red },
            Component("a") { Color.blue },
        ]
        _ = locals  // silence "unused" when not exercised directly

        let (res, diags) = resolve(
            nodes: [rootNode(), styleNode(id: "a")],
            locals: locals
        )
        marker += res.children.count
        XCTAssertEqual(marker, 1, "one resolved child despite duplicate locals")
        XCTAssertEqual(res.children.first?.resolution, .local)
        // A diagnostic should surface so the author notices.
        XCTAssertTrue(diags.warnings.contains { $0.kind == .duplicateLocalID("a") })
    }

    // MARK: - Hierarchical assembly (Phase 2 render-tree shape)

    /// A node with schema descendants becomes a container: its `nested`
    /// slot is populated and `isContainer` flips true. Leaves underneath
    /// stay flat. This is the structural precondition for the nested
    /// `FlexLayout` emitted by `JoyDOMView.body`.
    func testContainerNodeExposesNestedChildren() {
        let (res, _) = resolve(nodes: [
            rootNode(),
            styleNode(id: "row"),
            styleNode(id: "a", parentID: "row"),
            styleNode(id: "b", parentID: "row"),
        ])
        XCTAssertEqual(res.children.map(\.id), ["row"])
        let row = res.children[0]
        XCTAssertTrue(row.isContainer)
        XCTAssertEqual(row.nested.map(\.id), ["a", "b"])
        XCTAssertTrue(row.nested.allSatisfy { !$0.isContainer })
    }

    /// When a container node has a factory/local, the schema wins and the
    /// factory view is dropped with an `.other` diagnostic so the author
    /// notices rather than silently losing the view.
    func testContainerWithFactoryDropsViewWithDiagnostic() {
        let registry = ComponentRegistry()
            .register("box") { _, _ in .custom { Text("dropped") } }
        let (res, diags) = resolve(
            nodes: [
                rootNode(),
                styleNode(id: "row", schemaType: "box"),
                styleNode(id: "a", parentID: "row"),
            ],
            registry: registry
        )
        XCTAssertTrue(res.children[0].isContainer)
        XCTAssertEqual(res.children[0].resolution, .registry)
        XCTAssertTrue(
            diags.warnings.contains {
                if case .other = $0.kind {
                    return $0.detail.contains("'row'") && $0.detail.contains("schema children")
                }
                return false
            },
            "expected diagnostic about container 'row' dropping its factory view"
        )
    }

    // MARK: - `display: none` subtree removal

    private func hiddenStyle() -> ComputedStyle {
        var s = ComputedStyle()
        s.isDisplayNone = true
        return s
    }

    /// A flagged node is removed entirely: it does not appear as a child,
    /// no factory runs, and no placeholder is emitted.
    func testDisplayNoneNodeIsFiltered() {
        let registry = ComponentRegistry()
            .register("button") { _, _ in .custom { Text("should not render") } }
        let hidden = StyleNode(id: "a", schemaType: "button", computedStyle: hiddenStyle())
        let (res, _) = resolve(
            nodes: [rootNode(), hidden, styleNode(id: "b")],
            registry: registry
        )
        XCTAssertEqual(res.children.map(\.id), ["b"])
    }

    /// Unlike `display: none`, `visibility: hidden` keeps the node in
    /// the layout — it reserves space, only its paint is suppressed.
    /// The resolver therefore must NOT filter it out, and the flag must
    /// reach `ResolvedChild` so the render layer can apply `.hidden()`.
    private func hiddenVisibilityStyle() -> ComputedStyle {
        var s = ComputedStyle()
        s.isVisibilityHidden = true
        return s
    }

    func testVisibilityHiddenNodeIsPreservedInTree() {
        let node = StyleNode(id: "a", schemaType: nil,
                             computedStyle: hiddenVisibilityStyle())
        let (res, _) = resolve(nodes: [rootNode(), node, styleNode(id: "b")])
        XCTAssertEqual(res.children.map(\.id), ["a", "b"],
                       "visibility:hidden nodes keep their layout slot")
        XCTAssertTrue(res.children[0].isVisibilityHidden)
    }

    func testVisibilityHiddenDoesNotRemoveDescendants() {
        let hiddenParent = StyleNode(id: "row", schemaType: nil,
                                     computedStyle: hiddenVisibilityStyle())
        let (res, _) = resolve(nodes: [
            rootNode(),
            hiddenParent,
            styleNode(id: "a", parentID: "row"),
        ])
        XCTAssertEqual(res.children.map(\.id), ["row"])
        XCTAssertEqual(res.children[0].nested.map(\.id), ["a"],
                       "visibility:hidden must NOT prune descendants (CSS §11.2)")
    }

    /// CSS `display: none` removes the node's whole subtree, not just the
    /// node itself — children of a hidden node must not render either.
    func testDisplayNoneRemovesDescendantSubtree() {
        let hidden = StyleNode(id: "row", schemaType: nil, computedStyle: hiddenStyle())
        let (res, _) = resolve(nodes: [
            rootNode(),
            hidden,
            styleNode(id: "a", parentID: "row"),
            styleNode(id: "b", parentID: "row"),
            styleNode(id: "c"),
        ])
        XCTAssertEqual(res.children.map(\.id), ["c"],
                       "hidden row + its descendants a,b must all be filtered")
    }

    /// Deeper nesting must round-trip: grandchildren surface as nested
    /// inside their parent container (which is itself nested inside root).
    func testThreeLevelHierarchyAssembles() {
        let (res, _) = resolve(nodes: [
            rootNode(),
            styleNode(id: "outer"),
            styleNode(id: "inner", parentID: "outer"),
            styleNode(id: "leaf", parentID: "inner"),
        ])
        XCTAssertEqual(res.children.map(\.id), ["outer"])
        XCTAssertEqual(res.children[0].nested.map(\.id), ["inner"])
        XCTAssertEqual(res.children[0].nested[0].nested.map(\.id), ["leaf"])
    }

    // MARK: - Phase 3 — schema props reach the factory

    /// Factories need the server-sent prop bag (placeholder text, labels,
    /// binding paths). The resolver must thread `StyleNode.props` into
    /// `ComponentProps.values` so `props.string("placeholder")` inside the
    /// factory sees what the schema declared.
    func testSchemaPropsAreForwardedToFactory() {
        final class PropsCapture { var seen: [String: String] = [:] }
        let captured = PropsCapture()
        let registry = ComponentRegistry()
            .register("text-input") { props, _ in
                captured.seen = props.values
                return .custom { EmptyView() }
            }
        _ = resolve(
            nodes: [
                rootNode(),
                styleNode(id: "name",
                          schemaType: "text-input",
                          props: ["placeholder": "Full name",
                                  "binding": "user.name"]),
            ],
            registry: registry
        )
        XCTAssertEqual(captured.seen["placeholder"], "Full name")
        XCTAssertEqual(captured.seen["binding"], "user.name")
    }

    /// Props with no registered factory are irrelevant (placeholder
    /// branch) but must not crash. Sanity-check the fallback path.
    func testPropsAreIgnoredOnPlaceholderPath() {
        let (res, _) = resolve(nodes: [
            rootNode(),
            styleNode(id: "mystery", props: ["anything": "ok"]),
        ])
        XCTAssertEqual(res.children.first?.resolution, .placeholder)
    }

    // MARK: - Phase 3 — FormState-backed bindings

    /// Harness that registers a capturing factory and returns the
    /// `ComponentEvents` handed to it, so a test can exercise
    /// `events.binding(_:)` directly.
    private final class BindingProbe {
        var events: ComponentEvents?
    }

    private func resolveWithBindingProbe(
        nodes: [StyleNode],
        formState: FormState?,
        type: String = "text-input"
    ) -> BindingProbe {
        let probe = BindingProbe()
        let registry = ComponentRegistry()
            .register(type) { _, events in
                probe.events = events
                return .custom { EmptyView() }
            }
        _ = resolve(nodes: nodes, registry: registry, formState: formState)
        return probe
    }

    /// With no FormState wired in, every binding must be dead — the
    /// factory can still call `events.binding("value")` safely but it
    /// resolves to the empty-string default.
    func testBindingIsDeadWhenNoFormStateProvided() {
        let probe = resolveWithBindingProbe(
            nodes: [
                rootNode(),
                styleNode(id: "name", schemaType: "text-input",
                          props: ["binding": "user.name"]),
            ],
            formState: nil
        )
        XCTAssertEqual(probe.events?.binding("value").wrappedValue, "")
    }

    /// A schema that declares `"binding": "user.name"` must produce a
    /// binding that reads from (and writes to) `FormState` at that path.
    func testBindingResolvesPathFromSchemaToFormState() {
        let form = FormState(values: ["user.name": "Ada"])
        let probe = resolveWithBindingProbe(
            nodes: [
                rootNode(),
                styleNode(id: "name", schemaType: "text-input",
                          props: ["binding": "user.name"]),
            ],
            formState: form
        )
        let b = probe.events!.binding("value")
        XCTAssertEqual(b.wrappedValue, "Ada")
        b.wrappedValue = "Grace"
        XCTAssertEqual(form.get("user.name"), "Grace")
    }

    /// Components with multiple bound fields can scope the path per
    /// field via `"binding.<field>"` (e.g. a form row that binds both
    /// `value` and `checked`). The field-scoped key wins over the
    /// default `"binding"` key.
    func testFieldScopedBindingOverridesDefaultBinding() {
        let form = FormState(values: [
            "default.path": "should-not-read",
            "user.agreed": "yes",
        ])
        let probe = resolveWithBindingProbe(
            nodes: [
                rootNode(),
                styleNode(id: "row", schemaType: "text-input",
                          props: [
                            "binding":          "default.path",
                            "binding.checked":  "user.agreed",
                          ]),
            ],
            formState: form
        )
        XCTAssertEqual(probe.events?.binding("checked").wrappedValue, "yes")
        // Field without a scoped override still falls back to the
        // default binding key.
        XCTAssertEqual(probe.events?.binding("value").wrappedValue,
                       "should-not-read")
    }

    /// If the schema declares neither a default nor a field-scoped
    /// binding, the factory gets a dead binding — never a crash.
    func testBindingForFieldWithoutPathReturnsDeadBinding() {
        let form = FormState()
        let probe = resolveWithBindingProbe(
            nodes: [
                rootNode(),
                styleNode(id: "name", schemaType: "text-input", props: [:]),
            ],
            formState: form
        )
        XCTAssertEqual(probe.events?.binding("value").wrappedValue, "")
    }
}

// MARK: - Test doubles

/// Minimal `Cancellable` for use inside `ValueStore` fakes — the
/// resolver tests never exercise cancellation so a pure no-op is
/// enough.
private final class NoopCancellableStub: Cancellable {
    func cancel() {}
}
