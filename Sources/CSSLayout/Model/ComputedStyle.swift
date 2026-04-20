// ComputedStyle / ItemStyle — the post-cascade style value produced by
// `StyleResolver`.
//
// We deliberately keep container and item style separate inside
// `ComputedStyle` because FlexLayout also separates them: a view becomes a
// `FlexBox(config:)` using `container`, then every child applies `item` via
// `.flexItem(...)`. Storing a single flat struct here means the resolver
// doesn't need to know which properties target which axis — it just writes
// into the right nested field.

import Foundation
import FlexLayout
import CoreGraphics

/// Per-item flex-item properties, mirroring the CSS item-level subset.
///
/// Initial values match the CSS spec defaults exactly (`flex-grow:0`,
/// `flex-shrink:1`, `flex-basis:auto`, etc.) so an unstyled node still
/// renders correctly.
public struct ItemStyle: Equatable {
    public var grow:      CGFloat       = 0
    public var shrink:    CGFloat       = 1
    public var basis:     FlexBasis     = .auto
    public var alignSelf: AlignSelf     = .auto
    public var order:     Int           = 0
    public var width:     FlexSize      = .auto
    public var height:    FlexSize      = .auto
    public var overflow:  FlexOverflow  = .visible
    public var zIndex:    Int           = 0
    public var position:  FlexPosition  = .relative
    public var top:       CGFloat?      = nil
    public var bottom:    CGFloat?      = nil
    public var leading:   CGFloat?      = nil
    public var trailing:  CGFloat?      = nil

    public init() {}
}

/// A fully resolved style for a single CSS node.
///
/// `container` is consumed when the node renders as a flex container (`display:
/// flex` or simply because it has children). `item` is consumed by the parent
/// flex container when laying out this node as one of its items. Both are
/// always populated — using them correctly is the resolver's job.
public struct ComputedStyle: Equatable {
    public var container: FlexContainerConfig = FlexContainerConfig()
    public var item:      ItemStyle           = ItemStyle()
    public var display:   FlexDisplay         = .flex

    public init() {}
}
