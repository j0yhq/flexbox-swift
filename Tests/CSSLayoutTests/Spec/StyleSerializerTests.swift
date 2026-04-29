import XCTest
@testable import CSSLayout

/// Unit 2 — `StyleSerializer.serialize(_:)` turns a `Style` (the Swift
/// mirror of joy-dom's `Style` interface) into CSS declaration text that
/// CSSLayout's existing parser already accepts.
///
/// Two-layer test strategy:
///
///   1. **Golden-string tests** assert that each individual `Style`
///      field serializes to a specific declaration. This locks down the
///      wire format (property name spelling, unit suffix, ordering).
///
///   2. **Round-trip-through-parser tests** feed the serializer's output
///      back into `CSSParser` and assert the parser accepts every
///      production without warnings. This guarantees we never emit a
///      declaration the cascade can't honor — the serializer and parser
///      stay in lockstep.
final class StyleSerializerTests: XCTestCase {

    // MARK: - Empty style

    func testEmptyStyleSerializesToEmptyString() {
        XCTAssertEqual(StyleSerializer.serialize(Style()), "")
    }

    func testEmptyStyleRuleIsEmpty() {
        XCTAssertEqual(StyleSerializer.rule(selector: "#x", style: Style()), "")
    }

    // MARK: - Single-field declarations

    func testPositionRelative() {
        XCTAssertEqual(
            StyleSerializer.serialize(Style(position: .relative)),
            "position: relative;"
        )
    }

    func testPositionAbsolute() {
        XCTAssertEqual(
            StyleSerializer.serialize(Style(position: .absolute)),
            "position: absolute;"
        )
    }

    func testDisplayFlex() {
        XCTAssertEqual(
            StyleSerializer.serialize(Style(display: .flex)),
            "display: flex;"
        )
    }

    func testDisplayInlineBlock() {
        XCTAssertEqual(
            StyleSerializer.serialize(Style(display: .inlineBlock)),
            "display: inline-block;"
        )
    }

    func testZIndex() {
        XCTAssertEqual(
            StyleSerializer.serialize(Style(zIndex: 5)),
            "z-index: 5;"
        )
    }

    func testOverflow() {
        XCTAssertEqual(
            StyleSerializer.serialize(Style(overflow: .hidden)),
            "overflow: hidden;"
        )
    }

    func testTopBottomLeftRight() {
        XCTAssertEqual(
            StyleSerializer.serialize(Style(top: .px(10))),
            "top: 10px;"
        )
        XCTAssertEqual(
            StyleSerializer.serialize(Style(left: .px(20))),
            "left: 20px;"
        )
        XCTAssertEqual(
            StyleSerializer.serialize(Style(bottom: .px(30))),
            "bottom: 30px;"
        )
        XCTAssertEqual(
            StyleSerializer.serialize(Style(right: .px(40))),
            "right: 40px;"
        )
    }

    func testFlexDirection() {
        XCTAssertEqual(
            StyleSerializer.serialize(Style(flexDirection: .row)),
            "flex-direction: row;"
        )
        XCTAssertEqual(
            StyleSerializer.serialize(Style(flexDirection: .column)),
            "flex-direction: column;"
        )
    }

    func testFlexGrow() {
        XCTAssertEqual(
            StyleSerializer.serialize(Style(flexGrow: 1)),
            "flex-grow: 1;"
        )
    }

    func testFlexShrink() {
        XCTAssertEqual(
            StyleSerializer.serialize(Style(flexShrink: 0)),
            "flex-shrink: 0;"
        )
    }

    func testFlexBasisPx() {
        XCTAssertEqual(
            StyleSerializer.serialize(Style(flexBasis: .px(100))),
            "flex-basis: 100px;"
        )
    }

    func testFlexBasisPercent() {
        XCTAssertEqual(
            StyleSerializer.serialize(Style(flexBasis: .percent(50))),
            "flex-basis: 50%;"
        )
    }

    func testJustifyContent() {
        XCTAssertEqual(
            StyleSerializer.serialize(Style(justifyContent: .spaceBetween)),
            "justify-content: space-between;"
        )
    }

    func testAlignItems() {
        XCTAssertEqual(
            StyleSerializer.serialize(Style(alignItems: .center)),
            "align-items: center;"
        )
    }

    func testFlexWrap() {
        XCTAssertEqual(
            StyleSerializer.serialize(Style(flexWrap: .wrap)),
            "flex-wrap: wrap;"
        )
        XCTAssertEqual(
            StyleSerializer.serialize(Style(flexWrap: .nowrap)),
            "flex-wrap: nowrap;"
        )
    }

    func testGapUniform() {
        XCTAssertEqual(
            StyleSerializer.serialize(Style(gap: .uniform(.px(8)))),
            "gap: 8px;"
        )
    }

    func testGapAxesEmitsRowFirst() {
        // CSS `gap: <row-gap> <column-gap>` — joy-dom's `{ c, r }`
        // serializes to row-then-column to match the CSS grammar.
        XCTAssertEqual(
            StyleSerializer.serialize(Style(gap: .axes(column: .px(4), row: .px(8)))),
            "gap: 8px 4px;"
        )
    }

    func testOrder() {
        XCTAssertEqual(
            StyleSerializer.serialize(Style(order: 2)),
            "order: 2;"
        )
    }

    func testWidthAndHeight() {
        XCTAssertEqual(
            StyleSerializer.serialize(Style(width: .percent(100))),
            "width: 100%;"
        )
        XCTAssertEqual(
            StyleSerializer.serialize(Style(height: .px(120))),
            "height: 120px;"
        )
    }

    func testPaddingUniform() {
        XCTAssertEqual(
            StyleSerializer.serialize(Style(padding: .uniform(.px(12)))),
            "padding: 12px;"
        )
    }

    func testPaddingSidesEmitsTopRightBottomLeft() {
        // CSS shorthand order: top right bottom left.
        let style = Style(padding: .sides(
            top: .px(1), right: .px(2), bottom: .px(3), left: .px(4)
        ))
        XCTAssertEqual(
            StyleSerializer.serialize(style),
            "padding: 1px 2px 3px 4px;"
        )
    }

    // MARK: - Combination

    func testMultipleFieldsJoinedWithSpaces() {
        let style = Style(
            display: .flex,
            flexDirection: .row,
            gap: .uniform(.px(8))
        )
        // Order matches the property order on `Style` itself: display
        // before flexDirection before gap. Stable ordering keeps the
        // output deterministic for golden-string tests.
        XCTAssertEqual(
            StyleSerializer.serialize(style),
            "display: flex; flex-direction: row; gap: 8px;"
        )
    }

    func testRuleWrapsDeclarationsInSelector() {
        let style = Style(flexDirection: .column)
        XCTAssertEqual(
            StyleSerializer.rule(selector: "#root", style: style),
            "#root { flex-direction: column; }"
        )
    }

    func testRuleWithMultipleDeclarations() {
        let style = Style(display: .flex, flexDirection: .row)
        XCTAssertEqual(
            StyleSerializer.rule(selector: ".container", style: style),
            ".container { display: flex; flex-direction: row; }"
        )
    }

    // MARK: - Length number formatting

    func testIntegerLengthHasNoDecimal() {
        XCTAssertEqual(
            StyleSerializer.serialize(Style(width: .px(100))),
            "width: 100px;"
        )
    }

    func testFractionalLengthKeepsDecimals() {
        XCTAssertEqual(
            StyleSerializer.serialize(Style(width: Length(value: 12.5, unit: "px"))),
            "width: 12.5px;"
        )
    }

    // MARK: - Round-trip through the parser

    /// The serialized output must be a valid CSS document that
    /// `CSSParser` accepts without diagnostics. This is the contract
    /// that keeps the serializer and parser in sync.
    func testRoundTripThroughParserProducesNoDiagnostics() {
        let style = Style(
            position: .relative,
            display: .flex,
            zIndex: 5,
            overflow: .hidden,
            top: .px(10),
            flexDirection: .column,
            flexGrow: 1,
            flexShrink: 0,
            flexBasis: .percent(50),
            justifyContent: .spaceBetween,
            alignItems: .center,
            flexWrap: .wrap,
            gap: .uniform(.px(8)),
            order: 2,
            width: .percent(100),
            height: .px(120),
            padding: .uniform(.px(12))
        )
        let css = StyleSerializer.rule(selector: "#everything", style: style)
        var diagnostics = CSSDiagnostics()
        _ = CSSParser.parse(css, diagnostics: &diagnostics)
        XCTAssertTrue(
            diagnostics.warnings.isEmpty,
            "serializer emitted CSS the parser couldn't accept: \(diagnostics.warnings)"
        )
    }

    func testRoundTripGapAxesAcceptedByParser() {
        let css = StyleSerializer.rule(
            selector: "#g",
            style: Style(gap: .axes(column: .px(4), row: .px(8)))
        )
        var diagnostics = CSSDiagnostics()
        _ = CSSParser.parse(css, diagnostics: &diagnostics)
        XCTAssertTrue(diagnostics.warnings.isEmpty, "diagnostics: \(diagnostics.warnings)")
    }

    func testRoundTripPaddingSidesAcceptedByParser() {
        let css = StyleSerializer.rule(
            selector: "#p",
            style: Style(padding: .sides(
                top: .px(1), right: .px(2), bottom: .px(3), left: .px(4)
            ))
        )
        var diagnostics = CSSDiagnostics()
        _ = CSSParser.parse(css, diagnostics: &diagnostics)
        XCTAssertTrue(diagnostics.warnings.isEmpty, "diagnostics: \(diagnostics.warnings)")
    }
}
