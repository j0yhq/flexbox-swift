import XCTest
@testable import CSSLayout

/// Unit 5 — `MediaQuery.matches(in:)` decides whether a query matches
/// a given `Viewport`. Pure function. Pure function. Pure function.
///
/// Coverage matrix: width with all four operators (>, <, >=, <=) at
/// boundary and off-boundary; orientation with both values; print
/// type; nil-operator/value width queries that match any viewport;
/// and/or/not logical composition including vacuous-truth edges.
final class MediaQueryEvaluatorTests: XCTestCase {

    // MARK: - Width feature

    func testWidthLessThanMatchesUnderBoundary() {
        let q = MediaQuery.width(operator: .lessThan, value: 768, unit: .px)
        XCTAssertTrue(q.matches(in: Viewport(width: 600)))
    }

    func testWidthLessThanDoesNotMatchAtBoundary() {
        // Strict less-than: equal value must NOT match.
        let q = MediaQuery.width(operator: .lessThan, value: 768, unit: .px)
        XCTAssertFalse(q.matches(in: Viewport(width: 768)))
    }

    func testWidthLessThanDoesNotMatchOverBoundary() {
        let q = MediaQuery.width(operator: .lessThan, value: 768, unit: .px)
        XCTAssertFalse(q.matches(in: Viewport(width: 800)))
    }

    func testWidthLessThanOrEqualMatchesAtBoundary() {
        let q = MediaQuery.width(operator: .lessThanOrEqual, value: 768, unit: .px)
        XCTAssertTrue(q.matches(in: Viewport(width: 768)))
        XCTAssertTrue(q.matches(in: Viewport(width: 700)))
        XCTAssertFalse(q.matches(in: Viewport(width: 800)))
    }

    func testWidthGreaterThanMatchesAboveBoundary() {
        let q = MediaQuery.width(operator: .greaterThan, value: 768, unit: .px)
        XCTAssertTrue(q.matches(in: Viewport(width: 800)))
        XCTAssertFalse(q.matches(in: Viewport(width: 768)))
        XCTAssertFalse(q.matches(in: Viewport(width: 700)))
    }

    func testWidthGreaterThanOrEqualMatchesAtBoundary() {
        let q = MediaQuery.width(operator: .greaterThanOrEqual, value: 768, unit: .px)
        XCTAssertTrue(q.matches(in: Viewport(width: 768)))
        XCTAssertTrue(q.matches(in: Viewport(width: 800)))
        XCTAssertFalse(q.matches(in: Viewport(width: 700)))
    }

    func testWidthWithoutOperatorOrValueMatchesAnyViewport() {
        // CSS `@media (width)` with no comparator matches any viewport
        // (it's a feature-presence test, and width is always present).
        let q = MediaQuery.width()
        XCTAssertTrue(q.matches(in: Viewport(width: 0)))
        XCTAssertTrue(q.matches(in: Viewport(width: 9999)))
    }

    // MARK: - Orientation feature

    func testOrientationPortraitMatches() {
        let q = MediaQuery.orientation(.portrait)
        XCTAssertTrue(q.matches(in: Viewport(width: 320, orientation: .portrait)))
        XCTAssertFalse(q.matches(in: Viewport(width: 320, orientation: .landscape)))
    }

    func testOrientationLandscapeMatches() {
        let q = MediaQuery.orientation(.landscape)
        XCTAssertTrue(q.matches(in: Viewport(width: 800, orientation: .landscape)))
        XCTAssertFalse(q.matches(in: Viewport(width: 800, orientation: .portrait)))
    }

    // MARK: - Type (print)

    func testTypePrintMatchesWhenPrintFlagOn() {
        let q = MediaQuery.type(.print)
        XCTAssertTrue(q.matches(in: Viewport(width: 800, isPrint: true)))
        XCTAssertFalse(q.matches(in: Viewport(width: 800, isPrint: false)))
    }

    // MARK: - Logical AND

    func testLogicalAndMatchesWhenAllConditionsMatch() {
        let q = MediaQuery.logical(op: .and, conditions: [
            .width(operator: .greaterThanOrEqual, value: 768, unit: .px),
            .orientation(.landscape),
        ])
        XCTAssertTrue(q.matches(in: Viewport(width: 1024, orientation: .landscape)))
    }

    func testLogicalAndFailsWhenOneConditionFails() {
        let q = MediaQuery.logical(op: .and, conditions: [
            .width(operator: .greaterThanOrEqual, value: 768, unit: .px),
            .orientation(.landscape),
        ])
        // Width matches, but orientation does not.
        XCTAssertFalse(q.matches(in: Viewport(width: 1024, orientation: .portrait)))
        // Orientation matches, but width does not.
        XCTAssertFalse(q.matches(in: Viewport(width: 600, orientation: .landscape)))
    }

    func testLogicalAndWithEmptyConditionsIsVacuouslyTrue() {
        let q = MediaQuery.logical(op: .and, conditions: [])
        XCTAssertTrue(q.matches(in: Viewport(width: 0)))
    }

    // MARK: - Logical OR

    func testLogicalOrMatchesWhenAnyConditionMatches() {
        let q = MediaQuery.logical(op: .or, conditions: [
            .width(operator: .lessThan, value: 600, unit: .px),
            .orientation(.landscape),
        ])
        // First condition fires.
        XCTAssertTrue(q.matches(in: Viewport(width: 320, orientation: .portrait)))
        // Second condition fires.
        XCTAssertTrue(q.matches(in: Viewport(width: 1200, orientation: .landscape)))
    }

    func testLogicalOrFailsWhenAllConditionsFail() {
        let q = MediaQuery.logical(op: .or, conditions: [
            .width(operator: .lessThan, value: 600, unit: .px),
            .orientation(.landscape),
        ])
        XCTAssertFalse(q.matches(in: Viewport(width: 1200, orientation: .portrait)))
    }

    func testLogicalOrWithEmptyConditionsIsVacuouslyFalse() {
        let q = MediaQuery.logical(op: .or, conditions: [])
        XCTAssertFalse(q.matches(in: Viewport(width: 999)))
    }

    // MARK: - Negation

    func testNotInvertsInnerMatch() {
        let inner = MediaQuery.width(operator: .lessThan, value: 600, unit: .px)
        let q = MediaQuery.not(inner)
        XCTAssertFalse(q.matches(in: Viewport(width: 400)))   // inner matched → not is false
        XCTAssertTrue(q.matches(in: Viewport(width: 800)))    // inner failed → not is true
    }

    // MARK: - Deep nesting

    func testNestedNotAndOrCombinationEvaluatesCorrectly() {
        // (NOT (orientation: portrait)) AND ((width >= 768) OR (print))
        let q = MediaQuery.logical(op: .and, conditions: [
            .not(.orientation(.portrait)),
            .logical(op: .or, conditions: [
                .width(operator: .greaterThanOrEqual, value: 768, unit: .px),
                .type(.print),
            ]),
        ])
        // Landscape + wide → both branches true.
        XCTAssertTrue(q.matches(in: Viewport(width: 1024, orientation: .landscape)))
        // Landscape + narrow + print → first false on width, true on print.
        XCTAssertTrue(q.matches(in: Viewport(width: 320, orientation: .landscape, isPrint: true)))
        // Portrait → first AND clause fails.
        XCTAssertFalse(q.matches(in: Viewport(width: 1024, orientation: .portrait)))
        // Landscape + narrow + no print → second OR clause fails.
        XCTAssertFalse(q.matches(in: Viewport(width: 320, orientation: .landscape, isPrint: false)))
    }
}
