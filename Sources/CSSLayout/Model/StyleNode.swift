// StyleNode — a single node in the resolved style tree.
//
// Phase 1's tree is flat: one root plus every schema entry as a sibling.
// Phase 2 will add a `children` relationship for combinator-driven nesting.

import Foundation

/// One node in the `StyleTreeBuilder` output — an id, its optional
/// component type, and its resolved computed style.
public struct StyleNode: Equatable {
    /// The node's id. Matches `#id` selectors and local-component ids.
    public let id: String
    /// Id of the node's parent in the layout tree, or `nil` for the root.
    /// Resolved from ``SchemaEntry/parentID`` by ``StyleTreeBuilder`` —
    /// orphaned entries are re-parented to the root id, so this is never nil
    /// for non-root nodes.
    public let parentID: String?
    /// The node's registered component type (drives element selectors and
    /// registry lookup). `nil` for the root node.
    public let schemaType: String?
    /// The node's class names. Matches `.name` selectors in the cascade.
    /// Preserved in source order so the resolver doesn't hash-allocate per
    /// lookup (schemas are small; linear scan wins on cache).
    public let classes: [String]
    /// Mirror of `SchemaEntry.props` — forwarded to the component factory
    /// as `ComponentProps.values` by the resolver. Empty for the implicit
    /// root node and for entries that didn't declare props.
    public let props: [String: String]
    /// The fully cascaded style for this node.
    public let computedStyle: ComputedStyle

    public init(
        id: String,
        parentID: String? = nil,
        schemaType: String?,
        classes: [String] = [],
        props: [String: String] = [:],
        computedStyle: ComputedStyle
    ) {
        self.id = id
        self.parentID = parentID
        self.schemaType = schemaType
        self.classes = classes
        self.props = props
        self.computedStyle = computedStyle
    }
}
