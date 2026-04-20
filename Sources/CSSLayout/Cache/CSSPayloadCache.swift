// CSSPayloadCache — Phase 3 Unit 5 skeleton.
//
// Will become an actor-isolated LRU for CSSPayload. The red commit ships
// the public API surface so the test suite compiles; the next commit
// turns on LRU + eviction semantics.

import Foundation

/// Actor-isolated LRU cache for `CSSPayload`. Keys are caller-chosen
/// version strings (content hashes, ETags, etc.). Hits promote the entry
/// to most-recently-used; overflowing the configured `capacity` evicts
/// the least-recently-used entry.
public actor CSSPayloadCache {

    /// Default capacity — matches the design doc's LRU sizing.
    public static let defaultCapacity: Int = 32

    public init(capacity: Int = CSSPayloadCache.defaultCapacity) {
        _ = capacity
    }

    /// Number of entries currently held.
    public var count: Int { 0 }

    /// Fetch a payload by key. Returns nil on miss.
    public func get(_ key: String) -> CSSPayload? { nil }

    /// Store (or overwrite) a payload for `key`.
    public func put(_ key: String, _ payload: CSSPayload) {
        _ = (key, payload)
    }

    /// Drop every entry.
    public func clear() {}
}
