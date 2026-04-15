import SwiftUI

/// A SwiftUI `Layout` that implements the full CSS Flexbox specification.
///
/// `FlexLayout` is the low-level engine adapter. It conforms to SwiftUI's `Layout`
/// protocol, converts `Subviews` into ``FlexItemInput`` arrays, and delegates all
/// geometry computation to the pure ``FlexEngine``.
///
/// ## When to use `FlexLayout` vs `FlexBox`
///
/// - **``FlexBox``** (recommended) — a `View` that wraps `FlexLayout` with a
///   `@ViewBuilder` closure. Use this in the vast majority of cases.
/// - **`FlexLayout`** — use directly when you need `AnyLayout` switching, the
///   `Layout` protocol's `Subviews` access, or a custom `Layout` composition.
///
/// ```swift
/// // Direct usage of FlexLayout (AnyLayout pattern)
/// let layout: AnyLayout = isVertical
///     ? AnyLayout(FlexLayout(.init(direction: .column, gap: 8)))
///     : AnyLayout(FlexLayout(.init(direction: .row,    gap: 8)))
///
/// layout {
///     Text("A").flexItem(grow: 1)
///     Text("B").flexItem(grow: 1)
/// }
/// ```
///
/// ## Two-pass layout model
///
/// SwiftUI calls `sizeThatFits` first (possibly several times) and then
/// `placeSubviews` once with the final bounds. `FlexLayout` follows this pattern:
///
/// 1. **`sizeThatFits`** → calls `FlexEngine.computeRawLayout` to get the intrinsic
///    container size and caches the intermediate ``ComputedFlexLine`` array.
/// 2. **`placeSubviews`** → calls `FlexEngine.solve` with the *actual* placement
///    bounds (which may differ from the `sizeThatFits` result if the container was
///    stretched by a parent), then places each subview using `solution.frames[i]`.
///
/// > Note: `placeSubviews` always recomputes rather than relying solely on the cache,
/// because the bounds passed there can have a larger cross-axis size than the value
/// returned by `sizeThatFits` (flex containers act as block boxes in cross axis).
public struct FlexLayout: Layout {

    /// The complete set of flex container properties for this layout.
    public var config: FlexContainerConfig

    /// Creates a `FlexLayout` with the given container configuration.
    ///
    /// - Parameter config: All container properties. Defaults to a zero-gap, row-direction,
    ///   no-wrap configuration — matching CSS initial values.
    public init(_ config: FlexContainerConfig = FlexContainerConfig()) {
        self.config = config
    }

    // MARK: - Cache

    /// Intermediate layout state retained between `sizeThatFits` and `placeSubviews`.
    ///
    /// SwiftUI guarantees that the cache is passed back to `placeSubviews` after the
    /// matching `sizeThatFits` call, so the resolved line data does not need to be
    /// recomputed from scratch in the placement phase.
    public struct Cache {
        /// Resolved flex lines from the most recent `sizeThatFits` call.
        var lines:         [ComputedFlexLine] = []
        /// Out-of-flow (absolute-position) items from the most recent `sizeThatFits` call.
        var absoluteItems: [ComputedFlexItem] = []
        /// The container size returned by the most recent `sizeThatFits` call.
        var containerSize: CGSize = .zero
    }

    // MARK: - Layout Protocol

    public func makeCache(subviews: Subviews) -> Cache { Cache() }

    /// Returns the container size that fits the proposed space and stores intermediate
    /// layout data in `cache` for use by `placeSubviews`.
    ///
    /// ### Size rules
    /// - **Main axis (wrapping)**: if `wrap != .nowrap` and a finite main proposal is
    ///   available, the container claims exactly that space (matching CSS block-level
    ///   behaviour). Otherwise it hugs content.
    /// - **Cross axis**: fills the proposed cross size when finite; otherwise hugs content.
    public func sizeThatFits(
        proposal: ProposedViewSize,
        subviews: Subviews,
        cache: inout Cache
    ) -> CGSize {
        guard !subviews.isEmpty else { return .zero }

        // Strip padding before passing to the engine; add it back to the result.
        let pad = config.padding
        let innerProposal = ProposedViewSize(
            width:  proposal.width.map  { max(0, $0 - pad.leading - pad.trailing) },
            height: proposal.height.map { max(0, $0 - pad.top     - pad.bottom  ) }
        )

        let inputs = makeInputs(from: subviews)
        let result = FlexEngine.computeRawLayout(
            config:   config,
            inputs:   inputs,
            proposal: innerProposal
        )
        cache.lines         = result.lines
        cache.absoluteItems = result.absoluteItems

        let contentW = result.size.width  + pad.leading + pad.trailing
        let contentH = result.size.height + pad.top     + pad.bottom
        let isRow = config.direction.isRow

        let mainContent   = isRow ? contentW : contentH
        let crossContent  = isRow ? contentH : contentW
        let mainProposal  = isRow ? proposal.width  : proposal.height
        let crossProposal = isRow ? proposal.height : proposal.width

        // Main axis: wrapping containers claim their full allocation; others hug content.
        let finalMain: CGFloat
        if config.wrap != .nowrap, let mp = mainProposal, mp.isFinite {
            finalMain = mp
        } else {
            finalMain = mainProposal.flatMap { $0.isFinite ? max(mainContent, $0) : nil }
                ?? mainContent
        }

        // Cross axis: fill the proposed cross size (flex container is a block box).
        let finalCross = crossProposal.flatMap { $0.isFinite ? max(crossContent, $0) : nil }
            ?? crossContent

        cache.containerSize = isRow
            ? CGSize(width: finalMain, height: finalCross)
            : CGSize(width: finalCross, height: finalMain)
        return cache.containerSize
    }

    /// Places every subview using the concrete frames from ``FlexEngine/solve(config:inputs:proposal:)``.
    ///
    /// The placement bounds may be larger than what `sizeThatFits` returned (e.g., when
    /// a parent HStack stretches the container cross-axis). A full recompute with the
    /// actual bounds is therefore always performed here rather than reusing the cache.
    public func placeSubviews(
        in bounds: CGRect,
        proposal: ProposedViewSize,
        subviews: Subviews,
        cache: inout Cache
    ) {
        guard !subviews.isEmpty else { return }

        // Use the actual placement bounds as the proposal so items fill the true space.
        let pad = config.padding
        let innerProposal = ProposedViewSize(
            width:  (bounds.width  > 0) ? max(0, bounds.width  - pad.leading - pad.trailing) : nil,
            height: (bounds.height > 0) ? max(0, bounds.height - pad.top     - pad.bottom  ) : nil
        )
        _ = innerProposal  // used for documentation clarity; solve uses full bounds

        let inputs = makeInputs(from: subviews)
        let solution = FlexEngine.solve(
            config:   config,
            inputs:   inputs,
            proposal: ProposedViewSize(width: bounds.width, height: bounds.height)
        )

        // `solution.frames` are relative to (0, 0). Shift by the bounds origin.
        for i in inputs.indices {
            let frame    = solution.frames[i]
            let proposal = solution.proposals[i]
            subviews[i].place(
                at:       CGPoint(x: bounds.minX + frame.minX, y: bounds.minY + frame.minY),
                anchor:   .topLeading,
                proposal: proposal
            )
        }
    }

    // MARK: - applySingleLineCrossConstraint (exposed for legacy unit tests)

    /// Delegates to ``FlexEngine/applySingleLineCrossConstraint(config:lineCrossSize:crossConstraint:)``.
    ///
    /// Kept as a package-internal wrapper so existing `FlexLayoutTests` that call
    /// this method on a `FlexLayout` instance continue to compile without changes.
    func applySingleLineCrossConstraint(
        _ lineCrossSize: CGFloat,
        crossConstraint: CGFloat?
    ) -> CGFloat {
        FlexEngine.applySingleLineCrossConstraint(
            config:          config,
            lineCrossSize:   lineCrossSize,
            crossConstraint: crossConstraint
        )
    }

    // MARK: - Subview → FlexItemInput conversion

    /// Converts each SwiftUI `LayoutSubview` into a ``FlexItemInput`` by reading all
    /// ``LayoutValueKey`` values that the child attached via `.flexItem(...)`.
    ///
    /// The `measure` closure captures `sv.sizeThatFits` so that `FlexEngine` can call
    /// it without holding a reference to SwiftUI's `Subviews` collection.
    private func makeInputs(from subviews: Subviews) -> [FlexItemInput] {
        subviews.map { sv in
            FlexItemInput(
                measure:        { sv.sizeThatFits($0) },
                grow:           sv[FlexGrowKey.self],
                shrink:         sv[FlexShrinkKey.self],
                basis:          sv[FlexBasisKey.self],
                alignSelf:      sv[AlignSelfKey.self],
                order:          sv[FlexOrderKey.self],
                zIndex:         sv[FlexZIndexKey.self],
                position:       sv[FlexPositionKey.self],
                explicitWidth:  sv[FlexWidthKey.self],
                explicitHeight: sv[FlexHeightKey.self],
                top:            sv[FlexTopKey.self],
                bottom:         sv[FlexBottomKey.self],
                leading:        sv[FlexLeadingKey.self],
                trailing:       sv[FlexTrailingKey.self]
            )
        }
    }

    // MARK: - Min-content helper

    /// Returns the minimum content size of `subview` on `axis`.
    ///
    /// Implemented by proposing `0` on the target axis and reading back the resulting
    /// size. Used when an item's `width` or `height` is `.minContent`.
    private func minContentSize(
        subview: Subviews.Element,
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
}
