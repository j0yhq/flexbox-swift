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

    /// A minimal ancestor-ref used by the combinator matcher. Constructed by
    /// `StyleTreeBuilder` from each schema entry; exposed publicly so tests
    /// can exercise the resolver in isolation.
    public struct NodeRef: Equatable {
        public let id: String
        public let schemaType: String?
        public let classes: [String]

        public init(id: String, schemaType: String?, classes: [String]) {
            self.id = id
            self.schemaType = schemaType
            self.classes = classes
        }
    }

    /// Produce the fully computed style for a node.
    ///
    /// - Parameters:
    ///   - id: The node id (matches `#id` selectors).
    ///   - schemaType: The registered component type, if any (matches element
    ///     selectors like `button`).
    ///   - classes: The node's CSS class names (matches `.name` selectors).
    ///     Defaults to empty so pre-Phase-2 callers keep compiling.
    ///   - ancestors: The node's ancestor chain, innermost parent first and
    ///     the outermost ancestor last. Used to resolve descendant / child
    ///     combinators. Defaults to empty (flat schema).
    ///   - stylesheet: The parsed CSS to cascade over.
    ///   - diagnostics: Accumulator for invalid-value warnings.
    /// - Returns: The resolved ``ComputedStyle`` (defaults for unmatched nodes).
    public static func resolve(
        id: String,
        schemaType: String?,
        classes: [String] = [],
        ancestors: [NodeRef] = [],
        stylesheet: Stylesheet,
        diagnostics: inout JoyDiagnostics
    ) -> ComputedStyle {
        let subject = NodeRef(id: id, schemaType: schemaType, classes: classes)

        // 1. Select matching rules. A complex selector matches iff its subject
        // compound matches the node AND every preceding compound can be
        // satisfied by the ancestor chain respecting its combinator.
        let matched = stylesheet.rules.filter { rule in
            matches(rule.selector, subject: subject, ancestors: ancestors)
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

    // MARK: - Selector matching

    /// Full complex-selector match: subject compound against the node plus
    /// every preceding compound against the ancestor chain per its combinator.
    ///
    /// Scans compounds right-to-left (subject first) with backtracking for
    /// descendant combinators. Greedy matching is NOT sufficient — consider
    /// `#form > .row input` against an ancestor chain `[inner.row, cell,
    /// outer.row, form]`: picking the innermost `.row` greedily fails the
    /// `#form >` child check, even though choosing `outer.row` succeeds.
    ///
    /// For each preceding compound:
    ///   • `.child` — the very next ancestor must match; one shot, no choice.
    ///   • `.descendant` — try each candidate ancestor in turn; recurse on
    ///     the remainder. First success wins.
    private static func matches(
        _ complex: ComplexSelector,
        subject: NodeRef,
        ancestors: [NodeRef]
    ) -> Bool {
        guard matchesCompound(complex.subject, node: subject) else { return false }
        if complex.parts.count == 1 { return true }
        // Start matching from the compound adjacent to the subject, walking
        // outwards into `ancestors` (cursor = 0 = innermost).
        return matchPreceding(
            complex: complex,
            partIndex: complex.parts.count - 2,
            ancestors: ancestors,
            cursor: 0
        )
    }

    /// Recursive backtracking helper for preceding compounds. `partIndex`
    /// points at the compound to satisfy; `cursor` is the next ancestor to
    /// consider. Returns `true` when every preceding compound has found a
    /// consistent ancestor assignment.
    private static func matchPreceding(
        complex: ComplexSelector,
        partIndex: Int,
        ancestors: [NodeRef],
        cursor: Int
    ) -> Bool {
        // All preceding compounds satisfied.
        if partIndex < 0 { return true }

        let compound = complex.parts[partIndex]
        // `combinators[i]` links parts[i] to parts[i + 1]. Since we've already
        // matched parts[partIndex + 1], the relevant combinator is at
        // `partIndex`.
        switch complex.combinators[partIndex] {
        case .child:
            // One shot: ancestors[cursor] must match this compound, then
            // advance both partIndex and cursor by one.
            guard cursor < ancestors.count,
                  matchesCompound(compound, node: ancestors[cursor])
            else { return false }
            return matchPreceding(
                complex: complex,
                partIndex: partIndex - 1,
                ancestors: ancestors,
                cursor: cursor + 1
            )

        case .descendant:
            // Try each candidate ancestor at or after `cursor`. If matching
            // the remainder from that position succeeds, we're done. This
            // is the backtracking step: a later candidate may work when an
            // earlier one doesn't.
            var i = cursor
            while i < ancestors.count {
                if matchesCompound(compound, node: ancestors[i]),
                   matchPreceding(
                       complex: complex,
                       partIndex: partIndex - 1,
                       ancestors: ancestors,
                       cursor: i + 1
                   ) {
                    return true
                }
                i += 1
            }
            return false
        }
    }

    /// Every simple part of `compound` must match `node`.
    private static func matchesCompound(
        _ compound: CompoundSelector,
        node: NodeRef
    ) -> Bool {
        compound.parts.allSatisfy { part in
            switch part {
            case .id(let name):      return name == node.id
            case .element(let name): return name == node.schemaType
            case .class(let name):   return node.classes.contains(name)
            }
        }
    }

    // MARK: - Declaration application

    // Dispatch table for one declaration. Invalid values are reported via
    // `.invalidValue(property:value:)` and the target field is left at its
    // prior value (which is the CSS initial value for a fresh ComputedStyle).
    private static func apply(
        _ decl: Declaration,
        to style: inout ComputedStyle,
        diagnostics: inout JoyDiagnostics
    ) {
        switch decl.property {

        // MARK: Container
        case "display":
            // `display: none` is parsed here (not in `parseDisplay`) because
            // FlexDisplay has no `.none` case — we flag it on ComputedStyle
            // and let the resolver filter the node's whole subtree out.
            let raw = decl.value.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
            if raw == "none" {
                style.isDisplayNone = true
            } else if let v = CSSValueParsers.parseDisplay(decl.value) {
                style.display = v
                style.isDisplayNone = false
            } else {
                diagnostics.warn(.init(.invalidValue(property: decl.property, value: decl.value)))
            }

        case "visibility":
            // Only `visible` / `hidden` are modelled. `collapse` has no
            // meaningful flex mapping (it targets table-rows in CSS 2.1)
            // and anything else is garbage — both get `.invalidValue` so
            // the prior cascaded value is preserved.
            switch decl.value.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() {
            case "visible": style.isVisibilityHidden = false
            case "hidden":  style.isVisibilityHidden = true
            default:
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
            if let v = CSSValueParsers.parseFlexBasis(decl.value) {
                style.item.basis = v
            } else {
                diagnostics.warn(.init(.invalidValue(property: decl.property, value: decl.value)))
            }

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

        case "width":
            if let v = CSSValueParsers.parseFlexSize(decl.value) {
                style.item.width = v
            } else {
                diagnostics.warn(.init(.invalidValue(property: decl.property, value: decl.value)))
            }
        case "height":
            if let v = CSSValueParsers.parseFlexSize(decl.value) {
                style.item.height = v
            } else {
                diagnostics.warn(.init(.invalidValue(property: decl.property, value: decl.value)))
            }

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
        diagnostics: inout JoyDiagnostics
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
        diagnostics: inout JoyDiagnostics
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
        diagnostics: inout JoyDiagnostics
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
            } else if let b = CSSValueParsers.parseFlexBasis(parts[0]) {
                item.basis = b
            } else {
                diagnostics.warn(.init(.invalidValue(property: "flex", value: value)))
            }
        case 2:
            if let g = Double(parts[0]), let s = Double(parts[1]) {
                item.grow = CGFloat(g)
                item.shrink = CGFloat(s)
            } else {
                diagnostics.warn(.init(.invalidValue(property: "flex", value: value)))
            }
        case 3...:
            if let g = Double(parts[0]), let s = Double(parts[1]),
               let b = CSSValueParsers.parseFlexBasis(parts[2]) {
                item.grow = CGFloat(g)
                item.shrink = CGFloat(s)
                item.basis = b
            } else {
                diagnostics.warn(.init(.invalidValue(property: "flex", value: value)))
            }
        default:
            diagnostics.warn(.init(.invalidValue(property: "flex", value: value)))
        }
    }
}
