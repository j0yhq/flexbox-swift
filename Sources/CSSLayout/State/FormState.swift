// FormState — the Phase-3 binding value store.
//
// Owns every field value that a component binds against via
// `events.binding(_:)`. Because FormState lives *outside* the CSSLayout view
// tree (typically as an `@StateObject` on the hosting screen), field values
// survive the re-render that fires when the CSS payload hot-swaps. That
// state continuity is the whole point of having a separate store rather
// than leaning on SwiftUI `@State` inside each factory view.
//
// Design constraints:
//   • Flat string-keyed map. Paths like `"user.name"` are opaque strings to
//     this layer — nesting is a caller convention, not something FormState
//     parses or validates.
//   • `set` is idempotent on equal values so a SwiftUI `Binding`'s setter
//     echoing the current value doesn't cause a publish-render loop.
//   • `prune(keeping:)` is the hot-swap escape hatch: callers compute the
//     new payload's binding paths and ask FormState to drop anything else.
//     Critically, `prune` does **not** publish — it runs during SwiftUI
//     render (inside `CSSLayout.renderSnapshot`), where publishing would
//     trigger the runtime warning "Publishing changes from within view
//     updates is not allowed" and leave render order undefined. Pruned
//     paths are by definition orphans whose binding factory has been
//     dropped from the tree, so no observer needs a re-render.
//
// Phase 4 will gate writes behind a serial queue or make the type an actor
// if call sites start racing. For now SwiftUI drives all mutations on the
// main run loop, so a plain class is sufficient.
//
// Implementation note: we deliberately do not use `@Published` on the
// backing store, because `@Published` can't distinguish "mutation that
// must publish" (a caller-initiated `set`) from "mutation that must stay
// silent" (a render-time `prune`). Instead we hold a plain `_values` and
// call `objectWillChange.send()` by hand from `set` only.

import Foundation
import Combine

/// Binding-backed value store that outlives any single `CSSLayout` render.
///
/// Inject as an `@StateObject` (or `@EnvironmentObject` for nested screens)
/// so bound components can read/write form state across CSS hot-swaps.
public final class FormState: ObservableObject {

    /// The raw storage. Not `@Published` — see the file-level note:
    /// `set` publishes by hand, `prune` stays silent. External reads go
    /// through `values` (computed, read-only) or `snapshot()`.
    private var _values: [String: String]

    /// Read-only view of the current store. Kept for compatibility with
    /// callers (mainly tests) that inspect the dict directly. Mutation must
    /// still go through `set` / `prune` so the publishing contract holds.
    public var values: [String: String] { _values }

    /// Create a FormState, optionally seeded with initial values. Seeded
    /// values are present before the first `set`, handy for server-rendered
    /// forms that arrive pre-populated.
    public init(values: [String: String] = [:]) {
        self._values = values
    }

    /// Read the value at `path`, or `nil` if nothing has been written.
    public func get(_ path: String) -> String? {
        _values[path]
    }

    /// Write `value` to `path`. Idempotent on equal values — a no-op write
    /// does not fire `objectWillChange`, so SwiftUI Bindings can safely
    /// round-trip without triggering render loops.
    public func set(_ path: String, _ value: String) {
        if _values[path] == value { return }
        objectWillChange.send()
        _values[path] = value
    }

    /// Return a point-in-time copy of the store. Callers (e.g. a submit
    /// handler that captures state in an escaping closure) can keep the
    /// returned dict without racing against future `set` calls.
    public func snapshot() -> [String: String] {
        _values
    }

    /// Drop every path not in `paths`. Use this during CSS hot-swap: compute
    /// the new payload's set of binding paths and prune everything else so
    /// stale fields don't leak across payloads.
    ///
    /// **Does not publish**, even when it removes paths. `prune` runs during
    /// SwiftUI view composition (inside `CSSLayout.renderSnapshot`); firing
    /// `objectWillChange` there would provoke the runtime warning
    /// "Publishing changes from within view updates is not allowed" and
    /// make render order undefined. A pruned path is by definition one
    /// whose binding factory just vanished from the tree, so there's no
    /// observer that still needs its old value. The data contract
    /// (removed paths are gone; kept paths are unchanged) is preserved.
    public func prune(keeping paths: Set<String>) {
        let hasOrphan = _values.keys.contains { !paths.contains($0) }
        guard hasOrphan else { return }
        _values = _values.filter { paths.contains($0.key) }
    }
}
