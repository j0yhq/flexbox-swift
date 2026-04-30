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
import FlexLayout

/// The source the resolver chose for a given node.
public enum Resolution: Equatable {
    /// Matched by id in the `JoyDOMComponentBuilder` locals block.
    case local
    /// Matched by type in the ``ComponentRegistry``.
    case registry
    /// No local or registry match — placeholder rendered.
    case placeholder
}

/// One fully-resolved child, ready for the `FlexBox` to consume.
///
/// Phase 2: children can themselves be containers. When ``nested`` is
/// non-empty the node acts as a flex container — its ``view`` is the
/// factory/local/placeholder output but is only rendered when the node is
/// a leaf (no schema descendants). A container node's visible output is a
/// `FlexLayout(containerStyle) { nested… }`.
public struct ResolvedChild {
    public let id: String
    public let itemStyle: ItemStyle
    public let containerStyle: FlexContainerConfig
    public let resolution: Resolution
    public let view: AnyView
    public let nested: [ResolvedChild]
    /// Mirrors `ComputedStyle.isVisibilityHidden`. When true the render
    /// layer wraps this child in `.hidden()` — the flex slot stays.
    public let isVisibilityHidden: Bool

    /// True iff the node has at least one schema-declared child; such nodes
    /// render as a nested `FlexLayout` wrapping ``nested`` and the factory's
    /// output is dropped (with a diagnostic from the resolver).
    public var isContainer: Bool { !nested.isEmpty }

    public init(
        id: String,
        itemStyle: ItemStyle,
        containerStyle: FlexContainerConfig = FlexContainerConfig(),
        resolution: Resolution,
        view: AnyView,
        nested: [ResolvedChild] = [],
        isVisibilityHidden: Bool = false
    ) {
        self.id = id
        self.itemStyle = itemStyle
        self.containerStyle = containerStyle
        self.resolution = resolution
        self.view = view
        self.nested = nested
        self.isVisibilityHidden = isVisibilityHidden
    }
}

/// Phase 2 resolver: hierarchical root + schema-entry subtrees.
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
    ///   - locals: Inline component overrides from the `JoyDOMComponentBuilder`
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
        eventSink: ((
            _ sourceID: String,
            _ name: String,
            _ payload: [String: String],
            _ propagates: Bool
        ) -> Void)? = nil,
        formState: FormState? = nil,
        valueStore: ValueStore? = nil,
        diagnostics: inout JoyDiagnostics
    ) -> Resolved {
        // Precondition: `StyleTreeBuilder` always emits at least the root.
        let rootNode = nodes.first ?? StyleNode(
            id: "root", schemaType: nil, computedStyle: ComputedStyle()
        )
        let childNodes = nodes.dropFirst()

        // Pre-index locals for O(1) lookup by id. Duplicates resolve to
        // last-wins with a diagnostic so a typo in the author's locals block
        // surfaces instead of crashing the pipeline.
        var localsByID: [String: Component] = [:]
        localsByID.reserveCapacity(locals.count)
        for local in locals {
            if localsByID[local.id] != nil {
                diagnostics.warn(.init(.duplicateLocalID(local.id)))
            }
            localsByID[local.id] = local
        }

        // Per-node leaf data (view + resolution). We resolve each node to a
        // leaf view first, then assemble the tree in a second pass. Doing
        // both in one loop is tempting but complicates the diagnostic for
        // "factory declared on a container node" — we want to fire it only
        // once children have been counted.
        struct Leaf {
            let node: StyleNode
            let resolution: Resolution
            let view: AnyView
        }
        var leafByID: [String: Leaf] = [:]
        leafByID.reserveCapacity(childNodes.count)
        var orderedIDs: [String] = []
        orderedIDs.reserveCapacity(childNodes.count)

        // Identify display:none ancestors up-front so we can skip not just
        // the flagged node itself but its entire subtree. Walking parent
        // pointers once per node is O(depth) in the worst case and happens
        // before any view allocation — much cheaper than running the factory
        // and then throwing the output away.
        var nodeByID: [String: StyleNode] = [:]
        nodeByID.reserveCapacity(childNodes.count)
        for n in childNodes where nodeByID[n.id] == nil { nodeByID[n.id] = n }
        func isHiddenBranch(_ id: String) -> Bool {
            var visited: Set<String> = []
            var cursor: String? = id
            while let cur = cursor, visited.insert(cur).inserted {
                guard let node = nodeByID[cur] else { return false }
                if node.computedStyle.isDisplayNone { return true }
                cursor = node.parentID
            }
            return false
        }

        for node in childNodes {
            if isHiddenBranch(node.id) { continue }

            let resolution: Resolution
            let view: AnyView

            if let local = localsByID[node.id] {
                resolution = .local
                view = local.content
            } else if let type = node.schemaType, let factory = registry.factory(for: type) {
                resolution = .registry
                let props = ComponentProps(node.props, id: node.id)
                let id = node.id
                let nodeProps = node.props
                let sink: ComponentEvents.Sink = { name, payload, propagates in
                    eventSink?(id, name, payload, propagates)
                }
                // Only wire a binding resolver when a FormState is available.
                // Otherwise factories get the dead-binding default, matching
                // the test/preview contract of `ComponentEvents.binding(_:)`.
                let bindings: ComponentEvents.BindingResolver? = formState.map { form in
                    { field in
                        // Field-scoped key wins over the default `binding`
                        // key so one component can bind multiple fields
                        // (e.g. a row that binds both "value" and "checked").
                        let path = nodeProps["binding.\(field)"] ?? nodeProps["binding"]
                        guard let path else { return .constant("") }
                        return Binding(
                            get: { form.get(path) ?? "" },
                            set: { form.set(path, $0) }
                        )
                    }
                }
                // Tier 2: host-agnostic value store plumb-through. When
                // the caller supplied a `valueStore`, every factory's
                // ComponentEvents gets it — enabling setValue / observe
                // for non-SwiftUI bridges that can't speak Binding.
                let events = ComponentEvents(
                    sink: sink,
                    bindings: bindings,
                    values: valueStore
                )
                view = factory(props, events).makeView()
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

            leafByID[node.id] = Leaf(node: node, resolution: resolution, view: view)
            orderedIDs.append(node.id)
        }

        // Group node ids by their effective parent so we can assemble the
        // tree without mutating `leafByID`.
        var childrenByParent: [String: [String]] = [:]
        for id in orderedIDs {
            guard let leaf = leafByID[id] else { continue }
            let parent = leaf.node.parentID ?? rootNode.id
            childrenByParent[parent, default: []].append(id)
        }

        // Recursive assembly: any node with schema descendants becomes a
        // container (its factory view is dropped, with a diagnostic).
        func assemble(id: String) -> ResolvedChild {
            // Precondition: caller only passes ids present in `leafByID`.
            let leaf = leafByID[id]!
            let nested = (childrenByParent[id] ?? []).map { assemble(id: $0) }
            if !nested.isEmpty, leaf.resolution != .placeholder {
                // Author supplied a factory/local for a node that the schema
                // also populates with children. We can't inject children into
                // an opaque AnyView, so the schema wins; warn the author.
                diagnostics.warn(.init(
                    .other,
                    "node '\(id)' has schema children; its \(leaf.resolution) view was dropped in favour of a nested flex container"
                ))
            }
            return ResolvedChild(
                id: id,
                itemStyle: leaf.node.computedStyle.item,
                containerStyle: leaf.node.computedStyle.container,
                resolution: leaf.resolution,
                view: leaf.view,
                nested: nested,
                isVisibilityHidden: leaf.node.computedStyle.isVisibilityHidden
            )
        }

        let topLevel = (childrenByParent[rootNode.id] ?? []).map { assemble(id: $0) }
        return Resolved(rootStyle: rootNode.computedStyle, children: topLevel)
    }
}
