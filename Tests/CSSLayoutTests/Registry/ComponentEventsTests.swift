import XCTest
import SwiftUI
@testable import CSSLayout

/// Unit 3 — `ComponentEvents.binding(_:)` gives a factory a SwiftUI
/// `Binding<String>` for a named field (e.g. `"value"`, `"checked"`).
///
/// Contract:
///   • When no binding resolver has been installed (the default
///     `ComponentEvents()`), `binding(_:)` returns a dead binding
///     (`Binding.constant("")`). Factories can call it unconditionally
///     without needing to know whether the surrounding payload wired
///     them up.
///   • When a resolver is installed, `binding(_:)` delegates to it with
///     the field name and returns the resolver's `Binding<String>`.
///     Reads and writes against the returned binding must round-trip
///     through whatever storage the resolver closed over (in production
///     that storage is `FormState`).
final class ComponentEventsTests: XCTestCase {

    // MARK: - Default (no resolver)

    /// With no binding resolver wired, reading the binding returns the
    /// empty string — this is the "factory asked for a binding the schema
    /// didn't declare" path.
    func testBindingDefaultsToEmptyStringWhenNoResolver() {
        let events = ComponentEvents()
        XCTAssertEqual(events.binding("value").wrappedValue, "")
    }

    /// Writes against a dead binding are silently ignored — the factory
    /// still compiles, and there's no hidden shared state to corrupt.
    func testDeadBindingIgnoresWrites() {
        let events = ComponentEvents()
        let b = events.binding("value")
        b.wrappedValue = "ignored"
        XCTAssertEqual(
            events.binding("value").wrappedValue, "",
            "dead binding must not retain written values"
        )
    }

    // MARK: - Resolver delegation

    /// `binding(_:)` calls the installed resolver with the field name
    /// verbatim — no normalisation, no prefixing — so factories that ask
    /// for `"checked"` get back whatever the resolver mapped to that
    /// field. The test captures the field name to prove delegation.
    func testBindingDelegatesFieldNameToResolver() {
        final class Capture { var seen: String? }
        let captured = Capture()
        let events = ComponentEvents(
            sink: nil,
            bindings: { field in
                captured.seen = field
                return .constant("")
            }
        )
        _ = events.binding("checked")
        XCTAssertEqual(captured.seen, "checked")
    }

    /// A resolver-backed binding round-trips writes through its backing
    /// storage. This is the FormState integration in miniature — real
    /// FormState substitutes for the local `String` capture below.
    func testResolverBoundBindingRoundTripsReadsAndWrites() {
        final class Store { var value: String = "initial" }
        let store = Store()
        let events = ComponentEvents(
            sink: nil,
            bindings: { _ in
                Binding(
                    get: { store.value },
                    set: { store.value = $0 }
                )
            }
        )
        let b = events.binding("value")
        XCTAssertEqual(b.wrappedValue, "initial")
        b.wrappedValue = "updated"
        XCTAssertEqual(store.value, "updated")
        XCTAssertEqual(events.binding("value").wrappedValue, "updated",
                       "second lookup must see the updated value")
    }

    // MARK: - Host-agnostic value surface (Tier 2)

    /// With no `ValueStore` injected, `value(for:)` returns nil — this
    /// lets factories call it unconditionally without branching on
    /// whether the surrounding payload wired a store.
    func testValueForReturnsNilWhenUnbound() {
        let events = ComponentEvents()
        XCTAssertNil(events.value(for: "name"))
    }

    /// `setValue(_:for:)` must route to the injected store's `set`
    /// closure — the store is the single source of truth, not
    /// `ComponentEvents` itself.
    func testSetValueRoutesToProvider() {
        let store = InMemoryValueStore()
        let events = ComponentEvents(
            sink: nil,
            bindings: nil,
            values: store.asValueStore
        )
        events.setValue("hello", for: "name")
        XCTAssertEqual(store.values["name"], "hello")
    }

    /// `observe(_:_:)` must deliver callbacks on subsequent writes to the
    /// same field. This is the entry point for UIKit/WebKit factories
    /// that can't consume SwiftUI's `Binding<String>`.
    func testObserveFiresOnSetValue() {
        let store = InMemoryValueStore()
        let events = ComponentEvents(
            sink: nil,
            bindings: nil,
            values: store.asValueStore
        )
        var received: [String] = []
        _ = events.observe("name") { received.append($0) }
        events.setValue("ada", for: "name")
        events.setValue("lovelace", for: "name")
        XCTAssertEqual(received, ["ada", "lovelace"])
    }

    /// Cancelling the observer token stops further delivery.
    func testObserveCancellableStopsDelivery() {
        let store = InMemoryValueStore()
        let events = ComponentEvents(
            sink: nil,
            bindings: nil,
            values: store.asValueStore
        )
        var received: [String] = []
        let token = events.observe("name") { received.append($0) }
        events.setValue("one", for: "name")
        token.cancel()
        events.setValue("two", for: "name")
        XCTAssertEqual(received, ["one"], "writes after cancel must not fire")
    }

    // MARK: - emit() untouched

    /// Adding the binding parameter must not change the existing `emit`
    /// behavior — the two concerns compose, they don't conflict.
    func testEmitStillWorksAlongsideBindings() {
        final class Recorder {
            var events: [(name: String, payload: [String: String])] = []
        }
        let rec = Recorder()
        let events = ComponentEvents(
            sink: { name, payload, _ in rec.events.append((name, payload)) },
            bindings: { _ in .constant("") }
        )
        events.emit("tap", payload: ["x": "1"])
        XCTAssertEqual(rec.events.count, 1)
        XCTAssertEqual(rec.events.first?.name, "tap")
        XCTAssertEqual(rec.events.first?.payload["x"], "1")
    }
}

// MARK: - Test doubles

/// A minimal test double for the Tier-2 host-agnostic value store. It
/// mirrors FormState's read/write/observe contract but keeps everything
/// in a local dictionary so tests can assert directly on state.
///
/// Cancellation is modeled via a flag on the ``ObserverToken`` rather
/// than array mutation — simpler to reason about and avoids self-capture
/// dance inside the observer closure.
private final class InMemoryValueStore {
    var values: [String: String] = [:]
    private var observers: [String: [(token: ObserverToken, handler: (String) -> Void)]] = [:]

    final class ObserverToken: Cancellable {
        private(set) var cancelled = false
        func cancel() { cancelled = true }
    }

    var asValueStore: ValueStore {
        ValueStore(
            get: { [weak self] field in self?.values[field] },
            set: { [weak self] value, field in
                self?.values[field] = value
                self?.observers[field]?.forEach { entry in
                    if !entry.token.cancelled { entry.handler(value) }
                }
            },
            observe: { [weak self] field, handler in
                let token = ObserverToken()
                self?.observers[field, default: []].append((token, handler))
                return token
            }
        )
    }
}
