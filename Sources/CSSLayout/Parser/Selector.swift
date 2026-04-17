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

/// A compound selector — a chain of simple selectors that all apply to the
/// same subject (no intervening whitespace or combinator). The CSS grammar
/// calls this a "compound selector" and it's the building block of
/// `ComplexSelector` (Phase 2 combinators).
///
/// Phase 2 currently uses a compound as the full rule selector, so a bare
/// `#a` is modelled as a compound of length one.
public struct CompoundSelector: Equatable {
    /// Non-empty sequence of simple selectors, preserved in source order.
    public let parts: [SimpleSelector]

    /// Preferred init for explicit part lists. Traps on empty input.
    public init(_ parts: [SimpleSelector]) {
        precondition(!parts.isEmpty, "CompoundSelector requires at least one part")
        self.parts = parts
    }

    /// Convenience init for the common "single simple selector" case.
    public init(_ single: SimpleSelector) {
        self.parts = [single]
    }
}

// MARK: - Dot-syntax factories
//
// These make assertions like `XCTAssertEqual(rule.selector, .id("a"))` keep
// working after the refactor from `SimpleSelector` to `CompoundSelector` —
// dot-syntax resolves to these when the expected type is `CompoundSelector`.

extension CompoundSelector {
    public static func id(_ name: String) -> CompoundSelector {
        CompoundSelector(.id(name))
    }
    public static func `class`(_ name: String) -> CompoundSelector {
        CompoundSelector(.class(name))
    }
    public static func element(_ name: String) -> CompoundSelector {
        CompoundSelector(.element(name))
    }
}
