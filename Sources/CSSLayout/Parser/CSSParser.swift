// CSSParser — the public stylesheet entry point.
//
// Thin wrapper over `RuleParser.parseRules` that packages the result into a
// `Stylesheet`. Kept separate so callers (`CSSLayout` view, tests) don't
// depend on RuleParser directly, and so Phase 2 can add a post-processing
// step (e.g. rule grouping, `@media` promotion) without changing the public
// surface.

import Foundation

/// A parsed CSS stylesheet — the complete cascade input.
public struct Stylesheet: Equatable {
    /// All parsed rules in source order. Already filtered: malformed rules
    /// are dropped before reaching here.
    public let rules: [CSSRule]

    public init(rules: [CSSRule] = []) {
        self.rules = rules
    }
}

/// Public entry point for parsing a CSS payload.
///
/// `CSSLayout` is a *tolerant* parser: `parse` never throws, never aborts,
/// and always returns a `Stylesheet`. Hostile or malformed input yields an
/// empty stylesheet plus one or more warnings in `diagnostics`.
public enum CSSParser {

    /// Parse `css` into a stylesheet.
    ///
    /// - Parameters:
    ///   - css: Raw CSS text. `@media`, attribute selectors, pseudos, and
    ///     visual properties produce diagnostics and are dropped (Phase 1
    ///     supports the flexbox subset only — see §4.1 of the design doc).
    ///   - diagnostics: Accumulator — warnings are appended, never replaced.
    /// - Returns: A stylesheet containing every successfully parsed rule.
    public static func parse(
        _ css: String,
        diagnostics: inout CSSDiagnostics
    ) -> Stylesheet {
        let rules = RuleParser.parseRules(from: css, diagnostics: &diagnostics)
        return Stylesheet(rules: rules)
    }
}
