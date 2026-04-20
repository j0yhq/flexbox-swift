import XCTest
import SwiftUI
@testable import CSSLayout
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
        schemaType: String? = nil
    ) -> StyleNode {
        StyleNode(
            id: id,
            parentID: parentID,
            schemaType: schemaType,
            computedStyle: ComputedStyle()
        )
    }

    private func rootNode() -> StyleNode {
        StyleNode(id: "root", schemaType: nil, computedStyle: ComputedStyle())
    }

    private func resolve(
        nodes: [StyleNode],
        locals: [Component] = [],
        registry: ComponentRegistry = ComponentRegistry()
    ) -> (result: ComponentResolver.Resolved, diagnostics: CSSDiagnostics) {
        var diags = CSSDiagnostics()
        let result = ComponentResolver.resolve(
            nodes: nodes,
            locals: locals,
            registry: registry,
            placeholder: { _ in AnyView(EmptyView()) },
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
            .register("button") { _, _ in AnyView(Text("registry")) }
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
            .register("button") { _, _ in AnyView(Text("registry")) }
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
    /// `FlexLayout` emitted by `CSSLayout.body`.
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
            .register("box") { _, _ in AnyView(Text("dropped")) }
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
            .register("button") { _, _ in AnyView(Text("should not render")) }
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
}
