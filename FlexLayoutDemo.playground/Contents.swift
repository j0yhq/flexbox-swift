import PlaygroundSupport
import SwiftUI

// ─────────────────────────────────────────────────────────────────────────────
// FlexLayout Playground
//
// Run the playground (⌘⇧↩ or ▶ button) to see a live preview of each demo.
// Edit any FlexBox property and re-run to see the change instantly.
// ─────────────────────────────────────────────────────────────────────────────

// MARK: - Interactive Demo Picker

struct PlaygroundRoot: View {
    @State private var selected = 0

    let demos: [(String, AnyView)] = [
        ("Centered Hero",   AnyView(CenteredHeroDemo())),
        ("Navigation Bar",  AnyView(NavBarDemo())),
        ("Card Grid",       AnyView(CardGridDemo())),
        ("Holy Grail",      AnyView(HolyGrailDemo())),
        ("Sidebar+Content", AnyView(SidebarDemo())),
        ("Grow & Shrink",   AnyView(GrowShrinkDemo())),
        ("align-self",      AnyView(AlignSelfDemo())),
        ("order",           AnyView(OrderDemo())),
    ]

    var body: some View {
        VStack(spacing: 0) {
            // Tab strip
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 4) {
                    ForEach(demos.indices, id: \.self) { i in
                        Button(demos[i].0) { selected = i }
                            .buttonStyle(.plain)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 6)
                            .background(selected == i ? Color.accentColor : Color.clear)
                            .foregroundStyle(selected == i ? .white : .primary)
                            .clipShape(Capsule())
                    }
                }
                .padding(8)
            }
            .background(Color(white: 0.93))

            Divider()

            // Demo body
            ScrollView {
                demos[selected].1
                    .padding(20)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(Color(white: 0.97))
        }
        .frame(width: 640, height: 520)
    }
}

// MARK: - 1. Centered Hero
// column · justify-content: center · align-items: center · gap: 16

struct CenteredHeroDemo: View {
    var body: some View {
        DemoCard(title: "flex-direction: column  |  justify-content: center  |  align-items: center  |  gap: 16") {
            FlexBox(
                direction:      .column,
                justifyContent: .center,
                alignItems:     .center,
                gap:            16
            ) {
                Chip(color: .indigo, text: "Hero Title",  w: 200, h: 52)
                Chip(color: .purple, text: "Subtitle",    w: 150, h: 36)
                Chip(color: .pink,   text: "CTA Button",  w: 110, h: 40)
            }
            .frame(maxWidth: .infinity, minHeight: 180)
        }
    }
}

// MARK: - 2. Navigation Bar
// row · justify-content: space-between · align-items: center

struct NavBarDemo: View {
    var body: some View {
        DemoCard(title: "flex-direction: row  |  justify-content: space-between  |  align-items: center") {
            FlexBox(
                justifyContent: .spaceBetween,
                alignItems:     .center
            ) {
                Chip(color: .blue,   text: "Logo",    w: 70, h: 32)
                Color.clear.flexItem(flex: 1)           // spacer
                Chip(color: .cyan,   text: "Home",    w: 55, h: 28)
                Chip(color: .cyan,   text: "About",   w: 55, h: 28)
                Chip(color: .green,  text: "Sign In", w: 65, h: 28)
            }
            .frame(maxWidth: .infinity, minHeight: 56)
        }
    }
}

// MARK: - 3. Card Grid
// row · flex-wrap: wrap · justify-content: flex-start · gap: 12

struct CardGridDemo: View {
    let colors: [Color] = [.red, .orange, .yellow, .green, .blue, .purple,
                           .pink, .teal, .indigo, .mint, .cyan, .brown]
    var body: some View {
        DemoCard(title: "flex-wrap: wrap  |  justify-content: flexStart  |  gap: 12") {
            FlexBox(wrap: .wrap, justifyContent: .flexStart, gap: 12) {
                ForEach(0..<12) { i in
                    Chip(color: colors[i], text: "Item \(i + 1)", w: 100, h: 64)
                        .flexItem(shrink: 0, basis: .points(100))
                }
            }
            .frame(maxWidth: .infinity)
        }
    }
}

// MARK: - 4. Holy Grail
// row · left sidebar (fixed) + main (grow:1) + right sidebar (fixed)

struct HolyGrailDemo: View {
    var body: some View {
        DemoCard(title: "Holy Grail: fixed sidebars + flex-grow: 1 centre") {
            FlexBox(alignItems: .stretch) {
                Chip(color: .teal,   text: "Left\n72pt",  w: 0, h: 0)
                    .flexItem(shrink: 0, basis: .points(72), alignSelf: .stretch)
                Chip(color: .indigo, text: "Content (flex-grow: 1)", w: 0, h: 0)
                    .flexItem(flex: 1)
                Chip(color: .teal,   text: "Right\n72pt", w: 0, h: 0)
                    .flexItem(shrink: 0, basis: .points(72), alignSelf: .stretch)
            }
            .frame(maxWidth: .infinity, minHeight: 100)
        }
    }
}

// MARK: - 5. Sidebar + Content
// row · fixed sidebar + flex-grow content

struct SidebarDemo: View {
    var body: some View {
        DemoCard(title: "Sidebar (fixed 160pt) + Content (flex-grow: 1)") {
            FlexBox(alignItems: .stretch, gap: 8) {
                Chip(color: .orange, text: "Sidebar\n160pt", w: 0, h: 0)
                    .flexItem(shrink: 0, basis: .points(160), alignSelf: .stretch)
                Chip(color: .mint,   text: "Main Content\n(grows)", w: 0, h: 0)
                    .flexItem(flex: 1)
            }
            .frame(maxWidth: .infinity, minHeight: 100)
        }
    }
}

// MARK: - 6. Grow & Shrink
// Demonstrates flex-grow and flex-shrink ratios

struct GrowShrinkDemo: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            DemoCard(title: "flex-grow: 1 / 2 / 3  (total free space split 1:2:3)") {
                FlexBox(alignItems: .center, gap: 8) {
                    Chip(color: .red,    text: "grow:1", w: 0, h: 36)
                        .flexItem(grow: 1, basis: .points(40))
                    Chip(color: .orange, text: "grow:2", w: 0, h: 36)
                        .flexItem(grow: 2, basis: .points(40))
                    Chip(color: .green,  text: "grow:3", w: 0, h: 36)
                        .flexItem(grow: 3, basis: .points(40))
                }
                .frame(maxWidth: .infinity)
            }

            DemoCard(title: "flex-shrink: 1 / 2 / 0  (overflow distributed by shrink weight)") {
                FlexBox(alignItems: .center, gap: 4) {
                    Chip(color: .blue,   text: "shrink:1", w: 0, h: 36)
                        .flexItem(shrink: 1, basis: .points(200))
                    Chip(color: .purple, text: "shrink:2", w: 0, h: 36)
                        .flexItem(shrink: 2, basis: .points(200))
                    Chip(color: .pink,   text: "shrink:0", w: 0, h: 36)
                        .flexItem(shrink: 0, basis: .points(200))
                }
                .frame(maxWidth: .infinity)
            }
        }
    }
}

// MARK: - 7. align-self
// Each item overrides align-items with its own cross-axis alignment

struct AlignSelfDemo: View {
    var body: some View {
        DemoCard(title: "align-items: stretch  |  each item overrides with align-self") {
            FlexBox(
                justifyContent: .spaceEvenly,
                alignItems:     .stretch,
                gap:            8
            ) {
                Chip(color: .red,    text: "flexStart",  w: 80, h: 30)
                    .flexItem(alignSelf: .flexStart)
                Chip(color: .orange, text: "center",     w: 80, h: 30)
                    .flexItem(alignSelf: .center)
                Chip(color: .green,  text: "flexEnd",    w: 80, h: 30)
                    .flexItem(alignSelf: .flexEnd)
                Chip(color: .blue,   text: "stretch",    w: 80, h: 0)
                    .flexItem(alignSelf: .stretch)
                Chip(color: .purple, text: "baseline",   w: 80, h: 30)
                    .flexItem(alignSelf: .baseline)
            }
            .frame(maxWidth: .infinity, minHeight: 120)
        }
    }
}

// MARK: - 8. order
// Visual order differs from source order

struct OrderDemo: View {
    var body: some View {
        DemoCard(title: "CSS order property  |  source: A B C D E  →  visual: C A E B D") {
            FlexBox(justifyContent: .center, alignItems: .center, gap: 8) {
                Chip(color: .red,    text: "A (order:2)",  w: 80, h: 44).flexItem(order: 2)
                Chip(color: .orange, text: "B (order:4)",  w: 80, h: 44).flexItem(order: 4)
                Chip(color: .yellow, text: "C (order:1)",  w: 80, h: 44).flexItem(order: 1)
                Chip(color: .green,  text: "D (order:5)",  w: 80, h: 44).flexItem(order: 5)
                Chip(color: .blue,   text: "E (order:3)",  w: 80, h: 44).flexItem(order: 3)
            }
            .frame(maxWidth: .infinity, minHeight: 60)
        }
    }
}

// MARK: - Shared Components

struct Chip: View {
    let color: Color
    let text:  String
    var w: CGFloat
    var h: CGFloat

    var body: some View {
        Text(text)
            .font(.system(size: 11, weight: .semibold))
            .multilineTextAlignment(.center)
            .foregroundStyle(.white)
            .padding(6)
            .frame(
                minWidth:  w > 0 ? w : nil,
                maxWidth:  w > 0 ? w : .infinity,
                minHeight: h > 0 ? h : nil,
                maxHeight: h > 0 ? h : .infinity
            )
            .background(color.gradient)
            .clipShape(RoundedRectangle(cornerRadius: 8))
    }
}

struct DemoCard<Content: View>: View {
    let title:   String
    let content: Content
    init(title: String, @ViewBuilder content: () -> Content) {
        self.title = title; self.content = content()
    }
    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(title)
                .font(.system(size: 10, design: .monospaced))
                .foregroundStyle(.secondary)
            content
        }
        .padding(14)
        .background(Color.white)
        .clipShape(RoundedRectangle(cornerRadius: 10))
        .shadow(color: .black.opacity(0.06), radius: 4, y: 2)
    }
}

// MARK: - Launch

PlaygroundPage.current.setLiveView(PlaygroundRoot())
