// CSSPayloadCache — actor-isolated LRU cache for CSSPayload.
//
// Apps that fetch CSS over the network typically see the same payload
// (or a close neighbour) multiple times per session: a user navigates
// away from a screen and back, a background refresh arrives, a
// feature-flagged A/B pushes the same CSS to two different screens.
// Re-parsing on every mount is wasteful; this cache lets callers key
// payloads by a version string (a content hash or the server's ETag)
// and fetch them back without touching the parser.
//
// Design notes:
//   • Actor isolation serialises concurrent calls so the internal
//     ordering list stays consistent without ad-hoc locks.
//   • LRU is implemented as an ordered `[String]` (most-recently-used
//     last) + a `[String: CSSPayload]` lookup. O(n) on every hit to
//     reorder — fine for the ~32-entry caches the design doc targets.
//   • `capacity` is clamped to `>= 1` so a caller mistake can't produce
//     a cache that holds nothing.

import Foundation

/// Actor-isolated LRU cache for `CSSPayload`. Keys are caller-chosen
/// version strings (content hashes, ETags, etc.). Hits promote the
/// entry to most-recently-used; overflowing the configured `capacity`
/// evicts the least-recently-used entry.
public actor CSSPayloadCache {

    /// Default capacity — matches the design doc's LRU sizing for
    /// server-driven UI.
    public static let defaultCapacity: Int = 32

    private let capacity: Int
    private var storage: [String: CSSPayload] = [:]
    /// LRU ordering — least-recently-used first, most-recently-used
    /// last. Kept in sync with `storage` on every mutating call.
    private var order: [String] = []

    public init(capacity: Int = CSSPayloadCache.defaultCapacity) {
        // Clamp to ≥ 1 so a caller mistake (`capacity: 0`) still yields
        // a usable one-slot cache rather than a silent no-op.
        self.capacity = max(1, capacity)
    }

    /// Number of entries currently held.
    public var count: Int { storage.count }

    /// Fetch a payload by key. Returns nil on miss. Hits promote the
    /// entry to most-recently-used.
    public func get(_ key: String) -> CSSPayload? {
        guard let payload = storage[key] else { return nil }
        promote(key)
        return payload
    }

    /// Store (or overwrite) a payload for `key`. Overwriting an
    /// existing key preserves `count` and promotes the key to MRU.
    /// Inserting a new key past `capacity` evicts the LRU entry.
    public func put(_ key: String, _ payload: CSSPayload) {
        if storage[key] != nil {
            storage[key] = payload
            promote(key)
            return
        }
        storage[key] = payload
        order.append(key)
        if storage.count > capacity {
            let evicted = order.removeFirst()
            storage.removeValue(forKey: evicted)
        }
    }

    /// Drop every entry.
    public func clear() {
        storage.removeAll()
        order.removeAll()
    }

    // MARK: - Private

    /// Move `key` to the MRU end of the order list. No-op if the key
    /// is already last. Callers must only invoke this for keys they've
    /// already found in `storage`; because `storage` and `order` are
    /// kept in sync, that means `firstIndex(of:)` always has a hit and
    /// a force-unwrap is safe (and keeps the hot path branch-free).
    private func promote(_ key: String) {
        let idx = order.firstIndex(of: key)!
        if idx == order.count - 1 { return }
        order.remove(at: idx)
        order.append(key)
    }
}
