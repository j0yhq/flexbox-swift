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
