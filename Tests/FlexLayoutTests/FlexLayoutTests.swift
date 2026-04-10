import XCTest
@testable import FlexLayout

final class FlexLayoutTests: XCTestCase {

    // MARK: - FlexContainerConfig gap helpers

    func testMainAxisGap_rowDirection_usesColumnGap() {
        var config = FlexContainerConfig(direction: .row, gap: 10, columnGap: 20)
        XCTAssertEqual(config.mainAxisGap, 20, "row direction: main gap = column-gap")
        config.columnGap = nil
        XCTAssertEqual(config.mainAxisGap, 10, "falls back to gap when columnGap is nil")
    }

    func testMainAxisGap_columnDirection_usesRowGap() {
        let config = FlexContainerConfig(direction: .column, gap: 10, rowGap: 30)
        XCTAssertEqual(config.mainAxisGap, 30, "column direction: main gap = row-gap")
    }

    func testCrossAxisGap_rowDirection_usesRowGap() {
        let config = FlexContainerConfig(direction: .row, gap: 5, rowGap: 15)
        XCTAssertEqual(config.crossAxisGap, 15)
    }

    // MARK: - AlignSelf(from:) resolution

    func testAlignSelfResolution() {
        XCTAssertEqual(AlignSelf(from: .flexStart), .flexStart)
        XCTAssertEqual(AlignSelf(from: .flexEnd),   .flexEnd)
        XCTAssertEqual(AlignSelf(from: .center),    .center)
        XCTAssertEqual(AlignSelf(from: .stretch),   .stretch)
        XCTAssertEqual(AlignSelf(from: .baseline),  .baseline)
    }

    // MARK: - FlexDirection helpers

    func testFlexDirectionHelpers() {
        XCTAssertTrue(FlexDirection.row.isRow)
        XCTAssertTrue(FlexDirection.rowReverse.isRow)
        XCTAssertFalse(FlexDirection.column.isRow)
        XCTAssertFalse(FlexDirection.columnReverse.isRow)

        XCTAssertTrue(FlexDirection.rowReverse.isReversed)
        XCTAssertTrue(FlexDirection.columnReverse.isReversed)
        XCTAssertFalse(FlexDirection.row.isReversed)
        XCTAssertFalse(FlexDirection.column.isReversed)
    }

    // MARK: - FlexBasis equality

    func testFlexBasisEquality() {
        XCTAssertEqual(FlexBasis.auto, .auto)
        XCTAssertEqual(FlexBasis.points(100), .points(100))
        XCTAssertNotEqual(FlexBasis.points(100), .points(200))
        XCTAssertEqual(FlexBasis.fraction(0.5), .fraction(0.5))
        XCTAssertNotEqual(FlexBasis.auto, .points(0))
    }

    // MARK: - Single-line cross-size rule

    func testSingleLineCrossConstraintAppliesOnlyForNowrap() {
        let nowrap = FlexLayout(.init(wrap: .nowrap))
        let wrap = FlexLayout(.init(wrap: .wrap))

        XCTAssertEqual(
            nowrap.applySingleLineCrossConstraint(42, crossConstraint: 120),
            120,
            "nowrap containers should expand single-line cross size to container cross constraint"
        )

        XCTAssertEqual(
            wrap.applySingleLineCrossConstraint(42, crossConstraint: 120),
            42,
            "wrap containers that happen to have one line should keep natural line cross size"
        )
    }
}
