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

    /// Parse a **selector list** — `sel, sel, …` — into the sequence of
    /// compound selectors it expands to.
    ///
    /// Grouping is a prelude-level construct: `#a, #b { flex: 1; }` produces
    /// two rules sharing the same declarations. This helper is the entry point
    /// `RuleParser` uses; `parse(_:diagnostics:)` remains strict (a grouped
    /// source string is still reported as `unsupportedSelector("grouping")`).
    ///
    /// Empty members (`#a,,#b`) are tolerated silently; unparseable members
    /// emit their usual `unsupportedSelector` diagnostic and are dropped while
    /// the valid ones are kept.
    public static func parseList(
        _ source: String,
        diagnostics: inout CSSDiagnostics
    ) -> [CompoundSelector] {
        var result: [CompoundSelector] = []
        for part in source.split(separator: ",", omittingEmptySubsequences: false) {
            let trimmed = part.trimmingCharacters(in: .whitespacesAndNewlines)
            if trimmed.isEmpty { continue }           // tolerate `,,` and trailing `,`
            if let s = parse(trimmed, diagnostics: &diagnostics) {
                result.append(s)
            }
        }
        return result
    }

    /// Parse `source` as a **compound selector** — a chain of simple
    /// selectors on the same subject, e.g. `button.primary#submit`.
    ///
    /// - Parameters:
    ///   - source: The raw selector text (between `<css>{` and the `{`).
    ///   - diagnostics: Accumulator; one warning is appended per unsupported
    ///     selector shape.
    /// - Returns: The parsed ``CompoundSelector``, or `nil` if the input is
    ///   empty, malformed, or uses unsupported CSS.
    public static func parse(
        _ source: String,
        diagnostics: inout CSSDiagnostics
    ) -> CompoundSelector? {
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

        // Compound selector parse — scan a chain of simple selectors.
        //
        // Grammar (per CSS Selectors Level 3, reduced):
        //   compound := element? (hash | klass)*
        //   element  := ident
        //   hash     := '#' ident
        //   klass    := '.' ident
        //
        // A second bare element would need a combinator to be meaningful; the
        // descendant-combinator / whitespace check above already rejects it.

        let scalars = Array(trimmed.unicodeScalars)
        var i = 0
        var parts: [SimpleSelector] = []

        // Optional leading element selector. The first char being an ident
        // starter means we pick up a type selector; `#` / `.` skip straight
        // to the hash/class loop.
        if i < scalars.count, isIdentStart(scalars[i]) {
            let start = i
            while i < scalars.count, isIdentContinue(scalars[i]) { i += 1 }
            parts.append(.element(
                String(String.UnicodeScalarView(scalars[start..<i]))
            ))
        }

        // Zero or more `#ident` / `.ident` parts.
        while i < scalars.count {
            let marker = scalars[i]
            guard marker == "#" || marker == "." else {
                // Anything other than a hash/class marker here is malformed.
                return nil
            }
            i += 1
            let start = i
            while i < scalars.count, isIdentContinue(scalars[i]) { i += 1 }
            guard start < i else { return nil }           // empty ident after marker
            let name = String(String.UnicodeScalarView(scalars[start..<i]))
            parts.append(marker == "#" ? .id(name) : .class(name))
        }

        guard !parts.isEmpty else { return nil }
        return CompoundSelector(parts)
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
