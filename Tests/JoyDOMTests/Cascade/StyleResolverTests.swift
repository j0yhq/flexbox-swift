import XCTest
@testable import JoyDOM
import FlexLayout
import CoreGraphics

/// Unit (h) — `StyleResolver` applies a stylesheet's matching rules to a
/// target id, producing one `ComputedStyle` value.
///
/// Cascade contract (CSS §6.4):
///   1. Rules that do not match are ignored.
///   2. Matching rules are sorted by (specificity asc, sourceOrder asc).
///   3. Declarations are applied in that order — later wins.
final class StyleResolverTests: XCTestCase {

    // MARK: - Helpers

    private func resolve(
        _ css: String,
        id: String = "a",
        schemaType: String? = nil,
        classes: [String] = []
    ) -> (ComputedStyle, JoyDiagnostics) {
        var diags = JoyDiagnostics()
        let sheet = CSSParser.parse(css, diagnostics: &diags)
        let computed = StyleResolver.resolve(
            id: id,
            schemaType: schemaType,
            classes: classes,
            stylesheet: sheet,
            diagnostics: &diags
        )
        return (computed, diags)
    }

    // MARK: - Defaults

    func testDefaultsWhenNoMatchingRules() {
        let (style, _) = resolve("#other { flex: 1; }", id: "a")
        XCTAssertEqual(style, ComputedStyle())
    }

    func testMatchesIDSelector() {
        let (style, _) = resolve("#a { flex-grow: 2; }")
        XCTAssertEqual(style.item.grow, 2)
    }

    func testMatchesElementSelector() {
        let (style, _) = resolve("button { flex-grow: 3; }",
                                 id: "submit",
                                 schemaType: "button")
        XCTAssertEqual(style.item.grow, 3)
    }

    // MARK: - Cascade ordering

    func testLastWinsOnEqualSpecificity() {
        let (style, _) = resolve("#a { flex-grow: 1; } #a { flex-grow: 2; }")
        XCTAssertEqual(style.item.grow, 2)
    }

    func testHigherSpecificityWins() {
        // `.primary` wins over `button` (class > element), even though
        // `button` appears later in the stylesheet.
        let (style, _) = resolve("""
            .primary { flex-grow: 2; }
            button   { flex-grow: 1; }
        """, id: "submit", schemaType: "button", classes: ["primary"])
        XCTAssertEqual(style.item.grow, 2)
    }

    // MARK: - Class matching (Phase 2)

    func testMatchesClassSelector() {
        let (style, _) = resolve(".primary { flex-grow: 3; }",
                                 id: "submit", classes: ["primary"])
        XCTAssertEqual(style.item.grow, 3)
    }

    func testMatchesAnyOfMultipleClasses() {
        // Node carries two classes; each lone class selector matches.
        let (style, _) = resolve("""
            .primary { flex-grow: 1; }
            .large   { flex-basis: 200px; }
        """, id: "x", classes: ["primary", "large"])
        XCTAssertEqual(style.item.grow, 1)
        XCTAssertEqual(style.item.basis, .points(200))
    }

    func testClassSelectorWithoutClassDoesNotMatch() {
        let (style, _) = resolve(".primary { flex-grow: 9; }",
                                 id: "x", classes: [])
        XCTAssertEqual(style.item.grow, 0)          // default
    }

    func testIDBeatsClassOnSpecificity() {
        let (style, _) = resolve("""
            .primary { flex-grow: 1; }
            #submit  { flex-grow: 7; }
        """, id: "submit", classes: ["primary"])
        XCTAssertEqual(style.item.grow, 7)
    }

    func testClassBeatsElementOnSpecificity() {
        let (style, _) = resolve("""
            button   { flex-grow: 1; }
            .primary { flex-grow: 5; }
        """, id: "x", schemaType: "button", classes: ["primary"])
        XCTAssertEqual(style.item.grow, 5)
    }

    // MARK: - Compound selectors (Phase 2)

    func testCompoundSelectorMatchesOnlyWhenAllPartsMatch() {
        // `button.primary#submit` matches iff schemaType=="button" AND
        // classes contains "primary" AND id=="submit".
        let css = "button.primary#submit { flex-grow: 7; }"
        let (match, _)  = resolve(css,
                                  id: "submit", schemaType: "button",
                                  classes: ["primary"])
        XCTAssertEqual(match.item.grow, 7)

        // Drop any one part → the rule no longer matches.
        let (miss1, _) = resolve(css, id: "submit", schemaType: "button",
                                 classes: [])
        XCTAssertEqual(miss1.item.grow, 0)
        let (miss2, _) = resolve(css, id: "other",  schemaType: "button",
                                 classes: ["primary"])
        XCTAssertEqual(miss2.item.grow, 0)
        let (miss3, _) = resolve(css, id: "submit", schemaType: "input",
                                 classes: ["primary"])
        XCTAssertEqual(miss3.item.grow, 0)
    }

    func testCompoundSelectorSpecificityBeatsBareID() {
        // `#submit` (0,1,0,0) vs `button#submit.primary` (0,1,1,1) — compound
        // wins even though it appears first.
        let (style, _) = resolve("""
            button#submit.primary { flex-grow: 9; }
            #submit               { flex-grow: 1; }
        """, id: "submit", schemaType: "button", classes: ["primary"])
        XCTAssertEqual(style.item.grow, 9)
    }

    // MARK: - Combinator matching (Phase 2)

    /// Helper: resolve with an explicit ancestor chain (innermost parent first).
    private func resolveWithAncestors(
        _ css: String,
        id: String = "a",
        schemaType: String? = nil,
        classes: [String] = [],
        ancestors: [StyleResolver.NodeRef]
    ) -> (ComputedStyle, JoyDiagnostics) {
        var diags = JoyDiagnostics()
        let sheet = CSSParser.parse(css, diagnostics: &diags)
        let style = StyleResolver.resolve(
            id: id,
            schemaType: schemaType,
            classes: classes,
            ancestors: ancestors,
            stylesheet: sheet,
            diagnostics: &diags
        )
        return (style, diags)
    }

    func testDescendantCombinatorMatchesDirectParent() {
        let ancestors: [StyleResolver.NodeRef] = [
            .init(id: "form", schemaType: nil, classes: []),
        ]
        let (style, _) = resolveWithAncestors(
            "#form #name { flex-grow: 3; }",
            id: "name", ancestors: ancestors
        )
        XCTAssertEqual(style.item.grow, 3)
    }

    func testDescendantCombinatorMatchesGrandparent() {
        // obj has ancestor chain row→form; selector `#form #obj` must match
        // across the `row` gap.
        let ancestors: [StyleResolver.NodeRef] = [
            .init(id: "row",  schemaType: nil, classes: []),
            .init(id: "form", schemaType: nil, classes: []),
        ]
        let (style, _) = resolveWithAncestors(
            "#form #obj { flex-grow: 4; }",
            id: "obj", ancestors: ancestors
        )
        XCTAssertEqual(style.item.grow, 4)
    }

    func testDescendantCombinatorDoesNotMatchUnrelatedSubtree() {
        // Subject's ancestor is `other`, not `form`.
        let ancestors: [StyleResolver.NodeRef] = [
            .init(id: "other", schemaType: nil, classes: []),
        ]
        let (style, _) = resolveWithAncestors(
            "#form #name { flex-grow: 9; }",
            id: "name", ancestors: ancestors
        )
        XCTAssertEqual(style.item.grow, 0)
    }

    func testChildCombinatorRequiresImmediateParent() {
        // `#form > #name` matches only when form is the IMMEDIATE parent.
        let immediate: [StyleResolver.NodeRef] = [
            .init(id: "form", schemaType: nil, classes: []),
        ]
        let (yes, _) = resolveWithAncestors(
            "#form > #name { flex-grow: 5; }",
            id: "name", ancestors: immediate
        )
        XCTAssertEqual(yes.item.grow, 5)

        // With a `row` between name and form, child combinator must NOT match.
        let viaRow: [StyleResolver.NodeRef] = [
            .init(id: "row",  schemaType: nil, classes: []),
            .init(id: "form", schemaType: nil, classes: []),
        ]
        let (no, _) = resolveWithAncestors(
            "#form > #name { flex-grow: 5; }",
            id: "name", ancestors: viaRow
        )
        XCTAssertEqual(no.item.grow, 0)
    }

    func testMixedChildAndDescendantChain() {
        // `#form > .row input` — form is immediate parent of a `.row`, which
        // is any ancestor of the subject `input`.
        let ancestors: [StyleResolver.NodeRef] = [
            .init(id: "cell", schemaType: nil, classes: []),
            .init(id: "x",    schemaType: nil, classes: ["row"]),
            .init(id: "form", schemaType: nil, classes: []),
        ]
        let (style, _) = resolveWithAncestors(
            "#form > .row input { flex-grow: 2; }",
            id: "i", schemaType: "input", ancestors: ancestors
        )
        XCTAssertEqual(style.item.grow, 2)
    }

    // Regression: greedy right-to-left matching used to pick the innermost
    // `.row` unconditionally, then fail the `#form >` constraint against
    // that `.row`'s parent. The correct match requires the OUTER `.row`,
    // which backtracking must find.
    func testMixedCombinatorsFindValidMatchWithBacktracking() {
        // Tree: #form > .row(outer) > .cell > .row(inner) > input
        // Selector: `#form > .row input`
        //   - subject: input ✓
        //   - `.row` ancestor (descendant): two candidates
        //   - `#form >` child: only the OUTER .row's parent is #form
        let ancestors: [StyleResolver.NodeRef] = [
            .init(id: "inner", schemaType: nil, classes: ["row"]),
            .init(id: "cell",  schemaType: nil, classes: []),
            .init(id: "outer", schemaType: nil, classes: ["row"]),
            .init(id: "form",  schemaType: nil, classes: []),
        ]
        let (style, _) = resolveWithAncestors(
            "#form > .row input { flex-grow: 7; }",
            id: "i", schemaType: "input", ancestors: ancestors
        )
        XCTAssertEqual(style.item.grow, 7,
                       "matcher must backtrack past the inner .row to find the match")
    }

    func testMixedCombinatorsRejectWhenNoMatchExists() {
        // Same shape but the outer .row's parent is NOT #form → no match
        // regardless of backtracking. Sanity: backtracking doesn't over-match.
        let ancestors: [StyleResolver.NodeRef] = [
            .init(id: "inner", schemaType: nil, classes: ["row"]),
            .init(id: "cell",  schemaType: nil, classes: []),
            .init(id: "outer", schemaType: nil, classes: ["row"]),
            .init(id: "wrap",  schemaType: nil, classes: []),   // not #form
        ]
        let (style, _) = resolveWithAncestors(
            "#form > .row input { flex-grow: 7; }",
            id: "i", schemaType: "input", ancestors: ancestors
        )
        XCTAssertEqual(style.item.grow, 0)
    }

    func testIDBeatsElement() {
        let (style, _) = resolve("""
            button { flex-grow: 1; }
            #a     { flex-grow: 5; }
        """, id: "a", schemaType: "button")
        XCTAssertEqual(style.item.grow, 5)
    }

    func testElementLosesToIDEvenIfLater() {
        let (style, _) = resolve("""
            #a     { flex-grow: 5; }
            button { flex-grow: 1; }
        """, id: "a", schemaType: "button")
        XCTAssertEqual(style.item.grow, 5)
    }

    // MARK: - Container properties

    func testResolvesContainerProperties() {
        let (style, _) = resolve("""
            #a {
                display: flex;
                flex-direction: column;
                justify-content: center;
                align-items: center;
                gap: 12px;
                padding: 8px;
            }
        """)
        XCTAssertEqual(style.container.direction, .column)
        XCTAssertEqual(style.container.justifyContent, .center)
        XCTAssertEqual(style.container.alignItems, .center)
        XCTAssertEqual(style.container.gap, 12)
        XCTAssertEqual(style.container.padding.top, 8)
        XCTAssertEqual(style.container.padding.bottom, 8)
        XCTAssertEqual(style.container.padding.leading, 8)
        XCTAssertEqual(style.container.padding.trailing, 8)
    }

    func testPaddingShorthandTwoValues() {
        let (style, _) = resolve("#a { padding: 10px 20px; }")
        XCTAssertEqual(style.container.padding.top, 10)
        XCTAssertEqual(style.container.padding.bottom, 10)
        XCTAssertEqual(style.container.padding.leading, 20)
        XCTAssertEqual(style.container.padding.trailing, 20)
    }

    func testPaddingShorthandFourValues() {
        let (style, _) = resolve("#a { padding: 1px 2px 3px 4px; }")
        XCTAssertEqual(style.container.padding.top, 1)
        XCTAssertEqual(style.container.padding.trailing, 2)
        XCTAssertEqual(style.container.padding.bottom, 3)
        XCTAssertEqual(style.container.padding.leading, 4)
    }

    func testGapTwoValuesSplitsRowColumn() {
        let (style, _) = resolve("#a { gap: 4px 16px; }")
        XCTAssertEqual(style.container.rowGap, 4)
        XCTAssertEqual(style.container.columnGap, 16)
    }

    // MARK: - Item properties

    func testResolvesFlexShorthand_singleNumber() {
        let (style, _) = resolve("#a { flex: 2; }")
        XCTAssertEqual(style.item.grow, 2)
        XCTAssertEqual(style.item.shrink, 1)
        XCTAssertEqual(style.item.basis, .points(0))
    }

    func testResolvesFlexShorthand_triplet() {
        let (style, _) = resolve("#a { flex: 1 0 120px; }")
        XCTAssertEqual(style.item.grow, 1)
        XCTAssertEqual(style.item.shrink, 0)
        XCTAssertEqual(style.item.basis, .points(120))
    }

    func testResolvesFlexShorthand_keywords() {
        let (auto, _) = resolve("#a { flex: auto; }")
        XCTAssertEqual(auto.item.grow, 1)
        XCTAssertEqual(auto.item.shrink, 1)
        XCTAssertEqual(auto.item.basis, .auto)

        let (none, _) = resolve("#a { flex: none; }")
        XCTAssertEqual(none.item.grow, 0)
        XCTAssertEqual(none.item.shrink, 0)
        XCTAssertEqual(none.item.basis, .auto)
    }

    func testResolvesPositionAndInsets() {
        let (style, _) = resolve("""
            #a {
                position: absolute;
                top: 4px;
                right: 8px;
                bottom: 12px;
                left: 16px;
                z-index: 3;
            }
        """)
        XCTAssertEqual(style.item.position, .absolute)
        XCTAssertEqual(style.item.top, 4)
        XCTAssertEqual(style.item.trailing, 8)
        XCTAssertEqual(style.item.bottom, 12)
        XCTAssertEqual(style.item.leading, 16)
        XCTAssertEqual(style.item.zIndex, 3)
    }

    func testResolvesWidthHeightOverflow() {
        let (style, _) = resolve("""
            #a {
                width: 240px;
                height: 50%;
                overflow: hidden;
            }
        """)
        XCTAssertEqual(style.item.width, .points(240))
        XCTAssertEqual(style.item.height, .fraction(0.5))
        XCTAssertEqual(style.item.overflow, .hidden)
    }

    func testResolvesAlignSelfAndOrder() {
        let (style, _) = resolve("#a { align-self: center; order: -1; }")
        XCTAssertEqual(style.item.alignSelf, .center)
        XCTAssertEqual(style.item.order, -1)
    }

    func testResolvesDisplay() {
        let (style, _) = resolve("#a { display: block; }")
        XCTAssertEqual(style.display, .block)
    }

    // MARK: - Invalid-value diagnostics

    func testInvalidEnumValueEmitsDiagnosticAndKeepsDefault() {
        let (style, diags) = resolve("#a { flex-direction: diagonal; flex-grow: 1; }")
        // Invalid flex-direction — dropped.
        XCTAssertEqual(style.container.direction, .row)  // default
        // But the rest of the rule still applies.
        XCTAssertEqual(style.item.grow, 1)
        XCTAssertEqual(diags.count(of: .invalidValue(property: "flex-direction", value: "diagonal")), 1)
    }

    // Regression: invalid flex-basis / width / height used to silently reset
    // to `.auto`, overwriting any earlier valid declaration. The CSS spec
    // says invalid declarations are ignored; we now emit a diagnostic and
    // preserve the prior value.

    func testInvalidFlexBasisDoesNotClobberEarlierValidValue() {
        let (style, diags) = resolve("""
            #a { flex-basis: 100px; }
            #a { flex-basis: banana; }
        """)
        XCTAssertEqual(style.item.basis, .points(100),
                       "invalid flex-basis must not reset to .auto")
        XCTAssertEqual(diags.count(of: .invalidValue(property: "flex-basis", value: "banana")), 1)
    }

    func testInvalidWidthDoesNotClobberEarlierValidValue() {
        let (style, diags) = resolve("""
            #a { width: 240px; }
            #a { width: nonsense; }
        """)
        XCTAssertEqual(style.item.width, .points(240))
        XCTAssertEqual(diags.count(of: .invalidValue(property: "width", value: "nonsense")), 1)
    }

    func testInvalidHeightDoesNotClobberEarlierValidValue() {
        let (style, diags) = resolve("""
            #a { height: 80%; }
            #a { height: tall; }
        """)
        XCTAssertEqual(style.item.height, .fraction(0.8))
        XCTAssertEqual(diags.count(of: .invalidValue(property: "height", value: "tall")), 1)
    }

    // MARK: - `display: none`

    /// `display: none` has no matching FlexDisplay case, so we carry it as
    /// a separate flag on ComputedStyle. The cascade must set the flag
    /// without emitting an invalidValue diagnostic — `none` is a valid CSS
    /// value, just one that triggers subtree removal at resolve time.
    func testDisplayNoneSetsFlagWithoutWarning() {
        let (style, diags) = resolve("#a { display: none; }")
        XCTAssertTrue(style.isDisplayNone)
        XCTAssertEqual(
            diags.count(of: .invalidValue(property: "display", value: "none")),
            0
        )
    }

    /// A later `display: flex` cleanly un-hides the node (cascade still
    /// applies last-wins on the flag, so authors can override earlier
    /// `display: none` declarations).
    func testLaterDisplayFlexClearsDisplayNoneFlag() {
        let (style, _) = resolve("""
            #a { display: none; }
            #a { display: flex; }
        """)
        XCTAssertFalse(style.isDisplayNone)
        XCTAssertEqual(style.display, .flex)
    }

    // MARK: - `visibility: hidden` (Phase 2)

    /// Unlike `display: none`, `visibility: hidden` keeps the node in the
    /// layout (it still reserves space) but hides its painted content. We
    /// track it as a separate flag on ComputedStyle so the resolver can
    /// wrap the node's view in `.hidden()` without removing it from the
    /// flex tree.
    func testVisibilityHiddenSetsFlagWithoutWarning() {
        let (style, diags) = resolve("#a { visibility: hidden; }")
        XCTAssertTrue(style.isVisibilityHidden)
        XCTAssertFalse(style.isDisplayNone,
                       "visibility:hidden must NOT set the display:none flag")
        XCTAssertEqual(
            diags.count(of: .invalidValue(property: "visibility", value: "hidden")),
            0
        )
        XCTAssertFalse(
            diags.warnings.contains { $0.kind == .unsupportedProperty("visibility") }
        )
    }

    /// `visibility: visible` is the default and must clear a prior
    /// `hidden` so the cascade stays last-wins.
    func testLaterVisibilityVisibleClearsHiddenFlag() {
        let (style, _) = resolve("""
            #a { visibility: hidden; }
            #a { visibility: visible; }
        """)
        XCTAssertFalse(style.isVisibilityHidden)
    }

    /// Unknown values (e.g. `collapse`, which applies only to table rows
    /// in CSS 2.1) are rejected with an `.invalidValue` diagnostic and do
    /// not clobber a prior valid value.
    func testInvalidVisibilityValueDoesNotClobberEarlierValidValue() {
        let (style, diags) = resolve("""
            #a { visibility: hidden; }
            #a { visibility: collapse; }
        """)
        XCTAssertTrue(style.isVisibilityHidden,
                      "invalid visibility value must not reset the flag")
        XCTAssertEqual(
            diags.count(of: .invalidValue(property: "visibility", value: "collapse")),
            1
        )
    }
}
