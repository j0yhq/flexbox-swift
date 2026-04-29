import XCTest
@testable import CSSLayout

/// Unit 3 — `SchemaFlattener.flatten(_:)` walks a joy-dom `Node` tree
/// (the recursive shape in `DOM/spec.ts`) and emits the flat
/// `[SchemaEntry]` array CSSLayout's resolver consumes.
///
/// Contract:
///   • Render order is preserved: depth-first, parent-before-children.
///   • Stable ids: `props.id` wins; otherwise a path-based synthetic
///     id (`_root`, `_n_0_1`, …) keeps the output deterministic.
///   • Primitive children (string / number / null) become standalone
///     entries typed `primitive_string` / `primitive_number` /
///     `primitive_null` with the value stringified into `props["value"]`.
///   • `parentID` links are correct and only `nil` on the root.
///   • Flattening is pure — same input twice produces identical output.
final class SchemaFlattenerTests: XCTestCase {

    // MARK: - Single-node payloads

    func testSingleRootWithExplicitIdUsesItVerbatim() {
        let entries = SchemaFlattener.flatten(
            Node(type: "div", props: NodeProps(id: "main"))
        )
        XCTAssertEqual(entries.count, 1)
        XCTAssertEqual(entries[0].id, "main")
        XCTAssertEqual(entries[0].type, "div")
        XCTAssertNil(entries[0].parentID)
    }

    func testSingleRootWithoutIdGetsRootSyntheticId() {
        let entries = SchemaFlattener.flatten(Node(type: "div"))
        XCTAssertEqual(entries.count, 1)
        XCTAssertEqual(entries[0].id, "_root")
        XCTAssertNil(entries[0].parentID)
    }

    func testRootClassNamesArePreserved() {
        let entries = SchemaFlattener.flatten(
            Node(type: "div",
                 props: NodeProps(id: "page", className: ["a", "b"]))
        )
        XCTAssertEqual(entries[0].classes, ["a", "b"])
    }

    // MARK: - Parent + children

    func testParentAndChildrenLinkViaParentID() {
        let layout = Node(
            type: "div",
            props: NodeProps(id: "root"),
            children: [
                .node(Node(type: "p",   props: NodeProps(id: "first"))),
                .node(Node(type: "div", props: NodeProps(id: "second"))),
            ]
        )
        let entries = SchemaFlattener.flatten(layout)
        XCTAssertEqual(entries.count, 3)
        XCTAssertEqual(entries[0].id, "root")
        XCTAssertNil(entries[0].parentID)
        XCTAssertEqual(entries[1].id, "first")
        XCTAssertEqual(entries[1].parentID, "root")
        XCTAssertEqual(entries[2].id, "second")
        XCTAssertEqual(entries[2].parentID, "root")
    }

    func testRenderOrderIsDepthFirst() {
        let layout = Node(type: "div", props: NodeProps(id: "r"), children: [
            .node(Node(type: "div", props: NodeProps(id: "a"), children: [
                .node(Node(type: "div", props: NodeProps(id: "a1"))),
                .node(Node(type: "div", props: NodeProps(id: "a2"))),
            ])),
            .node(Node(type: "div", props: NodeProps(id: "b"))),
        ])
        let entries = SchemaFlattener.flatten(layout)
        XCTAssertEqual(entries.map(\.id), ["r", "a", "a1", "a2", "b"])
    }

    func testNestedThreeDeepPreservesParentLinks() {
        let layout = Node(type: "div", props: NodeProps(id: "L1"), children: [
            .node(Node(type: "div", props: NodeProps(id: "L2"), children: [
                .node(Node(type: "div", props: NodeProps(id: "L3"))),
            ])),
        ])
        let entries = SchemaFlattener.flatten(layout)
        XCTAssertEqual(entries.map(\.parentID), [nil, "L1", "L2"])
    }

    // MARK: - Synthetic id generation

    func testChildrenWithoutIdGetPathBasedSyntheticIds() {
        let layout = Node(type: "div", children: [
            .node(Node(type: "p")),
            .node(Node(type: "p")),
        ])
        let entries = SchemaFlattener.flatten(layout)
        XCTAssertEqual(entries.map(\.id), ["_root", "_n_0", "_n_1"])
        XCTAssertEqual(entries.map(\.parentID), [nil, "_root", "_root"])
    }

    func testNestedChildrenWithoutIdsGetPathSegmentJoinedIds() {
        let layout = Node(type: "div", children: [
            .node(Node(type: "div", children: [
                .node(Node(type: "p")),
                .node(Node(type: "p")),
            ])),
        ])
        let entries = SchemaFlattener.flatten(layout)
        XCTAssertEqual(entries.map(\.id), ["_root", "_n_0", "_n_0_0", "_n_0_1"])
    }

    func testExplicitIdOnAncestorDoesNotPropagateIntoSyntheticChildIds() {
        // Synthetic ids reference the position in the *tree*, not the
        // ancestor's name — keeps generation deterministic and
        // independent of authoring choices.
        let layout = Node(type: "div", props: NodeProps(id: "named"), children: [
            .node(Node(type: "p")),
        ])
        let entries = SchemaFlattener.flatten(layout)
        XCTAssertEqual(entries.map(\.id), ["named", "_n_0"])
        XCTAssertEqual(entries[1].parentID, "named")
    }

    // MARK: - Primitive children

    func testPrimitiveStringChildBecomesPrimitiveStringEntry() {
        let layout = Node(type: "p", props: NodeProps(id: "para"), children: [
            .primitive(.string("hello")),
        ])
        let entries = SchemaFlattener.flatten(layout)
        XCTAssertEqual(entries.count, 2)
        XCTAssertEqual(entries[1].type, "primitive_string")
        XCTAssertEqual(entries[1].props["value"], "hello")
        XCTAssertEqual(entries[1].parentID, "para")
    }

    func testPrimitiveNumberChildBecomesPrimitiveNumberEntry() {
        let layout = Node(type: "p", props: NodeProps(id: "para"), children: [
            .primitive(.number(42)),
        ])
        let entries = SchemaFlattener.flatten(layout)
        XCTAssertEqual(entries[1].type, "primitive_number")
        XCTAssertEqual(entries[1].props["value"], "42")
    }

    func testPrimitiveNullChildBecomesPrimitiveNullEntryWithoutValue() {
        let layout = Node(type: "p", props: NodeProps(id: "para"), children: [
            .primitive(.null),
        ])
        let entries = SchemaFlattener.flatten(layout)
        XCTAssertEqual(entries[1].type, "primitive_null")
        XCTAssertNil(entries[1].props["value"])
    }

    func testFractionalPrimitiveNumberKeepsDecimal() {
        let layout = Node(type: "p", children: [.primitive(.number(3.14))])
        let entries = SchemaFlattener.flatten(layout)
        XCTAssertEqual(entries[1].props["value"], "3.14")
    }

    func testIntegerPrimitiveNumberHasNoTrailingZero() {
        let layout = Node(type: "p", children: [.primitive(.number(7))])
        let entries = SchemaFlattener.flatten(layout)
        XCTAssertEqual(entries[1].props["value"], "7")
    }

    func testMixedNodeAndPrimitiveChildren() {
        let layout = Node(type: "p", props: NodeProps(id: "para"), children: [
            .node(Node(type: "span", props: NodeProps(id: "lead"))),
            .primitive(.string("middle")),
            .node(Node(type: "span", props: NodeProps(id: "tail"))),
        ])
        let entries = SchemaFlattener.flatten(layout)
        // Primitive "middle" sits at root's child index 1, so its
        // path is `[1]` and the synthetic id is `_n_1`.
        XCTAssertEqual(entries.map(\.id), ["para", "lead", "_n_1", "tail"])
        XCTAssertEqual(entries.map(\.type), ["p", "span", "primitive_string", "span"])
    }

    // MARK: - Determinism

    func testFlattenIsPureAndDeterministic() {
        let layout = Node(type: "div", children: [
            .node(Node(type: "p", children: [.primitive(.string("hi"))])),
            .node(Node(type: "p", children: [.primitive(.string("there"))])),
        ])
        let a = SchemaFlattener.flatten(layout)
        let b = SchemaFlattener.flatten(layout)
        XCTAssertEqual(a, b)
    }

    // MARK: - Inline style is left alone in Unit 3

    func testInlineStyleIsDroppedFromSchemaEntryProps() {
        // Unit 3's job is structural; Unit 4 promotes inline styles into
        // a synthetic CSS rule. SchemaEntry.props should NOT contain a
        // stringified style payload — that would leak the spec's structure
        // into the registry-facing prop bag.
        let layout = Node(
            type: "div",
            props: NodeProps(id: "x", style: Style(flexDirection: .row))
        )
        let entries = SchemaFlattener.flatten(layout)
        XCTAssertNil(entries[0].props["style"])
    }
}
