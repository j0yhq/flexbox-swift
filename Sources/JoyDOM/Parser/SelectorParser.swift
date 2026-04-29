// SelectorParser — parses a CSS selector source string into a
// `ComplexSelector` (Phase 2).
//
// Supported shapes:
//   •  a simple selector           `#id`, `.class`, `element`
//   •  a compound selector chain   `button.primary#submit`
//   •  descendant combinator       `#form #name`      (whitespace)
//   •  child combinator            `#form > #name`    (explicit `>`)
//   •  selector list via `parseList`  `#a, #b { … }`
//
// Rejected (emit `.unsupportedSelector(<category>)` and return `nil`):
//   •  attribute selectors     `[data-x]`
//   •  pseudo classes/elements `:hover`, `::before`
//   •  grouping via comma at the single-selector entry point
//     (the grouping-aware `parseList` splits commas before calling `parse`)
//
// The scan walks raw `String.UnicodeScalarView` rather than routing through
// `CSSTokenizer`: the tokenizer intentionally drops characters like `[` and
// `(` that we need to see to classify unsupported shapes correctly.

import Foundation

/// Parses a CSS selector string into a ``ComplexSelector``.
public enum SelectorParser {

    /// Parse a **selector list** — `sel, sel, …` — into the sequence of
    /// complex selectors it expands to.
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
        diagnostics: inout JoyDiagnostics
    ) -> [ComplexSelector] {
        var result: [ComplexSelector] = []
        for part in source.split(separator: ",", omittingEmptySubsequences: false) {
            let trimmed = part.trimmingCharacters(in: .whitespacesAndNewlines)
            if trimmed.isEmpty { continue }           // tolerate `,,` and trailing `,`
            if let s = parse(trimmed, diagnostics: &diagnostics) {
                result.append(s)
            }
        }
        return result
    }

    /// Parse `source` as a **complex selector** — one or more compound
    /// selectors joined by descendant or child combinators.
    public static func parse(
        _ source: String,
        diagnostics: inout JoyDiagnostics
    ) -> ComplexSelector? {
        let trimmed = source.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }

        // Reject unsupported shapes up-front. Combinators (`>` and whitespace)
        // are now parsed, not rejected.
        if trimmed.contains("[") || trimmed.contains("]") {
            diagnostics.warn(.init(.unsupportedSelector("attribute"), trimmed))
            return nil
        }
        if trimmed.contains(",") {
            diagnostics.warn(.init(.unsupportedSelector("grouping"), trimmed))
            return nil
        }
        if trimmed.contains(":") {
            diagnostics.warn(.init(.unsupportedSelector("pseudo"), trimmed))
            return nil
        }

        // Walk the scan: read one compound, then alternately read
        // combinators (descendant / child) and compounds until the input is
        // consumed. A dangling combinator at either end fails the parse.

        let scalars = Array(trimmed.unicodeScalars)
        var i = 0

        guard let first = parseCompound(scalars, at: &i) else { return nil }
        var parts = [first]
        var combinators: [Combinator] = []

        while i < scalars.count {
            // Collect whitespace; decide between descendant and child
            // combinator based on whether the next non-whitespace char is `>`.
            let hadSpace = skipASCIIWhitespace(scalars, at: &i)
            guard i < scalars.count else { break }          // trailing whitespace — done

            let combinator: Combinator
            if scalars[i] == ">" {
                i += 1
                _ = skipASCIIWhitespace(scalars, at: &i)
                combinator = .child
            } else if hadSpace {
                combinator = .descendant
            } else {
                // No whitespace and no `>` — malformed.
                return nil
            }

            guard let next = parseCompound(scalars, at: &i) else {
                // Dangling combinator with no right-hand compound.
                return nil
            }
            combinators.append(combinator)
            parts.append(next)
        }

        return ComplexSelector(parts: parts, combinators: combinators)
    }

    // MARK: - Compound scan

    /// Scan one compound selector (`element? (#id | .class)*`) starting at
    /// `i`. Advances `i` past the consumed characters. Returns `nil` if the
    /// scan cannot yield a non-empty compound.
    private static func parseCompound(
        _ scalars: [Unicode.Scalar],
        at i: inout Int
    ) -> CompoundSelector? {
        var parts: [SimpleSelector] = []

        // Optional leading element selector.
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
            guard marker == "#" || marker == "." else { break }
            i += 1
            let start = i
            while i < scalars.count, isIdentContinue(scalars[i]) { i += 1 }
            guard start < i else { return nil }             // empty ident after marker
            let name = String(String.UnicodeScalarView(scalars[start..<i]))
            parts.append(marker == "#" ? .id(name) : .class(name))
        }

        guard !parts.isEmpty else { return nil }
        return CompoundSelector(parts)
    }

    /// Advance `i` past any ASCII whitespace; return whether any was skipped.
    @discardableResult
    private static func skipASCIIWhitespace(
        _ scalars: [Unicode.Scalar],
        at i: inout Int
    ) -> Bool {
        let start = i
        while i < scalars.count, isASCIIWhitespace(scalars[i]) { i += 1 }
        return i > start
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
}
