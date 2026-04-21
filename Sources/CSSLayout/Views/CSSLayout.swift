// CSSLayout — the top-level SwiftUI view that renders a `CSSPayload`.
//
// Data flow per `body` evaluation:
//
//   1. `CSSParser.parse`        ──────────► Stylesheet
//   2. `StyleTreeBuilder.build` ──────────► [StyleNode]            (root + children)
//   3. `ComponentResolver.resolve` ───────► ComponentResolver.Resolved
//        • one AnyView per child
//        • a per-child ComponentEvents that fans events into the root sink
//   4. Root sink                ──────────► dispatches to `onEvent` handlers
//   5. Diagnostics              ──────────► forwarded to `onDiagnostic` (if set)
//   6. `FlexLayout`             ──────────► lays out children using `ItemStyle`
//
// Caller-facing knobs are `.onEvent`, `.placeholder`, `.onDiagnostic`. Each
// returns a new `CSSLayout` so chains compose like any SwiftUI modifier.

import Foundation
import SwiftUI
import FlexLayout
import CoreGraphics

/// Renders a CSS payload as a live SwiftUI view tree backed by `FlexLayout`.
///
/// ```swift
/// CSSLayout(
///     payload: CSSPayload(
///         css: "#root { display: flex; gap: 12px; } #a { flex: 1; }",
///         schema: [SchemaEntry(id: "a", type: "text")]
///     )
/// )
/// .onEvent("submit") { event in print("submitted:", event.payload) }
/// ```
public struct CSSLayout: View {

    // MARK: - Stored state

    private let payload: CSSPayload
    private let registry: ComponentRegistry
    private let locals: [Component]

    private var eventHandlers: [String: (CSSEvent) -> Void] = [:]
    private var placeholderFactory: (String) -> AnyView = { AnyView(PlaceholderBox(id: $0)) }
    private var diagnosticHandler: ((CSSWarning) -> Void)?
    private var formStateRef: FormState?

    // MARK: - Initialisers

    /// Primary initialiser.
    ///
    /// - Parameters:
    ///   - payload: The CSS text + schema to render.
    ///   - registry: Component factory registry. Defaults to ``ComponentRegistry/shared``.
    ///   - locals: Inline `Component("id") { … }` overrides (optional).
    public init(
        payload: CSSPayload,
        registry: ComponentRegistry = .shared,
        @CSSLayoutBuilder locals: () -> [Component] = { [] }
    ) {
        self.payload = payload
        self.registry = registry
        self.locals = locals()
    }

    /// Convenience initialiser for CSS-only payloads (typical for previews).
    public init(
        css: String,
        schema: [SchemaEntry] = [],
        registry: ComponentRegistry = .shared,
        @CSSLayoutBuilder _ locals: () -> [Component] = { [] }
    ) {
        self.init(
            payload: CSSPayload(css: css, schema: schema),
            registry: registry,
            locals: locals
        )
    }

    // MARK: - Modifiers

    /// Register a handler for events named `name`. Returns a new view — chain
    /// multiple calls to register for different names.
    ///
    /// Pass `"*"` to register a catch-all that fires for every propagating
    /// event after the named handler (if any). Later calls with the same name
    /// overwrite the earlier handler. Non-propagating events (emitted with
    /// `propagates: false`) bypass both named and wildcard handlers.
    public func onEvent(_ name: String, _ handler: @escaping (CSSEvent) -> Void) -> CSSLayout {
        var copy = self
        copy.eventHandlers[name] = handler
        return copy
    }

    /// Override the default placeholder factory. `id` is the node id that
    /// couldn't be resolved.
    public func placeholder(_ build: @escaping (String) -> AnyView) -> CSSLayout {
        var copy = self
        copy.placeholderFactory = build
        return copy
    }

    /// Register a diagnostic handler. Called once per `CSSWarning` emitted
    /// during parse/cascade/resolve. Useful for surfacing parse errors in
    /// debug builds; intentionally silent by default.
    public func onDiagnostic(_ handler: @escaping (CSSWarning) -> Void) -> CSSLayout {
        var copy = self
        copy.diagnosticHandler = handler
        return copy
    }

    /// Attach a `FormState` so every factory in the tree that declares a
    /// schema `binding` (or `binding.<field>`) prop can read and write its
    /// value live. The caller owns the `FormState` — state survives payload
    /// hot-swaps and is pruned to the paths the current schema declares on
    /// every render, so stale values don't accumulate across fetches.
    public func formState(_ form: FormState) -> CSSLayout {
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
        var diagnostics = CSSDiagnostics()
        let stylesheet = CSSParser.parse(payload.css, diagnostics: &diagnostics)
        let nodes = StyleTreeBuilder.build(
            rootID: "root",
            schema: payload.schema,
            stylesheet: stylesheet,
            diagnostics: &diagnostics
        )

        // Capture the handler map locally so the event sink closure doesn't
        // need to retain `self`.
        let handlers = eventHandlers
        // Bubble-path plumbing: look up each node's parent to walk ancestors,
        // and every local's handlers so `.onCSSEvent` can fire during bubble.
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
        let rootID = "root"
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
                let event = CSSEvent(
                    name: name,
                    sourceID: sourceID,
                    payload: payload,
                    propagates: propagates
                )
                // Bubble phase: visit source first, then each ancestor up to
                // (but excluding) the root. Each local along the way may
                // carry a matching `.onCSSEvent` handler. A non-propagating
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
