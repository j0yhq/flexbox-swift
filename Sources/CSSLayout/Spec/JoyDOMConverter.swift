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
    /// resolver consumes. Equivalent to the input — no styles applied,
    /// no breakpoints resolved — beyond translating shape.
    public static func convert(_ spec: JoyDOMSpec) -> CSSPayload {
        return CSSPayload(css: "", schema: [])
    }

    /// Walk a layout tree and produce the CSS rules implied by each
    /// node's inline `props.style`. Each rule is keyed by the node's
    /// resolved id (`props.id` or a synthetic id matching what
    /// `SchemaFlattener` produces), so inline styles target the same
    /// `#id` selector the resolver uses.
    ///
    /// Returns an empty string when no node carries an inline style.
    public static func inlineStyleCSS(for layout: Node) -> String {
        return ""
    }
}
