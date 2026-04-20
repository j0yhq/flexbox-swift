import XCTest
@testable import CSSLayout
import FlexLayout
import CoreGraphics

/// Unit (c) — property-value parsers lifted from `FlexDemoApp/CSSParser.swift`.
///
/// Every parser is pure, synchronous, and returns `nil` (or a sensible default)
/// on garbage. Cascade-level recovery is the caller's responsibility.
final class CSSValueParsersTests: XCTestCase {

    // MARK: - parsePx

    func testParsePx_pixels() {
        XCTAssertEqual(CSSValueParsers.parsePx("16px"), 16)
        XCTAssertEqual(CSSValueParsers.parsePx("0px"),  0)
    }

    func testParsePx_pointsAndUnitlessTreatedAsPoints() {
        XCTAssertEqual(CSSValueParsers.parsePx("12pt"), 12)
        XCTAssertEqual(CSSValueParsers.parsePx("12"),   12)
    }

    func testParsePx_emAndRemUseSixteenPxRoot() {
        XCTAssertEqual(CSSValueParsers.parsePx("1em"),   16)
        XCTAssertEqual(CSSValueParsers.parsePx("0.5em"), 8)
        XCTAssertEqual(CSSValueParsers.parsePx("2rem"),  32)
    }

    func testParsePx_trimsAndLowercases() {
        XCTAssertEqual(CSSValueParsers.parsePx("  16PX  "), 16)
    }

    func testParsePx_rejectsGarbage() {
        XCTAssertNil(CSSValueParsers.parsePx("abc"))
        XCTAssertNil(CSSValueParsers.parsePx(""))
    }

    // MARK: - parseFlexBasis

    func testParseFlexBasis_auto() {
        XCTAssertEqual(CSSValueParsers.parseFlexBasis("auto"), .auto)
    }

    func testParseFlexBasis_points() {
        XCTAssertEqual(CSSValueParsers.parseFlexBasis("120px"), .points(120))
    }

    func testParseFlexBasis_fraction() {
        XCTAssertEqual(CSSValueParsers.parseFlexBasis("50%"), .fraction(0.5))
    }

    func testParseFlexBasis_invalidFallsBackToAuto() {
        XCTAssertEqual(CSSValueParsers.parseFlexBasis("banana"), .auto)
    }

    // MARK: - parseFlexSize

    func testParseFlexSize_auto() {
        XCTAssertEqual(CSSValueParsers.parseFlexSize("auto"), .auto)
    }

    func testParseFlexSize_minContent() {
        XCTAssertEqual(CSSValueParsers.parseFlexSize("min-content"), .minContent)
    }

    func testParseFlexSize_percent() {
        XCTAssertEqual(CSSValueParsers.parseFlexSize("75%"), .fraction(0.75))
    }

    func testParseFlexSize_pixels() {
        XCTAssertEqual(CSSValueParsers.parseFlexSize("240px"), .points(240))
    }

    func testParseFlexSize_invalidFallsBackToAuto() {
        XCTAssertEqual(CSSValueParsers.parseFlexSize("nonsense"), .auto)
    }

    // MARK: - parseOverflow

    func testParseOverflow_allSupported() {
        XCTAssertEqual(CSSValueParsers.parseOverflow("visible"), .visible)
        XCTAssertEqual(CSSValueParsers.parseOverflow("hidden"),  .hidden)
        XCTAssertEqual(CSSValueParsers.parseOverflow("clip"),    .clip)
        XCTAssertEqual(CSSValueParsers.parseOverflow("scroll"),  .scroll)
        XCTAssertEqual(CSSValueParsers.parseOverflow("auto"),    .auto)
    }

    func testParseOverflow_unknown() {
        XCTAssertNil(CSSValueParsers.parseOverflow("weird"))
    }

    // MARK: - parsePosition

    func testParsePosition_supported() {
        XCTAssertEqual(CSSValueParsers.parsePosition("relative"), .relative)
        XCTAssertEqual(CSSValueParsers.parsePosition("absolute"), .absolute)
    }

    func testParsePosition_unsupportedReturnsNil() {
        // Phase 1 explicitly does not support `fixed` or `sticky`.
        XCTAssertNil(CSSValueParsers.parsePosition("fixed"))
        XCTAssertNil(CSSValueParsers.parsePosition("sticky"))
    }

    // MARK: - parseFlexDirection

    func testParseFlexDirection_allFourValues() {
        XCTAssertEqual(CSSValueParsers.parseFlexDirection("row"),            .row)
        XCTAssertEqual(CSSValueParsers.parseFlexDirection("row-reverse"),    .rowReverse)
        XCTAssertEqual(CSSValueParsers.parseFlexDirection("column"),         .column)
        XCTAssertEqual(CSSValueParsers.parseFlexDirection("column-reverse"), .columnReverse)
    }

    func testParseFlexDirection_unknown() {
        XCTAssertNil(CSSValueParsers.parseFlexDirection("diagonal"))
    }

    // MARK: - parseFlexWrap

    func testParseFlexWrap_allValues() {
        XCTAssertEqual(CSSValueParsers.parseFlexWrap("nowrap"),       .nowrap)
        XCTAssertEqual(CSSValueParsers.parseFlexWrap("wrap"),         .wrap)
        XCTAssertEqual(CSSValueParsers.parseFlexWrap("wrap-reverse"), .wrapReverse)
    }

    // MARK: - parseJustifyContent

    func testParseJustifyContent_startEndAliases() {
        XCTAssertEqual(CSSValueParsers.parseJustifyContent("start"),      .flexStart)
        XCTAssertEqual(CSSValueParsers.parseJustifyContent("flex-start"), .flexStart)
        XCTAssertEqual(CSSValueParsers.parseJustifyContent("left"),       .flexStart)
        XCTAssertEqual(CSSValueParsers.parseJustifyContent("end"),        .flexEnd)
        XCTAssertEqual(CSSValueParsers.parseJustifyContent("flex-end"),   .flexEnd)
        XCTAssertEqual(CSSValueParsers.parseJustifyContent("right"),      .flexEnd)
    }

    func testParseJustifyContent_distribution() {
        XCTAssertEqual(CSSValueParsers.parseJustifyContent("center"),        .center)
        XCTAssertEqual(CSSValueParsers.parseJustifyContent("space-between"), .spaceBetween)
        XCTAssertEqual(CSSValueParsers.parseJustifyContent("space-around"),  .spaceAround)
        XCTAssertEqual(CSSValueParsers.parseJustifyContent("space-evenly"),  .spaceEvenly)
    }

    // MARK: - parseAlignItems

    func testParseAlignItems_allValues() {
        XCTAssertEqual(CSSValueParsers.parseAlignItems("flex-start"), .flexStart)
        XCTAssertEqual(CSSValueParsers.parseAlignItems("start"),      .flexStart)
        XCTAssertEqual(CSSValueParsers.parseAlignItems("flex-end"),   .flexEnd)
        XCTAssertEqual(CSSValueParsers.parseAlignItems("end"),        .flexEnd)
        XCTAssertEqual(CSSValueParsers.parseAlignItems("center"),     .center)
        XCTAssertEqual(CSSValueParsers.parseAlignItems("stretch"),    .stretch)
        XCTAssertEqual(CSSValueParsers.parseAlignItems("baseline"),   .baseline)
    }

    // MARK: - parseAlignContent

    func testParseAlignContent_allValues() {
        XCTAssertEqual(CSSValueParsers.parseAlignContent("flex-start"),    .flexStart)
        XCTAssertEqual(CSSValueParsers.parseAlignContent("flex-end"),      .flexEnd)
        XCTAssertEqual(CSSValueParsers.parseAlignContent("center"),        .center)
        XCTAssertEqual(CSSValueParsers.parseAlignContent("space-between"), .spaceBetween)
        XCTAssertEqual(CSSValueParsers.parseAlignContent("space-around"),  .spaceAround)
        XCTAssertEqual(CSSValueParsers.parseAlignContent("space-evenly"),  .spaceEvenly)
        XCTAssertEqual(CSSValueParsers.parseAlignContent("stretch"),       .stretch)
    }

    // MARK: - parseAlignSelf

    func testParseAlignSelf_allValues() {
        XCTAssertEqual(CSSValueParsers.parseAlignSelf("auto"),       .auto)
        XCTAssertEqual(CSSValueParsers.parseAlignSelf("flex-start"), .flexStart)
        XCTAssertEqual(CSSValueParsers.parseAlignSelf("flex-end"),   .flexEnd)
        XCTAssertEqual(CSSValueParsers.parseAlignSelf("center"),     .center)
        XCTAssertEqual(CSSValueParsers.parseAlignSelf("stretch"),    .stretch)
        XCTAssertEqual(CSSValueParsers.parseAlignSelf("baseline"),   .baseline)
    }

    func testParseAlignSelf_unknown() {
        XCTAssertNil(CSSValueParsers.parseAlignSelf("weird"))
    }

    // MARK: - parseDisplay

    func testParseDisplay_supported() {
        XCTAssertEqual(CSSValueParsers.parseDisplay("flex"),   .flex)
        XCTAssertEqual(CSSValueParsers.parseDisplay("block"),  .block)
        XCTAssertEqual(CSSValueParsers.parseDisplay("inline"), .inline)
    }

    func testParseDisplay_inlineFlexMapsToFlex() {
        XCTAssertEqual(CSSValueParsers.parseDisplay("inline-flex"), .flex)
    }

    func testParseDisplay_unsupportedReturnsNil() {
        // Phase 1 does not support `display: none` — drop with diagnostic.
        XCTAssertNil(CSSValueParsers.parseDisplay("none"))
        XCTAssertNil(CSSValueParsers.parseDisplay("grid"))
    }
}
