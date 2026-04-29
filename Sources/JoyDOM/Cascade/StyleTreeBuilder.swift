// StyleTreeBuilder — produces a flat list of `StyleNode`s ready for rendering.
//
// Tree shape:
//   [root]                ← id = `rootID` (default "root"), schemaType = nil
//   ├── schema[i] …       ← entries with `parentID == nil` (or a missing id)
//   │   ├── schema[k] …   ← entries whose `parentID` points to an earlier entry
//   │   └── …
//   └── schema[j] …
//
// The returned array is still flat and preserves schema insertion order so the
// caller's `ForEach` loop renders children in the order the author declared
// them. Parent-child relationships are captured in `StyleNode.parentID` and
// used by the resolver for descendant / child combinator matching.

import Foundation

/// Builds the flat style tree consumed by `ComponentResolver`.
internal enum StyleTreeBuilder {

    /// Construct a node list for rendering.
    ///
    /// - Parameters:
    ///   - rootID: The id used for the implicit root container. `#<rootID>`
    ///     selectors in the stylesheet apply to it.
    ///   - schema: Schema entries in render order. Each becomes one child of
    ///     its declared parent (or of the root when `parentID` is nil or
    ///     dangling).
    ///   - stylesheet: The parsed CSS to cascade over.
    ///   - diagnostics: Forwarded to `StyleResolver` for invalid-value warnings.
    /// - Returns: `[root] + children`, always at least one node.
    internal static func build(
        rootID: String,
        schema: [SchemaEntry],
        stylesheet: Stylesheet,
        diagnostics: inout JoyDiagnostics
    ) -> [StyleNode] {
        // Index schema entries by id for parent lookup. First-wins on
        // duplicates (matches the render-order invariant — later copies would
        // be silently shadowed by earlier parent-chain lookups otherwise) and
        // emits one diagnostic per duplicated id so authors notice.
        var byID: [String: SchemaEntry] = [:]
        var seen: Set<String> = []
        for entry in schema {
            if seen.insert(entry.id).inserted {
                byID[entry.id] = entry
            } else {
                diagnostics.warn(.init(.duplicateSchemaID(entry.id)))
            }
        }

        /// Resolve an entry's effective parent id. Missing `parentID` or one
        /// that doesn't point at another entry both fall back to root — this
        /// keeps the tree connected regardless of schema authoring errors.
        func effectiveParentID(_ entry: SchemaEntry) -> String {
            if let pid = entry.parentID, byID[pid] != nil { return pid }
            return rootID
        }

        /// Walk parentID pointers outwards (not including root) and collect
        /// each ancestor as a `NodeRef` for the resolver. `innermost first,
        /// outermost last`, matching the resolver's contract.
        func ancestorChain(of entry: SchemaEntry) -> [StyleResolver.NodeRef] {
            var chain: [StyleResolver.NodeRef] = []
            var currentID = effectiveParentID(entry)
            var visited: Set<String> = [entry.id]      // guard against cycles
            while currentID != rootID, let parent = byID[currentID] {
                if !visited.insert(parent.id).inserted { break }
                chain.append(StyleResolver.NodeRef(
                    id: parent.id,
                    schemaType: parent.type,
                    classes: parent.classes
                ))
                currentID = effectiveParentID(parent)
            }
            return chain
        }

        var nodes: [StyleNode] = []

        // Root first. Its `schemaType` is nil so element selectors never match.
        let rootStyle = StyleResolver.resolve(
            id: rootID,
            schemaType: nil,
            classes: [],
            ancestors: [],
            stylesheet: stylesheet,
            diagnostics: &diagnostics
        )
        nodes.append(StyleNode(
            id: rootID,
            parentID: nil,
            schemaType: nil,
            classes: [],
            computedStyle: rootStyle
        ))

        // Children in schema insertion order, deduplicated by id so a
        // duplicate schema entry doesn't produce two StyleNodes with the
        // same id (which would break `parentByID` and event bubbling).
        var emitted: Set<String> = []
        for entry in schema where emitted.insert(entry.id).inserted {
            let ancestors = ancestorChain(of: entry)
            let style = StyleResolver.resolve(
                id: entry.id,
                schemaType: entry.type,
                classes: entry.classes,
                ancestors: ancestors,
                stylesheet: stylesheet,
                diagnostics: &diagnostics
            )
            nodes.append(StyleNode(
                id: entry.id,
                parentID: effectiveParentID(entry),
                schemaType: entry.type,
                classes: entry.classes,
                props: entry.props,
                computedStyle: style
            ))
        }

        return nodes
    }
}
