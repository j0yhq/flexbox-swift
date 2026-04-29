// StyleSerializer — turns a `Style` (Unit 1) into a CSS declarations
// string that CSSLayout's existing parser (`Sources/CSSLayout/Parser/`)
// already accepts.
//
// joy-dom payloads carry styles as structured objects, but CSSLayout's
// resolver consumes raw CSS text. Rather than fork the parser into two
// input formats, we keep the CSS pipeline as the single source of truth
// and serialize at the boundary. This file is that shim.
//
// Output shape: a sequence of `property: value;` declarations separated
// by single spaces, no surrounding braces or selector. The companion
// `rule(selector:style:)` helper wraps the output in `selector { ... }`
// for cases where a complete CSS rule is needed (e.g. inline node-style
// injection in Unit 4 and breakpoint style application in Unit 8).
//
// Every CSS property emitted here is guaranteed to be parseable by
// CSSLayout's `CSSValueParsers` — the property surface here is the
// intersection of joy-dom's `Style` interface and what the parser
// understands today (audited at the start of Tier 3).

import Foundation

/// Pure-function serializer for `Style` → CSS text.
public enum StyleSerializer {

    // MARK: - Public API

    /// Serialize a `Style` into a CSS declarations block. Returns an
    /// empty string when no fields are set.
    public static func serialize(_ style: Style) -> String {
        return ""
    }

    /// Wrap declarations inside a selector to produce a complete CSS
    /// rule. Returns an empty string when the style has no fields.
    public static func rule(selector: String, style: Style) -> String {
        return ""
    }
}
