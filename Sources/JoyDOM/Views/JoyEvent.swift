// JoyEvent — the envelope delivered to `onEvent` handlers.
//
// Phase 1 delivered the minimum: name, source id, string-keyed payload.
// Phase 2 adds `propagates` so a handler can stop the event from bubbling
// further up the component tree. Defaults to `true` (DOM convention).

import Foundation

/// An event produced by a component factory and dispatched to the
/// `JoyDOMView` view's registered `onEvent(_:)` handlers.
public struct JoyEvent: Equatable {
    /// The event name, e.g. `"submit"`, `"tap"`.
    public let name: String
    /// The id of the component that emitted the event (the `SchemaEntry.id`).
    public let sourceID: String
    /// Key/value payload. Phase 1 restricts this to strings to match
    /// `ComponentProps`.
    public let payload: [String: String]
    /// When `true` (the default) the dispatcher walks ancestor nodes looking
    /// for additional handlers after firing the handler at the source. Set to
    /// `false` in a factory to emit an event that only reaches the node that
    /// owns the component (Phase 2).
    public let propagates: Bool

    public init(
        name: String,
        sourceID: String,
        payload: [String: String] = [:],
        propagates: Bool = true
    ) {
        self.name = name
        self.sourceID = sourceID
        self.payload = payload
        self.propagates = propagates
    }
}
