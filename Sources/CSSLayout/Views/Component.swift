// Component — a local override for a single schema id.
//
// `CSSLayout` looks up every rendered node against:
//   1. The locals block (this type)
//   2. The component registry
//   3. A placeholder fallback
//
// Locals let app code render one-off SwiftUI views without touching the
// global registry — typical for inline components, previews, and tests.
//
// Phase 2 adds `.onCSSEvent(_ name:, _ handler:)` so a local can observe
// bubbling events from its descendants in the schema tree. Handlers are
// keyed by event name; non-matching names are ignored.

import Foundation
import SwiftUI

/// A local component override for a single node id.
///
/// Use inside the trailing closure of `CSSLayout(...)` to attach a SwiftUI
/// view directly to a schema id, bypassing the registry.
///
/// ```swift
/// CSSLayout(payload: payload) {
///     Component("banner") { Image("hero").resizable() }
///     Component("submit") { Button("Go") { … } }
///         .onCSSEvent("tap") { event in print(event.sourceID) }
/// }
/// ```
public struct Component {
    /// The schema id this component renders for.
    public let id: String
    /// Type-erased SwiftUI body captured from the trailing closure.
    public let content: AnyView
    /// Event handlers keyed by event name. Empty by default; populated by
    /// ``onCSSEvent(_:_:)``.
    internal var handlers: [String: (CSSEvent) -> Void]

    public init<V: View>(_ id: String, @ViewBuilder _ content: () -> V) {
        self.id = id
        self.content = AnyView(content())
        self.handlers = [:]
    }

    /// Register a handler for events with `name` emitted by this component
    /// or any of its schema descendants. Returns a new `Component` — chain
    /// multiple calls for different names.
    ///
    /// Handlers fire during the bubble phase: the originating node first,
    /// then each ancestor in turn, then the root `onEvent` handlers. Events
    /// emitted with `propagates: false` are target-only and never reach an
    /// ancestor handler registered here.
    public func onCSSEvent(
        _ name: String,
        _ handler: @escaping (CSSEvent) -> Void
    ) -> Component {
        var copy = self
        copy.handlers[name] = handler
        return copy
    }
}
