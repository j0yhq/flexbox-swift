// ComponentRegistry — maps component type names (`"button"`, `"text-input"`)
// to factory closures.
//
// A single `shared` instance serves as the package-wide default registry,
// but tests and previews instantiate their own registries to keep state
// isolated. The registry is *not* thread-safe in Phase 1 — callers should
// register everything during app startup. Phase 5 will add a lock.

import Foundation
import SwiftUI

/// Builds a ``ComponentBody`` for one schema-supplied component.
///
/// The factory receives the props extracted from the schema and an event
/// sink that routes user interactions back to the `JoyDOMView` host. Return
/// a ``ComponentBody`` — constructed via `.custom { ... }`, `.uiKit(...)`,
/// or `.webView(...)` — so the registry stays host-agnostic.
///
/// Tier 2 retired the legacy `-> AnyView` shape in favour of this one.
/// Call sites that previously returned `AnyView(X)` now return
/// `.custom { X }`; UIKit- or WebKit-backed components use the
/// corresponding ``ComponentBody`` factory.
public typealias ComponentFactory = (_ props: ComponentProps, _ events: ComponentEvents) -> ComponentBody

/// Registry of component factories keyed by type name.
public final class ComponentRegistry {

    /// The package-wide default registry. Apps register their factories here
    /// once at startup; `JoyDOMView` reads from it unless given a custom
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
    ///     .register("button") { props, events in .custom { … } }
    ///     .register("text")   { props, _      in .custom { … } }
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
