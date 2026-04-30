import XCTest
@testable import JoyDOM

/// End-to-end cascade tests for the Tier 5 tree-native pipeline.
///
/// Tier 5 deleted the old `Stylesheet` / `Declaration` / `SchemaEntry`
/// path and the unit tests that drove it directly. These tests replace
/// that coverage by exercising the same cascade scenarios through the
/// public API: build a `Spec`, run it through `RuleBuilder` +
/// `StyleTreeBuilder`, and assert the resolved `ComputedStyle` per node.
///
/// We don't go through `JoyDOMView.body` here because that requires a
/// SwiftUI host; instead we drive the same pipeline pieces the view's
/// `renderSnapshot` uses, in isolation.
final class CascadeIntegrationTests: XCTestCase {

    // MARK: - Helpers

    private func resolve(spec: Spec, viewport: Viewport? = nil) -> [String: ComputedStyle] {
        var diags = JoyDiagnostics()
        let activeBP = viewport.flatMap {
            BreakpointResolver.active(in: $0, breakpoints: spec.breakpoints)
        }
        let rules = RuleBuilder.buildRules(
            from: spec, activeBreakpoint: activeBP, diagnostics: &diags
        )
        let nodes = StyleTreeBuilder.build(
            layout: spec.layout,
            rootID: "__joydom_root__",
            rules: rules,
            classNameOverrides: activeBP?.nodes.compactMapValues { $0.className } ?? [:],
            diagnostics: &diags
        )
        var byID: [String: ComputedStyle] = [:]
        for n in nodes { byID[n.id] = n.computedStyle }
        return byID
    }

    // MARK: - Specificity priority: id > class > type

    func testIDSelectorWinsOverClassAndType() {
        let spec = Spec(
            style: [
                "div":        Style(flexDirection: .row),     // type: low specificity
                ".container": Style(flexDirection: .row),     // class: medium
                "#root":      Style(flexDirection: .column),  // id: highest
            ],
            breakpoints: [],
            layout: Node(
                type: "div",
                props: NodeProps(id: "root", className: ["container"])
            )
        )
        let resolved = resolve(spec: spec)
        XCTAssertEqual(resolved["root"]?.container.direction, .column,
                       "id selector should win over class and type")
    }

    func testClassSelectorWinsOverType() {
        let spec = Spec(
            style: [
                "div":  Style(flexDirection: .row),
                ".cls": Style(flexDirection: .column),
            ],
            breakpoints: [],
            layout: Node(
                type: "div",
                props: NodeProps(id: "x", className: ["cls"])
            )
        )
        let resolved = resolve(spec: spec)
        XCTAssertEqual(resolved["x"]?.container.direction, .column)
    }

    // MARK: - Source-order tie-break

    func testLaterSourceOrderWinsOnEqualSpecificity() {
        // Two #x selectors with equal specificity — the later one wins.
        let spec = Spec(
            style: [
                "#x": Style(flexDirection: .row),
            ],
            breakpoints: [
                // Document and breakpoint both target #x. Breakpoint is
                // emitted later in source order — it should win.
                Breakpoint(
                    conditions: [],   // always active
                    style: ["#x": Style(flexDirection: .column)]
                ),
            ],
            layout: Node(type: "div", props: NodeProps(id: "x"))
        )
        let resolved = resolve(spec: spec, viewport: Viewport(width: 0))
        XCTAssertEqual(resolved["x"]?.container.direction, .column,
                       "active breakpoint rule should override document rule at equal specificity")
    }

    // MARK: - Inline (props.style) wins over selectors

    func testInlinePropsStyleBeatsClassSelector() {
        let spec = Spec(
            style: [
                ".cls": Style(flexDirection: .row),
            ],
            breakpoints: [],
            layout: Node(
                type: "div",
                props: NodeProps(
                    id: "x",
                    className: ["cls"],
                    style: Style(flexDirection: .column)
                )
            )
        )
        let resolved = resolve(spec: spec)
        XCTAssertEqual(resolved["x"]?.container.direction, .column,
                       "inline `props.style` should win over class selector via id-level specificity")
    }

    // MARK: - Breakpoint per-node override has highest priority

    func testBreakpointPerNodeStyleBeatsBaseInline() {
        let spec = Spec(
            style: [:],
            breakpoints: [
                Breakpoint(
                    conditions: [],
                    nodes: [
                        "x": NodeProps(style: Style(flexDirection: .row))
                    ]
                ),
            ],
            layout: Node(
                type: "div",
                props: NodeProps(id: "x", style: Style(flexDirection: .column))
            )
        )
        let resolved = resolve(spec: spec, viewport: Viewport(width: 0))
        XCTAssertEqual(resolved["x"]?.container.direction, .row,
                       "breakpoint nodes[id].style should win over base props.style")
    }

    // MARK: - Descendant combinator

    func testDescendantCombinatorMatches() {
        let spec = Spec(
            style: [
                "#root .child": Style(flexDirection: .row),
            ],
            breakpoints: [],
            layout: Node(
                type: "div",
                props: NodeProps(id: "root"),
                children: [
                    .node(Node(
                        type: "div",
                        props: NodeProps(id: "c", className: ["child"])
                    ))
                ]
            )
        )
        let resolved = resolve(spec: spec)
        XCTAssertEqual(resolved["c"]?.container.direction, .row,
                       "descendant selector should match a child of #root")
    }

    // MARK: - Adjacent sibling combinator

    func testAdjacentSiblingCombinatorMatches() {
        let spec = Spec(
            style: [
                "#a + #b": Style(flexDirection: .row),
            ],
            breakpoints: [],
            layout: Node(
                type: "div",
                props: NodeProps(id: "root"),
                children: [
                    .node(Node(type: "div", props: NodeProps(id: "a"))),
                    .node(Node(type: "div", props: NodeProps(id: "b"))),
                ]
            )
        )
        let resolved = resolve(spec: spec)
        XCTAssertEqual(resolved["b"]?.container.direction, .row)
    }

    // MARK: - General sibling combinator

    func testGeneralSiblingCombinatorMatchesNonImmediate() {
        let spec = Spec(
            style: [
                "#a ~ #c": Style(flexDirection: .row),
            ],
            breakpoints: [],
            layout: Node(
                type: "div",
                props: NodeProps(id: "root"),
                children: [
                    .node(Node(type: "div", props: NodeProps(id: "a"))),
                    .node(Node(type: "div", props: NodeProps(id: "b"))),
                    .node(Node(type: "div", props: NodeProps(id: "c"))),
                ]
            )
        )
        let resolved = resolve(spec: spec)
        XCTAssertEqual(resolved["c"]?.container.direction, .row,
                       "general sibling should match #c after #a even with #b between")
    }

    // MARK: - Style fields end-to-end

    func testStyleFieldsTranslateToComputedStyle() {
        let spec = Spec(
            style: [
                "#x": Style(
                    flexDirection: .row,
                    flexGrow: 2,
                    flexShrink: 0,
                    justifyContent: .spaceBetween,
                    alignItems: .center,
                    flexWrap: .wrap,
                    gap: .uniform(.px(8)),
                    order: 3,
                    width: .px(100),
                    height: .percent(50),
                    padding: .uniform(.px(12))
                ),
            ],
            breakpoints: [],
            layout: Node(type: "div", props: NodeProps(id: "x"))
        )
        let s = resolve(spec: spec)["x"]
        XCTAssertEqual(s?.container.direction, .row)
        XCTAssertEqual(s?.item.grow, 2)
        XCTAssertEqual(s?.item.shrink, 0)
        XCTAssertEqual(s?.container.justifyContent, .spaceBetween)
        XCTAssertEqual(s?.container.alignItems, .center)
        XCTAssertEqual(s?.container.wrap, .wrap)
        XCTAssertEqual(s?.container.gap, 8)
        XCTAssertEqual(s?.item.order, 3)
        // width / height / padding shape-checks.
        XCTAssertNotNil(s?.item.width)
        XCTAssertNotNil(s?.item.height)
        XCTAssertEqual(s?.container.padding.top, 12)
        XCTAssertEqual(s?.container.padding.bottom, 12)
        XCTAssertEqual(s?.container.padding.leading, 12)
        XCTAssertEqual(s?.container.padding.trailing, 12)
    }

    func testGapAxesSetsRowAndColumnSeparately() {
        let spec = Spec(
            style: [
                "#x": Style(gap: .axes(column: .px(4), row: .px(8))),
            ],
            breakpoints: [],
            layout: Node(type: "div", props: NodeProps(id: "x"))
        )
        let s = resolve(spec: spec)["x"]
        XCTAssertEqual(s?.container.rowGap, 8)
        XCTAssertEqual(s?.container.columnGap, 4)
    }

    func testPaddingSidesAppliesPerSide() {
        let spec = Spec(
            style: [
                "#x": Style(padding: .sides(
                    top: .px(1), right: .px(2), bottom: .px(3), left: .px(4)
                )),
            ],
            breakpoints: [],
            layout: Node(type: "div", props: NodeProps(id: "x"))
        )
        let s = resolve(spec: spec)["x"]
        XCTAssertEqual(s?.container.padding.top, 1)
        XCTAssertEqual(s?.container.padding.trailing, 2)
        XCTAssertEqual(s?.container.padding.bottom, 3)
        XCTAssertEqual(s?.container.padding.leading, 4)
    }
}
