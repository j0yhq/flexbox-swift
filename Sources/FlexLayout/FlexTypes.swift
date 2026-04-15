import SwiftUI

// MARK: - Overflow & Positioning

/// Controls how content that overflows a flex container is rendered.
///
/// Maps directly to the CSS `overflow` property. Apply at the container level via
/// ``FlexBox`` or ``FlexLayout``, or at the item level via ``SwiftUI/View/flexItem(grow:shrink:basis:alignSelf:order:width:height:overflow:zIndex:position:top:bottom:leading:trailing:display:)``.
///
/// ```swift
/// // Clip overflowing cards without a scrollbar
/// FlexBox(wrap: .nowrap, overflow: .hidden) {
///     ForEach(cards) { CardView($0) }
/// }
///
/// // Show a scroll bar only when content overflows
/// FlexBox(wrap: .nowrap, overflow: .auto) {
///     ForEach(cards) { CardView($0) }
/// }
/// ```
public enum FlexOverflow: Equatable {
    /// Content is not clipped and may overflow the container bounds (default).
    case visible
    /// Content is clipped to the container bounds. No scrollbar is provided.
    case hidden
    /// Identical to `.hidden`. Included for CSS `overflow: clip` parity.
    case clip
    /// Content is clipped and always placed inside a `ScrollView`.
    case scroll
    /// Uses normal layout when content fits; wraps in a `ScrollView` when it overflows.
    /// Implemented with SwiftUI's `ViewThatFits`.
    case auto
}

/// Controls whether an item participates in the normal flex flow.
///
/// Maps to the CSS `position` property. Only `relative` and `absolute` are
/// supported in a flex formatting context.
///
/// ```swift
/// ZStack {
///     FlexBox(direction: .row) {
///         Text("In flow A")
///         Text("In flow B")
///     }
///     // Overlay badge pinned 8pt from the top-right corner
///     Text("NEW")
///         .flexItem(
///             position: .absolute,
///             top:      8,
///             trailing: 8
///         )
/// }
/// ```
public enum FlexPosition: Equatable {
    /// Item remains in the normal flex flow (default).
    case relative
    /// Item is removed from flow. Sized and positioned by `top`, `bottom`,
    /// `leading`, and `trailing` insets relative to the flex container.
    case absolute
}

/// An explicit width or height constraint applied to a single flex item.
///
/// Maps to the CSS `width` / `height` properties. Unlike ``FlexBasis``, explicit
/// sizes act as hard overrides on the cross or main axis irrespective of
/// flex-grow and flex-shrink.
///
/// ```swift
/// // Fixed 120-pt width, natural height
/// Text("Label")
///     .flexItem(width: .points(120))
///
/// // 50 % of the container's height
/// Rectangle()
///     .flexItem(height: .fraction(0.5))
///
/// // Shrink to the text's minimum intrinsic width
/// Text("Long label that may be truncated")
///     .flexItem(width: .minContent)
/// ```
public enum FlexSize: Equatable {
    /// No explicit size override; the flex algorithm determines the size (default).
    case auto
    /// A fixed size in points. CSS equivalent: `width: 120px`.
    case points(CGFloat)
    /// A fraction of the container's corresponding axis size. CSS equivalent: `width: 50%`.
    /// - Note: Resolves to `.auto` when the container's size on that axis is unconstrained.
    case fraction(CGFloat)
    /// The item's minimum intrinsic content size. CSS equivalent: `width: min-content`.
    case minContent
}

/// The CSS `display` value of a flex item.
///
/// In a flex formatting context the spec *blockifies* all flex items regardless of
/// their `display` value, so `block` and `inline` produce the same outer layout as
/// `flex`. They are accepted for CSS parser parity — e.g. when parsing a design-
/// token stylesheet that sets `display: block` on a child.
///
/// ```swift
/// // These three produce identical flex-item geometry:
/// Text("A").flexItem(display: .flex)
/// Text("B").flexItem(display: .block)   // blockified → same as flex
/// Text("C").flexItem(display: .inline)  // blockified → same as flex
/// ```
public enum FlexDisplay: Equatable {
    /// Participates in flex sizing as a normal flex item (default).
    case flex
    /// Accepted for CSS parity. Blockified during flex-item placement.
    case block
    /// Accepted for CSS parity. Blockified during flex-item placement.
    case inline
}

// MARK: - Container Properties

/// The main-axis direction for a flex container.
///
/// Maps to the CSS `flex-direction` property and determines the axis along which
/// flex items are laid out.
///
/// ```swift
/// // Horizontal navigation bar
/// FlexBox(direction: .row) { ... }
///
/// // Vertical sidebar
/// FlexBox(direction: .column) { ... }
///
/// // Right-to-left (e.g. RTL language) row
/// FlexBox(direction: .rowReverse) { ... }
/// ```
public enum FlexDirection: Equatable, CaseIterable {
    /// Items flow left → right (default). Main axis = horizontal.
    case row
    /// Items flow right → left. Main axis = horizontal, reversed.
    case rowReverse
    /// Items flow top → bottom. Main axis = vertical.
    case column
    /// Items flow bottom → top. Main axis = vertical, reversed.
    case columnReverse

    /// `true` when the main axis is horizontal (`row` or `rowReverse`).
    var isRow: Bool { self == .row || self == .rowReverse }

    /// `true` when items are placed in reverse source order.
    var isReversed: Bool { self == .rowReverse || self == .columnReverse }
}

/// Controls whether flex items are forced onto one line or can wrap onto multiple lines.
///
/// Maps to the CSS `flex-wrap` property.
///
/// ```swift
/// // Wrapping tag cloud
/// FlexBox(wrap: .wrap, gap: 8) {
///     ForEach(tags) { tag in
///         TagChip(tag)
///             .flexItem(shrink: 0)
///     }
/// }
/// ```
public enum FlexWrap: Equatable, CaseIterable {
    /// All items are forced onto one line (default). Items may overflow or shrink.
    case nowrap
    /// Items wrap onto additional lines in the positive cross-axis direction.
    case wrap
    /// Items wrap onto additional lines in the *negative* cross-axis direction
    /// (new lines appear above/before existing ones).
    case wrapReverse
}

/// Distributes free space among flex items along the **main** axis.
///
/// Maps to the CSS `justify-content` property. Applied after flex-grow and flex-shrink
/// have been resolved, so `justifyContent` only affects truly free space.
///
/// ```swift
/// // Space-between: first item at start, last at end
/// FlexBox(justifyContent: .spaceBetween) {
///     Text("Left label")
///     Text("Right label")
/// }
///
/// // Center: items grouped in the middle
/// FlexBox(justifyContent: .center) {
///     Image(systemName: "star")
///     Text("Featured")
/// }
/// ```
public enum JustifyContent: Equatable, CaseIterable {
    /// Items packed toward the main-axis start (default).
    case flexStart
    /// Items packed toward the main-axis end.
    case flexEnd
    /// Items centered along the main axis.
    case center
    /// Free space distributed *between* items; first item at start, last at end.
    case spaceBetween
    /// Free space distributed with equal gutters around each item
    /// (half-size gutters at the edges).
    case spaceAround
    /// Free space distributed equally between every gap, including the two outer gaps.
    case spaceEvenly
}

/// Aligns flex items along the **cross** axis within their flex line.
///
/// Maps to the CSS `align-items` property. Serves as the default for items that
/// do not set ``AlignSelf``.
///
/// ```swift
/// // Center icon and text vertically in a row
/// FlexBox(direction: .row, alignItems: .center) {
///     Image(systemName: "bell")
///     Text("Notifications")
/// }
///
/// // Stretch all cards to the tallest card's height
/// FlexBox(direction: .row, alignItems: .stretch) {
///     CardView(short)
///     CardView(tall)
/// }
/// ```
public enum AlignItems: Equatable, CaseIterable {
    /// Items aligned to the cross-axis start.
    case flexStart
    /// Items aligned to the cross-axis end.
    case flexEnd
    /// Items centered on the cross axis.
    case center
    /// Items stretched to fill the line's cross size (default).
    case stretch
    /// Items aligned so their text baselines are on a common horizontal line.
    case baseline
}

/// Distributes space among flex **lines** along the cross axis (multi-line only).
///
/// Maps to the CSS `align-content` property. Has no effect when ``FlexWrap`` is
/// `.nowrap` or when there is only one flex line.
///
/// ```swift
/// // Three-line grid: pack lines at the top
/// FlexBox(wrap: .wrap, alignContent: .flexStart, gap: 12) {
///     ForEach(items) { CardView($0).flexItem(basis: .points(150), shrink: 0) }
/// }
///
/// // Stretch all lines to fill the container cross axis evenly
/// FlexBox(wrap: .wrap, alignContent: .stretch) { ... }
/// ```
public enum AlignContent: Equatable, CaseIterable {
    /// Lines packed toward the cross-axis start.
    case flexStart
    /// Lines packed toward the cross-axis end.
    case flexEnd
    /// Lines centered on the cross axis.
    case center
    /// Free space distributed *between* lines; first line at start, last at end.
    case spaceBetween
    /// Free space distributed with equal gutters around each line.
    case spaceAround
    /// Free space distributed equally between every gap including outer gaps.
    case spaceEvenly
    /// Lines stretched to fill the container's cross axis (default).
    /// Extra space is divided equally among lines; items with `align-self: stretch`
    /// are re-stretched to the enlarged line size.
    case stretch
}

// MARK: - Item Properties

/// Overrides the container's ``AlignItems`` for a single flex item.
///
/// Maps to the CSS `align-self` property.
///
/// ```swift
/// FlexBox(direction: .row, alignItems: .stretch) {
///     Text("Baseline text")
///         .flexItem(alignSelf: .baseline)
///     Text("Bottom-pinned")
///         .flexItem(alignSelf: .flexEnd)
/// }
/// ```
public enum AlignSelf: Equatable, CaseIterable {
    /// Inherits the container's ``AlignItems`` value (default).
    case auto
    /// Aligns to the cross-axis start.
    case flexStart
    /// Aligns to the cross-axis end.
    case flexEnd
    /// Centers on the cross axis.
    case center
    /// Stretches to fill the line's cross size.
    case stretch
    /// Aligns to the text baseline shared within the line.
    case baseline

    /// Resolves `.auto` to a concrete value using the container's `alignItems`.
    init(from alignItems: AlignItems) {
        switch alignItems {
        case .flexStart: self = .flexStart
        case .flexEnd:   self = .flexEnd
        case .center:    self = .center
        case .stretch:   self = .stretch
        case .baseline:  self = .baseline
        }
    }
}

/// The initial main-axis size of a flex item *before* free space is distributed.
///
/// Maps to the CSS `flex-basis` property. Together with ``FlexGrowKey`` and
/// ``FlexShrinkKey`` it composes the CSS `flex` shorthand:
///
/// | CSS shorthand        | Swift equivalent                                   |
/// |----------------------|----------------------------------------------------|
/// | `flex: 1`            | `grow: 1, shrink: 1, basis: .points(0)`            |
/// | `flex: auto`         | `grow: 1, shrink: 1, basis: .auto`                 |
/// | `flex: none`         | `grow: 0, shrink: 0, basis: .auto`                 |
/// | `flex-basis: 120px`  | `basis: .points(120)`                              |
/// | `flex-basis: 50%`    | `basis: .fraction(0.5)`                            |
///
/// ```swift
/// // Three equal-width columns (CSS "flex: 1" pattern)
/// FlexBox(direction: .row) {
///     Text("A").flexItem(grow: 1, shrink: 1, basis: .points(0))
///     Text("B").flexItem(grow: 1, shrink: 1, basis: .points(0))
///     Text("C").flexItem(grow: 1, shrink: 1, basis: .points(0))
/// }
///
/// // Or use the shorthand helper:
/// FlexBox(direction: .row) {
///     Text("A").flexItem(flex: 1)
///     Text("B").flexItem(flex: 1)
///     Text("C").flexItem(flex: 1)
/// }
/// ```
public enum FlexBasis: Equatable {
    /// Use the item's intrinsic content size on the main axis (default).
    /// Equivalent to CSS `flex-basis: auto`.
    case auto
    /// A fixed size in points. Equivalent to CSS `flex-basis: 120px`.
    case points(CGFloat)
    /// A fraction of the container's main-axis size.
    /// Equivalent to CSS `flex-basis: 50%` when `f = 0.5`.
    /// Falls back to `.auto` when the container main size is unconstrained.
    case fraction(CGFloat)
}

// MARK: - Container Configuration

/// All flex-container properties bundled into one equatable value.
///
/// `FlexContainerConfig` is the single source of truth passed to ``FlexLayout``
/// and ``FlexBox``. Every property mirrors its CSS counterpart.
///
/// ## Usage
///
/// ```swift
/// // 1. Directly via FlexBox (most common)
/// FlexBox(
///     direction:      .row,
///     wrap:           .wrap,
///     justifyContent: .spaceBetween,
///     alignItems:     .center,
///     gap:            16,
///     padding:        EdgeInsets(top: 20, leading: 20, bottom: 20, trailing: 20)
/// ) {
///     Text("Left")
///     Text("Right")
/// }
///
/// // 2. Via FlexLayout for custom layout containers
/// FlexLayout(.init(direction: .column, gap: 8)) {
///     ForEach(rows) { RowView($0) }
/// }
/// ```
///
/// ## Gap resolution
///
/// The `gap`, `rowGap`, and `columnGap` properties follow the same priority
/// rule as CSS:
///
/// | Axis                          | Resolved gap                     |
/// |-------------------------------|----------------------------------|
/// | Between items (main axis)     | `columnGap ?? gap` (row direction)|
/// | Between lines (cross axis)    | `rowGap ?? gap` (row direction)   |
///
/// For `direction: .column` the axes swap: `rowGap` applies between items and
/// `columnGap` between lines.
public struct FlexContainerConfig: Equatable {
    /// The main axis direction. CSS `flex-direction`. Default `.row`.
    public var direction:      FlexDirection  = .row
    /// Whether items can wrap onto multiple lines. CSS `flex-wrap`. Default `.nowrap`.
    public var wrap:           FlexWrap       = .nowrap
    /// Main-axis distribution of free space. CSS `justify-content`. Default `.flexStart`.
    public var justifyContent: JustifyContent = .flexStart
    /// Cross-axis alignment of items within a line. CSS `align-items`. Default `.stretch`.
    public var alignItems:     AlignItems     = .stretch
    /// Cross-axis distribution of flex lines (multi-line only). CSS `align-content`. Default `.stretch`.
    public var alignContent:   AlignContent   = .stretch
    /// Gap applied to both axes when no axis-specific gap is set. CSS `gap`. Default `0`.
    public var gap:            CGFloat        = 0
    /// Gap between flex lines (cross axis). CSS `row-gap`. Overrides `gap` for lines when set.
    public var rowGap:         CGFloat?
    /// Gap between items within a line (main axis). CSS `column-gap`. Overrides `gap` for items when set.
    public var columnGap:      CGFloat?
    /// Inner spacing between the container boundary and its children. CSS `padding`.
    public var padding:        EdgeInsets     = EdgeInsets()
    /// How overflowing content is handled. CSS `overflow`. Default `.visible`.
    public var overflow:       FlexOverflow   = .visible

    /// Creates a flex container configuration.
    ///
    /// All parameters match CSS property names and default to their CSS initial values.
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
        overflow:       FlexOverflow   = .visible
    ) {
        self.direction      = direction
        self.wrap           = wrap
        self.justifyContent = justifyContent
        self.alignItems     = alignItems
        self.alignContent   = alignContent
        self.gap            = gap
        self.rowGap         = rowGap
        self.columnGap      = columnGap
        self.padding        = padding
        self.overflow       = overflow
    }

    // CSS gap axis mapping:
    //   row direction    → columnGap between items, rowGap between lines
    //   column direction → rowGap between items, columnGap between lines

    /// Effective gap between consecutive items within a flex line (main axis).
    ///
    /// Returns `columnGap` for row-direction containers, `rowGap` for column-direction,
    /// falling back to `gap` when the axis-specific value is not set.
    var mainAxisGap: CGFloat {
        direction.isRow ? (columnGap ?? gap) : (rowGap ?? gap)
    }

    /// Effective gap between flex lines (cross axis).
    ///
    /// Returns `rowGap` for row-direction containers, `columnGap` for column-direction,
    /// falling back to `gap` when the axis-specific value is not set.
    var crossAxisGap: CGFloat {
        direction.isRow ? (rowGap ?? gap) : (columnGap ?? gap)
    }
}
