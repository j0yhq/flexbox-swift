// BreakpointResolver — given a `Viewport` (Unit 5) and a list of
// `Breakpoint`s (Unit 1), pick the one breakpoint that should be
// active for the current render.
//
// Matching rule (per Josh's `DOM/guides/Breakpoints.md`):
//   • A breakpoint matches when *all* its `conditions` evaluate true
//     against the viewport. Empty conditions are vacuously true.
//
// Selection rule (per "cascade approach" in the same doc):
//   • Among matching breakpoints, the one with the *most conditions*
//     (specificity) wins.
//   • Ties on specificity are broken by source order — the later
//     breakpoint wins, mirroring CSS's "later rule overrides earlier
//     rule at equal specificity" convention.
//   • Only one breakpoint is active at a time. Josh explicitly ruled
//     out merging across multiple matching breakpoints.

import Foundation

/// Pure-function resolver for which breakpoint applies right now.
public enum BreakpointResolver {

    // MARK: - Public API

    /// Choose the active breakpoint for `viewport`, or `nil` if none of
    /// `breakpoints` matches.
    public static func active(
        in viewport: Viewport,
        breakpoints: [Breakpoint]
    ) -> Breakpoint? {
        return nil
    }

    /// Return the *index* of the active breakpoint inside `breakpoints`,
    /// or `nil` if none matches. Exposed alongside `active(in:_:)` so
    /// Unit 8's cache layer can key on the chosen breakpoint without
    /// re-comparing it by value.
    public static func activeIndex(
        in viewport: Viewport,
        breakpoints: [Breakpoint]
    ) -> Int? {
        return nil
    }
}
