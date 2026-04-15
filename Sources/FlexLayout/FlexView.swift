import SwiftUI

/// A SwiftUI view that arranges its children using the CSS Flexbox layout model.
///
/// `FlexBox` is the primary public API of the `FlexLayout` package. It wraps
/// ``FlexLayout`` in a `@ViewBuilder`-based `View` and exposes all container
/// properties as labelled initialiser parameters — mirroring the CSS API.
///
/// ## Basic usage
///
/// ```swift
/// // Horizontal navigation bar with a spacer
/// FlexBox(direction: .row, alignItems: .center) {
///     Text("Logo")
///     Spacer().flexItem(grow: 1)
///     Text("Menu")
/// }
/// ```
///
/// ## Wrapping grid
///
/// ```swift
/// // Card grid that wraps at 160 pt minimum card width
/// FlexBox(wrap: .wrap, justifyContent: .flexStart, gap: 12) {
///     ForEach(items) { item in
///         CardView(item: item)
///             .flexItem(basis: .points(160), shrink: 0)
///     }
/// }
/// ```
///
/// ## Column layout with padding
///
/// ```swift
/// FlexBox(
///     direction: .column,
///     gap:       16,
///     padding:   EdgeInsets(top: 20, leading: 20, bottom: 20, trailing: 20)
/// ) {
///     HeaderView()
///     BodyView().flexItem(grow: 1)
///     FooterView()
/// }
/// ```
///
/// ## Absolute positioning
///
/// ```swift
/// // Badge pinned to the top-right corner, outside the flex flow
/// FlexBox(direction: .row) {
///     Image(systemName: "envelope")
///     Text("Inbox")
///     Text("3")
///         .flexItem(position: .absolute, top: 0, trailing: 0)
/// }
/// ```
///
/// ## Overflow scroll
///
/// ```swift
/// // Horizontal scrolling tab bar
/// FlexBox(direction: .row, wrap: .nowrap, gap: 8, overflow: .scroll) {
///     ForEach(tabs) { tab in TabChip(tab) }
/// }
/// ```
public struct FlexBox<Content: View>: View {

    private let config:  FlexContainerConfig
    private let content: Content

    /// Creates a flex container.
    ///
    /// - Parameters:
    ///   - direction:      Main axis direction. CSS `flex-direction`. Default `.row`.
    ///   - wrap:           Whether items may wrap onto multiple lines. CSS `flex-wrap`. Default `.nowrap`.
    ///   - justifyContent: Distribution of free space along the main axis. CSS `justify-content`. Default `.flexStart`.
    ///   - alignItems:     Cross-axis alignment for items within a line. CSS `align-items`. Default `.stretch`.
    ///   - alignContent:   Cross-axis distribution of multiple lines. CSS `align-content`. Default `.stretch`.
    ///   - gap:            Uniform gap between items and between lines. CSS `gap`. Default `0`.
    ///   - rowGap:         Gap between flex lines only. CSS `row-gap`. Overrides `gap` for lines.
    ///   - columnGap:      Gap between items within a line only. CSS `column-gap`. Overrides `gap` for items.
    ///   - padding:        Inner spacing between the container boundary and its children. CSS `padding`.
    ///   - overflow:       How overflowing content is rendered. CSS `overflow`. Default `.visible`.
    ///   - content:        Child views. Each may use `.flexItem(...)` for per-item flex properties.
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

    /// The view's body: a ``FlexLayout`` wrapped with the container's overflow modifier.
    ///
    /// The overflow behaviour is applied at the container level via
    /// ``SwiftUI/View/flexOverflow(_:)`` so the `ScrollView` (if any) correctly encloses
    /// all children.
    @ViewBuilder
    public var body: some View {
        let layout = FlexLayout(config) { content }
        layout.flexOverflow(config.overflow)
    }
}
