// Specificity — CSS selector specificity per the spec cascade model
// (see design doc §4.1 / CSS Selectors Level 3 §16).
//
// Four components, lexicographically compared:
//   a — inline styles (always 0 for stylesheet-sourced rules)
//   b — number of ID selectors
//   c — number of class / attribute / pseudo-class selectors
//   d — number of element / pseudo-element selectors

import Foundation

/// CSS specificity. Higher values win in the cascade; ties break by source
/// order (handled by `StyleResolver`, not here).
public struct Specificity: Equatable, Comparable {
    public let a: Int
    public let b: Int
    public let c: Int
    public let d: Int

    public init(a: Int = 0, b: Int = 0, c: Int = 0, d: Int = 0) {
        self.a = a; self.b = b; self.c = c; self.d = d
    }

    /// Specificity of a single simple selector.
    public static func of(_ selector: SimpleSelector) -> Specificity {
        switch selector {
        case .id:      return Specificity(a: 0, b: 1, c: 0, d: 0)
        case .class:   return Specificity(a: 0, b: 0, c: 1, d: 0)
        case .element: return Specificity(a: 0, b: 0, c: 0, d: 1)
        }
    }

    public static func < (lhs: Specificity, rhs: Specificity) -> Bool {
        if lhs.a != rhs.a { return lhs.a < rhs.a }
        if lhs.b != rhs.b { return lhs.b < rhs.b }
        if lhs.c != rhs.c { return lhs.c < rhs.c }
        return lhs.d < rhs.d
    }
}
