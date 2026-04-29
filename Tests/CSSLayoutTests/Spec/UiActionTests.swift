import XCTest
@testable import CSSLayout

/// Unit 10 — `UiAction` is the JSON-serializable event-handler
/// descriptor referenced in joyfill/.joy's `react-dom-example.ts`.
/// CSSLayout encodes one as a JSON string in a `SchemaEntry.props`
/// slot and decodes it back via `ComponentProps.action(_:)`.
final class UiActionTests: XCTestCase {

    // MARK: - Codable round-trip

    func testEncodeDecodeRoundTrip() throws {
        let action = UiAction(action: "submit", args: ["form-1", "validate"])
        let json = try JSONEncoder().encode(action)
        let decoded = try JSONDecoder().decode(UiAction.self, from: json)
        XCTAssertEqual(decoded, action)
    }

    func testCanonicalWireFormat() throws {
        let action = UiAction(action: "alert", args: ["Hello"])
        let json = try JSONEncoder().encode(action)
        let object = try JSONSerialization.jsonObject(with: json) as? [String: Any]
        XCTAssertEqual(object?["action"] as? String, "alert")
        XCTAssertEqual(object?["args"] as? [String], ["Hello"])
    }

    func testEmptyArgsArrayRoundTrips() throws {
        let action = UiAction(action: "noop")
        let json = try JSONEncoder().encode(action)
        let decoded = try JSONDecoder().decode(UiAction.self, from: json)
        XCTAssertEqual(decoded, action)
        XCTAssertEqual(decoded.args, [])
    }

    // MARK: - encodedString / decode helpers

    func testEncodedStringProducesParseableJSON() {
        let action = UiAction(action: "submit", args: ["a", "b"])
        let encoded = action.encodedString()
        XCTAssertNotNil(encoded)
        XCTAssertNotNil(encoded.flatMap(UiAction.decode))
        XCTAssertEqual(UiAction.decode(encoded!), action)
    }

    func testDecodeOfPlainStringReturnsNil() {
        XCTAssertNil(UiAction.decode("submit"))
    }

    func testDecodeOfMalformedJSONReturnsNil() {
        XCTAssertNil(UiAction.decode("{not valid json"))
        XCTAssertNil(UiAction.decode(""))
    }

    func testDecodeOfJSONWithoutActionKeyReturnsNil() {
        XCTAssertNil(UiAction.decode(#"{"args":["x"]}"#))
    }

    // MARK: - ComponentProps.action(_:)

    func testActionAccessorReturnsNilWhenKeyMissing() {
        let props = ComponentProps([:])
        XCTAssertNil(props.action("onClick"))
    }

    func testActionAccessorReturnsNilWhenValueIsPlainString() {
        let props = ComponentProps(["onClick": "submit"])
        XCTAssertNil(props.action("onClick"),
                     "plain string is not a UiAction; expect nil")
    }

    func testActionAccessorReturnsActionWhenValueIsEncodedJSON() {
        let action = UiAction(action: "submit", args: ["form-1"])
        let encoded = action.encodedString()!
        let props = ComponentProps(["onClick": encoded])
        XCTAssertEqual(props.action("onClick"), action)
    }

    func testActionAccessorReturnsNilForMalformedJSON() {
        let props = ComponentProps(["onClick": "{nope"])
        XCTAssertNil(props.action("onClick"))
    }

    func testActionAccessorIsIndependentPerKey() {
        let action = UiAction(action: "alert", args: ["hi"])
        let props = ComponentProps([
            "onClick":  action.encodedString()!,
            "label":    "Click me",
        ])
        XCTAssertEqual(props.action("onClick"), action)
        XCTAssertNil(props.action("label"),
                     "label is a plain string, not a UiAction")
    }
}
