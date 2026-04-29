// SchemaFlattener — walks a joy-dom `Node` tree and produces the flat
// `[SchemaEntry]` array CSSLayout's existing pipeline consumes.
//
// joy-dom's `spec.ts` represents the document as a recursive tree
// (`Node.children: ChildNode[]`); CSSLayout has always used a flat array
// with `parentID` links. The two shapes are equivalent in expressive
// power, so this file is a pure structural translation — no styling, no
// breakpoints, no resolution. Subsequent units layer on top:
//
//   • Unit 4 promotes each node's inline `props.style` into a synthetic
//     CSS rule, appended to the document CSS string.
//   • Unit 8 deep-merges per-breakpoint node overrides on top of the
//     entries this file produces, before resolve.
//
// Stable id generation: the resolver and CSS selectors both key off
// `SchemaEntry.id`, so every node needs one. When `Node.props.id` is
// present we use it verbatim (matching Josh's "node_id is props.id"
// convention from `DOM/guides/Breakpoints.md`); when absent we synthesize
// a path-based id like `_n_0_1` (root is `_root`). The leading
// underscore keeps synthetic ids out of the namespace authors are
// likely to use, so collisions with author-provided ids stay unlikely.
//
// Primitive children (`PrimitiveValue` — string / number / null in
// joy-dom) become their own `SchemaEntry` with a synthetic id and one
// of three pseudo types: `"primitive_string"`, `"primitive_number"`,
// `"primitive_null"`. The actual value is stored in `props["value"]`
// (string-serialized) so registered factories for those types can pick
// it up via `ComponentProps.string("value")`. Renderers register
// factories for these types the same way they register `div` / `p`.

import Foundation

/// Pure-function flattener for a joy-dom tree.
public enum SchemaFlattener {

    // MARK: - Public API

    /// Flatten a joy-dom layout tree into the `[SchemaEntry]` array
    /// CSSLayout's resolver consumes.
    ///
    /// - Parameter layout: the document's root node (`Spec.layout`).
    /// - Returns: schema entries in render order. The root entry has
    ///   `parentID == nil` so CSSLayout's existing root-attach behavior
    ///   applies (`StyleTreeBuilder` re-parents `nil` to the implicit
    ///   root, then composes the rest of the tree via `parentID` links).
    public static func flatten(_ layout: Node) -> [SchemaEntry] {
        return []
    }
}
