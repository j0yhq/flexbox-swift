import SwiftUI

// MARK: - New Spec Primitives

/// Controls how content that overflows a flex container is rendered. CSS `overflow`.
public enum FlexOverflow: Equatable {
    case visible    // default — content is not clipped
    case hidden     // content clipped, no scroll
    case clip       // same as hidden (suppresses programmatic scroll in browsers)
    case scroll     // content clipped, scrollable
    case auto       // clipped only when content overflows (approximated as hidden in SwiftUI)
}

/// CSS `position` — controls whether an item participates in normal flex flow.
public enum FlexPosition: Equatable {
    case relative   // default — item stays in normal flow
    case absolute   // item removed from flow; positioned by top/right/bottom/left
}

/// Explicit width or height value. CSS `width` / `height`.
public enum FlexSize: Equatable {
    case auto                   // no explicit size override (default)
    case points(CGFloat)        // fixed px value
    case fraction(CGFloat)      // percentage of container's corresponding axis (0.5 = 50%)
    case minContent             // size to intrinsic content
}

/// CSS `display` property — controls how an item participates in layout.
public enum FlexDisplay: Equatable {
    case flex       // default: participates in flex sizing normally
    case block      // takes full cross-axis width; forces its own line
    case inline     // uses min-content sizing; does not grow
}

// MARK: - Container Properties

/// Establishes the main axis direction for flex items.
public enum FlexDirection: Equatable, CaseIterable {
    /// Items flow left → right (default).
    case row
    /// Items flow right → left.
    case rowReverse
    /// Items flow top → bottom.
    case column
    /// Items flow bottom → top.
    case columnReverse

    var isRow: Bool { self == .row || self == .rowReverse }
    var isReversed: Bool { self == .rowReverse || self == .columnReverse }
}

/// Controls whether flex items are forced onto one line or can wrap onto multiple lines.
public enum FlexWrap: Equatable, CaseIterable {
    /// All items on one line (default). Items may overflow.
    case nowrap
    /// Items wrap onto new lines, added in the cross-axis direction.
    case wrap
    /// Items wrap onto new lines added in the reverse cross-axis direction.
    case wrapReverse
}

/// Distributes free space along the main axis.
public enum JustifyContent: Equatable, CaseIterable {
    /// Items packed toward the start of the main axis (default).
    case flexStart
    /// Items packed toward the end of the main axis.
    case flexEnd
    /// Items centered along the main axis.
    case center
    /// Items evenly distributed; first at start, last at end.
    case spaceBetween
    /// Items evenly distributed with equal space around each.
    case spaceAround
    /// Items evenly distributed with equal space between all items and edges.
    case spaceEvenly
}

/// Aligns flex items along the cross axis within a single line.
public enum AlignItems: Equatable, CaseIterable {
    /// Items aligned to the start of the cross axis.
    case flexStart
    /// Items aligned to the end of the cross axis.
    case flexEnd
    /// Items centered on the cross axis.
    case center
    /// Items stretched to fill the line's cross size (default).
    case stretch
    /// Items aligned to their text baseline.
    case baseline
}

/// Aligns flex lines when there is extra space on the cross axis (multi-line only).
public enum AlignContent: Equatable, CaseIterable {
    /// Lines packed toward the start of the cross axis.
    case flexStart
    /// Lines packed toward the end of the cross axis.
    case flexEnd
    /// Lines centered on the cross axis.
    case center
    /// Lines evenly distributed; first at start, last at end.
    case spaceBetween
    /// Lines evenly distributed with equal space around each.
    case spaceAround
    /// Lines evenly distributed with equal space between all lines and edges.
    case spaceEvenly
    /// Lines stretched to fill the container (default).
    case stretch
}

// MARK: - Item Properties

/// Overrides the container's `alignItems` for a single flex item.
public enum AlignSelf: Equatable, CaseIterable {
    /// Inherits the container's `alignItems` value (default).
    case auto
    case flexStart
    case flexEnd
    case center
    case stretch
    case baseline

    /// Resolve `.auto` using the container's `alignItems`.
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

/// Sets the initial main-axis size of a flex item before free space is distributed.
public enum FlexBasis: Equatable {
    /// Use the item's natural (intrinsic) size on the main axis (default).
    case auto
    /// Fixed size in points (equivalent to CSS `flex-basis: 120px`).
    case points(CGFloat)
    /// Fraction of the container's main-axis size (e.g. `0.5` = 50%).
    /// Falls back to `.auto` when the container main size is unconstrained.
    case fraction(CGFloat)
}

// MARK: - Container Configuration

/// All flex container properties collected in one value.
public struct FlexContainerConfig: Equatable {
    public var direction:      FlexDirection  = .row
    public var wrap:           FlexWrap       = .nowrap
    public var justifyContent: JustifyContent = .flexStart
    public var alignItems:     AlignItems     = .stretch
    public var alignContent:   AlignContent   = .stretch
    /// Default gap applied to both axes.
    public var gap:            CGFloat        = 0
    /// Gap between flex lines (overrides `gap` for the cross axis).
    public var rowGap:         CGFloat?
    /// Gap between items in a line (overrides `gap` for the main axis when direction is row).
    public var columnGap:      CGFloat?
    /// Inner spacing between the container boundary and its children. CSS `padding`.
    public var padding:        EdgeInsets     = EdgeInsets()
    /// How overflowing content is handled. CSS `overflow`. Default `.visible`.
    public var overflow:       FlexOverflow   = .visible

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

    // In CSS: column-gap = between items within a row; row-gap = between lines.
    // For column direction these swap: row-gap is between items, column-gap between lines.

    /// Gap between consecutive items within a flex line (main axis).
    var mainAxisGap: CGFloat {
        direction.isRow ? (columnGap ?? gap) : (rowGap ?? gap)
    }

    /// Gap between flex lines (cross axis).
    var crossAxisGap: CGFloat {
        direction.isRow ? (rowGap ?? gap) : (columnGap ?? gap)
    }
}
