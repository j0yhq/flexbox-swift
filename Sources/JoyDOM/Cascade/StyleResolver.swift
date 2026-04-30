// StyleResolver — applies cascade rules to a single node.
//
// Given a node's `id` (and optional `schemaType`, which maps to an element
// selector), collect every matching rule from the rule list, sort by
// (specificity ascending, sourceOrder ascending), then apply each rule's
// `Style` field-by-field. Later applications overwrite earlier ones —
// this is the CSS cascade in its simplest form (no `!important`, no
// inheritance).
//
// Tier 5 rewrote this to consume `Style` (the joy-dom typed object)
// directly. The old CSS-string pipeline (Stylesheet → Declaration → switch
// on property name → CSSValueParsers) was deleted; the resolver now reads
// fields straight off `Style` and writes them into `ComputedStyle`. No
// string parsing happens in cascade-application anymore.
//
// What survives from the pre-Tier-5 resolver:
//   • Selector matching (`matches`, `matchPreceding`, `matchesCompound`)
//     — all the combinator + sibling logic kept verbatim.
//   • `NodeRef` — the (id, schemaType, classes) triple used by the
//     selector matcher for ancestors and preceding siblings.

import Foundation
import FlexLayout
import SwiftUI
import CoreGraphics

/// Resolves computed style for a single node.
public enum StyleResolver {

    // MARK: - Public types

    /// A minimal ancestor-ref used by the combinator matcher. Constructed by
    /// `StyleTreeBuilder` from each tree node; exposed publicly so tests can
    /// exercise the resolver in isolation.
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

    /// One pre-computed cascade rule: a parsed selector pointing at a
    /// `Style` value, with the specificity + source-order pair used to
    /// break ties. `StyleTreeBuilder` produces these from the
    /// document-level `Spec.style`, the active `Breakpoint.style`, plus
    /// any per-node inline `Node.props.style` rules.
    public struct Rule: Equatable {
        public let selector: ComplexSelector
        public let style: Style
        public let specificity: Specificity
        public let sourceOrder: Int

        public init(
            selector: ComplexSelector,
            style: Style,
            specificity: Specificity,
            sourceOrder: Int
        ) {
            self.selector = selector
            self.style = style
            self.specificity = specificity
            self.sourceOrder = sourceOrder
        }
    }

    // MARK: - Resolve

    /// Produce the fully computed style for a node.
    ///
    /// - Parameters:
    ///   - id: The node id (matches `#id` selectors).
    ///   - schemaType: The registered component type, if any (matches
    ///     element selectors like `button`).
    ///   - classes: The node's CSS class names (matches `.name` selectors).
    ///   - ancestors: Ancestor chain, innermost first. Used for descendant
    ///     and child combinators.
    ///   - precedingSiblings: Preceding-sibling chain in source order
    ///     (oldest first). Used for adjacent (`+`) and general (`~`)
    ///     sibling combinators.
    ///   - rules: Pre-built rule list (selector + Style + specificity +
    ///     sourceOrder) the cascade walks over.
    ///   - diagnostics: Accumulator for invalid-value warnings (kept for
    ///     parity with the old API; almost nothing in the new path emits
    ///     one because Style is already typed).
    /// - Returns: The resolved ``ComputedStyle`` (defaults for unmatched
    ///   nodes).
    public static func resolve(
        id: String,
        schemaType: String?,
        classes: [String] = [],
        ancestors: [NodeRef] = [],
        precedingSiblings: [NodeRef] = [],
        rules: [Rule],
        diagnostics: inout JoyDiagnostics
    ) -> ComputedStyle {
        let subject = NodeRef(id: id, schemaType: schemaType, classes: classes)

        // 1. Filter to matching rules.
        let matched = rules.filter { rule in
            matches(
                rule.selector,
                subject: subject,
                ancestors: ancestors,
                precedingSiblings: precedingSiblings
            )
        }

        // 2. Sort by (specificity asc, sourceOrder asc). Later wins on ties.
        let sorted = matched.sorted { a, b in
            if a.specificity != b.specificity { return a.specificity < b.specificity }
            return a.sourceOrder < b.sourceOrder
        }

        // 3. Apply each matching rule's Style field-by-field.
        var computed = ComputedStyle()
        for rule in sorted {
            apply(rule.style, to: &computed, diagnostics: &diagnostics)
        }
        return computed
    }

    // MARK: - Selector matching (unchanged from pre-Tier-5)

    /// Full complex-selector match: subject compound against the node plus
    /// every preceding compound against the ancestor chain per its combinator.
    private static func matches(
        _ complex: ComplexSelector,
        subject: NodeRef,
        ancestors: [NodeRef],
        precedingSiblings: [NodeRef]
    ) -> Bool {
        guard matchesCompound(complex.subject, node: subject) else { return false }
        if complex.parts.count == 1 { return true }
        return matchPreceding(
            complex: complex,
            partIndex: complex.parts.count - 2,
            ancestors: ancestors,
            ancestorCursor: 0,
            precedingSiblings: precedingSiblings,
            siblingUpperBound: precedingSiblings.count
        )
    }

    /// Recursive backtracking helper for preceding compounds.
    private static func matchPreceding(
        complex: ComplexSelector,
        partIndex: Int,
        ancestors: [NodeRef],
        ancestorCursor: Int,
        precedingSiblings: [NodeRef],
        siblingUpperBound: Int
    ) -> Bool {
        if partIndex < 0 { return true }

        let compound = complex.parts[partIndex]
        switch complex.combinators[partIndex] {

        case .child:
            guard ancestorCursor < ancestors.count,
                  matchesCompound(compound, node: ancestors[ancestorCursor])
            else { return false }
            return matchPreceding(
                complex: complex,
                partIndex: partIndex - 1,
                ancestors: ancestors,
                ancestorCursor: ancestorCursor + 1,
                precedingSiblings: precedingSiblings,
                siblingUpperBound: siblingUpperBound
            )

        case .descendant:
            var i = ancestorCursor
            while i < ancestors.count {
                if matchesCompound(compound, node: ancestors[i]),
                   matchPreceding(
                       complex: complex,
                       partIndex: partIndex - 1,
                       ancestors: ancestors,
                       ancestorCursor: i + 1,
                       precedingSiblings: precedingSiblings,
                       siblingUpperBound: siblingUpperBound
                   ) {
                    return true
                }
                i += 1
            }
            return false

        case .adjacentSibling:
            let idx = siblingUpperBound - 1
            guard idx >= 0,
                  matchesCompound(compound, node: precedingSiblings[idx])
            else { return false }
            return matchPreceding(
                complex: complex,
                partIndex: partIndex - 1,
                ancestors: ancestors,
                ancestorCursor: ancestorCursor,
                precedingSiblings: precedingSiblings,
                siblingUpperBound: idx
            )

        case .generalSibling:
            var i = siblingUpperBound - 1
            while i >= 0 {
                if matchesCompound(compound, node: precedingSiblings[i]),
                   matchPreceding(
                       complex: complex,
                       partIndex: partIndex - 1,
                       ancestors: ancestors,
                       ancestorCursor: ancestorCursor,
                       precedingSiblings: precedingSiblings,
                       siblingUpperBound: i
                   ) {
                    return true
                }
                i -= 1
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

    // MARK: - Style application

    /// Apply a joy-dom `Style` to `computed`, field-by-field. Translation
    /// is direct: each enum case maps to its FlexLayout counterpart, each
    /// `Length` resolves to the appropriate FlexLayout dimension type
    /// (px → CGFloat / .points, % → .fraction).
    private static func apply(
        _ s: Style,
        to computed: inout ComputedStyle,
        diagnostics: inout JoyDiagnostics
    ) {
        // Display — joy-dom's enum doesn't include `none`, so we don't
        // touch `isDisplayNone` here. (None can't be expressed in Style
        // today; future spec rev would add it.)
        if let v = s.display {
            switch v {
            case .flex:        computed.display = .flex
            case .block:       computed.display = .block
            case .inlineBlock: computed.display = .inline   // FlexDisplay has no inlineBlock; treat as inline
            }
            computed.isDisplayNone = false
        }

        // Container

        if let v = s.flexDirection {
            switch v {
            case .row:    computed.container.direction = .row
            case .column: computed.container.direction = .column
            }
        }

        if let v = s.flexWrap {
            switch v {
            case .nowrap: computed.container.wrap = .nowrap
            case .wrap:   computed.container.wrap = .wrap
            }
        }

        if let v = s.justifyContent {
            switch v {
            case .flexStart:    computed.container.justifyContent = .flexStart
            case .flexEnd:      computed.container.justifyContent = .flexEnd
            case .center:       computed.container.justifyContent = .center
            case .spaceBetween: computed.container.justifyContent = .spaceBetween
            case .spaceAround:  computed.container.justifyContent = .spaceAround
            }
        }

        if let v = s.alignItems {
            switch v {
            case .flexStart: computed.container.alignItems = .flexStart
            case .flexEnd:   computed.container.alignItems = .flexEnd
            case .center:    computed.container.alignItems = .center
            }
        }

        if let v = s.gap {
            switch v {
            case .uniform(let l):
                computed.container.gap = lengthToPx(l)
            case .axes(let column, let row):
                computed.container.rowGap    = lengthToPx(row)
                computed.container.columnGap = lengthToPx(column)
            }
        }

        if let v = s.padding {
            switch v {
            case .uniform(let l):
                let n = lengthToPx(l)
                computed.container.padding = EdgeInsets(top: n, leading: n, bottom: n, trailing: n)
            case .sides(let t, let r, let b, let l):
                computed.container.padding = EdgeInsets(
                    top: lengthToPx(t),
                    leading: lengthToPx(l),
                    bottom: lengthToPx(b),
                    trailing: lengthToPx(r)
                )
            }
        }

        if let v = s.overflow {
            // Overflow applies to both container and item contexts. The
            // flex engine reads from the item key when set, so we write
            // to both; the effective value is the same either way.
            let mapped: FlexOverflow
            switch v {
            case .visible: mapped = .visible
            case .hidden:  mapped = .hidden
            case .clip:    mapped = .clip
            case .scroll:  mapped = .scroll
            case .auto:    mapped = .auto
            }
            computed.container.overflow = mapped
            computed.item.overflow      = mapped
        }

        // Item

        if let v = s.flexGrow   { computed.item.grow   = CGFloat(v) }
        if let v = s.flexShrink { computed.item.shrink = CGFloat(v) }

        if let v = s.flexBasis {
            computed.item.basis = lengthToFlexBasis(v)
        }

        if let v = s.order { computed.item.order = v }

        if let v = s.width  { computed.item.width  = lengthToFlexSize(v) }
        if let v = s.height { computed.item.height = lengthToFlexSize(v) }

        if let v = s.zIndex { computed.item.zIndex = v }

        if let v = s.position {
            switch v {
            case .absolute: computed.item.position = .absolute
            case .relative: computed.item.position = .relative
            }
        }

        if let v = s.top    { computed.item.top      = lengthToPx(v) }
        if let v = s.bottom { computed.item.bottom   = lengthToPx(v) }
        if let v = s.left   { computed.item.leading  = lengthToPx(v) }
        if let v = s.right  { computed.item.trailing = lengthToPx(v) }

        // `_ = diagnostics` — kept in the signature for symmetry / future
        // spec rev. Today every Style field is typed and can't yield an
        // invalid-value warning at this layer.
        _ = diagnostics
    }

    // MARK: - Length helpers

    /// `Length` → CGFloat. Non-px units fall back to the raw value
    /// (treated as points), matching the Tier-3 serializer's behavior.
    /// Production payloads use only `px` for non-percentage fields.
    private static func lengthToPx(_ l: Length) -> CGFloat {
        CGFloat(l.value)
    }

    /// `Length` → `FlexBasis`. `px` → `.points(n)`; `%` → `.fraction(n / 100)`.
    private static func lengthToFlexBasis(_ l: Length) -> FlexBasis {
        switch l.unit {
        case "%": return .fraction(CGFloat(l.value) / 100)
        default:  return .points(CGFloat(l.value))
        }
    }

    /// `Length` → `FlexSize`. Same axis mapping as `lengthToFlexBasis`.
    private static func lengthToFlexSize(_ l: Length) -> FlexSize {
        switch l.unit {
        case "%": return .fraction(CGFloat(l.value) / 100)
        default:  return .points(CGFloat(l.value))
        }
    }
}
