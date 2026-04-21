// ComponentRegistry — maps component type names (`"button"`, `"text-input"`)
// to factory closures.
//
// A single `shared` instance serves as the package-wide default registry,
// but tests and previews instantiate their own registries to keep state
// isolated. The registry is *not* thread-safe in Phase 1 — callers should
// register everything during app startup. Phase 5 will add a lock.

import Foundation
import SwiftUI

/// Builds a SwiftUI view for one schema-supplied component.
///
/// The factory receives the props extracted from the schema and an event
/// sink that routes user interactions back to the `CSSLayout` host. Return
/// an `AnyView` to keep the registry value type-erased — each factory
/// controls its own body.
///
/// Tier 2 note: this typealias is the *legacy* factory shape. New
/// registrations should prefer ``ComponentBodyFactory`` via the
/// ``register(_:body:)`` overload, which returns the multi-host
/// ``ComponentBody`` wrapper. Unit 7 of the Tier-2 plan retires this
/// typealias in favour of `ComponentBody`; until then both shapes
/// coexist so call sites can migrate incrementally.
public typealias ComponentFactory = (_ props: ComponentProps, _ events: ComponentEvents) -> AnyView

/// Tier 2 factory shape — returns a ``ComponentBody`` wrapper that can
/// carry SwiftUI, UIKit, or WebKit-backed views uniformly.
public typealias ComponentBodyFactory = (_ props: ComponentProps, _ events: ComponentEvents) -> ComponentBody

/// Registry of component factories keyed by type name.
public final class ComponentRegistry {

    /// The package-wide default registry. Apps register their factories here
    /// once at startup; `CSSLayout` reads from it unless given a custom
    /// registry.
    public static let shared = ComponentRegistry()

    // Tier 2 unifies storage on the ``ComponentBodyFactory`` shape.
    // Legacy ``ComponentFactory`` registrations are wrapped at
    // registration time so both lookup methods share one bucket, and
    // either overload's registration can be retrieved via either
    // `factory(for:)` or `bodyFactory(for:)`.
    private var factories: [String: ComponentBodyFactory] = [:]

    public init() {}

    /// Register a factory for `type`. If `type` was registered previously,
    /// the new factory replaces it (last-wins, matching how a developer
    /// would expect `register` to behave during hot reload).
    ///
    /// Returns `self` so registrations can be chained fluently:
    /// ```swift
    /// ComponentRegistry.shared
    ///     .register("button") { props, events in … }
    ///     .register("text")   { props, _      in … }
    /// ```
    @discardableResult
    public func register(
        _ type: String,
        factory: @escaping ComponentFactory
    ) -> ComponentRegistry {
        // Adapt the legacy AnyView-returning factory into the unified
        // ComponentBody storage. The adapter captures `factory` and
        // reconstructs a `.custom` body on each lookup, so the legacy
        // factory is re-invoked per render (same contract as before).
        factories[type] = { props, events in
            .custom { factory(props, events) }
        }
        return self
    }

    /// Tier 2 register overload for the new ``ComponentBodyFactory`` shape.
    /// This is the preferred path for new code — the returned
    /// ``ComponentBody`` can carry SwiftUI, UIKit, or WebKit-backed views
    /// uniformly.
    @discardableResult
    public func register(
        _ type: String,
        body: @escaping ComponentBodyFactory
    ) -> ComponentRegistry {
        factories[type] = body
        return self
    }

    /// Look up a factory by component type. Returns `nil` for unknown types.
    ///
    /// Returns an AnyView-producing closure regardless of whether the
    /// original registration used the legacy or body overload — the body
    /// result is materialised via ``ComponentBody/makeView()``.
    public func factory(for type: String) -> ComponentFactory? {
        guard let body = factories[type] else { return nil }
        return { props, events in body(props, events).makeView() }
    }

    /// Tier 2: look up a ``ComponentBodyFactory`` by type. Returns the
    /// unified body factory — works for both legacy and Tier-2
    /// registrations.
    public func bodyFactory(for type: String) -> ComponentBodyFactory? {
        factories[type]
    }
}
