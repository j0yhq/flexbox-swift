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
public enum JoyDOMConverter {

    // MARK: - Public API

    /// Convert a `JoyDOMSpec` into the `CSSPayload` CSSLayout's
    /// resolver consumes.
    public static func convert(_ spec: JoyDOMSpec) -> CSSPayload {
        let schema = SchemaFlattener.flatten(spec.layout)

        // Document-level rules first. Sorted by selector key so output
        // is deterministic across dictionary iteration order.
        let documentRules = spec.style
            .sorted(by: { $0.key < $1.key })
            .compactMap { selector, style -> String? in
                let rule = StyleSerializer.rule(selector: selector, style: style)
                return rule.isEmpty ? nil : rule
            }

        // Per-node inline rules second. Their id-level specificity
        // wins on the cascade, but emitting after means same-specificity
        // ties also fall to inline (which matches authorial intent).
        let inlineCSS = inlineStyleCSS(for: spec.layout)
        let pieces = documentRules + (inlineCSS.isEmpty ? [] : [inlineCSS])

        return CSSPayload(
            css: pieces.joined(separator: "\n"),
            schema: schema
        )
    }

    /// Walk a layout tree and produce the CSS rules implied by each
    /// node's inline `props.style`. Each rule is keyed by the node's
    /// resolved id (`props.id` or a synthetic id matching what
    /// `SchemaFlattener` produces), so inline styles target the same
    /// `#id` selector the resolver uses.
    ///
    /// Returns an empty string when no node carries an inline style.
    public static func inlineStyleCSS(for layout: Node) -> String {
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
}
