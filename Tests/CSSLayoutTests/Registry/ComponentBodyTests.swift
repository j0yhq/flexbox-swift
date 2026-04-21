import XCTest
import SwiftUI
@testable import CSSLayout

/// Unit 1 — `ComponentBody` wraps a SwiftUI view into the factory-return
/// value the resolver consumes. These tests exercise observable behavior
/// (did the builder closure run? does `makeView` produce a view? does the
/// kind tag report correctly?) — never introspection of the opaque
/// `AnyView`, matching the house style for registry/resolver tests.
final class ComponentBodyTests: XCTestCase {

    // MARK: - .custom

    func testCustomInvokesBuilderOnMakeView() {
        var builderCalls = 0
        let body = ComponentBody.custom { () -> Text in
            builderCalls += 1
            return Text("hi")
        }
        _ = body.makeView()
        XCTAssertEqual(
            builderCalls, 1,
            "custom builder must run exactly once per makeView() call"
        )
    }

    func testCustomIsValueCopyable() {
        // The type is a struct — copying it into a collection must not
        // affect subsequent copies. Here we build two bodies via the same
        // declaration, stash them in an array, and confirm both still
        // invoke their own builders.
        var aCalls = 0
        var bCalls = 0
        let bodies: [ComponentBody] = [
            .custom { () -> Text in aCalls += 1; return Text("a") },
            .custom { () -> Text in bCalls += 1; return Text("b") },
        ]
        _ = bodies[0].makeView()
        _ = bodies[1].makeView()
        XCTAssertEqual(aCalls, 1)
        XCTAssertEqual(bCalls, 1)
    }

    func testKindTagForCustom() {
        let body = ComponentBody.custom { Text("x") }
        XCTAssertEqual(body.kind, .custom)
    }
}
