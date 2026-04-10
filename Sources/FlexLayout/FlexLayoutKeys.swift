import SwiftUI

// MARK: - LayoutValueKeys
//
// Each CSS flex item property is surfaced as a LayoutValueKey so that
// FlexLayout can read it from any subview at layout time.

/// Controls how much a flex item grows relative to its siblings when free space is available.
/// Equivalent to CSS `flex-grow`. Default: `0` (no growth).
public struct FlexGrowKey: LayoutValueKey {
    public static let defaultValue: CGFloat = 0
}

/// Controls how much a flex item shrinks relative to its siblings when space is insufficient.
/// Equivalent to CSS `flex-shrink`. Default: `1`.
public struct FlexShrinkKey: LayoutValueKey {
    public static let defaultValue: CGFloat = 1
}

/// Sets the initial main-axis size before free space is distributed.
/// Equivalent to CSS `flex-basis`. Default: `.auto`.
public struct FlexBasisKey: LayoutValueKey {
    public static let defaultValue: FlexBasis = .auto
}

/// Overrides the container's `alignItems` for a single item.
/// Equivalent to CSS `align-self`. Default: `.auto` (inherits container value).
public struct AlignSelfKey: LayoutValueKey {
    public static let defaultValue: AlignSelf = .auto
}

/// Controls the visual order of a flex item independently of source order.
/// Equivalent to CSS `order`. Default: `0`.
public struct FlexOrderKey: LayoutValueKey {
    public static let defaultValue: Int = 0
}

// MARK: - New Spec Keys

/// Explicit width constraint. CSS `width`. Default: `.auto` (no override).
public struct FlexWidthKey: LayoutValueKey {
    public static let defaultValue: FlexSize = .auto
}

/// Explicit height constraint. CSS `height`. Default: `.auto` (no override).
public struct FlexHeightKey: LayoutValueKey {
    public static let defaultValue: FlexSize = .auto
}

/// Overflow clipping behaviour. CSS `overflow`. Default: `.visible`.
public struct FlexOverflowKey: LayoutValueKey {
    public static let defaultValue: FlexOverflow = .visible
}

/// Z-axis stacking order. CSS `z-index`. Default: `0`.
public struct FlexZIndexKey: LayoutValueKey {
    public static let defaultValue: Int = 0
}

/// Positioning scheme. CSS `position`. Default: `.relative`.
public struct FlexPositionKey: LayoutValueKey {
    public static let defaultValue: FlexPosition = .relative
}

/// Distance from the containing block's top edge. CSS `top`. Default: `nil` (unset).
public struct FlexTopKey: LayoutValueKey {
    public static let defaultValue: CGFloat? = nil
}

/// Distance from the containing block's bottom edge. CSS `bottom`. Default: `nil`.
public struct FlexBottomKey: LayoutValueKey {
    public static let defaultValue: CGFloat? = nil
}

/// Distance from the containing block's leading (left) edge. CSS `left`. Default: `nil`.
public struct FlexLeadingKey: LayoutValueKey {
    public static let defaultValue: CGFloat? = nil
}

/// Distance from the containing block's trailing (right) edge. CSS `right`. Default: `nil`.
public struct FlexTrailingKey: LayoutValueKey {
    public static let defaultValue: CGFloat? = nil
}

/// Display mode. CSS `display`. Default: `.flex`.
public struct FlexDisplayKey: LayoutValueKey {
    public static let defaultValue: FlexDisplay = .flex
}
