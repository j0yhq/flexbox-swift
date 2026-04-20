// CSSValueParsers — pure property-value parsers for the flexbox CSS subset.
//
// Each parser takes a raw string (as the tokenizer/declaration parser would
// hand it back) and returns either a typed FlexLayout value or `nil` on
// garbage. The higher-level StyleResolver decides whether nil means "drop
// this declaration" or "emit a diagnostic and keep the default".
//
// These functions are intentionally symmetric with the ones in
// `FlexDemoApp/CSSParser.swift` — this is the promoted, tested, public copy.
// The demo app will switch to this module in a later refactor pass.

import Foundation
import FlexLayout
import CoreGraphics

/// Namespace for CSS property-value parsers.
///
/// All methods are `static`. Each returns `Optional<T>` (or, for shorthands
/// that always succeed with a default, the concrete type). Callers that need
/// to distinguish "missing" from "invalid" should inspect the optional.
public enum CSSValueParsers {

    // MARK: - Lengths

    /// Parses a CSS length value into points.
    ///
    /// Supported units: `px`, `pt`, `em`, `rem`, and unitless (treated as
    /// points). `em` and `rem` use a fixed 16-pt root; a proper root-font-size
    /// model is a Phase 3 concern. Returns `nil` for anything else.
    public static func parsePx(_ v: String) -> CGFloat? {
        let s = v.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard !s.isEmpty else { return nil }
        if s.hasSuffix("rem"), let n = Double(s.dropLast(3)) { return CGFloat(n * 16) }
        if s.hasSuffix("px"),  let n = Double(s.dropLast(2)) { return CGFloat(n) }
        if s.hasSuffix("pt"),  let n = Double(s.dropLast(2)) { return CGFloat(n) }
        if s.hasSuffix("em"),  let n = Double(s.dropLast(2)) { return CGFloat(n * 16) }
        if let n = Double(s) { return CGFloat(n) }
        return nil
    }

    // MARK: - Flex shorthand components

    /// Parses a CSS `flex-basis` value.
    ///
    /// Returns `nil` for unrecognised values so the caller can follow the CSS
    /// spec's rule that invalid declarations are ignored (preserving any
    /// prior value) rather than silently resetting to `.auto`.
    public static func parseFlexBasis(_ v: String) -> FlexBasis? {
        let s = v.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        if s == "auto" { return .auto }
        if s.hasSuffix("%"), let n = Double(s.dropLast()) {
            return .fraction(CGFloat(n) / 100)
        }
        if let n = parsePx(s) { return .points(n) }
        return nil
    }

    /// Parses a CSS `width` / `height` value into ``FlexSize``.
    ///
    /// Supports `auto`, `min-content`, percentages (`50%` → `.fraction(0.5)`),
    /// and all ``parsePx`` length units. Returns `nil` for unknown values so
    /// the cascade honours "invalid declarations are dropped".
    public static func parseFlexSize(_ v: String) -> FlexSize? {
        let s = v.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        if s == "auto"        { return .auto }
        if s == "min-content" { return .minContent }
        if s.hasSuffix("%"), let n = Double(s.dropLast()) {
            return .fraction(CGFloat(n) / 100)
        }
        if let n = parsePx(s) { return .points(n) }
        return nil
    }

    // MARK: - Enumerations

    /// Parses CSS `overflow`. Returns `nil` on unknown values so the caller
    /// can emit a diagnostic.
    public static func parseOverflow(_ v: String) -> FlexOverflow? {
        switch v.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() {
        case "visible": return .visible
        case "hidden":  return .hidden
        case "clip":    return .clip
        case "scroll":  return .scroll
        case "auto":    return .auto
        default:        return nil
        }
    }

    /// Parses CSS `position`. Only `relative` and `absolute` participate in
    /// a flex formatting context; `fixed`/`sticky` are rejected here and
    /// surfaced as unsupported by the caller.
    public static func parsePosition(_ v: String) -> FlexPosition? {
        switch v.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() {
        case "relative": return .relative
        case "absolute": return .absolute
        default:         return nil
        }
    }

    /// Parses CSS `flex-direction`.
    public static func parseFlexDirection(_ v: String) -> FlexDirection? {
        switch v.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() {
        case "row":            return .row
        case "row-reverse":    return .rowReverse
        case "column":         return .column
        case "column-reverse": return .columnReverse
        default:               return nil
        }
    }

    /// Parses CSS `flex-wrap`.
    public static func parseFlexWrap(_ v: String) -> FlexWrap? {
        switch v.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() {
        case "nowrap":       return .nowrap
        case "wrap":         return .wrap
        case "wrap-reverse": return .wrapReverse
        default:             return nil
        }
    }

    /// Parses CSS `justify-content`. Accepts the `start`/`end`/`left`/`right`
    /// aliases alongside the canonical `flex-start`/`flex-end`.
    public static func parseJustifyContent(_ v: String) -> JustifyContent? {
        switch v.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() {
        case "flex-start", "start", "left":  return .flexStart
        case "flex-end",   "end",   "right": return .flexEnd
        case "center":                        return .center
        case "space-between":                 return .spaceBetween
        case "space-around":                  return .spaceAround
        case "space-evenly":                  return .spaceEvenly
        default:                              return nil
        }
    }

    /// Parses CSS `align-items`.
    public static func parseAlignItems(_ v: String) -> AlignItems? {
        switch v.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() {
        case "flex-start", "start": return .flexStart
        case "flex-end",   "end":   return .flexEnd
        case "center":              return .center
        case "stretch":             return .stretch
        case "baseline":            return .baseline
        default:                    return nil
        }
    }

    /// Parses CSS `align-content`.
    public static func parseAlignContent(_ v: String) -> AlignContent? {
        switch v.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() {
        case "flex-start", "start": return .flexStart
        case "flex-end",   "end":   return .flexEnd
        case "center":              return .center
        case "space-between":       return .spaceBetween
        case "space-around":        return .spaceAround
        case "space-evenly":        return .spaceEvenly
        case "stretch":             return .stretch
        default:                    return nil
        }
    }

    /// Parses CSS `align-self`.
    public static func parseAlignSelf(_ v: String) -> AlignSelf? {
        switch v.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() {
        case "auto":                return .auto
        case "flex-start", "start": return .flexStart
        case "flex-end",   "end":   return .flexEnd
        case "center":              return .center
        case "stretch":             return .stretch
        case "baseline":            return .baseline
        default:                    return nil
        }
    }

    /// Parses CSS `display`. In a flex formatting context `inline-flex` is
    /// equivalent to `flex`. `none`, `grid`, and other values are unsupported
    /// in Phase 1.
    public static func parseDisplay(_ v: String) -> FlexDisplay? {
        switch v.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() {
        case "flex", "inline-flex": return .flex
        case "block":               return .block
        case "inline":              return .inline
        default:                    return nil
        }
    }
}
