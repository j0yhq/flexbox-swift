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
}
