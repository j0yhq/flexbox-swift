import SwiftUI
import FlexLayout

// ╔══════════════════════════════════════════════════════════════════════╗
// ║  Pure SwiftUI Screens — Layout: ONLY FlexBox                       ║
// ║  Views: native SwiftUI (Text, Image, TextField, etc.)              ║
// ║  No FlexCell hack — views fit naturally, backgrounds where needed  ║
// ╚══════════════════════════════════════════════════════════════════════╝

// MARK: - Shared helpers

private func avatar(_ initials: String, color: Color) -> some View {
    Text(initials)
        .font(.system(size: 12, weight: .bold))
        .foregroundStyle(.white)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(color, in: Circle())
}

// MARK: ═════════════════════════════════════════════════════════════════
// MARK: Sample 1 — Settings Page
// MARK: ═════════════════════════════════════════════════════════════════

struct SettingsPageSample: View {
    var body: some View {
        ScrollView {
            FlexBox(direction: .column, gap: 20,
                    padding: EdgeInsets(top: 24, leading: 24, bottom: 24, trailing: 24)) {

                Text("Settings").font(.largeTitle.bold())
                    .flexItem(shrink: 0)

                // ── Profile card ────────────────────────────────
                FlexBox(direction: .row, alignItems: .center, gap: 14,
                        padding: EdgeInsets(top: 14, leading: 16, bottom: 14, trailing: 16)) {
                    avatar("JA", color: .blue)
                        .flexItem(shrink: 0, width: .points(48), height: .points(48))
                    FlexBox(direction: .column, alignItems: .flexStart, gap: 2) {
                        Text("John Appleseed").font(.headline)
                            .flexItem(shrink: 0)
                        Text("john@apple.com").font(.subheadline).foregroundStyle(.secondary)
                            .flexItem(shrink: 0)
                    }
                    .flexItem(grow: 1)
                    Image(systemName: "chevron.right").foregroundStyle(.tertiary)
                        .flexItem(shrink: 0)
                }
                .flexItem(shrink: 0)
                .background(RoundedRectangle(cornerRadius: 10).fill(Color(nsColor: .controlBackgroundColor)))

                // ── General section ─────────────────────────────
                settingsGroup("General", rows: [
                    ("bell.badge",      "Notifications", "On"),
                    ("paintbrush",      "Appearance",    "System"),
                    ("globe",           "Language",      "English"),
                    ("lock.shield",     "Privacy",       ""),
                ])

                // ── Account section ─────────────────────────────
                settingsGroup("Account", rows: [
                    ("creditcard",          "Subscription", "Pro"),
                    ("externaldrive",       "Storage",      "4.2 GB"),
                    ("arrow.right.square",  "Sign Out",     ""),
                ])
            }
            .frame(maxWidth: .infinity)
        }
    }

    private func settingsGroup(_ title: String, rows: [(String, String, String)]) -> some View {
        FlexBox(direction: .column, alignItems: .stretch) {
            Text(title)
                .font(.caption.weight(.semibold)).foregroundStyle(.secondary).textCase(.uppercase)
                .padding(.leading, 4).padding(.bottom, 6)
                .flexItem(shrink: 0)

            ForEach(Array(rows.enumerated()), id: \.offset) { _, r in
                FlexBox(direction: .row, alignItems: .center, gap: 12,
                        padding: EdgeInsets(top: 0, leading: 14, bottom: 0, trailing: 14)) {
                    Image(systemName: r.0).font(.system(size: 15)).foregroundStyle(.blue)
                        .frame(width: 22)
                        .flexItem(shrink: 0, width: .points(22))
                    Text(r.1).font(.body)
                        .flexItem(grow: 1)
                    if !r.2.isEmpty {
                        Text(r.2).font(.subheadline).foregroundStyle(.secondary)
                            .flexItem(shrink: 0)
                    }
                    Image(systemName: "chevron.right").font(.caption2.weight(.semibold)).foregroundStyle(.tertiary)
                        .flexItem(shrink: 0)
                }
                .flexItem(shrink: 0, height: .points(48))
                .background(Color(nsColor: .controlBackgroundColor))
            }
        }
        .flexItem(shrink: 0)
        .clipShape(RoundedRectangle(cornerRadius: 10))
    }
}

// MARK: ═════════════════════════════════════════════════════════════════
// MARK: Sample 2 — Chat Screen
// MARK: ═════════════════════════════════════════════════════════════════

private struct Msg: Identifiable {
    let id = UUID(); let text: String; let isMe: Bool; let sender: String
}
private let msgs: [Msg] = [
    .init(text: "Hey! Are you free this afternoon?", isMe: false, sender: "A"),
    .init(text: "Yes! What time works for you?", isMe: true, sender: ""),
    .init(text: "How about 3pm? We can review the designs.", isMe: false, sender: "A"),
    .init(text: "Perfect, I'll send a calendar invite.", isMe: true, sender: ""),
    .init(text: "Great! See you then 🎉", isMe: false, sender: "A"),
    .init(text: "Looking forward to it!", isMe: true, sender: ""),
]

struct ChatScreenSample: View {
    @State private var draft = ""

    var body: some View {
        FlexBox(direction: .column, overflow: .hidden) {

            // ── Header ──────────────────────────────────────
            FlexBox(direction: .row, alignItems: .center, gap: 10,
                    padding: EdgeInsets(top: 0, leading: 14, bottom: 0, trailing: 14)) {
                Image(systemName: "chevron.left").font(.body.weight(.medium)).foregroundStyle(.blue)
                    .flexItem(shrink: 0)
                avatar("AJ", color: .indigo)
                    .flexItem(shrink: 0, width: .points(34), height: .points(34))
                FlexBox(direction: .column, alignItems: .flexStart, gap: 1) {
                    Text("Alice Johnson").font(.headline)
                        .flexItem(shrink: 0)
                    Text("Online").font(.caption).foregroundStyle(.green)
                        .flexItem(shrink: 0)
                }
                .flexItem(grow: 1)
                Image(systemName: "phone.fill").foregroundStyle(.blue)
                    .flexItem(shrink: 0)
                Image(systemName: "video.fill").foregroundStyle(.blue)
                    .flexItem(shrink: 0)
            }
            .flexItem(shrink: 0, height: .points(52))
            .background(Color(nsColor: .controlBackgroundColor))

            Divider().flexItem(shrink: 0)

            // ── Messages ────────────────────────────────────
            FlexBox(direction: .column, alignItems: .stretch, gap: 8,
                    padding: EdgeInsets(top: 12, leading: 12, bottom: 12, trailing: 12),
                    overflow: .scroll) {
                ForEach(msgs) { m in
                    FlexBox(direction: .row,
                            justifyContent: m.isMe ? .flexEnd : .flexStart,
                            alignItems: .flexEnd, gap: 6) {
                        if !m.isMe {
                            avatar(m.sender, color: .indigo)
                                .flexItem(shrink: 0, width: .points(26), height: .points(26))
                        }
                        Text(m.text)
                            .font(.body)
                            .foregroundStyle(m.isMe ? .white : .primary)
                            .padding(.horizontal, 12).padding(.vertical, 8)
                            .background(
                                m.isMe ? Color.blue : Color(nsColor: .controlBackgroundColor),
                                in: RoundedRectangle(cornerRadius: 16)
                            )
                            .flexItem(shrink: 1)
                    }
                    .flexItem(shrink: 0)
                }
            }
            .flexItem(grow: 1)

            Divider().flexItem(shrink: 0)

            // ── Input bar ───────────────────────────────────
            FlexBox(direction: .row, alignItems: .center, gap: 8,
                    padding: EdgeInsets(top: 8, leading: 12, bottom: 8, trailing: 12)) {
                Image(systemName: "plus.circle.fill").font(.title3).foregroundStyle(.blue)
                    .flexItem(shrink: 0)
                TextField("Type a message...", text: $draft)
                    .textFieldStyle(.roundedBorder)
                    .flexItem(grow: 1)
                Image(systemName: "arrow.up.circle.fill").font(.title3).foregroundStyle(.blue)
                    .flexItem(shrink: 0)
            }
            .flexItem(shrink: 0, height: .points(48))
            .background(Color(nsColor: .controlBackgroundColor))
        }
        .frame(maxWidth: 550, minHeight: 520, maxHeight: 580)
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .overlay(RoundedRectangle(cornerRadius: 12).strokeBorder(Color.gray.opacity(0.2)))
        .shadow(color: .black.opacity(0.06), radius: 6, y: 2)
        .padding(24)
    }
}

// MARK: ═════════════════════════════════════════════════════════════════
// MARK: Sample 3 — Dashboard
// MARK: ═════════════════════════════════════════════════════════════════

private struct KPI { let title: String; let value: String; let delta: String; let color: Color; let icon: String }
private let kpiData: [KPI] = [
    .init(title: "Revenue", value: "$48.2K", delta: "+12%", color: .green,  icon: "dollarsign.circle"),
    .init(title: "Users",   value: "2,847",  delta: "+8%",  color: .blue,   icon: "person.2"),
    .init(title: "Orders",  value: "1,024",  delta: "+15%", color: .purple, icon: "bag"),
    .init(title: "Churn",   value: "2.4%",   delta: "-3%",  color: .orange, icon: "arrow.down.right"),
]
private struct Act { let event: String; let amount: String; let icon: String; let color: Color }
private let actData: [Act] = [
    .init(event: "New subscription",  amount: "+$29", icon: "star.fill",       color: .yellow),
    .init(event: "Refund processed",  amount: "-$12", icon: "arrow.uturn.left",color: .red),
    .init(event: "Upgrade to Pro",    amount: "+$49", icon: "arrow.up.circle", color: .green),
    .init(event: "New signup",        amount: "+$9",  icon: "person.badge.plus",color: .blue),
    .init(event: "Invoice paid",      amount: "+$99", icon: "checkmark.circle",color: .green),
]

struct DashboardSample: View {
    var body: some View {
        ScrollView {
            FlexBox(direction: .column, gap: 18,
                    padding: EdgeInsets(top: 24, leading: 24, bottom: 24, trailing: 24)) {

                // ── Top bar ─────────────────────────────────
                FlexBox(direction: .row, alignItems: .center, gap: 12) {
                    Text("Dashboard").font(.title.bold())
                        .flexItem(grow: 1)
                    Image(systemName: "bell.badge").font(.title3).foregroundStyle(.secondary)
                        .flexItem(shrink: 0)
                    avatar("JA", color: .blue)
                        .flexItem(shrink: 0, width: .points(32), height: .points(32))
                }
                .flexItem(shrink: 0)

                // ── KPI cards ───────────────────────────────
                FlexBox(direction: .row, gap: 14) {
                    ForEach(Array(kpiData.enumerated()), id: \.offset) { _, k in
                        FlexBox(direction: .column, justifyContent: .spaceBetween, alignItems: .flexStart,
                                padding: EdgeInsets(top: 14, leading: 14, bottom: 14, trailing: 14)) {
                            FlexBox(direction: .row, alignItems: .center, gap: 6) {
                                Image(systemName: k.icon).font(.caption).foregroundStyle(k.color)
                                    .flexItem(shrink: 0)
                                Text(k.title).font(.caption).foregroundStyle(.secondary)
                                    .flexItem(shrink: 0)
                            }
                            .flexItem(shrink: 0)

                            Text(k.value).font(.title2.bold())
                                .flexItem(shrink: 0)

                            Text(k.delta).font(.caption.weight(.semibold))
                                .foregroundStyle(k.delta.hasPrefix("+") ? .green : .orange)
                                .flexItem(shrink: 0)
                        }
                        .flexItem(grow: 1, basis: .points(0), height: .points(100))
                        .background(RoundedRectangle(cornerRadius: 10).fill(Color(nsColor: .controlBackgroundColor)))
                    }
                }
                .flexItem(shrink: 0, height: .points(100))

                // ── Panels ──────────────────────────────────
                FlexBox(direction: .row, alignItems: .stretch, gap: 18) {

                    // Chart
                    FlexBox(direction: .column, alignItems: .stretch, gap: 12,
                            padding: EdgeInsets(top: 16, leading: 16, bottom: 16, trailing: 16)) {
                        FlexBox(direction: .row, alignItems: .center) {
                            Text("Revenue Over Time").font(.headline)
                                .flexItem(grow: 1)
                            Image(systemName: "ellipsis").foregroundStyle(.secondary)
                                .flexItem(shrink: 0)
                        }
                        .flexItem(shrink: 0)

                        // Chart placeholder
                        RoundedRectangle(cornerRadius: 8)
                            .fill(Color.blue.opacity(0.06))
                            .overlay(Image(systemName: "chart.xyaxis.line")
                                .font(.system(size: 40)).foregroundStyle(.blue.opacity(0.2)))
                            .flexItem(grow: 1)
                    }
                    .flexItem(grow: 2, basis: .points(0))
                    .background(RoundedRectangle(cornerRadius: 10).fill(Color(nsColor: .controlBackgroundColor)))

                    // Activity
                    FlexBox(direction: .column, alignItems: .stretch, gap: 2,
                            padding: EdgeInsets(top: 16, leading: 16, bottom: 16, trailing: 16)) {
                        Text("Recent Activity").font(.headline)
                            .flexItem(shrink: 0)

                        ForEach(Array(actData.enumerated()), id: \.offset) { _, a in
                            FlexBox(direction: .row, alignItems: .center, gap: 10) {
                                Image(systemName: a.icon).font(.caption).foregroundStyle(a.color)
                                    .frame(width: 24, height: 24)
                                    .background(a.color.opacity(0.1), in: Circle())
                                    .flexItem(shrink: 0, width: .points(24), height: .points(24))
                                Text(a.event).font(.subheadline)
                                    .flexItem(grow: 1)
                                Text(a.amount).font(.subheadline.weight(.medium))
                                    .foregroundStyle(a.amount.hasPrefix("+") ? .green : .red)
                                    .flexItem(shrink: 0)
                            }
                            .flexItem(shrink: 0, height: .points(36))
                        }
                    }
                    .flexItem(grow: 1, shrink: 0, basis: .points(280))
                    .background(RoundedRectangle(cornerRadius: 10).fill(Color(nsColor: .controlBackgroundColor)))
                }
                .flexItem(grow: 1)
            }
            .frame(maxWidth: .infinity, minHeight: 560)
        }
    }
}

// MARK: ═════════════════════════════════════════════════════════════════
// MARK: Sample 4 — Product Page
// MARK: ═════════════════════════════════════════════════════════════════

struct ProductPageSample: View {
    @State private var selColor = 0
    private let swatches: [(String, Color)] = [("Space Gray", .gray), ("Silver", Color(white: 0.82)), ("Blue", .blue), ("Red", .red)]

    var body: some View {
        ScrollView {
            FlexBox(direction: .row, wrap: .wrap, alignItems: .flexStart, gap: 32,
                    padding: EdgeInsets(top: 24, leading: 24, bottom: 24, trailing: 24)) {

                // ── Gallery ─────────────────────────────────
                FlexBox(direction: .column, alignItems: .stretch, gap: 12) {
                    RoundedRectangle(cornerRadius: 12).fill(Color.blue.opacity(0.05))
                        .overlay(Image(systemName: "headphones").font(.system(size: 72)).foregroundStyle(.blue.opacity(0.2)))
                        .flexItem(shrink: 0, height: .points(300))

                    FlexBox(direction: .row, gap: 8) {
                        ForEach(0..<5, id: \.self) { i in
                            RoundedRectangle(cornerRadius: 6)
                                .fill(i == 0 ? Color.blue.opacity(0.1) : Color.gray.opacity(0.06))
                                .overlay(RoundedRectangle(cornerRadius: 6)
                                    .strokeBorder(i == 0 ? Color.blue : Color.clear, lineWidth: 2))
                                .overlay(Image(systemName: "headphones").font(.caption).foregroundStyle(.secondary))
                                .flexItem(shrink: 0, width: .points(60), height: .points(60))
                        }
                    }
                    .flexItem(shrink: 0, height: .points(60))
                }
                .flexItem(shrink: 0, basis: .points(360))

                // ── Info ────────────────────────────────────
                FlexBox(direction: .column, alignItems: .flexStart, gap: 14) {
                    Text("Premium Wireless Headphones").font(.title.bold())
                        .flexItem(shrink: 0)

                    FlexBox(direction: .row, alignItems: .center, gap: 4) {
                        ForEach(0..<5, id: \.self) { i in
                            Image(systemName: i < 4 ? "star.fill" : "star.leadinghalf.filled")
                                .foregroundStyle(.orange).font(.caption)
                                .flexItem(shrink: 0)
                        }
                        Text("(2,847)").font(.caption).foregroundStyle(.secondary)
                            .flexItem(shrink: 0)
                    }
                    .flexItem(shrink: 0)

                    Text("$299.00").font(.title.bold()).foregroundStyle(.blue)
                        .flexItem(shrink: 0)

                    Text("Premium build quality with exceptional audio. 30hr battery, ANC, multi-device.")
                        .font(.body).foregroundStyle(.secondary)
                        .flexItem(shrink: 0)

                    // Colors
                    FlexBox(direction: .column, alignItems: .flexStart, gap: 8) {
                        Text("Color").font(.subheadline.weight(.medium))
                            .flexItem(shrink: 0)
                        FlexBox(direction: .row, gap: 10) {
                            ForEach(Array(swatches.enumerated()), id: \.offset) { i, s in
                                Circle().fill(s.1).frame(width: 28, height: 28)
                                    .overlay(Circle().strokeBorder(selColor == i ? Color.blue : Color.clear, lineWidth: 2.5).padding(-3))
                                    .onTapGesture { selColor = i }
                                    .flexItem(shrink: 0, width: .points(28), height: .points(28))
                            }
                        }
                        .flexItem(shrink: 0)
                    }
                    .flexItem(shrink: 0)

                    // Buttons
                    FlexBox(direction: .row, alignItems: .stretch, gap: 10) {
                        Text("Add to Cart").font(.headline).foregroundStyle(.white)
                            .frame(maxWidth: .infinity, maxHeight: .infinity)
                            .background(Color.blue, in: RoundedRectangle(cornerRadius: 10))
                            .flexItem(grow: 1, height: .points(48))
                        Image(systemName: "heart").font(.title3).foregroundStyle(.pink)
                            .frame(maxWidth: .infinity, maxHeight: .infinity)
                            .background(Color.pink.opacity(0.08), in: RoundedRectangle(cornerRadius: 10))
                            .flexItem(shrink: 0, width: .points(48), height: .points(48))
                    }
                    .flexItem(shrink: 0, height: .points(48))
                }
                .flexItem(grow: 1, basis: .points(300))
            }
            .frame(maxWidth: .infinity)
        }
    }
}

// MARK: ═════════════════════════════════════════════════════════════════
// MARK: Sample 5 — Kanban Board
// MARK: ═════════════════════════════════════════════════════════════════

private struct KCard { let title: String; let assignee: String; let tag: String; let tagColor: Color }
private let kCols: [(String, Color, [KCard])] = [
    ("To Do", .red, [
        .init(title: "Design login screen",  assignee: "Alice", tag: "Design",  tagColor: .purple),
        .init(title: "Write API docs",       assignee: "Bob",   tag: "Backend", tagColor: .blue),
        .init(title: "Setup CI/CD pipeline", assignee: "Carol", tag: "DevOps",  tagColor: .green),
    ]),
    ("In Progress", .orange, [
        .init(title: "Build flex layout lib", assignee: "Dave", tag: "iOS",    tagColor: .indigo),
        .init(title: "Review PR #42",         assignee: "Eve",  tag: "Review", tagColor: .teal),
    ]),
    ("Done", .green, [
        .init(title: "Ship v1.0 release",   assignee: "Frank", tag: "Release", tagColor: .cyan),
        .init(title: "Fix crash on launch",  assignee: "Grace", tag: "Bug",    tagColor: .red),
        .init(title: "Add dark mode",        assignee: "Hank",  tag: "iOS",    tagColor: .indigo),
        .init(title: "Write unit tests",     assignee: "Ivy",   tag: "Testing",tagColor: .orange),
    ]),
]

private struct KanbanColumn: View {
    let title: String; let color: Color; let cards: [KCard]
    var body: some View {
        FlexBox(direction: .column, alignItems: .stretch, gap: 10,
                padding: EdgeInsets(top: 12, leading: 12, bottom: 12, trailing: 12)) {
            FlexBox(direction: .row, alignItems: .center, gap: 8) {
                Circle().fill(color).frame(width: 8, height: 8)
                    .flexItem(shrink: 0)
                Text(title).font(.headline)
                    .flexItem(grow: 1)
                Text("\(cards.count)")
                    .font(.caption2.weight(.medium)).foregroundStyle(.secondary)
                    .padding(.horizontal, 6).padding(.vertical, 2)
                    .background(Color.gray.opacity(0.12), in: Capsule())
                    .flexItem(shrink: 0)
            }
            .flexItem(shrink: 0)

            ForEach(Array(cards.enumerated()), id: \.offset) { _, card in
                KanbanCardView(card: card)
                    .flexItem(shrink: 0)
            }
        }
        .background(Color.gray.opacity(0.05), in: RoundedRectangle(cornerRadius: 10))
    }
}

private struct KanbanCardView: View {
    let card: KCard
    var body: some View {
        FlexBox(direction: .column, alignItems: .stretch, gap: 8,
                padding: EdgeInsets(top: 10, leading: 12, bottom: 10, trailing: 12)) {
            Text(card.title).font(.subheadline.weight(.medium)).lineLimit(2)
                .flexItem(shrink: 0)
            FlexBox(direction: .row, alignItems: .center, gap: 6) {
                avatar(String(card.assignee.prefix(1)), color: .gray)
                    .flexItem(shrink: 0, width: .points(18), height: .points(18))
                Text(card.assignee).font(.caption).foregroundStyle(.secondary)
                    .flexItem(grow: 1)
                Text(card.tag).font(.caption2.weight(.semibold)).foregroundStyle(.white)
                    .padding(.horizontal, 6).padding(.vertical, 2)
                    .background(card.tagColor, in: RoundedRectangle(cornerRadius: 4))
                    .flexItem(shrink: 0)
            }
            .flexItem(shrink: 0)
        }
        .background(Color(nsColor: .windowBackgroundColor))
        .clipShape(RoundedRectangle(cornerRadius: 8))
        .shadow(color: .black.opacity(0.04), radius: 2, y: 1)
    }
}

struct KanbanBoardSample: View {
    var body: some View {
        FlexBox(direction: .column, gap: 16,
                padding: EdgeInsets(top: 20, leading: 20, bottom: 20, trailing: 20)) {
            FlexBox(direction: .row, alignItems: .center, gap: 12) {
                Text("Project Board").font(.title.bold())
                    .flexItem(grow: 1)
                Image(systemName: "plus.circle.fill").font(.title2).foregroundStyle(.blue)
                    .flexItem(shrink: 0)
            }
            .flexItem(shrink: 0)

            FlexBox(direction: .row, alignItems: .stretch, gap: 14) {
                ForEach(Array(kCols.enumerated()), id: \.offset) { _, col in
                    KanbanColumn(title: col.0, color: col.1, cards: col.2)
                        .flexItem(grow: 1, basis: .points(0))
                }
            }
            .flexItem(grow: 1)
        }
        .frame(maxWidth: .infinity, minHeight: 500)
    }
}
