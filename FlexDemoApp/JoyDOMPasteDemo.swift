// JoyDOMPasteDemo — paste a `JoyDOMSpec` JSON payload, see it render
// live. The joy-dom equivalent of the deleted CSSPasteDemo.
//
// The demo registers default primitives (`div`, `p`, `primitive_*`)
// plus a small registry of conventional types (`button`, `input`,
// `card`) so authored payloads light up without needing custom
// factories. A viewport slider drives breakpoint resolution; an
// error panel surfaces JSON / decoding diagnostics.

import SwiftUI
import JoyDOM

struct JoyDOMPasteDemo: View {

    // MARK: - Owned state

    @State private var jsonText: String = JoyDOMPasteDemo.sampleJSON
    @State private var decodeError: String? = nil
    @State private var simulatedWidth: CGFloat = 600

    // MARK: - Body

    var body: some View {
        let spec = decodedSpec
        let viewport = Viewport(width: simulatedWidth)

        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                header
                Divider()

                editorPane
                widthSlider
                Divider()

                renderPane(spec: spec, viewport: viewport)
                errorPane
            }
            .padding(24)
            .frame(maxWidth: 920, alignment: .leading)
        }
    }

    // MARK: - Sub-views

    private var header: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("Paste joy-dom JSON → Preview")
                .font(.title2.weight(.semibold))
            Text(
                "Drop a JoyDOMSpec JSON payload here and see it render live. "
                + "Default factories cover div, p, primitive_string/number/null, "
                + "and a few conventional widgets (button, input, card). "
                + "Drag the slider to test breakpoints."
            )
            .font(.subheadline)
            .foregroundStyle(.secondary)
        }
    }

    private var editorPane: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text("JSON payload")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)
                Spacer()
                Button("Reset to sample") {
                    jsonText = JoyDOMPasteDemo.sampleJSON
                }
                .buttonStyle(.bordered)
                .controlSize(.small)
            }

            TextEditor(text: $jsonText)
                .font(.system(.caption, design: .monospaced))
                .frame(minHeight: 220)
                .padding(8)
                .background(Color(white: 0.97))
                .clipShape(RoundedRectangle(cornerRadius: 8))
                .overlay(
                    RoundedRectangle(cornerRadius: 8)
                        .strokeBorder(Color.gray.opacity(0.25))
                )
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

    @ViewBuilder
    private func renderPane(spec: JoyDOMSpec?, viewport: Viewport) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Preview")
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)
            if let spec = spec {
                JoyDOMView(spec: spec, registry: registry)
                    .viewport(viewport)
                    .onEvent("*") { _ in /* swallow for the preview */ }
                    .frame(maxWidth: .infinity, alignment: .topLeading)
                    .padding(12)
                    .background(Color(white: 0.96))
                    .clipShape(RoundedRectangle(cornerRadius: 10))
                    .overlay(
                        RoundedRectangle(cornerRadius: 10)
                            .strokeBorder(Color.gray.opacity(0.25))
                    )
            } else {
                Text("(no preview — fix the JSON below)")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, minHeight: 160)
                    .background(Color(white: 0.96))
                    .clipShape(RoundedRectangle(cornerRadius: 10))
            }
        }
    }

    @ViewBuilder
    private var errorPane: some View {
        if let err = decodeError {
            GroupBox("Decode error") {
                Text(err)
                    .font(.system(.caption, design: .monospaced))
                    .foregroundStyle(.red)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(6)
            }
        }
    }

    // MARK: - Decode pipeline

    /// Decode the current `jsonText` into a `JoyDOMSpec`. Side-effects:
    /// updates `decodeError` so the error pane can surface the message.
    private var decodedSpec: JoyDOMSpec? {
        let data = Data(jsonText.utf8)
        do {
            let spec = try JSONDecoder().decode(JoyDOMSpec.self, from: data)
            DispatchQueue.main.async { self.decodeError = nil }
            return spec
        } catch {
            let friendly = friendlyMessage(for: error)
            DispatchQueue.main.async {
                self.decodeError = friendly
            }
            return nil
        }
    }

    /// Reformat a `DecodingError` (or any error) into a single-line
    /// human-readable message. Covers the four `DecodingError` cases
    /// plus a final fallback to `localizedDescription`.
    private func friendlyMessage(for error: Error) -> String {
        switch error {
        case let DecodingError.dataCorrupted(ctx):
            // The path of an underlying `NSError` JSON-syntax message
            // is the most useful bit for fixing typos.
            if let nsErr = ctx.underlyingError as NSError?,
               let msg = nsErr.userInfo["NSDebugDescription"] as? String {
                return "Invalid JSON: \(msg)"
            }
            return "Invalid JSON: \(ctx.debugDescription)"

        case let DecodingError.keyNotFound(key, ctx):
            return "Missing required key '\(key.stringValue)' at \(formatPath(ctx.codingPath))"

        case let DecodingError.typeMismatch(type, ctx):
            return "Wrong type at \(formatPath(ctx.codingPath)): expected \(type), \(ctx.debugDescription)"

        case let DecodingError.valueNotFound(type, ctx):
            return "Null value at \(formatPath(ctx.codingPath)), but \(type) expected"

        default:
            return error.localizedDescription
        }
    }

    private func formatPath(_ path: [CodingKey]) -> String {
        guard !path.isEmpty else { return "<root>" }
        return path.map { $0.stringValue }.joined(separator: ".")
    }

    // MARK: - Registry

    private var registry: ComponentRegistry {
        let r = ComponentRegistry().withDefaultPrimitives()

        // Buttons emit a named event from `props["event"]` (default
        // "tap"). Useful for testing event handlers.
        r.register("button") { props, events in
            let label = props.string("label") ?? props.string("text") ?? "Button"
            let event = props.string("event") ?? "tap"
            return .custom {
                Button(label) {
                    events.emit(event, payload: [:])
                }
                .buttonStyle(.borderedProminent)
                .frame(maxWidth: .infinity)
                .accessibilityIdentifier(props.id)
            }
        }

        // Single-line text input. Reads/writes via events.binding so
        // hosts wiring `.bindings([id: path]).formState(form)` get a
        // live two-way binding.
        r.register("input") { props, events in
            let placeholder = props.string("placeholder") ?? ""
            let id = props.id
            let binding = events.binding("value")
            return .custom {
                TextField(placeholder, text: binding)
                    .textFieldStyle(.roundedBorder)
                    .frame(maxWidth: .infinity)
                    .accessibilityIdentifier(id)
            }
        }

        // Decorative card with a coloured background — handy for
        // visualising layout without writing custom CSS.
        r.register("card") { props, _ in
            let label = props.string("label") ?? props.string("text") ?? ""
            return .custom {
                VStack(alignment: .leading) {
                    Text(label)
                        .font(.body.weight(.medium))
                }
                .padding(12)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
                .background(Color.accentColor.opacity(0.12))
                .clipShape(RoundedRectangle(cornerRadius: 6))
                .accessibilityIdentifier(props.id)
            }
        }

        return r
    }

    // MARK: - Sample payload

    /// A representative `JoyDOMSpec` used to seed the editor on first
    /// open and on "Reset to sample". Demonstrates document-level
    /// styles, a breakpoint, and a few of the registered component
    /// types so a fresh user sees a non-trivial layout immediately.
    fileprivate static let sampleJSON: String = #"""
    {
      "version": 1,
      "style": {
        "#root": {
          "flexDirection": "column",
          "gap": { "value": 12, "unit": "px" },
          "padding": { "value": 16, "unit": "px" }
        },
        "#row": {
          "flexDirection": "column",
          "gap": { "value": 12, "unit": "px" }
        },
        "#a, #b, #c": {
          "flexGrow": 1,
          "height": { "value": 80, "unit": "px" }
        }
      },
      "breakpoints": [
        {
          "conditions": [
            { "type": "feature", "name": "width", "operator": ">=", "value": 768, "unit": "px" }
          ],
          "nodes": {},
          "style": {
            "#row": {
              "flexDirection": "row",
              "gap": { "value": 16, "unit": "px" }
            }
          }
        }
      ],
      "layout": {
        "type": "div",
        "props": { "id": "root" },
        "children": [
          {
            "type": "p",
            "props": { "id": "title" },
            "children": ["Hello, joy-dom!"]
          },
          {
            "type": "div",
            "props": { "id": "row" },
            "children": [
              { "type": "card", "props": { "id": "a", "label": "Card A" } },
              { "type": "card", "props": { "id": "b", "label": "Card B" } },
              { "type": "card", "props": { "id": "c", "label": "Card C" } }
            ]
          },
          {
            "type": "button",
            "props": { "id": "submit", "label": "Submit", "event": "submit" }
          }
        ]
      }
    }
    """#
}
