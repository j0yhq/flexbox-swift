// DefaultPrimitives — `ComponentRegistry.withDefaultPrimitives()` adds
// factories for the joy-dom primitives every renderer needs:
//
//   • `div`              — passthrough container (children compose
//                          through the layout tree).
//   • `p`                — paragraph; children render through the
//                          layout tree exactly like `div`. Block-flow
//                          semantics aren't represented in flex-only
//                          JoyDOMView, so `p` and `div` differ only by
//                          element type for selector purposes.
//   • `primitive_string` — `Text(props["value"])` — text content.
//   • `primitive_number` — `Text(props["value"])` — number content
//                          serialized to a string by SchemaFlattener.
//   • `primitive_null`   — `EmptyView()` — explicit nothing.
//
// Apps that don't want these defaults can ignore the helper; apps
// that want to override one of them should register a custom factory
// AFTER calling `withDefaultPrimitives()` (last-wins per the registry's
// existing contract) — the helper itself preserves any pre-existing
// registration to support the opposite ordering too.

import Foundation
import SwiftUI

extension ComponentRegistry {

    /// Register the joy-dom primitive factories (`div`, `p`,
    /// `primitive_string`, `primitive_number`, `primitive_null`).
    ///
    /// Existing registrations for any of these types are preserved —
    /// the helper only fills in slots that are currently empty, so
    /// callers can register custom primitives first without losing
    /// them when chaining the helper afterward.
    ///
    /// Returns `self` so registrations can be chained fluently:
    /// ```swift
    /// let registry = ComponentRegistry()
    ///     .withDefaultPrimitives()
    ///     .register("button") { props, events in .custom { … } }
    /// ```
    @discardableResult
    public func withDefaultPrimitives() -> ComponentRegistry {
        registerIfAbsent("div") { _, _ in
            // Passthrough — children render through the layout tree.
            // The container itself contributes no visible chrome.
            .custom { EmptyView() }
        }
        registerIfAbsent("p") { _, _ in
            // Same as div for now. Block-flow semantics aren't part
            // of JoyDOMView's flex-only model; `p` is meaningful for
            // selector targeting only.
            .custom { EmptyView() }
        }
        registerIfAbsent("primitive_string") { props, _ in
            let value = props.string("value") ?? ""
            return .custom { Text(value) }
        }
        registerIfAbsent("primitive_number") { props, _ in
            let value = props.string("value") ?? ""
            return .custom { Text(value) }
        }
        registerIfAbsent("primitive_null") { _, _ in
            .custom { EmptyView() }
        }
        return self
    }

    /// Helper: register a factory only when the type isn't already
    /// registered. Lets `withDefaultPrimitives()` preserve user-supplied
    /// factories no matter the chaining order.
    private func registerIfAbsent(
        _ type: String,
        factory: @escaping ComponentFactory
    ) {
        guard self.factory(for: type) == nil else { return }
        register(type, factory: factory)
    }
}
