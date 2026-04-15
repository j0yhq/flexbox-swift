import XCTest
import SwiftUI
@testable import FlexLayout

// MARK: - Helpers

private let ε: CGFloat = 0.5   // half-point epsilon for CGFloat comparisons

private func assertFrames(
    _ actual: [CGRect],
    _ expected: [CGRect],
    file: StaticString = #file,
    line: UInt = #line
) {
    XCTAssertEqual(actual.count, expected.count,
                   "frame count mismatch", file: file, line: line)
    for (i, (a, e)) in zip(actual, expected).enumerated() {
        XCTAssert(abs(a.minX   - e.minX)   < ε &&
                  abs(a.minY   - e.minY)   < ε &&
                  abs(a.width  - e.width)  < ε &&
                  abs(a.height - e.height) < ε,
                  "frame[\(i)] expected \(e) got \(a)", file: file, line: line)
    }
}

/// Solve and return frames. The proposal covers the full container (including padding).
private func solve(
    _ config: FlexContainerConfig,
    _ inputs: [FlexItemInput],
    in containerSize: CGSize
) -> [CGRect] {
    FlexEngine.solve(
        config:   config,
        inputs:   inputs,
        proposal: ProposedViewSize(width: containerSize.width, height: containerSize.height)
    ).frames
}

// MARK: - FlexGeometryTests

final class FlexGeometryTests: XCTestCase {

    // MARK: flex-direction

    func testDirection_row_placesItemsLeftToRight() {
        let frames = solve(
            .init(direction: .row),
            [.fixed(width: 100, height: 50),
             .fixed(width:  80, height: 50)],
            in: CGSize(width: 300, height: 100)
        )
        assertFrames(frames, [
            CGRect(x:   0, y: 0, width: 100, height: 100), // stretch fills cross
            CGRect(x: 100, y: 0, width:  80, height: 100),
        ])
    }

    func testDirection_column_placesItemsTopToBottom() {
        let frames = solve(
            .init(direction: .column),
            [.fixed(width: 100, height: 40),
             .fixed(width: 100, height: 60)],
            in: CGSize(width: 200, height: 300)
        )
        assertFrames(frames, [
            CGRect(x: 0, y:  0, width: 200, height: 40),
            CGRect(x: 0, y: 40, width: 200, height: 60),
        ])
    }

    func testDirection_rowReverse_placesItemsRightToLeft() {
        let frames = solve(
            .init(direction: .rowReverse),
            [.fixed(width: 100, height: 50),
             .fixed(width:  80, height: 50)],
            in: CGSize(width: 300, height: 100)
        )
        // rowReverse: item0 ends at right, item1 to its left
        assertFrames(frames, [
            CGRect(x: 200, y: 0, width: 100, height: 100),
            CGRect(x: 120, y: 0, width:  80, height: 100),
        ])
    }

    func testDirection_columnReverse_placesItemsBottomToTop() {
        let frames = solve(
            .init(direction: .columnReverse),
            [.fixed(width: 100, height: 40),
             .fixed(width: 100, height: 60)],
            in: CGSize(width: 200, height: 300)
        )
        assertFrames(frames, [
            CGRect(x: 0, y: 260, width: 200, height: 40),
            CGRect(x: 0, y: 200, width: 200, height: 60),
        ])
    }

    // MARK: flex-grow

    func testGrow_singleItem_fillsRemainingSpace() {
        let frames = solve(
            .init(direction: .row),
            [.fixed(width: 100, height: 50, grow: 1)],
            in: CGSize(width: 400, height: 100)
        )
        XCTAssertEqual(frames[0].width, 400, accuracy: ε)
    }

    func testGrow_twoItems_distributesProportionally() {
        // 300 free, split 1:2 → 100 & 200
        let frames = solve(
            .init(direction: .row),
            [.fixed(width: 0, height: 50, grow: 1),
             .fixed(width: 0, height: 50, grow: 2)],
            in: CGSize(width: 300, height: 100)
        )
        XCTAssertEqual(frames[0].width, 100, accuracy: ε)
        XCTAssertEqual(frames[1].width, 200, accuracy: ε)
    }

    func testGrow_withGap_gapDeductedBeforeDistribution() {
        // 300 container, gap 20, two basis-0 items, grow 1 each
        // free = 300 - 20 = 280, each gets 140
        let frames = solve(
            .init(direction: .row, gap: 20),
            [.fixed(width: 0, height: 50, grow: 1),
             .fixed(width: 0, height: 50, grow: 1)],
            in: CGSize(width: 300, height: 100)
        )
        XCTAssertEqual(frames[0].width,  140, accuracy: ε)
        XCTAssertEqual(frames[1].minX,   160, accuracy: ε)  // 140 + gap 20
        XCTAssertEqual(frames[1].width,  140, accuracy: ε)
    }

    // MARK: flex-shrink

    func testShrink_defaultShrink1_compressesEvenly() {
        // Two 200px items in 300 container; each shrinks by 50
        let frames = solve(
            .init(direction: .row),
            [.fixed(width: 200, height: 50),
             .fixed(width: 200, height: 50)],
            in: CGSize(width: 300, height: 100)
        )
        XCTAssertEqual(frames[0].width, 150, accuracy: ε)
        XCTAssertEqual(frames[1].width, 150, accuracy: ε)
    }

    func testShrink_weightedByBasis() {
        // item0 basis=100 shrink=1, item1 basis=200 shrink=1; overflow=100
        // weight0 = 100/300; shrinks by 100*100/300 ≈ 33.3 → 66.7
        // weight1 = 200/300; shrinks by 100*200/300 ≈ 66.7 → 133.3
        let frames = solve(
            .init(direction: .row),
            [.fixed(width: 100, height: 50),
             .fixed(width: 200, height: 50)],
            in: CGSize(width: 200, height: 100)
        )
        XCTAssertEqual(frames[0].width, 200.0 / 3, accuracy: ε)
        XCTAssertEqual(frames[1].width, 400.0 / 3, accuracy: ε)
    }

    // MARK: flex-basis

    func testBasis_points_overridesIntrinsicSize() {
        let frames = solve(
            .init(direction: .row),
            [.fixed(width: 200, height: 50, basis: .points(120))],
            in: CGSize(width: 300, height: 100)
        )
        XCTAssertEqual(frames[0].width, 120, accuracy: ε)
    }

    func testBasis_fraction_computedFromMainConstraint() {
        // basis 50% of 400 = 200
        let frames = solve(
            .init(direction: .row),
            [.fixed(width: 0, height: 50, basis: .fraction(0.5))],
            in: CGSize(width: 400, height: 100)
        )
        XCTAssertEqual(frames[0].width, 200, accuracy: ε)
    }

    // MARK: flex-wrap

    func testWrap_nowrap_itemsShrinkToFitOnOneLine() {
        // 3 × 150px items in 300-wide nowrap container → all shrink to fit one line
        let frames = solve(
            .init(direction: .row, wrap: .nowrap),
            [.fixed(width: 150, height: 50),
             .fixed(width: 150, height: 50),
             .fixed(width: 150, height: 50)],
            in: CGSize(width: 300, height: 100)
        )
        XCTAssertEqual(frames.count, 3)
        XCTAssertLessThanOrEqual(frames[2].maxX, 300 + ε)
    }

    func testWrap_wrap_secondItemMovesToNewLine() {
        // Two 200px items in 300-wide wrap container → second wraps
        // alignContent: .flexStart so lines are not stretched to fill cross axis
        let frames = solve(
            .init(direction: .row, wrap: .wrap, alignContent: .flexStart),
            [.fixed(width: 200, height: 40),
             .fixed(width: 200, height: 60)],
            in: CGSize(width: 300, height: 300)
        )
        XCTAssertEqual(frames[0].minY,  0, accuracy: ε)
        XCTAssertEqual(frames[1].minY, 40, accuracy: ε, "item wraps to next line")
        XCTAssertEqual(frames[1].minX,  0, accuracy: ε, "item starts at left edge")
    }

    func testWrap_wrapReverse_linesInReverseCrossOrder() {
        let frames = solve(
            .init(direction: .row, wrap: .wrapReverse),
            [.fixed(width: 200, height: 40),
             .fixed(width: 200, height: 60)],
            in: CGSize(width: 300, height: 300)
        )
        // wrapReverse: first source line sits below the second
        XCTAssertGreaterThan(frames[0].minY, frames[1].minY,
                             "wrapReverse: first line should be lower")
    }

    func testWrap_wrap_doesNotApplySingleLineCrossRule() {
        // A wrap container with one line should NOT fill the cross axis
        let frames = solve(
            .init(direction: .row, wrap: .wrap),
            [.fixed(width: 100, height: 50)],
            in: CGSize(width: 300, height: 200)
        )
        // Default alignItems is stretch, but the single-line rule is nowrap-only.
        // So lineCrossSize = 50 (item height), not 200.
        XCTAssertEqual(frames[0].height, 50, accuracy: ε,
                       "wrap container should NOT apply single-line cross-size rule")
    }

    // MARK: justify-content

    func testJustify_flexStart_packsItemsAtStart() {
        let frames = solve(
            .init(direction: .row, justifyContent: .flexStart),
            [.fixed(width: 80, height: 50),
             .fixed(width: 80, height: 50)],
            in: CGSize(width: 300, height: 100)
        )
        XCTAssertEqual(frames[0].minX,   0, accuracy: ε)
        XCTAssertEqual(frames[1].minX,  80, accuracy: ε)
    }

    func testJustify_flexEnd_packsItemsAtEnd() {
        let frames = solve(
            .init(direction: .row, justifyContent: .flexEnd),
            [.fixed(width: 80, height: 50),
             .fixed(width: 80, height: 50)],
            in: CGSize(width: 300, height: 100)
        )
        XCTAssertEqual(frames[1].maxX, 300, accuracy: ε)
        XCTAssertEqual(frames[0].maxX, 220, accuracy: ε)
    }

    func testJustify_center_centersItems() {
        // total = 160, free = 140, leading offset = 70
        let frames = solve(
            .init(direction: .row, justifyContent: .center),
            [.fixed(width: 80, height: 50),
             .fixed(width: 80, height: 50)],
            in: CGSize(width: 300, height: 100)
        )
        XCTAssertEqual(frames[0].minX,  70, accuracy: ε)
        XCTAssertEqual(frames[1].minX, 150, accuracy: ε)
    }

    func testJustify_spaceBetween_putsSpaceBetweenItems() {
        // 3 × 80px in 300, free = 60, 2 gaps of 30
        let frames = solve(
            .init(direction: .row, justifyContent: .spaceBetween),
            [.fixed(width: 80, height: 50),
             .fixed(width: 80, height: 50),
             .fixed(width: 80, height: 50)],
            in: CGSize(width: 300, height: 100)
        )
        XCTAssertEqual(frames[0].minX,   0, accuracy: ε)
        XCTAssertEqual(frames[1].minX, 110, accuracy: ε)
        XCTAssertEqual(frames[2].minX, 220, accuracy: ε)
    }

    func testJustify_spaceAround_equalsSpaceAroundEachItem() {
        // 2 × 60px in 300, free = 180, 2 items → spacing = 90, half on edges → 45
        let frames = solve(
            .init(direction: .row, justifyContent: .spaceAround),
            [.fixed(width: 60, height: 50),
             .fixed(width: 60, height: 50)],
            in: CGSize(width: 300, height: 100)
        )
        XCTAssertEqual(frames[0].minX,  45, accuracy: ε)
        XCTAssertEqual(frames[1].minX, 195, accuracy: ε)
    }

    func testJustify_spaceEvenly_equalsSpaceBetweenAllGaps() {
        // 2 × 60px in 300, free = 180, 3 even gaps → 60 each
        let frames = solve(
            .init(direction: .row, justifyContent: .spaceEvenly),
            [.fixed(width: 60, height: 50),
             .fixed(width: 60, height: 50)],
            in: CGSize(width: 300, height: 100)
        )
        XCTAssertEqual(frames[0].minX,  60, accuracy: ε)
        XCTAssertEqual(frames[1].minX, 180, accuracy: ε)
    }

    // MARK: align-items

    func testAlignItems_flexStart_alignsToStart() {
        let frames = solve(
            .init(direction: .row, alignItems: .flexStart),
            [.fixed(width: 100, height: 40),
             .fixed(width: 100, height: 80)],
            in: CGSize(width: 300, height: 200)
        )
        XCTAssertEqual(frames[0].minY, 0, accuracy: ε)
        XCTAssertEqual(frames[1].minY, 0, accuracy: ε)
    }

    func testAlignItems_flexEnd_alignsToLineEnd() {
        let frames = solve(
            .init(direction: .row, alignItems: .flexEnd),
            [.fixed(width: 100, height: 40),
             .fixed(width: 100, height: 80)],
            in: CGSize(width: 300, height: 200)
        )
        // nowrap single-line rule → lineCross = 200
        XCTAssertEqual(frames[0].maxY, 200, accuracy: ε)
        XCTAssertEqual(frames[1].maxY, 200, accuracy: ε)
    }

    func testAlignItems_center_centersOnCrossAxis() {
        let frames = solve(
            .init(direction: .row, alignItems: .center),
            [.fixed(width: 100, height: 40),
             .fixed(width: 100, height: 80)],
            in: CGSize(width: 300, height: 200)
        )
        // lineCross = 200; item0 offset = (200-40)/2 = 80; item1 = (200-80)/2 = 60
        XCTAssertEqual(frames[0].minY, 80, accuracy: ε)
        XCTAssertEqual(frames[1].minY, 60, accuracy: ε)
    }

    func testAlignItems_stretch_fillsLineCross() {
        let frames = solve(
            .init(direction: .row, alignItems: .stretch),
            [.fixed(width: 100, height: 40)],
            in: CGSize(width: 300, height: 200)
        )
        // nowrap + stretch → fills 200
        XCTAssertEqual(frames[0].height, 200, accuracy: ε)
    }

    // MARK: align-self

    func testAlignSelf_overridesContainerAlignItems() {
        let frames = solve(
            .init(direction: .row, alignItems: .stretch),
            [.fixed(width: 100, height: 40, alignSelf: .flexStart),
             .fixed(width: 100, height: 60)],
            in: CGSize(width: 300, height: 200)
        )
        XCTAssertEqual(frames[0].height,  40, accuracy: ε, "alignSelf overrides stretch")
        XCTAssertEqual(frames[0].minY,     0, accuracy: ε)
        XCTAssertEqual(frames[1].height, 200, accuracy: ε, "sibling still stretches")
    }

    func testAlignSelf_center_centersOneItem() {
        let frames = solve(
            .init(direction: .row, alignItems: .flexStart),
            [.fixed(width: 100, height: 40, alignSelf: .center)],
            in: CGSize(width: 300, height: 200)
        )
        XCTAssertEqual(frames[0].minY, 80, accuracy: ε)  // (200-40)/2
    }

    func testAlignSelf_flexEnd_movesItemToLineEnd() {
        let frames = solve(
            .init(direction: .row, alignItems: .flexStart),
            [.fixed(width: 100, height: 40, alignSelf: .flexEnd)],
            in: CGSize(width: 300, height: 200)
        )
        XCTAssertEqual(frames[0].maxY, 200, accuracy: ε)
    }

    // MARK: align-content (multi-line)

    func testAlignContent_flexStart_packsLinesAtTop() {
        let frames = solve(
            .init(direction: .row, wrap: .wrap, alignContent: .flexStart),
            [.fixed(width: 200, height: 40),
             .fixed(width: 200, height: 60)],
            in: CGSize(width: 300, height: 300)
        )
        XCTAssertEqual(frames[0].minY,  0, accuracy: ε)
        XCTAssertEqual(frames[1].minY, 40, accuracy: ε)
    }

    func testAlignContent_flexEnd_packsLinesAtBottom() {
        let frames = solve(
            .init(direction: .row, wrap: .wrap, alignContent: .flexEnd),
            [.fixed(width: 200, height: 40),
             .fixed(width: 200, height: 60)],
            in: CGSize(width: 300, height: 300)
        )
        XCTAssertEqual(frames[1].maxY, 300, accuracy: ε)
        XCTAssertEqual(frames[0].maxY, 240, accuracy: ε)
    }

    func testAlignContent_center_centersLineBlock() {
        // totalLines=100, container=300, free=200 → start at 100
        let frames = solve(
            .init(direction: .row, wrap: .wrap, alignContent: .center),
            [.fixed(width: 200, height: 40),
             .fixed(width: 200, height: 60)],
            in: CGSize(width: 300, height: 300)
        )
        XCTAssertEqual(frames[0].minY, 100, accuracy: ε)
        XCTAssertEqual(frames[1].minY, 140, accuracy: ε)
    }

    func testAlignContent_spaceBetween_spreadsLinesToEdges() {
        let frames = solve(
            .init(direction: .row, wrap: .wrap, alignContent: .spaceBetween),
            [.fixed(width: 200, height: 40),
             .fixed(width: 200, height: 60)],
            in: CGSize(width: 300, height: 300)
        )
        XCTAssertEqual(frames[0].minY,   0, accuracy: ε)
        XCTAssertEqual(frames[1].minY, 240, accuracy: ε)
    }

    func testAlignContent_spaceEvenly_threeLines() {
        // 3 lines 50px each = 150, container 300, free 150 → 4 even gaps of 37.5
        let frames = solve(
            .init(direction: .row, wrap: .wrap, alignContent: .spaceEvenly),
            [.fixed(width: 300, height: 50),
             .fixed(width: 300, height: 50),
             .fixed(width: 300, height: 50)],
            in: CGSize(width: 300, height: 300)
        )
        XCTAssertEqual(frames[0].minY,  37.5, accuracy: ε)
        XCTAssertEqual(frames[1].minY, 125.0, accuracy: ε)
        XCTAssertEqual(frames[2].minY, 212.5, accuracy: ε)
    }

    // MARK: gap

    func testGap_mainAxis_addedBetweenItems() {
        let frames = solve(
            .init(direction: .row, justifyContent: .flexStart, gap: 20),
            [.fixed(width: 100, height: 50),
             .fixed(width: 100, height: 50)],
            in: CGSize(width: 400, height: 100)
        )
        XCTAssertEqual(frames[0].minX,   0, accuracy: ε)
        XCTAssertEqual(frames[1].minX, 120, accuracy: ε)  // 100 + gap 20
    }

    func testGap_crossAxis_addedBetweenLines() {
        // alignContent: .flexStart prevents stretch from redistributing free space across lines
        let frames = solve(
            .init(direction: .row, wrap: .wrap, alignContent: .flexStart, gap: 30),
            [.fixed(width: 200, height: 40),
             .fixed(width: 200, height: 60)],
            in: CGSize(width: 300, height: 400)
        )
        XCTAssertEqual(frames[1].minY, 70, accuracy: ε)  // line0=40, gap=30
    }

    func testColumnGapAndRowGap_areIndependentPerAxis() {
        // columnGap (between items in a row) = 10; rowGap (between lines) = 50
        // alignContent: .flexStart prevents stretch from redistributing free space across lines
        let frames = solve(
            .init(direction: .row, wrap: .wrap, alignContent: .flexStart, rowGap: 50, columnGap: 10),
            [.fixed(width: 100, height: 40),   // line 0 item 0
             .fixed(width: 100, height: 40),   // line 0 item 1 (gap=10)
             .fixed(width: 300, height: 60)],  // line 1 (gap=50)
            in: CGSize(width: 300, height: 400)
        )
        XCTAssertEqual(frames[1].minX,  110, accuracy: ε)  // 100 + columnGap 10
        XCTAssertEqual(frames[2].minY,   90, accuracy: ε)  // line0=40, rowGap=50
    }

    // MARK: padding

    func testPadding_offsetsAllItems() {
        let pad = EdgeInsets(top: 10, leading: 20, bottom: 10, trailing: 20)
        let frames = solve(
            .init(direction: .row, justifyContent: .flexStart, padding: pad),
            [.fixed(width: 100, height: 50)],
            in: CGSize(width: 300, height: 100)
        )
        XCTAssertEqual(frames[0].minX, 20, accuracy: ε)
        XCTAssertEqual(frames[0].minY, 10, accuracy: ε)
    }

    func testPadding_reducesSpaceForGrow() {
        // Container 300×100, padding 20 each side → inner 260×60
        let pad = EdgeInsets(top: 20, leading: 20, bottom: 20, trailing: 20)
        let frames = solve(
            .init(direction: .row, padding: pad),
            [.fixed(width: 0, height: 0, grow: 1)],
            in: CGSize(width: 300, height: 100)
        )
        XCTAssertEqual(frames[0].width,  260, accuracy: ε)
        XCTAssertEqual(frames[0].height,  60, accuracy: ε)
    }

    // MARK: width / height (explicit sizes)

    func testExplicitWidth_points_setsMainSize() {
        // grow:0 so the explicit width is the sole size driver (no free-space distribution on top)
        let frames = solve(
            .init(direction: .row),
            [FlexItemInput(
                measure: { _ in CGSize(width: 50, height: 50) },
                grow: 0,
                explicitWidth: .points(120)
            )],
            in: CGSize(width: 300, height: 100)
        )
        XCTAssertEqual(frames[0].width, 120, accuracy: ε)
    }

    func testExplicitHeight_points_setsCrossSize() {
        let frames = solve(
            .init(direction: .row, alignItems: .stretch),
            [FlexItemInput(
                measure: { _ in CGSize(width: 100, height: 50) },
                explicitHeight: .points(30)
            )],
            in: CGSize(width: 300, height: 200)
        )
        XCTAssertEqual(frames[0].height, 30, accuracy: ε)
    }

    func testExplicitWidth_fraction_percentageOfMainAxis() {
        let frames = solve(
            .init(direction: .row),
            [FlexItemInput(
                measure: { _ in CGSize(width: 50, height: 50) },
                explicitWidth: .fraction(0.5)
            )],
            in: CGSize(width: 400, height: 100)
        )
        XCTAssertEqual(frames[0].width, 200, accuracy: ε)
    }

    // MARK: order

    func testOrder_reordersVisualPosition() {
        // Source: A(order:2), B(order:0), C(order:1) → visual: B, C, A
        let frames = solve(
            .init(direction: .row, justifyContent: .flexStart),
            [.fixed(width: 60, height: 50, order: 2),   // A – index 0
             .fixed(width: 60, height: 50, order: 0),   // B – index 1
             .fixed(width: 60, height: 50, order: 1)],  // C – index 2
            in: CGSize(width: 300, height: 100)
        )
        XCTAssertEqual(frames[1].minX,   0, accuracy: ε, "order:0 item first")
        XCTAssertEqual(frames[2].minX,  60, accuracy: ε, "order:1 item second")
        XCTAssertEqual(frames[0].minX, 120, accuracy: ε, "order:2 item third")
    }

    // MARK: position: absolute

    func testAbsolute_removedFromFlowDoesNotPushSiblings() {
        let frames = solve(
            .init(direction: .row),
            [.fixed(width: 100, height: 50),                                 // flow
             .fixed(width: 100, height: 50, position: .absolute,             // abs
                    top: 10, leading: 200)],
            in: CGSize(width: 400, height: 200)
        )
        XCTAssertEqual(frames[0].minX,   0, accuracy: ε, "flow item unaffected by abs sibling")
        XCTAssertEqual(frames[1].minX, 200, accuracy: ε)
        XCTAssertEqual(frames[1].minY,  10, accuracy: ε)
    }

    func testAbsolute_trailing_positionedFromRightEdge() {
        let frames = solve(
            .init(direction: .row),
            [.fixed(width: 60, height: 60, position: .absolute, trailing: 20)],
            in: CGSize(width: 300, height: 200)
        )
        // x = 300 - 20 - 60 = 220
        XCTAssertEqual(frames[0].minX, 220, accuracy: ε)
    }

    func testAbsolute_bottom_positionedFromBottomEdge() {
        let frames = solve(
            .init(direction: .row),
            [.fixed(width: 60, height: 60, position: .absolute, bottom: 10)],
            in: CGSize(width: 300, height: 200)
        )
        // y = 200 - 10 - 60 = 130
        XCTAssertEqual(frames[0].minY, 130, accuracy: ε)
    }

    func testAbsolute_leadingAndTrailing_stretchesWidth() {
        let frames = solve(
            .init(direction: .row),
            [.fixed(width: 0, height: 60, position: .absolute, leading: 20, trailing: 30)],
            in: CGSize(width: 300, height: 200)
        )
        // width = 300 - 20 - 30 = 250
        XCTAssertEqual(frames[0].minX,   20, accuracy: ε)
        XCTAssertEqual(frames[0].width, 250, accuracy: ε)
    }

    // MARK: z-index

    func testZIndex_doesNotAffectLayoutGeometry() {
        // High z-index item should still be placed in source order for geometry
        let frames = solve(
            .init(direction: .row),
            [.fixed(width: 100, height: 50, zIndex: 10),
             .fixed(width: 100, height: 50, zIndex:  1)],
            in: CGSize(width: 300, height: 100)
        )
        XCTAssertEqual(frames[0].minX,   0, accuracy: ε)
        XCTAssertEqual(frames[1].minX, 100, accuracy: ε)
    }

    func testZIndex_samePriority_domOrderTieBreak() {
        // Frames are indexed by input (DOM) order regardless of z-index
        let solution = FlexEngine.solve(
            config:   .init(direction: .row),
            inputs:   [.fixed(width: 100, height: 50, zIndex: 0),
                       .fixed(width: 100, height: 50, zIndex: 0)],
            proposal: ProposedViewSize(width: 300, height: 100)
        )
        XCTAssertEqual(solution.frames[0].minX,   0, accuracy: ε)
        XCTAssertEqual(solution.frames[1].minX, 100, accuracy: ε)
    }

    // MARK: display:block/inline (blockified — no outer layout effect)

    func testDisplay_blockAndInline_haveSameGeometryAsFlex() {
        let base = solve(
            .init(direction: .row),
            [.fixed(width: 100, height: 50)],
            in: CGSize(width: 300, height: 100)
        )
        // FlexItemInput has no display concept — blockification is a no-op in the engine
        XCTAssertEqual(base[0].width,  100, accuracy: ε)
        XCTAssertEqual(base[0].height, 100, accuracy: ε)  // stretch
    }

    // MARK: Interactions

    func testInteraction_flexWrap_alignContent_spaceEvenly() {
        // See align-content spaceEvenly test above — covered there
    }

    func testInteraction_explicitWidth_andBasis_explicitWins() {
        // explicit width 200 overrides basis .auto
        let frames = solve(
            .init(direction: .row),
            [FlexItemInput(
                measure: { _ in CGSize(width: 50, height: 50) },
                basis: .auto,
                explicitWidth: .points(200)
            )],
            in: CGSize(width: 400, height: 100)
        )
        XCTAssertEqual(frames[0].width, 200, accuracy: ε)
    }

    func testInteraction_absolute_zIndex_frameUnaffected() {
        let frames = solve(
            .init(direction: .row),
            [.fixed(width: 80, height: 80,
                    zIndex: 5, position: .absolute, top: 20, leading: 40)],
            in: CGSize(width: 300, height: 200)
        )
        XCTAssertEqual(frames[0].minX,   40, accuracy: ε)
        XCTAssertEqual(frames[0].minY,   20, accuracy: ε)
        XCTAssertEqual(frames[0].width,  80, accuracy: ε)
        XCTAssertEqual(frames[0].height, 80, accuracy: ε)
    }

    func testInteraction_justifyCenter_andGap() {
        // 3 × 60px, gap 10 → total = 200; container 400 → free = 200 → offset = 100
        let frames = solve(
            .init(direction: .row, justifyContent: .center, gap: 10),
            [.fixed(width: 60, height: 50),
             .fixed(width: 60, height: 50),
             .fixed(width: 60, height: 50)],
            in: CGSize(width: 400, height: 100)
        )
        XCTAssertEqual(frames[0].minX, 100, accuracy: ε)
        XCTAssertEqual(frames[1].minX, 170, accuracy: ε)
        XCTAssertEqual(frames[2].minX, 240, accuracy: ε)
    }

    func testInteraction_padding_andFlexGrow() {
        // Container 400×100, padding 50 left/right → inner main = 300
        // Two grow:1 items split 300 → each 150
        let pad = EdgeInsets(top: 0, leading: 50, bottom: 0, trailing: 50)
        let frames = solve(
            .init(direction: .row, padding: pad),
            [.fixed(width: 0, height: 50, grow: 1),
             .fixed(width: 0, height: 50, grow: 1)],
            in: CGSize(width: 400, height: 100)
        )
        XCTAssertEqual(frames[0].minX,  50, accuracy: ε)
        XCTAssertEqual(frames[0].width, 150, accuracy: ε)
        XCTAssertEqual(frames[1].minX, 200, accuracy: ε)
        XCTAssertEqual(frames[1].width, 150, accuracy: ε)
    }

    // MARK: Pure helper: distributeMain

    func testDistributeMain_flexStart_packsLeft() {
        let offs = FlexEngine.distributeMain(
            containerMain: 300, itemSizes: [80, 80, 80], gap: 0,
            justify: .flexStart, reversed: false
        )
        XCTAssertEqual(offs, [0, 80, 160])
    }

    func testDistributeMain_spaceBetween_twoItems() {
        let offs = FlexEngine.distributeMain(
            containerMain: 300, itemSizes: [60, 60], gap: 0,
            justify: .spaceBetween, reversed: false
        )
        XCTAssertEqual(offs[0],   0, accuracy: ε)
        XCTAssertEqual(offs[1], 240, accuracy: ε)
    }

    func testDistributeMain_reversed_mirrorsOffsets() {
        let offs = FlexEngine.distributeMain(
            containerMain: 300, itemSizes: [100, 100], gap: 0,
            justify: .flexStart, reversed: true
        )
        XCTAssertEqual(offs[0], 200, accuracy: ε)
        XCTAssertEqual(offs[1], 100, accuracy: ε)
    }

    // MARK: Pure helper: distributeLines

    func testDistributeLines_flexStart_packsTop() {
        let offs = FlexEngine.distributeLines(
            containerCross: 300, lineSizes: [50, 60], gap: 0, align: .flexStart
        )
        XCTAssertEqual(offs[0],  0, accuracy: ε)
        XCTAssertEqual(offs[1], 50, accuracy: ε)
    }

    func testDistributeLines_center_centersBlock() {
        let offs = FlexEngine.distributeLines(
            containerCross: 300, lineSizes: [50, 50], gap: 0, align: .center
        )
        XCTAssertEqual(offs[0], 100, accuracy: ε)
        XCTAssertEqual(offs[1], 150, accuracy: ε)
    }

    // MARK: Pure helper: itemCrossOffset

    func testItemCrossOffset_flexEnd_pushedToEnd() {
        let off = FlexEngine.itemCrossOffset(
            alignSelf: .flexEnd, itemCross: 40, lineCross: 100, ascent: 0, maxAscent: 0
        )
        XCTAssertEqual(off, 60, accuracy: ε)
    }

    func testItemCrossOffset_center_centered() {
        let off = FlexEngine.itemCrossOffset(
            alignSelf: .center, itemCross: 40, lineCross: 100, ascent: 0, maxAscent: 0
        )
        XCTAssertEqual(off, 30, accuracy: ε)
    }

    // MARK: Pure helper: resolveGrow / resolveShrink

    func testResolveGrow_distributesFreeSpaceByWeight() {
        let items: [RawFlexItem] = [
            .init(inputIndex: 0, basisMain: 0, grow: 1, shrink: 1,
                  effectiveAlignSelf: .stretch, explicitCrossSize: nil, zIndex: 0),
            .init(inputIndex: 1, basisMain: 0, grow: 3, shrink: 1,
                  effectiveAlignSelf: .stretch, explicitCrossSize: nil, zIndex: 0),
        ]
        let sizes = FlexEngine.resolveGrow(items: items, freeSpace: 200)
        XCTAssertEqual(sizes[0],  50, accuracy: ε)   // 1/4 × 200
        XCTAssertEqual(sizes[1], 150, accuracy: ε)   // 3/4 × 200
    }

    func testResolveShrink_weightedByBasisAndShrinkFactor() {
        // overflow = 90; item0 weight = 100/300; item1 weight = 200/300
        let items: [RawFlexItem] = [
            .init(inputIndex: 0, basisMain: 100, grow: 0, shrink: 1,
                  effectiveAlignSelf: .stretch, explicitCrossSize: nil, zIndex: 0),
            .init(inputIndex: 1, basisMain: 200, grow: 0, shrink: 1,
                  effectiveAlignSelf: .stretch, explicitCrossSize: nil, zIndex: 0),
        ]
        let sizes = FlexEngine.resolveShrink(items: items, overflow: 90)
        XCTAssertEqual(sizes[0],  70, accuracy: ε)   // 100 - 30
        XCTAssertEqual(sizes[1], 140, accuracy: ε)   // 200 - 60
    }
}
