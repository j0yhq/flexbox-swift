// Viewport — the runtime context a `MediaQuery` evaluates against.
//
// joy-dom's `Breakpoint.conditions` are pure data; deciding whether a
// breakpoint is "active" requires comparing those conditions against
// the current rendering environment. `Viewport` is that environment,
// reduced to the three signals joy-dom's media queries can ask about:
// width (px), orientation, and print mode.
//
// Production wiring (Unit 6) reads these signals from `GeometryReader`
// + `UITraitCollection` on iOS / `NSWindow` on macOS. Tests construct
// `Viewport` values directly to drive the evaluator (Unit 5) under
// every interesting scenario.

import CoreGraphics
import Foundation

/// The runtime rendering context evaluated against a `MediaQuery`.
public struct Viewport: Equatable {
    /// Available width in points (CSS treats `px` and `pt` as 1:1 in
    /// joy-dom's spec — there's no DPR distinction at this layer).
    public var width: CGFloat

    /// Current orientation. Defaults to `.portrait` because that's the
    /// neutral choice when the host doesn't supply orientation
    /// (e.g. macOS windows that aren't strictly oriented).
    public var orientation: Orientation

    /// Whether the document is being rendered for print. Off by
    /// default; print previews flip it on so `@media print` style
    /// blocks activate.
    public var isPrint: Bool

    public init(
        width: CGFloat,
        orientation: Orientation = .portrait,
        isPrint: Bool = false
    ) {
        self.width = width
        self.orientation = orientation
        self.isPrint = isPrint
    }
}
