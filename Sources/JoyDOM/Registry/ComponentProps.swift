// ComponentProps — the read-only bag of values passed to a component factory.
//
// Phase 1 is intentionally thin: all props are `String`, lookup is by key,
// and the node id is exposed separately so components that render "#foo" in
// debug don't have to stuff it into the props dictionary.
//
// Phase 3 will expand this with typed accessors (`int(_:)`, `bool(_:)`,
// `binding(_:)`) once `FormState` ships. The `string(_:)` API is the
// stable base.

import Foundation

/// Read-only access to a component's key/value props.
///
/// Factories read props but never mutate them; JoyDOMView re-invokes the
/// factory whenever the upstream payload changes.
public struct ComponentProps {
    /// The node's id (mirrors `SchemaEntry.id`). Included here so factories
    /// needn't accept two parameters.
    public let id: String
    /// The raw props dictionary. Phase 1 stores strings only.
    public let values: [String: String]

    public init(_ values: [String: String], id: String = "") {
        self.id = id
        self.values = values
    }

    /// Returns the string value for `key`, or `nil` if absent.
    public func string(_ key: String) -> String? {
        values[key]
    }
}
