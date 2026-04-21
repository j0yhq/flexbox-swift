import XCTest
import Combine
@testable import CSSLayout

/// Unit 1 — `FormState` is the Phase-3 value store that outlives any single
/// `CSSLayout` render, giving bound components state continuity across CSS
/// hot-swaps (per CSSLayout-Design.md §4.6).
///
/// Contract:
///   • A flat string-to-string key/value map. The key is the binding path
///     (e.g. `"user.name"`); nested paths are opaque strings to this layer.
///   • `ObservableObject` via `@Published`, so SwiftUI views re-render when
///     a path they bind to changes.
///   • `set` is idempotent on equal values (no publish), so a round-trip
///     through a SwiftUI `Binding` doesn't create a publish/render loop.
///   • `prune(keeping:)` drops paths not in the allow-list — this is how
///     hot-swap discards bindings whose fields disappeared.
final class FormStateTests: XCTestCase {

    // MARK: - Construction

    func testInitializesEmptyByDefault() {
        let state = FormState()
        XCTAssertEqual(state.values, [:])
    }

    func testInitializesWithSeedValues() {
        let state = FormState(values: ["user.name": "Ada"])
        XCTAssertEqual(state.values["user.name"], "Ada")
    }

    // MARK: - Read / write

    func testGetReturnsStoredValue() {
        let state = FormState(values: ["email": "ada@lovelace.org"])
        XCTAssertEqual(state.get("email"), "ada@lovelace.org")
    }

    func testGetReturnsNilForMissingPath() {
        let state = FormState()
        XCTAssertNil(state.get("nope"))
    }

    func testSetStoresValueAtPath() {
        let state = FormState()
        state.set("user.name", "Ada")
        XCTAssertEqual(state.get("user.name"), "Ada")
    }

    func testSetOverwritesExistingValue() {
        let state = FormState(values: ["a": "1"])
        state.set("a", "2")
        XCTAssertEqual(state.get("a"), "2")
    }

    // MARK: - Snapshot

    func testSnapshotReturnsCurrentValues() {
        let state = FormState(values: ["a": "1", "b": "2"])
        XCTAssertEqual(state.snapshot(), ["a": "1", "b": "2"])
    }

    func testSnapshotIsIndependentCopy() {
        // Callers (e.g. a `submit` handler) may capture the snapshot in an
        // escaping closure and inspect it later — a concurrent `set` on the
        // live state must not mutate the captured dict.
        let state = FormState(values: ["a": "1"])
        let snap = state.snapshot()
        state.set("a", "2")
        XCTAssertEqual(snap["a"], "1")
    }

    // MARK: - Prune (hot-swap support)

    func testPruneKeepsOnlyListedPaths() {
        let state = FormState(values: ["a": "1", "b": "2", "c": "3"])
        state.prune(keeping: ["a", "c"])
        XCTAssertEqual(state.snapshot(), ["a": "1", "c": "3"])
    }

    func testPruneWithEmptySetRemovesAll() {
        let state = FormState(values: ["a": "1", "b": "2"])
        state.prune(keeping: [])
        XCTAssertEqual(state.snapshot(), [:])
    }

    func testPruneIsNoOpWhenAllPathsKept() {
        let state = FormState(values: ["a": "1"])
        state.prune(keeping: ["a", "b"])  // b isn't present; still a no-op
        XCTAssertEqual(state.snapshot(), ["a": "1"])
    }

    // MARK: - Publishing (ObservableObject contract)

    /// A change to `values` must fire `objectWillChange` so SwiftUI views
    /// holding an `@ObservedObject` / `@EnvironmentObject` re-render.
    func testSetPublishesChange() {
        let state = FormState()
        var fired = 0
        let bag = state.objectWillChange.sink { fired += 1 }
        state.set("a", "1")
        bag.cancel()
        XCTAssertEqual(fired, 1)
    }

    /// `set` is idempotent on equal values: avoiding unnecessary publishes
    /// prevents SwiftUI Binding ↔ FormState round-trips from looping.
    func testSetWithSameValueDoesNotPublish() {
        let state = FormState(values: ["a": "1"])
        var fired = 0
        let bag = state.objectWillChange.sink { fired += 1 }
        state.set("a", "1")
        bag.cancel()
        XCTAssertEqual(fired, 0, "no publish expected when value is unchanged")
    }

    /// `prune` must never fire `objectWillChange`, whether it removes paths
    /// or not. Prune is internal bookkeeping that `CSSLayout.renderSnapshot`
    /// calls *during* SwiftUI view composition to drop orphaned paths; if
    /// it published, SwiftUI would log
    ///
    ///   "Publishing changes from within view updates is not allowed"
    ///
    /// and the render order would be undefined. Pruned paths are by
    /// definition ones whose binding factory is gone from the tree, so no
    /// observer needs a re-render.
    func testPruneDoesNotPublish() {
        let state = FormState(values: ["a": "1", "b": "2"])
        var fired = 0
        let bag = state.objectWillChange.sink { fired += 1 }
        state.prune(keeping: ["a", "b"])   // nothing to remove
        XCTAssertEqual(fired, 0, "no-op prune must not publish")
        state.prune(keeping: ["a"])        // drops b
        bag.cancel()
        XCTAssertEqual(fired, 0, "removing prune must not publish either — it runs during render")
    }

    /// Prune is still observably correct: after a removing prune, the
    /// dropped path is gone and kept paths remain unchanged. The publish
    /// contract changed; the data contract did not.
    func testPruneStillRemovesOrphanPathsWithoutPublishing() {
        let state = FormState(values: ["a": "1", "b": "2", "c": "3"])
        state.prune(keeping: ["a", "c"])
        XCTAssertEqual(state.snapshot(), ["a": "1", "c": "3"])
        XCTAssertNil(state.get("b"))
    }
}
