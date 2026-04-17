// CSSLayoutDemo — end-to-end smoke demo for the `CSSLayout` package.
//
// Renders a 10-field signup form *from CSS + schema only*, backed by a
// tiny local component registry of text fields and a submit button.
// A `submit` event fires back through `.onEvent("submit")` to prove the
// event pipeline is wired from component factory → root handler.
//
// This view exists for manual smoke-testing during Phase 1. It's listed
// in `ContentView`'s demo sidebar and also exercised indirectly by
// `CSSLayoutIntegrationTests` which builds a similar tree headlessly.

import SwiftUI
import CSSLayout

struct CSSLayoutDemo: View {

    // MARK: - Live form state

    @State private var values: [String: String] = [
        "firstName": "",
        "lastName":  "",
        "email":     "",
        "company":   "",
        "role":      "",
        "phone":     "",
        "website":   "",
        "country":   "",
        "notes":     "",
    ]

    @State private var lastSubmitted: [String: String]?

    // MARK: - CSS payload

    /// 10 rows (1 title + 9 inputs) in a column container with gap.
    /// The CSS uses only §4.1 primitives to prove the Phase-1 subset is
    /// enough for a real form.
    private let css = """
    #root {
        display: flex;
        flex-direction: column;
        padding: 24px;
        gap: 14px;
    }
    #title        { height: 36px; }
    #firstName    { flex: 1; height: 32px; }
    #lastName     { flex: 1; height: 32px; }
    #email        { flex: 1; height: 32px; }
    #company      { flex: 1; height: 32px; }
    #role         { flex: 1; height: 32px; }
    #phone        { flex: 1; height: 32px; }
    #website      { flex: 1; height: 32px; }
    #country      { flex: 1; height: 32px; }
    #notes        { flex: 1; height: 72px; }
    #submit       { height: 40px; }
    """

    private var schema: [SchemaEntry] {
        [
            SchemaEntry(id: "title",     type: "heading"),
            SchemaEntry(id: "firstName", type: "text-field"),
            SchemaEntry(id: "lastName",  type: "text-field"),
            SchemaEntry(id: "email",     type: "text-field"),
            SchemaEntry(id: "company",   type: "text-field"),
            SchemaEntry(id: "role",      type: "text-field"),
            SchemaEntry(id: "phone",     type: "text-field"),
            SchemaEntry(id: "website",   type: "text-field"),
            SchemaEntry(id: "country",   type: "text-field"),
            SchemaEntry(id: "notes",     type: "text-field"),
            SchemaEntry(id: "submit",    type: "submit-button"),
        ]
    }

    /// A fresh registry instance per demo view keeps this screen from
    /// bleeding into the shared singleton.
    private var registry: ComponentRegistry {
        let r = ComponentRegistry()
        r.register("heading") { props, _ in
            AnyView(
                Text("Create your account")
                    .font(.title2.weight(.semibold))
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .accessibilityIdentifier(props.id)
            )
        }
        r.register("text-field") { props, _ in
            AnyView(
                TextFieldBinding(
                    id: props.id,
                    placeholder: props.id
                )
                .accessibilityIdentifier(props.id)
            )
        }
        r.register("submit-button") { props, events in
            AnyView(
                Button("Submit") {
                    events.emit("submit", payload: [:])
                }
                .buttonStyle(.borderedProminent)
                .frame(maxWidth: .infinity)
                .accessibilityIdentifier(props.id)
            )
        }
        return r
    }

    // MARK: - Body

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            CSSLayout(css: css, schema: schema, registry: registry)
                .onEvent("submit") { _ in
                    lastSubmitted = values
                    print("🎯 submit →", values)
                }
                .frame(maxWidth: 520)

            if let submitted = lastSubmitted {
                GroupBox("Last submission") {
                    VStack(alignment: .leading, spacing: 4) {
                        ForEach(submitted.sorted(by: { $0.key < $1.key }), id: \.key) { k, v in
                            Text("\(k): \(v.isEmpty ? "—" : v)")
                                .font(.system(.caption, design: .monospaced))
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
                .padding(.horizontal, 24)
                .padding(.bottom, 16)
            }
        }
        .environment(\.cssFormValues, $values)
    }
}

// MARK: - Field binding bridge
//
// A standalone TextField stored per-field through the environment —
// lets the component registry factories read/write `values` without
// capturing `self`.

private struct TextFieldBinding: View {
    let id: String
    let placeholder: String

    @Environment(\.cssFormValues) private var values

    var body: some View {
        TextField(placeholder, text: Binding(
            get: { values.wrappedValue[id] ?? "" },
            set: { values.wrappedValue[id] = $0 }
        ))
        .textFieldStyle(.roundedBorder)
        .frame(maxWidth: .infinity)
    }
}

private struct CSSFormValuesKey: EnvironmentKey {
    static let defaultValue: Binding<[String: String]> = .constant([:])
}

private extension EnvironmentValues {
    var cssFormValues: Binding<[String: String]> {
        get { self[CSSFormValuesKey.self] }
        set { self[CSSFormValuesKey.self] = newValue }
    }
}
