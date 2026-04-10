import FlexLayout
import SwiftUI

// MARK: - Display Mode
// Uses FlexDisplay from the library for flex/block/inline.
// inlineFlex is mapped to .flex (same behavior for our purposes).

// MARK: - Parsed CSS Result

/// Everything extracted from a pasted CSS snippet.
struct ParsedCSS {
    var container: FlexContainerConfig = FlexContainerConfig()
    var items:     [ParsedItem]        = []
    var errors:    [String]            = []
}

/// Properties parsed from a single item rule (e.g. `.item`, `.card`, `li`).
/// When a rule has both flex item properties AND `display: flex`, `childCSS`
/// carries the nested container + its children.
struct ParsedItem {
    var selector:  String       = ""
    // Flex item
    var grow:      CGFloat      = 0
    var shrink:    CGFloat      = 1
    var basis:     FlexBasis    = .auto
    var alignSelf: AlignSelf    = .auto
    var order:     Int          = 0
    var childCSS:  ParsedCSS?   = nil   // non-nil when this item is also a flex container
    // New spec properties
    var width:     FlexSize     = .auto
    var height:    FlexSize     = .auto
    var overflow:  FlexOverflow = .visible
    var zIndex:    Int          = 0
    var position:  FlexPosition = .relative
    var top:       CGFloat?     = nil
    var bottom:    CGFloat?     = nil
    var leading:   CGFloat?     = nil   // CSS `left`
    var trailing:  CGFloat?     = nil   // CSS `right`
    var display:   FlexDisplay  = .flex

    var label: String {
        if selector.isEmpty { return "item" }
        let last = selector
            .components(separatedBy: ">")
            .last?
            .trimmingCharacters(in: .whitespaces) ?? selector
        let name = last.hasPrefix(".") ? String(last.dropFirst()) : last
        return name
    }
    var isNestedContainer: Bool { childCSS != nil }
}

// MARK: - Internal build struct

private struct MutableContainer {
    var foundDisplay:    Bool           = false
    var direction:       FlexDirection  = .row
    var wrap:            FlexWrap       = .nowrap
    var justifyContent:  JustifyContent = .flexStart
    var alignItems:      AlignItems     = .stretch
    var alignContent:    AlignContent   = .stretch
    var gap:             CGFloat        = 0
    var rowGap:          CGFloat?       = nil
    var columnGap:       CGFloat?       = nil
    // New: padding sides
    var paddingTop:      CGFloat        = 0
    var paddingBottom:   CGFloat        = 0
    var paddingLeading:  CGFloat        = 0
    var paddingTrailing: CGFloat        = 0
    var overflow:        FlexOverflow   = .visible

    func toConfig() -> FlexContainerConfig {
        FlexContainerConfig(
            direction:      direction,
            wrap:           wrap,
            justifyContent: justifyContent,
            alignItems:     alignItems,
            alignContent:   alignContent,
            gap:            gap,
            rowGap:         rowGap,
            columnGap:      columnGap,
            padding:        EdgeInsets(
                top:      paddingTop,
                leading:  paddingLeading,
                bottom:   paddingBottom,
                trailing: paddingTrailing
            ),
            overflow:       overflow
        )
    }
}

// MARK: - Parser

struct CSSParser {

    // MARK: Public entry point

    /// Parse a raw CSS string. Handles:
    /// - CSS comments (`/* ... */`)
    /// - `!important` flags
    /// - `@media` / `@keyframes` / other at-rules (skipped)
    /// - Multiple `display: flex` rules (first = root container, rest = nested)
    /// - Rules that are simultaneously a flex item AND a flex container
    /// - Child rule matching via selector prefix heuristic
    /// - 3+ level deep nesting (deepest-first Pass 2)
    static func parse(_ input: String, viewportWidth: CGFloat? = nil) -> ParsedCSS {
        let css = preprocess(input)
        var result = ParsedCSS()
        var root = MutableContainer()
        var rootFound = false
        var rootSelector: String? = nil

        var nestedSelectors: [String]                    = []
        var nestedConfigs:   [String: MutableContainer]  = [:]
        var nestedItems:     [String: [ParsedItem]]      = [:]
        var nestedSelfItem:  [String: ParsedItem]        = [:]
        var repeatCounts:    [String: Int]               = [:]
        var itemDefs:        [String: ParsedItem]        = [:]
        var itemOrder:       [String]                    = []
        var itemRepeatCounts:[String: Int]               = [:]

        let blocks = extractBlocks(from: css, viewportWidth: viewportWidth)

        // ── Pass 1: classify and collect ─────────────────────────────────────
        for (selector, decls) in blocks {
            let props         = parseDeclarations(decls)
            let displayVal    = props["display"]?.trimmingCharacters(in: .whitespaces).lowercased() ?? ""
            let isDisplayFlex = displayVal == "flex" || displayVal == "inline-flex"
            let isDisplayBlock  = displayVal == "block"
            let isDisplayInline = displayVal == "inline"
            let hasContainer  = isFlexContainerBlock(props)
            let hasItem       = hasItemProps(props)
            let isContainerRule = isDisplayFlex || hasContainer
            let repeatCount = Int(props["--repeat"]?.trimmingCharacters(in: .whitespaces) ?? "") ?? 1

            if isContainerRule && !rootFound {
                rootFound = true
                rootSelector = selector
                root.foundDisplay = isDisplayFlex
                applyContainerProps(props, to: &root, errors: &result.errors)

            } else if isContainerRule {
                // Later rules for the root selector (e.g. @media overrides) should
                // merge into root, not become a nested node.
                if selector == rootSelector {
                    root.foundDisplay = root.foundDisplay || isDisplayFlex
                    applyContainerProps(props, to: &root, errors: &result.errors)
                    continue
                }

                // Nested flex container (merge duplicate selector rules by cascade).
                var nc = nestedConfigs[selector] ?? MutableContainer()
                applyContainerProps(props, to: &nc, errors: &result.errors)
                if !nestedSelectors.contains(selector) {
                    nestedSelectors.append(selector)
                }
                nestedConfigs[selector] = nc
                if nestedItems[selector] == nil {
                    nestedItems[selector] = []
                }

                var selfItem = nestedSelfItem[selector] ?? ParsedItem(selector: selector)
                if hasItem {
                    applyItemProps(props, to: &selfItem, errors: &result.errors)
                }
                nestedSelfItem[selector] = selfItem

                // --repeat: N  →  create N copies of this container in Pass 2
                if repeatCount > 1 {
                    repeatCounts[selector] = repeatCount
                }

            // `display:block` / `display:inline` rules still enter this branch so
            // elements are registered as flex items even without other item props.
            // In a flex formatting context, those display values are blockified.
            } else if isDisplayBlock || isDisplayInline || hasItem || props["--repeat"] != nil {
                // Item-like rule:
                // 1) if it targets a known nested container selector, merge into that
                //    container's self item (common in @media blocks)
                // 2) otherwise merge into a normal item definition map by selector
                if selector != rootSelector, nestedConfigs[selector] != nil {
                    var selfItem = nestedSelfItem[selector] ?? ParsedItem(selector: selector)
                    // In a flex formatting context, flex items are blockified for
                    // outer layout participation. Keep flex-item behavior unchanged.
                    if hasItem { applyItemProps(props, to: &selfItem, errors: &result.errors) }
                    nestedSelfItem[selector] = selfItem
                    if repeatCount > 1 { repeatCounts[selector] = repeatCount }
                } else {
                    var item = itemDefs[selector] ?? ParsedItem(selector: selector)
                    // In a flex formatting context, flex items are blockified for
                    // outer layout participation. Keep flex-item behavior unchanged.
                    if hasItem { applyItemProps(props, to: &item, errors: &result.errors) }
                    itemDefs[selector] = item
                    if !itemOrder.contains(selector) {
                        itemOrder.append(selector)
                    }
                    if repeatCount > 1 {
                        itemRepeatCounts[selector] = repeatCount
                    }
                }
            }
        }

        // Materialise non-container item rules after cascade merging, so repeated
        // selectors (including @media overrides) update existing items instead of
        // duplicating them.
        for selector in itemOrder {
            guard let mergedItem = itemDefs[selector] else { continue }
            let count = max(1, itemRepeatCounts[selector] ?? 1)
            let parentSel = findParentSelector(for: selector, among: nestedSelectors)

            for i in 0..<count {
                var item = mergedItem
                if count > 1 {
                    item.selector = shortLabel(selector, index: i + 1)
                }
                if let p = parentSel {
                    nestedItems[p, default: []].append(item)
                } else {
                    result.items.append(item)
                }
            }
        }

        // ── Pass 2: assemble nested containers deepest-first ───────────────────
        // For shortened selectors (e.g. ".chart-panel > .area" nested inside
        // ".dashboard > .panels > .chart-panel"), the raw ">" count gives the
        // wrong depth. We resolve actual DOM depth by walking up the parent chain.
        func rawDepth(_ sel: String) -> Int {
            sel.components(separatedBy: ">").count
        }
        var depthCache: [String: Int] = [:]
        func actualDepth(_ sel: String) -> Int {
            if let cached = depthCache[sel] { return cached }
            if let parent = findParentSelector(for: sel, among: nestedSelectors) {
                let d = actualDepth(parent) + 1
                depthCache[sel] = d
                return d
            }
            let d = rawDepth(sel)
            depthCache[sel] = d
            return d
        }
        let sortedByDepth = nestedSelectors
            .enumerated()
            .sorted { a, b in
                let da = actualDepth(a.element)
                let db = actualDepth(b.element)
                if da != db { return da > db }
                return a.offset < b.offset  // preserve source order at same depth
            }
            .map { $0.element }

        for sel in sortedByDepth {
            guard let nc = nestedConfigs[sel] else { continue }
            var childParsed = ParsedCSS()
            childParsed.container = nc.toConfig()
            childParsed.items     = nestedItems[sel] ?? []

            var item      = nestedSelfItem[sel] ?? ParsedItem(selector: sel)
            item.selector = sel
            item.childCSS = childParsed

            let otherNested = nestedSelectors.filter { $0 != sel }
            let count = repeatCounts[sel] ?? 1

            for i in 0..<max(count, 1) {
                var copy = item
                if count > 1 { copy.selector = shortLabel(sel, index: i + 1) }
                if let parentSel = findParentSelector(for: sel, among: otherNested) {
                    nestedItems[parentSel, default: []].append(copy)
                } else {
                    result.items.append(copy)
                }
            }
        }

        // ── Finalise root container ────────────────────────────────────────────
        result.container = root.toConfig()

        // Fallback: no rule blocks found — try treating the whole input as declarations
        if !rootFound && blocks.isEmpty {
            let props = parseDeclarations(css)
            if isFlexContainerBlock(props) || props["display"] != nil {
                applyContainerProps(props, to: &root, errors: &result.errors)
                result.container = root.toConfig()
            }
        }

        return result
    }

    // MARK: - Short label for repeated items

    /// Extracts a readable label from a full selector for repeated copies.
    /// e.g. ".dashboard > .metrics > .metric-card" → "metric-card 1"
    private static func shortLabel(_ selector: String, index: Int) -> String {
        let last = selector
            .components(separatedBy: ">")
            .last?
            .trimmingCharacters(in: .whitespaces) ?? selector
        let name = last.hasPrefix(".") ? String(last.dropFirst()) : last
        return "\(name) \(index)"
    }

    // MARK: - Phase 0: Pre-process

    private static func preprocess(_ css: String) -> String {
        var s = css

        // 1. Strip /* ... */ comments
        while let open = s.range(of: "/*") {
            if let close = s.range(of: "*/", range: open.upperBound..<s.endIndex) {
                s.removeSubrange(open.lowerBound..<close.upperBound)
            } else {
                s.removeSubrange(open.lowerBound..<s.endIndex)
                break
            }
        }

        // 2. Strip !important
        s = s.replacingOccurrences(of: "!important", with: "", options: .caseInsensitive)

        return s
    }

    // MARK: - Phase 1: Block extraction

    private static func extractBlocks(from css: String, viewportWidth: CGFloat? = nil) -> [(String, String)] {
        var results: [(String, String)] = []
        var i = css.startIndex

        while i < css.endIndex {
            guard let open  = css[i...].firstIndex(of: "{") else { break }
            guard let close = matchingBrace(in: css, openingBraceAt: open) else { break }

            let rawSelector = css[i..<open]
                .trimmingCharacters(in: .whitespacesAndNewlines)

            let selector = rawSelector
                .components(separatedBy: .newlines).last?
                .trimmingCharacters(in: .whitespacesAndNewlines) ?? rawSelector

            let body = String(css[css.index(after: open)..<close])

            if selector.lowercased().hasPrefix("@media") {
                if mediaQueryMatches(selector, viewportWidth: viewportWidth) {
                    results.append(contentsOf: extractBlocks(from: body, viewportWidth: viewportWidth))
                }
            } else if !selector.hasPrefix("@") && !selector.isEmpty {
                results.append((selector, body))
            }

            i = css.index(after: close)
        }
        return results
    }

    private static func matchingBrace(in css: String, openingBraceAt open: String.Index) -> String.Index? {
        var depth = 0
        var i = open

        while i < css.endIndex {
            let ch = css[i]
            if ch == "{" {
                depth += 1
            } else if ch == "}" {
                depth -= 1
                if depth == 0 { return i }
            }
            i = css.index(after: i)
        }

        return nil
    }

    private static func mediaQueryMatches(_ selector: String, viewportWidth: CGFloat?) -> Bool {
        guard let viewportWidth else { return false }

        let q = selector.lowercased()
        guard q.hasPrefix("@media") else { return false }

        var sawWidthCondition = false
        var idx = q.startIndex

        while let open = q[idx...].firstIndex(of: "(") {
            guard let close = q[open...].firstIndex(of: ")") else { break }
            let cond = q[q.index(after: open)..<close]
                .trimmingCharacters(in: .whitespacesAndNewlines)

            if cond.contains("max-width") {
                sawWidthCondition = true
                let raw = cond.components(separatedBy: ":").dropFirst().joined(separator: ":")
                    .trimmingCharacters(in: .whitespacesAndNewlines)
                if let n = parsePx(raw), viewportWidth > n + 0.001 {
                    return false
                }
            } else if cond.contains("min-width") {
                sawWidthCondition = true
                let raw = cond.components(separatedBy: ":").dropFirst().joined(separator: ":")
                    .trimmingCharacters(in: .whitespacesAndNewlines)
                if let n = parsePx(raw), viewportWidth < n - 0.001 {
                    return false
                }
            }

            idx = q.index(after: close)
        }

        return sawWidthCondition
    }

    // MARK: - Phase 2: Declaration parsing

    private static func parseDeclarations(_ body: String) -> [String: String] {
        var result: [String: String] = [:]
        for line in body.components(separatedBy: ";") {
            let parts = line.components(separatedBy: ":").map {
                $0.trimmingCharacters(in: .whitespacesAndNewlines)
            }
            guard parts.count >= 2 else { continue }
            let key   = parts[0].lowercased()
            let value = parts[1...].joined(separator: ":")
                .trimmingCharacters(in: .whitespacesAndNewlines)
            if !key.isEmpty && !value.isEmpty { result[key] = value }
        }
        return result
    }

    // MARK: - Classification helpers

    private static func isFlexContainerBlock(_ props: [String: String]) -> Bool {
        let keys: Set<String> = [
            "flex-direction","flex-wrap","justify-content",
            "align-items","align-content","gap","row-gap","column-gap",
            "padding","padding-top","padding-bottom","padding-left","padding-right"
        ]
        return props.keys.contains(where: keys.contains)
    }

    private static func hasItemProps(_ props: [String: String]) -> Bool {
        let keys: Set<String> = [
            "flex-grow","flex-shrink","flex-basis","align-self","order","flex",
            "width","height","overflow","z-index","position","top","bottom","left","right"
        ]
        return props.keys.contains(where: keys.contains)
    }

    // MARK: - Parent selector heuristic

    private static func findParentSelector(
        for childSelector: String,
        among candidates: [String]
    ) -> String? {
        let sorted = candidates.sorted { $0.count > $1.count }

        // 1. Exact prefix match — works for full-path selectors
        //    e.g. ".dashboard > .panels > .chart-panel > .area" → parent ".dashboard > .panels > .chart-panel"
        for candidate in sorted {
            guard childSelector != candidate else { continue }
            guard childSelector.hasPrefix(candidate) else { continue }
            let after = childSelector.dropFirst(candidate.count)
            let boundary: Set<Character> = [" ", ">", "~", "+", "[", ":", ".", "#"]
            if let first = after.first, boundary.contains(first) {
                return candidate
            }
        }

        // 2. Leaf-segment match — works for shortened selectors
        //    e.g. ".chart-panel > .area" first segment ".chart-panel"
        //    matches candidate ".dashboard > .panels > .chart-panel" whose last segment is ".chart-panel"
        let childFirstSeg = childSelector
            .components(separatedBy: ">")
            .first?
            .trimmingCharacters(in: .whitespaces) ?? ""
        guard !childFirstSeg.isEmpty else { return nil }

        for candidate in sorted {
            guard candidate != childSelector else { continue }
            let candLastSeg = candidate
                .components(separatedBy: ">")
                .last?
                .trimmingCharacters(in: .whitespaces) ?? ""
            if candLastSeg == childFirstSeg {
                return candidate
            }
        }

        return nil
    }

    // MARK: - Container property application

    private static func applyContainerProps(
        _ props: [String: String],
        to c: inout MutableContainer,
        errors: inout [String]
    ) {
        for (key, value) in props {
            switch key {
            case "flex-direction":
                if let v = parseFlexDirection(value) { c.direction = v }
                else { errors.append("Unknown flex-direction: \(value)") }

            case "flex-wrap":
                if let v = parseFlexWrap(value) { c.wrap = v }
                else { errors.append("Unknown flex-wrap: \(value)") }

            case "justify-content":
                if let v = parseJustifyContent(value) { c.justifyContent = v }
                else { errors.append("Unknown justify-content: \(value)") }

            case "align-items":
                if let v = parseAlignItems(value) { c.alignItems = v }
                else { errors.append("Unknown align-items: \(value)") }

            case "align-content":
                if let v = parseAlignContent(value) { c.alignContent = v }
                else { errors.append("Unknown align-content: \(value)") }

            case "gap":
                let parts = value.components(separatedBy: .whitespaces).filter { !$0.isEmpty }
                if parts.count == 2 {
                    c.rowGap    = parsePx(parts[0])
                    c.columnGap = parsePx(parts[1])
                } else if let n = parsePx(value) {
                    c.gap = n
                }

            case "row-gap":
                c.rowGap = parsePx(value)

            case "column-gap":
                c.columnGap = parsePx(value)

            // ── New: padding ──────────────────────────────────────────────────
            case "padding":
                // CSS shorthand: 1 value = all, 2 = TB/LR, 4 = T R B L
                let parts = value.components(separatedBy: .whitespaces).filter { !$0.isEmpty }
                switch parts.count {
                case 1:
                    let n = parsePx(parts[0]) ?? 0
                    c.paddingTop = n; c.paddingBottom = n
                    c.paddingLeading = n; c.paddingTrailing = n
                case 2:
                    let tb = parsePx(parts[0]) ?? 0
                    let lr = parsePx(parts[1]) ?? 0
                    c.paddingTop = tb; c.paddingBottom = tb
                    c.paddingLeading = lr; c.paddingTrailing = lr
                case 3:
                    // CSS 3-value: top, left-right, bottom
                    c.paddingTop      = parsePx(parts[0]) ?? 0
                    c.paddingLeading  = parsePx(parts[1]) ?? 0
                    c.paddingTrailing = parsePx(parts[1]) ?? 0
                    c.paddingBottom   = parsePx(parts[2]) ?? 0
                case 4:
                    c.paddingTop      = parsePx(parts[0]) ?? 0
                    c.paddingTrailing = parsePx(parts[1]) ?? 0
                    c.paddingBottom   = parsePx(parts[2]) ?? 0
                    c.paddingLeading  = parsePx(parts[3]) ?? 0
                default: break
                }

            case "padding-top":    c.paddingTop      = parsePx(value) ?? 0
            case "padding-bottom": c.paddingBottom   = parsePx(value) ?? 0
            case "padding-left":   c.paddingLeading  = parsePx(value) ?? 0
            case "padding-right":  c.paddingTrailing = parsePx(value) ?? 0

            case "overflow":
                if let o = parseOverflow(value) { c.overflow = o }

            default: break
            }
        }
    }

    // MARK: - Item property application

    private static func applyItemProps(
        _ props: [String: String],
        to item: inout ParsedItem,
        errors: inout [String]
    ) {
        for (key, value) in props {
            switch key {
            case "flex-grow":
                if let n = Double(value.trimmingCharacters(in: .whitespaces)) {
                    item.grow = CGFloat(n)
                }

            case "flex-shrink":
                if let n = Double(value.trimmingCharacters(in: .whitespaces)) {
                    item.shrink = CGFloat(n)
                }

            case "flex-basis":
                item.basis = parseFlexBasis(value)

            case "align-self":
                if let v = parseAlignSelf(value) { item.alignSelf = v }
                else { errors.append("Unknown align-self: \(value)") }

            case "order":
                if let n = Int(value.trimmingCharacters(in: .whitespaces)) {
                    item.order = n
                }

            case "flex":
                // Shorthand: flex: <grow> [<shrink> [<basis>]]
                let trimmed = value.trimmingCharacters(in: .whitespaces).lowercased()
                switch trimmed {
                case "auto":    item.grow = 1; item.shrink = 1; item.basis = .auto
                case "none":    item.grow = 0; item.shrink = 0; item.basis = .auto
                case "initial": item.grow = 0; item.shrink = 1; item.basis = .auto
                default:
                    let parts = trimmed.components(separatedBy: .whitespaces).filter { !$0.isEmpty }
                    if parts.count == 1 {
                        if let n = Double(parts[0]) {
                            item.grow = CGFloat(n); item.shrink = 1; item.basis = .points(0)
                        } else {
                            item.basis = parseFlexBasis(parts[0])
                        }
                    } else if parts.count == 2 {
                        if let g = Double(parts[0]), let s = Double(parts[1]) {
                            item.grow = CGFloat(g); item.shrink = CGFloat(s)
                        }
                    } else if parts.count >= 3 {
                        if let g = Double(parts[0]), let s = Double(parts[1]) {
                            item.grow   = CGFloat(g)
                            item.shrink = CGFloat(s)
                            item.basis  = parseFlexBasis(parts[2])
                        }
                    }
                }

            // ── New spec properties ───────────────────────────────────────────
            case "width":
                item.width = parseFlexSize(value)

            case "height":
                item.height = parseFlexSize(value)

            case "overflow":
                item.overflow = parseOverflow(value) ?? .visible

            case "z-index":
                if let n = Int(value.trimmingCharacters(in: .whitespaces)) {
                    item.zIndex = n
                }

            case "position":
                item.position = parsePosition(value) ?? .relative

            case "top":
                item.top = parsePx(value)

            case "bottom":
                item.bottom = parsePx(value)

            case "left":
                item.leading = parsePx(value)

            case "right":
                item.trailing = parsePx(value)

            default: break
            }
        }
    }

    // MARK: - Value parsers

    private static func parseFlexDirection(_ v: String) -> FlexDirection? {
        switch v.trimmingCharacters(in: .whitespaces).lowercased() {
        case "row":            return .row
        case "row-reverse":    return .rowReverse
        case "column":         return .column
        case "column-reverse": return .columnReverse
        default:               return nil
        }
    }

    private static func parseFlexWrap(_ v: String) -> FlexWrap? {
        switch v.trimmingCharacters(in: .whitespaces).lowercased() {
        case "nowrap":       return .nowrap
        case "wrap":         return .wrap
        case "wrap-reverse": return .wrapReverse
        default:             return nil
        }
    }

    private static func parseJustifyContent(_ v: String) -> JustifyContent? {
        switch v.trimmingCharacters(in: .whitespaces).lowercased() {
        case "flex-start", "start", "left":  return .flexStart
        case "flex-end",   "end",   "right": return .flexEnd
        case "center":                        return .center
        case "space-between":                 return .spaceBetween
        case "space-around":                  return .spaceAround
        case "space-evenly":                  return .spaceEvenly
        default:                              return nil
        }
    }

    private static func parseAlignItems(_ v: String) -> AlignItems? {
        switch v.trimmingCharacters(in: .whitespaces).lowercased() {
        case "flex-start", "start": return .flexStart
        case "flex-end",   "end":   return .flexEnd
        case "center":              return .center
        case "stretch":             return .stretch
        case "baseline":            return .baseline
        default:                    return nil
        }
    }

    private static func parseAlignContent(_ v: String) -> AlignContent? {
        switch v.trimmingCharacters(in: .whitespaces).lowercased() {
        case "flex-start", "start": return .flexStart
        case "flex-end",   "end":   return .flexEnd
        case "center":              return .center
        case "space-between":       return .spaceBetween
        case "space-around":        return .spaceAround
        case "space-evenly":        return .spaceEvenly
        case "stretch":             return .stretch
        default:                    return nil
        }
    }

    private static func parseAlignSelf(_ v: String) -> AlignSelf? {
        switch v.trimmingCharacters(in: .whitespaces).lowercased() {
        case "auto":                return .auto
        case "flex-start", "start": return .flexStart
        case "flex-end",   "end":   return .flexEnd
        case "center":              return .center
        case "stretch":             return .stretch
        case "baseline":            return .baseline
        default:                    return nil
        }
    }

    static func parseFlexBasis(_ v: String) -> FlexBasis {
        let s = v.trimmingCharacters(in: .whitespaces).lowercased()
        if s == "auto" { return .auto }
        if s.hasSuffix("%"), let n = Double(s.dropLast()) {
            return .fraction(CGFloat(n) / 100)
        }
        if let n = parsePx(s) { return .points(n) }
        return .auto
    }

    // ── New parsers ──────────────────────────────────────────────────────────

    /// Parse a CSS size value to `FlexSize` (used for `width`/`height`).
    static func parseFlexSize(_ v: String) -> FlexSize {
        let s = v.trimmingCharacters(in: .whitespaces).lowercased()
        if s == "auto"        { return .auto }
        if s == "min-content" { return .minContent }
        if s.hasSuffix("%"), let n = Double(s.dropLast()) {
            return .fraction(CGFloat(n) / 100)
        }
        if let n = parsePx(s) { return .points(n) }
        return .auto
    }

    private static func parseOverflow(_ v: String) -> FlexOverflow? {
        switch v.trimmingCharacters(in: .whitespaces).lowercased() {
        case "visible": return .visible
        case "hidden":  return .hidden
        case "clip":    return .clip
        case "scroll":  return .scroll
        case "auto":    return .auto
        default:        return nil
        }
    }

    private static func parsePosition(_ v: String) -> FlexPosition? {
        switch v.trimmingCharacters(in: .whitespaces).lowercased() {
        case "relative": return .relative
        case "absolute": return .absolute
        default:         return nil
        }
    }

    /// Parse a CSS length value → points.
    static func parsePx(_ v: String) -> CGFloat? {
        let s = v.trimmingCharacters(in: .whitespaces).lowercased()
        if s.hasSuffix("rem"), let n = Double(s.dropLast(3)) { return CGFloat(n * 16) }
        if s.hasSuffix("px"),  let n = Double(s.dropLast(2)) { return CGFloat(n) }
        if s.hasSuffix("pt"),  let n = Double(s.dropLast(2)) { return CGFloat(n) }
        if s.hasSuffix("em"),  let n = Double(s.dropLast(2)) { return CGFloat(n * 16) }
        if let n = Double(s) { return CGFloat(n) }
        return nil
    }
}
