// ComponentEvents — the outbound-event sink handed to each component factory.
//
// Phase 2 added the `propagates` bit on events.
// Phase 3 adds `binding(_:)` — a typed escape hatch that hands the factory a
// SwiftUI `Binding<String>` for a named field (e.g. `"value"`, `"checked"`).
// The surrounding payload decides what backs the binding (`FormState` in
// production, a plain local value in tests/previews); factories remain
// oblivious.
//
// Tier 2 adds a host-agnostic companion to `binding(_:)`: `value(for:)`,
// `setValue(_:for:)`, and `observe(_:_:)`. These are what non-SwiftUI
// factories (UIKit, WKWebView, Flutter) can reach for without pulling in
// SwiftUI's `Binding<String>`. All three delegate to an optional
// `ValueStore` injected via the new init overload; unwired instances
// return nil / no-op / a dead cancellable so test and preview call sites
// stay clean.

import Foundation
import SwiftUI

/// Token returned by ``ComponentEvents/observe(_:_:)``. Calling
/// ``cancel()`` stops further observer callbacks for the registration.
///
/// Deliberately **not** Combine's `Cancellable`: JoyDOMView has no Combine
/// dependency and host-agnostic factories should not need one either.
public protocol Cancellable: AnyObject {
    func cancel()
}

/// Host-agnostic value store injected into ``ComponentEvents``.
///
/// Production wires this to `FormState`; tests and previews can inject an
/// in-memory double. The three closures mirror the host-agnostic surface
/// of ``ComponentEvents`` — there's no SwiftUI-specific type anywhere.
public struct ValueStore {
    public typealias Getter = (_ field: String) -> String?
    public typealias Setter = (_ value: String, _ field: String) -> Void
    public typealias Observer = (
        _ field: String,
        _ handler: @escaping (String) -> Void
    ) -> Cancellable

    public let get: Getter
    public let set: Setter
    public let observe: Observer

    public init(
        get: @escaping Getter,
        set: @escaping Setter,
        observe: @escaping Observer
    ) {
        self.get = get
        self.set = set
        self.observe = observe
    }
}

/// Internal no-op cancellable — returned when no value store is wired,
/// so factories can call `observe` unconditionally and just discard the
/// token.
internal final class NoopCancellable: Cancellable {
    func cancel() {}
}

/// The outbound event channel given to a component factory.
///
/// Factories call `emit` to notify the surrounding `JoyDOMView` of user
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
    private let valueStore: ValueStore?

    public init(_ sink: Sink? = nil) {
        self.sink = sink
        self.bindingResolver = nil
        self.valueStore = nil
    }

    /// Wire both the event sink and the binding resolver. The resolver
    /// parameter is nullable so test call sites can opt into binding
    /// behavior independently of event dispatch.
    public init(sink: Sink?, bindings: BindingResolver?) {
        self.sink = sink
        self.bindingResolver = bindings
        self.valueStore = nil
    }

    /// Wire the sink, binding resolver, and host-agnostic value store in
    /// one go. All three parameters are optional — pass `nil` for the
    /// surfaces a given factory doesn't exercise.
    public init(
        sink: Sink?,
        bindings: BindingResolver?,
        values: ValueStore?
    ) {
        self.sink = sink
        self.bindingResolver = bindings
        self.valueStore = values
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

    // MARK: - Host-agnostic value surface (Tier 2)

    /// Read `field`'s current value from the injected ``ValueStore``, or
    /// `nil` when nothing is wired. Host-agnostic: no SwiftUI types.
    public func value(for field: String) -> String? {
        valueStore?.get(field)
    }

    /// Write `value` to `field` through the injected ``ValueStore``. A
    /// no-op when nothing is wired.
    public func setValue(_ value: String, for field: String) {
        valueStore?.set(value, field)
    }

    /// Subscribe to changes on `field`. The returned token's ``cancel()``
    /// removes the subscription. When nothing is wired the token is
    /// harmless and the handler is never called.
    public func observe(
        _ field: String,
        _ handler: @escaping (String) -> Void
    ) -> Cancellable {
        valueStore?.observe(field, handler) ?? NoopCancellable()
    }
}
