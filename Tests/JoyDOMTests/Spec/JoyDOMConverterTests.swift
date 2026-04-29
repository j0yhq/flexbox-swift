import XCTest
@testable import JoyDOM

/// Unit 4 — `JoyDOMConverter.convert(_:)` translates a `JoyDOMSpec`
/// into the `CSSPayload` JoyDOMView's resolver consumes. It composes:
///   • `SchemaFlattener` for the schema array
///   • `StyleSerializer` for document-level style rules
///   • A new "inline style injection" pass that emits a `#id { ... }`
///     rule per node carrying `props.style`
///
/// The converter is the seam between joy-dom's structured-object world
/// and JoyDOMView's text-CSS world. Output round-trips through the
/// existing parser without diagnostics.
final class JoyDOMConverterTests: XCTestCase {

    // MARK: - Trivial conversions

    func testEmptySpecProducesEmptyCSSAndOneRootEntry() {
        let spec = JoyDOMSpec(layout: Node(type: "div", props: NodeProps(id: "r")))
        let payload = JoyDOMConverter.convert(spec)
        XCTAssertEqual(payload.css, "")
        XCTAssertEqual(payload.schema.count, 1)
        XCTAssertEqual(payload.schema[0].id, "r")
    }

    func testSchemaMatchesSchemaFlattenerOutput() {
        let layout = Node(type: "div", props: NodeProps(id: "root"), children: [
            .node(Node(type: "p", props: NodeProps(id: "para"))),
            .primitive(.string("hi")),
        ])
        let spec = JoyDOMSpec(layout: layout)
        let payload = JoyDOMConverter.convert(spec)
        XCTAssertEqual(payload.schema, SchemaFlattener.flatten(layout))
    }

    // MARK: - Document-level styles

    func testDocumentStylesBecomeSelectorRules() {
        let spec = JoyDOMSpec(
            style: ["#root": Style(flexDirection: .column)],
            layout: Node(type: "div", props: NodeProps(id: "root"))
        )
        let payload = JoyDOMConverter.convert(spec)
        XCTAssertTrue(payload.css.contains("#root { flex-direction: column; }"),
                      "missing selector rule, got: \(payload.css)")
    }

    func testMultipleDocumentSelectorsAllSerialize() {
        let spec = JoyDOMSpec(
            style: [
                "#root":   Style(flexDirection: .column),
                ".panel":  Style(padding: .uniform(.px(8))),
            ],
            layout: Node(type: "div", props: NodeProps(id: "root"))
        )
        let payload = JoyDOMConverter.convert(spec)
        XCTAssertTrue(payload.css.contains("flex-direction: column"))
        XCTAssertTrue(payload.css.contains("padding: 8px"))
    }

    // MARK: - Inline node styles

    func testInlineStyleProducesIDRule() {
        let layout = Node(
            type: "div",
            props: NodeProps(id: "card", style: Style(flexDirection: .row))
        )
        let spec = JoyDOMSpec(layout: layout)
        let payload = JoyDOMConverter.convert(spec)
        XCTAssertTrue(payload.css.contains("#card { flex-direction: row; }"),
                      "expected inline-style rule, got: \(payload.css)")
    }

    func testInlineStyleOnNodeWithoutIDUsesSyntheticID() {
        // Synthetic id `_root` matches what SchemaFlattener emits, so
        // the rule still targets the right node even without an
        // author-supplied id.
        let layout = Node(type: "div", props: NodeProps(style: Style(display: .flex)))
        let spec = JoyDOMSpec(layout: layout)
        let payload = JoyDOMConverter.convert(spec)
        XCTAssertTrue(payload.css.contains("#_root { display: flex; }"),
                      "expected synthetic-id rule, got: \(payload.css)")
    }

    func testInlineStylesOnNestedNodesEachGetTheirOwnRule() {
        let layout = Node(
            type: "div",
            props: NodeProps(id: "root", style: Style(flexDirection: .column)),
            children: [
                .node(Node(type: "p",
                           props: NodeProps(id: "para",
                                            style: Style(padding: .uniform(.px(8)))))),
            ]
        )
        let spec = JoyDOMSpec(layout: layout)
        let payload = JoyDOMConverter.convert(spec)
        XCTAssertTrue(payload.css.contains("#root { flex-direction: column; }"))
        XCTAssertTrue(payload.css.contains("#para { padding: 8px; }"))
    }

    func testNodeWithoutStylePropertyEmitsNoInlineRule() {
        let layout = Node(type: "div", props: NodeProps(id: "x"))
        let spec = JoyDOMSpec(layout: layout)
        let payload = JoyDOMConverter.convert(spec)
        XCTAssertFalse(payload.css.contains("#x"),
                       "no inline style → no #x rule; got: \(payload.css)")
    }

    func testInlineStyleCSSStandaloneMatchesConverterOutput() {
        // The standalone helper exists so callers (Unit 8 breakpoint
        // application) can compose inline rules without going through
        // the full converter.
        let layout = Node(
            type: "div",
            props: NodeProps(id: "x", style: Style(flexDirection: .row))
        )
        let helper = JoyDOMConverter.inlineStyleCSS(for: layout)
        let payload = JoyDOMConverter.convert(JoyDOMSpec(layout: layout))
        XCTAssertTrue(payload.css.contains(helper))
        XCTAssertEqual(helper, "#x { flex-direction: row; }")
    }

    func testEmptyStyleObjectEmitsNoRule() {
        // An author-provided but empty Style on a node should not emit
        // a stray empty rule like "#x {}".
        let layout = Node(type: "div", props: NodeProps(id: "x", style: Style()))
        let spec = JoyDOMSpec(layout: layout)
        let payload = JoyDOMConverter.convert(spec)
        XCTAssertFalse(payload.css.contains("#x"),
                       "empty Style → no rule; got: \(payload.css)")
    }

    // MARK: - Cascade ordering — inline must follow document-level rules

    func testInlineRulesEmittedAfterDocumentRules() {
        // Source order: document rules first, inline rules second.
        // Inline rules win on id-specificity, but if two rules of equal
        // specificity match the same property the later one wins —
        // emitting inline last makes that path consistent for Unit 8.
        let spec = JoyDOMSpec(
            style: [".pad": Style(padding: .uniform(.px(4)))],
            layout: Node(
                type: "div",
                props: NodeProps(
                    id: "x",
                    className: ["pad"],
                    style: Style(padding: .uniform(.px(20)))
                )
            )
        )
        let payload = JoyDOMConverter.convert(spec)
        let docRange    = payload.css.range(of: ".pad")
        let inlineRange = payload.css.range(of: "#x")
        XCTAssertNotNil(docRange)
        XCTAssertNotNil(inlineRange)
        if let d = docRange, let i = inlineRange {
            XCTAssertLessThan(d.lowerBound, i.lowerBound,
                              "expected document rule to come before inline; got: \(payload.css)")
        }
    }

    // MARK: - Round-trip through CSSParser

    func testConverterOutputParsesWithoutDiagnostics() {
        let spec = JoyDOMSpec(
            style: ["#root": Style(flexDirection: .column, gap: .uniform(.px(12)))],
            layout: Node(
                type: "div",
                props: NodeProps(id: "root", style: Style(padding: .uniform(.px(16)))),
                children: [
                    .node(Node(
                        type: "p",
                        props: NodeProps(id: "p1", style: Style(flexGrow: 1))
                    )),
                ]
            )
        )
        let payload = JoyDOMConverter.convert(spec)
        var diagnostics = JoyDiagnostics()
        _ = CSSParser.parse(payload.css, diagnostics: &diagnostics)
        XCTAssertTrue(diagnostics.warnings.isEmpty,
                      "converter emitted CSS the parser couldn't accept: \(diagnostics.warnings)")
    }
}
