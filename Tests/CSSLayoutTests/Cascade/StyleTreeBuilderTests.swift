import XCTest
@testable import CSSLayout
import FlexLayout

/// Unit (g) — `StyleTreeBuilder` assembles a flat "root + children" tree of
/// `StyleNode` values from a `Stylesheet` and a `SchemaEntry` map.
///
/// Phase 1 keeps the tree flat: one implicit root (id = `"root"` by default)
/// plus every schema entry as a sibling child. Combinators and hierarchical
/// CSS selectors are Phase 2.
final class StyleTreeBuilderTests: XCTestCase {

    // MARK: - Helpers

    private func build(
        css: String,
        schema: [(String, String)] = [],
        rootID: String = "root"
    ) -> ([StyleNode], CSSDiagnostics) {
        var diags = CSSDiagnostics()
        let sheet = CSSParser.parse(css, diagnostics: &diags)
        // Preserve insertion order — tests need deterministic ordering.
        let schemaEntries = schema.map { SchemaEntry(id: $0.0, type: $0.1) }
        let nodes = StyleTreeBuilder.build(
            rootID: rootID,
            schema: schemaEntries,
            stylesheet: sheet,
            diagnostics: &diags
        )
        return (nodes, diags)
    }

    // MARK: - Structure

    func testBuildsRootPlusChildrenFromSchema() {
        let (nodes, _) = build(
            css: "",
            schema: [("a", "text"), ("b", "button"), ("c", "text")]
        )
        XCTAssertEqual(nodes.map(\.id), ["root", "a", "b", "c"])
    }

    func testRootHasNilSchemaType() {
        let (nodes, _) = build(css: "", schema: [("a", "text")])
        XCTAssertNil(nodes[0].schemaType)
        XCTAssertEqual(nodes[0].id, "root")
    }

    func testChildrenCarrySchemaType() {
        let (nodes, _) = build(
            css: "",
            schema: [("a", "text-input"), ("b", "button")]
        )
        XCTAssertEqual(nodes[1].schemaType, "text-input")
        XCTAssertEqual(nodes[2].schemaType, "button")
    }

    func testEmptySchemaProducesOnlyRoot() {
        let (nodes, _) = build(css: "", schema: [])
        XCTAssertEqual(nodes.count, 1)
        XCTAssertEqual(nodes[0].id, "root")
    }

    func testRootIDIsConfigurable() {
        let (nodes, _) = build(
            css: "",
            schema: [("a", "text")],
            rootID: "form"
        )
        XCTAssertEqual(nodes[0].id, "form")
    }

    // MARK: - Cascade integration

    func testRootTakesStyleFromRootIDSelector() {
        let (nodes, _) = build(
            css: "#root { display: flex; flex-direction: column; gap: 12px; }",
            schema: [("a", "text")]
        )
        XCTAssertEqual(nodes[0].id, "root")
        XCTAssertEqual(nodes[0].computedStyle.container.direction, .column)
        XCTAssertEqual(nodes[0].computedStyle.container.gap, 12)
    }

    func testChildTakesStyleFromIDSelector() {
        let (nodes, _) = build(
            css: "#a { flex-grow: 2; }",
            schema: [("a", "text"), ("b", "text")]
        )
        XCTAssertEqual(nodes[1].computedStyle.item.grow, 2)
        XCTAssertEqual(nodes[2].computedStyle.item.grow, 0)  // default
    }

    func testChildTakesStyleFromElementSelector() {
        let (nodes, _) = build(
            css: "button { flex-grow: 3; }",
            schema: [("a", "text"), ("submit", "button")]
        )
        XCTAssertEqual(nodes[1].computedStyle.item.grow, 0)
        XCTAssertEqual(nodes[2].computedStyle.item.grow, 3)
    }

    func testIDSelectorWinsOverElementSelector() {
        let (nodes, _) = build(
            css: "button { flex-grow: 1; } #submit { flex-grow: 9; }",
            schema: [("submit", "button")]
        )
        XCTAssertEqual(nodes[1].computedStyle.item.grow, 9)
    }

    func testUnstyledChildGetsDefaults() {
        let (nodes, _) = build(css: "", schema: [("a", "text")])
        XCTAssertEqual(nodes[1].computedStyle, ComputedStyle())
    }

    // MARK: - Hierarchical schema (Phase 2)

    func testParentIDEstablishesHierarchy() {
        var diags = CSSDiagnostics()
        let sheet = CSSParser.parse("", diagnostics: &diags)
        let nodes = StyleTreeBuilder.build(
            rootID: "root",
            schema: [
                SchemaEntry(id: "form"),
                SchemaEntry(id: "name", parentID: "form"),
            ],
            stylesheet: sheet,
            diagnostics: &diags
        )
        XCTAssertEqual(nodes.count, 3)
        XCTAssertNil(nodes[0].parentID)
        XCTAssertEqual(nodes[1].id, "form")
        XCTAssertEqual(nodes[1].parentID, "root")
        XCTAssertEqual(nodes[2].id, "name")
        XCTAssertEqual(nodes[2].parentID, "form")
    }

    func testDescendantSelectorMatchesHierarchically() {
        var diags = CSSDiagnostics()
        let sheet = CSSParser.parse(
            "#form #name { flex-grow: 7; }",
            diagnostics: &diags
        )
        let nodes = StyleTreeBuilder.build(
            rootID: "root",
            schema: [
                SchemaEntry(id: "form"),
                SchemaEntry(id: "row", parentID: "form"),
                SchemaEntry(id: "name", parentID: "row"),
            ],
            stylesheet: sheet,
            diagnostics: &diags
        )
        // The last node (`name`) has ancestors row→form→root; the selector
        // matches because `#form` is reachable via descendant.
        XCTAssertEqual(nodes.last?.id, "name")
        XCTAssertEqual(nodes.last?.computedStyle.item.grow, 7)
    }

    func testUnknownParentIDAttachesToRoot() {
        var diags = CSSDiagnostics()
        let sheet = CSSParser.parse("", diagnostics: &diags)
        let nodes = StyleTreeBuilder.build(
            rootID: "root",
            schema: [SchemaEntry(id: "orphan", parentID: "nowhere")],
            stylesheet: sheet,
            diagnostics: &diags
        )
        XCTAssertEqual(nodes[1].parentID, "root")
    }

    // MARK: - Class matching (Phase 2)

    /// A schema entry can now carry a `classes: [String]` list; `.class`
    /// selectors match against it in the cascade.
    func testSchemaClassesAreMatched() {
        var diags = CSSDiagnostics()
        let sheet = CSSParser.parse(".primary { flex-grow: 4; }", diagnostics: &diags)
        let nodes = StyleTreeBuilder.build(
            rootID: "root",
            schema: [SchemaEntry(id: "submit", type: "button", classes: ["primary"])],
            stylesheet: sheet,
            diagnostics: &diags
        )
        XCTAssertEqual(nodes[1].classes, ["primary"])
        XCTAssertEqual(nodes[1].computedStyle.item.grow, 4)
    }

    func testChildrenPreserveSchemaInsertionOrder() {
        // Two children, styled in reverse order — the *output order* must
        // still match the schema's insertion order.
        let (nodes, _) = build(
            css: "#b { flex-grow: 2; } #a { flex-grow: 5; }",
            schema: [("a", "text"), ("b", "text")]
        )
        XCTAssertEqual(nodes.map(\.id), ["root", "a", "b"])
        XCTAssertEqual(nodes[1].computedStyle.item.grow, 5)
        XCTAssertEqual(nodes[2].computedStyle.item.grow, 2)
    }

    func testDuplicateSchemaIDDoesNotCrashAndDeduplicates() {
        // Adversarial payloads may contain two entries with the same id.
        // The builder must emit one node (first wins) and surface a warning,
        // never crash.
        var diags = CSSDiagnostics()
        let sheet = CSSParser.parse("", diagnostics: &diags)
        let nodes = StyleTreeBuilder.build(
            rootID: "root",
            schema: [
                SchemaEntry(id: "a", type: "text"),
                SchemaEntry(id: "a", type: "button"),  // duplicate id
            ],
            stylesheet: sheet,
            diagnostics: &diags
        )
        XCTAssertEqual(nodes.map(\.id), ["root", "a"])
        XCTAssertEqual(nodes[1].schemaType, "text", "first wins")
        XCTAssertEqual(diags.count(of: .duplicateSchemaID("a")), 1)
    }

    // MARK: - Phase 3 — `SchemaEntry.props` propagation

    /// `SchemaEntry.props` is the server-sent prop bag (placeholder text,
    /// binding paths, labels, etc.). `StyleTreeBuilder` must preserve it on
    /// the emitted `StyleNode` so the resolver can later hand it to the
    /// component factory as a `ComponentProps`.
    func testSchemaPropsPropagateToStyleNode() {
        var diags = CSSDiagnostics()
        let sheet = CSSParser.parse("", diagnostics: &diags)
        let nodes = StyleTreeBuilder.build(
            rootID: "root",
            schema: [
                SchemaEntry(
                    id: "name",
                    type: "text-input",
                    props: ["placeholder": "Full name", "binding": "user.name"]
                ),
            ],
            stylesheet: sheet,
            diagnostics: &diags
        )
        let node = nodes.first { $0.id == "name" }
        XCTAssertEqual(node?.props["placeholder"], "Full name")
        XCTAssertEqual(node?.props["binding"], "user.name")
    }

    /// Entries without `props` must still produce a node (with empty props)
    /// so existing callers keep compiling unchanged.
    func testMissingPropsYieldsEmptyDictionary() {
        var diags = CSSDiagnostics()
        let sheet = CSSParser.parse("", diagnostics: &diags)
        let nodes = StyleTreeBuilder.build(
            rootID: "root",
            schema: [SchemaEntry(id: "a", type: "text")],
            stylesheet: sheet,
            diagnostics: &diags
        )
        XCTAssertEqual(nodes.first { $0.id == "a" }?.props, [:])
    }
}
