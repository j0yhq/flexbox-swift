// FormStateDemo — Phase 3 end-to-end showcase.
//
// Demonstrates the three Phase 3 additions working together:
//
//   1. `FormState` — an `ObservableObject` the demo owns and injects via
//      `.formState(_:)`. Factories read/write fields through
//      `events.binding("value")`; the demo never has to know which
//      field belongs to which screen.
//
//   2. State-preserving hot-swap — toggling between two CSS/schema
//      payloads replaces the view tree without clearing the form.
//      Fields that exist in both payloads keep their values; fields
//      unique to the previous payload are pruned.
//
//   3. `CSSPayloadCache` — a tiny LRU keyed by a version string that
//      stands in for the server's ETag. The cache hit counter below
//      the form ticks up when the same payload is shown twice — no
//      re-parse on the second mount.
//
// The factories live in a local `ComponentRegistry` so this screen
// can't leak into the shared singleton. Everything here is pure
// CSSLayout + SwiftUI; no imperative layout code.

import SwiftUI
import CSSLayout

struct FormStateDemo: View {

    // MARK: - Owned state

    /// Survives payload swaps; that's the whole point.
    @StateObject private var form = FormState(values: [
        "user.name":  "",
        "user.email": "",
    ])

    /// Actor-isolated cache of "server" payloads. Keyed by the version
    /// string the demo knows (could be an ETag in a real app).
    ///
    /// Must be `@State`, not `let`: a SwiftUI `View` is a value type and
    /// gets reconstructed on every parent re-render. A plain `let cache`
    /// would rebuild a fresh empty cache on each reconstruction,
    /// defeating the whole point of the demo — hits would never
    /// accumulate. `@State` parks the actor reference in SwiftUI's
    /// per-view storage so it survives across View-struct rebuilds.
    @State private var cache = CSSPayloadCache(capacity: 4)

    @State private var activeVersion: String = "v1-compact"
    @State private var currentPayload: CSSPayload = FormStateDemo.compactPayload
    @State private var cacheHits: Int = 0
    @State private var cacheMisses: Int = 0

    // MARK: - Body

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                header
                versionPicker
                Divider()
                formCanvas
                debugPanel
            }
            .padding(24)
            .frame(maxWidth: 620, alignment: .leading)
        }
        .task { await prime() }
    }

    // MARK: - Sub-views

    private var header: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("FormState + Hot-Swap + Cache")
                .font(.title2.weight(.semibold))
            Text(
                "Two server-style CSS payloads share one FormState. "
                + "Switching payloads preserves overlapping fields and "
                + "prunes the rest. The LRU cache avoids re-parsing the "
                + "same CSS twice."
            )
            .font(.subheadline)
            .foregroundStyle(.secondary)
        }
    }

    private var versionPicker: some View {
        HStack(spacing: 12) {
            Picker("Payload", selection: $activeVersion) {
                Text("v1 · compact (name + email)").tag("v1-compact")
                Text("v2 · extended (+ phone, role)").tag("v2-extended")
            }
            .pickerStyle(.segmented)
            .onChange(of: activeVersion) { newValue in
                Task { await load(version: newValue) }
            }
        }
    }

    private var formCanvas: some View {
        CSSLayout(payload: currentPayload, registry: registry)
            .formState(form)
            .onEvent("submit") { _ in
                print("🎯 submit →", form.snapshot())
            }
            .frame(maxWidth: .infinity, minHeight: 220, alignment: .topLeading)
            .padding(12)
            .background(Color(white: 0.96))
            .clipShape(RoundedRectangle(cornerRadius: 10))
            .overlay(
                RoundedRectangle(cornerRadius: 10)
                    .strokeBorder(Color.gray.opacity(0.25))
            )
    }

    private var debugPanel: some View {
        VStack(alignment: .leading, spacing: 12) {
            GroupBox("FormState snapshot") {
                VStack(alignment: .leading, spacing: 3) {
                    ForEach(form.snapshot().sorted(by: { $0.key < $1.key }), id: \.key) { k, v in
                        HStack {
                            Text(k)
                                .font(.system(.caption, design: .monospaced))
                                .foregroundStyle(.secondary)
                            Spacer()
                            Text(v.isEmpty ? "—" : v)
                                .font(.system(.caption, design: .monospaced))
                        }
                    }
                    if form.snapshot().isEmpty {
                        Text("(no fields)")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
                .padding(6)
                .frame(maxWidth: .infinity, alignment: .leading)
            }

            GroupBox("CSSPayloadCache") {
                HStack(spacing: 24) {
                    cacheStat("hits",   value: cacheHits,   color: .green)
                    cacheStat("misses", value: cacheMisses, color: .orange)
                    Spacer()
                    Button("Clear cache") {
                        Task {
                            await cache.clear()
                            cacheHits = 0
                            cacheMisses = 0
                        }
                    }
                    .buttonStyle(.bordered)
                }
                .padding(6)
            }
        }
    }

    private func cacheStat(_ label: String, value: Int, color: Color) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(label).font(.caption).foregroundStyle(.secondary)
            Text("\(value)")
                .font(.title3.weight(.semibold))
                .foregroundStyle(color)
        }
    }

    // MARK: - Cache-backed payload loading

    private func prime() async {
        // Seed the cache with v1 so the very first render is a hit.
        if await cache.get(activeVersion) == nil {
            await cache.put(activeVersion, currentPayload)
            cacheMisses += 1
        }
    }

    private func load(version: String) async {
        if let cached = await cache.get(version) {
            currentPayload = cached
            cacheHits += 1
            return
        }
        let freshlyFetched = Self.payload(for: version)
        await cache.put(version, freshlyFetched)
        currentPayload = freshlyFetched
        cacheMisses += 1
    }

    // MARK: - "Server" payloads

    private static func payload(for version: String) -> CSSPayload {
        switch version {
        case "v2-extended": return extendedPayload
        default:            return compactPayload
        }
    }

    private static let compactPayload = CSSPayload(
        css: """
        #root {
            display: flex;
            flex-direction: column;
            gap: 14px;
            padding: 16px;
        }
        #heading { height: 30px; }
        #name    { height: 32px; }
        #email   { height: 32px; }
        #submit  { height: 38px; }
        """,
        schema: [
            SchemaEntry(id: "heading", type: "heading",
                        props: ["text": "Compact signup"]),
            SchemaEntry(id: "name",    type: "text-field",
                        props: ["binding": "user.name",
                                "placeholder": "Full name"]),
            SchemaEntry(id: "email",   type: "text-field",
                        props: ["binding": "user.email",
                                "placeholder": "Email address"]),
            SchemaEntry(id: "submit",  type: "submit-button",
                        props: ["text": "Sign up"]),
        ]
    )

    private static let extendedPayload = CSSPayload(
        css: """
        #root {
            display: flex;
            flex-direction: column;
            gap: 12px;
            padding: 16px;
        }
        #heading { height: 30px; }
        .pair {
            display: flex;
            flex-direction: row;
            gap: 10px;
        }
        #name    { flex: 1; height: 32px; }
        #email   { flex: 1; height: 32px; }
        #phone   { flex: 1; height: 32px; }
        #role    { flex: 1; height: 32px; }
        #submit  { height: 38px; }
        """,
        schema: [
            SchemaEntry(id: "heading", type: "heading",
                        props: ["text": "Extended signup"]),
            SchemaEntry(id: "row-1", classes: ["pair"]),
            SchemaEntry(id: "name",    type: "text-field",
                        parentID: "row-1",
                        props: ["binding": "user.name",
                                "placeholder": "Full name"]),
            SchemaEntry(id: "email",   type: "text-field",
                        parentID: "row-1",
                        props: ["binding": "user.email",
                                "placeholder": "Email address"]),
            SchemaEntry(id: "row-2", classes: ["pair"]),
            SchemaEntry(id: "phone",   type: "text-field",
                        parentID: "row-2",
                        props: ["binding": "user.phone",
                                "placeholder": "Phone"]),
            SchemaEntry(id: "role",    type: "text-field",
                        parentID: "row-2",
                        props: ["binding": "user.role",
                                "placeholder": "Role"]),
            SchemaEntry(id: "submit",  type: "submit-button",
                        props: ["text": "Create account"]),
        ]
    )

    // MARK: - Registry

    /// Local registry — factories use the Phase 3 `events.binding(_:)`
    /// escape hatch so the demo view never has to thread bindings
    /// down manually.
    private var registry: ComponentRegistry {
        let r = ComponentRegistry()
        r.register("heading") { props, _ in
            AnyView(
                Text(props.string("text") ?? "")
                    .font(.title3.weight(.semibold))
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .accessibilityIdentifier(props.id)
            )
        }
        r.register("text-field") { props, events in
            AnyView(
                BoundTextField(
                    placeholder: props.string("placeholder") ?? "",
                    text: events.binding("value")
                )
                .accessibilityIdentifier(props.id)
            )
        }
        r.register("submit-button") { props, events in
            AnyView(
                Button(props.string("text") ?? "Submit") {
                    events.emit("submit", payload: [:])
                }
                .buttonStyle(.borderedProminent)
                .frame(maxWidth: .infinity)
                .accessibilityIdentifier(props.id)
            )
        }
        return r
    }
}

// MARK: - Text field wrapper

/// A plain `TextField` that reads and writes through a SwiftUI
/// `Binding<String>`. The factory passes the binding produced by
/// `ComponentEvents.binding("value")`, so the field edits land in
/// FormState without the view layer seeing FormState directly.
private struct BoundTextField: View {
    let placeholder: String
    @Binding var text: String

    var body: some View {
        TextField(placeholder, text: $text)
            .textFieldStyle(.roundedBorder)
            .frame(maxWidth: .infinity)
    }
}
