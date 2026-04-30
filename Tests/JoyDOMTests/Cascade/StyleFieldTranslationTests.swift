import XCTest
@testable import JoyDOM
import FlexLayout

/// Per-field tests for `StyleResolver.apply(_ style:, ...)`. The big
/// `testStyleFieldsTranslateToComputedStyle` in `CascadeIntegrationTests`
/// covers the happy paths in one fixture; this file pins each
/// regression-prone field individually so a failure points at the
/// specific property that broke.
final class StyleFieldTranslationTests: XCTestCase {

    // MARK: - Helper

    private func resolve(style: Style) -> ComputedStyle {
        var diags = JoyDiagnostics()
        let rules = RuleBuilder.buildRules(
            from: Spec(
                style: ["#x": style],
                breakpoints: [],
                layout: Node(type: "div", props: NodeProps(id: "x"))
            ),
            activeBreakpoint: nil,
            diagnostics: &diags
        )
        let nodes = StyleTreeBuilder.build(
            layout: Node(type: "div", props: NodeProps(id: "x")),
            rootID: "__joydom_root__",
            rules: rules,
            diagnostics: &diags
        )
        return nodes.first(where: { $0.id == "x" })!.computedStyle
    }

    // MARK: - flex-direction

    func testFlexDirectionRow() {
        XCTAssertEqual(resolve(style: Style(flexDirection: .row)).container.direction, .row)
    }
    func testFlexDirectionColumn() {
        XCTAssertEqual(resolve(style: Style(flexDirection: .column)).container.direction, .column)
    }

    // MARK: - flex-wrap

    func testFlexWrapNowrap() {
        XCTAssertEqual(resolve(style: Style(flexWrap: .nowrap)).container.wrap, .nowrap)
    }
    func testFlexWrapWrap() {
        XCTAssertEqual(resolve(style: Style(flexWrap: .wrap)).container.wrap, .wrap)
    }

    // MARK: - justify-content

    func testJustifyContentEachValue() {
        XCTAssertEqual(resolve(style: Style(justifyContent: .flexStart)).container.justifyContent, .flexStart)
        XCTAssertEqual(resolve(style: Style(justifyContent: .flexEnd)).container.justifyContent, .flexEnd)
        XCTAssertEqual(resolve(style: Style(justifyContent: .center)).container.justifyContent, .center)
        XCTAssertEqual(resolve(style: Style(justifyContent: .spaceBetween)).container.justifyContent, .spaceBetween)
        XCTAssertEqual(resolve(style: Style(justifyContent: .spaceAround)).container.justifyContent, .spaceAround)
    }

    // MARK: - align-items

    func testAlignItemsEachValue() {
        XCTAssertEqual(resolve(style: Style(alignItems: .flexStart)).container.alignItems, .flexStart)
        XCTAssertEqual(resolve(style: Style(alignItems: .flexEnd)).container.alignItems, .flexEnd)
        XCTAssertEqual(resolve(style: Style(alignItems: .center)).container.alignItems, .center)
    }

    // MARK: - flex-grow / flex-shrink

    func testFlexGrowFractional() {
        XCTAssertEqual(resolve(style: Style(flexGrow: 0)).item.grow,    0)
        XCTAssertEqual(resolve(style: Style(flexGrow: 1)).item.grow,    1)
        XCTAssertEqual(resolve(style: Style(flexGrow: 2.5)).item.grow,  2.5)
    }

    func testFlexShrinkExplicitZeroOverridesDefault() {
        // `flexShrink: 0` is the most common explicit override (on a
        // sidebar that should not shrink). Make sure the value lands
        // exactly even though the spec field's default would be nil.
        XCTAssertEqual(resolve(style: Style(flexShrink: 0)).item.shrink, 0)
    }

    func testFlexShrinkNonZero() {
        XCTAssertEqual(resolve(style: Style(flexShrink: 2)).item.shrink, 2)
    }

    // MARK: - flex-basis

    func testFlexBasisPxPoints() {
        let s = resolve(style: Style(flexBasis: .px(120)))
        XCTAssertEqual(s.item.basis, .points(120))
    }
    func testFlexBasisPercentFraction() {
        let s = resolve(style: Style(flexBasis: .percent(50)))
        XCTAssertEqual(s.item.basis, .fraction(0.5))
    }

    // MARK: - width / height

    func testWidthPxAndPercent() {
        XCTAssertEqual(resolve(style: Style(width: .px(100))).item.width, .points(100))
        XCTAssertEqual(resolve(style: Style(width: .percent(75))).item.width, .fraction(0.75))
    }
    func testHeightPxAndPercent() {
        XCTAssertEqual(resolve(style: Style(height: .px(40))).item.height, .points(40))
        XCTAssertEqual(resolve(style: Style(height: .percent(100))).item.height, .fraction(1))
    }

    // MARK: - gap

    func testGapUniformSetsTopLevelGap() {
        let c = resolve(style: Style(gap: .uniform(.px(8)))).container
        XCTAssertEqual(c.gap, 8)
    }

    func testGapAxesSetsRowAndColumnSeparately() {
        // Tier 5 spec change: `Gap.axes(column:, row:)` writes to
        // `.columnGap` and `.rowGap` — NOT `.gap` itself.
        let c = resolve(style: Style(gap: .axes(column: .px(4), row: .px(8)))).container
        XCTAssertEqual(c.rowGap, 8)
        XCTAssertEqual(c.columnGap, 4)
    }

    // MARK: - padding

    func testPaddingUniformSetsAllSides() {
        let c = resolve(style: Style(padding: .uniform(.px(12)))).container
        XCTAssertEqual(c.padding.top, 12)
        XCTAssertEqual(c.padding.bottom, 12)
        XCTAssertEqual(c.padding.leading, 12)
        XCTAssertEqual(c.padding.trailing, 12)
    }

    func testPaddingSidesAppliesPerSide() {
        let c = resolve(style: Style(padding: .sides(
            top: .px(1), right: .px(2), bottom: .px(3), left: .px(4)
        ))).container
        XCTAssertEqual(c.padding.top, 1)
        XCTAssertEqual(c.padding.trailing, 2)
        XCTAssertEqual(c.padding.bottom, 3)
        XCTAssertEqual(c.padding.leading, 4)
    }

    // MARK: - position + offsets

    func testPositionRelative() {
        XCTAssertEqual(resolve(style: Style(position: .relative)).item.position, .relative)
    }
    func testPositionAbsolute() {
        XCTAssertEqual(resolve(style: Style(position: .absolute)).item.position, .absolute)
    }

    func testTopBottomLeftRightOffsetsLandOnEdges() {
        let s = resolve(style: Style(
            top: .px(10), left: .px(20), bottom: .px(30), right: .px(40)
        ))
        XCTAssertEqual(s.item.top, 10)
        XCTAssertEqual(s.item.leading, 20)
        XCTAssertEqual(s.item.bottom, 30)
        XCTAssertEqual(s.item.trailing, 40)
    }

    // MARK: - z-index, order, overflow

    func testZIndex() {
        XCTAssertEqual(resolve(style: Style(zIndex: 5)).item.zIndex, 5)
        XCTAssertEqual(resolve(style: Style(zIndex: -1)).item.zIndex, -1)
    }

    func testOrder() {
        XCTAssertEqual(resolve(style: Style(order: 3)).item.order, 3)
        XCTAssertEqual(resolve(style: Style(order: -2)).item.order, -2)
    }

    func testOverflowEachValue() {
        XCTAssertEqual(resolve(style: Style(overflow: .visible)).container.overflow, .visible)
        XCTAssertEqual(resolve(style: Style(overflow: .hidden)).container.overflow, .hidden)
        XCTAssertEqual(resolve(style: Style(overflow: .clip)).container.overflow, .clip)
        XCTAssertEqual(resolve(style: Style(overflow: .scroll)).container.overflow, .scroll)
        XCTAssertEqual(resolve(style: Style(overflow: .auto)).container.overflow, .auto)
    }

    func testOverflowAlsoMirrorsToItem() {
        // The resolver writes overflow to BOTH container and item so
        // the flex engine's item-level reader sees a non-default value.
        let s = resolve(style: Style(overflow: .hidden))
        XCTAssertEqual(s.container.overflow, .hidden)
        XCTAssertEqual(s.item.overflow,      .hidden)
    }

    // MARK: - display

    func testDisplayFlex() {
        XCTAssertEqual(resolve(style: Style(display: .flex)).display, .flex)
    }
    func testDisplayBlock() {
        XCTAssertEqual(resolve(style: Style(display: .block)).display, .block)
    }
    func testDisplayInlineBlockMapsToInline() {
        // FlexDisplay has no `inlineBlock` — the resolver maps to
        // `.inline`. Spec'd in the resolver's apply() comment.
        XCTAssertEqual(resolve(style: Style(display: .inlineBlock)).display, .inline)
    }
}
