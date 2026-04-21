// ComponentBody — the wrapper value a `ComponentFactory` returns.
//
// Tier 2 introduces this type between the factory and the resolver so the
// registry's public API no longer speaks `AnyView` directly. That keeps the
// door open for non-SwiftUI rendering backends (UIKit, WKWebView, Flutter,
// etc.) — each arrives as its own static factory on `ComponentBody` that
// wraps the host-native view into a SwiftUI-consumable surface via
// `UIViewRepresentable` / `NSViewRepresentable`.
//
// Phase: Tier 2. Today only `.custom` is implemented; `.uiKit` and
// `.webView` land in subsequent units of this plan.

import SwiftUI

/// The output of a ``ComponentFactory``.
///
/// Construct one via a static factory (`.custom`, and — in later units —
/// `.uiKit`, `.webView`). The resolver calls ``makeView()`` to obtain the
/// SwiftUI-consumable view it inserts into the flex tree.
public struct ComponentBody {
    // Red-phase stub: the builder is never stored, so the counter test
    // below will observe zero invocations after `makeView()`. Unit 1's
    // green commit replaces this with a proper `Storage` enum.
    private let _stubbed: Void

    internal enum Kind: Equatable {
        case custom
    }

    /// Internal tag for tests (via `@testable import`).
    internal var kind: Kind { .custom }

    /// Build a `ComponentBody` that renders a SwiftUI view.
    ///
    /// The closure runs every time ``makeView()`` is called. Callers must
    /// not assume single invocation — SwiftUI may rebuild the wrapped view
    /// repeatedly during a layout pass.
    public static func custom<V: View>(_ build: @escaping () -> V) -> ComponentBody {
        // Red stub: ignores `build` entirely so the "builder invoked"
        // assertion fails. Green replaces this with proper storage.
        _ = build
        return ComponentBody(_stubbed: ())
    }

    /// Produce the SwiftUI view. The resolver inserts the result into the
    /// flex tree — callers typically don't invoke this directly.
    public func makeView() -> AnyView {
        AnyView(EmptyView())
    }
}
