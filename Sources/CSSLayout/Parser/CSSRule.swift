// CSSRule — one parsed `selector { declarations }` block.
//
// Source order is assigned by `RuleParser` in file order and is the cascade
// tie-breaker when two rules have identical specificity (CSS cascade spec
// §6.4.4). The selector carries its own `Specificity` so the resolver can
// sort without recomputing it per rule.

import Foundation

/// One parsed CSS rule.
public struct CSSRule: Equatable {
    /// The (Phase 1: simple) selector this rule matches against.
    public let selector: SimpleSelector
    /// Declarations in source order. Unsupported properties have already
    /// been filtered out by ``DeclarationParser``.
    public let declarations: [Declaration]
    /// Cached specificity of `selector`.
    public let specificity: Specificity
    /// Monotonic 0-based index — later rules win on equal specificity.
    public let sourceOrder: Int

    public init(
        selector: SimpleSelector,
        declarations: [Declaration],
        specificity: Specificity,
        sourceOrder: Int
    ) {
        self.selector = selector
        self.declarations = declarations
        self.specificity = specificity
        self.sourceOrder = sourceOrder
    }
}
