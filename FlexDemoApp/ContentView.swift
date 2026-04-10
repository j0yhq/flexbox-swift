import SwiftUI
import FlexLayout

// MARK: - Demo Registry

private struct DemoItem: Identifiable {
    let id: String
    let icon: String
    let title: String
    let subtitle: String
}

private let allDemos: [DemoItem] = [
    DemoItem(id: "paste",    icon: "doc.text.magnifyingglass",      title: "CSS → Preview",    subtitle: "paste any flex CSS"),
    DemoItem(id: "sandbox",  icon: "slider.horizontal.3",           title: "Sandbox",          subtitle: "all properties live"),
    DemoItem(id: "hero",     icon: "rectangle.center.inset.filled", title: "Centered Hero",    subtitle: "column · center · gap"),
    DemoItem(id: "navbar",   icon: "menubar.rectangle",             title: "Navigation Bar",   subtitle: "row · space-between"),
    DemoItem(id: "grid",     icon: "square.grid.3x3",               title: "Card Grid",        subtitle: "wrap · flex-start"),
    DemoItem(id: "grail",    icon: "rectangle.split.3x1",           title: "Holy Grail",       subtitle: "fixed sidebars · grow centre"),
    DemoItem(id: "sidebar",  icon: "sidebar.left",                  title: "Sidebar + Content",subtitle: "fixed + flex-grow"),
    DemoItem(id: "grow",     icon: "arrow.left.and.right",          title: "Grow & Shrink",    subtitle: "flex-grow · flex-shrink"),
    DemoItem(id: "align",    icon: "align.vertical.center",         title: "Alignment",        subtitle: "align-self per item"),
    // ── Real App Screens (pure FlexBox, no HStack/VStack) ──
    DemoItem(id: "s-settings", icon: "gearshape.fill",       title: "Settings Page",     subtitle: "pure FlexBox screen"),
    DemoItem(id: "s-chat",     icon: "bubble.left.and.bubble.right.fill", title: "Chat Screen", subtitle: "pure FlexBox screen"),
    DemoItem(id: "s-dash",     icon: "chart.bar.fill",       title: "Dashboard",         subtitle: "pure FlexBox screen"),
    DemoItem(id: "s-product",  icon: "bag.fill",             title: "Product Page",      subtitle: "pure FlexBox screen"),
    DemoItem(id: "s-kanban",   icon: "rectangle.split.3x1.fill", title: "Kanban Board",  subtitle: "pure FlexBox screen"),
    DemoItem(id: "s-pricing", icon: "creditcard.fill",          title: "Pricing Page",  subtitle: "responsive wrap"),
    DemoItem(id: "s-pricing-native", icon: "square.grid.2x2.fill", title: "Pricing Page (Native)", subtitle: "swiftui grid + stack"),
]

// MARK: - Root
// Uses a plain HStack instead of NavigationSplitView to avoid NSSplitView
// constraint issues when running as an SPM executable (no bundle identifier).

struct ContentView: View {
    @State private var selectedId: String = "paste"

    var body: some View {
        HStack(spacing: 0) {

            // ── Sidebar ─────────────────────────────────────────────────────
            VStack(alignment: .leading, spacing: 0) {
                Text("FlexLayout")
                    .font(.title3.weight(.semibold))
                    .padding(.horizontal, 14)
                    .padding(.top, 16)
                    .padding(.bottom, 10)

                Divider()

                ScrollView {
                    VStack(alignment: .leading, spacing: 2) {
                        ForEach(allDemos) { item in
                            SidebarRow(item: item, isSelected: selectedId == item.id)
                                .onTapGesture { selectedId = item.id }
                        }
                    }
                    .padding(8)
                }
            }
            .frame(width: 210)
            .background(Color(nsColor: .controlBackgroundColor))

            Divider()

            // ── Detail ──────────────────────────────────────────────────────
            Group {
                switch selectedId {
                case "paste":   CSSPasteDemo()
                case "hero":    CenteredHeroDemo()
                case "navbar":  NavBarDemo()
                case "grid":    CardGridDemo()
                case "grail":   HolyGrailDemo()
                case "sidebar": SidebarContentDemo()
                case "grow":    GrowShrinkDemo()
                case "align":   AlignmentDemo()
                case "sandbox": SandboxDemo()
                // Real app screens (wrapped in responsive viewport toolbar)
                case "s-settings": ResponsivePreview { SettingsPageSample() }
                case "s-chat":     ResponsivePreview { ChatScreenSample() }
                case "s-dash":     ResponsivePreview { DashboardSample() }
                case "s-product":  ResponsivePreview { ProductPageSample() }
                case "s-kanban":   ResponsivePreview { KanbanBoardSample() }
                case "s-pricing":  ResponsivePreview { PricingPage() }
                case "s-pricing-native": ResponsivePreview { NativePricingPage() }
                default:        Text("Pick a demo").foregroundStyle(.secondary)
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(Color(nsColor: .windowBackgroundColor))
        }
        .ignoresSafeArea()
    }
}

private struct SidebarRow: View {
    let item: DemoItem
    let isSelected: Bool

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: item.icon)
                .foregroundStyle(isSelected ? .white : .blue)
                .frame(width: 20)
            VStack(alignment: .leading, spacing: 1) {
                Text(item.title)
                    .font(.body)
                    .foregroundStyle(isSelected ? .white : .primary)
                Text(item.subtitle)
                    .font(.caption)
                    .foregroundStyle(isSelected ? .white.opacity(0.8) : .secondary)
            }
            Spacer()
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 7)
        .background(isSelected ? Color.accentColor : Color.clear)
        .clipShape(RoundedRectangle(cornerRadius: 7))
        .contentShape(Rectangle())
    }
}

// MARK: - Shared UI Kit

struct DemoBox: View {
    let color: Color
    let label: String
    var minW: CGFloat = 60
    var minH: CGFloat = 40

    var body: some View {
        Text(label)
            .font(.system(size: 11, weight: .semibold))
            .multilineTextAlignment(.center)
            .lineLimit(3)
            .foregroundStyle(.white)
            .padding(6)
            .frame(minWidth: minW, maxWidth: .infinity, minHeight: minH, maxHeight: .infinity)
            .background(color.gradient)
            .clipShape(RoundedRectangle(cornerRadius: 7))
    }
}

struct DemoCanvas<Content: View>: View {
    let content: Content
    init(@ViewBuilder _ content: () -> Content) { self.content = content() }

    var body: some View {
        content
            .padding(12)
            .frame(maxWidth: .infinity)
            .background(Color(white: 0.94))
            .clipShape(RoundedRectangle(cornerRadius: 10))
            .overlay(RoundedRectangle(cornerRadius: 10)
                .strokeBorder(Color.gray.opacity(0.25)))
    }
}

struct PropRow: View {
    let label: String
    let value: String
    var body: some View {
        HStack {
            Text(label).foregroundStyle(.secondary)
            Spacer()
            Text(value)
                .font(.system(.caption, design: .monospaced))
                .padding(.horizontal, 6).padding(.vertical, 2)
                .background(Color.blue.opacity(0.08))
                .clipShape(RoundedRectangle(cornerRadius: 4))
        }
        .font(.caption)
    }
}

struct DemoPage<Canvas: View, Props: View>: View {
    let title: String
    let description: String
    let canvas: Canvas
    let props: Props

    init(
        title: String,
        description: String,
        @ViewBuilder canvas: () -> Canvas,
        @ViewBuilder props: () -> Props
    ) {
        self.title = title
        self.description = description
        self.canvas = canvas()
        self.props = props()
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(title).font(.title2.weight(.semibold))
                    Text(description).font(.subheadline).foregroundStyle(.secondary)
                }
                DemoCanvas { canvas }
                GroupBox("CSS Properties") {
                    VStack(alignment: .leading, spacing: 6) { props }
                        .padding(4)
                }
            }
            .padding(24)
        }
    }
}

// MARK: - Demo 1: Centered Hero

struct CenteredHeroDemo: View {
    var body: some View {
        DemoPage(
            title: "Centered Hero",
            description: "A column flex container that centers all children both horizontally and vertically."
        ) {
            FlexBox(direction: .column, justifyContent: .center, alignItems: .center, gap: 16) {
                DemoBox(color: .indigo, label: "Hero Title",  minW: 200, minH: 52)
                DemoBox(color: .purple, label: "Subtitle",    minW: 160, minH: 36)
                DemoBox(color: .pink,   label: "CTA Button",  minW: 120, minH: 40)
            }
            .frame(maxWidth: .infinity, minHeight: 200)
        } props: {
            PropRow(label: "flex-direction",   value: "column")
            PropRow(label: "justify-content",  value: "center")
            PropRow(label: "align-items",      value: "center")
            PropRow(label: "gap",              value: "16pt")
        }
    }
}

// MARK: - Demo 2: Navigation Bar

struct NavBarDemo: View {
    var body: some View {
        DemoPage(
            title: "Navigation Bar",
            description: "A row container with space-between distribution. A zero-size spacer with flex-grow: 1 pushes nav links to the right."
        ) {
            FlexBox(justifyContent: .spaceBetween, alignItems: .center, gap: 8) {
                DemoBox(color: .blue,  label: "Logo",   minW: 70, minH: 34)
                Color.clear.flexItem(flex: 1)
                DemoBox(color: .cyan,  label: "Home",   minW: 52, minH: 28)
                DemoBox(color: .cyan,  label: "About",  minW: 52, minH: 28)
                DemoBox(color: .cyan,  label: "Docs",   minW: 52, minH: 28)
                DemoBox(color: .green, label: "Sign In", minW: 64, minH: 28)
            }
            .frame(maxWidth: .infinity, minHeight: 60)
        } props: {
            PropRow(label: "flex-direction",  value: "row")
            PropRow(label: "justify-content", value: "space-between")
            PropRow(label: "align-items",     value: "center")
            PropRow(label: "spacer item",     value: "flex-grow: 1")
        }
    }
}

// MARK: - Demo 3: Card Grid

struct CardGridDemo: View {
    @State private var count = 8
    private let colors: [Color] = [.red, .orange, .yellow, .green, .teal, .blue, .indigo, .purple, .pink, .mint, .cyan, .brown]

    var body: some View {
        DemoPage(
            title: "Card Grid",
            description: "flex-wrap: wrap lets items flow onto new lines. Each card has a fixed flex-basis and shrink: 0."
        ) {
            VStack(alignment: .leading, spacing: 8) {
                FlexBox(wrap: .wrap, justifyContent: .flexStart, alignItems: .flexStart, gap: 10) {
                    ForEach(0..<count, id: \.self) { i in
                        DemoBox(color: colors[i % colors.count], label: "Card \(i + 1)", minW: 100, minH: 70)
                            .flexItem(shrink: 0, basis: .points(100))
                    }
                }
                .frame(maxWidth: .infinity)

                HStack {
                    Text("Items: \(count)").font(.caption).foregroundStyle(.secondary)
                    Slider(value: Binding(get: { Double(count) }, set: { count = Int($0) }), in: 1...12, step: 1)
                }
            }
        } props: {
            PropRow(label: "flex-direction",  value: "row")
            PropRow(label: "flex-wrap",       value: "wrap")
            PropRow(label: "justify-content", value: "flex-start")
            PropRow(label: "gap",             value: "10pt")
            PropRow(label: "item flex-basis", value: "100pt")
            PropRow(label: "item flex-shrink",value: "0")
        }
    }
}

// MARK: - Demo 4: Holy Grail

struct HolyGrailDemo: View {
    var body: some View {
        DemoPage(
            title: "Holy Grail Layout",
            description: "Two fixed-width sidebars with a flex-grow: 1 centre column that fills all remaining space."
        ) {
            FlexBox(alignItems: .stretch, gap: 8) {
                DemoBox(color: .teal,   label: "Left\nSidebar\n80pt", minW: 0, minH: 0)
                    .flexItem(shrink: 0, basis: .points(80), alignSelf: .stretch)
                DemoBox(color: .indigo, label: "Main Content\n(flex-grow: 1)", minW: 0, minH: 0)
                    .flexItem(flex: 1)
                DemoBox(color: .teal,   label: "Right\nSidebar\n80pt", minW: 0, minH: 0)
                    .flexItem(shrink: 0, basis: .points(80), alignSelf: .stretch)
            }
            .frame(maxWidth: .infinity, minHeight: 130)
        } props: {
            PropRow(label: "flex-direction",        value: "row")
            PropRow(label: "align-items",           value: "stretch")
            PropRow(label: "sidebar flex-basis",    value: "80pt")
            PropRow(label: "sidebar flex-shrink",   value: "0")
            PropRow(label: "content flex-grow",     value: "1")
        }
    }
}

// MARK: - Demo 5: Sidebar + Content

struct SidebarContentDemo: View {
    @State private var sidebarWidth: CGFloat = 160

    var body: some View {
        DemoPage(
            title: "Sidebar + Content",
            description: "Fixed-width sidebar (flex-shrink: 0) alongside a flex-grow: 1 content area. Drag the slider to resize."
        ) {
            VStack(alignment: .leading, spacing: 8) {
                FlexBox(alignItems: .stretch, gap: 8) {
                    DemoBox(color: .orange, label: "Sidebar\n\(Int(sidebarWidth))pt", minW: 0, minH: 0)
                        .flexItem(shrink: 0, basis: .points(sidebarWidth), alignSelf: .stretch)
                    DemoBox(color: .mint,   label: "Content (grows)", minW: 0, minH: 0)
                        .flexItem(flex: 1)
                }
                .frame(maxWidth: .infinity, minHeight: 110)

                HStack {
                    Text("Sidebar: \(Int(sidebarWidth))pt").font(.caption).foregroundStyle(.secondary)
                    Slider(value: $sidebarWidth, in: 80...300)
                }
            }
        } props: {
            PropRow(label: "flex-direction",       value: "row")
            PropRow(label: "sidebar flex-basis",   value: "\(Int(sidebarWidth))pt")
            PropRow(label: "sidebar flex-shrink",  value: "0")
            PropRow(label: "content flex-grow",    value: "1")
        }
    }
}

// MARK: - Demo 6: Grow & Shrink

struct GrowShrinkDemo: View {
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                Text("Grow & Shrink").font(.title2.weight(.semibold))
                Text("flex-grow distributes positive free space. flex-shrink distributes overflow proportionally by shrink × basis.")
                    .font(.subheadline).foregroundStyle(.secondary)

                // Grow
                GroupBox("flex-grow  —  ratios 1 : 2 : 3") {
                    VStack(alignment: .leading, spacing: 10) {
                        DemoCanvas {
                            FlexBox(alignItems: .center, gap: 6) {
                                DemoBox(color: .red,    label: "grow: 1", minW: 0, minH: 36)
                                    .flexItem(grow: 1, basis: .points(40))
                                DemoBox(color: .orange, label: "grow: 2", minW: 0, minH: 36)
                                    .flexItem(grow: 2, basis: .points(40))
                                DemoBox(color: .green,  label: "grow: 3", minW: 0, minH: 36)
                                    .flexItem(grow: 3, basis: .points(40))
                            }
                            .frame(maxWidth: .infinity)
                        }
                        Text("All items start at basis: 40pt, then remaining space is split 1:2:3")
                            .font(.caption).foregroundStyle(.secondary)
                    }.padding(8)
                }

                // Shrink
                GroupBox("flex-shrink  —  shrink: 1 / 2 / 0") {
                    VStack(alignment: .leading, spacing: 10) {
                        DemoCanvas {
                            FlexBox(alignItems: .center, gap: 4) {
                                DemoBox(color: .blue,   label: "shrink: 1", minW: 0, minH: 36)
                                    .flexItem(shrink: 1, basis: .points(240))
                                DemoBox(color: .purple, label: "shrink: 2", minW: 0, minH: 36)
                                    .flexItem(shrink: 2, basis: .points(240))
                                DemoBox(color: .pink,   label: "shrink: 0\n(no shrink)", minW: 0, minH: 36)
                                    .flexItem(shrink: 0, basis: .points(240))
                            }
                            .frame(maxWidth: .infinity)
                        }
                        Text("All items start at basis: 240pt. Purple shrinks twice as fast as blue. Pink refuses to shrink.")
                            .font(.caption).foregroundStyle(.secondary)
                    }.padding(8)
                }

                // flex shorthand
                GroupBox("flex: 1 shorthand  —  equal columns") {
                    VStack(alignment: .leading, spacing: 10) {
                        DemoCanvas {
                            FlexBox(gap: 6) {
                                ForEach(["Col A", "Col B", "Col C", "Col D"], id: \.self) { label in
                                    DemoBox(color: .teal, label: label, minW: 0, minH: 44)
                                        .flexItem(flex: 1)
                                }
                            }
                            .frame(maxWidth: .infinity)
                        }
                        Text(".flexItem(flex: 1) expands to grow:1, shrink:1, basis: .points(0)")
                            .font(.caption).foregroundStyle(.secondary)
                    }.padding(8)
                }
            }
            .padding(24)
        }
    }
}

// MARK: - Demo 7: Alignment

struct AlignmentDemo: View {
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                Text("Alignment").font(.title2.weight(.semibold))
                Text("align-items sets the default cross-axis alignment. align-self overrides it per item.")
                    .font(.subheadline).foregroundStyle(.secondary)

                GroupBox("align-self overrides per item") {
                    DemoCanvas {
                        FlexBox(justifyContent: .spaceEvenly, alignItems: .stretch, gap: 6) {
                            VStack(spacing: 2) {
                                DemoBox(color: .red,    label: "flex\nStart", minW: 72, minH: 28)
                                    .flexItem(alignSelf: .flexStart)
                                Text("flexStart").font(.system(size: 9)).foregroundStyle(.secondary)
                            }
                            VStack(spacing: 2) {
                                DemoBox(color: .orange, label: "center", minW: 72, minH: 28)
                                    .flexItem(alignSelf: .center)
                                Text("center").font(.system(size: 9)).foregroundStyle(.secondary)
                            }
                            VStack(spacing: 2) {
                                DemoBox(color: .green,  label: "flex\nEnd", minW: 72, minH: 28)
                                    .flexItem(alignSelf: .flexEnd)
                                Text("flexEnd").font(.system(size: 9)).foregroundStyle(.secondary)
                            }
                            VStack(spacing: 2) {
                                DemoBox(color: .blue,   label: "stretch\n(fills)", minW: 72, minH: 0)
                                    .flexItem(alignSelf: .stretch)
                                Text("stretch").font(.system(size: 9)).foregroundStyle(.secondary)
                            }
                            VStack(spacing: 2) {
                                DemoBox(color: .purple, label: "baseline", minW: 72, minH: 28)
                                    .flexItem(alignSelf: .baseline)
                                Text("baseline").font(.system(size: 9)).foregroundStyle(.secondary)
                            }
                        }
                        .frame(maxWidth: .infinity, minHeight: 110)
                    }
                    .padding(8)
                }

                GroupBox("justify-content — all 6 values") {
                    VStack(spacing: 10) {
                        ForEach([
                            (JustifyContent.flexStart,   "flex-start"),
                            (.flexEnd,                    "flex-end"),
                            (.center,                     "center"),
                            (.spaceBetween,               "space-between"),
                            (.spaceAround,                "space-around"),
                            (.spaceEvenly,                "space-evenly"),
                        ], id: \.1) { justify, label in
                            VStack(alignment: .leading, spacing: 3) {
                                Text(label)
                                    .font(.system(.caption, design: .monospaced))
                                    .foregroundStyle(.secondary)
                                DemoCanvas {
                                    FlexBox(justifyContent: justify, alignItems: .center) {
                                        ForEach(["A","B","C"], id: \.self) { t in
                                            DemoBox(color: .blue, label: t, minW: 48, minH: 32)
                                        }
                                    }
                                    .frame(maxWidth: .infinity)
                                }
                            }
                        }
                    }
                    .padding(8)
                }

                GroupBox("CSS order property") {
                    VStack(alignment: .leading, spacing: 6) {
                        Text("Source order: A B C D E   →   Visual order: C A E B D")
                            .font(.caption).foregroundStyle(.secondary)
                        DemoCanvas {
                            FlexBox(justifyContent: .center, alignItems: .center, gap: 8) {
                                DemoBox(color: .red,    label: "A\norder:2", minW: 72, minH: 44).flexItem(order: 2)
                                DemoBox(color: .orange, label: "B\norder:4", minW: 72, minH: 44).flexItem(order: 4)
                                DemoBox(color: .yellow, label: "C\norder:1", minW: 72, minH: 44).flexItem(order: 1)
                                DemoBox(color: .green,  label: "D\norder:5", minW: 72, minH: 44).flexItem(order: 5)
                                DemoBox(color: .blue,   label: "E\norder:3", minW: 72, minH: 44).flexItem(order: 3)
                            }
                            .frame(maxWidth: .infinity)
                        }
                    }
                    .padding(8)
                }
            }
            .padding(24)
        }
    }
}

// MARK: - Demo 8: Sandbox (fully interactive)

private let sandboxColors: [Color] = [.red, .orange, .yellow, .green, .teal, .blue, .indigo, .purple]

struct SandboxDemo: View {
    // Container
    @State private var direction:      FlexDirection  = .row
    @State private var wrap:           FlexWrap       = .nowrap
    @State private var justifyContent: JustifyContent = .flexStart
    @State private var alignItems:     AlignItems     = .stretch
    @State private var alignContent:   AlignContent   = .stretch
    @State private var gap:            CGFloat        = 8

    // Items
    @State private var itemCount:  Int = 4
    @State private var itemGrow:   CGFloat = 0
    @State private var itemShrink: CGFloat = 1
    @State private var basisMode:  Int = 0   // 0=auto 1=points 2=fraction
    @State private var basisPts:   CGFloat = 100
    @State private var basisFrac:  CGFloat = 0.25

    private var flexBasis: FlexBasis {
        switch basisMode {
        case 1: return .points(basisPts)
        case 2: return .fraction(basisFrac)
        default: return .auto
        }
    }

    var body: some View {
        HSplitView {
            // ── Controls ────────────────────────────────────────────────────
            ScrollView {
                VStack(alignment: .leading, spacing: 0) {
                    ControlSection("Container") {
                        EnumPicker("flex-direction",   selection: $direction)
                        EnumPicker("flex-wrap",        selection: $wrap)
                        EnumPicker("justify-content",  selection: $justifyContent)
                        EnumPicker("align-items",      selection: $alignItems)
                        EnumPicker("align-content",    selection: $alignContent)
                        SliderRow("gap", value: $gap, range: 0...40, format: "%.0fpt")
                    }
                    Divider().padding(.vertical, 8)
                    ControlSection("Items (all)") {
                        SliderRow("flex-grow",   value: $itemGrow,   range: 0...5, format: "%.1f")
                        SliderRow("flex-shrink", value: $itemShrink, range: 0...5, format: "%.1f")
                        VStack(alignment: .leading, spacing: 4) {
                            Text("flex-basis").font(.caption).foregroundStyle(.secondary)
                            Picker("", selection: $basisMode) {
                                Text("auto").tag(0)
                                Text("points").tag(1)
                                Text("fraction").tag(2)
                            }
                            .pickerStyle(.segmented)
                            if basisMode == 1 {
                                SliderRow("pts", value: $basisPts, range: 20...300, format: "%.0f")
                            } else if basisMode == 2 {
                                SliderRow("%", value: $basisFrac, range: 0.05...0.9, format: "%.0f%%",
                                          displayTransform: { $0 * 100 })
                            }
                        }
                        SliderRow("item count", value: Binding(
                            get: { Double(itemCount) },
                            set: { itemCount = Int($0) }
                        ), range: 1...8, format: "%.0f")
                    }
                }
                .padding(14)
            }
            .frame(minWidth: 240, maxWidth: 280)
            .background(Color(nsColor: .controlBackgroundColor))

            // ── Preview + CSS output ─────────────────────────────────────────
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    // Live preview
                    FlexBox(
                        direction:      direction,
                        wrap:           wrap,
                        justifyContent: justifyContent,
                        alignItems:     alignItems,
                        alignContent:   alignContent,
                        gap:            gap
                    ) {
                        ForEach(0..<itemCount, id: \.self) { i in
                            DemoBox(
                                color: sandboxColors[i % sandboxColors.count],
                                label: "Item \(i + 1)",
                                minW: basisMode == 0 ? 60 : 0,
                                minH: 50
                            )
                            .flexItem(
                                grow:   itemGrow,
                                shrink: itemShrink,
                                basis:  flexBasis
                            )
                        }
                    }
                    .frame(maxWidth: .infinity, minHeight: 160)
                    .padding(12)
                    .background(Color(white: 0.94))
                    .clipShape(RoundedRectangle(cornerRadius: 10))
                    .overlay(RoundedRectangle(cornerRadius: 10)
                        .strokeBorder(Color.gray.opacity(0.25)))

                    // Generated CSS
                    GroupBox("Generated CSS") {
                        Text(generatedCSS)
                            .font(.system(.footnote, design: .monospaced))
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(10)
                            .background(Color(white: 0.96))
                            .clipShape(RoundedRectangle(cornerRadius: 6))
                    }
                }
                .padding(20)
            }
        }
    }

    // MARK: Generated CSS

    private var generatedCSS: String {
        var lines = [
            ".container {",
            "  display: flex;",
            "  flex-direction: \(direction.cssName);",
        ]
        if wrap != .nowrap        { lines.append("  flex-wrap: \(wrap.cssName);") }
        if justifyContent != .flexStart { lines.append("  justify-content: \(justifyContent.cssName);") }
        if alignItems != .stretch { lines.append("  align-items: \(alignItems.cssName);") }
        if wrap != .nowrap && alignContent != .stretch { lines.append("  align-content: \(alignContent.cssName);") }
        if gap > 0               { lines.append("  gap: \(Int(gap))px;") }
        lines.append("}")
        lines.append("")
        lines.append(".item {")
        if itemGrow   != 0       { lines.append("  flex-grow: \(formatNum(itemGrow));") }
        if itemShrink != 1       { lines.append("  flex-shrink: \(formatNum(itemShrink));") }
        switch flexBasis {
        case .auto:              break
        case .points(let n):     lines.append("  flex-basis: \(Int(n))px;")
        case .fraction(let f):   lines.append("  flex-basis: \(Int(f * 100))%;")
        }
        lines.append("}")
        return lines.joined(separator: "\n")
    }

    private func formatNum(_ n: CGFloat) -> String {
        n.truncatingRemainder(dividingBy: 1) == 0 ? "\(Int(n))" : String(format: "%.1f", n)
    }
}

// MARK: - Sandbox sub-components

private struct ControlSection<Content: View>: View {
    let title: String
    let content: Content
    init(_ title: String, @ViewBuilder content: () -> Content) {
        self.title = title; self.content = content()
    }
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title).font(.caption.weight(.semibold)).foregroundStyle(.secondary).textCase(.uppercase)
            content
        }
    }
}

private struct SliderRow: View {
    let label: String
    let binding: Binding<Double>
    let range: ClosedRange<Double>
    let format: String
    let displayTransform: (Double) -> Double

    init(_ label: String, value: Binding<CGFloat>, range: ClosedRange<Double>,
         format: String, displayTransform: @escaping (Double) -> Double = { $0 }) {
        self.label = label
        self.binding = Binding(get: { Double(value.wrappedValue) }, set: { value.wrappedValue = CGFloat($0) })
        self.range = range
        self.format = format
        self.displayTransform = displayTransform
    }

    init(_ label: String, value: Binding<Double>, range: ClosedRange<Double>,
         format: String, displayTransform: @escaping (Double) -> Double = { $0 }) {
        self.label = label
        self.binding = value
        self.range = range
        self.format = format
        self.displayTransform = displayTransform
    }

    var body: some View {
        HStack {
            Text(label).font(.caption).foregroundStyle(.secondary).frame(width: 80, alignment: .leading)
            Slider(value: binding, in: range)
            Text(String(format: format, displayTransform(binding.wrappedValue)))
                .font(.system(.caption, design: .monospaced))
                .frame(width: 44, alignment: .trailing)
        }
    }
}

private struct EnumPicker<T: CaseIterable & Hashable & CustomStringConvertible>: View {
    let label: String
    let selection: Binding<T>

    init(_ label: String, selection: Binding<T>) {
        self.label = label; self.selection = selection
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(label).font(.caption).foregroundStyle(.secondary)
            Picker("", selection: selection) {
                ForEach(Array(T.allCases as! [T]), id: \.self) { val in
                    Text(val.description).tag(val)
                }
            }
            .labelsHidden()
        }
    }
}

// MARK: - CustomStringConvertible for CSS names in Picker

extension FlexDirection: CustomStringConvertible {
    public var description: String { cssName }
    var cssName: String {
        switch self {
        case .row:           return "row"
        case .rowReverse:    return "row-reverse"
        case .column:        return "column"
        case .columnReverse: return "column-reverse"
        }
    }
}

extension FlexWrap: CustomStringConvertible {
    public var description: String { cssName }
    var cssName: String {
        switch self {
        case .nowrap:      return "nowrap"
        case .wrap:        return "wrap"
        case .wrapReverse: return "wrap-reverse"
        }
    }
}

extension JustifyContent: CustomStringConvertible {
    public var description: String { cssName }
    var cssName: String {
        switch self {
        case .flexStart:   return "flex-start"
        case .flexEnd:     return "flex-end"
        case .center:      return "center"
        case .spaceBetween:return "space-between"
        case .spaceAround: return "space-around"
        case .spaceEvenly: return "space-evenly"
        }
    }
}

extension AlignItems: CustomStringConvertible {
    public var description: String { cssName }
    var cssName: String {
        switch self {
        case .flexStart: return "flex-start"
        case .flexEnd:   return "flex-end"
        case .center:    return "center"
        case .stretch:   return "stretch"
        case .baseline:  return "baseline"
        }
    }
}

extension AlignContent: CustomStringConvertible {
    public var description: String { cssName }
    var cssName: String {
        switch self {
        case .flexStart:    return "flex-start"
        case .flexEnd:      return "flex-end"
        case .center:       return "center"
        case .spaceBetween: return "space-between"
        case .spaceAround:  return "space-around"
        case .spaceEvenly:  return "space-evenly"
        case .stretch:      return "stretch"
        }
    }
}

extension AlignSelf: CustomStringConvertible {
    public var description: String {
        switch self {
        case .auto:      return "auto"
        case .flexStart: return "flex-start"
        case .flexEnd:   return "flex-end"
        case .center:    return "center"
        case .stretch:   return "stretch"
        case .baseline:  return "baseline"
        }
    }
}
