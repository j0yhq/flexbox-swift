import Foundation
import CoreGraphics
import SwiftUI
import FlexLayout
@testable import CSSLayout

/// Chrome-parity fixture runner.
///
/// Each fixture is a paired `<name>.css` / `<name>.json` in
/// `Tests/CSSLayoutTests/Fixtures/` and describes:
///
///   • A container size (W × H).
///   • Zero-or-more child IDs plus their expected frames (x, y, w, h).
///
/// The runner parses the CSS with the real CSSLayout pipeline
/// (`CSSParser` → `StyleTreeBuilder`), translates every child's
/// `ComputedStyle` into a `FlexItemInput`, and then solves with
/// `FlexEngine.solve`. Frames are compared to the expected values
/// with a half-point tolerance, matching FlexLayout's own tests.
///
/// Why bypass SwiftUI rendering: SwiftUI hosts are opaque, slow, and
/// platform-specific. FlexLayout's engine *is* the layout contract we
/// ship — testing against it gives deterministic, fast assertions that
/// still exercise every line of CSS parsing, cascading, and style
/// lowering we own.
enum FixtureRunner {

    /// Tolerance used when comparing frames — matches FlexGeometryTests.
    static let ε: CGFloat = 0.5

    // MARK: - JSON model

    struct Fixture: Decodable {
        let container: [CGFloat]          // [width, height]
        let expected: [ExpectedChild]

        var containerSize: CGSize { CGSize(width: container[0], height: container[1]) }
    }

    struct ExpectedChild: Decodable {
        let id: String
        let frame: [CGFloat]              // [x, y, w, h]

        var rect: CGRect {
            CGRect(x: frame[0], y: frame[1], width: frame[2], height: frame[3])
        }
    }

    // MARK: - Loading

    /// Returns every fixture name discovered under `Fixtures/` in the
    /// test bundle. A fixture is counted once per CSS file.
    static func discoverNames() -> [String] {
        guard let resourceURL = Bundle.module.resourceURL else { return [] }
        // Resources are copied under `Fixtures/` preserving structure.
        let fixturesDir = resourceURL.appendingPathComponent("Fixtures", isDirectory: true)
        guard let urls = try? FileManager.default.contentsOfDirectory(
            at: fixturesDir,
            includingPropertiesForKeys: nil
        ) else { return [] }
        return urls
            .filter { $0.pathExtension == "css" }
            .map { $0.deletingPathExtension().lastPathComponent }
            .sorted()
    }

    // MARK: - Running

    /// Runs one named fixture and returns `(actual, expected)` rectangle
    /// pairs in ID order, plus any warnings the parse pipeline emitted.
    static func run(_ name: String) throws -> (
        ids: [String],
        actual: [CGRect],
        expected: [CGRect],
        warnings: [CSSWarning]
    ) {
        let (css, fixture) = try load(name)

        // Mimic CSSLayout's internal pipeline without going through
        // SwiftUI rendering.
        var diagnostics = CSSDiagnostics()
        let stylesheet = CSSParser.parse(css, diagnostics: &diagnostics)
        let schema = fixture.expected.map { SchemaEntry(id: $0.id) }
        let nodes = StyleTreeBuilder.build(
            rootID: "root",
            schema: schema,
            stylesheet: stylesheet,
            diagnostics: &diagnostics
        )

        let root     = nodes.first!.computedStyle
        let children = Array(nodes.dropFirst())

        let inputs: [FlexItemInput] = children.map { node in
            makeInput(from: node.computedStyle.item)
        }

        let frames = FlexEngine.solve(
            config:   root.container,
            inputs:   inputs,
            proposal: ProposedViewSize(
                width:  fixture.containerSize.width,
                height: fixture.containerSize.height
            )
        ).frames

        return (
            ids:      children.map(\.id),
            actual:   frames,
            expected: fixture.expected.map(\.rect),
            warnings: diagnostics.warnings
        )
    }

    // MARK: - Helpers

    /// Translates an `ItemStyle` into a `FlexItemInput` with a greedy
    /// measure closure (returns the proposed size).
    ///
    /// The greedy measure lets `align-items: stretch` behave like a real
    /// SwiftUI view accepting any cross-axis size, while explicit
    /// `width`/`height`/`basis` still take precedence inside the engine.
    private static func makeInput(from style: ItemStyle) -> FlexItemInput {
        FlexItemInput(
            measure: { proposal in
                CGSize(width:  proposal.width  ?? 0,
                       height: proposal.height ?? 0)
            },
            grow:           style.grow,
            shrink:         style.shrink,
            basis:          style.basis,
            alignSelf:      style.alignSelf,
            order:          style.order,
            zIndex:         style.zIndex,
            position:       style.position,
            explicitWidth:  style.width,
            explicitHeight: style.height,
            top:            style.top,
            bottom:         style.bottom,
            leading:        style.leading,
            trailing:       style.trailing
        )
    }

    private static func load(_ name: String) throws -> (css: String, fixture: Fixture) {
        let cssURL  = try resourceURL(name: name, extension: "css")
        let jsonURL = try resourceURL(name: name, extension: "json")
        let css  = try String(contentsOf: cssURL, encoding: .utf8)
        let json = try Data(contentsOf: jsonURL)
        let fixture = try JSONDecoder().decode(Fixture.self, from: json)
        return (css, fixture)
    }

    private static func resourceURL(name: String, extension ext: String) throws -> URL {
        if let url = Bundle.module.url(
            forResource: name,
            withExtension: ext,
            subdirectory: "Fixtures"
        ) {
            return url
        }
        throw FixtureError.resourceMissing("\(name).\(ext)")
    }

    enum FixtureError: Error, CustomStringConvertible {
        case resourceMissing(String)
        var description: String {
            switch self {
            case .resourceMissing(let name): return "fixture resource missing: \(name)"
            }
        }
    }
}
