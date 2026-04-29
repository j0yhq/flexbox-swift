// DefaultPrimitives — `ComponentRegistry.withDefaultPrimitives()` adds
// factories for the joy-dom primitives every renderer needs:
//
//   • `div`              — passthrough container (children compose
//                          through the layout tree).
//   • `p`                — paragraph; children render through the
//                          layout tree exactly like `div`. Block-flow
//                          semantics aren't represented in flex-only
//                          CSSLayout, so `p` and `div` differ only by
//                          element type for selector purposes.
//   • `primitive_string` — `Text(props["value"])` — text content.
//   • `primitive_number` — `Text(props["value"])` — number content
//                          serialized to a string by SchemaFlattener.
//   • `primitive_null`   — `EmptyView()` — explicit nothing.
//
// Apps that don't want these defaults can ignore the helper; apps
// that want to override one of them should call
// `withDefaultPrimitives()` first and then `register(_:factory:)`
// with the type they want to replace (last-wins, matching the
// existing registry contract).

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
        // RED stub — replaced in Unit 9 GREEN.
        return self
    }
}
