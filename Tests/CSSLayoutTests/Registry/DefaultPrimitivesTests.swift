import XCTest
import SwiftUI
@testable import CSSLayout

/// Unit 9 — `ComponentRegistry.withDefaultPrimitives()` registers
/// factories for joy-dom's built-in primitives so apps don't have to
/// reimplement `div` / `p` / `primitive_*` for every screen.
///
/// We can't introspect the SwiftUI views the factories produce, so the
/// tests assert what's observable: registration presence, fluent
/// chaining, last-wins precedence with user factories, and that the
/// factories survive invocation without trapping.
final class DefaultPrimitivesTests: XCTestCase {

    // MARK: - All primitive types are registered

    func testWithDefaultPrimitivesRegistersDivAndP() {
        let r = ComponentRegistry().withDefaultPrimitives()
        XCTAssertNotNil(r.factory(for: "div"))
        XCTAssertNotNil(r.factory(for: "p"))
    }

    func testWithDefaultPrimitivesRegistersAllThreePrimitiveTypes() {
        let r = ComponentRegistry().withDefaultPrimitives()
        XCTAssertNotNil(r.factory(for: "primitive_string"))
        XCTAssertNotNil(r.factory(for: "primitive_number"))
        XCTAssertNotNil(r.factory(for: "primitive_null"))
    }

    // MARK: - Fluent chaining

    func testReturnsSameInstanceForChaining() {
        let registry = ComponentRegistry()
        let returned = registry.withDefaultPrimitives()
        XCTAssertTrue(returned === registry)
    }

    // MARK: - User factories take precedence

    func testUserFactoryRegisteredBeforeDefaultsIsPreserved() {
        // The helper fills empty slots only — a pre-registered
        // factory for `div` must survive the call.
        let r = ComponentRegistry()
        var marker = 0
        r.register("div") { _, _ in
            marker = 42
            return .custom { EmptyView() }
        }
        _ = r.withDefaultPrimitives()
        _ = r.factory(for: "div")?(ComponentProps([:]), ComponentEvents())
        XCTAssertEqual(marker, 42, "user-registered div factory must win")
    }

    func testUserFactoryRegisteredAfterDefaultsOverrides() {
        // Standard last-wins behavior of `ComponentRegistry.register`
        // still applies — calling register after the helper replaces
        // the default.
        let r = ComponentRegistry().withDefaultPrimitives()
        var marker = 0
        r.register("div") { _, _ in
            marker = 77
            return .custom { EmptyView() }
        }
        _ = r.factory(for: "div")?(ComponentProps([:]), ComponentEvents())
        XCTAssertEqual(marker, 77, "register after defaults must override")
    }

    // MARK: - Factory invocation does not trap

    func testEachDefaultFactoryInvokesWithoutCrash() {
        let r = ComponentRegistry().withDefaultPrimitives()
        let types = ["div", "p", "primitive_string", "primitive_number", "primitive_null"]
        for type in types {
            let body = r.factory(for: type)?(
                ComponentProps(["value": "sample"]),
                ComponentEvents()
            )
            XCTAssertNotNil(body, "factory for '\(type)' must produce a body")
        }
    }

    // MARK: - Doesn't pollute unrelated registry slots

    func testHelperDoesNotRegisterUnrelatedTypes() {
        let r = ComponentRegistry().withDefaultPrimitives()
        XCTAssertNil(r.factory(for: "button"),
                     "helper should not register types it doesn't own")
        XCTAssertNil(r.factory(for: "text-field"))
    }

    // MARK: - Idempotent

    func testCallingHelperTwiceIsHarmless() {
        let r = ComponentRegistry()
            .withDefaultPrimitives()
            .withDefaultPrimitives()
        XCTAssertNotNil(r.factory(for: "div"))
        XCTAssertNotNil(r.factory(for: "p"))
    }
}
