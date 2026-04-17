// Component — a local override for a single schema id.
//
// `CSSLayout` looks up every rendered node against:
//   1. The locals block (this type)
//   2. The component registry
//   3. A placeholder fallback
//
// Locals let app code render one-off SwiftUI views without touching the
// global registry — typical for inline components, previews, and tests.

import Foundation
import SwiftUI

/// A local component override for a single node id.
///
/// Use inside the trailing closure of `CSSLayout(...)` to attach a SwiftUI
/// view directly to a schema id, bypassing the registry.
///
/// ```swift
/// CSSLayout(payload: payload) {
///     Component("banner") { Image("hero").resizable() }
///     Component("submit") { Button("Go") { … } }
/// }
/// ```
public struct Component {
    /// The schema id this component renders for.
    public let id: String
    /// Type-erased SwiftUI body captured from the trailing closure.
    public let content: AnyView

    public init<V: View>(_ id: String, @ViewBuilder _ content: () -> V) {
        self.id = id
        self.content = AnyView(content())
    }
}
