import XCTest
@testable import JoyDOM

/// Defensive guard: every sample in the paste demo's dropdown must
/// decode cleanly into a `JoyDOMSpec`. Future additions can't slip in
/// missing required keys (`style`, `breakpoints`, etc.) without
/// failing this suite.
///
/// This is intentionally a smoke check — we trust the per-shape
/// Codable tests for wire-format correctness; this just runs every
/// sample end-to-end through the decoder so a typo in one entry
/// doesn't ship past CI.
///
/// The samples themselves live in `FlexDemoApp/JoyDOMSamples.swift`,
/// which the test target can't import directly (different target).
/// We embed them here verbatim and assert each one decodes. If a
/// sample changes, the embedded copy needs to follow — small price
/// for the regression net.
final class JoyDOMSamplesIntegrityTests: XCTestCase {

    private func assertDecodes(
        _ json: String,
        label: String,
        file: StaticString = #file,
        line: UInt = #line
    ) {
        let data = Data(json.utf8)
        do {
            let spec = try JSONDecoder().decode(JoyDOMSpec.self, from: data)
            XCTAssertEqual(spec.version, 1, "\(label): version must be 1",
                           file: file, line: line)
        } catch {
            XCTFail("\(label) failed to decode: \(error)", file: file, line: line)
        }
    }

    // MARK: - Hello world

    func testHelloWorldDecodes() {
        assertDecodes(#"""
        {
          "version": 1,
          "style": {},
          "breakpoints": [],
          "layout": {
            "type": "p",
            "props": { "id": "greeting" },
            "children": ["Hello, joy-dom!"]
          }
        }
        """#, label: "hello-world")
    }

    // MARK: - Three cards

    func testThreeCardsDecodes() {
        assertDecodes(#"""
        {
          "version": 1,
          "style": {
            "#root": {
              "flexDirection": "column",
              "gap": { "value": 12, "unit": "px" },
              "padding": { "value": 16, "unit": "px" }
            },
            "#row": {
              "flexDirection": "column",
              "gap": { "value": 12, "unit": "px" }
            },
            "#a, #b, #c": {
              "flexGrow": 1,
              "height": { "value": 80, "unit": "px" }
            }
          },
          "breakpoints": [
            {
              "conditions": [
                { "type": "feature", "name": "width", "operator": ">=", "value": 768, "unit": "px" }
              ],
              "nodes": {},
              "style": {
                "#row": {
                  "flexDirection": "row",
                  "gap": { "value": 16, "unit": "px" }
                }
              }
            }
          ],
          "layout": {
            "type": "div",
            "props": { "id": "root" },
            "children": [
              { "type": "p", "props": { "id": "title" }, "children": ["Hello"] },
              {
                "type": "div",
                "props": { "id": "row" },
                "children": [
                  { "type": "card", "props": { "id": "a", "label": "A" } },
                  { "type": "card", "props": { "id": "b", "label": "B" } },
                  { "type": "card", "props": { "id": "c", "label": "C" } }
                ]
              }
            ]
          }
        }
        """#, label: "three-cards")
    }

    // MARK: - Signup form

    func testSignupFormDecodes() {
        assertDecodes(#"""
        {
          "version": 1,
          "style": {
            "#root": { "flexDirection": "column", "gap": { "value": 12, "unit": "px" } },
            "#row":  { "flexDirection": "column", "gap": { "value": 12, "unit": "px" } }
          },
          "breakpoints": [
            {
              "conditions": [
                { "type": "feature", "name": "width", "operator": ">=", "value": 768, "unit": "px" }
              ],
              "nodes": {},
              "style": { "#row": { "flexDirection": "row" } }
            }
          ],
          "layout": {
            "type": "div",
            "props": { "id": "root" },
            "children": [
              { "type": "p", "props": { "id": "title" }, "children": ["Sign up"] },
              {
                "type": "div",
                "props": { "id": "row" },
                "children": [
                  { "type": "input", "props": { "id": "name", "placeholder": "Name" } },
                  { "type": "input", "props": { "id": "email", "placeholder": "Email" } }
                ]
              },
              { "type": "button", "props": { "id": "submit", "label": "Submit", "event": "submit" } }
            ]
          }
        }
        """#, label: "signup-form")
    }

    // MARK: - Article

    func testArticleDecodes() {
        assertDecodes(#"""
        {
          "version": 1,
          "style": {
            "#article": { "flexDirection": "column", "gap": { "value": 12, "unit": "px" } },
            "#title":   { "height": { "value": 36, "unit": "px" } }
          },
          "breakpoints": [],
          "layout": {
            "type": "div",
            "props": { "id": "article" },
            "children": [
              { "type": "p", "props": { "id": "title" }, "children": ["Title"] },
              { "type": "p", "children": ["Body paragraph one."] },
              { "type": "p", "children": ["Body paragraph two."] }
            ]
          }
        }
        """#, label: "article")
    }

    // MARK: - Pricing tiers

    func testPricingTiersDecodes() {
        assertDecodes(#"""
        {
          "version": 1,
          "style": {
            "#root":  { "flexDirection": "column", "gap": { "value": 16, "unit": "px" } },
            "#tiers": { "flexDirection": "column", "gap": { "value": 12, "unit": "px" } }
          },
          "breakpoints": [
            {
              "conditions": [
                { "type": "feature", "name": "width", "operator": ">=", "value": 768, "unit": "px" }
              ],
              "nodes": {},
              "style": { "#tiers": { "flexDirection": "row" } }
            }
          ],
          "layout": {
            "type": "div",
            "props": { "id": "root" },
            "children": [
              { "type": "p", "props": { "id": "heading" }, "children": ["Plans"] },
              {
                "type": "div",
                "props": { "id": "tiers" },
                "children": [
                  { "type": "card", "props": { "id": "tier-free",  "label": "Free" } },
                  { "type": "card", "props": { "id": "tier-pro",   "label": "Pro" } },
                  { "type": "card", "props": { "id": "tier-team",  "label": "Team" } }
                ]
              }
            ]
          }
        }
        """#, label: "pricing-tiers")
    }

    // MARK: - Required-key sanity

    /// A `JoyDOMSpec` JSON missing `style` or `breakpoints` must throw —
    /// pinning the contract every sample has to honor.
    func testMissingStyleFailsToDecode() {
        let bad = #"""
        {
          "version": 1,
          "breakpoints": [],
          "layout": { "type": "div" }
        }
        """#
        XCTAssertThrowsError(
            try JSONDecoder().decode(JoyDOMSpec.self, from: Data(bad.utf8))
        )
    }

    func testMissingBreakpointsFailsToDecode() {
        let bad = #"""
        {
          "version": 1,
          "style": {},
          "layout": { "type": "div" }
        }
        """#
        XCTAssertThrowsError(
            try JSONDecoder().decode(JoyDOMSpec.self, from: Data(bad.utf8))
        )
    }
}
