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
        guard let index = activeIndex(in: viewport, breakpoints: breakpoints) else {
            return nil
        }
        return breakpoints[index]
    }

    /// Return the *index* of the active breakpoint inside `breakpoints`,
    /// or `nil` if none matches. Exposed alongside `active(in:_:)` so
    /// Unit 8's cache layer can key on the chosen breakpoint without
    /// re-comparing it by value.
    public static func activeIndex(
        in viewport: Viewport,
        breakpoints: [Breakpoint]
    ) -> Int? {
        // Walk in source order and remember the most-specific match
        // seen so far. Ties are broken by replacing on equal-or-higher
        // specificity, which gives later source-order entries the win.
        var winnerIndex: Int? = nil
        var winnerSpecificity: Int = -1

        for (i, bp) in breakpoints.enumerated() {
            guard matches(bp, in: viewport) else { continue }
            let specificity = bp.conditions.count
            if specificity >= winnerSpecificity {
                winnerSpecificity = specificity
                winnerIndex = i
            }
        }
        return winnerIndex
    }

    // MARK: - Match check

    /// True iff every condition in `breakpoint` evaluates true against
    /// `viewport`. Empty `conditions` is vacuously true.
    private static func matches(
        _ breakpoint: Breakpoint,
        in viewport: Viewport
    ) -> Bool {
        breakpoint.conditions.allSatisfy { $0.matches(in: viewport) }
    }
}
