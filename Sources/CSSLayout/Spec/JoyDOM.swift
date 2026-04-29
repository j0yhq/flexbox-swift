// JoyDOM — Swift mirror of `joy-dom` (joyfill/.joy spec, PR #33).
//
// This file defines the data types that match `DOM/spec.ts` from the
// joyfill `.joy` repository, so an iOS host can decode a server-sent
// `joy-dom` document and feed it into CSSLayout's render pipeline.
//
// The shapes below are pure data — no behavior, no rendering. Subsequent
// units add:
//   • Unit 2 — `Style` → CSS string serializer
//   • Unit 3 — tree → flat `[SchemaEntry]` converter
//   • Unit 5 — `MediaQuery` evaluator against a `Viewport`
//   • Unit 7 — Breakpoint cascade resolver
//   • Unit 8 — applying an active breakpoint to the render pipeline
//
// Every type round-trips through JSON via Codable, with field names that
// match Josh's TS spec verbatim (camelCase, e.g. `flexDirection`).
//
// Scope notes for Unit 1:
//   • `NodeProps` covers the named fields (`id`, `className`, `style`).
//     The `[key: string]: unknown` escape hatch from the TS spec is not
//     yet mirrored — it lands in Unit 10 alongside `UiAction` descriptors.
//   • `Length<'px' | '%'>` from TS collapses to a single `Length` struct
//     with a `String` unit field; unit validity is a serializer concern
//     (Unit 2), not a type-system concern.

import Foundation

// MARK: - Document root (`Spec`)

/// The top-level joy-dom document. Mirrors `Spec` in `DOM/spec.ts`.
public struct JoyDOMSpec: Equatable {
    /// Schema version. Always `1` in the current spec.
    public var version: Int
    /// Document-level style rules, keyed by selector (`#id`, `.class`, `type`).
    public var style: [String: Style]
    /// Responsive breakpoints in source order. Cascade resolution picks the
    /// active breakpoint by specificity then source order at render time.
    public var breakpoints: [Breakpoint]
    /// The root node of the document.
    public var layout: Node

    public init(
        version: Int = 1,
        style: [String: Style] = [:],
        breakpoints: [Breakpoint] = [],
        layout: Node
    ) {
        self.version = version
        self.style = style
        self.breakpoints = breakpoints
        self.layout = layout
    }
}

// MARK: - Node tree

/// A renderable element. Mirrors `Node` in `DOM/spec.ts`.
public struct Node: Equatable {
    /// Element type — `"div"`, `"p"`, or a custom string for registry
    /// components (`"button"`, `"text-field"`, etc.).
    public var type: String
    /// Optional element-level props (id, className, inline style).
    public var props: NodeProps?
    /// Optional children. A child may be another `Node` or a primitive
    /// value (string / number / null) representing text content.
    public var children: [ChildNode]?

    public init(
        type: String,
        props: NodeProps? = nil,
        children: [ChildNode]? = nil
    ) {
        self.type = type
        self.props = props
        self.children = children
    }
}

/// Element-level props. Mirrors `NodeProps` in `DOM/spec.ts`.
///
/// Unit 1 covers the named fields only; the TS `[key: string]: unknown`
/// escape hatch lands in Unit 10.
public struct NodeProps: Equatable {
    /// Element id — used as both the graph identity and the CSS `#id`
    /// selector target. Nodes without an `id` cannot be addressed in
    /// `Breakpoint.nodes` overrides.
    public var id: String?
    /// CSS class names — matched by `.class` selectors.
    public var className: [String]?
    /// Inline style applied directly to this node. Wins over selector-based
    /// rules per the cascade order documented in `DOM/guides/Styles.md`.
    public var style: Style?

    public init(
        id: String? = nil,
        className: [String]? = nil,
        style: Style? = nil
    ) {
        self.id = id
        self.className = className
        self.style = style
    }
}

/// A child of a `Node`. Either a nested element or a primitive value.
public enum ChildNode: Equatable {
    case node(Node)
    case primitive(PrimitiveValue)
}

/// Primitive value used as text content. Mirrors `PrimitiveValue` in
/// `DOM/spec.ts`.
public enum PrimitiveValue: Equatable {
    case string(String)
    case number(Double)
    case null
}

// MARK: - Style

/// JSON-safe length (`{ value, unit }`). Mirrors `Length` in `DOM/spec.ts`.
///
/// Josh's TS spec uses `Length<'px'>` and `Length<'px' | '%'>` — Swift's
/// type system can't express string-literal unit constraints cleanly, so
/// we collapse both into one struct and validate the unit in the
/// serializer (Unit 2) where the context is known.
public struct Length: Equatable {
    public var value: Double
    public var unit: String

    public init(value: Double, unit: String) {
        self.value = value
        self.unit = unit
    }

    /// Convenience for the common `{ value: N, unit: "px" }` case.
    public static func px(_ value: Double) -> Length {
        Length(value: value, unit: "px")
    }

    /// Convenience for the common `{ value: N, unit: "%" }` case.
    public static func percent(_ value: Double) -> Length {
        Length(value: value, unit: "%")
    }
}

/// Subset of CSS that joy-dom supports. Mirrors `Style` in `DOM/spec.ts`.
///
/// Every field is optional — `Style()` represents "no overrides". The
/// cascade in Unit 8 deep-merges Style values, so partial overrides keep
/// sibling fields intact.
public struct Style: Equatable {
    public var position: Position?
    public var display: Display?
    public var zIndex: Int?
    public var overflow: Overflow?

    public var top: Length?
    public var left: Length?
    public var bottom: Length?
    public var right: Length?

    public var flexDirection: Style.FlexDirection?
    public var flexGrow: Double?
    public var flexShrink: Double?
    public var flexBasis: Length?
    public var justifyContent: Style.JustifyContent?
    public var alignItems: Style.AlignItems?
    public var flexWrap: Style.FlexWrap?
    public var gap: Gap?
    public var order: Int?

    public var width: Length?
    public var height: Length?
    public var padding: Padding?

    public init(
        position: Position? = nil,
        display: Display? = nil,
        zIndex: Int? = nil,
        overflow: Overflow? = nil,
        top: Length? = nil,
        left: Length? = nil,
        bottom: Length? = nil,
        right: Length? = nil,
        flexDirection: Style.FlexDirection? = nil,
        flexGrow: Double? = nil,
        flexShrink: Double? = nil,
        flexBasis: Length? = nil,
        justifyContent: Style.JustifyContent? = nil,
        alignItems: Style.AlignItems? = nil,
        flexWrap: Style.FlexWrap? = nil,
        gap: Gap? = nil,
        order: Int? = nil,
        width: Length? = nil,
        height: Length? = nil,
        padding: Padding? = nil
    ) {
        self.position = position
        self.display = display
        self.zIndex = zIndex
        self.overflow = overflow
        self.top = top
        self.left = left
        self.bottom = bottom
        self.right = right
        self.flexDirection = flexDirection
        self.flexGrow = flexGrow
        self.flexShrink = flexShrink
        self.flexBasis = flexBasis
        self.justifyContent = justifyContent
        self.alignItems = alignItems
        self.flexWrap = flexWrap
        self.gap = gap
        self.order = order
        self.width = width
        self.height = height
        self.padding = padding
    }
}

// MARK: - Style enums (string-keyed, raw values match the TS literal types)

public enum Position: String, Equatable {
    case absolute
    case relative
}

public enum Display: String, Equatable {
    case block
    case inlineBlock = "inline-block"
    case flex
}

public enum Overflow: String, Equatable {
    case visible
    case hidden
    case clip
    case scroll
    case auto
}

// `FlexDirection` / `JustifyContent` / `AlignItems` / `FlexWrap` are nested
// inside `Style` because the surrounding `FlexLayout` package exports
// types with the same top-level names. Nesting keeps the API honest
// (`Style.FlexDirection.row`) while avoiding ambiguity at every call site
// in the resolver and serializer.
extension Style {
    public enum FlexDirection: String, Equatable {
        case row
        case column
    }

    public enum JustifyContent: String, Equatable {
        case flexStart    = "flex-start"
        case flexEnd      = "flex-end"
        case center
        case spaceBetween = "space-between"
        case spaceAround  = "space-around"
    }

    public enum AlignItems: String, Equatable {
        case flexStart = "flex-start"
        case flexEnd   = "flex-end"
        case center
    }

    public enum FlexWrap: String, Equatable {
        case nowrap
        case wrap
    }
}

/// `gap` is either a uniform length (single value applied to row + column)
/// or a per-axis pair `{ c, r }`.
public enum Gap: Equatable {
    case uniform(Length)
    case axes(column: Length, row: Length)
}

/// `padding` is either a uniform length or a per-side `{ top, right, bottom, left }`.
public enum Padding: Equatable {
    case uniform(Length)
    case sides(top: Length, right: Length, bottom: Length, left: Length)
}

// MARK: - Breakpoints

/// A responsive breakpoint. Mirrors `Breakpoint` in `DOM/spec.ts`.
///
/// At render time, `BreakpointResolver` (Unit 7) picks the highest-
/// specificity matching breakpoint for the current viewport. Per Josh's
/// `Breakpoints.md`: "Only one breakpoint can be applied at a time."
public struct Breakpoint: Equatable {
    /// Conditions ANDed together — all must match for the breakpoint to
    /// activate.
    public var conditions: [MediaQuery]
    /// Per-node overrides keyed by `props.id`. Restyle / re-prop only —
    /// structural fields (`type`, `children`) are deliberately not in
    /// `NodeProps`, so re-parenting is impossible. This is the deliberate
    /// "no tree mutation" guarantee the spec inherits from web `@media`.
    public var nodes: [String: NodeProps]
    /// Selector-keyed style overrides applied while this breakpoint is
    /// active. Cascade between this and `nodes[id].style` is documented
    /// in the cascade order: `Document.style → Breakpoint.style →
    /// node.props.style → Breakpoint.nodes[id].style`.
    public var style: [String: Style]

    public init(
        conditions: [MediaQuery] = [],
        nodes: [String: NodeProps] = [:],
        style: [String: Style] = [:]
    ) {
        self.conditions = conditions
        self.nodes = nodes
        self.style = style
    }
}

/// A media-query condition. Mirrors the discriminated union of
/// `MediaQueryLogical | MediaQueryNot | MediaWidthFeature |
/// MediaOrientationFeature | MediaType` in `DOM/spec.ts`.
public indirect enum MediaQuery: Equatable {
    case logical(op: LogicalOp, conditions: [MediaQuery])
    case not(MediaQuery)
    case type(MediaTypeKind)
    case width(operator: WidthOperator? = nil, value: Double? = nil, unit: WidthUnit? = nil)
    case orientation(Orientation)
}

public enum LogicalOp: String, Equatable {
    case and
    case or
}

public enum MediaTypeKind: String, Equatable {
    case print
}

public enum WidthOperator: String, Equatable {
    case greaterThan       = ">"
    case lessThan          = "<"
    case greaterThanOrEqual = ">="
    case lessThanOrEqual    = "<="
}

public enum WidthUnit: String, Equatable {
    case px
}

public enum Orientation: String, Equatable {
    case landscape
    case portrait
}

// MARK: - Codable

// Swift can synthesize `Codable` for types whose fields are all themselves
// `Codable`. For pure structs (`JoyDOMSpec`, `Node`, `NodeProps`, `Style`,
// `Length`, `Breakpoint`) and `String`-raw enums (`Position`, `Display`,
// `Overflow`, `FlexDirection`, `JustifyContent`, `AlignItems`, `FlexWrap`,
// `LogicalOp`, `MediaTypeKind`, `WidthOperator`, `WidthUnit`,
// `Orientation`) the synthesized implementation matches Josh's JSON shape
// exactly.
//
// The union-shape enums (`PrimitiveValue`, `ChildNode`, `Gap`, `Padding`,
// `MediaQuery`) need custom Codable because Swift's default synthesis
// emits `{"uniform": …}` / `{"node": …}` discriminators that don't match
// the spec. Unit 1's RED stubs below produce empty / null output so
// round-trip tests fail observably; Unit 1's GREEN replaces them with
// implementations matching `DOM/spec.ts`.

extension JoyDOMSpec: Codable {}
extension Node: Codable {}
extension NodeProps: Codable {}
extension Style: Codable {}
extension Length: Codable {}
extension Breakpoint: Codable {}

extension Position: Codable {}
extension Display: Codable {}
extension Overflow: Codable {}
extension Style.FlexDirection: Codable {}
extension Style.JustifyContent: Codable {}
extension Style.AlignItems: Codable {}
extension Style.FlexWrap: Codable {}
extension LogicalOp: Codable {}
extension MediaTypeKind: Codable {}
extension WidthOperator: Codable {}
extension WidthUnit: Codable {}
extension Orientation: Codable {}

// MARK: - Custom Codable RED stubs (replaced in Unit 1 GREEN)

extension PrimitiveValue: Codable {
    public init(from decoder: Decoder) throws {
        self = .null
    }
    public func encode(to encoder: Encoder) throws {
        var c = encoder.singleValueContainer()
        try c.encodeNil()
    }
}

extension ChildNode: Codable {
    public init(from decoder: Decoder) throws {
        self = .primitive(.null)
    }
    public func encode(to encoder: Encoder) throws {
        var c = encoder.singleValueContainer()
        try c.encodeNil()
    }
}

extension Gap: Codable {
    public init(from decoder: Decoder) throws {
        self = .uniform(Length(value: 0, unit: ""))
    }
    public func encode(to encoder: Encoder) throws {
        var c = encoder.singleValueContainer()
        try c.encodeNil()
    }
}

extension Padding: Codable {
    public init(from decoder: Decoder) throws {
        self = .uniform(Length(value: 0, unit: ""))
    }
    public func encode(to encoder: Encoder) throws {
        var c = encoder.singleValueContainer()
        try c.encodeNil()
    }
}

extension MediaQuery: Codable {
    public init(from decoder: Decoder) throws {
        self = .type(.print)
    }
    public func encode(to encoder: Encoder) throws {
        var c = encoder.singleValueContainer()
        try c.encodeNil()
    }
}
