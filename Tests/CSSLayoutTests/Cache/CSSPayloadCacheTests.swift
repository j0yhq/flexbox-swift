import XCTest
@testable import CSSLayout

/// Unit 5 — `CSSPayloadCache` is an actor-based LRU for `CSSPayload`s
/// keyed by a caller-chosen version string (usually a content hash or
/// the server's `ETag`). It exists so apps fetching CSS over the network
/// don't re-parse the same payload on every screen mount.
///
/// Contract:
///   • Empty cache → every `get` returns nil.
///   • `put` followed by `get(key)` returns the stored payload.
///   • A capacity-limited cache evicts the *least recently used* entry
///     when a new key pushes it past capacity. "Recently used" is
///     updated on both `put` (insert / overwrite) and `get` (hit).
///   • Re-putting an existing key overwrites the payload and promotes
///     the key to most-recently-used without changing `count`.
///   • `clear()` drops every entry.
///   • All operations are safe to call from concurrent tasks (actor
///     isolation; no data races on the internal ordering).
final class CSSPayloadCacheTests: XCTestCase {

    // MARK: - Fixtures

    private func payload(_ tag: String) -> CSSPayload {
        CSSPayload(
            css: "#\(tag) { flex: 1; }",
            schema: [SchemaEntry(id: tag)]
        )
    }

    // MARK: - Basic read/write

    func testEmptyCacheReturnsNil() async {
        let cache = CSSPayloadCache()
        let hit = await cache.get("missing")
        XCTAssertNil(hit)
    }

    func testPutAndGetRoundTrips() async {
        let cache = CSSPayloadCache()
        let p = payload("a")
        await cache.put("v1", p)
        let hit = await cache.get("v1")
        XCTAssertEqual(hit, p)
    }

    func testCountReflectsStoredEntries() async {
        let cache = CSSPayloadCache()
        await cache.put("v1", payload("a"))
        await cache.put("v2", payload("b"))
        let count = await cache.count
        XCTAssertEqual(count, 2)
    }

    func testClearEmptiesCache() async {
        let cache = CSSPayloadCache()
        await cache.put("v1", payload("a"))
        await cache.put("v2", payload("b"))
        await cache.clear()
        let count = await cache.count
        XCTAssertEqual(count, 0)
        let hit = await cache.get("v1")
        XCTAssertNil(hit)
    }

    // MARK: - Overwrite semantics

    func testPutOverwritesExistingKey() async {
        let cache = CSSPayloadCache()
        await cache.put("v1", payload("a"))
        let replacement = payload("z")
        await cache.put("v1", replacement)
        let count = await cache.count
        XCTAssertEqual(count, 1, "overwrite must not grow the cache")
        let hit = await cache.get("v1")
        XCTAssertEqual(hit, replacement)
    }

    // MARK: - LRU eviction

    /// Default / caller-specified capacity: the oldest-by-access entry
    /// is evicted on overflow, not the oldest-by-insertion.
    func testCapacityEvictsLeastRecentlyUsed() async {
        let cache = CSSPayloadCache(capacity: 2)
        await cache.put("a", payload("a"))
        await cache.put("b", payload("b"))
        // Touching "a" makes "b" the LRU.
        _ = await cache.get("a")
        await cache.put("c", payload("c"))
        let a = await cache.get("a")
        let b = await cache.get("b")
        let c = await cache.get("c")
        XCTAssertNotNil(a, "recently-used 'a' must survive eviction")
        XCTAssertNil(b,    "least-recently-used 'b' must be evicted")
        XCTAssertNotNil(c, "newly-inserted 'c' must be present")
    }

    /// A hit promotes the key to most-recently-used, so a later eviction
    /// picks a different key.
    func testGetPromotesEntryToMostRecentlyUsed() async {
        let cache = CSSPayloadCache(capacity: 2)
        await cache.put("a", payload("a"))
        await cache.put("b", payload("b"))
        _ = await cache.get("a") // promote 'a'
        await cache.put("c", payload("c")) // evicts LRU: 'b'
        let b = await cache.get("b")
        XCTAssertNil(b, "get-promoted 'a' outranks 'b' on LRU order")
    }

    /// Re-putting an existing key also promotes it to MRU.
    func testPutPromotesExistingKeyToMostRecentlyUsed() async {
        let cache = CSSPayloadCache(capacity: 2)
        await cache.put("a", payload("a"))
        await cache.put("b", payload("b"))
        await cache.put("a", payload("a2")) // overwrite + promote
        await cache.put("c", payload("c"))  // evicts 'b'
        let a = await cache.get("a")
        let b = await cache.get("b")
        XCTAssertNotNil(a)
        XCTAssertNil(b, "overwrite must promote the key, evicting 'b'")
    }

    /// Capacity 1: each new insert evicts the previous one.
    func testCapacityOfOneKeepsOnlyLatest() async {
        let cache = CSSPayloadCache(capacity: 1)
        await cache.put("a", payload("a"))
        await cache.put("b", payload("b"))
        let a = await cache.get("a")
        let b = await cache.get("b")
        XCTAssertNil(a)
        XCTAssertNotNil(b)
    }

    /// A zero-or-negative capacity is a caller mistake — clamp to 1 so
    /// the cache still works (never crashes, never holds nothing).
    func testZeroCapacityClampsToOne() async {
        let cache = CSSPayloadCache(capacity: 0)
        await cache.put("a", payload("a"))
        let hit = await cache.get("a")
        XCTAssertNotNil(hit, "capacity clamps to ≥1 so the last put survives")
    }

    // MARK: - Concurrency

    /// Hammering the cache from many concurrent tasks must never crash
    /// or report a count higher than the capacity.
    func testConcurrentAccessDoesNotCrash() async {
        let cache = CSSPayloadCache(capacity: 16)
        await withTaskGroup(of: Void.self) { group in
            for i in 0..<100 {
                group.addTask {
                    await cache.put("k\(i)", self.payload("t\(i)"))
                    _ = await cache.get("k\(i)")
                }
            }
        }
        let count = await cache.count
        XCTAssertLessThanOrEqual(count, 16)
    }
}
