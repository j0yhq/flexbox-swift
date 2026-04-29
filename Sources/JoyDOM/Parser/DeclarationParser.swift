// DeclarationParser — splits a rule-block body into `Declaration` values.
//
// Input is the text *between* the `{` and `}` of a rule. Phase 1 supports
// exactly the properties enumerated in §4.1 of the design doc; anything else
// is dropped with an `.unsupportedProperty` diagnostic.
//
// The parser is tolerant by design:
//   • missing trailing `;` is fine (common in hand-edited CSS)
//   • stray `;;` collapses to a single delimiter
//   • declarations with no `:` are silently skipped
//   • `!important` is accepted and stripped (we don't model importance in
//     Phase 1 — the cascade is specificity + source-order only)
//
// We walk the raw string rather than routing through `CSSTokenizer` because
// a value like `1 1 120px` needs its internal whitespace preserved, and the
// tokenizer would split that into three tokens.

import Foundation

/// Parses a declaration-block body into a list of ``Declaration`` values.
public enum DeclarationParser {

    /// The §4.1-supported property allow-list.
    ///
    /// Anything outside this set produces an `.unsupportedProperty(name)`
    /// diagnostic and is dropped from the output. Changes to the Phase 1
    /// scope happen here.
    static let supportedProperties: Set<String> = [
        // Container
        "display",
        "flex-direction", "flex-wrap",
        "justify-content", "align-items", "align-content",
        "gap", "row-gap", "column-gap",
        "padding", "padding-top", "padding-bottom", "padding-left", "padding-right",
        "overflow",
        // Item
        "flex", "flex-grow", "flex-shrink", "flex-basis",
        "align-self", "order",
        "width", "height",
        "z-index",
        "position", "top", "bottom", "left", "right",
        // Visibility (Phase 2)
        "visibility",
    ]

    /// Parse `body` — the text between `{` and `}` of a single rule.
    ///
    /// - Parameters:
    ///   - body: Raw declaration text. May contain any whitespace, comments
    ///     are *not* handled here (they should have been stripped upstream
    ///     by the tokenizer or a preprocessing pass).
    ///   - diagnostics: Accumulator for warnings. Unsupported properties and
    ///     malformed declarations append here.
    /// - Returns: The accepted ``Declaration`` values in source order.
    public static func parse(
        _ body: String,
        diagnostics: inout JoyDiagnostics
    ) -> [Declaration] {
        var out: [Declaration] = []
        for segment in body.split(separator: ";", omittingEmptySubsequences: true) {
            let raw = String(segment).trimmingCharacters(in: .whitespacesAndNewlines)
            guard !raw.isEmpty else { continue }

            // Split on the first `:` — values may legitimately contain colons
            // (e.g. a URL) but Phase 1's subset doesn't; still, be defensive.
            guard let colonIdx = raw.firstIndex(of: ":") else {
                diagnostics.warn(.init(.other, "malformed declaration: \(raw)"))
                continue
            }

            let propertyRaw = raw[..<colonIdx]
                .trimmingCharacters(in: .whitespacesAndNewlines)
            let valueRaw = raw[raw.index(after: colonIdx)...]
                .trimmingCharacters(in: .whitespacesAndNewlines)
            guard !propertyRaw.isEmpty, !valueRaw.isEmpty else {
                diagnostics.warn(.init(.other, "malformed declaration: \(raw)"))
                continue
            }

            let property = propertyRaw.lowercased()
            let value = stripImportant(valueRaw)

            guard supportedProperties.contains(property) else {
                diagnostics.warn(.init(.unsupportedProperty(property), value))
                continue
            }

            out.append(Declaration(property: property, value: value))
        }
        return out
    }

    // MARK: - Helpers

    /// Removes a trailing `!important` suffix (case-insensitive) and returns
    /// the remaining value, trimmed. Phase 1 does not model importance.
    private static func stripImportant(_ value: String) -> String {
        let suffix = "!important"
        let lower = value.lowercased()
        guard lower.hasSuffix(suffix) else { return value }
        let trimmed = value.dropLast(suffix.count)
        return String(trimmed).trimmingCharacters(in: .whitespacesAndNewlines)
    }
}
