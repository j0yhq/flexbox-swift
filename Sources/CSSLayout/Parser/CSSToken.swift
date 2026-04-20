// CSSToken — the token alphabet produced by `CSSTokenizer`.
//
// Phase 1 covers the flexbox-only CSS subset (§4.1 of the design doc). The
// token set intentionally doesn't distinguish selectors from declarations;
// the parser layer interprets context.

import Foundation

/// A single lexical token produced by ``CSSTokenizer``.
///
/// Whitespace is emitted as a standalone `.whitespace` token (collapsed to
/// one per run) because it is significant for future combinator parsing
/// (Phase 2 descendant selector).
public enum CSSToken: Equatable {
    /// An identifier like `color`, `flex-direction`, `red`.
    case ident(String)
    /// A `#`-prefixed identifier like `#submit` (ID selector, or hash-value).
    case hash(String)
    /// A bare `.` — used for class selector prefix. (Leading-dot numbers like
    /// `.5px` are tokenized as `.number` instead.)
    case dot
    /// A numeric literal, optionally followed by a unit ident (`16px`, `1em`,
    /// `-1`, `0.5`).
    case number(Double, unit: String?)
    /// A numeric literal followed by `%` (`50%`).
    case percentage(Double)
    /// A quoted string literal (`"…"` or `'…'`), contents without the quotes.
    case string(String)
    case colon
    case semicolon
    case comma
    case lbrace
    case rbrace
    /// `>` — child combinator (Phase 2 parses; Phase 1 rejects with diagnostic).
    case gt
    /// One run of whitespace (any mix of spaces, tabs, newlines).
    case whitespace
    /// An `@`-prefixed identifier like `@media`.
    case atKeyword(String)
    /// End of input sentinel. Always the last token.
    case eof
}
