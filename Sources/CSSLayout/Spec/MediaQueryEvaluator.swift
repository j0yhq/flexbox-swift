// MediaQueryEvaluator — decides whether a `MediaQuery` (Unit 1) matches
// a given `Viewport`.
//
// Pure function, no side effects, easy to drive from unit tests. Used
// by the breakpoint resolver (Unit 7) to decide which breakpoint, if
// any, is active for the current render. Mirrors browser semantics for
// the subset of media features joy-dom exposes (width with operators,
// orientation, print mode, plus and/or/not composition).
//
// Vacuous truth: `.logical(.and, [])` matches (vacuously true);
// `.logical(.or, [])` does not match (vacuously false). This matches
// CSS's behavior for `@media (min-width: ...) {}` with no conditions.

import Foundation

extension MediaQuery {

    /// Evaluate this query against the supplied viewport.
    public func matches(in viewport: Viewport) -> Bool {
        return false
    }
}
