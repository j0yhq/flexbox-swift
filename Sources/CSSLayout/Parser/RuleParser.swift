// RuleParser — turns raw CSS text into a list of `CSSRule` values.
//
// Phase 1's CSS grammar is small enough that a character-level scan with
// brace matching is the clearest implementation. The scanner:
//
//   1. Strips `/* … */` comments (they can appear anywhere outside strings,
//      and no Phase 1 value type contains `/*`, so a text-level pass is safe).
//   2. Finds the next `{` — the preceding text is the selector prelude.
//   3. Matches the `}` that closes that block (brace-depth counting, so
//      nested `@media { #a { … } }` doesn't confuse us).
//   4. Dispatches on whether the prelude is an `@…` rule or a normal selector.
//      At-rules are rejected with `.unsupportedAtRule(name)`; normal rules go
//      through `SelectorParser` + `DeclarationParser`.
//
// The parser is tolerant: unterminated blocks are accepted with whatever
// body is available, and empty bodies produce zero-declaration rules.

import Foundation

/// Parses the top-level CSS text into `CSSRule` values.
public enum RuleParser {

    /// Scan `css` and return every valid rule in source order.
    ///
    /// - Parameters:
    ///   - css: The raw CSS text, typically the full `CSSPayload.css`.
    ///   - diagnostics: Accumulator; unsupported selectors/properties and
    ///     at-rule skips each append one warning.
    /// - Returns: Parsed rules. Rules whose selector can't be parsed are
    ///   dropped; rules with some unsupported declarations are kept with the
    ///   supported subset.
    public static func parseRules(
        from css: String,
        diagnostics: inout CSSDiagnostics
    ) -> [CSSRule] {
        let source = stripComments(css)
        var rules: [CSSRule] = []
        var sourceOrder = 0

        let scalars = Array(source.unicodeScalars)
        var i = 0

        while i < scalars.count {
            // Find next `{`.
            guard let openIdx = indexOf(scalars, from: i, char: "{") else {
                // No more blocks — we're done.
                break
            }

            let prelude = String(
                String.UnicodeScalarView(scalars[i..<openIdx])
            ).trimmingCharacters(in: .whitespacesAndNewlines)

            // Find the matching `}` by brace-depth.
            let closeIdx = indexOfMatchingClose(scalars, openIdx: openIdx)
            // `closeIdx == scalars.count` means the block was unterminated —
            // treat the remainder as the body.
            let bodyStart = openIdx + 1
            let bodyEnd = min(closeIdx, scalars.count)
            let body = String(
                String.UnicodeScalarView(scalars[bodyStart..<bodyEnd])
            )

            // At-rule? (`@media`, `@keyframes`, etc.)
            if prelude.hasPrefix("@") {
                let name = atRuleName(prelude)
                diagnostics.warn(.init(.unsupportedAtRule(name), prelude))
            } else if !prelude.isEmpty {
                if let selector = SelectorParser.parse(prelude, diagnostics: &diagnostics) {
                    let decls = DeclarationParser.parse(body, diagnostics: &diagnostics)
                    rules.append(CSSRule(
                        selector: selector,
                        declarations: decls,
                        specificity: Specificity.of(selector),
                        sourceOrder: sourceOrder
                    ))
                    sourceOrder += 1
                }
                // SelectorParser already emitted the diagnostic on nil; drop.
            }

            // Advance past the closing brace (or to EOF on unterminated).
            i = closeIdx < scalars.count ? closeIdx + 1 : scalars.count
        }

        return rules
    }

    // MARK: - Helpers

    /// Removes every `/* … */` comment. Unterminated comments consume to EOF.
    private static func stripComments(_ s: String) -> String {
        var out = ""
        let scalars = Array(s.unicodeScalars)
        var i = 0
        while i < scalars.count {
            if i + 1 < scalars.count, scalars[i] == "/", scalars[i + 1] == "*" {
                i += 2
                while i + 1 < scalars.count, !(scalars[i] == "*" && scalars[i + 1] == "/") {
                    i += 1
                }
                if i + 1 < scalars.count { i += 2 } else { return out }
            } else {
                out.unicodeScalars.append(scalars[i])
                i += 1
            }
        }
        return out
    }

    /// Linear scan for the first occurrence of `char` at or after `from`.
    private static func indexOf(
        _ scalars: [Unicode.Scalar],
        from: Int,
        char: Unicode.Scalar
    ) -> Int? {
        var j = from
        while j < scalars.count {
            if scalars[j] == char { return j }
            j += 1
        }
        return nil
    }

    /// Walks brace depth starting from an opening `{` and returns the index
    /// of its matching `}`. Returns `scalars.count` when the block never
    /// closes (unterminated) — callers treat that as "consume to EOF".
    private static func indexOfMatchingClose(
        _ scalars: [Unicode.Scalar],
        openIdx: Int
    ) -> Int {
        var depth = 0
        var j = openIdx
        while j < scalars.count {
            let c = scalars[j]
            if c == "{" { depth += 1 }
            else if c == "}" {
                depth -= 1
                if depth == 0 { return j }
            }
            j += 1
        }
        return scalars.count
    }

    /// Extracts the bare at-rule name from a prelude like `@media (…)`.
    /// Returns the empty string if nothing follows the `@`.
    private static func atRuleName(_ prelude: String) -> String {
        precondition(prelude.hasPrefix("@"))
        let afterAt = prelude.dropFirst()
        var name = ""
        for scalar in afterAt.unicodeScalars {
            if isIdentContinue(scalar) {
                name.unicodeScalars.append(scalar)
            } else {
                break
            }
        }
        return name
    }

    private static func isIdentContinue(_ c: Unicode.Scalar) -> Bool {
        (c >= "a" && c <= "z") || (c >= "A" && c <= "Z") ||
            (c >= "0" && c <= "9") || c == "_" || c == "-"
    }
}
