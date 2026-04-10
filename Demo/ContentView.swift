/// FlexLayout Demo — mirrors the 5 presets from the web-based Flexbox builder.
///
/// Paste this file into any iOS 16+ / macOS 13+ SwiftUI project that has
/// the FlexLayout package added as a dependency.

import SwiftUI
import FlexLayout

struct ContentView: View {
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 32) {
                Group {
                    SectionHeader("1 · Centered Hero")
                    CenteredHeroPreset()

                    SectionHeader("2 · Navigation Bar")
                    NavigationBarPreset()

                    SectionHeader("3 · Card Grid")
                    CardGridPreset()
                }
                Group {
                    SectionHeader("4 · Holy Grail")
                    HolyGrailPreset()

                    SectionHeader("5 · Sidebar + Content")
                    SidebarContentPreset()
                }
            }
            .padding(24)
        }
        .background(Color(white: 0.95))
    }
}

// MARK: - Preset 1: Centered Hero
// flex-direction: column; justify-content: center; align-items: center; gap: 16

struct CenteredHeroPreset: View {
    var body: some View {
        FlexBox(
            direction:      .column,
            justifyContent: .center,
            alignItems:     .center,
            gap:            16
        ) {
            FlexCard(color: .indigo,  label: "Hero Title",    width: 220, height: 52)
            FlexCard(color: .purple,  label: "Subtitle",      width: 160, height: 36)
            FlexCard(color: .pink,    label: "CTA Button",    width: 120, height: 44)
        }
        .frame(width: 320, height: 200)
        .containerStyle()
    }
}

// MARK: - Preset 2: Navigation Bar
// flex-direction: row; justify-content: space-between; align-items: center

struct NavigationBarPreset: View {
    var body: some View {
        FlexBox(
            justifyContent: .spaceBetween,
            alignItems:     .center
        ) {
            FlexCard(color: .blue,    label: "Logo",  width: 80, height: 36)
            // Spacer grows to fill available space
            Color.clear.flexItem(flex: 1)
            FlexCard(color: .cyan,    label: "Home",  width: 60, height: 32)
            FlexCard(color: .cyan,    label: "About", width: 60, height: 32)
            FlexCard(color: .green,   label: "Login", width: 70, height: 32)
        }
        .frame(maxWidth: .infinity, minHeight: 56)
        .containerStyle()
    }
}

// MARK: - Preset 3: Card Grid
// flex-direction: row; flex-wrap: wrap; justify-content: flex-start; gap: 12

struct CardGridPreset: View {
    let items = Array(1...6)

    var body: some View {
        FlexBox(
            wrap:           .wrap,
            justifyContent: .flexStart,
            alignItems:     .flexStart,
            gap:            12
        ) {
            ForEach(items, id: \.self) { i in
                FlexCard(
                    color:  cardColor(i),
                    label:  "Card \(i)",
                    width:  120,
                    height: 80
                )
                .flexItem(basis: .points(120), shrink: 0)
            }
        }
        .frame(maxWidth: .infinity)
        .containerStyle()
    }

    func cardColor(_ i: Int) -> Color {
        [Color.red, .orange, .yellow, .green, .blue, .purple][i - 1]
    }
}

// MARK: - Preset 4: Holy Grail
// row | left sidebar (fixed) + main content (grow:1) + right sidebar (fixed)

struct HolyGrailPreset: View {
    var body: some View {
        FlexBox(
            justifyContent: .flexStart,
            alignItems:     .stretch,
            gap:            0
        ) {
            // Left sidebar
            FlexCard(color: .teal,    label: "Left\nSidebar",  width: 0, height: 0)
                .flexItem(basis: .points(80), shrink: 0, grow: 0, alignSelf: .stretch)

            // Main content
            FlexCard(color: .indigo,  label: "Main Content",   width: 0, height: 0)
                .flexItem(grow: 1, shrink: 1)

            // Right sidebar
            FlexCard(color: .teal,    label: "Right\nSidebar", width: 0, height: 0)
                .flexItem(basis: .points(80), shrink: 0, grow: 0, alignSelf: .stretch)
        }
        .frame(maxWidth: .infinity, minHeight: 120)
        .containerStyle()
    }
}

// MARK: - Preset 5: Sidebar + Content
// row | fixed left panel + flex-grow right area

struct SidebarContentPreset: View {
    var body: some View {
        FlexBox(
            justifyContent: .flexStart,
            alignItems:     .stretch,
            gap:            8
        ) {
            // Fixed sidebar
            FlexCard(color: .orange,  label: "Sidebar\n240 pt", width: 0, height: 0)
                .flexItem(basis: .points(140), shrink: 0, grow: 0, alignSelf: .stretch)

            // Flexible content area
            FlexCard(color: .mint,    label: "Content Area (grows)", width: 0, height: 0)
                .flexItem(grow: 1, shrink: 1)
        }
        .frame(maxWidth: .infinity, minHeight: 100)
        .containerStyle()
    }
}

// MARK: - Shared Helpers

struct FlexCard: View {
    let color:  Color
    let label:  String
    var width:  CGFloat
    var height: CGFloat

    var body: some View {
        Text(label)
            .font(.caption.weight(.semibold))
            .multilineTextAlignment(.center)
            .foregroundStyle(.white)
            .padding(6)
            .frame(
                minWidth:  width  > 0 ? width  : nil,
                minHeight: height > 0 ? height : nil,
                maxWidth:  width  > 0 ? width  : .infinity,
                maxHeight: height > 0 ? height : .infinity
            )
            .background(color.gradient)
            .clipShape(RoundedRectangle(cornerRadius: 8))
    }
}

struct SectionHeader: View {
    let title: String
    init(_ title: String) { self.title = title }

    var body: some View {
        Text(title)
            .font(.headline)
            .foregroundStyle(.secondary)
    }
}

extension View {
    func containerStyle() -> some View {
        self
            .padding(12)
            .background(Color.white)
            .clipShape(RoundedRectangle(cornerRadius: 12))
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .strokeBorder(Color.gray.opacity(0.25), lineWidth: 1)
            )
    }
}

#Preview {
    ContentView()
}
