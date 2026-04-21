// WizardDemo — Phase 3 server-driven screen #3.
//
// Angle: **multi-step server flows**. Three server payloads represent
// three steps of a signup wizard. Each step's payload defines only the
// fields relevant to that step; navigation between steps swaps payloads
// while the shared FormState keeps every value in place.
//
//   Step 1 · basics   → firstName, lastName
//   Step 2 · contact  → adds email, phone
//   Step 3 · review   → a read-only summary of the accumulated values
//
// The "next" / "back" / "submit" buttons emit named events that the
// host screen catches through `CSSLayout.onEvent(_:)`, which is how a
// real app would let the server drive step transitions without the
// client hard-coding the wizard shape.

import SwiftUI
import CSSLayout

struct WizardDemo: View {

    // MARK: - Owned state

    @StateObject private var form = FormState(values: [
        "signup.firstName": "",
        "signup.lastName":  "",
        "signup.email":     "",
        "signup.phone":     "",
    ])

    /// Cache survives View-struct rebuilds; see FormStateDemo for the
    /// SwiftUI lifetime note.
    @State private var cache = CSSPayloadCache(capacity: 4)

    /// Current step, 1-indexed. Advanced/retreated by events from the
    /// rendered payload.
    @State private var step: Int = 1
    @State private var currentPayload: CSSPayload = WizardDemo.step1Payload
    @State private var submittedAt: Date? = nil
    @State private var cacheHits: Int = 0
    @State private var cacheMisses: Int = 0

    // MARK: - Body

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                header
                progress
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
            Text("Multi-Step Server Flow")
                .font(.title2.weight(.semibold))
            Text(
                "A three-step signup wizard. The server ships one CSS "
                + "payload per step; FormState accumulates across all "
                + "three. Go forward, back, forward again — every value "
                + "you've typed is still there."
            )
            .font(.subheadline)
            .foregroundStyle(.secondary)
        }
    }

    private var progress: some View {
        HStack(spacing: 6) {
            ForEach(1...3, id: \.self) { i in
                Capsule()
                    .fill(i <= step ? Color.accentColor : Color.gray.opacity(0.25))
                    .frame(height: 6)
            }
            Text("Step \(step) of 3")
                .font(.caption.weight(.medium))
                .foregroundStyle(.secondary)
                .padding(.leading, 6)
        }
    }

    private var formCanvas: some View {
        CSSLayout(payload: currentPayload, registry: registry)
            .formState(form)
            .onEvent("next")   { _ in advance() }
            .onEvent("back")   { _ in retreat() }
            .onEvent("submit") { _ in submit() }
            .frame(maxWidth: .infinity, minHeight: 260, alignment: .topLeading)
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
            GroupBox("FormState snapshot · accumulates across all steps") {
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

            if let submittedAt {
                GroupBox("Submitted") {
                    Text("Wizard completed at \(submittedAt.formatted(date: .omitted, time: .standard)).")
                        .font(.caption)
                        .padding(6)
                }
            }

            GroupBox("CSSPayloadCache") {
                HStack(spacing: 24) {
                    stat("hits",   value: cacheHits,   color: .green)
                    stat("misses", value: cacheMisses, color: .orange)
                    Spacer()
                    Button("Reset wizard") {
                        Task {
                            await cache.clear()
                            cacheHits = 0
                            cacheMisses = 0
                            submittedAt = nil
                            step = 1
                            currentPayload = Self.step1Payload
                            await prime()
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

    // MARK: - Step transitions

    private func advance() {
        guard step < 3 else { return }
        step += 1
        Task { await load(step: step) }
    }

    private func retreat() {
        guard step > 1 else { return }
        step -= 1
        Task { await load(step: step) }
    }

    private func submit() {
        submittedAt = Date()
        print("🚀 wizard submit →", form.snapshot())
    }

    // MARK: - Cache-backed payload loading

    private func prime() async {
        if await cache.get(versionKey(for: 1)) == nil {
            await cache.put(versionKey(for: 1), currentPayload)
            cacheMisses += 1
        }
    }

    private func load(step: Int) async {
        let key = versionKey(for: step)
        if let cached = await cache.get(key) {
            currentPayload = cached
            cacheHits += 1
            return
        }
        let fresh = Self.payload(for: step)
        await cache.put(key, fresh)
        currentPayload = fresh
        cacheMisses += 1
    }

    private func versionKey(for step: Int) -> String { "wizard-step-\(step)" }

    // MARK: - "Server" payloads — one per step

    private static func payload(for step: Int) -> CSSPayload {
        switch step {
        case 2: return step2Payload
        case 3: return step3Payload
        default: return step1Payload
        }
    }

    private static let step1Payload = CSSPayload(
        css: """
        #root {
            display: flex;
            flex-direction: column;
            gap: 12px;
            padding: 16px;
        }
        #heading { height: 30px; }
        .pair { display: flex; flex-direction: row; gap: 12px; }
        #firstName, #lastName { flex: 1; height: 32px; }
        .buttons { display: flex; flex-direction: row; gap: 10px; }
        #next { flex: 1; height: 38px; }
        """,
        schema: [
            SchemaEntry(id: "heading", type: "heading",
                        props: ["text": "Step 1 · Your basics"]),
            SchemaEntry(id: "row-1", classes: ["pair"]),
            SchemaEntry(id: "firstName", type: "text-field",
                        parentID: "row-1",
                        props: ["binding": "signup.firstName",
                                "placeholder": "First name"]),
            SchemaEntry(id: "lastName", type: "text-field",
                        parentID: "row-1",
                        props: ["binding": "signup.lastName",
                                "placeholder": "Last name"]),
            SchemaEntry(id: "buttons", classes: ["buttons"]),
            SchemaEntry(id: "next", type: "nav-button",
                        parentID: "buttons",
                        props: ["text": "Continue",
                                "event": "next",
                                "style": "primary"]),
        ]
    )

    private static let step2Payload = CSSPayload(
        css: """
        #root {
            display: flex;
            flex-direction: column;
            gap: 12px;
            padding: 16px;
        }
        #heading { height: 30px; }
        #email, #phone { height: 32px; }
        .buttons { display: flex; flex-direction: row; gap: 10px; }
        #back { flex: 1; height: 38px; }
        #next { flex: 2; height: 38px; }
        """,
        schema: [
            SchemaEntry(id: "heading", type: "heading",
                        props: ["text": "Step 2 · How we reach you"]),
            SchemaEntry(id: "email", type: "text-field",
                        props: ["binding": "signup.email",
                                "placeholder": "Email address"]),
            SchemaEntry(id: "phone", type: "text-field",
                        props: ["binding": "signup.phone",
                                "placeholder": "Phone number"]),
            SchemaEntry(id: "buttons", classes: ["buttons"]),
            SchemaEntry(id: "back", type: "nav-button",
                        parentID: "buttons",
                        props: ["text": "Back",
                                "event": "back",
                                "style": "secondary"]),
            SchemaEntry(id: "next", type: "nav-button",
                        parentID: "buttons",
                        props: ["text": "Continue",
                                "event": "next",
                                "style": "primary"]),
        ]
    )

    private static let step3Payload = CSSPayload(
        css: """
        #root {
            display: flex;
            flex-direction: column;
            gap: 10px;
            padding: 16px;
        }
        #heading, #subheading { height: 28px; }
        #nameReview, #emailReview, #phoneReview { height: 26px; }
        .buttons { display: flex; flex-direction: row; gap: 10px; }
        #back { flex: 1; height: 38px; }
        #submit { flex: 2; height: 38px; }
        """,
        schema: [
            SchemaEntry(id: "heading", type: "heading",
                        props: ["text": "Step 3 · Review"]),
            SchemaEntry(id: "subheading", type: "subheading",
                        props: ["text": "Confirm everything below is correct."]),
            SchemaEntry(id: "nameReview", type: "readonly-field",
                        props: ["label": "Name",
                                "binding.first": "signup.firstName",
                                "binding.last":  "signup.lastName"]),
            SchemaEntry(id: "emailReview", type: "readonly-field",
                        props: ["label": "Email",
                                "binding": "signup.email"]),
            SchemaEntry(id: "phoneReview", type: "readonly-field",
                        props: ["label": "Phone",
                                "binding": "signup.phone"]),
            SchemaEntry(id: "buttons", classes: ["buttons"]),
            SchemaEntry(id: "back", type: "nav-button",
                        parentID: "buttons",
                        props: ["text": "Back",
                                "event": "back",
                                "style": "secondary"]),
            SchemaEntry(id: "submit", type: "nav-button",
                        parentID: "buttons",
                        props: ["text": "Create account",
                                "event": "submit",
                                "style": "primary"]),
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

        r.register("subheading") { props, _ in
            .custom {
                Text(props.string("text") ?? "")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .accessibilityIdentifier(props.id)
            }
        }

        r.register("text-field") { props, events in
            .custom {
                WizardBoundField(
                    placeholder: props.string("placeholder") ?? "",
                    text: events.binding("value")
                )
                .accessibilityIdentifier(props.id)
            }
        }

        // A read-only row. Either binds to a single FormState path via
        // `binding` (label: value) or joins two paths via
        // `binding.first`/`binding.last` for e.g. full-name review.
        r.register("readonly-field") { props, events in
            let label = props.string("label") ?? ""
            let single = events.binding("value").wrappedValue
            let first  = events.binding("first").wrappedValue
            let last   = events.binding("last").wrappedValue
            let value: String = {
                if props.string("binding.first") != nil {
                    let joined = [first, last].filter { !$0.isEmpty }.joined(separator: " ")
                    return joined.isEmpty ? "—" : joined
                }
                return single.isEmpty ? "—" : single
            }()
            return .custom {
                HStack {
                    Text(label)
                        .font(.system(.caption, design: .monospaced))
                        .foregroundStyle(.secondary)
                    Spacer()
                    Text(value)
                        .font(.system(.caption, design: .monospaced))
                }
                .accessibilityIdentifier(props.id)
            }
        }

        // Generic event button — emits whatever name the payload put in
        // `event`. Lets the server drive navigation without the client
        // having to hard-code a step machine.
        r.register("nav-button") { props, events in
            let title   = props.string("text")  ?? "Continue"
            let name    = props.string("event") ?? "next"
            let primary = (props.string("style") ?? "primary") == "primary"
            return .custom {
                Group {
                    if primary {
                        Button(title) { events.emit(name, payload: [:]) }
                            .buttonStyle(.borderedProminent)
                    } else {
                        Button(title) { events.emit(name, payload: [:]) }
                            .buttonStyle(.bordered)
                    }
                }
                .frame(maxWidth: .infinity)
                .accessibilityIdentifier(props.id)
            }
        }

        return r
    }
}

// MARK: - Text field wrapper

private struct WizardBoundField: View {
    let placeholder: String
    @Binding var text: String

    var body: some View {
        TextField(placeholder, text: $text)
            .textFieldStyle(.roundedBorder)
            .frame(maxWidth: .infinity)
    }
}
