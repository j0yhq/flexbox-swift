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
    /// The node's registered component type (drives element selectors and
    /// registry lookup). `nil` for the root node.
    public let schemaType: String?
    /// The fully cascaded style for this node.
    public let computedStyle: ComputedStyle

    public init(id: String, schemaType: String?, computedStyle: ComputedStyle) {
        self.id = id
        self.schemaType = schemaType
        self.computedStyle = computedStyle
    }
}
