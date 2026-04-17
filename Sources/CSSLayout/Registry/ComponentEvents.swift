// ComponentEvents — the outbound-event sink handed to each component factory.
//
// Phase 1 supports exactly one direction: factory → root handler. There is
// no bubbling, no `*` catch-all, no local `.onCSSEvent` modifier. The
// `CSSLayout` view injects a sink that dispatches to any handlers registered
// via `.onEvent("name", …)`.

import Foundation

/// The outbound event channel given to a component factory.
///
/// Factories call `emit` to notify the surrounding `CSSLayout` of user
/// interactions; the sink decides what to do with the event (typically fan
/// out to the registered `onEvent` handlers, but for tests it's often a
/// simple closure that records calls).
public struct ComponentEvents {
    /// The underlying dispatcher. `nil` means "no sink wired" — `emit` is a
    /// no-op. This keeps factory code safe to invoke in isolation (e.g.
    /// registry tests, previews).
    public typealias Sink = (_ name: String, _ payload: [String: String]) -> Void
    private let sink: Sink?

    public init(_ sink: Sink? = nil) {
        self.sink = sink
    }

    /// Emit a named event with an optional payload.
    public func emit(_ name: String, payload: [String: String] = [:]) {
        sink?(name, payload)
    }
}
