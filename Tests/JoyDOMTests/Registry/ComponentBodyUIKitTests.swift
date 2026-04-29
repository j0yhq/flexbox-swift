#if canImport(UIKit) && !os(watchOS)

import XCTest
import SwiftUI
import UIKit
@testable import JoyDOM

/// Unit 5 — `ComponentBody.uiKit(make:update:)` lifts a UIKit view into
/// the JoyDOMView pipeline.
///
/// Tests drive the stored closures through the package-internal
/// `_invokeMake` / `_invokeUpdate` helpers so we don't have to run
/// SwiftUI's `UIViewRepresentable` lifecycle to exercise the bridge.
/// That lifecycle is covered by the demo smoke checklist in Unit 8.
final class ComponentBodyUIKitTests: XCTestCase {

    func testUIKitStoresMakeAndUpdateClosures() {
        var makeCalls = 0
        var updateCalls = 0
        let body = ComponentBody.uiKit(
            make: { () -> UILabel in
                makeCalls += 1
                return UILabel()
            },
            update: { _ in updateCalls += 1 }
        )

        let produced = body._invokeMake()
        XCTAssertNotNil(produced, "_invokeMake must return the view built by make")
        XCTAssertEqual(makeCalls, 1)
        XCTAssertTrue(produced is UILabel)

        body._invokeUpdate(produced ?? UIView())
        XCTAssertEqual(updateCalls, 1, "_invokeUpdate must invoke the stored update closure")
    }

    func testUIKitMakeViewReturnsAnyView() {
        let body = ComponentBody.uiKit(make: { UIView() })
        // Construction smoke only — the test house style never
        // introspects `AnyView`, so asserting its shape is out of
        // scope.
        _ = body.makeView()
    }

    func testUIKitKindTag() {
        let body = ComponentBody.uiKit(make: { UIView() })
        XCTAssertEqual(body.kind, .uiKit)
    }
}

#endif
