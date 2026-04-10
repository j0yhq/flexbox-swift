import SwiftUI

/// A SwiftUI `Layout` that implements the full CSS Flexbox specification.
///
/// Use `FlexBox` (in `FlexView.swift`) as a convenient SwiftUI view wrapper,
/// or call `FlexLayout` directly as a layout container:
///
/// ```swift
/// FlexLayout(.init(direction: .row, wrap: .wrap, gap: 8)) {
///     Text("A").flexItem(grow: 1)
///     Text("B").flexItem(basis: .points(120))
/// }
/// ```
public struct FlexLayout: Layout {

    public var config: FlexContainerConfig

    public init(_ config: FlexContainerConfig = FlexContainerConfig()) {
        self.config = config
    }

    // MARK: - Cache

    public struct Cache {
        var lines:         [ComputedLine] = []
        var absoluteItems: [ComputedItem] = []   // out-of-flow items (position: absolute)
        var containerSize: CGSize = .zero
    }

    // A fully resolved flex line, ready for placement.
    struct ComputedLine {
        var items: [ComputedItem]
        var crossSize: CGFloat      // final cross-axis size of this line
        var crossOffset: CGFloat    // position on the cross axis (set by align-content)
    }

    // A fully resolved flex item within a line, ready for placement.
    struct ComputedItem {
        var subviewIndex: Int       // original index into the Subviews collection
        var mainSize: CGFloat       // final size on the main axis
        var crossSize: CGFloat      // final size on the cross axis
        var mainOffset: CGFloat     // position on the main axis (set by justify-content)
        var crossOffset: CGFloat    // position within the line on the cross axis
        var ascent: CGFloat         // distance from cross-start to text baseline
        var zIndex: Int             // CSS z-index (used to sort painter order)
        // Absolute positioning insets (only meaningful for out-of-flow items)
        var isAbsolute:   Bool      = false
        var absTop:       CGFloat?  = nil
        var absBottom:    CGFloat?  = nil
        var absLeading:   CGFloat?  = nil
        var absTrailing:  CGFloat?  = nil
    }

    // MARK: - Layout Protocol

    public func makeCache(subviews: Subviews) -> Cache { Cache() }

    public func sizeThatFits(
        proposal: ProposedViewSize,
        subviews: Subviews,
        cache: inout Cache
    ) -> CGSize {
        guard !subviews.isEmpty else { return .zero }

        let pad = config.padding
        // Subtract padding from available space before the flex algorithm runs.
        let innerProposal = ProposedViewSize(
            width:  proposal.width.map  { max(0, $0 - pad.leading - pad.trailing) },
            height: proposal.height.map { max(0, $0 - pad.top - pad.bottom) }
        )

        let result = computeLayout(proposal: innerProposal, subviews: subviews)
        cache.lines         = result.lines
        cache.absoluteItems = result.absoluteItems
        // Add padding back to the reported container size.
        // On the CROSS axis: fill the proposal (a flex container acts like a block box).
        // On the MAIN axis: use the computed size (content-driven; wrapping stays within proposal).
        let contentW = result.size.width  + pad.leading + pad.trailing
        let contentH = result.size.height + pad.top + pad.bottom
        let isRow = config.direction.isRow
        let mainContent  = isRow ? contentW : contentH
        let crossContent = isRow ? contentH : contentW
        let mainProposal  = isRow ? proposal.width  : proposal.height
        let crossProposal = isRow ? proposal.height : proposal.width

        // Main axis: for wrapping containers, clamp to proposal (don't expand beyond it).
        // For non-wrapping, fill the proposal if larger than content.
        let finalMain: CGFloat
        if config.wrap != .nowrap, let mp = mainProposal, mp.isFinite {
            finalMain = mp  // wrapping container stays within its allocation
        } else {
            finalMain = mainProposal.flatMap { $0.isFinite ? max(mainContent, $0) : nil } ?? mainContent
        }
        // Cross axis: fill the proposed cross size (so children can grow/stretch into it)
        let finalCross = crossProposal.flatMap { $0.isFinite ? max(crossContent, $0) : nil } ?? crossContent

        cache.containerSize = isRow
            ? CGSize(width: finalMain, height: finalCross)
            : CGSize(width: finalCross, height: finalMain)
        return cache.containerSize
    }

    public func placeSubviews(
        in bounds: CGRect,
        proposal: ProposedViewSize,
        subviews: Subviews,
        cache: inout Cache
    ) {
        guard !subviews.isEmpty else { return }

        // Always recompute layout using the actual placement bounds.
        // sizeThatFits may have returned a larger size (filling the proposal),
        // so the cached layout from sizeThatFits may be for a smaller area.
        let pad = config.padding
        let innerProposal = ProposedViewSize(
            width:  (bounds.width  > 0) ? max(0, bounds.width  - pad.leading - pad.trailing) : nil,
            height: (bounds.height > 0) ? max(0, bounds.height - pad.top - pad.bottom)       : nil
        )
        let result = computeLayout(proposal: innerProposal, subviews: subviews)
        let lines         = result.lines
        let absoluteItems = result.absoluteItems

        let isRow = config.direction.isRow

        // The bounds after removing container padding — this is the coordinate
        // space all offsets in ComputedItem/ComputedLine are relative to.
        let innerBounds = CGRect(
            x:      bounds.minX + pad.leading,
            y:      bounds.minY + pad.top,
            width:  max(0, bounds.width  - pad.leading - pad.trailing),
            height: max(0, bounds.height - pad.top - pad.bottom)
        )

        // ── Place in-flow items (sorted by z-index, then source order) ──
        // Flatten all items across lines while preserving their line cross offsets.
        struct PlaceEntry {
            var item: ComputedItem
            var lineCrossOffset: CGFloat
            var sourceOrder: Int
        }
        var entries: [PlaceEntry] = []
        var sourceOrder = 0
        for line in lines {
            for item in line.items {
                entries.append(PlaceEntry(item: item, lineCrossOffset: line.crossOffset, sourceOrder: sourceOrder))
                sourceOrder += 1
            }
        }
        entries.sort {
            if $0.item.zIndex == $1.item.zIndex {
                return $0.sourceOrder < $1.sourceOrder
            }
            return $0.item.zIndex < $1.item.zIndex
        }

        for entry in entries {
            let item = entry.item
            let width:  CGFloat = isRow ? item.mainSize  : item.crossSize
            let height: CGFloat = isRow ? item.crossSize : item.mainSize
            let x: CGFloat
            let y: CGFloat

            if isRow {
                x = innerBounds.minX + item.mainOffset
                y = innerBounds.minY + entry.lineCrossOffset + item.crossOffset
            } else {
                x = innerBounds.minX + entry.lineCrossOffset + item.crossOffset
                y = innerBounds.minY + item.mainOffset
            }

            subviews[item.subviewIndex].place(
                at: CGPoint(x: x, y: y),
                anchor: .topLeading,
                proposal: ProposedViewSize(width: width, height: height)
            )
        }

        // ── Place absolutely-positioned items (sorted by z-index, then source order) ──
        let sortedAbsolute = absoluteItems.enumerated().sorted {
            if $0.element.zIndex == $1.element.zIndex {
                return $0.offset < $1.offset
            }
            return $0.element.zIndex < $1.element.zIndex
        }.map(\.element)
        for absItem in sortedAbsolute {
            let sv = subviews[absItem.subviewIndex]

            // Re-resolve dimensions based on which insets are set:
            let finalW: CGFloat
            let finalH: CGFloat
            if isRow {
                finalW = (absItem.absLeading != nil && absItem.absTrailing != nil)
                    ? max(0, innerBounds.width - absItem.absLeading! - absItem.absTrailing!)
                    : absItem.mainSize
                finalH = (absItem.absTop != nil && absItem.absBottom != nil)
                    ? max(0, innerBounds.height - absItem.absTop! - absItem.absBottom!)
                    : absItem.crossSize
            } else {
                finalW = (absItem.absLeading != nil && absItem.absTrailing != nil)
                    ? max(0, innerBounds.width - absItem.absLeading! - absItem.absTrailing!)
                    : absItem.crossSize
                finalH = (absItem.absTop != nil && absItem.absBottom != nil)
                    ? max(0, innerBounds.height - absItem.absTop! - absItem.absBottom!)
                    : absItem.mainSize
            }

            let x: CGFloat
            if let l = absItem.absLeading {
                x = innerBounds.minX + l
            } else if let r = absItem.absTrailing {
                x = innerBounds.maxX - r - finalW
            } else {
                x = innerBounds.minX
            }

            let y: CGFloat
            if let t = absItem.absTop {
                y = innerBounds.minY + t
            } else if let b = absItem.absBottom {
                y = innerBounds.maxY - b - finalH
            } else {
                y = innerBounds.minY
            }

            sv.place(
                at: CGPoint(x: x, y: y),
                anchor: .topLeading,
                proposal: ProposedViewSize(width: finalW, height: finalH)
            )
        }
    }

    // MARK: - Core Flex Algorithm

    /// Intermediate representation of a flex item before sizing is resolved.
    private struct RawItem {
        var subviewIndex:       Int
        var basisMain:          CGFloat
        var grow:               CGFloat
        var shrink:             CGFloat
        var effectiveAlignSelf: AlignSelf
        var explicitCrossSize:  CGFloat?   // resolved explicit size on the cross axis
        var position:           FlexPosition
        var zIndex:             Int
        var top:                CGFloat?
        var bottom:             CGFloat?
        var leading:            CGFloat?
        var trailing:           CGFloat?
    }

    // MARK: - resolveFlexSize helpers

    /// Extended resolution result that distinguishes `.auto` from `.minContent`.
    private enum ResolvedSize {
        case value(CGFloat)
        case minContent
        case auto
    }

    /// Resolve a `FlexSize` into a concrete value, or signal auto/min-content.
    private func resolveFlexSizeEx(_ size: FlexSize, container: CGFloat?) -> ResolvedSize {
        switch size {
        case .auto:
            return .auto
        case .minContent:
            return .minContent
        case .points(let n):
            return .value(max(0, n))
        case .fraction(let f):
            if let c = container { return .value(max(0, f * c)) }
            return .auto
        }
    }

    /// Convenience: resolve to optional CGFloat (treats minContent as nil, like auto).
    /// Used in paths that don't need to distinguish the two.
    private func resolveFlexSize(_ size: FlexSize, container: CGFloat?) -> CGFloat? {
        switch resolveFlexSizeEx(size, container: container) {
        case .value(let v): return v
        default:            return nil
        }
    }

    /// Compute min-content size for a subview on the given axis.
    /// Proposes 0 on that axis to force the view to report its minimum wrapping size.
    private func minContentSize(
        subview: LayoutSubview,
        axis: Axis,
        otherAxisSize: CGFloat? = nil
    ) -> CGFloat {
        let proposal: ProposedViewSize
        switch axis {
        case .horizontal:
            proposal = ProposedViewSize(width: 0, height: otherAxisSize)
        case .vertical:
            proposal = ProposedViewSize(width: otherAxisSize, height: 0)
        }
        let sz = subview.sizeThatFits(proposal)
        return axis == .horizontal ? sz.width : sz.height
    }

    private enum Axis { case horizontal, vertical }

    private func computeLayout(
        proposal: ProposedViewSize,
        subviews: Subviews
    ) -> (size: CGSize, lines: [ComputedLine], absoluteItems: [ComputedItem]) {

        let isRow     = config.direction.isRow
        let mainGap   = config.mainAxisGap
        let crossGap  = config.crossAxisGap

        let mainConstraint  = (isRow ? proposal.width  : proposal.height).flatMap { $0.isFinite && $0 >= 0 ? $0 : nil }
        let crossConstraint = (isRow ? proposal.height : proposal.width ).flatMap { $0.isFinite && $0 >= 0 ? $0 : nil }

        // ── Step 1: Sort subviews by CSS `order` ────────────────────────────
        let sortedIndices = subviews.indices.sorted {
            subviews[$0][FlexOrderKey.self] < subviews[$1][FlexOrderKey.self]
        }

        // ── Step 1b: Partition into flow vs absolute items ───────────────────
        var flowIndices:     [Int] = []
        var absoluteIndices: [Int] = []
        for idx in sortedIndices {
            if subviews[idx][FlexPositionKey.self] == .absolute {
                absoluteIndices.append(idx)
            } else {
                flowIndices.append(idx)
            }
        }

        // ── Step 2: Resolve flex-basis for every IN-FLOW item ────────────────
        let rawItems: [RawItem] = flowIndices.map { idx in
            let sv   = subviews[idx]
            let grow = sv[FlexGrowKey.self]
            let shrink = sv[FlexShrinkKey.self]
            let rawAlignSelf = sv[AlignSelfKey.self]
            let effectiveAlignSelf = rawAlignSelf == .auto
                ? AlignSelf(from: config.alignItems)
                : rawAlignSelf

            // Explicit width/height from FlexWidthKey / FlexHeightKey
            let rawWidth  = sv[FlexWidthKey.self]
            let rawHeight = sv[FlexHeightKey.self]
            let mainResolved  = resolveFlexSizeEx(isRow ? rawWidth : rawHeight, container: mainConstraint)
            let crossResolved = resolveFlexSizeEx(isRow ? rawHeight : rawWidth, container: crossConstraint)

            let mainExplicit:  CGFloat? = { if case .value(let v) = mainResolved  { return v }; return nil }()
            var crossExplicit: CGFloat?
            switch crossResolved {
            case .value(let v):   crossExplicit = v
            case .minContent:     crossExplicit = minContentSize(subview: sv, axis: isRow ? .vertical : .horizontal)
            case .auto:           crossExplicit = nil
            }

            // Measuring the natural main-axis size with `.unspecified` causes
            // nested wrapping containers to report a stale single-line size.
            // When we know the cross axis, include it in the measurement so
            // auto/fallback basis can react to width changes.
            let measureCross = crossExplicit
                ?? ((effectiveAlignSelf == .stretch) ? crossConstraint : nil)
            let naturalProposal = makeProposal(main: nil, cross: measureCross, isRow: isRow)
            let naturalSize = sv.sizeThatFits(naturalProposal)

            let basisMain: CGFloat
            // min-content on the main axis always wins (even over flex-basis)
            if case .minContent = mainResolved {
                basisMain = minContentSize(subview: sv, axis: isRow ? .horizontal : .vertical)
            } else {
                switch sv[FlexBasisKey.self] {
                case .auto:
                    if let explicit = mainExplicit {
                        basisMain = explicit
                    } else {
                        basisMain = isRow ? naturalSize.width : naturalSize.height
                    }
                case .points(let n):
                    basisMain = max(0, n)
                case .fraction(let f):
                    if let cm = mainConstraint {
                        basisMain = max(0, f * cm)
                    } else {
                        basisMain = isRow ? naturalSize.width : naturalSize.height
                    }
                }
            }

            return RawItem(
                subviewIndex:       idx,
                basisMain:          basisMain,
                grow:               grow,
                shrink:             shrink,
                effectiveAlignSelf: effectiveAlignSelf,
                explicitCrossSize:  crossExplicit,
                position:           .relative,
                zIndex:             sv[FlexZIndexKey.self],
                top:                sv[FlexTopKey.self],
                bottom:             sv[FlexBottomKey.self],
                leading:            sv[FlexLeadingKey.self],
                trailing:           sv[FlexTrailingKey.self]
            )
        }

        // ── Step 3: Line-breaking ────────────────────────────────────────────
        var lineGroups: [[Int]] = []

        if config.wrap == .nowrap || mainConstraint == nil {
            lineGroups = [Array(rawItems.indices)]
        } else {
            let cm = mainConstraint!
            var lineStart = 0
            var usedMain: CGFloat = 0

            for i in rawItems.indices {
                let itemMain = rawItems[i].basisMain
                let gapBefore: CGFloat = (i > lineStart) ? mainGap : 0

                if i > lineStart && usedMain + gapBefore + itemMain > cm + 0.001 {
                    lineGroups.append(Array(lineStart..<i))
                    lineStart = i
                    usedMain = itemMain
                } else {
                    usedMain += gapBefore + itemMain
                }
            }
            if lineStart < rawItems.count {
                lineGroups.append(Array(lineStart..<rawItems.count))
            }
        }

        // ── Steps 4–5: Resolve main & cross sizes per line ──────────────────
        var lines: [ComputedLine] = []

        for lineGroup in lineGroups {
            let lineRaw   = lineGroup.map { rawItems[$0] }
            let totalBasis = lineRaw.reduce(0) { $0 + $1.basisMain }
            let totalGaps  = CGFloat(max(0, lineRaw.count - 1)) * mainGap

            // ── 4a. Flex grow / shrink ──────────────────────────────────────
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
                mainSizes = lineRaw.map { $0.basisMain }
            }

            // ── 4b. Cross sizes, ascents, line cross size ──────────────────
            var crossSizes = [CGFloat](repeating: 0, count: lineRaw.count)
            var ascents    = [CGFloat](repeating: 0, count: lineRaw.count)
            var maxAscent: CGFloat = 0

            for i in lineRaw.indices {
                let sv        = subviews[lineRaw[i].subviewIndex]
                let mainSz    = mainSizes[i]

                // Use explicit cross size if set; otherwise query the subview.
                if let explicitCross = lineRaw[i].explicitCrossSize {
                    crossSizes[i] = explicitCross
                } else {
                    let crossProp = makeProposal(main: mainSz, cross: nil, isRow: isRow)
                    let sz        = sv.sizeThatFits(crossProp)
                    crossSizes[i] = isRow ? sz.height : sz.width
                }

                if lineRaw[i].effectiveAlignSelf == .baseline {
                    let crossProp = makeProposal(main: mainSz, cross: nil, isRow: isRow)
                    let dims   = sv.dimensions(in: crossProp)
                    let b      = dims[.lastTextBaseline]
                    ascents[i] = b
                    maxAscent  = max(maxAscent, b)
                }
            }

            var lineCrossSize: CGFloat = 0
            for i in lineRaw.indices {
                switch lineRaw[i].effectiveAlignSelf {
                case .stretch:
                    lineCrossSize = max(lineCrossSize, crossSizes[i])
                case .baseline:
                    let descent = crossSizes[i] - ascents[i]
                    lineCrossSize = max(lineCrossSize, maxAscent + descent)
                default:
                    lineCrossSize = max(lineCrossSize, crossSizes[i])
                }
            }
            // CSS single-line flex containers are specifically `flex-wrap: nowrap`.
            // `wrap` containers that happen to produce one line should not use this rule.
            if config.wrap == .nowrap, let cc = crossConstraint {
                lineCrossSize = max(lineCrossSize, cc)
            }

            // ── 4c. Final cross sizes + cross offsets per item ─────────────
            var computedItems: [ComputedItem] = []
            for i in lineRaw.indices {
                let mainSz = mainSizes[i]
                var finalCross = crossSizes[i]

                if lineRaw[i].effectiveAlignSelf == .stretch && lineRaw[i].explicitCrossSize == nil {
                    // CSS stretch: cross-size IS the line size — don't re-query the child.
                    // The child gets this size as a proposal in placeSubviews and decides
                    // how to render within it (Text wraps, shapes fill, etc.)
                    finalCross = lineCrossSize
                }

                let crossOff = itemCrossOffset(
                    alignSelf: lineRaw[i].effectiveAlignSelf,
                    itemCross: finalCross,
                    lineCross: lineCrossSize,
                    ascent: ascents[i],
                    maxAscent: maxAscent
                )

                computedItems.append(ComputedItem(
                    subviewIndex: lineRaw[i].subviewIndex,
                    mainSize:    mainSz,
                    crossSize:   finalCross,
                    mainOffset:  0,
                    crossOffset: crossOff,
                    ascent:      ascents[i],
                    zIndex:      lineRaw[i].zIndex
                ))
            }

            lines.append(ComputedLine(
                items:       computedItems,
                crossSize:   lineCrossSize,
                crossOffset: 0
            ))
        }

        if config.wrap == .wrapReverse { lines.reverse() }

        // ── Step 6: Compute final container size ─────────────────────────────
        let totalLineCross = lines.reduce(0) { $0 + $1.crossSize }
        let totalCrossGaps = CGFloat(max(0, lines.count - 1)) * crossGap

        let containerCross: CGFloat = crossConstraint ?? (totalLineCross + totalCrossGaps)
        let containerMain: CGFloat
        if let cm = mainConstraint {
            containerMain = cm
        } else {
            containerMain = lines.map { line -> CGFloat in
                let items = line.items.reduce(0) { $0 + $1.mainSize }
                return items + CGFloat(max(0, line.items.count - 1)) * mainGap
            }.max() ?? 0
        }

        // ── Step 7: justify-content ──────────────────────────────────────────
        for li in lines.indices {
            let line     = lines[li]
            let itemMainSizes = line.items.map { $0.mainSize }
            let offsets  = distributeMain(
                containerMain: containerMain,
                itemSizes:     itemMainSizes,
                gap:           mainGap,
                justify:       config.justifyContent,
                reversed:      config.direction.isReversed
            )
            for i in line.items.indices {
                lines[li].items[i].mainOffset = offsets[i]
            }
        }

        // ── Step 8: align-content ────────────────────────────────────────────
        let lineSizes = lines.map { $0.crossSize }
        var crossOffsets = distributeLines(
            containerCross: containerCross,
            lineSizes:      lineSizes,
            gap:            crossGap,
            align:          config.alignContent
        )

        if config.alignContent == .stretch && lines.count > 1 {
            let usedCross = totalLineCross + totalCrossGaps
            let extra     = (containerCross - usedCross) / CGFloat(lines.count)
            if extra > 0 {
                for li in lines.indices {
                    let newLineCross = lines[li].crossSize + extra
                    lines[li].crossSize = newLineCross
                    let lineMaxAscent: CGFloat = lines[li].items.map { $0.ascent }.max() ?? 0

                    for i in lines[li].items.indices {
                        let item = lines[li].items[i]
                        let rawIdx = flowIndices.firstIndex(of: item.subviewIndex) ?? 0
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

        // ── Resolve absolute items ───────────────────────────────────────────
        // These are out-of-flow — they don't affect container sizing.
        var absoluteComputedItems: [ComputedItem] = []
        for idx in absoluteIndices {
            let sv = subviews[idx]
            let rawW = sv[FlexWidthKey.self]
            let rawH = sv[FlexHeightKey.self]
            let resW = resolveFlexSizeEx(rawW, container: isRow ? containerMain : containerCross)
            let resH = resolveFlexSizeEx(rawH, container: isRow ? containerCross : containerMain)

            // Resolve each axis, handling min-content specifically.
            let w: CGFloat
            switch resW {
            case .value(let v):   w = v
            case .minContent:     w = minContentSize(subview: sv, axis: .horizontal)
            case .auto:           w = sv.sizeThatFits(ProposedViewSize(width: nil, height: nil)).width
            }
            let h: CGFloat
            switch resH {
            case .value(let v):   h = v
            case .minContent:     h = minContentSize(subview: sv, axis: .vertical, otherAxisSize: w)
            case .auto:           h = sv.sizeThatFits(ProposedViewSize(width: w, height: nil)).height
            }

            // Store main/cross in the correct field based on direction.
            let mainSz:  CGFloat = isRow ? w : h
            let crossSz: CGFloat = isRow ? h : w

            absoluteComputedItems.append(ComputedItem(
                subviewIndex: idx,
                mainSize:     mainSz,
                crossSize:    crossSz,
                mainOffset:   0,
                crossOffset:  0,
                ascent:       0,
                zIndex:       sv[FlexZIndexKey.self],
                isAbsolute:   true,
                absTop:       sv[FlexTopKey.self],
                absBottom:    sv[FlexBottomKey.self],
                absLeading:   sv[FlexLeadingKey.self],
                absTrailing:  sv[FlexTrailingKey.self]
            ))
        }

        let size: CGSize = isRow
            ? CGSize(width: containerMain,  height: containerCross)
            : CGSize(width: containerCross, height: containerMain)

        return (size, lines, absoluteComputedItems)
    }

    // MARK: - Flex Grow

    private func resolveGrow(items: [RawItem], freeSpace: CGFloat) -> [CGFloat] {
        let totalGrow = items.reduce(0) { $0 + $1.grow }
        guard totalGrow > 0 else { return items.map { $0.basisMain } }
        return items.map { $0.basisMain + ($0.grow / totalGrow) * freeSpace }
    }

    // MARK: - Flex Shrink

    private func resolveShrink(items: [RawItem], overflow: CGFloat) -> [CGFloat] {
        let totalWeight = items.reduce(0) { $0 + $1.shrink * $1.basisMain }
        guard totalWeight > 0 else { return items.map { $0.basisMain } }
        return items.map { item in
            let weight = item.shrink * item.basisMain / totalWeight
            return max(0, item.basisMain - weight * overflow)
        }
    }

    // MARK: - justify-content distribution

    private func distributeMain(
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
            let spacing = count > 0 ? free / CGFloat(count) : 0
            var pos: CGFloat = spacing / 2
            for i in 0..<count { offsets[i] = pos; pos += itemSizes[i] + gap + spacing }

        case .spaceEvenly:
            let spacing = count > 0 ? free / CGFloat(count + 1) : 0
            var pos: CGFloat = spacing
            for i in 0..<count { offsets[i] = pos; pos += itemSizes[i] + gap + spacing }
        }

        if reversed {
            return offsets.enumerated().map { i, offset in
                containerMain - offset - itemSizes[i]
            }
        }

        return offsets
    }

    // MARK: - align-content distribution

    private func distributeLines(
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

    // MARK: - align-self per item

    private func itemCrossOffset(
        alignSelf: AlignSelf,
        itemCross: CGFloat,
        lineCross: CGFloat,
        ascent:    CGFloat,
        maxAscent: CGFloat
    ) -> CGFloat {
        switch alignSelf {
        case .auto, .stretch, .flexStart:
            return 0
        case .flexEnd:
            return max(0, lineCross - itemCross)
        case .center:
            return (lineCross - itemCross) / 2
        case .baseline:
            return max(0, maxAscent - ascent)
        }
    }

    // MARK: - Proposal Helper

    private func makeProposal(main: CGFloat?, cross: CGFloat?, isRow: Bool) -> ProposedViewSize {
        isRow
            ? ProposedViewSize(width: main,  height: cross)
            : ProposedViewSize(width: cross, height: main)
    }
}
