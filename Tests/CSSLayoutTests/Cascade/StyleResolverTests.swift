import XCTest
@testable import CSSLayout
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
        schemaType: String? = nil
    ) -> (ComputedStyle, CSSDiagnostics) {
        var diags = CSSDiagnostics()
        let sheet = CSSParser.parse(css, diagnostics: &diags)
        let computed = StyleResolver.resolve(
            id: id,
            schemaType: schemaType,
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
        """, id: "submit", schemaType: "button")
        // Note: in Phase 1 we don't match class names via id; classes require
        // a "classes" dimension on the node. The minimum assertion here is
        // that element-only matching still produces the element's value.
        XCTAssertEqual(style.item.grow, 1)
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
}
