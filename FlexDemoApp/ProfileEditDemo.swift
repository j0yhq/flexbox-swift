// ProfileEditDemo — Phase 3 server-driven screen #2.
//
// Angle: **layout-agnostic state**. The two CSS payloads drive the *same*
// four fields (full name, email, bio, website) but arrange them very
// differently. Typing into the stacked layout and then switching to the
// two-column pair layout proves that FormState values survive a
// structural re-render, not just a cosmetic one.
//
// Contrast with FormStateDemo, which swaps between payloads whose
// schemas differ (compact vs extended). Here the schema IDs and
// bindings are identical across payloads; only the CSS changes. This
// isolates the "state continuity under structural hot-swap" guarantee
// from the "pruning orphan paths" guarantee FormStateDemo showcases.

import SwiftUI
import CSSLayout

struct ProfileEditDemo: View {

    // MARK: - Owned state

    @StateObject private var form = FormState(values: [
        "profile.name":    "",
        "profile.email":   "",
        "profile.bio":     "",
        "profile.website": "",
    ])

    /// See FormStateDemo for why this must be `@State` and not `let`:
    /// SwiftUI Views are value types rebuilt on parent re-render, so a
    /// plain `let cache = …` would reset on every redraw.
    @State private var cache = CSSPayloadCache(capacity: 4)

    @State private var activeLayout: String = "stacked"
    @State private var currentPayload: CSSPayload = ProfileEditDemo.stackedPayload
    @State private var cacheHits: Int = 0
    @State private var cacheMisses: Int = 0

    // MARK: - Body

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                header
                layoutPicker
                Divider()
                formCanvas
                debugPanel
            }
            .padding(24)
            .frame(maxWidth: 640, alignment: .leading)
        }
        .task { await prime() }
    }

    // MARK: - Sub-views

    private var header: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("Layout-Agnostic FormState")
                .font(.title2.weight(.semibold))
            Text(
                "Two CSS payloads drive the same four-field profile "
                + "form. Type anything, switch layouts, and the values "
                + "survive — only the arrangement changes. The schema "
                + "IDs and binding paths are identical across payloads."
            )
            .font(.subheadline)
            .foregroundStyle(.secondary)
        }
    }

    private var layoutPicker: some View {
        HStack(spacing: 12) {
            Picker("Layout", selection: $activeLayout) {
                Text("Stacked · single column").tag("stacked")
                Text("Paired · two columns").tag("paired")
            }
            .pickerStyle(.segmented)
            .onChange(of: activeLayout) { newValue in
                Task { await load(layout: newValue) }
            }
        }
    }

    private var formCanvas: some View {
        CSSLayout(payload: currentPayload, registry: registry)
            .formState(form)
            .onEvent("save") { _ in
                print("💾 save →", form.snapshot())
            }
            .frame(maxWidth: .infinity, minHeight: 280, alignment: .topLeading)
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
            GroupBox("FormState snapshot · persists across layout swaps") {
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
                }
                .padding(6)
                .frame(maxWidth: .infinity, alignment: .leading)
            }

            GroupBox("CSSPayloadCache") {
                HStack(spacing: 24) {
                    stat("hits",   value: cacheHits,   color: .green)
                    stat("misses", value: cacheMisses, color: .orange)
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

    private func stat(_ label: String, value: Int, color: Color) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(label).font(.caption).foregroundStyle(.secondary)
            Text("\(value)")
                .font(.title3.weight(.semibold))
                .foregroundStyle(color)
        }
    }

    // MARK: - Cache-backed payload loading

    private func prime() async {
        if await cache.get(activeLayout) == nil {
            await cache.put(activeLayout, currentPayload)
            cacheMisses += 1
        }
    }

    private func load(layout: String) async {
        if let cached = await cache.get(layout) {
            currentPayload = cached
            cacheHits += 1
            return
        }
        let fresh = Self.payload(for: layout)
        await cache.put(layout, fresh)
        currentPayload = fresh
        cacheMisses += 1
    }

    // MARK: - "Server" payloads (same schema, different CSS)

    private static func payload(for layout: String) -> CSSPayload {
        switch layout {
        case "paired": return pairedPayload
        default:       return stackedPayload
        }
    }

    /// Shared schema — identical IDs and bindings across both layouts.
    /// `parentID` differs between payloads; that's what lets CSS
    /// re-arrange the same fields into different container structures.
    private static let sharedFields: [(id: String, binding: String, placeholder: String)] = [
        ("name",    "profile.name",    "Full name"),
        ("email",   "profile.email",   "Email address"),
        ("bio",     "profile.bio",     "Short bio"),
        ("website", "profile.website", "Website URL"),
    ]

    private static let stackedPayload = CSSPayload(
        css: """
        #root {
            display: flex;
            flex-direction: column;
            gap: 12px;
            padding: 16px;
        }
        #heading { height: 30px; }
        #name, #email, #bio, #website { height: 32px; }
        #save { height: 38px; }
        """,
        schema: [
            SchemaEntry(id: "heading", type: "heading",
                        props: ["text": "Edit profile"]),
            SchemaEntry(id: "name",    type: "text-field",
                        props: ["binding": "profile.name",
                                "placeholder": "Full name"]),
            SchemaEntry(id: "email",   type: "text-field",
                        props: ["binding": "profile.email",
                                "placeholder": "Email address"]),
            SchemaEntry(id: "bio",     type: "text-field",
                        props: ["binding": "profile.bio",
                                "placeholder": "Short bio"]),
            SchemaEntry(id: "website", type: "text-field",
                        props: ["binding": "profile.website",
                                "placeholder": "Website URL"]),
            SchemaEntry(id: "save",    type: "save-button",
                        props: ["text": "Save profile"]),
        ]
    )

    private static let pairedPayload = CSSPayload(
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
            gap: 12px;
        }
        #name, #email, #bio, #website { flex: 1; height: 32px; }
        #save { height: 38px; }
        """,
        schema: [
            SchemaEntry(id: "heading", type: "heading",
                        props: ["text": "Edit profile — paired layout"]),
            SchemaEntry(id: "row-1", classes: ["pair"]),
            SchemaEntry(id: "name",    type: "text-field",
                        parentID: "row-1",
                        props: ["binding": "profile.name",
                                "placeholder": "Full name"]),
            SchemaEntry(id: "email",   type: "text-field",
                        parentID: "row-1",
                        props: ["binding": "profile.email",
                                "placeholder": "Email address"]),
            SchemaEntry(id: "row-2", classes: ["pair"]),
            SchemaEntry(id: "bio",     type: "text-field",
                        parentID: "row-2",
                        props: ["binding": "profile.bio",
                                "placeholder": "Short bio"]),
            SchemaEntry(id: "website", type: "text-field",
                        parentID: "row-2",
                        props: ["binding": "profile.website",
                                "placeholder": "Website URL"]),
            SchemaEntry(id: "save",    type: "save-button",
                        props: ["text": "Save profile"]),
        ]
    )

    // MARK: - Registry

    private var registry: ComponentRegistry {
        let r = ComponentRegistry()
        r.register("heading") { props, _ in
            .custom {
                Text(props.string("text") ?? "")
                    .font(.title3.weight(.semibold))
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .accessibilityIdentifier(props.id)
            }
        }
        r.register("text-field") { props, events in
            .custom {
                ProfileBoundField(
                    placeholder: props.string("placeholder") ?? "",
                    text: events.binding("value")
                )
                .accessibilityIdentifier(props.id)
            }
        }
        r.register("save-button") { props, events in
            .custom {
                Button(props.string("text") ?? "Save") {
                    events.emit("save", payload: [:])
                }
                .buttonStyle(.borderedProminent)
                .frame(maxWidth: .infinity)
                .accessibilityIdentifier(props.id)
            }
        }
        return r
    }
}

// MARK: - Text field wrapper

private struct ProfileBoundField: View {
    let placeholder: String
    @Binding var text: String

    var body: some View {
        TextField(placeholder, text: $text)
            .textFieldStyle(.roundedBorder)
            .frame(maxWidth: .infinity)
    }
}
