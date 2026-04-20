import XCTest
@testable import CSSLayout

/// Unit (d) — `DeclarationParser` turns a declaration-block body into a list
/// of `Declaration` values, emitting diagnostics for unsupported properties.
///
/// The parser is tolerant: missing semicolons, stray whitespace, and
/// `!important` suffixes are all accepted without hard failure.
final class DeclarationParserTests: XCTestCase {

    // MARK: - Helpers

    private func parse(_ body: String) -> ([Declaration], CSSDiagnostics) {
        var diags = CSSDiagnostics()
        let decls = DeclarationParser.parse(body, diagnostics: &diags)
        return (decls, diags)
    }

    // MARK: - Happy path

    func testParsesSingleDeclaration() {
        let (decls, diags) = parse("flex: 1;")
        XCTAssertEqual(decls.count, 1)
        XCTAssertEqual(decls[0].property, "flex")
        XCTAssertEqual(decls[0].value, "1")
        XCTAssertEqual(diags.warnings.count, 0)
    }

    func testParsesMultipleDeclarations() {
        let (decls, _) = parse("gap: 8px; padding: 4px;")
        XCTAssertEqual(decls.count, 2)
        XCTAssertEqual(decls[0].property, "gap")
        XCTAssertEqual(decls[0].value, "8px")
        XCTAssertEqual(decls[1].property, "padding")
        XCTAssertEqual(decls[1].value, "4px")
    }

    func testTolerantOfMissingTrailingSemicolon() {
        let (decls, _) = parse("flex-grow: 1; flex-shrink: 0")
        XCTAssertEqual(decls.count, 2)
        XCTAssertEqual(decls[1].property, "flex-shrink")
        XCTAssertEqual(decls[1].value, "0")
    }

    func testPropertyNameIsLowercased() {
        let (decls, _) = parse("FLEX-DIRECTION: row;")
        XCTAssertEqual(decls.first?.property, "flex-direction")
        XCTAssertEqual(decls.first?.value, "row")
    }

    func testTrimsWhitespaceAroundValue() {
        let (decls, _) = parse("gap:   16px   ;")
        XCTAssertEqual(decls.first?.value, "16px")
    }

    func testPreservesInternalValueWhitespace() {
        // Shorthand values depend on whitespace inside the value — keep it.
        let (decls, _) = parse("flex: 1 1 120px;")
        XCTAssertEqual(decls.first?.value, "1 1 120px")
    }

    func testStripsImportantSuffix() {
        let (decls, _) = parse("flex: 1 !important;")
        XCTAssertEqual(decls.first?.value, "1")
    }

    func testStripsImportantSuffixCaseInsensitive() {
        let (decls, _) = parse("flex: 2 !IMPORTANT;")
        XCTAssertEqual(decls.first?.value, "2")
    }

    func testSkipsEmptyDeclarations() {
        // Stray `;;` should not produce empty-string declarations.
        let (decls, _) = parse(";;flex: 1;;")
        XCTAssertEqual(decls.count, 1)
    }

    func testEmptyBodyYieldsNothing() {
        let (decls, diags) = parse("")
        XCTAssertEqual(decls.count, 0)
        XCTAssertEqual(diags.warnings.count, 0)
    }

    // MARK: - Diagnostics

    func testUnsupportedPropertyEmitsDiagnosticAndIsDropped() {
        let (decls, diags) = parse("margin: 8px; flex: 1;")
        XCTAssertEqual(decls.count, 1)
        XCTAssertEqual(decls[0].property, "flex")
        XCTAssertEqual(diags.count(of: .unsupportedProperty("margin")), 1)
    }

    func testMultipleUnsupportedPropertiesEachEmitDiagnostic() {
        let (decls, diags) = parse("margin: 8px; background: red; color: blue;")
        XCTAssertEqual(decls.count, 0)
        XCTAssertEqual(diags.count(of: .unsupportedProperty("margin")),     1)
        XCTAssertEqual(diags.count(of: .unsupportedProperty("background")), 1)
        XCTAssertEqual(diags.count(of: .unsupportedProperty("color")),      1)
    }

    func testMalformedDeclarationWithoutColonIsSkipped() {
        let (decls, _) = parse("flex 1; flex: 2;")
        XCTAssertEqual(decls.count, 1)
        XCTAssertEqual(decls[0].value, "2")
    }

    // MARK: - Allow-list coverage

    func testAllSupportedContainerPropertiesAccepted() {
        let body = """
            flex-direction: row;
            flex-wrap: wrap;
            justify-content: center;
            align-items: stretch;
            align-content: stretch;
            gap: 8px;
            row-gap: 4px;
            column-gap: 4px;
            padding: 4px;
            padding-top: 4px;
            padding-bottom: 4px;
            padding-left: 4px;
            padding-right: 4px;
            overflow: visible;
        """
        let (decls, diags) = parse(body)
        XCTAssertEqual(decls.count, 14)
        XCTAssertEqual(diags.warnings.count, 0)
    }

    func testAllSupportedItemPropertiesAccepted() {
        let body = """
            flex: 1;
            flex-grow: 1;
            flex-shrink: 0;
            flex-basis: 120px;
            align-self: center;
            order: 2;
            width: 100px;
            height: 50%;
            overflow: hidden;
            z-index: 3;
            position: absolute;
            top: 0;
            bottom: 0;
            left: 0;
            right: 0;
            display: flex;
        """
        let (decls, diags) = parse(body)
        XCTAssertEqual(decls.count, 16)
        XCTAssertEqual(diags.warnings.count, 0)
    }
}
