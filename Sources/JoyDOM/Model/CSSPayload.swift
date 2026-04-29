// CSSPayload / SchemaEntry — the caller-supplied input to `JoyDOMView`.
//
// A `CSSPayload` bundles the CSS text with the schema that names each
// renderable node and optionally types it (e.g. `"button"`, `"text-input"`)
// so element selectors can match.
//
// In Phase 1 the schema is a plain ordered list — no nesting. Phase 3 will
// add per-entry `bindings` and `props` dictionaries for `FormState`.

import Foundation

/// One entry in the layout schema — the authoring counterpart to a DOM node.
///
/// The `id` is the anchor for `#id` selectors and the key that
/// `CSSLayoutBuilder` locals match against. `type` is matched by element
/// selectors (`button { … }` matches every entry with `type == "button"`).
internal struct SchemaEntry: Equatable {
    /// Unique per payload — the cascade matches `#id` selectors against this.
    let id: String
    /// Optional component type; `nil` means "unknown component, resolver will
    /// render a placeholder in debug builds".
    let type: String?
    /// Zero or more CSS class names this entry carries. `.name` selectors in
    /// the stylesheet match against this list. Defaults to empty so callers
    /// that predate class support keep compiling unchanged.
    let classes: [String]
    /// Optional id of the entry's parent in the layout tree. `nil` (default)
    /// attaches the entry to the implicit root. Non-nil ids that don't resolve
    /// to another entry fall back to root — the tree is always connected.
    let parentID: String?
    /// Opaque prop bag (placeholder text, labels, binding paths, etc.)
    /// handed to the component factory as `ComponentProps.values`.
    let props: [String: String]

    init(
        id: String,
        type: String? = nil,
        classes: [String] = [],
        parentID: String? = nil,
        props: [String: String] = [:]
    ) {
        self.id = id
        self.type = type
        self.classes = classes
        self.parentID = parentID
        self.props = props
    }
}

/// The server-driven (or hard-coded) payload consumed by `JoyDOMView`.
///
/// Phase 1 carries exactly two fields. Phase 3 will add `version` and
/// `bindings` for `FormState` integration.
internal struct CSSPayload: Equatable {
    /// The raw CSS text. Tolerance rules: any malformed/unsupported rule is
    /// dropped with a diagnostic, so safe to pass server-delivered strings.
    let css: String
    /// Schema entries in render order. The first entry renders first in the
    /// parent flex container.
    let schema: [SchemaEntry]

    init(css: String, schema: [SchemaEntry] = []) {
        self.css = css
        self.schema = schema
    }
}
