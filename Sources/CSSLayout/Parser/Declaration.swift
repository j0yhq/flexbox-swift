// Declaration — a single `property: value` pair inside a CSS rule block.
//
// The parser stores values as raw strings; typed parsing happens later in
// `StyleResolver` via `CSSValueParsers`. Keeping the declaration untyped here
// lets the same Declaration flow through diagnostics without losing source
// text, which matters for `invalidValue(property:value:)` warnings.

import Foundation

/// A parsed `property: value` declaration.
///
/// `property` is normalised to lowercase so selectors and cascades can match
/// without re-casing. `value` is trimmed of surrounding whitespace but
/// internal whitespace (shorthand components like `1 1 120px`) is preserved.
public struct Declaration: Equatable {
    /// Lowercase property name, e.g. `"flex-direction"`.
    public let property: String
    /// Raw value string with surrounding whitespace trimmed and any
    /// `!important` suffix removed.
    public let value: String

    public init(property: String, value: String) {
        self.property = property
        self.value = value
    }
}
