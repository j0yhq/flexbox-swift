import XCTest
@testable import CSSLayout

/// Unit (b) — Selector AST + SelectorParser + Specificity.
///
/// Phase 1 supports **simple selectors only**: ID, class, element. Everything
/// else (combinators, attributes, pseudos) emits a diagnostic and returns nil.
final class SelectorParserTests: XCTestCase {

    // MARK: Helpers

    private func parse(_ s: String) -> (CompoundSelector?, CSSDiagnostics) {
        var diags = CSSDiagnostics()
        let result = SelectorParser.parse(s, diagnostics: &diags)
        return (result, diags)
    }

    // MARK: Happy path

    func testParsesIDSelector() {
        let (sel, diags) = parse("#submit")
        XCTAssertEqual(sel, .id("submit"))
        XCTAssertEqual(diags.warnings.count, 0)
    }

    func testParsesClassSelector() {
        let (sel, diags) = parse(".primary")
        XCTAssertEqual(sel, .class("primary"))
        XCTAssertEqual(diags.warnings.count, 0)
    }

    func testParsesElementSelector() {
        let (sel, diags) = parse("button")
        XCTAssertEqual(sel, .element("button"))
        XCTAssertEqual(diags.warnings.count, 0)
    }

    func testParsesHyphenatedIdent() {
        XCTAssertEqual(parse("text-input").0, .element("text-input"))
        XCTAssertEqual(parse("#first-name").0, .id("first-name"))
        XCTAssertEqual(parse(".btn-primary").0, .class("btn-primary"))
    }

    func testTolerantOfSurroundingWhitespace() {
        XCTAssertEqual(parse("  #a  ").0, .id("a"))
    }

    // MARK: Rejections with diagnostics

    func testRejectsAttributeSelector() {
        let (sel, diags) = parse("[data-x=\"y\"]")
        XCTAssertNil(sel)
        XCTAssertEqual(diags.count(of: .unsupportedSelector("attribute")), 1)
    }

    func testRejectsPseudoClassSelector() {
        let (sel, diags) = parse("a:hover")
        XCTAssertNil(sel)
        XCTAssertEqual(diags.count(of: .unsupportedSelector("pseudo")), 1)
    }

    func testRejectsPseudoElementSelector() {
        let (sel, diags) = parse("p::before")
        XCTAssertNil(sel)
        XCTAssertEqual(diags.count(of: .unsupportedSelector("pseudo")), 1)
    }

    func testRejectsChildCombinator() {
        let (sel, diags) = parse("#a > #b")
        XCTAssertNil(sel)
        XCTAssertEqual(diags.count(of: .unsupportedSelector("combinator")), 1)
    }

    func testRejectsDescendantCombinator() {
        let (sel, diags) = parse("#form #name")
        XCTAssertNil(sel)
        XCTAssertEqual(diags.count(of: .unsupportedSelector("combinator")), 1)
    }

    func testRejectsGrouping() {
        let (sel, diags) = parse("#a, #b")
        XCTAssertNil(sel)
        XCTAssertEqual(diags.count(of: .unsupportedSelector("grouping")), 1)
    }

    func testEmptyInputReturnsNil() {
        let (sel, _) = parse("")
        XCTAssertNil(sel)
    }

    // MARK: Specificity

    func testSpecificityOfID() {
        XCTAssertEqual(Specificity.of(.id("a")), Specificity(a: 0, b: 1, c: 0, d: 0))
    }

    func testSpecificityOfClass() {
        XCTAssertEqual(Specificity.of(.class("a")), Specificity(a: 0, b: 0, c: 1, d: 0))
    }

    func testSpecificityOfElement() {
        XCTAssertEqual(Specificity.of(.element("a")), Specificity(a: 0, b: 0, c: 0, d: 1))
    }

    func testSpecificityOrdering() {
        // ID > class > element, lexicographically on (a, b, c, d).
        let id    = Specificity.of(.id("x"))
        let cls   = Specificity.of(.class("x"))
        let elem  = Specificity.of(.element("x"))
        XCTAssertTrue(id > cls)
        XCTAssertTrue(cls > elem)
        XCTAssertTrue(id > elem)
    }

    func testSpecificityEquality() {
        XCTAssertEqual(Specificity.of(.id("a")), Specificity.of(.id("b")))
    }

    // MARK: - Grouping (Phase 2)

    /// `parseList` is the grouping-aware entry point used by `RuleParser`. The
    /// single-selector `parse` function still rejects a comma prelude outright,
    /// so only `parseList` expands a group into multiple selectors.
    private func parseList(_ s: String) -> ([CompoundSelector], CSSDiagnostics) {
        var diags = CSSDiagnostics()
        let result = SelectorParser.parseList(s, diagnostics: &diags)
        return (result, diags)
    }

    func testParseListReturnsSingleSelector() {
        let (list, diags) = parseList("#a")
        XCTAssertEqual(list, [.id("a")])
        XCTAssertEqual(diags.warnings.count, 0)
    }

    func testParseListSplitsOnComma() {
        let (list, diags) = parseList("#a, #b, .c")
        XCTAssertEqual(list, [.id("a"), .id("b"), .class("c")])
        XCTAssertEqual(diags.warnings.count, 0)
    }

    func testParseListTrimsEachMember() {
        let (list, diags) = parseList("  #a  ,\n\t.b\n")
        XCTAssertEqual(list, [.id("a"), .class("b")])
        XCTAssertEqual(diags.warnings.count, 0)
    }

    func testParseListSkipsEmptyMembers() {
        // Trailing comma, doubled commas — tolerated, no diagnostic.
        let (list, diags) = parseList("#a,,#b,")
        XCTAssertEqual(list, [.id("a"), .id("b")])
        XCTAssertEqual(diags.warnings.count, 0)
    }

    func testParseListCollectsValidPartsAndWarnsOnInvalid() {
        // One valid + one attribute selector → [valid], 1 warning.
        let (list, diags) = parseList("#a, [data-x]")
        XCTAssertEqual(list, [.id("a")])
        XCTAssertEqual(diags.count(of: .unsupportedSelector("attribute")), 1)
    }

    func testParseListEmptyInputYieldsEmpty() {
        let (list, diags) = parseList("")
        XCTAssertEqual(list, [])
        XCTAssertEqual(diags.warnings.count, 0)
    }

    // MARK: - Compound selectors (Phase 2)

    func testParsesCompoundElementAndClass() {
        let (sel, diags) = parse("button.primary")
        XCTAssertEqual(sel, CompoundSelector([.element("button"), .class("primary")]))
        XCTAssertEqual(diags.warnings.count, 0)
    }

    func testParsesCompoundElementClassID() {
        let (sel, _) = parse("button.primary#submit")
        XCTAssertEqual(sel, CompoundSelector([
            .element("button"), .class("primary"), .id("submit"),
        ]))
    }

    func testParsesCompoundMultipleClasses() {
        let (sel, _) = parse(".a.b.c")
        XCTAssertEqual(sel, CompoundSelector([.class("a"), .class("b"), .class("c")]))
    }

    func testParsesCompoundIDThenClass() {
        let (sel, _) = parse("#submit.primary")
        XCTAssertEqual(sel, CompoundSelector([.id("submit"), .class("primary")]))
    }

    func testRejectsEmptyIdentAfterMarker() {
        // `#` / `.` with no ident following is invalid; no diagnostic (we
        // already classify the malformed selector as "couldn't parse").
        let (sel1, _) = parse("#")
        XCTAssertNil(sel1)
        let (sel2, _) = parse(".")
        XCTAssertNil(sel2)
        let (sel3, _) = parse("button#")
        XCTAssertNil(sel3)
    }

    // MARK: - Compound specificity

    func testSpecificityOfCompoundSumsContributions() {
        let compound = CompoundSelector([
            .element("button"), .class("primary"), .id("submit"),
        ])
        XCTAssertEqual(Specificity.of(compound), Specificity(a: 0, b: 1, c: 1, d: 1))
    }

    func testSpecificityOfMultipleClasses() {
        let compound = CompoundSelector([.class("a"), .class("b"), .class("c")])
        XCTAssertEqual(Specificity.of(compound), Specificity(a: 0, b: 0, c: 3, d: 0))
    }

    func testSpecificityOfSingleCompoundMatchesSimple() {
        // A compound of length one carries the same specificity as the bare
        // simple selector it wraps.
        XCTAssertEqual(
            Specificity.of(CompoundSelector([.id("a")])),
            Specificity.of(part: .id("a"))
        )
    }
}
