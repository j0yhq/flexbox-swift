// JoyDOMSamples — curated joy-dom payloads for the paste demo's
// dropdown. Each sample is a complete, valid `JoyDOMSpec` JSON
// document so picking one drops you straight into a working render.
//
// Ordered roughly by complexity: Hello world (minimal) → cards
// (responsive) → signup (FormState territory) → article (primitive
// content) → pricing (multi-card responsive grid).
//
// Adding a new sample: append a `JoyDOMSample` to `JoyDOMSamples.all`
// and the dropdown picks it up automatically.

import Foundation

struct JoyDOMSample: Identifiable, Hashable {
    let id: String
    let label: String
    let json: String
}

enum JoyDOMSamples {

    static let all: [JoyDOMSample] = [
        helloWorld,
        threeCards,
        signupForm,
        article,
        pricingTiers,
    ]

    /// Default selection on first open. Matches the demo's prior
    /// hard-coded sample so the initial UI is unchanged.
    static let defaultID = threeCards.id

    static func sample(withID id: String) -> JoyDOMSample? {
        all.first(where: { $0.id == id })
    }

    // MARK: - Sample 1 — Hello world

    private static let helloWorld = JoyDOMSample(
        id: "hello",
        label: "Hello world",
        json: #"""
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
        """#
    )

    // MARK: - Sample 2 — Three cards (responsive)

    private static let threeCards = JoyDOMSample(
        id: "cards",
        label: "Three cards · responsive",
        json: #"""
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
              {
                "type": "p",
                "props": { "id": "title" },
                "children": ["Hello, joy-dom!"]
              },
              {
                "type": "div",
                "props": { "id": "row" },
                "children": [
                  { "type": "card", "props": { "id": "a", "label": "Card A" } },
                  { "type": "card", "props": { "id": "b", "label": "Card B" } },
                  { "type": "card", "props": { "id": "c", "label": "Card C" } }
                ]
              },
              {
                "type": "button",
                "props": { "id": "submit", "label": "Submit", "event": "submit" }
              }
            ]
          }
        }
        """#
    )

    // MARK: - Sample 3 — Signup form

    private static let signupForm = JoyDOMSample(
        id: "signup",
        label: "Signup form · inputs + submit",
        json: #"""
        {
          "version": 1,
          "style": {
            "#root": {
              "flexDirection": "column",
              "gap": { "value": 12, "unit": "px" },
              "padding": { "value": 24, "unit": "px" }
            },
            "#row": {
              "flexDirection": "column",
              "gap": { "value": 12, "unit": "px" }
            },
            "#name, #email": {
              "flexGrow": 1,
              "height": { "value": 38, "unit": "px" }
            },
            "#submit": { "height": { "value": 40, "unit": "px" } }
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
              {
                "type": "p",
                "props": { "id": "title" },
                "children": ["Create your account"]
              },
              {
                "type": "div",
                "props": { "id": "row" },
                "children": [
                  {
                    "type": "input",
                    "props": { "id": "name", "placeholder": "Full name" }
                  },
                  {
                    "type": "input",
                    "props": { "id": "email", "placeholder": "Email address" }
                  }
                ]
              },
              {
                "type": "button",
                "props": {
                  "id": "submit",
                  "label": "Create account",
                  "event": "submit"
                }
              }
            ]
          }
        }
        """#
    )

    // MARK: - Sample 4 — Article (primitive content)

    private static let article = JoyDOMSample(
        id: "article",
        label: "Article · primitive content",
        json: #"""
        {
          "version": 1,
          "style": {
            "#article": {
              "flexDirection": "column",
              "gap": { "value": 12, "unit": "px" },
              "padding": { "value": 24, "unit": "px" }
            },
            "#title": { "height": { "value": 36, "unit": "px" } },
            "#byline": { "height": { "value": 20, "unit": "px" } }
          },
          "breakpoints": [],
          "layout": {
            "type": "div",
            "props": { "id": "article" },
            "children": [
              {
                "type": "p",
                "props": { "id": "title" },
                "children": ["The Joy of Server-Driven UI"]
              },
              {
                "type": "p",
                "props": { "id": "byline" },
                "children": ["By the joyfill team · April 2026"]
              },
              {
                "type": "p",
                "props": { "id": "lede" },
                "children": [
                  "Server-driven UI promises a single document format that renders identically across every client."
                ]
              },
              {
                "type": "p",
                "children": [
                  "The trick is finding the right level of abstraction — high enough to be platform-agnostic, low enough to express real screens. Joy-dom lands closer to HTML than to a screenshot, which is the right place for a layout layer to live."
                ]
              },
              {
                "type": "p",
                "children": [
                  "This article is rendered through the same pipeline as every other demo: a JSON document, a tree flatten, a CSS cascade, and a SwiftUI render."
                ]
              }
            ]
          }
        }
        """#
    )

    // MARK: - Sample 5 — Pricing tiers

    private static let pricingTiers = JoyDOMSample(
        id: "pricing",
        label: "Pricing tiers · 3-column",
        json: #"""
        {
          "version": 1,
          "style": {
            "#root": {
              "flexDirection": "column",
              "gap": { "value": 16, "unit": "px" },
              "padding": { "value": 24, "unit": "px" }
            },
            "#heading": { "height": { "value": 32, "unit": "px" } },
            "#tiers": {
              "flexDirection": "column",
              "gap": { "value": 12, "unit": "px" }
            },
            "#tier-free, #tier-pro, #tier-team": {
              "flexGrow": 1,
              "height": { "value": 140, "unit": "px" }
            },
            "#cta": { "height": { "value": 40, "unit": "px" } }
          },
          "breakpoints": [
            {
              "conditions": [
                { "type": "feature", "name": "width", "operator": ">=", "value": 768, "unit": "px" }
              ],
              "nodes": {},
              "style": {
                "#tiers": {
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
              {
                "type": "p",
                "props": { "id": "heading" },
                "children": ["Choose a plan"]
              },
              {
                "type": "div",
                "props": { "id": "tiers" },
                "children": [
                  {
                    "type": "card",
                    "props": { "id": "tier-free", "label": "Free — $0 / mo" }
                  },
                  {
                    "type": "card",
                    "props": { "id": "tier-pro", "label": "Pro — $15 / mo" }
                  },
                  {
                    "type": "card",
                    "props": { "id": "tier-team", "label": "Team — $40 / mo" }
                  }
                ]
              },
              {
                "type": "button",
                "props": {
                  "id": "cta",
                  "label": "Start free trial",
                  "event": "cta-tap"
                }
              }
            ]
          }
        }
        """#
    )
}
