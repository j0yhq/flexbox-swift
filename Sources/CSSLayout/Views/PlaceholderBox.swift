// PlaceholderBox — the default fallback view for unresolved nodes.
//
// In DEBUG builds we render a visible grey rectangle labelled with the id so
// authoring mistakes surface obviously. In RELEASE we collapse to an empty
// zero-sized view — the layout engine still tracks the node for flex sizing
// but the user sees nothing.

import SwiftUI

/// The default placeholder shown when `ComponentResolver` can't find a
/// factory for a node.
public struct PlaceholderBox: View {
    public let id: String

    public init(id: String) {
        self.id = id
    }

    public var body: some View {
        #if DEBUG
        RoundedRectangle(cornerRadius: 4)
            .fill(Color.gray.opacity(0.15))
            .overlay(
                Text("#\(id)")
                    .font(.caption.monospaced())
                    .foregroundColor(.secondary)
                    .padding(4)
            )
        #else
        Color.clear.frame(width: 0, height: 0)
        #endif
    }
}
