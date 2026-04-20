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
}
