import XCTest
import SwiftUI
@testable import JoyDOM

/// Unit (j) — `Component` and `JoyDOMComponentBuilder`.
///
/// The result builder converts a trailing-closure of `Component(...)` calls
/// into the `[Component]` array consumed by the `JoyDOMView` view. These
/// tests assert on the array shape, not on the rendered views.
final class CSSLayoutBuilderTests: XCTestCase {

    // MARK: - Component

    func testComponentIDIsPreserved() {
        let c = Component("submit") { EmptyView() }
        XCTAssertEqual(c.id, "submit")
    }

    // MARK: - Builder — sequential blocks

    func testBuildsSingleComponent() {
        let components: [Component] = buildComponents {
            Component("a") { EmptyView() }
        }
        XCTAssertEqual(components.map(\.id), ["a"])
    }

    func testBuildsMultipleComponents() {
        let components: [Component] = buildComponents {
            Component("a") { EmptyView() }
            Component("b") { EmptyView() }
            Component("c") { EmptyView() }
        }
        XCTAssertEqual(components.map(\.id), ["a", "b", "c"])
    }

    func testBuildsEmptyBlock() {
        let components: [Component] = buildComponents {}
        XCTAssertEqual(components.count, 0)
    }

    // MARK: - Builder — conditionals

    func testBuildOptionalYieldsEmptyWhenNil() {
        let flag = false
        let components: [Component] = buildComponents {
            Component("always") { EmptyView() }
            if flag {
                Component("maybe") { EmptyView() }
            }
        }
        XCTAssertEqual(components.map(\.id), ["always"])
    }

    func testBuildOptionalYieldsComponentWhenPresent() {
        let flag = true
        let components: [Component] = buildComponents {
            Component("always") { EmptyView() }
            if flag {
                Component("maybe") { EmptyView() }
            }
        }
        XCTAssertEqual(components.map(\.id), ["always", "maybe"])
    }

    func testBuildEitherFirstBranch() {
        let components: [Component] = buildComponents {
            if true {
                Component("first") { EmptyView() }
            } else {
                Component("second") { EmptyView() }
            }
        }
        XCTAssertEqual(components.map(\.id), ["first"])
    }

    func testBuildEitherSecondBranch() {
        let components: [Component] = buildComponents {
            if false {
                Component("first") { EmptyView() }
            } else {
                Component("second") { EmptyView() }
            }
        }
        XCTAssertEqual(components.map(\.id), ["second"])
    }

    // MARK: - Helper

    /// Invokes the result builder under test. Wraps the annotation so tests
    /// stay focused on input/output shape.
    private func buildComponents(
        @JoyDOMComponentBuilder _ body: () -> [Component]
    ) -> [Component] {
        body()
    }
}
