// ComponentEvents — the outbound-event sink handed to each component factory.
//
// Phase 2 added the `propagates` bit on events.
// Phase 3 adds `binding(_:)` — a typed escape hatch that hands the factory a
// SwiftUI `Binding<String>` for a named field (e.g. `"value"`, `"checked"`).
// The surrounding payload decides what backs the binding (`FormState` in
// production, a plain local value in tests/previews); factories remain
// oblivious.
//
// The `binding(_:)` implementation delegates to an injected `BindingResolver`
// closure. In production that closure is built by `ComponentResolver`, which
// closes over `FormState` and the current node's props so `binding("value")`
// resolves to the correct FormState path. When no resolver is wired (test,
// preview, or a factory whose schema didn't declare a binding), the method
// falls back to `Binding.constant("")` — factories don't have to branch on
// whether the surrounding payload is participating.

import Foundation
import SwiftUI

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
    public typealias Sink = (
        _ name: String,
        _ payload: [String: String],
        _ propagates: Bool
    ) -> Void
    /// Produces the SwiftUI `Binding<String>` returned by `binding(_:)`.
    /// The field name is the key the factory asked for (e.g. `"value"`);
    /// the resolver decides how to map that to FormState storage.
    public typealias BindingResolver = (_ field: String) -> Binding<String>

    private let sink: Sink?
    private let bindingResolver: BindingResolver?

    public init(_ sink: Sink? = nil) {
        self.sink = sink
        self.bindingResolver = nil
    }

    /// Wire both the event sink and the binding resolver. The resolver
    /// parameter is nullable so test call sites can opt into binding
    /// behavior independently of event dispatch.
    public init(sink: Sink?, bindings: BindingResolver?) {
        self.sink = sink
        self.bindingResolver = bindings
    }

    /// Emit a named event with an optional payload. `propagates` controls
    /// whether the event bubbles up the component tree to ancestor handlers
    /// (including the root `onEvent` handler). Defaults to `true`, matching
    /// DOM convention.
    public func emit(
        _ name: String,
        payload: [String: String] = [:],
        propagates: Bool = true
    ) {
        sink?(name, payload, propagates)
    }

    /// Return a `Binding<String>` for `field`. If a resolver is installed
    /// it is called with the verbatim field name; otherwise a dead binding
    /// (`Binding.constant("")`) is returned so factories don't have to
    /// branch on whether the surrounding payload wired them up.
    public func binding(_ field: String) -> Binding<String> {
        bindingResolver?(field) ?? .constant("")
    }
}
