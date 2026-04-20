import XCTest
@testable import CSSLayout

/// Unit (a) — CSSTokenizer.
///
/// The tokenizer is the only layer that inspects raw CSS text. Every other
/// layer works on tokens. Tests here are the ONLY place tokens are asserted.
final class CSSTokenizerTests: XCTestCase {

    // MARK: Helpers

    /// Convenience: tokenize and drop `.whitespace` tokens to keep assertions
    /// focused on structure. Use `CSSTokenizer.tokenize(_:)` directly when
    /// whitespace is load-bearing (e.g. descendant combinator in Phase 2).
    private func tokens(_ s: String) -> [CSSToken] {
        CSSTokenizer.tokenize(s).filter { $0 != .whitespace }
    }

    // MARK: Selectors

    func testTokenizesIDSelector() {
        XCTAssertEqual(tokens("#foo"), [.hash("foo"), .eof])
    }

    func testTokenizesClassSelector() {
        XCTAssertEqual(tokens(".primary"), [.dot, .ident("primary"), .eof])
    }

    func testTokenizesElementSelector() {
        XCTAssertEqual(tokens("button"), [.ident("button"), .eof])
    }

    // MARK: Declaration block

    func testTokenizesDeclarationBlock() {
        // `#a { color: red; }` without whitespace should expand into:
        // [ .hash("a"), .lbrace, .ident("color"), .colon, .ident("red"),
        //   .semicolon, .rbrace, .eof ]
        XCTAssertEqual(
            tokens("#a { color: red; }"),
            [
                .hash("a"),
                .lbrace,
                .ident("color"),
                .colon,
                .ident("red"),
                .semicolon,
                .rbrace,
                .eof,
            ]
        )
    }

    // MARK: Numbers & units

    func testTokenizesPixelNumber() {
        XCTAssertEqual(tokens("16px"), [.number(16, unit: "px"), .eof])
    }

    func testTokenizesPercentage() {
        XCTAssertEqual(tokens("50%"), [.percentage(50), .eof])
    }

    func testTokenizesUnitlessNumber() {
        XCTAssertEqual(tokens("1"), [.number(1, unit: nil), .eof])
    }

    func testTokenizesDecimalNumber() {
        XCTAssertEqual(tokens("0.5rem"), [.number(0.5, unit: "rem"), .eof])
    }

    func testTokenizesLeadingDotDecimal() {
        // `.5px` — the leading `.` starts a number, not a `.dot` punctuation.
        XCTAssertEqual(tokens(".5px"), [.number(0.5, unit: "px"), .eof])
    }

    func testTokenizesNegativeNumber() {
        XCTAssertEqual(tokens("-1"), [.number(-1, unit: nil), .eof])
    }

    // MARK: Comments & whitespace

    func testStripsBlockComments() {
        XCTAssertEqual(tokens("/* hi */ #a {}"),
                       [.hash("a"), .lbrace, .rbrace, .eof])
    }

    func testCommentInsideDeclarationIsStripped() {
        XCTAssertEqual(
            tokens("#a { /* nope */ color: red; }"),
            [
                .hash("a"), .lbrace,
                .ident("color"), .colon, .ident("red"), .semicolon,
                .rbrace, .eof,
            ]
        )
    }

    func testWhitespaceIsEmittedAsAToken() {
        // Use the raw tokenizer output; whitespace should appear as a single
        // .whitespace token regardless of how many spaces/tabs/newlines.
        let raw = CSSTokenizer.tokenize("  \t\n  ")
        XCTAssertEqual(raw, [.whitespace, .eof])
    }

    // MARK: Identifiers

    func testPreservesHyphensInIdent() {
        XCTAssertEqual(tokens("flex-direction"),
                       [.ident("flex-direction"), .eof])
    }

    func testHyphenInHashValue() {
        XCTAssertEqual(tokens("#first-name"),
                       [.hash("first-name"), .eof])
    }

    // MARK: At-rules

    func testAtKeyword() {
        XCTAssertEqual(tokens("@media"),
                       [.atKeyword("media"), .eof])
    }

    // MARK: Punctuation

    func testPunctuation() {
        XCTAssertEqual(
            tokens(":;,>{}"),
            [.colon, .semicolon, .comma, .gt, .lbrace, .rbrace, .eof]
        )
    }

    // MARK: Strings

    func testTokenizesDoubleQuotedString() {
        XCTAssertEqual(tokens("\"hello\""),
                       [.string("hello"), .eof])
    }

    func testTokenizesSingleQuotedString() {
        XCTAssertEqual(tokens("'hello'"),
                       [.string("hello"), .eof])
    }

    // MARK: Empty / edge cases

    func testEmptyInputYieldsOnlyEOF() {
        XCTAssertEqual(tokens(""), [.eof])
    }

    func testUnknownCharacterIsSkipped() {
        // Phase 1: tolerant — unknown bytes are dropped silently.
        // (A diagnostic will be wired at the parser layer.)
        XCTAssertEqual(tokens("#a ~ #b"),
                       [.hash("a"), .hash("b"), .eof])
    }
}
