// UiAction — JSON-serializable event-handler descriptor borrowed from
// `react-dom-example.ts` in joyfill/.joy#33.
//
// The canonical `spec.ts` doesn't include this token (it documents
// it only in a sibling reference file), but the iOS port carries an
// optional decoder so apps that *do* serialize event handlers in
// joy-dom payloads can light up factories without a separate
// transport. If Josh promotes UiAction into spec.ts later, this code
// stays valid; if he never does, hosts who don't use it pay nothing.
//
// Format:
//   { "action": "submit", "args": ["form-1", "validate"] }
//
// JoyDOMView's prop bag (`SchemaEntry.props`) is a `[String: String]`
// dictionary. The bridge is JSON-string-in, struct-out: callers store
// `UiAction.encodedString()` under whatever prop key they choose
// (e.g. `"onClick"`), and factories read it via
// `ComponentProps.action(_:)` which parses the JSON back into the
// struct. This keeps the prop bag's existing string-only contract and
// avoids invasive changes to ComponentProps internals.

import Foundation

/// JSON-serializable representation of an event-handler invocation.
///
/// Round-trips through `Codable`; encode with the canonical wire
/// shape `{ "action": "<name>", "args": [...] }` matching joyfill's
/// `react-dom-example.ts`.
public struct UiAction: Equatable, Codable {

    /// Action identifier — host-defined. Common conventions include
    /// `"submit"`, `"alert"`, `"navigate"`, `"emit"`. The renderer
    /// looks the name up in its own action registry to decide what
    /// happens at invocation time.
    public var action: String

    /// Optional positional arguments. Encoded as JSON-safe strings
    /// (joyfill's spec uses `JsonValue[]`; the iOS port narrows to
    /// `[String]` because every value SchemaEntry.props can carry is
    /// already a string at the wire layer).
    public var args: [String]

    public init(action: String, args: [String] = []) {
        self.action = action
        self.args = args
    }

    /// Encode this action as the JSON string apps store under a
    /// `SchemaEntry.props` key. Returns `nil` only if encoding fails
    /// (which is impossible for the current shape but kept optional
    /// to keep the API resilient if `args` ever takes richer types).
    public func encodedString() -> String? {
        guard let data = try? JSONEncoder().encode(self) else { return nil }
        return String(data: data, encoding: .utf8)
    }

    /// Decode a UiAction from the JSON string stored in a prop slot.
    /// Returns `nil` for non-action values (plain strings, malformed
    /// JSON, JSON without an `action` key) so factories can attempt
    /// the parse cheaply on every prop access.
    public static func decode(_ string: String) -> UiAction? {
        guard let data = string.data(using: .utf8) else { return nil }
        return try? JSONDecoder().decode(UiAction.self, from: data)
    }
}

// MARK: - ComponentProps typed accessor

extension ComponentProps {

    /// Read the prop at `key` as a `UiAction`. Returns `nil` if the
    /// key isn't set or the value isn't a JSON-encoded UiAction.
    ///
    /// Pairs with `UiAction.encodedString()` on the producer side —
    /// authoring tools / converters write the JSON string into
    /// `SchemaEntry.props` and factories consume it as a struct.
    public func action(_ key: String) -> UiAction? {
        guard let raw = string(key) else { return nil }
        return UiAction.decode(raw)
    }
}
