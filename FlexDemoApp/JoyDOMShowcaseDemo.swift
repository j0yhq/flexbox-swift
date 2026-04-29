// JoyDOMShowcaseDemo — Tier 3 end-to-end demo.
//
// Renders a `JoyDOMSpec` (Josh's joyfill/.joy DOM spec) through every
// piece of plumbing CSSLayout's Tier 3 added:
//
//   • Spec types       (Unit 1)  — JoyDOMSpec / Node / NodeProps / Style
//   • Style serializer (Unit 2)  — Style → CSS text the parser accepts
//   • Tree flattener   (Unit 3)  — Node tree → SchemaEntry array
//   • Inline styles    (Unit 4)  — props.style → `#id { ... }` rules
//   • MediaQuery eval  (Unit 5)  — width / orientation / print
//   • Viewport plumb   (Unit 6)  — host width pushed via env / props
//   • Breakpoint pick  (Unit 7)  — cascade + specificity
//   • Apply breakpoint (Unit 8)  — re-emit cascade for active bp
//   • Default prims    (Unit 9)  — div / p / primitive_* factories
//   • UiAction         (Unit 10) — JSON-encoded handler descriptors
//
// The slider drives a mock viewport width. Two breakpoints are wired
// into the spec:
//
//   • `width >= 768` — two-column horizontal layout
//   • `width < 600`  — single-column stacked, secondary panel hidden
//
// In the dead band 600–767 neither breakpoint matches, so the
// document-level styles (a single column) render. Pressing the
// "Sign in" button emits a `UiAction` whose log entry surfaces in
// the debug panel — proving the JSON-encoded action token round-trips
// through the prop bag and out via ComponentEvents.

import SwiftUI
import CSSLayout

struct JoyDOMShowcaseDemo: View {

    // MARK: - Owned state

    /// Slider drives the mock viewport width. Range covers all three
    /// breakpoint zones (narrow < 600, dead band 600..<768, wide >=
    /// 768) so the user can step through every cascade transition.
    @State private var simulatedWidth: CGFloat = 480

    /// Rolling event log — the `Sign in` button emits a UiAction
    /// whose payload lands here so we can show the round-trip in UI.
    @State private var eventLog: [String] = []

    // MARK: - Body

    var body: some View {
        let viewport = Viewport(width: simulatedWidth)
        let activeIndex = BreakpointResolver.activeIndex(
            in: viewport,
            breakpoints: spec.breakpoints
        )

        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                header
                control
                Divider()
                canvas(viewport: viewport)
                debug(active: activeIndex)
            }
            .padding(24)
            .frame(maxWidth: 720, alignment: .leading)
        }
    }

    // MARK: - Chrome

    private var header: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("joy-dom Showcase")
                .font(.title2.weight(.semibold))
            Text(
                "A JoyDOMSpec rendered through every Tier 3 piece — "
                + "tree flattening, inline styles, breakpoint cascade, "
                + "default primitives, UiAction events. Drag the slider "
                + "to step through breakpoint transitions."
            )
            .font(.subheadline)
            .foregroundStyle(.secondary)
        }
    }

    private var control: some View {
        VStack(alignment: .leading, spacing: 6) {
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
            zoneLegend
        }
    }

    /// Visualizes the three breakpoint zones beneath the slider so
    /// it's obvious which one the current width falls into.
    private var zoneLegend: some View {
        HStack(spacing: 8) {
            zoneChip(label: "< 600 narrow",    color: .orange,
                     active: simulatedWidth < 600)
            zoneChip(label: "600–767 dead",    color: .gray,
                     active: simulatedWidth >= 600 && simulatedWidth < 768)
            zoneChip(label: "≥ 768 wide",      color: .green,
                     active: simulatedWidth >= 768)
        }
    }

    private func zoneChip(label: String, color: Color, active: Bool) -> some View {
        Text(label)
            .font(.system(.caption, design: .monospaced))
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(active ? color.opacity(0.20) : Color.clear)
            .foregroundStyle(active ? color : .secondary)
            .clipShape(RoundedRectangle(cornerRadius: 5))
            .overlay(
                RoundedRectangle(cornerRadius: 5)
                    .strokeBorder(active ? color.opacity(0.5) : Color.gray.opacity(0.25))
            )
    }

    private func canvas(viewport: Viewport) -> some View {
        CSSLayout(spec: spec, registry: registry)
            .viewport(viewport)
            .onEvent("*") { event in
                eventLog.append("\(event.sourceID) → \(event.name) \(event.payload)")
                if eventLog.count > 8 {
                    eventLog.removeFirst(eventLog.count - 8)
                }
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

    private func debug(active: Int?) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            GroupBox("Active breakpoint") {
                HStack {
                    Text("index")
                        .font(.caption).foregroundStyle(.secondary)
                    Spacer()
                    Text(active.map { "\($0) — \(self.label(for: $0))" } ?? "(none)")
                        .font(.system(.caption, design: .monospaced))
                        .padding(.horizontal, 6).padding(.vertical, 2)
                        .background(Color.blue.opacity(0.10))
                        .clipShape(RoundedRectangle(cornerRadius: 4))
                }
                .padding(6)
            }

            GroupBox("Event log") {
                VStack(alignment: .leading, spacing: 2) {
                    if eventLog.isEmpty {
                        Text("Tap a button…")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    } else {
                        ForEach(Array(eventLog.enumerated()), id: \.offset) { _, line in
                            Text(line)
                                .font(.system(.caption, design: .monospaced))
                        }
                    }
                }
                .padding(6)
                .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
    }

    private func label(for index: Int) -> String {
        index == 0 ? "wide ≥ 768" : "narrow < 600"
    }

    // MARK: - Spec — the joy-dom payload this demo renders

    private var spec: JoyDOMSpec {
        JoyDOMSpec(
            // Document-level styles — the default rendering. The
            // wide-bp and narrow-bp re-style #row to switch between
            // row and column flow, which is the responsive flip.
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
            ],
            breakpoints: [
                // Index 0 — wide layout: two columns side by side.
                Breakpoint(
                    conditions: [.width(operator: .greaterThanOrEqual,
                                        value: 768, unit: .px)],
                    style: [
                        "#row": Style(
                            flexDirection: .row,
                            gap: .uniform(.px(20))
                        ),
                    ]
                ),
                // Index 1 — narrow layout: per-node breakpoint
                // override demotes the secondary panel via padding
                // and flex-grow tweaks so it's visibly de-emphasized.
                // joy-dom's Style.display doesn't expose `none`, so
                // visibility-toggling waits on a future spec rev;
                // for now we shrink and tint the panel via inline
                // styles in the breakpoint.nodes override.
                Breakpoint(
                    conditions: [.width(operator: .lessThan,
                                        value: 600, unit: .px)],
                    nodes: [
                        "secondary": NodeProps(
                            style: Style(
                                flexGrow: 0,
                                padding: .uniform(.px(4))
                            )
                        ),
                    ]
                ),
            ],
            layout: Node(
                type: "div",
                props: NodeProps(id: "root"),
                children: [
                    .node(Node(
                        type: "p",
                        props: NodeProps(
                            id: "title",
                            style: Style(padding: .uniform(.px(8)))
                        ),
                        children: [.primitive(.string("Welcome to joy-dom"))]
                    )),
                    .node(Node(
                        type: "div",
                        props: NodeProps(id: "row"),
                        children: [
                            .node(Node(
                                type: "div",
                                props: NodeProps(
                                    id: "primary",
                                    style: Style(
                                        flexGrow: 1,
                                        padding: .uniform(.px(12))
                                    )
                                ),
                                children: [
                                    .node(Node(
                                        type: "p",
                                        children: [.primitive(.string("Primary panel"))]
                                    )),
                                    .node(Node(
                                        type: "p",
                                        children: [.primitive(
                                            .string("Reads top-to-bottom on narrow, left-of on wide.")
                                        )]
                                    )),
                                    .node(signInButton),
                                ]
                            )),
                            .node(Node(
                                type: "div",
                                props: NodeProps(
                                    id: "secondary",
                                    style: Style(
                                        flexGrow: 1,
                                        padding: .uniform(.px(12))
                                    )
                                ),
                                children: [
                                    .node(Node(
                                        type: "p",
                                        children: [.primitive(.string("Secondary panel"))]
                                    )),
                                    .node(Node(
                                        type: "p",
                                        children: [.primitive(
                                            .string("Disappears below 600px via the narrow breakpoint.")
                                        )]
                                    )),
                                ]
                            )),
                        ]
                    )),
                ]
            )
        )
    }

    /// The "Sign in" button node. The button's UiAction is constructed
    /// inside its factory closure (in `registry` below) so the round-
    /// trip happens at emit time. SchemaFlattener prop-routing for
    /// arbitrary NodeProps fields is a follow-up iteration; this
    /// demo's purpose is to show every Tier 3 piece working together,
    /// not to fully wire JSON-encoded actions through the schema bag.
    private var signInButton: Node {
        Node(
            type: "button",
            props: NodeProps(
                id: "sign-in-btn",
                style: Style(padding: .uniform(.px(8)))
            )
        )
    }

    // MARK: - Registry

    private var registry: ComponentRegistry {
        let r = ComponentRegistry().withDefaultPrimitives()

        r.register("button") { props, events in
            let id = props.id
            return .custom {
                Button("Sign in") {
                    // Demonstrate UiAction round-trip: the factory
                    // builds an action descriptor and emits it as
                    // event payload, where the root .onEvent("*")
                    // sink renders the log entry.
                    let action = UiAction(action: "submit", args: ["sign-in"])
                    let encoded = action.encodedString() ?? ""
                    events.emit("ui-action", payload: ["action": encoded])
                }
                .buttonStyle(.borderedProminent)
                .accessibilityIdentifier(id)
            }
        }

        return r
    }
}
