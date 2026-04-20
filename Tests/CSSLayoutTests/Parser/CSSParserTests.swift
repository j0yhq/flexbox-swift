import XCTest
@testable import CSSLayout

/// Unit (f) — `CSSParser.parse(...)` is the public entry point that wraps
/// `RuleParser.parseRules` in a `Stylesheet`. It owns the tolerance contract:
/// never throws, always returns a stylesheet, accumulates diagnostics.
final class CSSParserTests: XCTestCase {

    // MARK: - Helpers

    private func parse(_ css: String) -> (Stylesheet, CSSDiagnostics) {
        var diags = CSSDiagnostics()
        let sheet = CSSParser.parse(css, diagnostics: &diags)
        return (sheet, diags)
    }

    // MARK: - Happy path

    func testParsesTwoRules() {
        let (sheet, diags) = parse("#a { flex: 1; } .b { gap: 8px; }")
        XCTAssertEqual(sheet.rules.count, 2)
        XCTAssertEqual(sheet.rules[0].selector, .id("a"))
        XCTAssertEqual(sheet.rules[1].selector, .class("b"))
        XCTAssertEqual(diags.warnings.count, 0)
    }

    func testStripsComments() {
        let (sheet, _) = parse("""
            /* top */
            #a { flex: 1; } /* trailing */
        """)
        XCTAssertEqual(sheet.rules.count, 1)
    }

    // MARK: - Tolerance

    func testEmptyInputYieldsEmptyStylesheet() {
        let (sheet, diags) = parse("")
        XCTAssertEqual(sheet.rules.count, 0)
        XCTAssertEqual(diags.warnings.count, 0)
    }

    func testRecoversFromMalformedRule() {
        // First rule has an unparseable selector, second is well-formed.
        let (sheet, _) = parse("[bad]{flex:1;} #b{flex:2;}")
        XCTAssertEqual(sheet.rules.count, 1)
        XCTAssertEqual(sheet.rules.first?.selector, .id("b"))
    }

    func testMalformedClosingBraceDoesNotCrash() {
        // Completely adversarial input — no assertion other than "we returned."
        let (sheet, _) = parse("#a{{{{")
        XCTAssertNotNil(sheet)
    }

    func testNeverThrows() {
        // Document intent: `parse` is not `throws`. If the signature regresses
        // to throwing, this file stops compiling — which is the assertion.
        var diags = CSSDiagnostics()
        _ = CSSParser.parse("garbage ;;;; {{{} }} !@#", diagnostics: &diags)
    }

    // MARK: - Diagnostics accumulate

    func testDiagnosticsAccumulate() {
        let (_, diags) = parse("""
            #a { margin: 8px; }
            @media (min-width: 100px) { #b { flex: 1; } }
            :hover { flex: 1; }
        """)
        XCTAssertGreaterThanOrEqual(diags.warnings.count, 3)
    }
}
