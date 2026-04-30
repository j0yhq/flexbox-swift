// JoyDOMComponentBuilder — the result builder backing `JoyDOMView`'s locals block.
//
// Converts a sequence of `Component(...)` calls into the `[Component]`
// array consumed by `ComponentResolver`. Supports conditionals
// (`if`/`else`) and optional blocks so app code can swap components in and
// out based on runtime state without writing out intermediate arrays.
//
// We deliberately do NOT support `ForEach`/loops in Phase 1 — repeated
// schemas come from the payload, not from the DSL.

import Foundation

/// Result builder for the `JoyDOMView` locals trailing closure.
///
/// ```swift
/// JoyDOMView(payload: payload) {
///     Component("header") { Header() }
///     if showBanner {
///         Component("banner") { Banner() }
///     }
/// }
/// ```
@resultBuilder
public enum JoyDOMComponentBuilder {
    public static func buildBlock(_ parts: [Component]...) -> [Component] {
        parts.flatMap { $0 }
    }

    /// Each `Component(...)` literal inside the closure is promoted to a
    /// single-element array via this expression builder.
    public static func buildExpression(_ component: Component) -> [Component] {
        [component]
    }

    public static func buildExpression(_ components: [Component]) -> [Component] {
        components
    }

    /// `if` without `else` — missing branches yield zero components.
    public static func buildOptional(_ component: [Component]?) -> [Component] {
        component ?? []
    }

    /// `if/else` — first branch.
    public static func buildEither(first: [Component]) -> [Component] {
        first
    }

    /// `if/else` — second branch.
    public static func buildEither(second: [Component]) -> [Component] {
        second
    }
}
