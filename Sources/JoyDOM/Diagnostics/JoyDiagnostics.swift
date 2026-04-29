// JoyDiagnostics — a single accumulator for non-fatal warnings emitted by
// every parsing/cascade/resolution stage.
//
// JoyDOMView never throws on bad input; it collects warnings here and the
// caller (or the `JoyDOMView` view, via an `onDiagnostic` closure in Unit l)
// can surface them in debug builds.

import Foundation

/// A single non-fatal warning produced while parsing or resolving CSS.
///
/// `kind` is a structured discriminator so tests can assert on categories
/// without string-matching. `detail` is a human-readable message suitable
/// for console logs in debug.
public struct JoyWarning: Equatable {
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
        /// Two or more `Component("x")` entries were passed with the same id.
        /// The last declaration wins; this surfaces so authors can fix the
        /// shadowed declaration.
        case duplicateLocalID(String)
        /// Two or more `SchemaEntry(id: "x")` entries share an id. The first
        /// wins for rendering; later duplicates are dropped.
        case duplicateSchemaID(String)
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
public struct JoyDiagnostics: Equatable {
    public private(set) var warnings: [JoyWarning] = []

    public init() {}

    public mutating func warn(_ w: JoyWarning) {
        warnings.append(w)
    }

    /// Convenience for tests: count warnings of a particular kind.
    public func count(of kind: JoyWarning.Kind) -> Int {
        warnings.filter { $0.kind == kind }.count
    }
}
