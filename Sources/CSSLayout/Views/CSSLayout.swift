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
    /// Phase 1: no `"*"` catch-all, no event bubbling. Only the exact name
    /// matches. Later calls with the same name overwrite the earlier handler.
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

    // MARK: - Body

    public var body: some View {
        let snapshot = renderSnapshot()
        return FlexLayout(snapshot.rootStyle.container) {
            ForEach(Array(snapshot.children.enumerated()), id: \.offset) { _, child in
                applyItem(child.view, style: child.itemStyle)
            }
        }
        .flexOverflow(snapshot.rootStyle.container.overflow)
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
        let resolved = ComponentResolver.resolve(
            nodes: nodes,
            locals: locals,
            registry: registry,
            placeholder: placeholderFactory,
            eventSink: { sourceID, name, payload in
                let event = CSSEvent(name: name, sourceID: sourceID, payload: payload)
                handlers[name]?(event)
            },
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
