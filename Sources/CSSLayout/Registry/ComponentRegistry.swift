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
public typealias ComponentFactory = (_ props: ComponentProps, _ events: ComponentEvents) -> AnyView

/// Registry of component factories keyed by type name.
public final class ComponentRegistry {

    /// The package-wide default registry. Apps register their factories here
    /// once at startup; `CSSLayout` reads from it unless given a custom
    /// registry.
    public static let shared = ComponentRegistry()

    private var factories: [String: ComponentFactory] = [:]

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
        factories[type] = factory
        return self
    }

    /// Look up a factory by component type. Returns `nil` for unknown types.
    public func factory(for type: String) -> ComponentFactory? {
        factories[type]
    }
}
