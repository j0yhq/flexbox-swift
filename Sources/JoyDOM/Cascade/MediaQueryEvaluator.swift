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
        switch self {
        case .logical(let op, let conditions):
            switch op {
            case .and:
                // `allSatisfy` returns true on the empty array
                // (vacuously true) which is the correct CSS behavior.
                return conditions.allSatisfy { $0.matches(in: viewport) }
            case .or:
                // `contains(where:)` returns false on the empty array
                // (vacuously false) — matches CSS.
                return conditions.contains(where: { $0.matches(in: viewport) })
            }

        case .not(let inner):
            return !inner.matches(in: viewport)

        case .type(let kind):
            switch kind {
            case .print:
                return viewport.isPrint
            }

        case .width(let op, let value, _):
            // Without an operator+value pair, the query is a feature-
            // presence test: `(width)` always matches in joy-dom (a
            // viewport always has a width). With both supplied, compare.
            guard let op = op, let value = value else { return true }
            switch op {
            case .greaterThan:        return viewport.width >  CGFloat(value)
            case .lessThan:           return viewport.width <  CGFloat(value)
            case .greaterThanOrEqual: return viewport.width >= CGFloat(value)
            case .lessThanOrEqual:    return viewport.width <= CGFloat(value)
            }

        case .orientation(let o):
            return viewport.orientation == o
        }
    }
}
