import XCTest
@testable import JoyDOM

/// Unit 8 — `JoyDOMConverter.convert(_:viewport:)` applies the active
/// breakpoint to the render pipeline before flattening.
///
/// What "apply" means concretely:
///   • `Breakpoint.style[selector]` rules emitted after document
///     selector rules and before per-node inline rules. Source order
///     gives them priority over document rules at equal specificity.
///   • `Breakpoint.nodes[id].style` emitted as `#id { ... }` rules
///     AFTER the base inline rules — Josh's documented per-node
///     breakpoint inline override beats per-node base inline.
///   • `Breakpoint.nodes[id].className`, when present, REPLACES the
///     SchemaEntry's `classes` for that node so class selectors
///     re-match against the breakpoint-effective class list.
///
/// Cascade order produced by source order (later wins on tie):
///   `Document.style → Breakpoint.style → node.props.style →
///    Breakpoint.nodes[id].style`
final class JoyDOMBreakpointApplicationTests: XCTestCase {

    // MARK: - Fixtures

    private func twoBreakpointSpec() -> Spec {
        Spec(
            style: ["#root": Style(flexDirection: .column)],
            breakpoints: [
                Breakpoint(
                    conditions: [.width(operator: .greaterThanOrEqual, value: 768, unit: .px)],
                    style: ["#root": Style(flexDirection: .row)]
                ),
                Breakpoint(
                    conditions: [.width(operator: .lessThan, value: 600, unit: .px)],
                    nodes: ["sidebar": NodeProps(style: Style(display: .block))]
                ),
            ],
            layout: Node(type: "div", props: NodeProps(id: "root"), children: [
                .node(Node(type: "div", props: NodeProps(id: "sidebar"))),
            ])
        )
    }

    // MARK: - No-viewport / no-match passes through

    func testConvertWithNilViewportEqualsUnit4Convert() {
        let spec = twoBreakpointSpec()
        let withoutVP = JoyDOMConverter.convert(spec)
        let withNilVP = JoyDOMConverter.convert(spec, viewport: nil)
        XCTAssertEqual(withoutVP.css, withNilVP.css)
        XCTAssertEqual(withoutVP.schema, withNilVP.schema)
    }

    func testNoMatchingBreakpointBehavesLikeNoBreakpoint() {
        let spec = twoBreakpointSpec()
        // Viewport in the dead zone between the two breakpoints (600..767).
        let viewport = Viewport(width: 700)
        let payload = JoyDOMConverter.convert(spec, viewport: viewport)
        XCTAssertFalse(payload.css.contains("flex-direction: row"),
                       "wide-bp should not activate; got: \(payload.css)")
        XCTAssertFalse(payload.css.contains("display: block"),
                       "narrow-bp should not activate; got: \(payload.css)")
    }

    // MARK: - Selector-keyed breakpoint styles

    func testActiveBreakpointSelectorStyleAppearsAfterDocumentStyle() {
        let spec = twoBreakpointSpec()
        let payload = JoyDOMConverter.convert(spec, viewport: Viewport(width: 1024))
        // Document rule for #root is `flex-direction: column`. The
        // active breakpoint also targets `#root` with
        // `flex-direction: row`. Both must appear, with the breakpoint
        // rule positioned later in source order so the cascade picks
        // `row` at equal specificity.
        let docRange = payload.css.range(of: "flex-direction: column")
        let bpRange  = payload.css.range(of: "flex-direction: row")
        XCTAssertNotNil(docRange, "missing document rule, css: \(payload.css)")
        XCTAssertNotNil(bpRange,  "missing breakpoint rule, css: \(payload.css)")
        if let d = docRange, let b = bpRange {
            XCTAssertLessThan(d.lowerBound, b.lowerBound,
                              "breakpoint rule must come after document rule; got: \(payload.css)")
        }
    }

    func testInactiveBreakpointSelectorStylesAreNotEmitted() {
        let spec = twoBreakpointSpec()
        let payload = JoyDOMConverter.convert(spec, viewport: Viewport(width: 1024))
        // The narrow-bp targets `display: block` on #sidebar — must
        // NOT appear when only the wide-bp is active.
        XCTAssertFalse(payload.css.contains("display: block"))
    }

    // MARK: - Per-node breakpoint overrides (nodes[id].style)

    func testPerNodeBreakpointStyleEmittedAsIDRule() {
        let spec = twoBreakpointSpec()
        let payload = JoyDOMConverter.convert(spec, viewport: Viewport(width: 320))
        XCTAssertTrue(payload.css.contains("#sidebar { display: block; }"),
                      "missing per-node breakpoint rule, css: \(payload.css)")
    }

    func testPerNodeBreakpointStyleFollowsBaseInlineStyle() {
        // Base node carries inline padding; breakpoint adds display.
        // Cascade order: base `#sidebar { padding: 8px; }` first,
        // breakpoint `#sidebar { display: block; }` second — so
        // padding survives, display added.
        let spec = Spec(
            breakpoints: [
                Breakpoint(
                    conditions: [],   // always active
                    nodes: ["sidebar": NodeProps(style: Style(display: .block))]
                ),
            ],
            layout: Node(type: "div", props: NodeProps(id: "root"), children: [
                .node(Node(
                    type: "div",
                    props: NodeProps(id: "sidebar", style: Style(padding: .uniform(.px(8))))
                )),
            ])
        )
        let payload = JoyDOMConverter.convert(spec, viewport: Viewport(width: 320))
        let base = payload.css.range(of: "padding: 8px")
        let bp   = payload.css.range(of: "display: block")
        XCTAssertNotNil(base)
        XCTAssertNotNil(bp)
        if let b = base, let bp = bp {
            XCTAssertLessThan(b.lowerBound, bp.lowerBound,
                              "breakpoint inline must come after base inline; got: \(payload.css)")
        }
    }

    // MARK: - Per-node className override replaces SchemaEntry classes

    func testBreakpointClassNameOverrideReplacesSchemaClasses() {
        let spec = Spec(
            breakpoints: [
                Breakpoint(
                    conditions: [],   // always active
                    nodes: ["x": NodeProps(className: ["bp-only"])]
                ),
            ],
            layout: Node(
                type: "div",
                props: NodeProps(id: "x", className: ["base-only"])
            )
        )
        let payload = JoyDOMConverter.convert(spec, viewport: Viewport(width: 320))
        let entry = payload.schema.first { $0.id == "x" }
        XCTAssertEqual(entry?.classes, ["bp-only"],
                       "breakpoint className must replace base className")
    }

    func testBreakpointWithoutClassNameLeavesSchemaClassesUntouched() {
        let spec = Spec(
            breakpoints: [
                Breakpoint(
                    conditions: [],
                    nodes: ["x": NodeProps(style: Style(display: .flex))]
                ),
            ],
            layout: Node(
                type: "div",
                props: NodeProps(id: "x", className: ["base-only"])
            )
        )
        let payload = JoyDOMConverter.convert(spec, viewport: Viewport(width: 320))
        let entry = payload.schema.first { $0.id == "x" }
        XCTAssertEqual(entry?.classes, ["base-only"])
    }

    // MARK: - Round-trip through parser

    func testBreakpointAppliedOutputParsesWithoutDiagnostics() {
        let spec = twoBreakpointSpec()
        let payload = JoyDOMConverter.convert(spec, viewport: Viewport(width: 320))
        var diagnostics = JoyDiagnostics()
        _ = CSSParser.parse(payload.css, diagnostics: &diagnostics)
        XCTAssertTrue(diagnostics.warnings.isEmpty,
                      "post-breakpoint CSS must parse cleanly; got: \(diagnostics.warnings)")
    }
}
