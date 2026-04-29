// ComponentBody+UIKit — lift a UIKit `UIView` into the JoyDOMView
// component pipeline.
//
// The bridge lets factory authors return any `UIView` subclass from a
// `ComponentBody`-returning factory; internally the view is wrapped in a
// private `UIViewRepresentable` so SwiftUI can host it as part of the
// flex tree. `update` fires on every SwiftUI layout pass — authors
// mutate the supplied view in place rather than returning a new one.
//
// Platform guard: UIKit is unavailable on macOS and watchOS — on those
// platforms this file simply isn't compiled, and calling `.uiKit(...)`
// produces "member not found" at the call site, making the platform
// mismatch a compile-time error instead of a runtime trap.

#if canImport(UIKit) && !os(watchOS)

import SwiftUI
import UIKit

extension ComponentBody {

    /// Build a `ComponentBody` that wraps a UIKit `UIView`.
    ///
    /// - Parameters:
    ///   - make: Builds the underlying view once per SwiftUI
    ///     `UIViewRepresentable` instantiation. Capture any initial
    ///     configuration inside this closure.
    ///   - update: Fires on every SwiftUI layout pass. Push the latest
    ///     values captured from the enclosing factory into the view.
    ///     Defaults to a no-op for views that only need `make`.
    public static func uiKit<V: UIView>(
        make: @escaping () -> V,
        update: @escaping (V) -> Void = { _ in }
    ) -> ComponentBody {
        // Erase the concrete `V` to `UIView` so Storage stays
        // non-generic. The `update` adapter downcasts — the only way
        // the stored view is not a `V` is if the Storage is mutated
        // externally, which we don't permit.
        ComponentBody(storage: .uiKit(
            make: { make() },
            update: { erased in
                guard let concrete = erased as? V else { return }
                update(concrete)
            }
        ))
    }

    // MARK: - Internal test hooks

    /// Returns the wrapped `UIView` by invoking the stored `make`
    /// closure. Visible only to `@testable import` consumers; returns
    /// nil when the body doesn't hold a UIKit bridge.
    internal func _invokeMake() -> UIView? {
        if case .uiKit(let make, _) = storage {
            return make()
        }
        return nil
    }

    /// Invokes the stored `update` closure against `view`. Visible only
    /// to `@testable import` consumers; no-op when the body doesn't
    /// hold a UIKit bridge.
    internal func _invokeUpdate(_ view: UIView) {
        if case .uiKit(_, let update) = storage {
            update(view)
        }
    }
}

#endif
