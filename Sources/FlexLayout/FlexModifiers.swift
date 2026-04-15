import SwiftUI

// MARK: - FlexItemModifier

/// A `ViewModifier` that attaches all CSS flex item properties to a view
/// as `LayoutValueKey` values so they can be read by ``FlexLayout`` at layout time.
///
/// You almost never need to create `FlexItemModifier` directly. Use the
/// ``SwiftUI/View/flexItem(grow:shrink:basis:alignSelf:order:width:height:overflow:zIndex:position:top:bottom:leading:trailing:display:)``
/// extension method instead.
public struct FlexItemModifier: ViewModifier {

    // Core flex item properties
    let grow:      CGFloat
    let shrink:    CGFloat
    let basis:     FlexBasis
    let alignSelf: AlignSelf
    let order:     Int

    // Extended spec properties
    let width:     FlexSize
    let height:    FlexSize
    let overflow:  FlexOverflow
    let zIndex:    Int
    let position:  FlexPosition
    let top:       CGFloat?
    let bottom:    CGFloat?
    let leading:   CGFloat?
    let trailing:  CGFloat?
    let display:   FlexDisplay

    public func body(content: Content) -> some View {
        content
            .layoutValue(key: FlexGrowKey.self,     value: grow)
            .layoutValue(key: FlexShrinkKey.self,   value: shrink)
            .layoutValue(key: FlexBasisKey.self,     value: basis)
            .layoutValue(key: AlignSelfKey.self,     value: alignSelf)
            .layoutValue(key: FlexOrderKey.self,     value: order)
            .layoutValue(key: FlexWidthKey.self,     value: width)
            .layoutValue(key: FlexHeightKey.self,    value: height)
            .layoutValue(key: FlexOverflowKey.self,  value: overflow)
            .layoutValue(key: FlexZIndexKey.self,    value: zIndex)
            .layoutValue(key: FlexPositionKey.self,  value: position)
            .layoutValue(key: FlexTopKey.self,       value: top)
            .layoutValue(key: FlexBottomKey.self,    value: bottom)
            .layoutValue(key: FlexLeadingKey.self,   value: leading)
            .layoutValue(key: FlexTrailingKey.self,  value: trailing)
            .layoutValue(key: FlexDisplayKey.self,   value: display)
    }
}

// MARK: - View Extension

public extension View {

    /// Attaches CSS flex item properties to this view.
    ///
    /// Call `.flexItem(...)` on any child of a ``FlexBox`` or ``FlexLayout`` to
    /// control how that individual item is sized and placed. All parameters are
    /// optional and default to their CSS initial values, so you only need to supply
    /// the properties you want to customise.
    ///
    /// ## Common patterns
    ///
    /// ```swift
    /// // 1. Grow to fill remaining space (CSS: flex-grow: 1)
    /// Spacer()
    ///     .flexItem(grow: 1)
    ///
    /// // 2. Fixed-width sidebar that never shrinks
    /// SidebarView()
    ///     .flexItem(basis: .points(240), shrink: 0)
    ///
    /// // 3. Three equal-width columns (CSS "flex: 1" pattern)
    /// FlexBox(direction: .row) {
    ///     Text("A").flexItem(grow: 1, shrink: 1, basis: .points(0))
    ///     Text("B").flexItem(grow: 1, shrink: 1, basis: .points(0))
    ///     Text("C").flexItem(grow: 1, shrink: 1, basis: .points(0))
    /// }
    ///
    /// // 4. Absolutely-positioned badge (removed from flex flow)
    /// Text("NEW")
    ///     .flexItem(zIndex: 1, position: .absolute, top: 8, trailing: 8)
    ///
    /// // 5. Override cross-axis alignment for one item
    /// Image(systemName: "star")
    ///     .flexItem(alignSelf: .flexEnd)
    ///
    /// // 6. 50 % width column
    /// ContentView()
    ///     .flexItem(width: .fraction(0.5))
    /// ```
    ///
    /// - Parameters:
    ///   - grow:      How much this item grows relative to siblings when free main-axis
    ///                space is available. CSS `flex-grow`. Default `0`.
    ///   - shrink:    How much this item shrinks relative to siblings when the line
    ///                overflows. CSS `flex-shrink`. Default `1`.
    ///   - basis:     Initial main-axis size before free-space distribution.
    ///                CSS `flex-basis`. Default `.auto`.
    ///   - alignSelf: Cross-axis alignment override for this item only.
    ///                CSS `align-self`. Default `.auto` (inherits `alignItems`).
    ///   - order:     Visual order relative to other items. Lower values appear first.
    ///                CSS `order`. Default `0`.
    ///   - width:     Explicit width override. Takes precedence over intrinsic width.
    ///                CSS `width`. Default `.auto`.
    ///   - height:    Explicit height override. Takes precedence over intrinsic height.
    ///                CSS `height`. Default `.auto`.
    ///   - overflow:  Overflow clipping behaviour for this item's content.
    ///                CSS `overflow`. Default `.visible`.
    ///   - zIndex:    Z-axis stacking order. Higher values appear on top.
    ///                Ties are broken by DOM/source order. CSS `z-index`. Default `0`.
    ///   - position:  Positioning scheme. `.absolute` removes the item from the flex
    ///                flow and positions it relative to the container.
    ///                CSS `position`. Default `.relative`.
    ///   - top:       Distance from the container's top edge. Only meaningful when
    ///                `position == .absolute`. CSS `top`. Default `nil`.
    ///   - bottom:    Distance from the container's bottom edge. Only meaningful when
    ///                `position == .absolute`. CSS `bottom`. Default `nil`.
    ///   - leading:   Distance from the container's leading (left) edge. Only meaningful
    ///                when `position == .absolute`. CSS `left`. Default `nil`.
    ///   - trailing:  Distance from the container's trailing (right) edge. Only meaningful
    ///                when `position == .absolute`. CSS `right`. Default `nil`.
    ///   - display:   CSS `display` value accepted for parser parity.
    ///                In a flex context, `block` and `inline` are blockified and produce
    ///                the same layout as `flex`. Default `.flex`.
    func flexItem(
        grow:      CGFloat      = 0,
        shrink:    CGFloat      = 1,
        basis:     FlexBasis    = .auto,
        alignSelf: AlignSelf    = .auto,
        order:     Int          = 0,
        width:     FlexSize     = .auto,
        height:    FlexSize     = .auto,
        overflow:  FlexOverflow = .visible,
        zIndex:    Int          = 0,
        position:  FlexPosition = .relative,
        top:       CGFloat?     = nil,
        bottom:    CGFloat?     = nil,
        leading:   CGFloat?     = nil,
        trailing:  CGFloat?     = nil,
        display:   FlexDisplay  = .flex
    ) -> some View {
        modifier(FlexItemModifier(
            grow:      grow,
            shrink:    shrink,
            basis:     basis,
            alignSelf: alignSelf,
            order:     order,
            width:     width,
            height:    height,
            overflow:  overflow,
            zIndex:    zIndex,
            position:  position,
            top:       top,
            bottom:    bottom,
            leading:   leading,
            trailing:  trailing,
            display:   display
        ))
    }

    /// Shorthand for the CSS `flex: <n>` property.
    ///
    /// Sets `grow = n`, `shrink = 1`, `basis = .points(0)`, which is the exact
    /// interpretation of `flex: 1` in the CSS Flexbox specification.
    ///
    /// ```swift
    /// // Three perfectly equal columns — idiomatic "flex: 1"
    /// FlexBox(direction: .row) {
    ///     Text("Column A").flexItem(flex: 1)
    ///     Text("Column B").flexItem(flex: 1)
    ///     Text("Column C").flexItem(flex: 1)
    /// }
    ///
    /// // Sidebar (flex: 0) + content area (flex: 1)
    /// FlexBox(direction: .row) {
    ///     SidebarView().flexItem(flex: 0)   // hugs content
    ///     ContentView().flexItem(flex: 1)   // fills remainder
    /// }
    /// ```
    ///
    /// - Parameter n: The `flex-grow` factor. Pass `0` to prevent growth and shrinkage.
    func flexItem(flex n: CGFloat) -> some View {
        flexItem(grow: n, shrink: 1, basis: .points(0))
    }

    /// Applies CSS `overflow` clipping to an individual view.
    ///
    /// Use this when you need to control overflow on a single item rather than the
    /// entire container. For container-level overflow, use ``FlexBox``'s `overflow:`
    /// parameter instead.
    ///
    /// ```swift
    /// // Clip a long text view to its bounds without a scrollbar
    /// LongTextView()
    ///     .flexOverflow(.hidden)
    ///
    /// // Make a single item scrollable when it overflows
    /// LargeImageView()
    ///     .flexOverflow(.scroll)
    /// ```
    ///
    /// - Parameter overflow: The overflow handling mode to apply.
    func flexOverflow(_ overflow: FlexOverflow) -> some View {
        modifier(FlexOverflowModifier(overflow: overflow))
    }
}

// MARK: - FlexOverflowModifier

/// Applies visual overflow clipping to a view, mirroring the CSS `overflow` property.
///
/// Used internally by ``SwiftUI/View/flexOverflow(_:)`` and applied at the container
/// level by ``FlexBox``.
///
/// | Value        | SwiftUI behaviour                                               |
/// |--------------|------------------------------------------------------------------|
/// | `.visible`   | No change — content can draw outside bounds                    |
/// | `.hidden`    | `.clipped()` — hard clip to bounds                              |
/// | `.clip`      | `.clipped()` — identical to `.hidden` (CSS parity)             |
/// | `.scroll`    | `ScrollView([.horizontal, .vertical])` — always scrollable      |
/// | `.auto`      | `ViewThatFits` — normal layout when content fits, scroll when not|
///
/// ```swift
/// // Apply to an arbitrary view:
/// MyView()
///     .modifier(FlexOverflowModifier(overflow: .auto))
///
/// // Or use the convenience extension:
/// MyView()
///     .flexOverflow(.auto)
/// ```
public struct FlexOverflowModifier: ViewModifier {

    /// The overflow mode to apply.
    public let overflow: FlexOverflow

    /// Creates an overflow modifier.
    /// - Parameter overflow: The CSS `overflow` value to apply.
    public init(overflow: FlexOverflow) {
        self.overflow = overflow
    }

    public func body(content: Content) -> some View {
        switch overflow {
        case .visible:
            // No clipping — content renders outside bounds if needed.
            content
        case .hidden, .clip:
            // Hard clip: content is never visible outside the view's frame.
            content.clipped()
        case .scroll:
            // Always scrollable in both axes, regardless of content size.
            ScrollView([.horizontal, .vertical]) { content }.clipped()
        case .auto:
            // Use a plain (non-scrolling) layout when content fits.
            // Fall back to a ScrollView when it overflows.
            // Implemented with `ViewThatFits` which evaluates the first variant
            // that fits and uses the second when the first is too large.
            ViewThatFits(in: [.horizontal, .vertical]) {
                content.clipped()
                ScrollView([.horizontal, .vertical]) { content }.clipped()
            }
        }
    }
}
