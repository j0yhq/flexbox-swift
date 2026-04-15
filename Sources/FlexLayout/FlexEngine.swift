import SwiftUI

// MARK: - FlexItemInput

/// A pure-value description of one flex item, fully decoupled from SwiftUI's `LayoutSubview`.
///
/// `FlexItemInput` is the bridge between the SwiftUI view hierarchy and the pure
/// ``FlexEngine`` algorithm. ``FlexLayout`` converts each `Subviews.Element` into a
/// `FlexItemInput` (via `makeInputs(from:)`), then passes the array to `FlexEngine`.
///
/// ## Why the `measure` closure?
///
/// SwiftUI's `LayoutSubview` cannot be constructed from test code, so any algorithm
/// that calls `subview.sizeThatFits(_:)` directly is untestable in isolation.
/// `FlexItemInput.measure` captures the same measurement contract as a plain closure,
/// enabling full geometry testing without a host app or view hierarchy.
///
/// ## Usage in unit tests
///
/// ```swift
/// // Fixed 100×50 item — the closure ignores the proposal
/// let fixedItem = FlexItemInput(
///     measure: { _ in CGSize(width: 100, height: 50) }
/// )
///
/// // Item that fills whatever is proposed (like SwiftUI's Color)
/// let fillItem = FlexItemInput(
///     measure: { p in CGSize(width: p.width ?? 0, height: p.height ?? 0) },
///     grow: 1
/// )
///
/// // Convenience factories for the common cases:
/// let a = FlexItemInput.fixed(width: 100, height: 50, grow: 1)
/// let b = FlexItemInput.fill(grow: 1)
///
/// let solution = FlexEngine.solve(
///     config:   .init(direction: .row),
///     inputs:   [a, b],
///     proposal: ProposedViewSize(width: 400, height: 200)
/// )
/// // solution.frames[0] → {x:0, y:0, width:100, height:200}
/// // solution.frames[1] → {x:100, y:0, width:300, height:200}
/// ```
struct FlexItemInput {
    /// Returns the item's natural size given a layout proposal.
    ///
    /// In production code this is `{ sv.sizeThatFits($0) }`.
    /// In tests it is any closure that returns a `CGSize`.
    var measure: (ProposedViewSize) -> CGSize

    /// How much this item grows relative to siblings when free main-axis space is available.
    /// CSS `flex-grow`. Default `0` (no growth).
    var grow:          CGFloat

    /// How much this item shrinks relative to siblings when the line overflows.
    /// CSS `flex-shrink`. Default `1`.
    var shrink:        CGFloat

    /// Initial main-axis size before free space is distributed. CSS `flex-basis`. Default `.auto`.
    var basis:         FlexBasis

    /// Cross-axis alignment override for this item. CSS `align-self`. Default `.auto`.
    var alignSelf:     AlignSelf

    /// Visual ordering relative to other items. CSS `order`. Default `0`.
    var order:         Int

    /// Z-axis stacking order. CSS `z-index`. Default `0`.
    var zIndex:        Int

    /// Positioning scheme. CSS `position`. Default `.relative`.
    var position:      FlexPosition

    /// Explicit width override. CSS `width`. Default `.auto`.
    var explicitWidth: FlexSize

    /// Explicit height override. CSS `height`. Default `.auto`.
    var explicitHeight: FlexSize

    // Absolute-positioning insets (only meaningful when `position == .absolute`)
    /// Distance from the container's top edge. CSS `top`.
    var top:           CGFloat?
    /// Distance from the container's bottom edge. CSS `bottom`.
    var bottom:        CGFloat?
    /// Distance from the container's leading (left) edge. CSS `left`.
    var leading:       CGFloat?
    /// Distance from the container's trailing (right) edge. CSS `right`.
    var trailing:      CGFloat?

    /// Creates a flex item input with all flex properties.
    ///
    /// - Parameters:
    ///   - measure:        Closure returning the item's size for a given proposal.
    ///   - grow:           CSS `flex-grow`. Default `0`.
    ///   - shrink:         CSS `flex-shrink`. Default `1`.
    ///   - basis:          CSS `flex-basis`. Default `.auto`.
    ///   - alignSelf:      CSS `align-self`. Default `.auto`.
    ///   - order:          CSS `order`. Default `0`.
    ///   - zIndex:         CSS `z-index`. Default `0`.
    ///   - position:       CSS `position`. Default `.relative`.
    ///   - explicitWidth:  CSS `width`. Default `.auto`.
    ///   - explicitHeight: CSS `height`. Default `.auto`.
    ///   - top:            CSS `top`. Default `nil`.
    ///   - bottom:         CSS `bottom`. Default `nil`.
    ///   - leading:        CSS `left`. Default `nil`.
    ///   - trailing:       CSS `right`. Default `nil`.
    init(
        measure:        @escaping (ProposedViewSize) -> CGSize,
        grow:           CGFloat      = 0,
        shrink:         CGFloat      = 1,
        basis:          FlexBasis    = .auto,
        alignSelf:      AlignSelf    = .auto,
        order:          Int          = 0,
        zIndex:         Int          = 0,
        position:       FlexPosition = .relative,
        explicitWidth:  FlexSize     = .auto,
        explicitHeight: FlexSize     = .auto,
        top:            CGFloat?     = nil,
        bottom:         CGFloat?     = nil,
        leading:        CGFloat?     = nil,
        trailing:       CGFloat?     = nil
    ) {
        self.measure        = measure
        self.grow           = grow
        self.shrink         = shrink
        self.basis          = basis
        self.alignSelf      = alignSelf
        self.order          = order
        self.zIndex         = zIndex
        self.position       = position
        self.explicitWidth  = explicitWidth
        self.explicitHeight = explicitHeight
        self.top            = top
        self.bottom         = bottom
        self.leading        = leading
        self.trailing       = trailing
    }

    // MARK: Convenience factories

    /// Returns a `FlexItemInput` whose `measure` closure always returns `size`.
    ///
    /// This is the most common factory in unit tests: the item has a fixed intrinsic
    /// size that does not respond to the layout proposal.
    ///
    /// ```swift
    /// let item = FlexItemInput.fixed(CGSize(width: 80, height: 40), grow: 1)
    /// ```
    static func fixed(
        _ size: CGSize,
        grow:      CGFloat      = 0,
        shrink:    CGFloat      = 1,
        basis:     FlexBasis    = .auto,
        alignSelf: AlignSelf    = .auto,
        order:     Int          = 0,
        zIndex:    Int          = 0,
        position:  FlexPosition = .relative,
        top:       CGFloat?     = nil,
        bottom:    CGFloat?     = nil,
        leading:   CGFloat?     = nil,
        trailing:  CGFloat?     = nil
    ) -> FlexItemInput {
        FlexItemInput(
            measure:   { _ in size },
            grow:      grow, shrink: shrink, basis: basis,
            alignSelf: alignSelf, order: order, zIndex: zIndex, position: position,
            top: top, bottom: bottom, leading: leading, trailing: trailing
        )
    }

    /// Returns a `FlexItemInput` with a fixed intrinsic size expressed as (width, height).
    ///
    /// ```swift
    /// let item = FlexItemInput.fixed(width: 80, height: 40, grow: 1)
    /// ```
    static func fixed(
        width: CGFloat, height: CGFloat,
        grow:      CGFloat      = 0,
        shrink:    CGFloat      = 1,
        basis:     FlexBasis    = .auto,
        alignSelf: AlignSelf    = .auto,
        order:     Int          = 0,
        zIndex:    Int          = 0,
        position:  FlexPosition = .relative,
        top:       CGFloat?     = nil,
        bottom:    CGFloat?     = nil,
        leading:   CGFloat?     = nil,
        trailing:  CGFloat?     = nil
    ) -> FlexItemInput {
        .fixed(
            CGSize(width: width, height: height),
            grow: grow, shrink: shrink, basis: basis,
            alignSelf: alignSelf, order: order, zIndex: zIndex, position: position,
            top: top, bottom: bottom, leading: leading, trailing: trailing
        )
    }

    /// Returns a `FlexItemInput` that fills whatever size is proposed on both axes.
    ///
    /// Analogous to SwiftUI's `Color` or `Rectangle`: the view accepts any proposed
    /// size without resistance. Useful for testing grow/shrink in isolation.
    ///
    /// ```swift
    /// // Two equal-width fill items that share all available space
    /// let solution = FlexEngine.solve(
    ///     config:   .init(direction: .row),
    ///     inputs:   [.fill(grow: 1), .fill(grow: 1)],
    ///     proposal: ProposedViewSize(width: 400, height: 100)
    /// )
    /// // solution.frames[0].width == 200
    /// // solution.frames[1].width == 200
    /// ```
    static func fill(
        grow:      CGFloat      = 0,
        shrink:    CGFloat      = 1,
        basis:     FlexBasis    = .auto,
        alignSelf: AlignSelf    = .auto,
        order:     Int          = 0,
        zIndex:    Int          = 0
    ) -> FlexItemInput {
        FlexItemInput(
            measure:   { p in CGSize(width: p.width ?? 0, height: p.height ?? 0) },
            grow:      grow, shrink: shrink, basis: basis,
            alignSelf: alignSelf, order: order, zIndex: zIndex
        )
    }
}

// MARK: - FlexSolution

/// The result of one ``FlexEngine/solve(config:inputs:proposal:)`` call.
///
/// All coordinates are relative to the container origin `(0, 0)`. When placing views
/// inside a `CGRect` with a non-zero origin, add `bounds.minX` / `bounds.minY` to
/// each frame as ``FlexLayout`` does in `placeSubviews`.
struct FlexSolution {
    /// Frame of each item, indexed by **input order** (not visual/order-property order).
    ///
    /// `frames[i]` corresponds to `inputs[i]` in the original `[FlexItemInput]` array.
    /// Absolute-position items and order-reordered items are already resolved to their
    /// final positions.
    var frames: [CGRect]

    /// The proposal to pass to `placeSubviews` for each item (same index as `frames`).
    ///
    /// Equal to `CGSize(width: frame.width, height: frame.height)` for in-flow items,
    /// and the resolved absolute size for out-of-flow items.
    var proposals: [ProposedViewSize]

    /// Total size of the flex container, including padding on all sides.
    var containerSize: CGSize
}

// MARK: - Internal layout types (shared between FlexEngine and FlexLayout)

/// An item after flex-basis resolution but before free-space distribution.
///
/// Created in ``FlexEngine/computeRawLayout(config:inputs:proposal:)`` step 2 for each
/// in-flow item. `basisMain` is the resolved `flex-basis` value ready for grow/shrink.
struct RawFlexItem {
    /// Index into the original `[FlexItemInput]` array (source order, not `order`-sorted).
    var inputIndex:         Int
    /// Resolved main-axis basis size in points.
    var basisMain:          CGFloat
    /// `flex-grow` factor.
    var grow:               CGFloat
    /// `flex-shrink` factor.
    var shrink:             CGFloat
    /// Resolved `align-self` value (`.auto` already substituted with container `alignItems`).
    var effectiveAlignSelf: AlignSelf
    /// Explicit cross-axis size in points, or `nil` if the item uses intrinsic cross size.
    var explicitCrossSize:  CGFloat?
    /// CSS `z-index` value.
    var zIndex:             Int
    // Absolute-positioning insets (unused for in-flow items):
    var top:                CGFloat?
    var bottom:             CGFloat?
    var leading:            CGFloat?
    var trailing:           CGFloat?
}

/// A fully resolved flex item ready for placement.
///
/// Produced from ``RawFlexItem`` after grow/shrink, justify-content, align-items,
/// and align-content have been applied.
struct ComputedFlexItem {
    /// Index into the original `[FlexItemInput]` array (source order).
    var inputIndex:  Int
    /// Final main-axis size in points (after grow/shrink).
    var mainSize:    CGFloat
    /// Final cross-axis size in points (after stretch/explicit override).
    var crossSize:   CGFloat
    /// Position on the main axis within the container (after justify-content).
    var mainOffset:  CGFloat
    /// Position on the cross axis within the item's flex line (after align-items/align-self).
    var crossOffset: CGFloat
    /// Distance from cross-start to the text baseline (simplified; equal to crossSize when baseline is used).
    var ascent:      CGFloat
    /// CSS `z-index`.
    var zIndex:      Int
    // Absolute positioning metadata:
    var isAbsolute:  Bool     = false
    var absTop:      CGFloat? = nil
    var absBottom:   CGFloat? = nil
    var absLeading:  CGFloat? = nil
    var absTrailing: CGFloat? = nil
}

/// A fully resolved flex line after grow/shrink, justify-content, and align-content.
struct ComputedFlexLine {
    /// All resolved items in this line, in visual (order-sorted) sequence.
    var items:       [ComputedFlexItem]
    /// Final cross-axis size of this line in points (max of item cross sizes, stretched by `align-content: stretch`).
    var crossSize:   CGFloat
    /// Offset of this line from the container's cross-axis start (after align-content distribution).
    var crossOffset: CGFloat
}

// MARK: - FlexEngine

/// A stateless, pure-Swift implementation of the CSS Flexbox layout algorithm.
///
/// `FlexEngine` is intentionally decoupled from SwiftUI so that every algorithm
/// phase can be exercised in plain XCTest without a view hierarchy. All methods are
/// `static`; the engine has no stored state.
///
/// ## Architecture
///
/// ```
/// [FlexItemInput]  ──┐
///                    ├──▶  computeRawLayout  ──▶  (CGSize, [ComputedFlexLine], [ComputedFlexItem])
/// FlexContainerConfig┘          │
///                               │ (also called internally by solve)
///                               ▼
///                            solve  ──▶  FlexSolution  { frames, proposals, containerSize }
/// ```
///
/// ``FlexLayout`` (the SwiftUI `Layout`) converts its `Subviews` into
/// `[FlexItemInput]` and then delegates to this engine:
///
/// ```swift
/// // In FlexLayout.sizeThatFits:
/// let result = FlexEngine.computeRawLayout(config: config, inputs: inputs, proposal: innerProposal)
///
/// // In FlexLayout.placeSubviews:
/// let solution = FlexEngine.solve(config: config, inputs: inputs, proposal: ...)
/// subviews[i].place(at: origin + solution.frames[i].origin, ...)
/// ```
///
/// ## Algorithm phases in `computeRawLayout`
///
/// 1. Sort items by `order` property.
/// 2. Partition items into in-flow and absolute-position sets.
/// 3. Resolve `flex-basis` for each in-flow item (steps 3–4 of the CSS spec §9).
/// 4. Break items into lines (CSS §9.3).
/// 5. Apply `flex-grow` / `flex-shrink` per line (CSS §9.7–9.11).
/// 6. Measure cross sizes; apply the single-line cross constraint (nowrap only).
/// 7. Compute container size.
/// 8. Apply `justify-content` (main-axis offsets).
/// 9. Apply `align-content` (cross-axis line offsets + optional stretch redistribution).
/// 10. Resolve absolute items.
enum FlexEngine {

    // MARK: - Main entry point

    /// Runs the full flex layout algorithm and returns concrete frames for every item.
    ///
    /// This is the primary API for unit tests and the method called by ``FlexLayout``
    /// in `placeSubviews`.
    ///
    /// - Parameters:
    ///   - config:   All container properties (`direction`, `wrap`, `gap`, etc.).
    ///   - inputs:   One ``FlexItemInput`` per flex item, in source order.
    ///   - proposal: The space offered to the container. `nil` components mean unconstrained.
    /// - Returns:    A ``FlexSolution`` with per-item frames indexed by source order.
    ///
    /// ```swift
    /// let solution = FlexEngine.solve(
    ///     config:   .init(direction: .row, justifyContent: .spaceBetween),
    ///     inputs:   [
    ///         .fixed(width: 60, height: 40),
    ///         .fixed(width: 80, height: 40),
    ///     ],
    ///     proposal: ProposedViewSize(width: 300, height: 100)
    /// )
    /// // solution.frames[0] → {x:0,   y:30, width:60,  height:40}
    /// // solution.frames[1] → {x:220, y:30, width:80,  height:40}
    /// //                        ↑ spaceBetween pushes item to far end
    /// ```
    static func solve(
        config:   FlexContainerConfig,
        inputs:   [FlexItemInput],
        proposal: ProposedViewSize
    ) -> FlexSolution {
        guard !inputs.isEmpty else {
            return FlexSolution(frames: [], proposals: [], containerSize: .zero)
        }

        let pad = config.padding
        let innerProposal = ProposedViewSize(
            width:  proposal.width.map  { max(0, $0 - pad.leading - pad.trailing) },
            height: proposal.height.map { max(0, $0 - pad.top    - pad.bottom   ) }
        )

        let (innerSize, lines, absoluteItems) =
            computeRawLayout(config: config, inputs: inputs, proposal: innerProposal)

        let containerSize = CGSize(
            width:  innerSize.width  + pad.leading + pad.trailing,
            height: innerSize.height + pad.top     + pad.bottom
        )

        var frames    = [CGRect](repeating: .zero, count: inputs.count)
        var proposals = [ProposedViewSize](repeating: .unspecified, count: inputs.count)

        let isRow    = config.direction.isRow
        let innerW   = innerSize.width
        let innerH   = innerSize.height

        // ── In-flow items ─────────────────────────────────────────────────────
        // Each item's frame is built from (mainOffset, crossOffset) plus the
        // line's crossOffset. Padding is added so coordinates are relative to
        // the container's outer (0,0) origin, not the inner content area.
        for line in lines {
            for item in line.items {
                let w = isRow ? item.mainSize  : item.crossSize
                let h = isRow ? item.crossSize : item.mainSize
                let x: CGFloat
                let y: CGFloat
                if isRow {
                    x = pad.leading + item.mainOffset
                    y = pad.top     + line.crossOffset + item.crossOffset
                } else {
                    x = pad.leading + line.crossOffset + item.crossOffset
                    y = pad.top     + item.mainOffset
                }
                frames[item.inputIndex]    = CGRect(x: x, y: y, width: w, height: h)
                proposals[item.inputIndex] = ProposedViewSize(width: w, height: h)
            }
        }

        // ── Absolute items ─────────────────────────────────────────────────────
        // Absolute items are not in any flex line. Their positions are resolved
        // from the container's inner size and the `top/bottom/leading/trailing` insets.
        // When both insets on an axis are set, the item is stretched to fill the gap.
        for absItem in absoluteItems {
            let finalW: CGFloat
            let finalH: CGFloat
            if isRow {
                finalW = (absItem.absLeading != nil && absItem.absTrailing != nil)
                    ? max(0, innerW - absItem.absLeading! - absItem.absTrailing!)
                    : absItem.mainSize
                finalH = (absItem.absTop != nil && absItem.absBottom != nil)
                    ? max(0, innerH - absItem.absTop! - absItem.absBottom!)
                    : absItem.crossSize
            } else {
                finalW = (absItem.absLeading != nil && absItem.absTrailing != nil)
                    ? max(0, innerW - absItem.absLeading! - absItem.absTrailing!)
                    : absItem.crossSize
                finalH = (absItem.absTop != nil && absItem.absBottom != nil)
                    ? max(0, innerH - absItem.absTop! - absItem.absBottom!)
                    : absItem.mainSize
            }

            let x: CGFloat
            if let l = absItem.absLeading        { x = pad.leading + l }
            else if let r = absItem.absTrailing   { x = pad.leading + innerW - r - finalW }
            else                                  { x = pad.leading }

            let y: CGFloat
            if let t = absItem.absTop             { y = pad.top + t }
            else if let b = absItem.absBottom     { y = pad.top + innerH - b - finalH }
            else                                  { y = pad.top }

            frames[absItem.inputIndex]    = CGRect(x: x, y: y, width: finalW, height: finalH)
            proposals[absItem.inputIndex] = ProposedViewSize(width: finalW, height: finalH)
        }

        return FlexSolution(frames: frames, proposals: proposals, containerSize: containerSize)
    }

    // MARK: - Raw layout (used by FlexLayout's sizeThatFits / placeSubviews cache)

    /// Runs the core flex algorithm and returns the container size plus resolved lines.
    ///
    /// Called by both ``solve(config:inputs:proposal:)`` and ``FlexLayout``'s
    /// `sizeThatFits` (where only the container size is needed for the first pass).
    ///
    /// - Parameters:
    ///   - config:   Container configuration.
    ///   - inputs:   Flex items in source order.
    ///   - proposal: Inner (padding-stripped) size offered to the container.
    /// - Returns:
    ///   - `size`:          The container's inner content size (without padding).
    ///   - `lines`:         Resolved in-flow lines with final item frames.
    ///   - `absoluteItems`: Resolved out-of-flow items (not part of any line).
    static func computeRawLayout(
        config:   FlexContainerConfig,
        inputs:   [FlexItemInput],
        proposal: ProposedViewSize
    ) -> (size: CGSize, lines: [ComputedFlexLine], absoluteItems: [ComputedFlexItem]) {

        let isRow    = config.direction.isRow
        let mainGap  = config.mainAxisGap
        let crossGap = config.crossAxisGap

        // Convert nil / infinite proposals to nil (unconstrained).
        let mainConstraint  = (isRow ? proposal.width  : proposal.height)
            .flatMap { $0.isFinite && $0 >= 0 ? $0 : nil }
        let crossConstraint = (isRow ? proposal.height : proposal.width)
            .flatMap { $0.isFinite && $0 >= 0 ? $0 : nil }

        // ── Step 1: Sort by CSS `order` ──────────────────────────────────────
        // Items with a lower `order` value come first; equal values use source order.
        let sortedIndices = inputs.indices.sorted { inputs[$0].order < inputs[$1].order }

        // ── Step 1b: Partition flow vs absolute ──────────────────────────────
        // `position: absolute` items are removed from the flex flow and resolved
        // separately at the end of the algorithm.
        var flowIndices:     [Int] = []
        var absoluteIndices: [Int] = []
        for idx in sortedIndices {
            if inputs[idx].position == .absolute {
                absoluteIndices.append(idx)
            } else {
                flowIndices.append(idx)
            }
        }

        // ── Step 2: Resolve flex-basis for flow items ─────────────────────────
        // For each in-flow item we build a `RawFlexItem` whose `basisMain` is the
        // CSS §9.2 "used value of flex-basis". Priority:
        //   explicit width/height (points/fraction) > flex-basis > intrinsic measure
        let rawItems: [RawFlexItem] = flowIndices.map { idx in
            let input        = inputs[idx]
            let rawAlignSelf = input.alignSelf
            let effectiveAlignSelf = rawAlignSelf == .auto
                ? AlignSelf(from: config.alignItems)
                : rawAlignSelf

            let mainSize   = isRow ? input.explicitWidth  : input.explicitHeight
            let crossSize  = isRow ? input.explicitHeight : input.explicitWidth
            let mainRes    = resolveFlexSizeEx(mainSize,  container: mainConstraint)
            let crossRes   = resolveFlexSizeEx(crossSize, container: crossConstraint)

            // Explicit main-axis value (overrides flex-basis when set).
            let mainExplicit: CGFloat? = {
                if case .value(let v) = mainRes { return v }
                return nil
            }()

            // Explicit cross-axis value (applied after cross sizing).
            var crossExplicit: CGFloat?
            switch crossRes {
            case .value(let v):
                crossExplicit = v
            case .minContent:
                // min-content on the cross axis: measure with a zero cross proposal.
                let p: ProposedViewSize = isRow
                    ? ProposedViewSize(width: nil, height: 0)
                    : ProposedViewSize(width: 0, height: nil)
                let sz = input.measure(p)
                crossExplicit = isRow ? sz.height : sz.width
            case .auto:
                crossExplicit = nil
            }

            // Measure the item's natural size. The cross-axis proposal respects
            // `align-self: stretch` (offer the available cross space) or explicit
            // cross sizes, so the item can size accordingly.
            let measureCross = crossExplicit
                ?? ((effectiveAlignSelf == .stretch) ? crossConstraint : nil)
            let naturalProposal: ProposedViewSize = isRow
                ? ProposedViewSize(width: nil, height: measureCross)
                : ProposedViewSize(width: measureCross, height: nil)
            let naturalSize = input.measure(naturalProposal)

            // Resolve the flex-basis to a point value.
            let basisMain: CGFloat
            if case .minContent = mainRes {
                // min-content on main axis: measure with a zero main-axis proposal.
                let minP: ProposedViewSize = isRow
                    ? ProposedViewSize(width: 0, height: measureCross)
                    : ProposedViewSize(width: measureCross, height: 0)
                basisMain = isRow ? input.measure(minP).width : input.measure(minP).height
            } else {
                switch input.basis {
                case .auto:
                    // CSS: if explicit main size exists, use it; else use intrinsic.
                    basisMain = mainExplicit ?? (isRow ? naturalSize.width : naturalSize.height)
                case .points(let n):
                    basisMain = max(0, n)
                case .fraction(let f):
                    // Percentage basis: resolve against the main constraint.
                    // Falls back to intrinsic size when the container is unconstrained.
                    basisMain = mainConstraint.map { max(0, f * $0) }
                        ?? (isRow ? naturalSize.width : naturalSize.height)
                }
            }

            return RawFlexItem(
                inputIndex:         idx,
                basisMain:          basisMain,
                grow:               input.grow,
                shrink:             input.shrink,
                effectiveAlignSelf: effectiveAlignSelf,
                explicitCrossSize:  crossExplicit,
                zIndex:             input.zIndex,
                top:                input.top,
                bottom:             input.bottom,
                leading:            input.leading,
                trailing:           input.trailing
            )
        }

        // ── Step 3: Line-breaking ─────────────────────────────────────────────
        // `nowrap`: all items go on one line regardless of overflow.
        // `wrap` / `wrapReverse`: start a new line when the next item would exceed
        // the main constraint (with a 0.001 pt tolerance for rounding).
        var lineGroups: [[Int]] = []

        if config.wrap == .nowrap || mainConstraint == nil {
            lineGroups = [Array(rawItems.indices)]
        } else {
            let cm = mainConstraint!
            var lineStart = 0
            var usedMain: CGFloat = 0

            for i in rawItems.indices {
                let itemMain  = rawItems[i].basisMain
                let gapBefore = (i > lineStart) ? mainGap : 0

                if i > lineStart && usedMain + gapBefore + itemMain > cm + 0.001 {
                    lineGroups.append(Array(lineStart..<i))
                    lineStart = i
                    usedMain  = itemMain
                } else {
                    usedMain += gapBefore + itemMain
                }
            }
            if lineStart < rawItems.count {
                lineGroups.append(Array(lineStart..<rawItems.count))
            }
        }

        // ── Steps 4-5: Grow / shrink and cross sizing per line ───────────────
        var lines: [ComputedFlexLine] = []

        for lineGroup in lineGroups {
            let lineRaw    = lineGroup.map { rawItems[$0] }
            let totalBasis = lineRaw.reduce(0) { $0 + $1.basisMain }
            let totalGaps  = CGFloat(max(0, lineRaw.count - 1)) * mainGap

            // Distribute free space via grow or shrink (§9.7–9.11).
            var mainSizes: [CGFloat]
            if let cm = mainConstraint {
                let free = cm - totalBasis - totalGaps
                if free > 0.5 {
                    mainSizes = resolveGrow(items: lineRaw, freeSpace: free)
                } else if free < -0.5 {
                    mainSizes = resolveShrink(items: lineRaw, overflow: -free)
                } else {
                    mainSizes = lineRaw.map { $0.basisMain }
                }
            } else {
                // Unconstrained main axis: no grow or shrink — items use basis size.
                mainSizes = lineRaw.map { $0.basisMain }
            }

            // Measure cross sizes using final main sizes.
            var crossSizes = [CGFloat](repeating: 0, count: lineRaw.count)
            var ascents    = [CGFloat](repeating: 0, count: lineRaw.count)
            var maxAscent: CGFloat = 0

            for i in lineRaw.indices {
                let input  = inputs[lineRaw[i].inputIndex]
                let mainSz = mainSizes[i]

                if let explicitCross = lineRaw[i].explicitCrossSize {
                    crossSizes[i] = explicitCross
                } else {
                    // Propose the resolved main size on the main axis; let the item
                    // determine its cross size naturally.
                    let crossProp: ProposedViewSize = isRow
                        ? ProposedViewSize(width: mainSz, height: nil)
                        : ProposedViewSize(width: nil, height: mainSz)
                    let sz        = input.measure(crossProp)
                    crossSizes[i] = isRow ? sz.height : sz.width
                }

                if lineRaw[i].effectiveAlignSelf == .baseline {
                    ascents[i] = crossSizes[i]   // simplified: ascent = full cross size
                    maxAscent  = max(maxAscent, ascents[i])
                }
            }

            // The line's cross size = max of item cross sizes.
            // For `nowrap` only: expand to fill the cross constraint (CSS §9.4).
            var lineCrossSize: CGFloat = lineRaw.indices.reduce(0) { acc, i in
                max(acc, crossSizes[i])
            }
            lineCrossSize = applySingleLineCrossConstraint(
                config:          config,
                lineCrossSize:   lineCrossSize,
                crossConstraint: crossConstraint
            )

            // Build ComputedFlexItems — main offsets are set to 0 here and
            // populated after justify-content is applied in Step 7.
            var computedItems: [ComputedFlexItem] = []
            for i in lineRaw.indices {
                let mainSz = mainSizes[i]
                var finalCross = crossSizes[i]

                // `align-self: stretch` expands the item to the line's cross size.
                if lineRaw[i].effectiveAlignSelf == .stretch
                    && lineRaw[i].explicitCrossSize == nil {
                    finalCross = lineCrossSize
                }

                let crossOff = itemCrossOffset(
                    alignSelf: lineRaw[i].effectiveAlignSelf,
                    itemCross: finalCross,
                    lineCross: lineCrossSize,
                    ascent:    ascents[i],
                    maxAscent: maxAscent
                )

                computedItems.append(ComputedFlexItem(
                    inputIndex:  lineRaw[i].inputIndex,
                    mainSize:    mainSz,
                    crossSize:   finalCross,
                    mainOffset:  0,          // populated in Step 7
                    crossOffset: crossOff,
                    ascent:      ascents[i],
                    zIndex:      lineRaw[i].zIndex
                ))
            }

            lines.append(ComputedFlexLine(
                items:       computedItems,
                crossSize:   lineCrossSize,
                crossOffset: 0             // populated in Step 8
            ))
        }

        // `wrapReverse` reverses the cross-axis order of lines (not item order within lines).
        if config.wrap == .wrapReverse { lines.reverse() }

        // ── Step 6: Container size ────────────────────────────────────────────
        // When the container is unconstrained on an axis, it hugs its content.
        let totalLineCross = lines.reduce(0) { $0 + $1.crossSize }
        let totalCrossGaps = CGFloat(max(0, lines.count - 1)) * crossGap
        let containerCross: CGFloat = crossConstraint ?? (totalLineCross + totalCrossGaps)
        let containerMain: CGFloat
        if let cm = mainConstraint {
            containerMain = cm
        } else {
            containerMain = lines.map { line in
                line.items.reduce(0) { $0 + $1.mainSize }
                + CGFloat(max(0, line.items.count - 1)) * mainGap
            }.max() ?? 0
        }

        // ── Step 7: justify-content (main-axis offsets) ───────────────────────
        for li in lines.indices {
            let offsets = distributeMain(
                containerMain: containerMain,
                itemSizes:     lines[li].items.map { $0.mainSize },
                gap:           mainGap,
                justify:       config.justifyContent,
                reversed:      config.direction.isReversed
            )
            for i in lines[li].items.indices {
                lines[li].items[i].mainOffset = offsets[i]
            }
        }

        // ── Step 8: align-content (cross-axis line offsets) ───────────────────
        // For `align-content: stretch` with multiple lines, the extra cross space is
        // divided equally among all lines, and stretched items within each line are
        // re-measured against the enlarged line cross size.
        var crossOffsets = distributeLines(
            containerCross: containerCross,
            lineSizes:      lines.map { $0.crossSize },
            gap:            crossGap,
            align:          config.alignContent
        )

        if config.alignContent == .stretch && lines.count > 1 {
            let usedCross = totalLineCross + totalCrossGaps
            let extra     = (containerCross - usedCross) / CGFloat(lines.count)
            if extra > 0 {
                for li in lines.indices {
                    let newLineCross  = lines[li].crossSize + extra
                    lines[li].crossSize = newLineCross
                    let lineMaxAscent = lines[li].items.map { $0.ascent }.max() ?? 0

                    for i in lines[li].items.indices {
                        let item   = lines[li].items[i]
                        let rawIdx = rawItems.firstIndex { $0.inputIndex == item.inputIndex } ?? 0
                        let raw    = rawItems[rawIdx]
                        var finalCross = item.crossSize
                        if raw.effectiveAlignSelf == .stretch && raw.explicitCrossSize == nil {
                            finalCross = newLineCross
                        }
                        lines[li].items[i].crossSize   = finalCross
                        lines[li].items[i].crossOffset = itemCrossOffset(
                            alignSelf:  raw.effectiveAlignSelf,
                            itemCross:  finalCross,
                            lineCross:  newLineCross,
                            ascent:     item.ascent,
                            maxAscent:  lineMaxAscent
                        )
                    }
                }
                // Re-run distribute after line sizes have changed.
                crossOffsets = distributeLines(
                    containerCross: containerCross,
                    lineSizes:      lines.map { $0.crossSize },
                    gap:            crossGap,
                    align:          config.alignContent
                )
            }
        }

        for (li, offset) in crossOffsets.enumerated() {
            lines[li].crossOffset = offset
        }

        // ── Absolute items ────────────────────────────────────────────────────
        // Out-of-flow items are sized and positioned independently of flex lines.
        var absoluteComputedItems: [ComputedFlexItem] = []
        for idx in absoluteIndices {
            let input = inputs[idx]
            let resW  = resolveFlexSizeEx(input.explicitWidth,
                                          container: isRow ? containerMain : containerCross)
            let resH  = resolveFlexSizeEx(input.explicitHeight,
                                          container: isRow ? containerCross : containerMain)

            let w: CGFloat
            switch resW {
            case .value(let v): w = v
            case .minContent:   w = input.measure(ProposedViewSize(width: 0,   height: nil)).width
            case .auto:         w = input.measure(ProposedViewSize(width: nil,  height: nil)).width
            }
            let h: CGFloat
            switch resH {
            case .value(let v): h = v
            case .minContent:   h = input.measure(ProposedViewSize(width: w,   height: 0  )).height
            case .auto:         h = input.measure(ProposedViewSize(width: w,   height: nil)).height
            }

            let mainSz:  CGFloat = isRow ? w : h
            let crossSz: CGFloat = isRow ? h : w

            absoluteComputedItems.append(ComputedFlexItem(
                inputIndex:  idx,
                mainSize:    mainSz,
                crossSize:   crossSz,
                mainOffset:  0,
                crossOffset: 0,
                ascent:      0,
                zIndex:      input.zIndex,
                isAbsolute:  true,
                absTop:      input.top,
                absBottom:   input.bottom,
                absLeading:  input.leading,
                absTrailing: input.trailing
            ))
        }

        let size: CGSize = isRow
            ? CGSize(width: containerMain,  height: containerCross)
            : CGSize(width: containerCross, height: containerMain)

        return (size, lines, absoluteComputedItems)
    }

    // MARK: - Helpers

    /// Intermediate resolution of a ``FlexSize`` value against an optional container size.
    ///
    /// - `.auto` → `.auto` (defer to intrinsic measurement)
    /// - `.minContent` → `.minContent` (trigger a min-content measurement)
    /// - `.points(n)` → `.value(max(0, n))`
    /// - `.fraction(f)` → `.value(max(0, f × container))` when container is known, else `.auto`
    enum ResolvedFlexSize {
        case value(CGFloat)
        case minContent
        case auto
    }

    /// Resolves a ``FlexSize`` to a concrete ``ResolvedFlexSize`` given an optional container dimension.
    ///
    /// - Parameters:
    ///   - size:      The size value to resolve.
    ///   - container: The container's dimension on the same axis, or `nil` if unconstrained.
    static func resolveFlexSizeEx(_ size: FlexSize, container: CGFloat?) -> ResolvedFlexSize {
        switch size {
        case .auto:          return .auto
        case .minContent:    return .minContent
        case .points(let n): return .value(max(0, n))
        case .fraction(let f):
            if let c = container { return .value(max(0, f * c)) }
            return .auto
        }
    }

    /// Applies the CSS §9.4 single-line cross-size rule.
    ///
    /// For `nowrap` containers the single flex line is stretched to fill the entire
    /// cross constraint (if one exists). This rule does **not** apply to `wrap` /
    /// `wrapReverse` containers.
    ///
    /// - Parameters:
    ///   - config:          Container configuration (only `wrap` is inspected).
    ///   - lineCrossSize:   The line's natural cross size (max of item cross sizes).
    ///   - crossConstraint: The container's cross-axis constraint, or `nil`.
    /// - Returns: The effective line cross size — expanded to the cross constraint for `nowrap`.
    static func applySingleLineCrossConstraint(
        config:          FlexContainerConfig,
        lineCrossSize:   CGFloat,
        crossConstraint: CGFloat?
    ) -> CGFloat {
        guard config.wrap == .nowrap, let cc = crossConstraint else { return lineCrossSize }
        return max(lineCrossSize, cc)
    }

    /// Distributes free main-axis space among items proportionally to their `flex-grow` factors.
    ///
    /// Implements CSS §9.7. Items with `grow = 0` receive no extra space.
    ///
    /// - Parameters:
    ///   - items:     In-line items with their `basisMain` and `grow` factors.
    ///   - freeSpace: Positive number of points to distribute.
    /// - Returns: Final main-axis size for each item in the same order as `items`.
    ///
    /// ```
    /// // Basis: [100, 100, 100]; grow: [1, 2, 1]; freeSpace = 80
    /// // totalGrow = 4 → increments: [20, 40, 20]
    /// // Result: [120, 140, 120]
    /// ```
    static func resolveGrow(items: [RawFlexItem], freeSpace: CGFloat) -> [CGFloat] {
        let totalGrow = items.reduce(0) { $0 + $1.grow }
        guard totalGrow > 0 else { return items.map { $0.basisMain } }
        return items.map { $0.basisMain + ($0.grow / totalGrow) * freeSpace }
    }

    /// Shrinks overflowing items proportionally to `shrink × basis`.
    ///
    /// Implements CSS §9.11. The shrink weight for each item is
    /// `(shrink × basis) / Σ(shrinkᵢ × basisᵢ)`, which means items with a larger
    /// basis absorb a proportionally larger share of the overflow.
    ///
    /// - Parameters:
    ///   - items:    In-line items with their `basisMain` and `shrink` factors.
    ///   - overflow: Positive number of points by which the line overflows.
    /// - Returns: Final main-axis size for each item, clamped to `max(0, ...)`.
    ///
    /// ```
    /// // Basis: [200, 100]; shrink: [1, 1]; overflow = 60
    /// // weights: [200/300, 100/300] = [0.667, 0.333]
    /// // Reduction: [40, 20] → Result: [160, 80]
    /// ```
    static func resolveShrink(items: [RawFlexItem], overflow: CGFloat) -> [CGFloat] {
        let totalWeight = items.reduce(0) { $0 + $1.shrink * $1.basisMain }
        guard totalWeight > 0 else { return items.map { $0.basisMain } }
        return items.map { item in
            let weight = item.shrink * item.basisMain / totalWeight
            return max(0, item.basisMain - weight * overflow)
        }
    }

    /// Computes the cross-axis offset of a single item within its flex line.
    ///
    /// Implements `align-self` for one item. Returns the distance from the line's
    /// cross-axis start to the item's cross-axis start.
    ///
    /// - Parameters:
    ///   - alignSelf: The item's resolved (non-auto) `align-self` value.
    ///   - itemCross: The item's cross-axis size in points.
    ///   - lineCross: The line's cross-axis size in points.
    ///   - ascent:    The item's ascent (distance from cross-start to baseline).
    ///   - maxAscent: The maximum ascent among all baseline-aligned items in the line.
    /// - Returns: Cross-axis offset from the line start to the item start.
    static func itemCrossOffset(
        alignSelf: AlignSelf,
        itemCross: CGFloat,
        lineCross: CGFloat,
        ascent:    CGFloat,
        maxAscent: CGFloat
    ) -> CGFloat {
        switch alignSelf {
        case .auto, .stretch, .flexStart: return 0
        case .flexEnd:                    return max(0, lineCross - itemCross)
        case .center:                     return (lineCross - itemCross) / 2
        case .baseline:                   return max(0, maxAscent - ascent)
        }
    }

    /// Assigns main-axis offsets to items in a single flex line (implements `justify-content`).
    ///
    /// All `justify-content` modes are derived from two quantities:
    /// - `free = containerMain − Σ(itemSizes) − Σ(gaps)`
    /// - Starting position and spacing per mode (see table below):
    ///
    /// | `justify`       | Initial offset | Gap between items              |
    /// |-----------------|----------------|--------------------------------|
    /// | `.flexStart`    | `0`            | `gap`                          |
    /// | `.flexEnd`      | `free`         | `gap`                          |
    /// | `.center`       | `free / 2`     | `gap`                          |
    /// | `.spaceBetween` | `0`            | `gap + free/(n-1)`             |
    /// | `.spaceAround`  | `free/n / 2`   | `gap + free/n`                 |
    /// | `.spaceEvenly`  | `free/(n+1)`   | `gap + free/(n+1)`             |
    ///
    /// - Parameters:
    ///   - containerMain: Total main-axis size of the container.
    ///   - itemSizes:     Resolved main-axis sizes for each item in visual order.
    ///   - gap:           Gap between consecutive items (`mainAxisGap`).
    ///   - justify:       The container's `justify-content` value.
    ///   - reversed:      `true` for `rowReverse` / `columnReverse` directions.
    /// - Returns: Main-axis offset for each item, indexed in the same order as `itemSizes`.
    static func distributeMain(
        containerMain: CGFloat,
        itemSizes:     [CGFloat],
        gap:           CGFloat,
        justify:       JustifyContent,
        reversed:      Bool
    ) -> [CGFloat] {
        let count = itemSizes.count
        guard count > 0 else { return [] }

        let totalItems = itemSizes.reduce(0, +)
        let totalGaps  = CGFloat(max(0, count - 1)) * gap
        let free       = containerMain - totalItems - totalGaps

        var offsets = [CGFloat](repeating: 0, count: count)

        switch justify {
        case .flexStart:
            var pos: CGFloat = 0
            for i in 0..<count { offsets[i] = pos; pos += itemSizes[i] + gap }
        case .flexEnd:
            var pos: CGFloat = max(0, free)
            for i in 0..<count { offsets[i] = pos; pos += itemSizes[i] + gap }
        case .center:
            var pos: CGFloat = free / 2
            for i in 0..<count { offsets[i] = pos; pos += itemSizes[i] + gap }
        case .spaceBetween:
            let extra = count > 1 ? free / CGFloat(count - 1) : 0
            var pos: CGFloat = 0
            for i in 0..<count { offsets[i] = pos; pos += itemSizes[i] + gap + extra }
        case .spaceAround:
            let spacing = free / CGFloat(max(1, count))
            var pos: CGFloat = spacing / 2
            for i in 0..<count { offsets[i] = pos; pos += itemSizes[i] + gap + spacing }
        case .spaceEvenly:
            let spacing = free / CGFloat(count + 1)
            var pos: CGFloat = spacing
            for i in 0..<count { offsets[i] = pos; pos += itemSizes[i] + gap + spacing }
        }

        // For reversed directions, mirror offsets so the visual order is reversed.
        if reversed {
            return offsets.enumerated().map { i, offset in
                containerMain - offset - itemSizes[i]
            }
        }
        return offsets
    }

    /// Assigns cross-axis offsets to flex lines (implements `align-content`).
    ///
    /// Mirrors `distributeMain` but operates on lines and the cross axis.
    /// The `stretch` case is handled separately in `computeRawLayout` (it enlarges
    /// lines and re-stretches items); here it behaves identically to `flexStart`.
    ///
    /// - Parameters:
    ///   - containerCross: Total cross-axis size of the container.
    ///   - lineSizes:      Cross-axis size of each flex line.
    ///   - gap:            Gap between consecutive lines (`crossAxisGap`).
    ///   - align:          The container's `align-content` value.
    /// - Returns: Cross-axis offset for each line, indexed in the same order as `lineSizes`.
    static func distributeLines(
        containerCross: CGFloat,
        lineSizes:      [CGFloat],
        gap:            CGFloat,
        align:          AlignContent
    ) -> [CGFloat] {
        let count = lineSizes.count
        guard count > 0 else { return [] }

        let totalLines = lineSizes.reduce(0, +)
        let totalGaps  = CGFloat(max(0, count - 1)) * gap
        let free       = containerCross - totalLines - totalGaps

        var offsets = [CGFloat](repeating: 0, count: count)

        switch align {
        case .flexStart, .stretch:
            // `stretch` lines are pre-enlarged before this function is called a second time,
            // so at call time they behave like `flexStart`.
            var pos: CGFloat = 0
            for i in 0..<count { offsets[i] = pos; pos += lineSizes[i] + gap }
        case .flexEnd:
            var pos: CGFloat = max(0, free)
            for i in 0..<count { offsets[i] = pos; pos += lineSizes[i] + gap }
        case .center:
            var pos: CGFloat = free / 2
            for i in 0..<count { offsets[i] = pos; pos += lineSizes[i] + gap }
        case .spaceBetween:
            let extra = count > 1 ? free / CGFloat(count - 1) : 0
            var pos: CGFloat = 0
            for i in 0..<count { offsets[i] = pos; pos += lineSizes[i] + gap + extra }
        case .spaceAround:
            let spacing = free / CGFloat(max(1, count))
            var pos: CGFloat = spacing / 2
            for i in 0..<count { offsets[i] = pos; pos += lineSizes[i] + gap + spacing }
        case .spaceEvenly:
            let spacing = free / CGFloat(count + 1)
            var pos: CGFloat = spacing
            for i in 0..<count { offsets[i] = pos; pos += lineSizes[i] + gap + spacing }
        }
        return offsets
    }
}
