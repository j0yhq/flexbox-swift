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
//
// Phase 4 will gate writes behind a serial queue or make the type an actor
// if call sites start racing. For now SwiftUI drives all mutations on the
// main run loop, so a plain class is sufficient.

import Foundation
import Combine

/// Binding-backed value store that outlives any single `CSSLayout` render.
///
/// Inject as an `@StateObject` (or `@EnvironmentObject` for nested screens)
/// so bound components can read/write form state across CSS hot-swaps.
public final class FormState: ObservableObject {

    /// The raw storage. `private(set)` so mutation goes through `set` /
    /// `prune`, which enforce the idempotency and publishing rules.
    @Published public private(set) var values: [String: String]

    /// Create a FormState, optionally seeded with initial values. Seeded
    /// values are present before the first `set`, handy for server-rendered
    /// forms that arrive pre-populated.
    public init(values: [String: String] = [:]) {
        self.values = values
    }

    /// Read the value at `path`, or `nil` if nothing has been written.
    public func get(_ path: String) -> String? {
        values[path]
    }

    /// Write `value` to `path`. Idempotent on equal values — a no-op write
    /// does not fire `objectWillChange`, so SwiftUI Bindings can safely
    /// round-trip without triggering render loops.
    public func set(_ path: String, _ value: String) {
        if values[path] == value { return }
        values[path] = value
    }

    /// Return a point-in-time copy of the store. Callers (e.g. a submit
    /// handler that captures state in an escaping closure) can keep the
    /// returned dict without racing against future `set` calls.
    public func snapshot() -> [String: String] {
        values
    }

    /// Drop every path not in `paths`. Use this during CSS hot-swap: compute
    /// the new payload's set of binding paths and prune everything else so
    /// stale fields don't leak across payloads. Publishes only when at least
    /// one path was actually removed.
    public func prune(keeping paths: Set<String>) {
        // Filter in two steps so we can detect whether anything changed
        // *before* assigning to the @Published property (which would
        // publish regardless of whether the new value equals the old).
        let removed = values.keys.contains { !paths.contains($0) }
        guard removed else { return }
        values = values.filter { paths.contains($0.key) }
    }
}
