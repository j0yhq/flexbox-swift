// ViewportProvider — wires `Viewport` (Unit 5) into CSSLayout's render
// pipeline so breakpoint resolution (Unit 7) and breakpoint application
// (Unit 8) can read the current rendering environment without each
// step having to scrape SwiftUI geometry on its own.
//
// Two layers in this file:
//
//   1. A protocol + concrete static provider — pure data, no SwiftUI
//      dependency, used by tests and previews to drive deterministic
//      breakpoint scenarios.
//
//   2. A SwiftUI environment key + `.joyViewport(_:)` view modifier —
//      so a host that knows the current viewport (e.g. a window with
//      a `GeometryReader` wrapping the layout) can push it down the
//      view tree. CSSLayout's render pipeline reads it from the
//      environment in Unit 8.
//
// Live geometry observation (`GeometryReader` + `UITraitCollection` /
// `NSWindow`) is a host concern. The repo's existing
// `ResponsivePreview` (FlexDemoApp) already supplies a width slider
// for previews — Unit 11's demo wires that slider directly into
// `.joyViewport(_:)`.

import SwiftUI

/// Source for the current `Viewport`. Implementations may be static
/// (tests / previews) or live (a SwiftUI host that reads geometry).
public protocol ViewportProvider {
    func currentViewport() -> Viewport
}

/// Trivial provider that always returns the same viewport. Used in
/// tests, previews, and as the default before a host wires up a real
/// observer.
public struct StaticViewportProvider: ViewportProvider {
    public let viewport: Viewport

    public init(_ viewport: Viewport) {
        self.viewport = viewport
    }

    public func currentViewport() -> Viewport {
        viewport
    }
}

// MARK: - SwiftUI environment

/// Environment key carrying the active viewport. The default value is
/// `nil` — meaning "no host wired this up"; downstream resolvers
/// fall back to a sensible default (a wide-portrait viewport, so
/// breakpoints with `min-width` rules don't accidentally activate).
public struct ViewportEnvironmentKey: EnvironmentKey {
    public static let defaultValue: Viewport? = nil
}

extension EnvironmentValues {
    /// Read the host-supplied viewport. `nil` means the environment
    /// hasn't been populated; resolvers should treat that as a signal
    /// to fall back to a default rather than throw.
    public var joyViewport: Viewport? {
        get { self[ViewportEnvironmentKey.self] }
        set { self[ViewportEnvironmentKey.self] = newValue }
    }
}

extension View {
    /// Inject a viewport into the SwiftUI environment for downstream
    /// CSSLayout views. Hosts call this from inside a `GeometryReader`
    /// (or a `ResponsivePreview`-like simulator) to feed the current
    /// width / orientation / print-mode into breakpoint resolution.
    public func joyViewport(_ viewport: Viewport) -> some View {
        environment(\.joyViewport, viewport)
    }
}
