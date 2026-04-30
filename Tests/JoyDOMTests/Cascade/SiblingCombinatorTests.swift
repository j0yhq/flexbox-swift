import XCTest
@testable import JoyDOM

/// Sibling-combinator coverage restored after Tier 5 deleted the
/// stylesheet-driven test file. Same scenarios, but driven through the
/// joy-dom `Spec` → `RuleBuilder` → `StyleResolver` pipeline.
///
/// Coverage zones:
///   1. Selector parser recognizes `+` / `~` (already covered in
///      `SelectorParserTests`; not duplicated here).
///   2. Matcher — adjacent vs general; positive AND negative cases;
///      chained `.a + .b + .c`; cross-parent scoping; empty siblings.
final class SiblingCombinatorTests: XCTestCase {

    // MARK: - Helper

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

    private func threeSiblings(rule: String) -> Spec {
        Spec(
            style: [rule: Style(flexDirection: .column)],
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
    }

    // MARK: - Adjacent sibling (`+`)

    func testAdjacentMatchesImmediatePredecessor() {
        let r = resolve(spec: threeSiblings(rule: "#a + #b"))
        XCTAssertEqual(r["b"]?.container.direction, .column)
    }

    func testAdjacentDoesNotMatchNonAdjacentTarget() {
        // `#a + #c` should NOT match #c — #b is between #a and #c.
        let r = resolve(spec: threeSiblings(rule: "#a + #c"))
        XCTAssertNotEqual(r["c"]?.container.direction, .column,
                          "+ requires the IMMEDIATE predecessor")
    }

    func testAdjacentDoesNotMatchSubject() {
        // The `#b` part matches the subject; the `#a +` precedes it. So
        // the rule applies to #b, not #a or #c.
        let r = resolve(spec: threeSiblings(rule: "#a + #b"))
        XCTAssertNotEqual(r["a"]?.container.direction, .column)
        XCTAssertNotEqual(r["c"]?.container.direction, .column)
    }

    func testAdjacentDoesNotMatchInReverseOrder() {
        // `#b + #a` requires #b BEFORE #a in source order. In our tree
        // #a comes first, so the rule must not match.
        let r = resolve(spec: threeSiblings(rule: "#b + #a"))
        XCTAssertNotEqual(r["a"]?.container.direction, .column,
                          "+ is order-sensitive")
    }

    // MARK: - General sibling (`~`)

    func testGeneralMatchesImmediatePredecessor() {
        // `~` is a superset of `+` — the immediate case still matches.
        let r = resolve(spec: threeSiblings(rule: "#a ~ #b"))
        XCTAssertEqual(r["b"]?.container.direction, .column)
    }

    func testGeneralMatchesNonAdjacentLater() {
        // `#a ~ #c` matches even though #b is between them.
        let r = resolve(spec: threeSiblings(rule: "#a ~ #c"))
        XCTAssertEqual(r["c"]?.container.direction, .column)
    }

    func testGeneralDoesNotMatchInReverseOrder() {
        // `#c ~ #a` — #c is later than #a, so #a has no #c sibling
        // before it.
        let r = resolve(spec: threeSiblings(rule: "#c ~ #a"))
        XCTAssertNotEqual(r["a"]?.container.direction, .column)
    }

    func testGeneralDoesNotMatchSubject() {
        let r = resolve(spec: threeSiblings(rule: "#a ~ #c"))
        XCTAssertNotEqual(r["a"]?.container.direction, .column)
        XCTAssertNotEqual(r["b"]?.container.direction, .column)
    }

    // MARK: - Chained combinators

    func testChainedAdjacent() {
        // `#a + #b + #c` — both `+` checks must pass in order.
        let r = resolve(spec: threeSiblings(rule: "#a + #b + #c"))
        XCTAssertEqual(r["c"]?.container.direction, .column)
    }

    func testChainedAdjacentBreaksOnGap() {
        // `#a + #c` already proven non-matching (test above). Chain
        // sanity-check: `#a + #x + #c` where #x doesn't exist must
        // also not match.
        let r = resolve(spec: threeSiblings(rule: "#a + #nonexistent + #c"))
        XCTAssertNotEqual(r["c"]?.container.direction, .column)
    }

    // MARK: - Cross-parent scoping

    func testSiblingDoesNotMatchAcrossParents() {
        // #a in container #left, #b in container #right. They don't
        // share a parent, so `#a + #b` must not match.
        let spec = Spec(
            style: ["#a + #b": Style(flexDirection: .column)],
            breakpoints: [],
            layout: Node(
                type: "div",
                props: NodeProps(id: "root"),
                children: [
                    .node(Node(
                        type: "div",
                        props: NodeProps(id: "left"),
                        children: [.node(Node(type: "div", props: NodeProps(id: "a")))]
                    )),
                    .node(Node(
                        type: "div",
                        props: NodeProps(id: "right"),
                        children: [.node(Node(type: "div", props: NodeProps(id: "b")))]
                    )),
                ]
            )
        )
        let r = resolve(spec: spec)
        XCTAssertNotEqual(r["b"]?.container.direction, .column,
                          "sibling combinators must not match across parents")
    }

    // MARK: - Empty / single-child cases

    func testFirstChildHasNoPrecedingSiblings() {
        // `#a + #foo` can't match #a because #a has no preceding
        // sibling — it's the first child.
        let r = resolve(spec: threeSiblings(rule: "#x + #a"))
        XCTAssertNotEqual(r["a"]?.container.direction, .column)
    }

    func testSingleChildHasNoSiblings() {
        let spec = Spec(
            style: ["#x + #only": Style(flexDirection: .column)],
            breakpoints: [],
            layout: Node(
                type: "div",
                props: NodeProps(id: "root"),
                children: [.node(Node(type: "div", props: NodeProps(id: "only")))]
            )
        )
        let r = resolve(spec: spec)
        XCTAssertNotEqual(r["only"]?.container.direction, .column)
    }

    // MARK: - Sibling combinators don't leak to descendants

    func testSiblingDoesNotMatchInsideMatchedSibling() {
        // `#a + .b` should match `.b` only when it's an actual sibling
        // of `#a`, not when it's a descendant of one.
        let spec = Spec(
            style: ["#a + .b": Style(flexDirection: .column)],
            breakpoints: [],
            layout: Node(
                type: "div",
                props: NodeProps(id: "root"),
                children: [
                    .node(Node(type: "div", props: NodeProps(id: "a"))),
                    .node(Node(
                        type: "div",
                        props: NodeProps(id: "wrap"),
                        children: [
                            // `nested.b` is a descendant of #wrap, NOT
                            // a sibling of #a.
                            .node(Node(
                                type: "div",
                                props: NodeProps(id: "nested", className: ["b"])
                            )),
                        ]
                    )),
                ]
            )
        )
        let r = resolve(spec: spec)
        XCTAssertNotEqual(r["nested"]?.container.direction, .column,
                          "+ matches siblings only, not descendants")
    }
}
