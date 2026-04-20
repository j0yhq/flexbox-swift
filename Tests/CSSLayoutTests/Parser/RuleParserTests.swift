import XCTest
@testable import CSSLayout

/// Unit (e) — `RuleParser` scans raw CSS for `selector { declarations }`
/// blocks and emits typed `CSSRule` values.
///
/// Source order (`sourceOrder`) is assigned monotonically in the order the
/// rules appear; it breaks specificity ties in the cascade.
final class RuleParserTests: XCTestCase {

    // MARK: - Helpers

    private func parse(_ css: String) -> ([CSSRule], CSSDiagnostics) {
        var diags = CSSDiagnostics()
        let rules = RuleParser.parseRules(from: css, diagnostics: &diags)
        return (rules, diags)
    }

    // MARK: - Happy path

    func testParsesSingleRule() {
        let (rules, diags) = parse("#a { flex: 1; gap: 8px; }")
        XCTAssertEqual(rules.count, 1)
        XCTAssertEqual(rules[0].selector, .id("a"))
        XCTAssertEqual(rules[0].declarations.count, 2)
        XCTAssertEqual(rules[0].specificity, Specificity(a: 0, b: 1, c: 0, d: 0))
        XCTAssertEqual(rules[0].sourceOrder, 0)
        XCTAssertEqual(diags.warnings.count, 0)
    }

    func testParsesMultipleRules() {
        let (rules, _) = parse("""
            #a { flex: 1; }
            .primary { gap: 8px; }
            button { order: 2; }
        """)
        XCTAssertEqual(rules.count, 3)
        XCTAssertEqual(rules[0].selector, .id("a"))
        XCTAssertEqual(rules[1].selector, .class("primary"))
        XCTAssertEqual(rules[2].selector, .element("button"))
    }

    func testAssignsMonotonicSourceOrder() {
        let (rules, _) = parse("#a{flex:1;} #b{flex:2;} #c{flex:3;}")
        XCTAssertEqual(rules.map(\.sourceOrder), [0, 1, 2])
    }

    func testRetainsDeclarationOrder() {
        let (rules, _) = parse("#a { flex-grow: 1; flex-shrink: 0; flex-basis: 120px; }")
        XCTAssertEqual(rules.first?.declarations.map(\.property),
                       ["flex-grow", "flex-shrink", "flex-basis"])
    }

    // MARK: - Diagnostic rejections

    func testSkipsRuleWithUnparseableSelector() {
        let (rules, diags) = parse("[data-x=\"y\"] { flex: 1; }")
        XCTAssertEqual(rules.count, 0)
        XCTAssertEqual(diags.count(of: .unsupportedSelector("attribute")), 1)
    }

    func testSkipsRuleWithCombinatorSelector() {
        let (rules, diags) = parse("#a > #b { flex: 1; }")
        XCTAssertEqual(rules.count, 0)
        XCTAssertEqual(diags.count(of: .unsupportedSelector("combinator")), 1)
    }

    func testSkipsAtRulesInPhase1() {
        let (rules, diags) = parse("""
            @media (max-width: 600px) {
                #a { flex: 1; }
            }
            #b { flex: 2; }
        """)
        XCTAssertEqual(rules.count, 1)
        XCTAssertEqual(rules.first?.selector, .id("b"))
        XCTAssertEqual(diags.count(of: .unsupportedAtRule("media")), 1)
    }

    func testUnsupportedPropertyInsideRuleEmitsDiagnosticButKeepsRule() {
        let (rules, diags) = parse("#a { margin: 8px; flex: 1; }")
        XCTAssertEqual(rules.count, 1)
        XCTAssertEqual(rules[0].declarations.count, 1)
        XCTAssertEqual(rules[0].declarations[0].property, "flex")
        XCTAssertEqual(diags.count(of: .unsupportedProperty("margin")), 1)
    }

    // MARK: - Edge cases

    func testEmptyBodyYieldsZeroDeclarations() {
        let (rules, _) = parse("#a {}")
        XCTAssertEqual(rules.count, 1)
        XCTAssertEqual(rules[0].declarations.count, 0)
    }

    func testTolerantOfMissingClosingBrace() {
        // Unterminated block — treat the remainder as the body, don't crash.
        let (rules, _) = parse("#a { flex: 1;")
        // Implementation choice: we accept the rule gracefully.
        XCTAssertEqual(rules.count, 1)
        XCTAssertEqual(rules[0].selector, .id("a"))
    }

    func testEmptyInputYieldsNoRules() {
        let (rules, diags) = parse("")
        XCTAssertEqual(rules.count, 0)
        XCTAssertEqual(diags.warnings.count, 0)
    }

    func testSkipsCommentsBetweenRules() {
        let (rules, _) = parse("""
            /* header */
            #a { flex: 1; }
            /* spacer */
            #b { flex: 2; }
        """)
        XCTAssertEqual(rules.count, 2)
    }
}
