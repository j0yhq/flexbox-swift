// StyleResolver — applies cascade rules to a single node.
//
// Given a node's `id` (and optional `schemaType`, which maps to an element
// selector), collect every matching rule from the stylesheet, sort by
// (specificity ascending, sourceOrder ascending), then apply declarations
// in order. Later declarations overwrite earlier ones — this is the CSS
// cascade in its simplest form (no inline styles, no !important, no
// inheritance; all Phase 2+).
//
// Phase 1 matches `SimpleSelector`:
//   •  `.id("x")`      ↔ node.id == "x"
//   •  `.element("t")` ↔ node.schemaType == "t"
//   •  `.class(_)`     ↔ never matches (classes not yet modeled on nodes)
//
// The class case is included so the type-system compiles, and so Phase 2 can
// wire classes through without changing this file's signature.

import Foundation
import FlexLayout
import SwiftUI
import CoreGraphics

/// Resolves computed style for a single node.
public enum StyleResolver {

    /// Produce the fully computed style for a node.
    ///
    /// - Parameters:
    ///   - id: The node id (matches `#id` selectors).
    ///   - schemaType: The registered component type, if any (matches element
    ///     selectors like `button`).
    ///   - classes: The node's CSS class names (matches `.name` selectors).
    ///     Defaults to empty so pre-Phase-2 callers keep compiling.
    ///   - stylesheet: The parsed CSS to cascade over.
    ///   - diagnostics: Accumulator for invalid-value warnings.
    /// - Returns: The resolved ``ComputedStyle`` (defaults for unmatched nodes).
    public static func resolve(
        id: String,
        schemaType: String?,
        classes: [String] = [],
        stylesheet: Stylesheet,
        diagnostics: inout CSSDiagnostics
    ) -> ComputedStyle {
        // 1. Select matching rules. A compound selector matches iff **every**
        // part matches the node — a single dissenter rejects the whole rule.
        let matched = stylesheet.rules.filter { rule in
            rule.selector.parts.allSatisfy { part in
                switch part {
                case .id(let name):      return name == id
                case .element(let name): return name == schemaType
                case .class(let name):   return classes.contains(name)
                }
            }
        }

        // 2. Sort by (specificity asc, sourceOrder asc). "Later wins" on ties.
        let sorted = matched.sorted { a, b in
            if a.specificity != b.specificity { return a.specificity < b.specificity }
            return a.sourceOrder < b.sourceOrder
        }

        // 3. Apply each rule's declarations.
        var style = ComputedStyle()
        for rule in sorted {
            for decl in rule.declarations {
                apply(decl, to: &style, diagnostics: &diagnostics)
            }
        }
        return style
    }

    // MARK: - Declaration application

    // Dispatch table for one declaration. Invalid values are reported via
    // `.invalidValue(property:value:)` and the target field is left at its
    // prior value (which is the CSS initial value for a fresh ComputedStyle).
    private static func apply(
        _ decl: Declaration,
        to style: inout ComputedStyle,
        diagnostics: inout CSSDiagnostics
    ) {
        switch decl.property {

        // MARK: Container
        case "display":
            if let v = CSSValueParsers.parseDisplay(decl.value) {
                style.display = v
            } else {
                diagnostics.warn(.init(.invalidValue(property: decl.property, value: decl.value)))
            }

        case "flex-direction":
            if let v = CSSValueParsers.parseFlexDirection(decl.value) {
                style.container.direction = v
            } else {
                diagnostics.warn(.init(.invalidValue(property: decl.property, value: decl.value)))
            }

        case "flex-wrap":
            if let v = CSSValueParsers.parseFlexWrap(decl.value) {
                style.container.wrap = v
            } else {
                diagnostics.warn(.init(.invalidValue(property: decl.property, value: decl.value)))
            }

        case "justify-content":
            if let v = CSSValueParsers.parseJustifyContent(decl.value) {
                style.container.justifyContent = v
            } else {
                diagnostics.warn(.init(.invalidValue(property: decl.property, value: decl.value)))
            }

        case "align-items":
            if let v = CSSValueParsers.parseAlignItems(decl.value) {
                style.container.alignItems = v
            } else {
                diagnostics.warn(.init(.invalidValue(property: decl.property, value: decl.value)))
            }

        case "align-content":
            if let v = CSSValueParsers.parseAlignContent(decl.value) {
                style.container.alignContent = v
            } else {
                diagnostics.warn(.init(.invalidValue(property: decl.property, value: decl.value)))
            }

        case "gap":
            applyGap(decl.value, to: &style.container, diagnostics: &diagnostics)

        case "row-gap":
            if let n = CSSValueParsers.parsePx(decl.value) {
                style.container.rowGap = n
            } else {
                diagnostics.warn(.init(.invalidValue(property: decl.property, value: decl.value)))
            }

        case "column-gap":
            if let n = CSSValueParsers.parsePx(decl.value) {
                style.container.columnGap = n
            } else {
                diagnostics.warn(.init(.invalidValue(property: decl.property, value: decl.value)))
            }

        case "padding":
            applyPaddingShorthand(decl.value, to: &style.container, diagnostics: &diagnostics)

        case "padding-top":
            if let n = CSSValueParsers.parsePx(decl.value) { style.container.padding.top = n }
            else { diagnostics.warn(.init(.invalidValue(property: decl.property, value: decl.value))) }
        case "padding-bottom":
            if let n = CSSValueParsers.parsePx(decl.value) { style.container.padding.bottom = n }
            else { diagnostics.warn(.init(.invalidValue(property: decl.property, value: decl.value))) }
        case "padding-left":
            if let n = CSSValueParsers.parsePx(decl.value) { style.container.padding.leading = n }
            else { diagnostics.warn(.init(.invalidValue(property: decl.property, value: decl.value))) }
        case "padding-right":
            if let n = CSSValueParsers.parsePx(decl.value) { style.container.padding.trailing = n }
            else { diagnostics.warn(.init(.invalidValue(property: decl.property, value: decl.value))) }

        case "overflow":
            // `overflow` applies to both container and item contexts. The
            // flex engine reads from the item key when set, so we write to
            // both; the effective value is the same either way.
            if let v = CSSValueParsers.parseOverflow(decl.value) {
                style.container.overflow = v
                style.item.overflow = v
            } else {
                diagnostics.warn(.init(.invalidValue(property: decl.property, value: decl.value)))
            }

        // MARK: Item shorthand
        case "flex":
            applyFlexShorthand(decl.value, to: &style.item, diagnostics: &diagnostics)

        case "flex-grow":
            if let n = parseDouble(decl.value) { style.item.grow = CGFloat(n) }
            else { diagnostics.warn(.init(.invalidValue(property: decl.property, value: decl.value))) }

        case "flex-shrink":
            if let n = parseDouble(decl.value) { style.item.shrink = CGFloat(n) }
            else { diagnostics.warn(.init(.invalidValue(property: decl.property, value: decl.value))) }

        case "flex-basis":
            style.item.basis = CSSValueParsers.parseFlexBasis(decl.value)

        case "align-self":
            if let v = CSSValueParsers.parseAlignSelf(decl.value) {
                style.item.alignSelf = v
            } else {
                diagnostics.warn(.init(.invalidValue(property: decl.property, value: decl.value)))
            }

        case "order":
            if let n = Int(decl.value.trimmingCharacters(in: .whitespaces)) {
                style.item.order = n
            } else {
                diagnostics.warn(.init(.invalidValue(property: decl.property, value: decl.value)))
            }

        case "width":  style.item.width  = CSSValueParsers.parseFlexSize(decl.value)
        case "height": style.item.height = CSSValueParsers.parseFlexSize(decl.value)

        case "z-index":
            if let n = Int(decl.value.trimmingCharacters(in: .whitespaces)) {
                style.item.zIndex = n
            } else {
                diagnostics.warn(.init(.invalidValue(property: decl.property, value: decl.value)))
            }

        case "position":
            if let v = CSSValueParsers.parsePosition(decl.value) {
                style.item.position = v
            } else {
                diagnostics.warn(.init(.invalidValue(property: decl.property, value: decl.value)))
            }

        case "top":
            if let n = CSSValueParsers.parsePx(decl.value) { style.item.top = n }
            else { diagnostics.warn(.init(.invalidValue(property: decl.property, value: decl.value))) }
        case "bottom":
            if let n = CSSValueParsers.parsePx(decl.value) { style.item.bottom = n }
            else { diagnostics.warn(.init(.invalidValue(property: decl.property, value: decl.value))) }
        case "left":
            if let n = CSSValueParsers.parsePx(decl.value) { style.item.leading = n }
            else { diagnostics.warn(.init(.invalidValue(property: decl.property, value: decl.value))) }
        case "right":
            if let n = CSSValueParsers.parsePx(decl.value) { style.item.trailing = n }
            else { diagnostics.warn(.init(.invalidValue(property: decl.property, value: decl.value))) }

        default:
            // `DeclarationParser` already drops unsupported properties, so we
            // should never reach this branch. Fall through silently to keep
            // the resolver tolerant of future allow-list expansions.
            break
        }
    }

    // MARK: - Value helpers

    private static func parseDouble(_ s: String) -> Double? {
        Double(s.trimmingCharacters(in: .whitespaces))
    }

    private static func applyGap(
        _ value: String,
        to c: inout FlexContainerConfig,
        diagnostics: inout CSSDiagnostics
    ) {
        let parts = value
            .components(separatedBy: .whitespaces)
            .filter { !$0.isEmpty }
        switch parts.count {
        case 2:
            if let r = CSSValueParsers.parsePx(parts[0]),
               let col = CSSValueParsers.parsePx(parts[1]) {
                c.rowGap = r
                c.columnGap = col
            } else {
                diagnostics.warn(.init(.invalidValue(property: "gap", value: value)))
            }
        case 1:
            if let n = CSSValueParsers.parsePx(value) {
                c.gap = n
            } else {
                diagnostics.warn(.init(.invalidValue(property: "gap", value: value)))
            }
        default:
            diagnostics.warn(.init(.invalidValue(property: "gap", value: value)))
        }
    }

    private static func applyPaddingShorthand(
        _ value: String,
        to c: inout FlexContainerConfig,
        diagnostics: inout CSSDiagnostics
    ) {
        let parts = value
            .components(separatedBy: .whitespaces)
            .filter { !$0.isEmpty }
            .compactMap { CSSValueParsers.parsePx($0) }
        // The `.compactMap` drops unparseable tokens; if the count doesn't
        // match the CSS 1/2/3/4 shorthand forms, we leave padding untouched
        // and emit a diagnostic.
        switch parts.count {
        case 1:
            c.padding = EdgeInsets(top: parts[0], leading: parts[0], bottom: parts[0], trailing: parts[0])
        case 2:
            c.padding = EdgeInsets(top: parts[0], leading: parts[1], bottom: parts[0], trailing: parts[1])
        case 3:
            c.padding = EdgeInsets(top: parts[0], leading: parts[1], bottom: parts[2], trailing: parts[1])
        case 4:
            c.padding = EdgeInsets(top: parts[0], leading: parts[3], bottom: parts[2], trailing: parts[1])
        default:
            diagnostics.warn(.init(.invalidValue(property: "padding", value: value)))
        }
    }

    private static func applyFlexShorthand(
        _ value: String,
        to item: inout ItemStyle,
        diagnostics: inout CSSDiagnostics
    ) {
        let trimmed = value.trimmingCharacters(in: .whitespaces).lowercased()
        switch trimmed {
        case "auto":    item.grow = 1; item.shrink = 1; item.basis = .auto; return
        case "none":    item.grow = 0; item.shrink = 0; item.basis = .auto; return
        case "initial": item.grow = 0; item.shrink = 1; item.basis = .auto; return
        default: break
        }

        let parts = trimmed.components(separatedBy: .whitespaces).filter { !$0.isEmpty }
        switch parts.count {
        case 1:
            if let n = Double(parts[0]) {
                item.grow = CGFloat(n)
                item.shrink = 1
                item.basis = .points(0)
            } else {
                item.basis = CSSValueParsers.parseFlexBasis(parts[0])
            }
        case 2:
            if let g = Double(parts[0]), let s = Double(parts[1]) {
                item.grow = CGFloat(g)
                item.shrink = CGFloat(s)
            } else {
                diagnostics.warn(.init(.invalidValue(property: "flex", value: value)))
            }
        case 3...:
            if let g = Double(parts[0]), let s = Double(parts[1]) {
                item.grow = CGFloat(g)
                item.shrink = CGFloat(s)
                item.basis = CSSValueParsers.parseFlexBasis(parts[2])
            } else {
                diagnostics.warn(.init(.invalidValue(property: "flex", value: value)))
            }
        default:
            diagnostics.warn(.init(.invalidValue(property: "flex", value: value)))
        }
    }
}
