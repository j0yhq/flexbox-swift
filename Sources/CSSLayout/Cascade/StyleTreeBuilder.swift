// StyleTreeBuilder — produces a flat list of `StyleNode`s ready for rendering.
//
// Phase 1 tree shape:
//   [root]            ← id = `rootID` (default "root"), schemaType = nil
//   ├── schema[0]     ← child 1
//   ├── schema[1]     ← child 2
//   └── …             ← every schema entry, in declared order
//
// Phase 2 adds hierarchical nesting driven by selector combinators; the
// public API here stays stable — only the internal assembly changes.

import Foundation

/// Builds the flat style tree consumed by `ComponentResolver`.
public enum StyleTreeBuilder {

    /// Construct a node list for rendering.
    ///
    /// - Parameters:
    ///   - rootID: The id used for the implicit root container. `#<rootID>`
    ///     selectors in the stylesheet apply to it.
    ///   - schema: Schema entries in render order. Each becomes one child of
    ///     the root.
    ///   - stylesheet: The parsed CSS to cascade over.
    ///   - diagnostics: Forwarded to `StyleResolver` for invalid-value warnings.
    /// - Returns: `[root] + children`, always at least one node.
    public static func build(
        rootID: String,
        schema: [SchemaEntry],
        stylesheet: Stylesheet,
        diagnostics: inout CSSDiagnostics
    ) -> [StyleNode] {
        var nodes: [StyleNode] = []

        // Root first. Its `schemaType` is nil so element selectors never match.
        let rootStyle = StyleResolver.resolve(
            id: rootID,
            schemaType: nil,
            stylesheet: stylesheet,
            diagnostics: &diagnostics
        )
        nodes.append(StyleNode(id: rootID, schemaType: nil, computedStyle: rootStyle))

        // Children in schema insertion order.
        for entry in schema {
            let style = StyleResolver.resolve(
                id: entry.id,
                schemaType: entry.type,
                stylesheet: stylesheet,
                diagnostics: &diagnostics
            )
            nodes.append(StyleNode(id: entry.id, schemaType: entry.type, computedStyle: style))
        }

        return nodes
    }
}
