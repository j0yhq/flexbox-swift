// CSSDiagnostics — a single accumulator for non-fatal warnings emitted by
// every parsing/cascade/resolution stage.
//
// CSSLayout never throws on bad input; it collects warnings here and the
// caller (or the `CSSLayout` view, via an `onDiagnostic` closure in Unit l)
// can surface them in debug builds.

import Foundation

/// A single non-fatal warning produced while parsing or resolving CSS.
///
/// `kind` is a structured discriminator so tests can assert on categories
/// without string-matching. `detail` is a human-readable message suitable
/// for console logs in debug.
public struct CSSWarning: Equatable {
    public enum Kind: Equatable {
        /// A property outside the §4.1 supported subset.
        case unsupportedProperty(String)
        /// A selector form not supported in Phase 1 (attributes, pseudos,
        /// combinators).
        case unsupportedSelector(String)
        /// An at-rule like `@media` that is parsed-skipped in Phase 1.
        case unsupportedAtRule(String)
        /// A property value that couldn't be parsed.
        case invalidValue(property: String, value: String)
        /// Any other parse-level recovery event.
        case other
    }

    public let kind: Kind
    public let detail: String

    public init(_ kind: Kind, _ detail: String = "") {
        self.kind = kind
        self.detail = detail
    }
}

/// Accumulator passed `inout` through the parsing/cascade pipeline.
public struct CSSDiagnostics: Equatable {
    public private(set) var warnings: [CSSWarning] = []

    public init() {}

    public mutating func warn(_ w: CSSWarning) {
        warnings.append(w)
    }

    /// Convenience for tests: count warnings of a particular kind.
    public func count(of kind: CSSWarning.Kind) -> Int {
        warnings.filter { $0.kind == kind }.count
    }
}
