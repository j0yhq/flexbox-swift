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
    ///
    /// Field emission order matches the property order on `Style` itself,
    /// so the output is deterministic and stable for golden-string tests.
    public static func serialize(_ style: Style) -> String {
        var parts: [String] = []

        if let v = style.position       { parts.append("position: \(v.rawValue);") }
        if let v = style.display        { parts.append("display: \(v.rawValue);") }
        if let v = style.zIndex         { parts.append("z-index: \(v);") }
        if let v = style.overflow       { parts.append("overflow: \(v.rawValue);") }

        if let v = style.top            { parts.append("top: \(formatLength(v));") }
        if let v = style.left           { parts.append("left: \(formatLength(v));") }
        if let v = style.bottom         { parts.append("bottom: \(formatLength(v));") }
        if let v = style.right          { parts.append("right: \(formatLength(v));") }

        if let v = style.flexDirection  { parts.append("flex-direction: \(v.rawValue);") }
        if let v = style.flexGrow       { parts.append("flex-grow: \(formatNumber(v));") }
        if let v = style.flexShrink     { parts.append("flex-shrink: \(formatNumber(v));") }
        if let v = style.flexBasis      { parts.append("flex-basis: \(formatLength(v));") }
        if let v = style.justifyContent { parts.append("justify-content: \(v.rawValue);") }
        if let v = style.alignItems     { parts.append("align-items: \(v.rawValue);") }
        if let v = style.flexWrap       { parts.append("flex-wrap: \(v.rawValue);") }
        if let v = style.gap            { parts.append("gap: \(formatGap(v));") }
        if let v = style.order          { parts.append("order: \(v);") }

        if let v = style.width          { parts.append("width: \(formatLength(v));") }
        if let v = style.height         { parts.append("height: \(formatLength(v));") }
        if let v = style.padding        { parts.append("padding: \(formatPadding(v));") }

        return parts.joined(separator: " ")
    }

    /// Wrap declarations inside a selector to produce a complete CSS
    /// rule. Returns an empty string when the style has no fields, so
    /// callers can safely chain output without checking emptiness first.
    public static func rule(selector: String, style: Style) -> String {
        let body = serialize(style)
        guard !body.isEmpty else { return "" }
        return "\(selector) { \(body) }"
    }

    // MARK: - Value formatting

    /// `Length` → `123px` / `50%`. Trailing `.0` is dropped so integer
    /// lengths produce idiomatic output (`100px`, not `100.0px`).
    private static func formatLength(_ length: Length) -> String {
        return "\(formatNumber(length.value))\(length.unit)"
    }

    /// `Gap.uniform` → `8px`; `Gap.axes` → `<row> <column>` per CSS
    /// shorthand grammar (`gap: <row-gap> <column-gap>`).
    private static func formatGap(_ gap: Gap) -> String {
        switch gap {
        case .uniform(let l):
            return formatLength(l)
        case .axes(let column, let row):
            return "\(formatLength(row)) \(formatLength(column))"
        }
    }

    /// `Padding.uniform` → `12px`; `Padding.sides` → `top right bottom left`
    /// per CSS shorthand grammar.
    private static func formatPadding(_ padding: Padding) -> String {
        switch padding {
        case .uniform(let l):
            return formatLength(l)
        case .sides(let top, let right, let bottom, let left):
            return [top, right, bottom, left].map(formatLength).joined(separator: " ")
        }
    }

    /// Drop the trailing `.0` for integer-valued doubles so the CSS
    /// reads naturally. Fractional values keep their decimals.
    private static func formatNumber(_ value: Double) -> String {
        if value.truncatingRemainder(dividingBy: 1) == 0 {
            return String(Int(value))
        }
        return String(value)
    }
}
