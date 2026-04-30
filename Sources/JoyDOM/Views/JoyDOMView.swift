// JoyDOMView — the top-level SwiftUI view that renders a `Spec`.
//
// Data flow per `body` evaluation:
//
//   1. `BreakpointResolver.active` ──────► active Breakpoint (or nil)
//   2. `RuleBuilder.buildRules`    ──────► [StyleResolver.Rule]
//   3. `StyleTreeBuilder.build`    ──────► [StyleNode]
//   4. `ComponentResolver.resolve` ──────► ComponentResolver.Resolved
//        • one AnyView per child
//        • a per-child ComponentEvents that fans events into the root sink
//   5. Root sink                   ──────► dispatches to `onEvent` handlers
//   6. Diagnostics                 ──────► forwarded to `onDiagnostic`
//   7. `FlexLayout`                ──────► lays out children using `ItemStyle`
//
// Caller-facing knobs: `.onEvent`, `.placeholder`, `.onDiagnostic`,
// `.viewport`, `.formState`, `.bindings`. Each returns a new
// `JoyDOMView` so chains compose like any SwiftUI modifier.

import Foundation
import SwiftUI
import FlexLayout
import CoreGraphics

/// Renders a `Spec` as a live SwiftUI view tree backed by `FlexLayout`.
///
/// ```swift
/// JoyDOMView(spec: spec)
///     .joyViewport(.init(width: 1024))
///     .onEvent("submit") { event in print("submitted:", event.payload) }
/// ```
///
/// Pass a `Viewport` via `.joyViewport(_:)` so breakpoint resolution can
/// pick the active breakpoint. Without one, only the document-level styles
/// apply.
public struct JoyDOMView: View {

    // MARK: - Stored state

    private let spec: Spec
    private let registry: ComponentRegistry
    private let locals: [Component]

    private var eventHandlers: [String: (JoyEvent) -> Void] = [:]
    private var placeholderFactory: (String) -> AnyView = { AnyView(PlaceholderBox(id: $0)) }
    private var diagnosticHandler: ((JoyWarning) -> Void)?
    private var formStateRef: FormState?
    /// Viewport supplied via `.viewport(_:)`. Drives breakpoint
    /// resolution. Demos typically wire this to `GeometryReader`'s
    /// width; tests construct viewports directly.
    private var storedViewport: Viewport?
    /// Sidecar binding map declared via `.bindings(_:)`. Keys are
    /// `Node.props.id` values; values are FormState dotted paths.
    /// Empty by default — joy-dom payloads stay pure (no iOS-specific
    /// binding tokens leak into the wire format).
    private var bindingsByID: [String: String] = [:]

    // MARK: - Initialisers

    /// Render a `Spec`.
    ///
    /// - Parameters:
    ///   - spec: The joy-dom document to render.
    ///   - registry: Component factory registry. Defaults to ``ComponentRegistry/shared``.
    ///   - locals: Inline `Component("id") { … }` overrides (optional).
    public init(
        spec: Spec,
        registry: ComponentRegistry = .shared,
        @JoyDOMComponentBuilder locals: () -> [Component] = { [] }
    ) {
        self.spec = spec
        self.registry = registry
        self.locals = locals()
    }

    // MARK: - Modifiers

    /// Register a handler for events named `name`. Returns a new view — chain
    /// multiple calls to register for different names.
    ///
    /// Pass `"*"` to register a catch-all that fires for every propagating
    /// event after the named handler (if any). Later calls with the same name
    /// overwrite the earlier handler. Non-propagating events (emitted with
    /// `propagates: false`) bypass both named and wildcard handlers.
    public func onEvent(_ name: String, _ handler: @escaping (JoyEvent) -> Void) -> JoyDOMView {
        var copy = self
        copy.eventHandlers[name] = handler
        return copy
    }

    /// Override the default placeholder factory. `id` is the node id that
    /// couldn't be resolved.
    public func placeholder(_ build: @escaping (String) -> AnyView) -> JoyDOMView {
        var copy = self
        copy.placeholderFactory = build
        return copy
    }

    /// Register a diagnostic handler. Called once per `JoyWarning` emitted
    /// during parse/cascade/resolve. Useful for surfacing parse errors in
    /// debug builds; intentionally silent by default.
    public func onDiagnostic(_ handler: @escaping (JoyWarning) -> Void) -> JoyDOMView {
        var copy = self
        copy.diagnosticHandler = handler
        return copy
    }

    /// Override the viewport used for breakpoint resolution. When unset
    /// (or set to `nil`), no breakpoint applies and the document-level
    /// styles render unchanged. Demos typically wrap JoyDOMView in a
    /// `GeometryReader` and feed `proxy.size.width` here.
    public func viewport(_ viewport: Viewport?) -> JoyDOMView {
        var copy = self
        copy.storedViewport = viewport
        return copy
    }

    /// Declare the FormState path each node id binds to.
    ///
    /// Joy-dom payloads carry no iOS-specific binding tokens — that's
    /// the spec's "pre-resolved values" stance. iOS hosts that want
    /// live two-way binding wire it up here, declaratively, at the
    /// SwiftUI surface:
    ///
    /// ```swift
    /// JoyDOMView(spec: spec)
    ///     .formState(form)
    ///     .bindings([
    ///         "name-field":  "user.name",
    ///         "email-field": "user.email",
    ///     ])
    /// ```
    ///
    /// Calling `.bindings(_:)` more than once merges the maps — later
    /// calls win on conflicting keys.
    public func bindings(_ map: [String: String]) -> JoyDOMView {
        var copy = self
        for (id, path) in map {
            copy.bindingsByID[id] = path
        }
        return copy
    }

    /// Attach a `FormState` so every factory in the tree that declares a
    /// schema `binding` (or `binding.<field>`) prop can read and write its
    /// value live. The caller owns the `FormState` — state survives payload
    /// hot-swaps and is pruned to the paths the current schema declares on
    /// every render, so stale values don't accumulate across fetches.
    public func formState(_ form: FormState) -> JoyDOMView {
        var copy = self
        copy.formStateRef = form
        return copy
    }

    // MARK: - Body

    /// Identifiable pair used by `ForEach` so the child index provides stable
    /// identity without requiring `ResolvedChild` itself to be `Identifiable`
    /// (child ids are non-unique across subtrees during Phase 2 development).
    private struct IndexedChild: Identifiable {
        let offset: Int
        let child: ResolvedChild
        var id: Int { offset }
    }

    public var body: some View {
        let snapshot = renderSnapshot()
        return FlexLayout(snapshot.rootStyle.container) {
            childrenView(snapshot.children)
        }
        .flexOverflow(snapshot.rootStyle.container.overflow)
    }

    /// Build the `ForEach` over one level of resolved children. Separated so
    /// the recursive case in `render(_:)` doesn't have to reason about the
    /// `@ViewBuilder` closure types.
    private func childrenView(_ children: [ResolvedChild]) -> some View {
        let pairs = Array(children.enumerated()).map { IndexedChild(offset: $0.offset, child: $0.element) }
        return ForEach(pairs) { pair in
            self.render(pair.child)
        }
    }

    /// Render a single resolved child. Leaves use the factory's view; nodes
    /// with schema descendants wrap their children in a nested `FlexLayout`
    /// so container geometry (direction, gap, padding, justify/align) takes
    /// effect exactly where the schema declares it.
    private func render(_ child: ResolvedChild) -> AnyView {
        let rawView: AnyView
        if child.isContainer {
            let nested = child.nested
            let inner = FlexLayout(child.containerStyle) {
                self.childrenView(nested)
            }
            .flexOverflow(child.containerStyle.overflow)
            rawView = AnyView(inner)
        } else {
            rawView = child.view
        }
        // `visibility: hidden` keeps the flex slot and only suppresses the
        // paint — apply `.hidden()` *before* `.flexItem(...)` so layout
        // still sees the natural size of the underlying view.
        let maybeHidden: AnyView = child.isVisibilityHidden
            ? AnyView(rawView.hidden())
            : rawView
        return AnyView(applyItem(maybeHidden, style: child.itemStyle))
    }

    // MARK: - Rendering helpers

    /// Runs the full parse → cascade → resolve pipeline once.
    ///
    /// Separated from `body` so test helpers can exercise the full flow by
    /// simply reading `body`, yet the resolver's factories only run once per
    /// evaluation.
    private func renderSnapshot() -> ComponentResolver.Resolved {
        var diagnostics = JoyDiagnostics()

        // Pick the active breakpoint for the current viewport (if any).
        let activeBreakpoint = storedViewport.flatMap {
            BreakpointResolver.active(in: $0, breakpoints: spec.breakpoints)
        }

        // Build the cascade rule list and the per-node className overrides
        // the active breakpoint declares.
        let rules = RuleBuilder.buildRules(
            from: spec,
            activeBreakpoint: activeBreakpoint,
            diagnostics: &diagnostics
        )
        var classNameOverrides: [String: [String]] = [:]
        if let bp = activeBreakpoint {
            for (id, props) in bp.nodes {
                if let classes = props.className {
                    classNameOverrides[id] = classes
                }
            }
        }

        // Walk the tree.
        let nodes = StyleTreeBuilder.build(
            layout: spec.layout,
            rootID: "__joydom_root__",
            rules: rules,
            classNameOverrides: classNameOverrides,
            bindingsByID: bindingsByID,
            diagnostics: &diagnostics
        )

        // Capture the handler map locally so the event sink closure doesn't
        // need to retain `self`.
        let handlers = eventHandlers
        // Bubble-path plumbing: look up each node's parent to walk ancestors,
        // and every local's handlers so `.onJoyEvent` can fire during bubble.
        // Both dictionaries use a tolerant init (`[key] = value` in a loop)
        // so adversarial payloads with duplicate ids never hard-crash.
        var parentByID: [String: String?] = [:]
        parentByID.reserveCapacity(nodes.count)
        for n in nodes where parentByID[n.id] == nil {
            parentByID[n.id] = n.parentID
        }
        var localsByID: [String: Component] = [:]
        localsByID.reserveCapacity(locals.count)
        for l in locals { localsByID[l.id] = l }
        let rootID = "__joydom_root__"
        // Prune FormState to the binding paths the current schema
        // declares *before* handing it to the resolver. Done up front so
        // a factory that reads its binding during its initial render
        // can't observe a stale value from a previous payload that
        // happened to reuse a now-dropped path key.
        if let form = formStateRef {
            var keep: Set<String> = []
            for n in nodes {
                for (key, value) in n.props {
                    if key == "binding" || key.hasPrefix("binding.") {
                        keep.insert(value)
                    }
                }
            }
            form.prune(keeping: keep)
        }
        let resolved = ComponentResolver.resolve(
            nodes: nodes,
            locals: locals,
            registry: registry,
            placeholder: placeholderFactory,
            eventSink: { sourceID, name, payload, propagates in
                let event = JoyEvent(
                    name: name,
                    sourceID: sourceID,
                    payload: payload,
                    propagates: propagates
                )
                // Bubble phase: visit source first, then each ancestor up to
                // (but excluding) the root. Each local along the way may
                // carry a matching `.onJoyEvent` handler. A non-propagating
                // event only fires at the target.
                var cursor: String? = sourceID
                var visited: Set<String> = []
                while let id = cursor, id != rootID, visited.insert(id).inserted {
                    if let local = localsByID[id],
                       let handler = local.handlers[name] {
                        handler(event)
                    }
                    if !propagates { break }
                    cursor = parentByID[id] ?? nil
                }
                // Root handlers are the terminal stop of the bubble phase.
                if propagates {
                    handlers[name]?(event)
                    // Wildcard fires after the named handler so specific
                    // logic (which may modify state) runs before the sniffer.
                    if name != "*" { handlers["*"]?(event) }
                }
            },
            formState: formStateRef,
            diagnostics: &diagnostics
        )

        if let sink = diagnosticHandler {
            for warning in diagnostics.warnings { sink(warning) }
        }
        return resolved
    }

    /// Wraps one resolved child with the `.flexItem(...)` modifier carrying
    /// every CSS item property. Extracted so `body` stays focused on layout
    /// assembly.
    private func applyItem(_ view: AnyView, style: ItemStyle) -> some View {
        view.flexItem(
            grow:      style.grow,
            shrink:    style.shrink,
            basis:     style.basis,
            alignSelf: style.alignSelf,
            order:     style.order,
            width:     style.width,
            height:    style.height,
            overflow:  style.overflow,
            zIndex:    style.zIndex,
            position:  style.position,
            top:       style.top,
            bottom:    style.bottom,
            leading:   style.leading,
            trailing:  style.trailing
        )
    }
}
