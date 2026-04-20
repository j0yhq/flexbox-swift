// SelectorParser — Phase 1 simple-selector parser.
//
// Accepts exactly one of:
//   •  `#ident`   → `.id(ident)`
//   •  `.ident`   → `.class(ident)`
//   •  `ident`    → `.element(ident)`
//
// Anything else (attribute `[…]`, pseudo `:x` / `::x`, combinators `>` or
// descendant whitespace, grouping `,`) emits a diagnostic under
// `CSSWarning.Kind.unsupportedSelector(<category>)` and returns `nil`. The
// caller drops the rule and moves on — CSSLayout is tolerant by design.
//
// We scan the raw (trimmed) source rather than routing through `CSSTokenizer`
// because the tokenizer intentionally drops characters outside the flexbox
// subset (e.g. `[`, `]`, `(`). Detecting unsupported-selector shapes requires
// seeing those characters, so a tiny raw-string scan is the right tool here.

import Foundation

/// Parses a **single simple selector** source string into a ``SimpleSelector``.
///
/// Not a full CSS selector parser — Phase 1 deliberately rejects combinators,
/// grouping, attributes, and pseudos. Phase 2 will introduce `ComplexSelector`
/// and expand this API.
public enum SelectorParser {

    /// Parse `source` as a simple selector.
    ///
    /// - Parameters:
    ///   - source: The raw selector text (between `<css>{` and the `{`).
    ///   - diagnostics: Accumulator; one warning is appended per unsupported
    ///     selector shape.
    /// - Returns: The parsed ``SimpleSelector``, or `nil` if the input is
    ///   empty, malformed, or uses unsupported CSS.
    public static func parse(
        _ source: String,
        diagnostics: inout CSSDiagnostics
    ) -> SimpleSelector? {
        let trimmed = source.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }

        // Detect unsupported shapes up-front. Order matters only where more
        // than one category could match a single string; for the Phase 1
        // rejection set, the categories are mutually exclusive for realistic
        // inputs, so we pick the most specific signal first.

        if trimmed.contains("[") || trimmed.contains("]") {
            diagnostics.warn(.init(.unsupportedSelector("attribute"), trimmed))
            return nil
        }
        if trimmed.contains(",") {
            diagnostics.warn(.init(.unsupportedSelector("grouping"), trimmed))
            return nil
        }
        if trimmed.contains(">") {
            diagnostics.warn(.init(.unsupportedSelector("combinator"), trimmed))
            return nil
        }
        if trimmed.contains(":") {
            // Covers both `:hover` (pseudo-class) and `::before` (pseudo-element).
            diagnostics.warn(.init(.unsupportedSelector("pseudo"), trimmed))
            return nil
        }
        // Internal whitespace after trimming ⇒ descendant combinator.
        if trimmed.unicodeScalars.contains(where: { isASCIIWhitespace($0) }) {
            diagnostics.warn(.init(.unsupportedSelector("combinator"), trimmed))
            return nil
        }

        // Simple selector parse: look at the first character.
        let scalars = Array(trimmed.unicodeScalars)
        let first = scalars[0]

        if first == "#" {
            let name = String(String.UnicodeScalarView(scalars.dropFirst()))
            guard isValidIdent(name) else { return nil }
            return .id(name)
        }
        if first == "." {
            let name = String(String.UnicodeScalarView(scalars.dropFirst()))
            guard isValidIdent(name) else { return nil }
            return .class(name)
        }
        if isIdentStart(first) {
            guard isValidIdent(trimmed) else { return nil }
            return .element(trimmed)
        }

        // Anything else (numbers leading, `*` universal, `&` nesting, etc.)
        // isn't supported in Phase 1 and isn't worth a specialized warning.
        return nil
    }

    // MARK: - Character classes (mirror CSSTokenizer's rules)

    private static func isASCIIWhitespace(_ c: Unicode.Scalar) -> Bool {
        c == " " || c == "\t" || c == "\n" || c == "\r" || c == "\u{000C}"
    }

    private static func isIdentStart(_ c: Unicode.Scalar) -> Bool {
        (c >= "a" && c <= "z") || (c >= "A" && c <= "Z") || c == "_" || c == "-"
    }

    private static func isIdentContinue(_ c: Unicode.Scalar) -> Bool {
        isIdentStart(c) || (c >= "0" && c <= "9")
    }

    private static func isValidIdent(_ s: String) -> Bool {
        let scalars = Array(s.unicodeScalars)
        guard let head = scalars.first, isIdentStart(head) else { return false }
        for c in scalars.dropFirst() where !isIdentContinue(c) { return false }
        return true
    }
}
