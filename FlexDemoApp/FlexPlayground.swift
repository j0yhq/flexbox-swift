import SwiftUI
import FlexLayout

// MARK: - FlexPlayground
// A simple view you can open in Xcode Previews and tweak live.
// Uses ONLY FlexBox for layout — no HStack/VStack/ZStack.

struct FlexPlayground: View {
    var body: some View {
        FlexBox(direction: .column, gap: 16,
                padding: EdgeInsets(top: 20, leading: 20, bottom: 20, trailing: 20)) {

            // ── Row: avatar + name + button ─────────────
            FlexBox(direction: .row, alignItems: .center, gap: 12) {
                Text("🧑‍💻")
                    .font(.system(size: 32))
                    .flexItem(shrink: 0)

                Text("Hello FlexBox!")
                    .font(.title2.bold())
                    .flexItem(grow: 1)

                Text("Edit")
                    .font(.subheadline)
                    .foregroundStyle(.blue)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 6)
                    .background(.blue.opacity(0.1), in: Capsule())
                    .flexItem(shrink: 0)
            }
            .flexItem(shrink: 0)

            // ── Three equal cards ───────────────────────
            FlexBox(direction: .row, gap: 12) {
                card("Revenue", value: "$48K", color: .green)
                    .flexItem(grow: 1, basis: .points(0))
                card("Users", value: "2.8K", color: .blue)
                    .flexItem(grow: 1, basis: .points(0))
                card("Orders", value: "1K", color: .purple)
                    .flexItem(grow: 1, basis: .points(0))
            }
            .flexItem(shrink: 0)

            // ── Wrapping tags ───────────────────────────
            FlexBox(direction: .row, wrap: .wrap, gap: 8) {
                ForEach(["SwiftUI", "FlexBox", "CSS", "Layout", "iOS", "macOS", "Grow", "Shrink", "Wrap"], id: \.self) { tag in
                    Text(tag)
                        .font(.caption.weight(.medium))
                        .padding(.horizontal, 10)
                        .padding(.vertical, 5)
                        .background(Color.blue.opacity(0.1), in: Capsule())
                        .flexItem(shrink: 0)
                }
            }
            .flexItem(shrink: 0)

            // ── Content area (grows to fill) ────────────
            RoundedRectangle(cornerRadius: 12)
                .fill(.blue.opacity(0.05))
                .overlay(
                    Text("This area grows to fill remaining space")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                )
                .flexItem(grow: 1)

            // ── Bottom bar ──────────────────────────────
            FlexBox(direction: .row, justifyContent: .spaceBetween, alignItems: .center) {
                Text("3 items").font(.caption).foregroundStyle(.secondary)
                    .flexItem(shrink: 0)
                Text("Done")
                    .font(.subheadline.bold())
                    .foregroundStyle(.white)
                    .padding(.horizontal, 20)
                    .padding(.vertical, 8)
                    .background(.blue, in: Capsule())
                    .flexItem(shrink: 0)
            }
            .flexItem(shrink: 0)
        }
        .frame(width: 400, height: 500)
        .background(Color(nsColor: .windowBackgroundColor))
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .shadow(color: .black.opacity(0.1), radius: 10, y: 4)
    }

    private func card(_ title: String, value: String, color: Color) -> some View {
        FlexBox(direction: .column, justifyContent: .spaceBetween, alignItems: .flexStart,
                padding: EdgeInsets(top: 12, leading: 12, bottom: 12, trailing: 12)) {
            Text(title)
                .font(.caption)
                .foregroundStyle(.secondary)
                .flexItem(shrink: 0)
            Text(value)
                .font(.title3.bold())
                .foregroundStyle(color)
                .flexItem(shrink: 0)
        }
        .background(RoundedRectangle(cornerRadius: 10).fill(Color(nsColor: .controlBackgroundColor)))
    }
}

// MARK: - Preview

#Preview("FlexPlayground") {
    FlexPlayground()
        .padding(40)
}

#Preview("Dark Mode") {
    FlexPlayground()
        .padding(40)
        .preferredColorScheme(.dark)
}
