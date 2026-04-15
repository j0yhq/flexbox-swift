import SwiftUI

// MARK: - LayoutValueKey declarations
//
// Each CSS flex item property is surfaced as a `LayoutValueKey` so that
// `FlexLayout` can read it from any child view at layout time.
//
// A child attaches values via `.flexItem(...)`, which calls
// `.layoutValue(key:value:)` for each key below.
//
// `FlexLayout.makeInputs(from:)` then reads them back using `subview[KeyType.self]`.

// MARK: Core flex item keys

/// The `flex-grow` factor: how much a flex item grows relative to its siblings.
///
/// - Default: `0` — the item does not grow beyond its basis size.
/// - CSS: `flex-grow`
/// - Set via: `.flexItem(grow: 1)`
public struct FlexGrowKey: LayoutValueKey {
    public static let defaultValue: CGFloat = 0
}

/// The `flex-shrink` factor: how much a flex item shrinks relative to its siblings.
///
/// - Default: `1` — all items shrink equally by default (CSS initial value).
/// - CSS: `flex-shrink`
/// - Set via: `.flexItem(shrink: 0)` to prevent shrinking.
public struct FlexShrinkKey: LayoutValueKey {
    public static let defaultValue: CGFloat = 1
}

/// The initial main-axis size before free space is distributed.
///
/// - Default: `.auto` — the item uses its intrinsic content size as the basis.
/// - CSS: `flex-basis`
/// - Set via: `.flexItem(basis: .points(120))` or `.flexItem(basis: .fraction(0.5))`
public struct FlexBasisKey: LayoutValueKey {
    public static let defaultValue: FlexBasis = .auto
}

/// Cross-axis alignment override for a single flex item.
///
/// - Default: `.auto` — inherits the container's `align-items` value.
/// - CSS: `align-self`
/// - Set via: `.flexItem(alignSelf: .center)`
public struct AlignSelfKey: LayoutValueKey {
    public static let defaultValue: AlignSelf = .auto
}

/// Visual order of a flex item relative to its siblings.
///
/// Items with a lower `order` value appear first in the flex line.
/// Items with equal `order` values are placed in source order.
///
/// - Default: `0`
/// - CSS: `order`
/// - Set via: `.flexItem(order: -1)` to place an item before all `order: 0` items.
public struct FlexOrderKey: LayoutValueKey {
    public static let defaultValue: Int = 0
}

// MARK: Extended spec keys

/// Explicit width override for a flex item.
///
/// - Default: `.auto` — no explicit width; the flex algorithm determines the size.
/// - CSS: `width`
/// - Set via: `.flexItem(width: .points(200))` or `.flexItem(width: .fraction(0.5))`
public struct FlexWidthKey: LayoutValueKey {
    public static let defaultValue: FlexSize = .auto
}

/// Explicit height override for a flex item.
///
/// - Default: `.auto` — no explicit height.
/// - CSS: `height`
/// - Set via: `.flexItem(height: .points(80))`
public struct FlexHeightKey: LayoutValueKey {
    public static let defaultValue: FlexSize = .auto
}

/// Overflow clipping behaviour for an individual flex item.
///
/// - Default: `.visible` — content is not clipped.
/// - CSS: `overflow`
/// - Set via: `.flexItem(overflow: .hidden)`
public struct FlexOverflowKey: LayoutValueKey {
    public static let defaultValue: FlexOverflow = .visible
}

/// Z-axis stacking order.
///
/// Higher values are rendered on top. When two items share the same `z-index`,
/// the one that appears later in source order is rendered on top (DOM order
/// tie-breaking).
///
/// - Default: `0`
/// - CSS: `z-index`
/// - Set via: `.flexItem(zIndex: 10)`
public struct FlexZIndexKey: LayoutValueKey {
    public static let defaultValue: Int = 0
}

/// Positioning scheme for a flex item.
///
/// `.absolute` removes the item from the flex flow. It is then positioned by
/// `top`, `bottom`, `leading`, and `trailing` insets relative to the container.
///
/// - Default: `.relative` — item participates in normal flex flow.
/// - CSS: `position`
/// - Set via: `.flexItem(position: .absolute, top: 0, trailing: 0)`
public struct FlexPositionKey: LayoutValueKey {
    public static let defaultValue: FlexPosition = .relative
}

/// Distance from the containing block's top edge (absolute positioning only).
///
/// - Default: `nil` — inset is not set.
/// - CSS: `top`
/// - Set via: `.flexItem(position: .absolute, top: 16)`
public struct FlexTopKey: LayoutValueKey {
    public static let defaultValue: CGFloat? = nil
}

/// Distance from the containing block's bottom edge (absolute positioning only).
///
/// - Default: `nil` — inset is not set.
/// - CSS: `bottom`
/// - Set via: `.flexItem(position: .absolute, bottom: 16)`
public struct FlexBottomKey: LayoutValueKey {
    public static let defaultValue: CGFloat? = nil
}

/// Distance from the containing block's leading (left) edge (absolute positioning only).
///
/// - Default: `nil` — inset is not set.
/// - CSS: `left`
/// - Set via: `.flexItem(position: .absolute, leading: 16)`
public struct FlexLeadingKey: LayoutValueKey {
    public static let defaultValue: CGFloat? = nil
}

/// Distance from the containing block's trailing (right) edge (absolute positioning only).
///
/// - Default: `nil` — inset is not set.
/// - CSS: `right`
/// - Set via: `.flexItem(position: .absolute, trailing: 16)`
public struct FlexTrailingKey: LayoutValueKey {
    public static let defaultValue: CGFloat? = nil
}

/// The CSS `display` mode of a flex item.
///
/// In a flex formatting context all children are *blockified* regardless of this value.
/// `block` and `inline` are accepted for CSS parser parity but produce the same outer
/// layout as `flex`.
///
/// - Default: `.flex`
/// - CSS: `display`
/// - Set via: `.flexItem(display: .block)`
public struct FlexDisplayKey: LayoutValueKey {
    public static let defaultValue: FlexDisplay = .flex
}
