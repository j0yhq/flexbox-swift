// JoyDOMConverter — turns a `JoyDOMSpec` (Unit 1) into the
// `CSSPayload` CSSLayout's resolver already consumes.
//
// The converter is the boundary between joy-dom's structured-object
// world (tree of `Node`s, typed `Style` values, `Breakpoint` arrays)
// and CSSLayout's text-CSS-plus-flat-schema world. By doing the
// translation at this seam we keep the existing parser, cascade, and
// resolver as the single source of truth for layout — no fork.
//
// What this unit (Unit 4) covers:
//   • Schema flattening (delegated to `SchemaFlattener`)
//   • Document-level style serialization (selector-keyed → CSS rules)
//   • Inline node-style injection (per-node `#id { ... }` rules with
//     id-level specificity, so they win over selector rules per
//     Josh's documented cascade order)
//
// What's deliberately deferred:
//   • Active breakpoint application — Unit 7 picks the active
//     breakpoint, Unit 8 deep-merges its overrides into this output.
//
// Cascade order honored by this converter:
//   `Spec.style[selector]`  ← document-level rules emitted first
//   `Node.props.style`      ← per-node `#id { ... }` rules emitted
//                             after, so id-specificity gives them
//                             priority over selector rules.

import Foundation

/// Pure-function converter from `JoyDOMSpec` to `CSSPayload`.
internal enum JoyDOMConverter {

    // MARK: - Public API

    /// Convert a `JoyDOMSpec` into the `CSSPayload` CSSLayout's
    /// resolver consumes, applying the active breakpoint (if any) for
    /// `viewport`.
    ///
    /// Cascade order produced (later wins on tie):
    ///   `Document.style → Breakpoint.style → node.props.style →
    ///    Breakpoint.nodes[id].style`
    ///
    /// Per-node breakpoint overrides also REPLACE `className` on the
    /// affected `SchemaEntry` so class selectors re-match against the
    /// breakpoint-effective class list.
    internal static func convert(_ spec: JoyDOMSpec, viewport: Viewport?) -> CSSPayload {
        let activeBreakpoint = viewport.flatMap {
            BreakpointResolver.active(in: $0, breakpoints: spec.breakpoints)
        }

        // Schema entries — base flatten, then per-node className
        // overrides from the active breakpoint applied as a transform.
        let baseSchema = SchemaFlattener.flatten(spec.layout)
        let schema = applyClassNameOverrides(
            baseSchema,
            from: activeBreakpoint?.nodes ?? [:]
        )

        // Document-level rules first. Sorted by selector key so output
        // is deterministic across dictionary iteration order.
        let documentRules = serializeSelectorMap(spec.style)

        // Active breakpoint's selector-keyed rules sit between document
        // rules and any inline rules — later source order means they
        // win equal-specificity ties against document rules.
        let breakpointSelectorRules = serializeSelectorMap(activeBreakpoint?.style ?? [:])

        // Per-node inline rules from `Node.props.style`.
        let baseInlineCSS = inlineStyleCSS(for: spec.layout)

        // Per-node breakpoint inline rules from
        // `Breakpoint.nodes[id].style`. Emitted last so their later
        // source order wins equal-specificity ties against base inline.
        let breakpointInlineRules = (activeBreakpoint?.nodes ?? [:])
            .sorted(by: { $0.key < $1.key })
            .compactMap { id, props -> String? in
                guard let style = props.style else { return nil }
                let rule = StyleSerializer.rule(selector: "#\(id)", style: style)
                return rule.isEmpty ? nil : rule
            }

        let pieces: [String] = (
            documentRules
            + breakpointSelectorRules
            + (baseInlineCSS.isEmpty ? [] : [baseInlineCSS])
            + breakpointInlineRules
        )

        return CSSPayload(
            css: pieces.joined(separator: "\n"),
            schema: schema
        )
    }

    /// Convert a `JoyDOMSpec` into the `CSSPayload` CSSLayout's
    /// resolver consumes.
    internal static func convert(_ spec: JoyDOMSpec) -> CSSPayload {
        return convert(spec, viewport: nil)
    }

    /// Walk a layout tree and produce the CSS rules implied by each
    /// node's inline `props.style`. Each rule is keyed by the node's
    /// resolved id (`props.id` or a synthetic id matching what
    /// `SchemaFlattener` produces), so inline styles target the same
    /// `#id` selector the resolver uses.
    ///
    /// Returns an empty string when no node carries an inline style.
    internal static func inlineStyleCSS(for layout: Node) -> String {
        var rules: [String] = []
        collectInlineRules(node: layout, path: [], into: &rules)
        return rules.joined(separator: "\n")
    }

    // MARK: - Recursion

    /// Append inline-style rules for `node` and recurse into its
    /// children. Mirrors `SchemaFlattener.emit` exactly so resolved ids
    /// stay in lockstep — same `props.id`-or-synthetic policy, same
    /// path encoding for the synthetic case.
    private static func collectInlineRules(
        node: Node,
        path: [Int],
        into rules: inout [String]
    ) {
        if let style = node.props?.style {
            let id = resolveID(node: node, path: path)
            let rule = StyleSerializer.rule(selector: "#\(id)", style: style)
            if !rule.isEmpty {
                rules.append(rule)
            }
        }

        for (index, child) in (node.children ?? []).enumerated() {
            switch child {
            case .node(let childNode):
                collectInlineRules(node: childNode, path: path + [index], into: &rules)
            case .primitive:
                // Primitives can't carry styles in joy-dom — they're
                // bare values. Nothing to emit.
                break
            }
        }
    }

    /// Same id-resolution policy as `SchemaFlattener`: explicit
    /// `props.id` wins; otherwise a path-based synthetic id keeps
    /// generation deterministic and matches the schema entries that
    /// `SchemaFlattener.flatten` will produce for the same tree.
    private static func resolveID(node: Node, path: [Int]) -> String {
        if let explicit = node.props?.id {
            return explicit
        }
        if path.isEmpty { return "_root" }
        return "_n_" + path.map(String.init).joined(separator: "_")
    }

    // MARK: - Per-node breakpoint overrides

    /// Apply `className` overrides from the active breakpoint to the
    /// flattened schema. Only `className` is applied here — `style`
    /// overrides ride the CSS cascade via dedicated `#id { ... }` rules
    /// emitted in `convert(_:viewport:)`.
    private static func applyClassNameOverrides(
        _ schema: [SchemaEntry],
        from overrides: [String: NodeProps]
    ) -> [SchemaEntry] {
        guard !overrides.isEmpty else { return schema }
        return schema.map { entry in
            guard let override = overrides[entry.id],
                  let newClasses = override.className
            else { return entry }
            return SchemaEntry(
                id: entry.id,
                type: entry.type,
                classes: newClasses,
                parentID: entry.parentID,
                props: entry.props
            )
        }
    }

    /// Stable, deterministic CSS rules for a `[selector: Style]` map.
    /// Sorted by selector so dictionary iteration order doesn't leak
    /// into golden-string tests downstream.
    private static func serializeSelectorMap(_ map: [String: Style]) -> [String] {
        map.sorted(by: { $0.key < $1.key })
            .compactMap { selector, style -> String? in
                let rule = StyleSerializer.rule(selector: selector, style: style)
                return rule.isEmpty ? nil : rule
            }
    }
}
