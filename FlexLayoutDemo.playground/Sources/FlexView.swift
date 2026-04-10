import SwiftUI

/// A SwiftUI view that arranges its children using the CSS Flexbox layout model.
///
/// `FlexBox` is a thin wrapper around `FlexLayout` that exposes all container
/// properties as labeled initialiser parameters, mirroring the CSS API.
///
/// ```swift
/// // Navigation bar
/// FlexBox(justifyContent: .spaceBetween, alignItems: .center) {
///     Text("Logo")
///     Spacer().flexItem(grow: 1)
///     Text("Menu")
/// }
///
/// // Wrapping card grid
/// FlexBox(wrap: .wrap, justifyContent: .flexStart, gap: 12) {
///     ForEach(items) { item in
///         CardView(item: item)
///             .flexItem(basis: .points(160), shrink: 0)
///     }
/// }
/// ```
public struct FlexBox<Content: View>: View {

    private let config:  FlexContainerConfig
    private let content: Content

    /// Create a flex container.
    ///
    /// - Parameters:
    ///   - direction:      Main axis direction. CSS `flex-direction`. Default `.row`.
    ///   - wrap:           Whether items wrap. CSS `flex-wrap`. Default `.nowrap`.
    ///   - justifyContent: Main-axis distribution. CSS `justify-content`. Default `.flexStart`.
    ///   - alignItems:     Cross-axis alignment for items. CSS `align-items`. Default `.stretch`.
    ///   - alignContent:   Cross-axis distribution of lines. CSS `align-content`. Default `.stretch`.
    ///   - gap:            Gap applied to both axes. CSS `gap`. Default `0`.
    ///   - rowGap:         Gap between flex lines. CSS `row-gap`. Overrides `gap` for lines.
    ///   - columnGap:      Gap between items within a line. CSS `column-gap`. Overrides `gap` for items.
    ///   - padding:        Inner spacing between container boundary and children. CSS `padding`.
    ///   - content:        Child views — each may use `.flexItem(...)` for per-item properties.
    public init(
        direction:      FlexDirection  = .row,
        wrap:           FlexWrap       = .nowrap,
        justifyContent: JustifyContent = .flexStart,
        alignItems:     AlignItems     = .stretch,
        alignContent:   AlignContent   = .stretch,
        gap:            CGFloat        = 0,
        rowGap:         CGFloat?       = nil,
        columnGap:      CGFloat?       = nil,
        padding:        EdgeInsets     = EdgeInsets(),
        overflow:       FlexOverflow   = .visible,
        @ViewBuilder content: () -> Content
    ) {
        self.config = FlexContainerConfig(
            direction:      direction,
            wrap:           wrap,
            justifyContent: justifyContent,
            alignItems:     alignItems,
            alignContent:   alignContent,
            gap:            gap,
            rowGap:         rowGap,
            columnGap:      columnGap,
            padding:        padding,
            overflow:       overflow
        )
        self.content = content()
    }

    @ViewBuilder
    public var body: some View {
        let layout = FlexLayout(config) { content }
        switch config.overflow {
        case .visible:
            layout
        case .hidden, .clip, .auto:
            layout.clipped()
        case .scroll:
            ScrollView([.horizontal, .vertical]) { layout }.clipped()
        }
    }
}
