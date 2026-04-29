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
internal enum SchemaFlattener {

    // MARK: - Public API

    /// Flatten a joy-dom layout tree into the `[SchemaEntry]` array
    /// CSSLayout's resolver consumes.
    ///
    /// - Parameter layout: the document's root node (`Spec.layout`).
    /// - Returns: schema entries in render order. The root entry has
    ///   `parentID == nil` so CSSLayout's existing root-attach behavior
    ///   applies (`StyleTreeBuilder` re-parents `nil` to the implicit
    ///   root, then composes the rest of the tree via `parentID` links).
    internal static func flatten(_ layout: Node) -> [SchemaEntry] {
        var output: [SchemaEntry] = []
        emit(node: layout, parentID: nil, path: [], into: &output)
        return output
    }

    // MARK: - Recursion

    /// Append the entry for `node` (and recursively its children) to
    /// `output`. `path` is the index trail from the root used to mint
    /// synthetic ids when `node.props.id` is absent.
    private static func emit(
        node: Node,
        parentID: String?,
        path: [Int],
        into output: inout [SchemaEntry]
    ) {
        let id = node.props?.id ?? syntheticID(for: path)
        output.append(SchemaEntry(
            id: id,
            type: node.type,
            classes: node.props?.className ?? [],
            parentID: parentID,
            props: [:]   // Inline styles & arbitrary props arrive in later units.
        ))

        // Recurse children. Each ChildNode is either a Node (deeper
        // recursion) or a primitive (leaf entry).
        for (index, child) in (node.children ?? []).enumerated() {
            let childPath = path + [index]
            switch child {
            case .node(let childNode):
                emit(node: childNode, parentID: id, path: childPath, into: &output)
            case .primitive(let value):
                output.append(primitiveEntry(value, parentID: id, path: childPath))
            }
        }
    }

    // MARK: - Synthetic id

    /// `[]` → `"_root"`; `[0]` → `"_n_0"`; `[0, 1]` → `"_n_0_1"`.
    private static func syntheticID(for path: [Int]) -> String {
        guard !path.isEmpty else { return "_root" }
        return "_n_" + path.map(String.init).joined(separator: "_")
    }

    // MARK: - Primitive child → SchemaEntry

    private static func primitiveEntry(
        _ value: PrimitiveValue,
        parentID: String,
        path: [Int]
    ) -> SchemaEntry {
        let id = syntheticID(for: path)
        switch value {
        case .string(let s):
            return SchemaEntry(
                id: id,
                type: "primitive_string",
                parentID: parentID,
                props: ["value": s]
            )
        case .number(let n):
            return SchemaEntry(
                id: id,
                type: "primitive_number",
                parentID: parentID,
                props: ["value": formatNumber(n)]
            )
        case .null:
            return SchemaEntry(
                id: id,
                type: "primitive_null",
                parentID: parentID,
                props: [:]
            )
        }
    }

    /// Match `StyleSerializer`'s number formatting so primitive numbers
    /// round-trip without spurious `.0` decorations.
    private static func formatNumber(_ value: Double) -> String {
        if value.truncatingRemainder(dividingBy: 1) == 0 {
            return String(Int(value))
        }
        return String(value)
    }
}
