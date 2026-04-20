// CSSTokenizer — a minimal CSS lexer for the flexbox-only subset.
//
// Index-based scanner over `String.UnicodeScalarView`. No regex. Tolerant:
// unknown characters are silently dropped (the parser layer emits diagnostics
// when context matters).

import Foundation

/// Turns a CSS source string into a stream of ``CSSToken`` values.
///
/// This is the only layer in CSSLayout that inspects raw text. Every other
/// unit consumes tokens.
public enum CSSTokenizer {

    /// Tokenize `input`. Always terminates with a `.eof` token.
    public static func tokenize(_ input: String) -> [CSSToken] {
        var scanner = Scanner(input)
        var out: [CSSToken] = []
        while let token = scanner.next() {
            out.append(token)
        }
        out.append(.eof)
        return out
    }
}

// MARK: - Scanner

private struct Scanner {
    private let scalars: [Unicode.Scalar]
    private var i: Int = 0

    init(_ s: String) {
        self.scalars = Array(s.unicodeScalars)
    }

    mutating func next() -> CSSToken? {
        // Skip block comments up-front so `/* ... */` never produces a token.
        skipComments()
        guard i < scalars.count else { return nil }

        let c = scalars[i]

        // Whitespace run — collapse to a single .whitespace token.
        if Self.isWhitespace(c) {
            while i < scalars.count && (Self.isWhitespace(scalars[i]) || peekCommentStart()) {
                if peekCommentStart() {
                    skipComments()
                } else {
                    i += 1
                }
            }
            return .whitespace
        }

        // Punctuation
        switch c {
        case ":": i += 1; return .colon
        case ";": i += 1; return .semicolon
        case ",": i += 1; return .comma
        case "{": i += 1; return .lbrace
        case "}": i += 1; return .rbrace
        case ">": i += 1; return .gt
        default: break
        }

        // Strings
        if c == "\"" || c == "'" {
            return readString(quote: c)
        }

        // Hash: `#` followed by ident chars.
        if c == "#" {
            i += 1
            let name = readIdent()
            return .hash(name)
        }

        // At-keyword: `@` followed by ident chars.
        if c == "@" {
            i += 1
            let name = readIdent()
            return .atKeyword(name)
        }

        // Numbers: digit, or `.` followed by digit, or sign followed by digit.
        if Self.isDigit(c) {
            return readNumber(signedNegative: false)
        }
        if c == "." {
            if i + 1 < scalars.count && Self.isDigit(scalars[i + 1]) {
                return readNumber(signedNegative: false)
            }
            i += 1
            return .dot
        }
        if c == "-" && i + 1 < scalars.count {
            let next = scalars[i + 1]
            if Self.isDigit(next) || (next == "." && i + 2 < scalars.count && Self.isDigit(scalars[i + 2])) {
                i += 1  // consume sign
                return readNumber(signedNegative: true)
            }
            // Bare `-foo` is a valid ident start in CSS (e.g. custom props),
            // which we don't need in Phase 1 — fall through to ident path.
        }

        // Identifier
        if Self.isIdentStart(c) {
            let name = readIdent()
            return .ident(name)
        }

        // Unknown character — skip silently (tolerant mode).
        i += 1
        return next()
    }

    // MARK: Sub-scanners

    private mutating func readIdent() -> String {
        var out = ""
        while i < scalars.count, Self.isIdentContinue(scalars[i]) {
            out.unicodeScalars.append(scalars[i])
            i += 1
        }
        return out
    }

    private mutating func readNumber(signedNegative: Bool) -> CSSToken {
        var digits = ""
        // Integer portion
        while i < scalars.count, Self.isDigit(scalars[i]) {
            digits.unicodeScalars.append(scalars[i])
            i += 1
        }
        // Fractional portion
        if i < scalars.count, scalars[i] == ".",
           i + 1 < scalars.count, Self.isDigit(scalars[i + 1]) {
            digits.append(".")
            i += 1
            while i < scalars.count, Self.isDigit(scalars[i]) {
                digits.unicodeScalars.append(scalars[i])
                i += 1
            }
        }
        // Leading-dot case: `digits` is empty but the scanner's cursor sits
        // on the `.`. Emit a leading `0` so `Double(".5")` parses as 0.5.
        if digits.isEmpty, i < scalars.count, scalars[i] == "." {
            digits = "0"
            digits.append(".")
            i += 1
            while i < scalars.count, Self.isDigit(scalars[i]) {
                digits.unicodeScalars.append(scalars[i])
                i += 1
            }
        }

        var value = Double(digits) ?? 0
        if signedNegative { value = -value }

        // Percentage
        if i < scalars.count, scalars[i] == "%" {
            i += 1
            return .percentage(value)
        }
        // Unit (ident immediately following number, no whitespace)
        if i < scalars.count, Self.isIdentStart(scalars[i]) {
            let unit = readIdent()
            return .number(value, unit: unit)
        }
        return .number(value, unit: nil)
    }

    private mutating func readString(quote: Unicode.Scalar) -> CSSToken {
        i += 1  // consume opening quote
        var out = ""
        while i < scalars.count, scalars[i] != quote {
            // Simple escape handling: `\X` → X
            if scalars[i] == "\\", i + 1 < scalars.count {
                out.unicodeScalars.append(scalars[i + 1])
                i += 2
                continue
            }
            out.unicodeScalars.append(scalars[i])
            i += 1
        }
        if i < scalars.count { i += 1 }  // consume closing quote if present
        return .string(out)
    }

    private mutating func skipComments() {
        while peekCommentStart() {
            i += 2  // consume `/*`
            while i + 1 < scalars.count, !(scalars[i] == "*" && scalars[i + 1] == "/") {
                i += 1
            }
            if i + 1 < scalars.count { i += 2 }  // consume `*/`
            else { i = scalars.count }           // unterminated — drop to EOF
        }
    }

    private func peekCommentStart() -> Bool {
        i + 1 < scalars.count && scalars[i] == "/" && scalars[i + 1] == "*"
    }

    // MARK: Character classes

    private static func isWhitespace(_ c: Unicode.Scalar) -> Bool {
        c == " " || c == "\t" || c == "\n" || c == "\r" || c == "\u{000C}"
    }

    private static func isDigit(_ c: Unicode.Scalar) -> Bool {
        c >= "0" && c <= "9"
    }

    private static func isIdentStart(_ c: Unicode.Scalar) -> Bool {
        (c >= "a" && c <= "z") || (c >= "A" && c <= "Z") || c == "_" || c == "-"
    }

    private static func isIdentContinue(_ c: Unicode.Scalar) -> Bool {
        isIdentStart(c) || isDigit(c)
    }
}
