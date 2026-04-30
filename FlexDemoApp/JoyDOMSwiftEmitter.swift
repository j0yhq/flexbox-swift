// JoyDOMSwiftEmitter — turns a `Spec` value (decoded from JSON
// in the paste demo) back into the equivalent Swift literal. Useful
// for embedding a payload directly in test fixtures or demo code:
//
//   let spec = Spec(
//       version: 1,
//       style: [ "#root": Style(flexDirection: .column) ],
//       …
//   )
//
// Pure code generator. No formatting opinions beyond consistent
// indentation; consumers are expected to run the result through
// SwiftFormat / their tool of choice if they want stricter style.

import Foundation
import JoyDOM

enum JoyDOMSwiftEmitter {

    static func emit(_ spec: Spec) -> String {
        return emit(spec, indent: "")
    }

    // MARK: - Top-level

    private static func emit(_ spec: Spec, indent: String) -> String {
        let next = indent + "    "
        var out = "Spec(\n"
        out += "\(next)version: \(spec.version),\n"
        out += "\(next)style: \(emitSelectorMap(spec.style, indent: next)),\n"
        out += "\(next)breakpoints: \(emitArray(spec.breakpoints, indent: next, emit: emitBreakpoint)),\n"
        out += "\(next)layout: \(emitNode(spec.layout, indent: next))\n"
        out += "\(indent))"
        return out
    }

    // MARK: - Containers

    private static func emitSelectorMap(_ map: [String: Style], indent: String) -> String {
        guard !map.isEmpty else { return "[:]" }
        let next = indent + "    "
        let entries = map.sorted(by: { $0.key < $1.key }).map { key, value in
            "\(next)\(swiftString(key)): \(emitStyle(value, indent: next))"
        }
        return "[\n\(entries.joined(separator: ",\n"))\n\(indent)]"
    }

    private static func emitNodePropsMap(_ map: [String: NodeProps], indent: String) -> String {
        guard !map.isEmpty else { return "[:]" }
        let next = indent + "    "
        let entries = map.sorted(by: { $0.key < $1.key }).map { key, value in
            "\(next)\(swiftString(key)): \(emitNodeProps(value, indent: next))"
        }
        return "[\n\(entries.joined(separator: ",\n"))\n\(indent)]"
    }

    private static func emitArray<T>(
        _ items: [T],
        indent: String,
        emit: (T, String) -> String
    ) -> String {
        guard !items.isEmpty else { return "[]" }
        let next = indent + "    "
        let body = items.map { "\(next)\(emit($0, next))" }.joined(separator: ",\n")
        return "[\n\(body)\n\(indent)]"
    }

    // MARK: - Node tree

    private static func emitNode(_ node: Node, indent: String) -> String {
        let next = indent + "    "
        var lines: [String] = []
        lines.append("\(next)type: \(swiftString(node.type))")
        if let props = node.props, !isEmpty(props) {
            lines.append("\(next)props: \(emitNodeProps(props, indent: next))")
        }
        if let children = node.children, !children.isEmpty {
            lines.append("\(next)children: \(emitArray(children, indent: next, emit: emitChildNode))")
        }
        return "Node(\n\(lines.joined(separator: ",\n"))\n\(indent))"
    }

    private static func emitNodeProps(_ props: NodeProps, indent: String) -> String {
        let next = indent + "    "
        var lines: [String] = []
        if let id = props.id {
            lines.append("\(next)id: \(swiftString(id))")
        }
        if let classes = props.className, !classes.isEmpty {
            let arr = classes.map(swiftString).joined(separator: ", ")
            lines.append("\(next)className: [\(arr)]")
        }
        if let style = props.style, !isEmpty(style) {
            lines.append("\(next)style: \(emitStyle(style, indent: next))")
        }
        if lines.isEmpty {
            return "NodeProps()"
        }
        return "NodeProps(\n\(lines.joined(separator: ",\n"))\n\(indent))"
    }

    private static func emitChildNode(_ child: ChildNode, indent: String) -> String {
        switch child {
        case .primitive(let v):
            return ".primitive(\(emitPrimitive(v)))"
        case .node(let n):
            return ".node(\(emitNode(n, indent: indent)))"
        }
    }

    private static func emitPrimitive(_ v: PrimitiveValue) -> String {
        switch v {
        case .string(let s): return ".string(\(swiftString(s)))"
        case .number(let n): return ".number(\(formatNumber(n)))"
        case .null:          return ".null"
        }
    }

    // MARK: - Breakpoints / MediaQuery

    private static func emitBreakpoint(_ bp: Breakpoint, indent: String) -> String {
        let next = indent + "    "
        var lines: [String] = []
        lines.append("\(next)conditions: \(emitArray(bp.conditions, indent: next, emit: emitMediaQuery))")
        if !bp.nodes.isEmpty {
            lines.append("\(next)nodes: \(emitNodePropsMap(bp.nodes, indent: next))")
        }
        if !bp.style.isEmpty {
            lines.append("\(next)style: \(emitSelectorMap(bp.style, indent: next))")
        }
        return "Breakpoint(\n\(lines.joined(separator: ",\n"))\n\(indent))"
    }

    private static func emitMediaQuery(_ q: MediaQuery, indent: String) -> String {
        switch q {
        case .logical(let op, let conditions):
            let inner = emitArray(conditions, indent: indent, emit: emitMediaQuery)
            return ".logical(op: .\(op.rawValue), conditions: \(inner))"
        case .not(let inner):
            return ".not(\(emitMediaQuery(inner, indent: indent)))"
        case .type(let kind):
            return ".type(.\(kind.rawValue))"
        case .width(let op, let val, let unit):
            var args: [String] = []
            if let op = op   { args.append("operator: \(emitWidthOperator(op))") }
            if let val = val { args.append("value: \(formatNumber(val))") }
            if let unit = unit { args.append("unit: .\(unit.rawValue)") }
            return ".width(\(args.joined(separator: ", ")))"
        case .orientation(let o):
            return ".orientation(.\(o.rawValue))"
        }
    }

    private static func emitWidthOperator(_ op: WidthOperator) -> String {
        switch op {
        case .greaterThan:        return ".greaterThan"
        case .lessThan:           return ".lessThan"
        case .greaterThanOrEqual: return ".greaterThanOrEqual"
        case .lessThanOrEqual:    return ".lessThanOrEqual"
        }
    }

    // MARK: - Style

    private static func emitStyle(_ s: Style, indent: String) -> String {
        let next = indent + "    "
        var lines: [String] = []

        if let v = s.position       { lines.append("\(next)position: \(emitPosition(v))") }
        if let v = s.display        { lines.append("\(next)display: \(emitDisplay(v))") }
        if let v = s.zIndex         { lines.append("\(next)zIndex: \(v)") }
        if let v = s.overflow       { lines.append("\(next)overflow: \(emitOverflow(v))") }
        if let v = s.top            { lines.append("\(next)top: \(emitLength(v))") }
        if let v = s.left           { lines.append("\(next)left: \(emitLength(v))") }
        if let v = s.bottom         { lines.append("\(next)bottom: \(emitLength(v))") }
        if let v = s.right          { lines.append("\(next)right: \(emitLength(v))") }
        if let v = s.flexDirection  { lines.append("\(next)flexDirection: \(emitFlexDirection(v))") }
        if let v = s.flexGrow       { lines.append("\(next)flexGrow: \(formatNumber(v))") }
        if let v = s.flexShrink     { lines.append("\(next)flexShrink: \(formatNumber(v))") }
        if let v = s.flexBasis      { lines.append("\(next)flexBasis: \(emitLength(v))") }
        if let v = s.justifyContent { lines.append("\(next)justifyContent: \(emitJustifyContent(v))") }
        if let v = s.alignItems     { lines.append("\(next)alignItems: \(emitAlignItems(v))") }
        if let v = s.flexWrap       { lines.append("\(next)flexWrap: \(emitFlexWrap(v))") }
        if let v = s.gap            { lines.append("\(next)gap: \(emitGap(v))") }
        if let v = s.order          { lines.append("\(next)order: \(v)") }
        if let v = s.width          { lines.append("\(next)width: \(emitLength(v))") }
        if let v = s.height         { lines.append("\(next)height: \(emitLength(v))") }
        if let v = s.padding        { lines.append("\(next)padding: \(emitPadding(v))") }

        if lines.isEmpty {
            return "Style()"
        }
        return "Style(\n\(lines.joined(separator: ",\n"))\n\(indent))"
    }

    // MARK: - Style enums

    private static func emitPosition(_ v: Position) -> String { ".\(v.rawValue)" }
    private static func emitOverflow(_ v: Overflow) -> String { ".\(v.rawValue)" }

    private static func emitDisplay(_ v: Display) -> String {
        switch v {
        case .block:       return ".block"
        case .inlineBlock: return ".inlineBlock"
        case .flex:        return ".flex"
        }
    }

    private static func emitFlexDirection(_ v: Style.FlexDirection) -> String {
        switch v {
        case .row:    return ".row"
        case .column: return ".column"
        }
    }

    private static func emitJustifyContent(_ v: Style.JustifyContent) -> String {
        switch v {
        case .flexStart:    return ".flexStart"
        case .flexEnd:      return ".flexEnd"
        case .center:       return ".center"
        case .spaceBetween: return ".spaceBetween"
        case .spaceAround:  return ".spaceAround"
        }
    }

    private static func emitAlignItems(_ v: Style.AlignItems) -> String {
        switch v {
        case .flexStart: return ".flexStart"
        case .flexEnd:   return ".flexEnd"
        case .center:    return ".center"
        }
    }

    private static func emitFlexWrap(_ v: Style.FlexWrap) -> String {
        switch v {
        case .nowrap: return ".nowrap"
        case .wrap:   return ".wrap"
        }
    }

    // MARK: - Length / Gap / Padding

    private static func emitLength(_ l: Length) -> String {
        // Prefer the .px / .percent shortcuts when they apply.
        switch l.unit {
        case "px": return "Length.px(\(formatNumber(l.value)))"
        case "%":  return "Length.percent(\(formatNumber(l.value)))"
        default:   return "Length(value: \(formatNumber(l.value)), unit: \(swiftString(l.unit)))"
        }
    }

    private static func emitGap(_ g: Gap) -> String {
        switch g {
        case .uniform(let l):
            return ".uniform(\(emitLength(l)))"
        case .axes(let c, let r):
            return ".axes(column: \(emitLength(c)), row: \(emitLength(r)))"
        }
    }

    private static func emitPadding(_ p: Padding) -> String {
        switch p {
        case .uniform(let l):
            return ".uniform(\(emitLength(l)))"
        case .sides(let t, let r, let b, let lf):
            return ".sides(top: \(emitLength(t)), right: \(emitLength(r)), bottom: \(emitLength(b)), left: \(emitLength(lf)))"
        }
    }

    // MARK: - Helpers

    /// Skip empty NodeProps / Style — emitting `Style()` mid-tree is
    /// uglier than just dropping the field.
    private static func isEmpty(_ p: NodeProps) -> Bool {
        p.id == nil && (p.className?.isEmpty ?? true) && p.style == nil
    }

    private static func isEmpty(_ s: Style) -> Bool {
        s.position == nil && s.display == nil && s.zIndex == nil && s.overflow == nil &&
        s.top == nil && s.left == nil && s.bottom == nil && s.right == nil &&
        s.flexDirection == nil && s.flexGrow == nil && s.flexShrink == nil && s.flexBasis == nil &&
        s.justifyContent == nil && s.alignItems == nil && s.flexWrap == nil && s.gap == nil &&
        s.order == nil && s.width == nil && s.height == nil && s.padding == nil
    }

    /// Escape a string for safe embedding in Swift source. Handles
    /// backslashes, double quotes, and the common control chars.
    private static func swiftString(_ s: String) -> String {
        var out = "\""
        for ch in s {
            switch ch {
            case "\\": out += "\\\\"
            case "\"": out += "\\\""
            case "\n": out += "\\n"
            case "\r": out += "\\r"
            case "\t": out += "\\t"
            default:   out.append(ch)
            }
        }
        out += "\""
        return out
    }

    /// Drop trailing `.0` for integer-valued doubles so the literal
    /// reads naturally (`100` not `100.0`).
    private static func formatNumber(_ v: Double) -> String {
        if v.truncatingRemainder(dividingBy: 1) == 0 {
            return String(Int(v))
        }
        return String(v)
    }
}
