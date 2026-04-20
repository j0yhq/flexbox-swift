import XCTest
import CoreGraphics
@testable import CSSLayout

/// Chrome-parity fixture suite — exercises the full CSSLayout pipeline
/// (parse → cascade → flex solve) against hand-authored expected frames.
///
/// Each `.css` under `Fixtures/` is paired with a same-named `.json`
/// describing the container size and expected child rectangles. The
/// runner iterates every discovered fixture and reports each one as a
/// separate `XCTContext.runActivity` so failures surface with the
/// fixture they belong to. New fixtures are picked up automatically by
/// dropping the two files into `Fixtures/`.
final class FixtureTests: XCTestCase {

    /// Ensures at least the Phase-1 floor of fixtures has been authored
    /// and that bundle resources resolve. Catches broken SPM wiring
    /// long before per-fixture assertions run.
    func testAtLeastFifteenFixturesDiscovered() {
        let names = FixtureRunner.discoverNames()
        XCTAssertGreaterThanOrEqual(
            names.count, 15,
            "expected ≥15 Chrome-parity fixtures, found \(names.count): \(names)"
        )
    }

    /// Runs every fixture. Each fixture is wrapped in `runActivity` so
    /// Xcode's test report shows one row per `.css` file with its own
    /// assertion log — failures don't short-circuit siblings.
    func testAllFixtures() throws {
        let names = FixtureRunner.discoverNames()
        XCTAssertFalse(names.isEmpty, "no fixtures discovered under Fixtures/")
        for name in names {
            XCTContext.runActivity(named: "fixture: \(name)") { _ in
                do {
                    try assertFixture(name)
                } catch {
                    XCTFail("[\(name)] \(error)")
                }
            }
        }
    }

    // MARK: - Per-fixture assertion

    private func assertFixture(_ name: String) throws {
        let result = try FixtureRunner.run(name)

        XCTAssertEqual(
            result.actual.count, result.expected.count,
            "[\(name)] frame count mismatch"
        )
        for (i, id) in result.ids.enumerated()
        where i < result.actual.count && i < result.expected.count {
            let a = result.actual[i]
            let e = result.expected[i]
            let close = abs(a.minX   - e.minX)   < FixtureRunner.ε &&
                        abs(a.minY   - e.minY)   < FixtureRunner.ε &&
                        abs(a.width  - e.width)  < FixtureRunner.ε &&
                        abs(a.height - e.height) < FixtureRunner.ε
            XCTAssert(
                close,
                "[\(name)] id=\(id) expected \(e) got \(a)"
            )
        }
    }
}
