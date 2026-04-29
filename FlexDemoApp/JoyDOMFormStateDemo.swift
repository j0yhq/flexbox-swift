// JoyDOMFormStateDemo — focused demo for the .bindings(_:) modifier
// added in Tier 4 Phase C1.
//
// A two-field signup form where:
//   • The schema is a `JoyDOMSpec` — the public API exposed to the
//     joyfill server / authoring tool.
//   • Field bindings to FormState are declared at the SwiftUI surface
//     via `.bindings([node_id: form_state_path])`. Joy-dom payloads
//     stay pure — no `$bind` tokens leaking into the wire format.
//   • A breakpoint flips the form from two-column at >=768px to a
//     stacked single-column at narrow widths.
//   • Submit emits an event the root sink logs, and the FormState
//     snapshot updates live in the debug panel.

import SwiftUI
import JoyDOM

struct JoyDOMFormStateDemo: View {

    // MARK: - Owned state

    @StateObject private var form = FormState(values: [
        "user.name":  "",
        "user.email": "",
    ])

    @State private var simulatedWidth: CGFloat = 480
    @State private var lastEvent: String = "—"

    // MARK: - Body

    var body: some View {
        let viewport = Viewport(width: simulatedWidth)

        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                header
                widthSlider
                Divider()
                canvas(viewport: viewport)
                debug
            }
            .padding(24)
            .frame(maxWidth: 720, alignment: .leading)
        }
    }

    // MARK: - Sub-views

    private var header: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("joy-dom + FormState")
                .font(.title2.weight(.semibold))
            Text(
                "A two-field signup whose values live in FormState. "
                + "Bindings are declared via `.bindings([id: path])` at "
                + "the SwiftUI surface — the joy-dom payload stays "
                + "pure. Drag the slider to see the breakpoint flip "
                + "the form between two-column and stacked layouts."
            )
            .font(.subheadline)
            .foregroundStyle(.secondary)
        }
    }

    private var widthSlider: some View {
        HStack(spacing: 12) {
            Text("Viewport width")
                .font(.caption)
                .foregroundStyle(.secondary)
                .frame(width: 110, alignment: .leading)
            Slider(value: $simulatedWidth, in: 320...1200, step: 1)
            Text("\(Int(simulatedWidth))px")
                .font(.system(.caption, design: .monospaced))
                .frame(width: 70, alignment: .trailing)
        }
    }

    private func canvas(viewport: Viewport) -> some View {
        JoyDOMView(spec: spec, registry: registry)
            .viewport(viewport)
            .formState(form)
            .bindings([
                "name-field":  "user.name",
                "email-field": "user.email",
            ])
            .onEvent("submit") { event in
                lastEvent = "submit @ \(event.sourceID) — \(form.snapshot())"
            }
            .frame(maxWidth: .infinity, alignment: .topLeading)
            .padding(12)
            .background(Color(white: 0.96))
            .clipShape(RoundedRectangle(cornerRadius: 10))
            .overlay(
                RoundedRectangle(cornerRadius: 10)
                    .strokeBorder(Color.gray.opacity(0.25))
            )
    }

    private var debug: some View {
        VStack(alignment: .leading, spacing: 10) {
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
                }
                .padding(6)
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            GroupBox("Last event") {
                Text(lastEvent)
                    .font(.system(.caption, design: .monospaced))
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(6)
            }
        }
    }

    // MARK: - Spec

    private var spec: JoyDOMSpec {
        JoyDOMSpec(
            style: [
                "#root": Style(
                    flexDirection: .column,
                    gap: .uniform(.px(12)),
                    padding: .uniform(.px(16))
                ),
                "#row": Style(
                    flexDirection: .column,
                    gap: .uniform(.px(12))
                ),
                "#name-field": Style(flexGrow: 1, height: .px(38)),
                "#email-field": Style(flexGrow: 1, height: .px(38)),
                "#submit": Style(height: .px(40)),
            ],
            breakpoints: [
                Breakpoint(
                    conditions: [.width(operator: .greaterThanOrEqual,
                                        value: 768, unit: .px)],
                    style: [
                        "#row": Style(
                            flexDirection: .row,
                            gap: .uniform(.px(16))
                        ),
                    ]
                ),
            ],
            layout: Node(
                type: "div",
                props: NodeProps(id: "root"),
                children: [
                    .node(Node(type: "p", props: NodeProps(id: "title"),
                               children: [.primitive(.string("Sign up"))])),
                    .node(Node(
                        type: "div",
                        props: NodeProps(id: "row"),
                        children: [
                            .node(Node(type: "name-input",
                                       props: NodeProps(id: "name-field"))),
                            .node(Node(type: "email-input",
                                       props: NodeProps(id: "email-field"))),
                        ]
                    )),
                    .node(Node(type: "submit-button",
                               props: NodeProps(id: "submit"))),
                ]
            )
        )
    }

    // MARK: - Registry

    private var registry: ComponentRegistry {
        let r = ComponentRegistry().withDefaultPrimitives()
        r.register("name-input")  { props, events in fieldFactory(props, events, placeholder: "Full name") }
        r.register("email-input") { props, events in fieldFactory(props, events, placeholder: "Email address") }
        r.register("submit-button") { props, events in
            .custom {
                Button("Create account") {
                    events.emit("submit", payload: [:])
                }
                .buttonStyle(.borderedProminent)
                .frame(maxWidth: .infinity)
                .accessibilityIdentifier(props.id)
            }
        }
        return r
    }

    private func fieldFactory(
        _ props: ComponentProps,
        _ events: ComponentEvents,
        placeholder: String
    ) -> ComponentBody {
        let binding = events.binding("value")
        let id = props.id
        return .custom {
            TextField(placeholder, text: binding)
                .textFieldStyle(.roundedBorder)
                .frame(maxWidth: .infinity)
                .accessibilityIdentifier(id)
        }
    }
}
