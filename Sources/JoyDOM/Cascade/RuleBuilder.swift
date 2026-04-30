// RuleBuilder — turns a `Spec` (plus the active breakpoint, if any)
// into the `[StyleResolver.Rule]` list the cascade walks.
//
// Tier 5 absorbs JoyDOMConverter's role: rules used to be produced by
// serializing `Style` objects to CSS text and re-parsing the text. Now
// we walk the typed `Style` values directly and emit `Rule`s with
// pre-computed selectors and specificity. Selector keys still go
// through `SelectorParser` (they're string keys in the spec wire
// format), but values stay typed end-to-end.
//
// Source-order assignment matches the documented cascade in
// `DOM/guides/Styles.md`:
//
//   1. `Spec.style[selector]`               (lowest priority)
//   2. `Breakpoint.style[selector]`
//   3. Per-`Node` `props.style` (`#id` rule)
//   4. `Breakpoint.nodes[id].style` (`#id` rule, highest)
//
// All four collapse into a single rule list, ordered. Equal-specificity
// ties resolve to later source order — so per-node breakpoint inline
// styles win when they exist, then per-node base inline, then
// breakpoint selectors, then document selectors. Matches Josh's
// documented precedence exactly.

import Foundation

internal enum RuleBuilder {

    /// Build the cascade rule list for `spec` with `activeBreakpoint`
    /// (or none).
    ///
    /// Source order is assigned monotonically across the four layers in
    /// priority order (document → breakpoint selector → node inline →
    /// breakpoint node inline). Ties on specificity break toward later
    /// sourceOrder, which gives the right precedence end-to-end.
    static func buildRules(
        from spec: Spec,
        activeBreakpoint: Breakpoint?,
        diagnostics: inout JoyDiagnostics
    ) -> [StyleResolver.Rule] {
        var rules: [StyleResolver.Rule] = []
        var sourceOrder = 0

        // 1. Document-level selector rules.
        appendSelectorRules(
            spec.style,
            into: &rules,
            sourceOrder: &sourceOrder,
            diagnostics: &diagnostics
        )

        // 2. Active breakpoint selector rules — later in source order so
        //    they beat document-level rules at equal specificity.
        if let bp = activeBreakpoint {
            appendSelectorRules(
                bp.style,
                into: &rules,
                sourceOrder: &sourceOrder,
                diagnostics: &diagnostics
            )
        }

        // 3. Per-node inline `props.style` — synthetic `#id { ... }` rules.
        //    Only nodes with author-supplied `props.id` are addressable;
        //    synthetic ids never enter the rule index (the spec says
        //    unaddressable nodes can't be re-styled by id).
        appendInlineRules(
            tree: spec.layout,
            into: &rules,
            sourceOrder: &sourceOrder
        )

        // 4. Per-node breakpoint overrides (highest priority).
        if let bp = activeBreakpoint {
            for (nodeID, props) in bp.nodes.sorted(by: { $0.key < $1.key }) {
                guard let style = props.style else { continue }
                let selector = idSelector(nodeID)
                rules.append(StyleResolver.Rule(
                    selector: selector,
                    style: style,
                    specificity: Specificity.of(selector),
                    sourceOrder: sourceOrder
                ))
                sourceOrder += 1
            }
        }

        return rules
    }

    // MARK: - Helpers

    /// Convert a `[selector: Style]` map into rules. Selector keys go
    /// through `SelectorParser.parseList` to handle comma-grouped forms
    /// (`#a, #b, #c`) — each grouped selector becomes its own rule.
    private static func appendSelectorRules(
        _ map: [String: Style],
        into rules: inout [StyleResolver.Rule],
        sourceOrder: inout Int,
        diagnostics: inout JoyDiagnostics
    ) {
        // Sort the dict by key so output is deterministic.
        for (selectorKey, style) in map.sorted(by: { $0.key < $1.key }) {
            let parsed = SelectorParser.parseList(selectorKey, diagnostics: &diagnostics)
            for selector in parsed {
                rules.append(StyleResolver.Rule(
                    selector: selector,
                    style: style,
                    specificity: Specificity.of(selector),
                    sourceOrder: sourceOrder
                ))
                sourceOrder += 1
            }
        }
    }

    /// Walk the Node tree and emit a `#<id> { ... }` rule for each node
    /// that has BOTH `props.id` AND `props.style` set. Nodes missing
    /// either are skipped.
    private static func appendInlineRules(
        tree: Node,
        into rules: inout [StyleResolver.Rule],
        sourceOrder: inout Int
    ) {
        if let id = tree.props?.id, let style = tree.props?.style {
            let selector = idSelector(id)
            rules.append(StyleResolver.Rule(
                selector: selector,
                style: style,
                specificity: Specificity.of(selector),
                sourceOrder: sourceOrder
            ))
            sourceOrder += 1
        }
        for child in tree.children ?? [] {
            if case .node(let n) = child {
                appendInlineRules(tree: n, into: &rules, sourceOrder: &sourceOrder)
            }
        }
    }

    /// Build a single-id `ComplexSelector` for `#<nodeID>`. Used for
    /// per-node inline rules and breakpoint per-node overrides.
    private static func idSelector(_ nodeID: String) -> ComplexSelector {
        ComplexSelector(CompoundSelector(.id(nodeID)))
    }
}
