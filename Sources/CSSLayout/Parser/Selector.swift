// Selector — the Phase 1 simple-selector AST.
//
// Phase 1 supports ID, class, and element selectors only. Phase 2 will
// introduce a `ComplexSelector` wrapper that composes these with combinators
// (`>`, descendant, `,` grouping) — the `SimpleSelector` value remains as-is
// and becomes the leaf of a compound selector chain.

import Foundation

/// A single simple selector.
public enum SimpleSelector: Equatable {
    /// `#foo`
    case id(String)
    /// `.primary`
    case `class`(String)
    /// `button`, `text-input`, etc. — matches a component by its registered type.
    case element(String)
}
