// ComponentResolver — picks the right view source for every node.
//
// Phase 1 lookup priority:
//   1. `locals[id]`           — inline `Component("id") { … }` overrides
//   2. `registry[schemaType]` — the package-wide component factory table
//   3. `placeholder(id)`      — caller-supplied fallback (default =
//                               `PlaceholderBox` in debug, empty in release)
//
// The resolver returns structured `ResolvedChild` values carrying the
// chosen `Resolution` tag so tests and debug logging can see which branch
// fired without inspecting the opaque SwiftUI view.

import Foundation
import SwiftUI

/// The source the resolver chose for a given node.
public enum Resolution: Equatable {
    /// Matched by id in the `CSSLayoutBuilder` locals block.
    case local
    /// Matched by type in the ``ComponentRegistry``.
    case registry
    /// No local or registry match — placeholder rendered.
    case placeholder
}

/// One fully-resolved child, ready for the `FlexBox` to consume.
public struct ResolvedChild {
    public let id: String
    public let itemStyle: ItemStyle
    public let resolution: Resolution
    public let view: AnyView
}

/// Phase 1 resolver: flat root + schema-entry siblings.
public enum ComponentResolver {

    /// Grouped return value for `resolve`.
    public struct Resolved {
        /// The root container's computed style (extracted from the first
        /// node; used by the surrounding `FlexBox`).
        public let rootStyle: ComputedStyle
        /// One entry per non-root node, in the style tree's order.
        public let children: [ResolvedChild]
    }

    /// Resolve every node to a `ResolvedChild`.
    ///
    /// - Parameters:
    ///   - nodes: The `StyleTreeBuilder` output. The first node is always
    ///     treated as root.
    ///   - locals: Inline component overrides from the `CSSLayoutBuilder`
    ///     trailing closure.
    ///   - registry: The active component registry.
    ///   - placeholder: Factory invoked for unresolved nodes (unknown id or
    ///     unregistered type).
    ///   - eventSink: Optional root-level sink that receives every event
    ///     emitted by a child factory, tagged with the source node id. The
    ///     resolver builds a per-child ``ComponentEvents`` that forwards to
    ///     this sink — so factories don't need to know their own id.
    ///   - diagnostics: Warnings accumulator — unregistered-type misses and
    ///     unknown-id fallbacks both append.
    public static func resolve(
        nodes: [StyleNode],
        locals: [Component],
        registry: ComponentRegistry,
        placeholder: (String) -> AnyView,
        eventSink: ((_ sourceID: String, _ name: String, _ payload: [String: String]) -> Void)? = nil,
        diagnostics: inout CSSDiagnostics
    ) -> Resolved {
        // Precondition: `StyleTreeBuilder` always emits at least the root.
        let rootNode = nodes.first ?? StyleNode(
            id: "root", schemaType: nil, computedStyle: ComputedStyle()
        )
        let childNodes = nodes.dropFirst()

        // Pre-index locals for O(1) lookup by id.
        let localsByID: [String: Component] = Dictionary(
            uniqueKeysWithValues: locals.map { ($0.id, $0) }
        )

        var resolved: [ResolvedChild] = []
        resolved.reserveCapacity(childNodes.count)

        for node in childNodes {
            let resolution: Resolution
            let view: AnyView

            if let local = localsByID[node.id] {
                resolution = .local
                view = local.content
            } else if let type = node.schemaType, let factory = registry.factory(for: type) {
                resolution = .registry
                let props = ComponentProps([:], id: node.id)
                let id = node.id
                let events = ComponentEvents { name, payload in
                    eventSink?(id, name, payload)
                }
                view = factory(props, events)
            } else {
                resolution = .placeholder
                // Only diagnose when the schema names a type we can't find —
                // unknown ids with no type are legitimately "caller didn't
                // supply a factory yet".
                if let type = node.schemaType {
                    diagnostics.warn(.init(
                        .other,
                        "no factory registered for type '\(type)' (id '\(node.id)')"
                    ))
                }
                view = placeholder(node.id)
            }

            resolved.append(ResolvedChild(
                id: node.id,
                itemStyle: node.computedStyle.item,
                resolution: resolution,
                view: view
            ))
        }

        return Resolved(rootStyle: rootNode.computedStyle, children: resolved)
    }
}
