import SwiftUI

// MARK: - FlexItemModifier

/// A ViewModifier that attaches all CSS flex item properties to a view
/// so they can be read by `FlexLayout` at layout time.
public struct FlexItemModifier: ViewModifier {
    // Existing flex item properties
    let grow:      CGFloat
    let shrink:    CGFloat
    let basis:     FlexBasis
    let alignSelf: AlignSelf
    let order:     Int
    // New spec properties
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
            // Existing
            .layoutValue(key: FlexGrowKey.self,     value: grow)
            .layoutValue(key: FlexShrinkKey.self,   value: shrink)
            .layoutValue(key: FlexBasisKey.self,    value: basis)
            .layoutValue(key: AlignSelfKey.self,    value: alignSelf)
            .layoutValue(key: FlexOrderKey.self,    value: order)
            // New
            .layoutValue(key: FlexWidthKey.self,    value: width)
            .layoutValue(key: FlexHeightKey.self,   value: height)
            .layoutValue(key: FlexOverflowKey.self, value: overflow)
            .layoutValue(key: FlexZIndexKey.self,   value: zIndex)
            .layoutValue(key: FlexPositionKey.self, value: position)
            .layoutValue(key: FlexTopKey.self,      value: top)
            .layoutValue(key: FlexBottomKey.self,   value: bottom)
            .layoutValue(key: FlexLeadingKey.self,  value: leading)
            .layoutValue(key: FlexTrailingKey.self, value: trailing)
            .layoutValue(key: FlexDisplayKey.self,  value: display)
    }
}

// MARK: - View Extension

public extension View {

    /// Attach CSS flex item properties to this view.
    ///
    /// All parameters are optional and default to their CSS initial values so
    /// existing call sites continue to compile unchanged.
    ///
    /// - Parameters:
    ///   - grow:      How much this item grows relative to siblings. CSS `flex-grow`. Default `0`.
    ///   - shrink:    How much this item shrinks relative to siblings. CSS `flex-shrink`. Default `1`.
    ///   - basis:     Initial main-axis size before free space is distributed. CSS `flex-basis`. Default `.auto`.
    ///   - alignSelf: Cross-axis alignment override. CSS `align-self`. Default `.auto`.
    ///   - order:     Visual order relative to other items. CSS `order`. Default `0`.
    ///   - width:     Explicit width constraint. CSS `width`. Default `.auto` (no override).
    ///   - height:    Explicit height constraint. CSS `height`. Default `.auto` (no override).
    ///   - overflow:  Overflow clipping behaviour. CSS `overflow`. Default `.visible`.
    ///   - zIndex:    Z-axis stacking order. CSS `z-index`. Default `0`.
    ///   - position:  Positioning scheme. CSS `position`. Default `.relative`.
    ///   - top:       Distance from container's top edge (absolute only). CSS `top`.
    ///   - bottom:    Distance from container's bottom edge (absolute only). CSS `bottom`.
    ///   - leading:   Distance from container's leading edge (absolute only). CSS `left`.
    ///   - trailing:  Distance from container's trailing edge (absolute only). CSS `right`.
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

    /// Shorthand equivalent to CSS `flex: <n>`.
    ///
    /// Sets `grow = n`, `shrink = 1`, `basis = .points(0)` — the CSS spec
    /// interpretation of `flex: 1`.
    func flexItem(flex n: CGFloat) -> some View {
        flexItem(grow: n, shrink: 1, basis: .points(0))
    }

    /// Apply overflow clipping to an individual view.
    ///
    /// This mirrors the CSS `overflow` property at the item level.
    /// For container-level overflow, use `FlexBox(overflow:)` instead.
    func flexOverflow(_ overflow: FlexOverflow) -> some View {
        modifier(FlexOverflowModifier(overflow: overflow))
    }
}

// MARK: - Overflow ViewModifier (public, for item-level clipping)

/// Applies visual overflow clipping to a view. CSS `overflow`.
///
/// - `.visible`: no clipping (default)
/// - `.hidden`, `.clip`: clips content to the view's bounds
/// - `.scroll`, `.auto`: wraps in a ScrollView and clips
public struct FlexOverflowModifier: ViewModifier {
    public let overflow: FlexOverflow

    public init(overflow: FlexOverflow) {
        self.overflow = overflow
    }

    public func body(content: Content) -> some View {
        switch overflow {
        case .visible:
            content
        case .hidden, .clip:
            content.clipped()
        case .scroll, .auto:
            ScrollView([.horizontal, .vertical]) { content }.clipped()
        }
    }
}
