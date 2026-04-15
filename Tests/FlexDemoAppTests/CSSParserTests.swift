import XCTest
import FlexLayout
@testable import FlexDemoApp

final class CSSParserTests: XCTestCase {

    private let pricingCSS = """
    .pricing {
      display: flex;
      flex-direction: column;
      align-items: center;
      gap: 32px;
      padding: 40px 24px;
      overflow: auto;
    }

    .pricing > .plans {
      display: flex;
      flex-direction: row;
      flex-wrap: wrap;
      gap: 20px;
      justify-content: center;
      align-items: flex-start;
      width: 100%;
    }

    .pricing > .plans > .plan {
      display: flex;
      flex-direction: column;
      flex-grow: 0;
      flex-shrink: 0;
      flex-basis: 280px;
      overflow: hidden;
      position: relative;
      --repeat: 3;
    }

    .plan > .feature-list {
      display: flex;
      flex-direction: column;
      gap: 10px;
      padding: 16px 20px;
      flex-grow: 1;
    }

    .feature-list > .feature {
      flex-shrink: 0;
      height: 22px;
      --repeat: 4;
    }

    @media (max-width: 768px) {
      .pricing {
        align-items: stretch;
        padding: 20px 12px;
        gap: 16px;
      }

      .pricing > .plans {
        flex-direction: column;
        flex-wrap: nowrap;
        justify-content: flex-start;
        align-items: stretch;
        gap: 12px;
      }

      .pricing > .plans > .plan {
        width: 100%;
        flex-basis: auto;
      }
    }
    """

    func testPricingMediaOverridesMergeWithoutDuplicateContainersOnMobile() {
        let parsed = CSSParser.parse(pricingCSS, viewportWidth: 375)

        XCTAssertEqual(parsed.items.count, 1, "Root should contain only one .plans container item")
        guard let plans = parsed.items.first?.childCSS else {
            return XCTFail("Expected .pricing > .plans nested container")
        }

        XCTAssertEqual(plans.container.direction, .column)
        XCTAssertEqual(plans.container.wrap, .nowrap)
        XCTAssertEqual(plans.items.count, 3, "Expected three plan cards from --repeat: 3")

        let firstPlan = plans.items[0]
        XCTAssertEqual(firstPlan.width, .fraction(1))
        XCTAssertEqual(firstPlan.basis, .auto)
    }

    func testPricingKeepsDesktopLayoutAtWideViewport() {
        let parsed = CSSParser.parse(pricingCSS, viewportWidth: 1024)

        XCTAssertEqual(parsed.items.count, 1)
        guard let plans = parsed.items.first?.childCSS else {
            return XCTFail("Expected .pricing > .plans nested container")
        }

        XCTAssertEqual(plans.container.direction, .row)
        XCTAssertEqual(plans.container.wrap, .wrap)
        XCTAssertEqual(plans.items.count, 3)

        let firstPlan = plans.items[0]
        XCTAssertEqual(firstPlan.width, .auto)
        XCTAssertEqual(firstPlan.basis, .points(280))
    }

    func testDisplayBlockAndInlineAreBlockifiedForFlexItemPlacement() {
        let css = """
        .container {
          display: flex;
        }

        .container > .block-item {
          display: block;
        }

        .container > .inline-item {
          display: inline;
        }
        """

        let parsed = CSSParser.parse(css)
        XCTAssertEqual(parsed.items.count, 2)
        XCTAssertTrue(parsed.items.allSatisfy { $0.display == .flex })
    }

    // MARK: - Per-property parse tests (one per CSS property)

    func testFlexDirection_allValues() {
        func dir(_ v: String) -> FlexDirection {
            CSSParser.parse(".r { display:flex; flex-direction:\(v); }").container.direction
        }
        XCTAssertEqual(dir("row"),            .row)
        XCTAssertEqual(dir("column"),         .column)
        XCTAssertEqual(dir("row-reverse"),    .rowReverse)
        XCTAssertEqual(dir("column-reverse"), .columnReverse)
    }

    func testFlexWrap_allValues() {
        func wrap(_ v: String) -> FlexWrap {
            CSSParser.parse(".r { display:flex; flex-wrap:\(v); }").container.wrap
        }
        XCTAssertEqual(wrap("nowrap"),       .nowrap)
        XCTAssertEqual(wrap("wrap"),         .wrap)
        XCTAssertEqual(wrap("wrap-reverse"), .wrapReverse)
    }

    func testJustifyContent_allValues() {
        func jc(_ v: String) -> JustifyContent {
            CSSParser.parse(".r { display:flex; justify-content:\(v); }").container.justifyContent
        }
        XCTAssertEqual(jc("flex-start"),    .flexStart)
        XCTAssertEqual(jc("flex-end"),      .flexEnd)
        XCTAssertEqual(jc("center"),        .center)
        XCTAssertEqual(jc("space-between"), .spaceBetween)
        XCTAssertEqual(jc("space-around"),  .spaceAround)
        XCTAssertEqual(jc("space-evenly"),  .spaceEvenly)
    }

    func testAlignItems_allValues() {
        func ai(_ v: String) -> AlignItems {
            CSSParser.parse(".r { display:flex; align-items:\(v); }").container.alignItems
        }
        XCTAssertEqual(ai("flex-start"), .flexStart)
        XCTAssertEqual(ai("flex-end"),   .flexEnd)
        XCTAssertEqual(ai("center"),     .center)
        XCTAssertEqual(ai("stretch"),    .stretch)
        XCTAssertEqual(ai("baseline"),   .baseline)
    }

    func testAlignContent_allValues() {
        func ac(_ v: String) -> AlignContent {
            CSSParser.parse(".r { display:flex; align-content:\(v); }").container.alignContent
        }
        XCTAssertEqual(ac("flex-start"),    .flexStart)
        XCTAssertEqual(ac("flex-end"),      .flexEnd)
        XCTAssertEqual(ac("center"),        .center)
        XCTAssertEqual(ac("stretch"),       .stretch)
        XCTAssertEqual(ac("space-between"), .spaceBetween)
        XCTAssertEqual(ac("space-around"),  .spaceAround)
        XCTAssertEqual(ac("space-evenly"),  .spaceEvenly)
    }

    func testOverflow_allValues() {
        func ov(_ v: String) -> FlexOverflow {
            CSSParser.parse(".r { display:flex; overflow:\(v); }").container.overflow
        }
        XCTAssertEqual(ov("visible"), .visible)
        XCTAssertEqual(ov("hidden"),  .hidden)
        XCTAssertEqual(ov("clip"),    .clip)
        XCTAssertEqual(ov("scroll"),  .scroll)
        XCTAssertEqual(ov("auto"),    .auto)
    }

    func testGap_shorthand_setsBothAxes() {
        let c = CSSParser.parse(".r { display:flex; gap: 16px; }").container
        XCTAssertNil(c.rowGap,    "shorthand gap should leave rowGap nil (falls back to gap)")
        XCTAssertNil(c.columnGap, "shorthand gap should leave columnGap nil")
        XCTAssertEqual(c.gap, 16)
    }

    func testGap_twoValue_setsRowAndColumnSeparately() {
        let c = CSSParser.parse(".r { display:flex; gap: 20px 8px; }").container
        XCTAssertEqual(c.rowGap,    20)
        XCTAssertEqual(c.columnGap,  8)
    }

    func testPadding_fourValue_mapsToEdges() {
        // padding: top right bottom left
        let c = CSSParser.parse(".r { display:flex; padding: 1px 2px 3px 4px; }").container
        XCTAssertEqual(c.padding.top,      1)
        XCTAssertEqual(c.padding.trailing, 2)
        XCTAssertEqual(c.padding.bottom,   3)
        XCTAssertEqual(c.padding.leading,  4)
    }

    func testPadding_twoValue_mapsTopBottomAndLeftRight() {
        let c = CSSParser.parse(".r { display:flex; padding: 10px 20px; }").container
        XCTAssertEqual(c.padding.top,      10)
        XCTAssertEqual(c.padding.bottom,   10)
        XCTAssertEqual(c.padding.leading,  20)
        XCTAssertEqual(c.padding.trailing, 20)
    }

    func testItemFlexGrow_parsesNumericValue() throws {
        let css = ".r { display:flex; } .r>.i { flex-grow: 3; }"
        let item = try XCTUnwrap(CSSParser.parse(css).items.first)
        XCTAssertEqual(item.grow, 3)
    }

    func testItemFlexShrink_parsesNumericValue() throws {
        let css = ".r { display:flex; } .r>.i { flex-shrink: 0; }"
        let item = try XCTUnwrap(CSSParser.parse(css).items.first)
        XCTAssertEqual(item.shrink, 0)
    }

    func testItemFlexBasis_pixels() throws {
        let css = ".r { display:flex; } .r>.i { flex-basis: 150px; }"
        let item = try XCTUnwrap(CSSParser.parse(css).items.first)
        XCTAssertEqual(item.basis, .points(150))
    }

    func testItemFlexBasis_percentage() throws {
        let css = ".r { display:flex; } .r>.i { flex-basis: 33%; }"
        let item = try XCTUnwrap(CSSParser.parse(css).items.first)
        if case .fraction(let f) = item.basis {
            XCTAssertEqual(f, 0.33, accuracy: 0.001)
        } else {
            XCTFail("expected .fraction, got \(item.basis)")
        }
    }

    func testItemFlexBasis_auto() throws {
        let css = ".r { display:flex; } .r>.i { flex-basis: auto; }"
        let item = try XCTUnwrap(CSSParser.parse(css).items.first)
        XCTAssertEqual(item.basis, .auto)
    }

    func testItemWidth_minContent() throws {
        let css = ".r { display:flex; } .r>.i { width: min-content; }"
        let item = try XCTUnwrap(CSSParser.parse(css).items.first)
        XCTAssertEqual(item.width, .minContent)
    }

    func testItemHeight_pixels() throws {
        let css = ".r { display:flex; } .r>.i { height: 44px; }"
        let item = try XCTUnwrap(CSSParser.parse(css).items.first)
        XCTAssertEqual(item.height, .points(44))
    }

    func testItemPosition_absolute() throws {
        let css = ".r { display:flex; } .r>.i { position: absolute; }"
        let item = try XCTUnwrap(CSSParser.parse(css).items.first)
        XCTAssertEqual(item.position, .absolute)
    }

    func testItemOffsets_allFourSides() throws {
        let css = ".r { display:flex; } .r>.i { position:absolute; top:1px; bottom:2px; left:3px; right:4px; }"
        let item = try XCTUnwrap(CSSParser.parse(css).items.first)
        XCTAssertEqual(item.top,      1)
        XCTAssertEqual(item.bottom,   2)
        XCTAssertEqual(item.leading,  3)
        XCTAssertEqual(item.trailing, 4)
    }

    func testItemZIndex_parsesInteger() throws {
        let css = ".r { display:flex; } .r>.i { z-index: 5; }"
        let item = try XCTUnwrap(CSSParser.parse(css).items.first)
        XCTAssertEqual(item.zIndex, 5)
    }

    func testItemOrder_parsesInteger() throws {
        let css = ".r { display:flex; } .r>.i { order: -1; }"
        let item = try XCTUnwrap(CSSParser.parse(css).items.first)
        XCTAssertEqual(item.order, -1)
    }

    // MARK: - Invalid value fallback tests

    func testInvalidFlexDirection_fallsBackToRow() {
        let c = CSSParser.parse(".r { display:flex; flex-direction: diagonal; }").container
        XCTAssertEqual(c.direction, .row, "unknown direction should fall back to default .row")
    }

    func testInvalidFlexWrap_fallsBackToNowrap() {
        let c = CSSParser.parse(".r { display:flex; flex-wrap: zigzag; }").container
        XCTAssertEqual(c.wrap, .nowrap, "unknown wrap should fall back to default .nowrap")
    }

    func testInvalidJustifyContent_fallsBackToFlexStart() {
        let c = CSSParser.parse(".r { display:flex; justify-content: unicorn; }").container
        XCTAssertEqual(c.justifyContent, .flexStart)
    }

    func testInvalidAlignItems_fallsBackToStretch() {
        let c = CSSParser.parse(".r { display:flex; align-items: rainbow; }").container
        XCTAssertEqual(c.alignItems, .stretch)
    }

    func testInvalidGap_treatedAsZero() {
        let c = CSSParser.parse(".r { display:flex; gap: notapx; }").container
        XCTAssertEqual(c.gap, 0)
    }

    func testInvalidFlexBasis_fallsBackToAuto() throws {
        let css = ".r { display:flex; } .r>.i { flex-basis: notavalue; }"
        let item = try XCTUnwrap(CSSParser.parse(css).items.first)
        XCTAssertEqual(item.basis, .auto)
    }

    func testInvalidOverflow_fallsBackToVisible() {
        let c = CSSParser.parse(".r { display:flex; overflow: explode; }").container
        XCTAssertEqual(c.overflow, .visible)
    }

    func testInvalidPosition_fallsBackToRelative() throws {
        let css = ".r { display:flex; } .r>.i { position: floating; }"
        let item = try XCTUnwrap(CSSParser.parse(css).items.first)
        XCTAssertEqual(item.position, .relative)
    }

    // MARK: - Exhaustive property snapshot test

    func testParsesAllSupportedContainerAndItemProperties() throws {
        let css = """
        .root {
          display: flex;
          flex-direction: row-reverse;
          flex-wrap: wrap-reverse;
          justify-content: space-around;
          align-items: flex-end;
          gap: 12px 8px;
          padding: 1px 2px 3px 4px;
          overflow: clip;
        }

        .root > .item {
          flex-grow: 2;
          flex-shrink: 0;
          flex-basis: 25%;
          order: 3;
          width: min-content;
          height: 40px;
          overflow: scroll;
          z-index: 7;
          position: absolute;
          top: 4px;
          bottom: 6px;
          left: 8px;
          right: 10px;
        }
        """

        let parsed = CSSParser.parse(css)

        XCTAssertEqual(parsed.container.direction, .rowReverse)
        XCTAssertEqual(parsed.container.wrap, .wrapReverse)
        XCTAssertEqual(parsed.container.justifyContent, .spaceAround)
        XCTAssertEqual(parsed.container.alignItems, .flexEnd)
        XCTAssertEqual(parsed.container.rowGap, 12)
        XCTAssertEqual(parsed.container.columnGap, 8)
        XCTAssertEqual(parsed.container.padding.top, 1)
        XCTAssertEqual(parsed.container.padding.trailing, 2)
        XCTAssertEqual(parsed.container.padding.bottom, 3)
        XCTAssertEqual(parsed.container.padding.leading, 4)
        XCTAssertEqual(parsed.container.overflow, .clip)

        XCTAssertEqual(parsed.items.count, 1)
        let item = try XCTUnwrap(parsed.items.first)
        XCTAssertEqual(item.grow, 2)
        XCTAssertEqual(item.shrink, 0)
        XCTAssertEqual(item.basis, .fraction(0.25))
        XCTAssertEqual(item.order, 3)
        XCTAssertEqual(item.width, .minContent)
        XCTAssertEqual(item.height, .points(40))
        XCTAssertEqual(item.overflow, .scroll)
        XCTAssertEqual(item.zIndex, 7)
        XCTAssertEqual(item.position, .absolute)
        XCTAssertEqual(item.top, 4)
        XCTAssertEqual(item.bottom, 6)
        XCTAssertEqual(item.leading, 8)
        XCTAssertEqual(item.trailing, 10)
    }
}
