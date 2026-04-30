// StyleTreeBuilder — walks a joy-dom `Node` tree and produces the flat
// `[StyleNode]` array `ComponentResolver` consumes.
//
// Tier 5 rewrite: this used to consume `[SchemaEntry]` (the flat schema
// from `SchemaFlattener`) plus a parsed `Stylesheet`. After the joy-dom-
// native refactor it walks the `Node` tree directly and resolves against
// a pre-built `[StyleResolver.Rule]` list, dropping the flat-array
// intermediate entirely.
//
// Tree shape produced:
//   [root]                ← id = `rootID`, schemaType = nil
//   ├── layout            ← the document's top-level Node
//   │   ├── layout.children[0]
//   │   │   ├── …
//   │   │   └── …
//   │   └── layout.children[1]
//   └── …
//
// Each `Node` becomes one `StyleNode`. Primitive children (string /
// number / null) become `StyleNode`s typed `primitive_string` etc. with
// the value stringified into props. The returned array is flat and
// preserves render order so the parent flex layout iterates children
// in author-declared order.
//
// IDs are author-supplied (`Node.props.id`) when present; otherwise we
// synthesize a deterministic position-based id (`_n_0_1`). Synthetic
// ids never enter the rule-matching `id` index — only addressable
// nodes (with author ids) match `#id` selectors. This is the
// synthetic-id-leak fix that motivated the tree-native refactor.

import Foundation

internal enum StyleTreeBuilder {

    /// Walk `layout` and produce the flat node list for rendering.
    ///
    /// - Parameters:
    ///   - layout: The document's root `Node` (`Spec.layout`).
    ///   - rootID: The id used for the implicit container above `layout`.
    ///     `#<rootID>` selectors apply to it. Conventionally
    ///     `__joydom_root__` to avoid colliding with author ids.
    ///   - rules: Pre-built rule list — typically `RuleBuilder.buildRules(...)`
    ///     output, which absorbs `Spec.style`, the active breakpoint's
    ///     `style` and `nodes[id].style`, and any per-node `props.style`.
    ///   - diagnostics: Forwarded to `StyleResolver`.
    /// - Returns: `[root] + descendants` in render order, always at least
    ///   one node.
    internal static func build(
        layout: Node,
        rootID: String,
        rules: [StyleResolver.Rule],
        classNameOverrides: [String: [String]] = [:],
        bindingsByID: [String: String] = [:],
        diagnostics: inout JoyDiagnostics
    ) -> [StyleNode] {
        var output: [StyleNode] = []
        var ancestorChain: [StyleResolver.NodeRef] = []
        var siblingsByParent: [String: [StyleResolver.NodeRef]] = [:]

        // Root first. No ancestors, no siblings.
        let rootStyle = StyleResolver.resolve(
            id: rootID,
            schemaType: nil,
            classes: [],
            ancestors: [],
            precedingSiblings: [],
            rules: rules,
            diagnostics: &diagnostics
        )
        output.append(StyleNode(
            id: rootID,
            parentID: nil,
            schemaType: nil,
            classes: [],
            computedStyle: rootStyle
        ))
        siblingsByParent[rootID] = []

        // Walk the tree.
        emit(
            node: layout,
            parentID: rootID,
            path: [],
            ancestorChain: &ancestorChain,
            siblingsByParent: &siblingsByParent,
            rules: rules,
            classNameOverrides: classNameOverrides,
            bindingsByID: bindingsByID,
            output: &output,
            diagnostics: &diagnostics
        )

        return output
    }

    // MARK: - Recursion

    /// Visit `node`, resolve its style, append to `output`, then recurse
    /// into children. `ancestorChain` is mutated in/out around the
    /// recursion so each subtree sees the right ancestors.
    private static func emit(
        node: Node,
        parentID: String,
        path: [Int],
        ancestorChain: inout [StyleResolver.NodeRef],
        siblingsByParent: inout [String: [StyleResolver.NodeRef]],
        rules: [StyleResolver.Rule],
        classNameOverrides: [String: [String]],
        bindingsByID: [String: String],
        output: inout [StyleNode],
        diagnostics: inout JoyDiagnostics
    ) {
        let id          = resolveID(node: node, path: path)
        let schemaType  = node.type
        // Per-node breakpoint className override REPLACES the base
        // className (does NOT merge). Matches Josh's `spec.ts`:
        // `Breakpoint.nodes[id]` carries `Partial<NodeProps>`, and a
        // supplied `className` array overrides the base array
        // entirely. To merge instead, the spec would need a separate
        // "addedClasses" field. Pinned by
        // `testBreakpointClassNameReplacesBase` in
        // `JoyDOMViewIntegrationTests`.
        let classes     = classNameOverrides[id] ?? (node.props?.className ?? [])

        // Preceding siblings under this parent — already-emitted refs.
        let precedingSiblings = siblingsByParent[parentID] ?? []

        let computed = StyleResolver.resolve(
            id: id,
            schemaType: schemaType,
            classes: classes,
            ancestors: ancestorChain,
            precedingSiblings: precedingSiblings,
            rules: rules,
            diagnostics: &diagnostics
        )

        // Bake the FormState binding path into props if `.bindings(_:)`
        // declared one for this node id. The resolver looks here for
        // `binding`/`binding.<field>` keys to wire up Binding<String>.
        var props: [String: String] = [:]
        if let path = bindingsByID[id] {
            props["binding"] = path
        }
        output.append(StyleNode(
            id: id,
            parentID: parentID,
            schemaType: schemaType,
            classes: classes,
            props: props,
            computedStyle: computed
        ))

        // Register myself as a sibling of future descendants of my parent.
        siblingsByParent[parentID, default: []].append(StyleResolver.NodeRef(
            id: id,
            schemaType: schemaType,
            classes: classes
        ))

        // Recurse into Node children. Primitives are leaf StyleNodes —
        // they get a synthetic id and a primitive_<kind> schemaType so
        // factories registered via DefaultPrimitives can render them.
        guard let children = node.children, !children.isEmpty else { return }

        // Push myself onto the ancestor chain for descendants.
        ancestorChain.insert(StyleResolver.NodeRef(
            id: id,
            schemaType: schemaType,
            classes: classes
        ), at: 0)
        // Reset siblings tracking for this new parent scope.
        siblingsByParent[id] = []

        for (index, child) in children.enumerated() {
            let childPath = path + [index]
            switch child {
            case .node(let childNode):
                emit(
                    node: childNode,
                    parentID: id,
                    path: childPath,
                    ancestorChain: &ancestorChain,
                    siblingsByParent: &siblingsByParent,
                    rules: rules,
                    classNameOverrides: classNameOverrides,
                    bindingsByID: bindingsByID,
                    output: &output,
                    diagnostics: &diagnostics
                )
            case .primitive(let value):
                emitPrimitive(
                    value: value,
                    parentID: id,
                    path: childPath,
                    ancestorChain: ancestorChain,
                    siblingsByParent: &siblingsByParent,
                    rules: rules,
                    output: &output,
                    diagnostics: &diagnostics
                )
            }
        }

        // Pop ancestor.
        ancestorChain.removeFirst()
    }

    /// Primitive children (string / number / null) become leaf nodes
    /// with a synthetic id and a `primitive_<kind>` type so the registered
    /// factories can render them.
    private static func emitPrimitive(
        value: PrimitiveValue,
        parentID: String,
        path: [Int],
        ancestorChain: [StyleResolver.NodeRef],
        siblingsByParent: inout [String: [StyleResolver.NodeRef]],
        rules: [StyleResolver.Rule],
        output: inout [StyleNode],
        diagnostics: inout JoyDiagnostics
    ) {
        let id = syntheticID(for: path)
        let (schemaType, props): (String, [String: String]) = {
            switch value {
            case .string(let s): return ("primitive_string", ["value": s])
            case .number(let n): return ("primitive_number", ["value": formatNumber(n)])
            case .null:          return ("primitive_null",   [:])
            }
        }()

        let precedingSiblings = siblingsByParent[parentID] ?? []
        let computed = StyleResolver.resolve(
            id: id,
            schemaType: schemaType,
            classes: [],
            ancestors: ancestorChain,
            precedingSiblings: precedingSiblings,
            rules: rules,
            diagnostics: &diagnostics
        )

        output.append(StyleNode(
            id: id,
            parentID: parentID,
            schemaType: schemaType,
            classes: [],
            props: props,
            computedStyle: computed
        ))

        siblingsByParent[parentID, default: []].append(StyleResolver.NodeRef(
            id: id,
            schemaType: schemaType,
            classes: []
        ))
    }

    // MARK: - Identity

    /// Author-supplied `props.id` wins; otherwise a deterministic
    /// position-based fallback.
    ///
    /// Synthetic ids carry a `__joydom_anon_` prefix so they're visibly
    /// generated and unlikely to collide with author-supplied ids. They
    /// can still appear in `StyleNode.id`, event `sourceID`, and debug
    /// logs — that's by design (the resolver needs a stable identity
    /// for every node, even unaddressable ones). What they DON'T do:
    /// participate in the cascade as `#id` selector targets, because
    /// `RuleBuilder.appendInlineRules` skips nodes without an
    /// author-supplied `props.id`. So a hostile selector
    /// `#__joydom_anon_0_1` would only match if the author somehow
    /// wrote that exact id elsewhere, which the prefix makes extremely
    /// unlikely.
    private static func resolveID(node: Node, path: [Int]) -> String {
        if let explicit = node.props?.id { return explicit }
        return syntheticID(for: path)
    }

    /// `[]` → unused (root has its own id); `[0]` → `__joydom_anon_0`;
    /// `[0, 1]` → `__joydom_anon_0_1`.
    private static func syntheticID(for path: [Int]) -> String {
        guard !path.isEmpty else { return "__joydom_anon_" }
        return "__joydom_anon_" + path.map(String.init).joined(separator: "_")
    }

    // MARK: - Number formatting

    /// Match `StyleSerializer`'s prior behavior: drop trailing `.0` for
    /// integer-valued doubles so primitive numbers round-trip cleanly.
    private static func formatNumber(_ value: Double) -> String {
        if value.truncatingRemainder(dividingBy: 1) == 0 {
            return String(Int(value))
        }
        return String(value)
    }
}
