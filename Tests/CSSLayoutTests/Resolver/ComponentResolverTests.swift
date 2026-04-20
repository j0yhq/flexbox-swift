import XCTest
import SwiftUI
@testable import CSSLayout
import FlexLayout

/// Unit (k) — `ComponentResolver` picks the right view source per node.
///
/// Priority per node: `locals[id]` > `registry[schema[id].type]` > placeholder.
/// Tests assert on the emitted `Resolution` tag and the id stream, never on
/// actual SwiftUI view identity (which is opaque).
final class ComponentResolverTests: XCTestCase {

    // MARK: - Fixtures

    private func styleNode(id: String, schemaType: String? = nil) -> StyleNode {
        StyleNode(id: id, schemaType: schemaType, computedStyle: ComputedStyle())
    }

    private func rootNode() -> StyleNode {
        StyleNode(id: "root", schemaType: nil, computedStyle: ComputedStyle())
    }

    private func resolve(
        nodes: [StyleNode],
        locals: [Component] = [],
        registry: ComponentRegistry = ComponentRegistry()
    ) -> (result: ComponentResolver.Resolved, diagnostics: CSSDiagnostics) {
        var diags = CSSDiagnostics()
        let result = ComponentResolver.resolve(
            nodes: nodes,
            locals: locals,
            registry: registry,
            placeholder: { _ in AnyView(EmptyView()) },
            diagnostics: &diags
        )
        return (result, diags)
    }

    // MARK: - Structure

    func testRootIsFirstNodeAndChildrenFollow() {
        let (res, _) = resolve(nodes: [
            rootNode(),
            styleNode(id: "a"),
            styleNode(id: "b"),
        ])
        XCTAssertEqual(res.children.map(\.id), ["a", "b"])
    }

    func testEmptySchemaProducesNoChildren() {
        let (res, _) = resolve(nodes: [rootNode()])
        XCTAssertEqual(res.children.count, 0)
    }

    // MARK: - Priority

    func testLocalComponentWinsOverRegistry() {
        let registry = ComponentRegistry()
            .register("button") { _, _ in AnyView(Text("registry")) }
        let locals = [Component("submit") { Text("local") }]
        let (res, _) = resolve(
            nodes: [rootNode(), styleNode(id: "submit", schemaType: "button")],
            locals: locals,
            registry: registry
        )
        XCTAssertEqual(res.children.first?.resolution, .local)
    }

    func testFallsBackToRegistry() {
        let registry = ComponentRegistry()
            .register("button") { _, _ in AnyView(Text("registry")) }
        let (res, _) = resolve(
            nodes: [rootNode(), styleNode(id: "submit", schemaType: "button")],
            registry: registry
        )
        XCTAssertEqual(res.children.first?.resolution, .registry)
    }

    func testUnknownIDFiresPlaceholder() {
        // No locals, no schemaType — nothing can match → placeholder.
        let (res, _) = resolve(
            nodes: [rootNode(), styleNode(id: "mystery")]
        )
        XCTAssertEqual(res.children.first?.resolution, .placeholder)
    }

    func testUnregisteredSchemaTypeFiresPlaceholderPlusDiagnostic() {
        // schemaType is set but the registry doesn't know it. We still fall
        // back to placeholder AND emit a diagnostic so the caller can catch
        // typos at runtime.
        let (res, diags) = resolve(
            nodes: [rootNode(), styleNode(id: "x", schemaType: "widget")]
        )
        XCTAssertEqual(res.children.first?.resolution, .placeholder)
        XCTAssertEqual(diags.count(of: .other), 1)
        XCTAssertTrue(diags.warnings.contains {
            if case .other = $0.kind { return $0.detail.contains("widget") }
            return false
        })
    }

    // MARK: - Root style propagation

    func testRootStyleIsReturned() {
        var rootStyle = ComputedStyle()
        rootStyle.container.direction = .column
        rootStyle.container.gap = 16
        let (res, _) = resolve(
            nodes: [
                StyleNode(id: "root", schemaType: nil, computedStyle: rootStyle),
                styleNode(id: "a"),
            ]
        )
        XCTAssertEqual(res.rootStyle.container.direction, .column)
        XCTAssertEqual(res.rootStyle.container.gap, 16)
    }

    // MARK: - Item-style forwarding

    func testChildrenCarryTheirComputedItemStyle() {
        var aStyle = ComputedStyle()
        aStyle.item.grow = 2
        let (res, _) = resolve(
            nodes: [
                rootNode(),
                StyleNode(id: "a", schemaType: nil, computedStyle: aStyle),
            ]
        )
        XCTAssertEqual(res.children.first?.itemStyle.grow, 2)
    }
}
