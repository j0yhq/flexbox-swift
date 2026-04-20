// CSSEvent — the envelope delivered to `onEvent` handlers.
//
// Phase 1 keeps the shape minimal: name, source id, and a string-keyed
// payload. `propagates` and bubbling are Phase 2.

import Foundation

/// An event produced by a component factory and dispatched to the
/// `CSSLayout` view's registered `onEvent(_:)` handlers.
public struct CSSEvent: Equatable {
    /// The event name, e.g. `"submit"`, `"tap"`.
    public let name: String
    /// The id of the component that emitted the event (the `SchemaEntry.id`).
    public let sourceID: String
    /// Key/value payload. Phase 1 restricts this to strings to match
    /// `ComponentProps`.
    public let payload: [String: String]

    public init(name: String, sourceID: String, payload: [String: String] = [:]) {
        self.name = name
        self.sourceID = sourceID
        self.payload = payload
    }
}
