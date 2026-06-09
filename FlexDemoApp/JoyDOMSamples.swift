// JoyDOMSamples — curated joy-dom payloads for the paste demo's
// dropdown. Each sample is a complete, valid `Spec` JSON
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
        kitchenSink,
        visualCSS,
        decorations,
        positioning,
        cornerRadius,
        flexAlign,
        constraints,
        marginShowcase,
        breakpointOrder,
        backgroundImageWrapper,
        breakpointVisibility,
        objectFitGallery,
        objectPositionGrid,
        responsiveHero,
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
                "children": ["By the J0y team · April 2026"]
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

    // MARK: - Sample 6 — Kitchen sink (every primitive + style we support)

    /// A deliberately busy showcase that exercises most of the joy-dom
    /// surface in one document. What it covers:
    ///
    ///   • All four selector kinds — type (`p`), id (`#hero`), class
    ///     (`.feature-card`), comma-list (`#name, #email`), descendant
    ///     (`#features p`).
    ///   • Both `gap` shapes — uniform `Length` and per-axis
    ///     `{ c, r }`.
    ///   • Both `padding` shapes — uniform and per-side.
    ///   • Both `Length` units — `px` and `%`.
    ///   • Cascade priorities — type < class < id, document <
    ///     breakpoint, plus inline `props.style` overriding via id-level
    ///     specificity.
    ///   • Three breakpoints — `>= 768`, `>= 1024`, plus a no-op
    ///     `orientation: landscape` to demonstrate the media query
    ///     shape (no visible effect, but it parses).
    ///   • Per-node breakpoint override — `#hero` gets bigger padding
    ///     at `>= 1024`.
    ///   • All registered widget kinds — `card`, `button`, `input`.
    ///   • Default primitives — `div`, `p`, plus `primitive_string`
    ///     children inside `<p>` elements.
    ///   • Position + offsets + z-index — the "NEW" badge floats
    ///     absolutely over its parent feature card.
    ///   • flex-grow / flex-shrink / flex-basis on the stat row,
    ///     `flexWrap: wrap` for graceful overflow.
    ///   • `justifyContent: space-between` + `space-around`,
    ///     `alignItems: center`.
    ///   • `overflow: hidden` on the footer, `overflow: auto` inline
    ///     on the root.
    ///
    /// At ≥1024px wide it reads as a marketing page; below 600px it
    /// stacks. Drag the slider and watch every section reflow.
    private static let kitchenSink = JoyDOMSample(
        id: "kitchen-sink",
        label: "Kitchen sink · everything",
        json: #"""
        {
          "version": 1,
          "style": {
            "p": {
              "padding": { "value": 4, "unit": "px" }
            },
            "#root": {
              "flexDirection": "column",
              "gap": { "value": 24, "unit": "px" },
              "padding": { "value": 24, "unit": "px" }
            },
            "#hero": {
              "flexDirection": "column",
              "alignItems": "center",
              "gap": { "value": 12, "unit": "px" },
              "padding": {
                "top":    { "value": 32, "unit": "px" },
                "right":  { "value": 24, "unit": "px" },
                "bottom": { "value": 40, "unit": "px" },
                "left":   { "value": 24, "unit": "px" }
              },
              "height": { "value": 240, "unit": "px" }
            },
            "#hero-title": {
              "height": { "value": 40, "unit": "px" }
            },
            "#hero-subtitle": {
              "height": { "value": 22, "unit": "px" }
            },
            "#cta": {
              "height": { "value": 44, "unit": "px" },
              "width":  { "value": 200, "unit": "px" }
            },
            "#stats": {
              "flexDirection": "row",
              "justifyContent": "space-around",
              "flexWrap": "wrap",
              "gap": {
                "c": { "value": 16, "unit": "px" },
                "r": { "value": 12, "unit": "px" }
              }
            },
            ".stat": {
              "flexGrow": 1,
              "flexShrink": 1,
              "flexBasis": { "value": 30, "unit": "%" },
              "height":    { "value": 80, "unit": "px" }
            },
            "#features": {
              "flexDirection": "column",
              "gap": { "value": 12, "unit": "px" }
            },
            ".feature-card": {
              "flexGrow":   1,
              "flexShrink": 1,
              "flexBasis":  { "value": 0,   "unit": "px" },
              "height":     { "value": 140, "unit": "px" },
              "position":   "relative"
            },
            "#badge": {
              "position": "absolute",
              "top":      { "value": 8,  "unit": "px" },
              "right":    { "value": 8,  "unit": "px" },
              "zIndex":   10,
              "width":    { "value": 56, "unit": "px" },
              "height":   { "value": 22, "unit": "px" }
            },
            "#form-section": {
              "flexDirection": "column",
              "gap": { "value": 12, "unit": "px" }
            },
            "#form-row": {
              "flexDirection": "column",
              "gap": { "value": 12, "unit": "px" }
            },
            "#name, #email": {
              "flexGrow": 1,
              "height":   { "value": 38, "unit": "px" }
            },
            "#submit": {
              "height": { "value": 40, "unit": "px" }
            },
            "#footer": {
              "flexDirection":  "row",
              "justifyContent": "space-between",
              "alignItems":     "center",
              "padding":        { "value": 16, "unit": "px" },
              "overflow":       "hidden",
              "height":         { "value": 56, "unit": "px" }
            },
            "#footer-nav": {
              "flexDirection": "row",
              "gap": { "value": 8, "unit": "px" }
            },
            ".nav-link": {
              "flexBasis":  { "value": 80, "unit": "px" },
              "flexShrink": 0,
              "height":     { "value": 32, "unit": "px" }
            }
          },
          "breakpoints": [
            {
              "conditions": [
                { "type": "feature", "name": "width", "operator": ">=", "value": 768, "unit": "px" }
              ],
              "nodes": {},
              "style": {
                "#features": {
                  "flexDirection": "row",
                  "gap": { "value": 16, "unit": "px" }
                },
                "#form-row": {
                  "flexDirection": "row",
                  "gap": { "value": 16, "unit": "px" }
                }
              }
            },
            {
              "conditions": [
                { "type": "feature", "name": "width", "operator": ">=", "value": 1024, "unit": "px" }
              ],
              "nodes": {
                "hero": {
                  "style": {
                    "padding": { "value": 64, "unit": "px" },
                    "height":  { "value": 320, "unit": "px" }
                  }
                }
              },
              "style": {
                "#hero-title": {
                  "height": { "value": 56, "unit": "px" }
                }
              }
            },
            {
              "conditions": [
                { "type": "feature", "name": "orientation", "value": "landscape" }
              ],
              "nodes": {},
              "style": {}
            }
          ],
          "layout": {
            "type": "div",
            "props": {
              "id": "root",
              "style": { "overflow": "auto" }
            },
            "children": [
              {
                "type": "div",
                "props": { "id": "hero" },
                "children": [
                  {
                    "type": "p",
                    "props": {
                      "id": "hero-title",
                      "style": { "padding": { "value": 0, "unit": "px" } }
                    },
                    "children": ["The Joy of Server-Driven UI"]
                  },
                  {
                    "type": "p",
                    "props": { "id": "hero-subtitle" },
                    "children": ["One JSON, every screen."]
                  },
                  {
                    "type": "button",
                    "props": { "id": "cta", "label": "Get started", "event": "cta-tap" }
                  }
                ]
              },
              {
                "type": "div",
                "props": { "id": "stats" },
                "children": [
                  { "type": "card", "props": { "id": "stat-1", "className": ["stat"], "label": "12k stars" } },
                  { "type": "card", "props": { "id": "stat-2", "className": ["stat"], "label": "1.2M downloads" } },
                  { "type": "card", "props": { "id": "stat-3", "className": ["stat"], "label": "98% uptime" } }
                ]
              },
              {
                "type": "div",
                "props": { "id": "features" },
                "children": [
                  {
                    "type": "card",
                    "props": {
                      "id": "f-fast",
                      "className": ["feature-card"],
                      "label": "Fast — typed Style end-to-end"
                    },
                    "children": [
                      {
                        "type": "card",
                        "props": { "id": "badge", "label": "NEW" }
                      }
                    ]
                  },
                  {
                    "type": "card",
                    "props": {
                      "id": "f-typed",
                      "className": ["feature-card"],
                      "label": "Typed — no string parsing in cascade"
                    }
                  },
                  {
                    "type": "card",
                    "props": {
                      "id": "f-portable",
                      "className": ["feature-card"],
                      "label": "Portable — render anywhere"
                    }
                  }
                ]
              },
              {
                "type": "div",
                "props": { "id": "form-section" },
                "children": [
                  { "type": "p", "props": { "id": "form-title" }, "children": ["Get early access"] },
                  {
                    "type": "div",
                    "props": { "id": "form-row" },
                    "children": [
                      {
                        "type": "input",
                        "props": { "id": "name",  "placeholder": "Full name" }
                      },
                      {
                        "type": "input",
                        "props": { "id": "email", "placeholder": "Email address" }
                      }
                    ]
                  },
                  {
                    "type": "button",
                    "props": { "id": "submit", "label": "Subscribe", "event": "subscribe" }
                  }
                ]
              },
              {
                "type": "div",
                "props": { "id": "footer" },
                "children": [
                  { "type": "p", "props": { "id": "copyright" }, "children": ["© 2026 J0y, Inc."] },
                  {
                    "type": "div",
                    "props": { "id": "footer-nav" },
                    "children": [
                      { "type": "button", "props": { "id": "nav-docs",   "className": ["nav-link"], "label": "Docs",   "event": "nav-docs"   } },
                      { "type": "button", "props": { "id": "nav-spec",   "className": ["nav-link"], "label": "Spec",   "event": "nav-spec"   } },
                      { "type": "button", "props": { "id": "nav-github", "className": ["nav-link"], "label": "GitHub", "event": "nav-github" } }
                    ]
                  }
                ]
              }
            ]
          }
        }
        """#
    )

    // MARK: - Sample 7 — Visual CSS
    // Exercises backgroundColor, opacity, border, borderRadius, margin,
    // typography (fontFamily, fontSize, fontWeight, color, lineHeight,
    // letterSpacing, textAlign, textTransform), alignSelf, minWidth/maxWidth,
    // rowGap/columnGap, display:none, h1–h4, span, and img.

    static let visualCSS = JoyDOMSample(
        id: "visual-css",
        label: "Visual CSS · typography + box model",
        json: #"""
        {
          "version": 1,
          "style": {
            "#root": {
              "flexDirection": "column",
              "gap": { "value": 0, "unit": "px" },
              "backgroundColor": "#F8F9FA"
            },
            ".section": {
              "flexDirection": "column",
              "padding": { "value": 20, "unit": "px" },
              "margin": { "value": 12, "unit": "px" },
              "backgroundColor": "#FFFFFF",
              "borderRadius": { "value": 12, "unit": "px" },
              "borderWidth": { "value": 1, "unit": "px" },
              "borderColor": "#E0E0E0",
              "borderStyle": "solid"
            },
            "h1": {
              "fontSize": { "value": 28, "unit": "px" },
              "fontWeight": 700,
              "color": "#1A1A2E",
              "letterSpacing": { "value": -0.5, "unit": "px" },
              "lineHeight": 1.2
            },
            "h2": {
              "fontSize": { "value": 20, "unit": "px" },
              "fontWeight": 600,
              "color": "#16213E",
              "lineHeight": 1.3
            },
            "h3": {
              "fontSize": { "value": 16, "unit": "px" },
              "fontWeight": 500,
              "color": "#0F3460",
              "textTransform": "uppercase",
              "letterSpacing": { "value": 1, "unit": "px" }
            },
            "p": {
              "fontSize": { "value": 14, "unit": "px" },
              "color": "#555555",
              "lineHeight": 1.6
            },
            ".badge": {
              "backgroundColor": "#E8F4FD",
              "borderRadius": { "value": 20, "unit": "px" },
              "padding": { "topLeft": null, "top": { "value": 4, "unit": "px" }, "right": { "value": 12, "unit": "px" }, "bottom": { "value": 4, "unit": "px" }, "left": { "value": 12, "unit": "px" } },
              "borderWidth": { "value": 1, "unit": "px" },
              "borderColor": "#B3D9F5",
              "borderStyle": "solid"
            },
            ".badge-text": {
              "fontSize": { "value": 12, "unit": "px" },
              "fontWeight": 600,
              "color": "#1976D2",
              "textTransform": "uppercase",
              "letterSpacing": { "value": 0.5, "unit": "px" }
            },
            ".row": {
              "flexDirection": "row",
              "flexWrap": "wrap",
              "columnGap": { "value": 12, "unit": "px" },
              "rowGap": { "value": 8, "unit": "px" }
            },
            ".card": {
              "flexDirection": "column",
              "flexGrow": 1,
              "minWidth": { "value": 120, "unit": "px" },
              "maxWidth": { "value": 200, "unit": "px" },
              "padding": { "value": 16, "unit": "px" },
              "backgroundColor": "#F0F4FF",
              "borderRadius": { "value": 8, "unit": "px" }
            },
            ".card-value": {
              "fontSize": { "value": 24, "unit": "px" },
              "fontWeight": 700,
              "color": "#3B4FE0",
              "textAlign": "center"
            },
            ".card-label": {
              "fontSize": { "value": 11, "unit": "px" },
              "color": "#888888",
              "textAlign": "center",
              "textTransform": "uppercase",
              "letterSpacing": { "value": 0.8, "unit": "px" }
            },
            ".faded": {
              "opacity": 0.4
            },
            ".hidden-node": {
              "display": "none"
            }
          },
          "breakpoints": [],
          "layout": {
            "type": "div",
            "props": { "id": "root" },
            "children": [
              {
                "type": "div",
                "props": { "id": "hero-section", "className": ["section"] },
                "children": [
                  {
                    "type": "div",
                    "props": { "id": "badge-row", "className": ["row"] },
                    "children": [
                      {
                        "type": "div",
                        "props": { "id": "badge-new", "className": ["badge"] },
                        "children": [
                          { "type": "p", "props": { "id": "badge-new-text", "className": ["badge-text"] }, "children": ["New"] }
                        ]
                      },
                      {
                        "type": "div",
                        "props": { "id": "badge-v2", "className": ["badge"] },
                        "children": [
                          { "type": "p", "props": { "id": "badge-v2-text", "className": ["badge-text"] }, "children": ["v2.0"] }
                        ]
                      }
                    ]
                  },
                  { "type": "h1", "props": { "id": "hero-title" }, "children": ["Visual CSS in JoyDOM"] },
                  { "type": "p",  "props": { "id": "hero-body" },  "children": ["This sample exercises the full visual CSS property set: borders, border radius, background colors, opacity, typography, min/max sizing, and more."] }
                ]
              },
              {
                "type": "div",
                "props": { "id": "stats-section", "className": ["section"] },
                "children": [
                  { "type": "h3", "props": { "id": "stats-label" }, "children": ["At a glance"] },
                  {
                    "type": "div",
                    "props": { "id": "stats-row", "className": ["row"] },
                    "children": [
                      {
                        "type": "div",
                        "props": { "id": "stat-a", "className": ["card"] },
                        "children": [
                          { "type": "p", "props": { "id": "stat-a-val", "className": ["card-value"] }, "children": ["28"] },
                          { "type": "p", "props": { "id": "stat-a-lbl", "className": ["card-label"] }, "children": ["CSS props"] }
                        ]
                      },
                      {
                        "type": "div",
                        "props": { "id": "stat-b", "className": ["card"] },
                        "children": [
                          { "type": "p", "props": { "id": "stat-b-val", "className": ["card-value"] }, "children": ["8"] },
                          { "type": "p", "props": { "id": "stat-b-lbl", "className": ["card-label"] }, "children": ["HTML types"] }
                        ]
                      },
                      {
                        "type": "div",
                        "props": { "id": "stat-c", "className": ["card", "faded"] },
                        "children": [
                          { "type": "p", "props": { "id": "stat-c-val", "className": ["card-value"] }, "children": ["∞"] },
                          { "type": "p", "props": { "id": "stat-c-lbl", "className": ["card-label"] }, "children": ["Possible UIs"] }
                        ]
                      }
                    ]
                  }
                ]
              },
              {
                "type": "div",
                "props": { "id": "hidden-section", "className": ["hidden-node"] },
                "children": [
                  { "type": "p", "props": { "id": "hidden-p" }, "children": ["This node is display:none — it should not be visible."] }
                ]
              },
              {
                "type": "div",
                "props": { "id": "typography-section", "className": ["section"] },
                "children": [
                  { "type": "h2", "props": { "id": "typo-title" }, "children": ["Typography scale"] },
                  { "type": "h1", "props": { "id": "typo-h1" }, "children": ["Heading 1"] },
                  { "type": "h2", "props": { "id": "typo-h2" }, "children": ["Heading 2"] },
                  { "type": "h3", "props": { "id": "typo-h3" }, "children": ["Heading 3"] },
                  { "type": "h4", "props": { "id": "typo-h4" }, "children": ["Heading 4"] },
                  { "type": "p",  "props": { "id": "typo-p" },  "children": ["Body paragraph with comfortable line-height and subdued color. Designed to be readable at 14 px on any background."] }
                ]
              }
            ]
          }
        }
        """#
    )

    // MARK: - Sample 8 — Decorations (Phase 2 typography showcase)
    //
    // Exercises: textDecoration env cascade onto text leaves,
    // textTransform: uppercase, fontStyle: italic, letterSpacing em→pt
    // scaling at known font sizes, and the four numeric font-weight bands
    // (100 ultraLight, 400 regular, 700 bold, 900 black).

    static let decorations = JoyDOMSample(
        id: "decorations",
        label: "Typography · decorations + weights",
        json: #"""
        {
          "version": 1,
          "style": {
            "#root": {
              "flexDirection": "column",
              "gap": { "value": 16, "unit": "px" },
              "padding": { "value": 24, "unit": "px" },
              "backgroundColor": "#FFFFFF"
            },
            "#underline-block": {
              "flexDirection": "column",
              "gap": { "value": 6, "unit": "px" },
              "textDecoration": "underline",
              "color": "#1A1A2E",
              "fontSize": { "value": 16, "unit": "px" }
            },
            "#strike-block": {
              "flexDirection": "column",
              "gap": { "value": 6, "unit": "px" },
              "textDecoration": "line-through",
              "color": "#888888"
            },
            "#shout": {
              "textTransform": "uppercase",
              "fontSize": { "value": 18, "unit": "px" },
              "fontWeight": 600,
              "letterSpacing": { "value": 1, "unit": "px" },
              "color": "#0F3460"
            },
            "#italic-line": {
              "fontStyle": "italic",
              "fontSize": { "value": 16, "unit": "px" },
              "color": "#16213E"
            },
            "#tracked": {
              "fontSize":      { "value": 24,  "unit": "px" },
              "letterSpacing": { "value": 2.4, "unit": "px" },
              "color": "#3B4FE0"
            },
            ".weights-row": {
              "flexDirection": "row",
              "flexWrap": "wrap",
              "gap": { "value": 16, "unit": "px" },
              "fontSize": { "value": 18, "unit": "px" }
            },
            "#w-100": { "fontWeight": 100 },
            "#w-400": { "fontWeight": 400 },
            "#w-700": { "fontWeight": 700 },
            "#w-900": { "fontWeight": 900 }
          },
          "breakpoints": [],
          "layout": {
            "type": "div",
            "props": { "id": "root" },
            "children": [
              {
                "type": "div",
                "props": { "id": "underline-block" },
                "children": [
                  { "type": "p", "props": { "id": "underline-line" }, "children": ["Underlined heading via env cascade"] },
                  { "type": "p", "props": { "id": "underline-line-2" }, "children": ["A second line that also picks up the underline"] }
                ]
              },
              {
                "type": "div",
                "props": { "id": "strike-block" },
                "children": [
                  { "type": "p", "props": { "id": "strike-line" }, "children": ["Discounted price through the cascade"] }
                ]
              },
              { "type": "p", "props": { "id": "shout" }, "children": ["uppercase shouting"] },
              { "type": "p", "props": { "id": "italic-line" }, "children": ["This line is rendered in italic"] },
              { "type": "p", "props": { "id": "tracked" }, "children": ["letter-spaced em→pt"] },
              {
                "type": "div",
                "props": { "id": "weights", "className": ["weights-row"] },
                "children": [
                  { "type": "p", "props": { "id": "w-100" }, "children": ["Weight 100"] },
                  { "type": "p", "props": { "id": "w-400" }, "children": ["Weight 400"] },
                  { "type": "p", "props": { "id": "w-700" }, "children": ["Weight 700"] },
                  { "type": "p", "props": { "id": "w-900" }, "children": ["Weight 900"] }
                ]
              }
            ]
          }
        }
        """#
    )

    // MARK: - Sample 9 — Positioning (absolute overlays + zIndex + fixed diagnostic)

    static let positioning = JoyDOMSample(
        id: "positioning",
        label: "Positioning · absolute, zIndex, fixed",
        json: #"""
        {
          "version": 1,
          "style": {
            "#root": {
              "flexDirection": "column",
              "gap": { "value": 16, "unit": "px" },
              "padding": { "value": 24, "unit": "px" }
            },
            "#card": {
              "position": "relative",
              "width":  { "value": 300, "unit": "px" },
              "height": { "value": 200, "unit": "px" },
              "backgroundColor": "#F0F4FF",
              "borderRadius": { "value": 8, "unit": "px" }
            },
            "#ribbon": {
              "position": "absolute",
              "top":  { "value": 0, "unit": "px" },
              "left": { "value": 0, "unit": "px" },
              "width":  { "value": 240, "unit": "px" },
              "height": { "value": 28,  "unit": "px" },
              "backgroundColor": "#3B4FE0",
              "zIndex": 1
            },
            "#badge": {
              "position": "absolute",
              "top":   { "value": 4, "unit": "px" },
              "right": { "value": 0, "unit": "px" },
              "zIndex": 10,
              "width":  { "value": 80, "unit": "px" },
              "height": { "value": 22, "unit": "px" },
              "backgroundColor": "#E94560"
            },
            "#footer-pin": {
              "position": "absolute",
              "left":   { "value": 0, "unit": "px" },
              "right":  { "value": 0, "unit": "px" },
              "bottom": { "value": 0, "unit": "px" },
              "height": { "value": 32, "unit": "px" },
              "backgroundColor": "#16213E"
            },
            "#fixed-diag": {
              "position": "fixed",
              "top":  { "value": 0, "unit": "px" },
              "left": { "value": 0, "unit": "px" },
              "width":  { "value": 120, "unit": "px" },
              "height": { "value": 24, "unit": "px" }
            }
          },
          "breakpoints": [],
          "layout": {
            "type": "div",
            "props": { "id": "root" },
            "children": [
              {
                "type": "div",
                "props": { "id": "card" },
                "children": [
                  { "type": "card", "props": { "id": "ribbon", "label": "RIBBON" } },
                  { "type": "card", "props": { "id": "badge",  "label": "NEW" } },
                  { "type": "card", "props": { "id": "footer-pin", "label": "Pinned footer" } }
                ]
              },
              { "type": "card", "props": { "id": "fixed-diag", "label": "position:fixed (diagnostic)" } }
            ]
          }
        }
        """#
    )

    // MARK: - Sample 10 — Per-corner radius shapes

    static let cornerRadius = JoyDOMSample(
        id: "corner-radius",
        label: "Corner radius · per-corner shapes",
        json: #"""
        {
          "version": 1,
          "style": {
            "#root": {
              "flexDirection": "column",
              "gap": { "value": 20, "unit": "px" },
              "padding": { "value": 24, "unit": "px" }
            },
            "#bubble": {
              "width":  { "value": 240, "unit": "px" },
              "height": { "value": 80,  "unit": "px" },
              "backgroundColor": "#E8F4FD",
              "borderRadius": {
                "topLeft":     { "value": 12, "unit": "px" },
                "topRight":    { "value": 12, "unit": "px" },
                "bottomRight": { "value": 12, "unit": "px" },
                "bottomLeft":  { "value": 0,  "unit": "px" }
              }
            },
            "#chip": {
              "width":  { "value": 160, "unit": "px" },
              "height": { "value": 32,  "unit": "px" },
              "backgroundColor": "#3B4FE0",
              "borderRadius": {
                "topLeft":     { "value": 16, "unit": "px" },
                "topRight":    { "value": 0,  "unit": "px" },
                "bottomRight": { "value": 0,  "unit": "px" },
                "bottomLeft":  { "value": 16, "unit": "px" }
              }
            },
            "#asym": {
              "width":  { "value": 200, "unit": "px" },
              "height": { "value": 80,  "unit": "px" },
              "backgroundColor": "#F0F4FF",
              "borderRadius": {
                "topLeft":     { "value": 4,  "unit": "px" },
                "topRight":    { "value": 8,  "unit": "px" },
                "bottomRight": { "value": 16, "unit": "px" },
                "bottomLeft":  { "value": 24, "unit": "px" }
              }
            }
          },
          "breakpoints": [],
          "layout": {
            "type": "div",
            "props": { "id": "root" },
            "children": [
              { "type": "card", "props": { "id": "bubble", "label": "Speech bubble" } },
              { "type": "card", "props": { "id": "chip",   "label": "Asymmetric pill" } },
              { "type": "card", "props": { "id": "asym",   "label": "All four corners" } }
            ]
          }
        }
        """#
    )

    // MARK: - Sample 11 — Flex alignment (alignSelf, order, alignContent, all directions)

    static let flexAlign = JoyDOMSample(
        id: "flex-align",
        label: "Flex · alignSelf, order, all directions",
        json: #"""
        {
          "version": 1,
          "style": {
            "#root": {
              "flexDirection": "column",
              "gap": { "value": 20, "unit": "px" },
              "padding": { "value": 16, "unit": "px" }
            },
            ".section": {
              "flexDirection": "column",
              "gap": { "value": 8, "unit": "px" }
            },
            "#wrap-row": {
              "flexDirection": "row",
              "flexWrap": "wrap",
              "alignContent": "space-between",
              "gap": { "value": 8, "unit": "px" },
              "height": { "value": 220, "unit": "px" },
              "backgroundColor": "#F0F4FF"
            },
            ".wrap-cell": {
              "width":  { "value": 110, "unit": "px" },
              "height": { "value": 40,  "unit": "px" },
              "backgroundColor": "#3B4FE0"
            },
            "#self-row": {
              "flexDirection": "row",
              "alignItems": "flex-start",
              "gap": { "value": 8, "unit": "px" },
              "height": { "value": 100, "unit": "px" },
              "backgroundColor": "#E8F4FD"
            },
            "#self-a": { "width": { "value": 60, "unit": "px" }, "height": { "value": 30, "unit": "px" } },
            "#self-b": { "width": { "value": 60, "unit": "px" }, "height": { "value": 30, "unit": "px" }, "alignSelf": "center" },
            "#self-c": { "width": { "value": 60, "unit": "px" }, "height": { "value": 30, "unit": "px" }, "alignSelf": "flex-end" },
            "#order-row": {
              "flexDirection": "row",
              "gap": { "value": 8, "unit": "px" }
            },
            "#order-a": { "order": 3, "width": { "value": 60, "unit": "px" }, "height": { "value": 30, "unit": "px" } },
            "#order-b": { "order": 1, "width": { "value": 60, "unit": "px" }, "height": { "value": 30, "unit": "px" } },
            "#order-c": { "order": 2, "width": { "value": 60, "unit": "px" }, "height": { "value": 30, "unit": "px" } },
            "#dir-row":          { "flexDirection": "row",            "gap": { "value": 8, "unit": "px" } },
            "#dir-row-reverse":  { "flexDirection": "row-reverse",    "gap": { "value": 8, "unit": "px" } },
            "#dir-col":          { "flexDirection": "column",         "gap": { "value": 8, "unit": "px" } },
            "#dir-col-reverse":  { "flexDirection": "column-reverse", "gap": { "value": 8, "unit": "px" } },
            ".dir-cell": { "width": { "value": 40, "unit": "px" }, "height": { "value": 24, "unit": "px" } },
            "#wrap-rev": {
              "flexDirection": "row",
              "flexWrap": "wrap-reverse",
              "gap": { "value": 8, "unit": "px" },
              "height": { "value": 130, "unit": "px" }
            }
          },
          "breakpoints": [],
          "layout": {
            "type": "div",
            "props": { "id": "root" },
            "children": [
              {
                "type": "div",
                "props": { "id": "wrap-row" },
                "children": [
                  { "type": "card", "props": { "id": "wc-1", "className": ["wrap-cell"], "label": "1" } },
                  { "type": "card", "props": { "id": "wc-2", "className": ["wrap-cell"], "label": "2" } },
                  { "type": "card", "props": { "id": "wc-3", "className": ["wrap-cell"], "label": "3" } },
                  { "type": "card", "props": { "id": "wc-4", "className": ["wrap-cell"], "label": "4" } },
                  { "type": "card", "props": { "id": "wc-5", "className": ["wrap-cell"], "label": "5" } },
                  { "type": "card", "props": { "id": "wc-6", "className": ["wrap-cell"], "label": "6" } }
                ]
              },
              {
                "type": "div",
                "props": { "id": "self-row" },
                "children": [
                  { "type": "card", "props": { "id": "self-a", "label": "start" } },
                  { "type": "card", "props": { "id": "self-b", "label": "center" } },
                  { "type": "card", "props": { "id": "self-c", "label": "end" } }
                ]
              },
              {
                "type": "div",
                "props": { "id": "order-row" },
                "children": [
                  { "type": "card", "props": { "id": "order-a", "label": "A (order 3)" } },
                  { "type": "card", "props": { "id": "order-b", "label": "B (order 1)" } },
                  { "type": "card", "props": { "id": "order-c", "label": "C (order 2)" } }
                ]
              },
              {
                "type": "div",
                "props": { "id": "dir-row" },
                "children": [
                  { "type": "card", "props": { "id": "dr-1", "className": ["dir-cell"], "label": "1" } },
                  { "type": "card", "props": { "id": "dr-2", "className": ["dir-cell"], "label": "2" } },
                  { "type": "card", "props": { "id": "dr-3", "className": ["dir-cell"], "label": "3" } }
                ]
              },
              {
                "type": "div",
                "props": { "id": "dir-row-reverse" },
                "children": [
                  { "type": "card", "props": { "id": "drr-1", "className": ["dir-cell"], "label": "1" } },
                  { "type": "card", "props": { "id": "drr-2", "className": ["dir-cell"], "label": "2" } },
                  { "type": "card", "props": { "id": "drr-3", "className": ["dir-cell"], "label": "3" } }
                ]
              },
              {
                "type": "div",
                "props": { "id": "dir-col" },
                "children": [
                  { "type": "card", "props": { "id": "dc-1", "className": ["dir-cell"], "label": "1" } },
                  { "type": "card", "props": { "id": "dc-2", "className": ["dir-cell"], "label": "2" } }
                ]
              },
              {
                "type": "div",
                "props": { "id": "dir-col-reverse" },
                "children": [
                  { "type": "card", "props": { "id": "dcr-1", "className": ["dir-cell"], "label": "1" } },
                  { "type": "card", "props": { "id": "dcr-2", "className": ["dir-cell"], "label": "2" } }
                ]
              },
              {
                "type": "div",
                "props": { "id": "wrap-rev" },
                "children": [
                  { "type": "card", "props": { "id": "wr-1", "className": ["wrap-cell"], "label": "1" } },
                  { "type": "card", "props": { "id": "wr-2", "className": ["wrap-cell"], "label": "2" } },
                  { "type": "card", "props": { "id": "wr-3", "className": ["wrap-cell"], "label": "3" } },
                  { "type": "card", "props": { "id": "wr-4", "className": ["wrap-cell"], "label": "4" } },
                  { "type": "card", "props": { "id": "wr-5", "className": ["wrap-cell"], "label": "5" } },
                  { "type": "card", "props": { "id": "wr-6", "className": ["wrap-cell"], "label": "6" } },
                  { "type": "card", "props": { "id": "wr-7", "className": ["wrap-cell"], "label": "7" } },
                  { "type": "card", "props": { "id": "wr-8", "className": ["wrap-cell"], "label": "8" } }
                ]
              }
            ]
          }
        }
        """#
    )

    // MARK: - Sample 12 — Constraints (min/max + §9.7 redistribution)

    static let constraints = JoyDOMSample(
        id: "constraints",
        label: "Constraints · min/max + redistribution",
        json: #"""
        {
          "version": 1,
          "style": {
            "#root": {
              "flexDirection": "column",
              "gap": { "value": 20, "unit": "px" },
              "padding": { "value": 16, "unit": "px" }
            },
            "#redist-row": {
              "flexDirection": "row",
              "gap": { "value": 0, "unit": "px" },
              "width":  { "value": 300, "unit": "px" },
              "height": { "value": 60,  "unit": "px" }
            },
            "#redist-a": { "flexGrow": 1, "maxWidth": { "value": 50, "unit": "px" }, "backgroundColor": "#3B4FE0" },
            "#redist-b": { "flexGrow": 1, "backgroundColor": "#16213E" },
            "#redist-c": { "flexGrow": 1, "backgroundColor": "#0F3460" },
            "#min-h": {
              "minHeight": { "value": 100, "unit": "px" },
              "width":     { "value": 240, "unit": "px" },
              "backgroundColor": "#E8F4FD"
            },
            "#max-h": {
              "maxHeight": { "value": 80, "unit": "px" },
              "width":     { "value": 240, "unit": "px" },
              "backgroundColor": "#F0F4FF"
            },
            "#nested-outer": {
              "flexDirection": "column",
              "width": { "value": 320, "unit": "px" },
              "padding": { "value": 8, "unit": "px" },
              "backgroundColor": "#F8F9FA"
            },
            "#nested-inner": {
              "minWidth": { "value": 50, "unit": "%" },
              "height":   { "value": 40, "unit": "px" },
              "backgroundColor": "#3B4FE0"
            }
          },
          "breakpoints": [],
          "layout": {
            "type": "div",
            "props": { "id": "root" },
            "children": [
              {
                "type": "div",
                "props": { "id": "redist-row" },
                "children": [
                  { "type": "card", "props": { "id": "redist-a", "label": "max=50" } },
                  { "type": "card", "props": { "id": "redist-b", "label": "grow" } },
                  { "type": "card", "props": { "id": "redist-c", "label": "grow" } }
                ]
              },
              { "type": "card", "props": { "id": "min-h", "label": "minHeight 100 (content shorter)" } },
              { "type": "card", "props": { "id": "max-h", "label": "maxHeight 80 (content taller — clamped)" } },
              {
                "type": "div",
                "props": { "id": "nested-outer" },
                "children": [
                  { "type": "card", "props": { "id": "nested-inner", "label": "minWidth 50% of outer" } }
                ]
              }
            ]
          }
        }
        """#
    )

    // MARK: - Sample 13 — Margin showcase (Phase 3 true flex-item margin)

    static let marginShowcase = JoyDOMSample(
        id: "margin-showcase",
        label: "Margin · true flex-item margins",
        json: #"""
        {
          "version": 1,
          "style": {
            "#root": {
              "flexDirection": "column",
              "gap": { "value": 16, "unit": "px" },
              "padding": { "value": 16, "unit": "px" }
            },
            "#mg-row": {
              "flexDirection": "row",
              "gap": { "value": 0, "unit": "px" },
              "backgroundColor": "#F0F4FF"
            },
            ".mg-card": {
              "flexGrow": 1,
              "height": { "value": 60, "unit": "px" },
              "margin": { "value": 16, "unit": "px" },
              "backgroundColor": "#3B4FE0"
            },
            "#asym-col": {
              "flexDirection": "column",
              "backgroundColor": "#E8F4FD"
            },
            ".asym-row": {
              "height": { "value": 32, "unit": "px" },
              "margin": {
                "top":    { "value": 8,  "unit": "px" },
                "right":  { "value": 0,  "unit": "px" },
                "bottom": { "value": 16, "unit": "px" },
                "left":   { "value": 0,  "unit": "px" }
              },
              "backgroundColor": "#16213E"
            },
            "#composed": {
              "width":   { "value": 200, "unit": "px" },
              "height":  { "value": 80,  "unit": "px" },
              "padding": { "value": 12,  "unit": "px" },
              "margin":  { "value": 24,  "unit": "px" },
              "backgroundColor": "#F8F9FA",
              "borderWidth": { "value": 2, "unit": "px" },
              "borderColor": "#3B4FE0",
              "borderStyle": "solid"
            }
          },
          "breakpoints": [],
          "layout": {
            "type": "div",
            "props": { "id": "root" },
            "children": [
              {
                "type": "div",
                "props": { "id": "mg-row" },
                "children": [
                  { "type": "card", "props": { "id": "mg-1", "className": ["mg-card"], "label": "m=16" } },
                  { "type": "card", "props": { "id": "mg-2", "className": ["mg-card"], "label": "m=16" } },
                  { "type": "card", "props": { "id": "mg-3", "className": ["mg-card"], "label": "m=16" } }
                ]
              },
              {
                "type": "div",
                "props": { "id": "asym-col" },
                "children": [
                  { "type": "card", "props": { "id": "asym-1", "className": ["asym-row"], "label": "asym 1" } },
                  { "type": "card", "props": { "id": "asym-2", "className": ["asym-row"], "label": "asym 2" } },
                  { "type": "card", "props": { "id": "asym-3", "className": ["asym-row"], "label": "asym 3" } }
                ]
              },
              { "type": "card", "props": { "id": "composed", "label": "padding 12 + margin 24" } }
            ]
          }
        }
        """#
    )

    // MARK: - Sample 14 — Breakpoint order override
    //
    // Spec primary use case for `Breakpoint.style` rules touching `order`:
    // a row of three labelled cards (A / B / C) with document-level `order:
    // 1, 2, 3`. A `width >= 768px` breakpoint flips the assignment to `3,
    // 2, 1`, so at wide widths the visual order becomes C, B, A. Drag the
    // viewport slider across the boundary to watch the siblings re-order
    // live. Documented in `DOM/guides/Breakpoints.md` "Custom Breakpoint
    // Node Ordering".

    static let breakpointOrder = JoyDOMSample(
        id: "breakpoint-order",
        label: "Breakpoint · order override at >=768px",
        json: #"""
        {
          "version": 1,
          "style": {
            "#root": {
              "flexDirection": "column",
              "gap":     { "value": 12, "unit": "px" },
              "padding": { "value": 16, "unit": "px" }
            },
            "#row": {
              "flexDirection": "row",
              "gap": { "value": 12, "unit": "px" }
            },
            ".card": {
              "flexGrow": 1,
              "height":   { "value": 80,  "unit": "px" },
              "minWidth": { "value": 80,  "unit": "px" },
              "backgroundColor": "#3B4FE0",
              "borderRadius":    { "value": 8, "unit": "px" }
            },
            "#a": { "order": 1 },
            "#b": { "order": 2 },
            "#c": { "order": 3 }
          },
          "breakpoints": [
            {
              "conditions": [
                { "type": "feature", "name": "width", "operator": ">=", "value": 768, "unit": "px" }
              ],
              "nodes": {},
              "style": {
                "#a": { "order": 3 },
                "#b": { "order": 2 },
                "#c": { "order": 1 }
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
                "children": ["Drag the viewport across 768px to flip the order"]
              },
              {
                "type": "div",
                "props": { "id": "row" },
                "children": [
                  { "type": "card", "props": { "id": "a", "className": ["card"], "label": "A" } },
                  { "type": "card", "props": { "id": "b", "className": ["card"], "label": "B" } },
                  { "type": "card", "props": { "id": "c", "className": ["card"], "label": "C" } }
                ]
              }
            ]
          }
        }
        """#
    )

    // MARK: - Background image wrapper (DOM/guides/BackgroundImages.md)

    /// Spec recipe — joy-dom does NOT support CSS `background-image`.
    /// Instead authors declare a `position: relative` wrapper, an
    /// absolutely-pinned `<img>` with `object-fit: cover` at zIndex 0,
    /// and a sibling content layer at zIndex 1. This sample mirrors the
    /// recipe in `DOM/guides/BackgroundImages.md` step-for-step so the
    /// pattern has a tested, runnable reference.
    static let backgroundImageWrapper = JoyDOMSample(
        id: "background-image-wrapper",
        label: "Image · background-image wrapper recipe",
        json: #"""
        {
          "version": 1,
          "style": {
            "#wrapper": {
              "position": "relative",
              "width":         { "value": 320, "unit": "px" },
              "height":        { "value": 200, "unit": "px" },
              "overflow":      "hidden",
              "borderRadius":  { "value": 12,  "unit": "px" }
            },
            "#bg": {
              "position": "absolute",
              "top":      { "value": 0, "unit": "px" },
              "left":     { "value": 0, "unit": "px" },
              "right":    { "value": 0, "unit": "px" },
              "bottom":   { "value": 0, "unit": "px" },
              "zIndex":   0,
              "objectFit": "cover"
            },
            "#content": {
              "position": "absolute",
              "top":      { "value": 0, "unit": "px" },
              "left":     { "value": 0, "unit": "px" },
              "right":    { "value": 0, "unit": "px" },
              "bottom":   { "value": 0, "unit": "px" },
              "zIndex":   1,
              "padding":  { "value": 16, "unit": "px" },
              "color":    "#FFFFFF",
              "flexDirection": "column",
              "justifyContent": "flex-end"
            }
          },
          "breakpoints": [],
          "layout": {
            "type": "div",
            "props": { "id": "wrapper" },
            "children": [
              {
                "type": "img",
                "props": {
                  "id": "bg",
                  "src": "https://picsum.photos/seed/joydom-bg/640/400"
                }
              },
              {
                "type": "div",
                "props": { "id": "content" },
                "children": [
                  { "type": "p", "props": { "id": "headline" }, "children": ["Background image via wrapper"] }
                ]
              }
            ]
          }
        }
        """#
    )

    // MARK: - Breakpoint visibility (DOM/guides/Breakpoints.md)

    /// Three sibling slots in a row. At viewports `>=768px` the middle
    /// slot is hidden via `display: none` — the spec's "Custom
    /// Breakpoint Node Visibility" recipe in `DOM/guides/Breakpoints.md`.
    static let breakpointVisibility = JoyDOMSample(
        id: "breakpoint-visibility",
        label: "Breakpoint · hide middle slot at >=768px",
        json: #"""
        {
          "version": 1,
          "style": {
            "#root": {
              "flexDirection": "column",
              "gap":     { "value": 12, "unit": "px" },
              "padding": { "value": 16, "unit": "px" }
            },
            "#row": {
              "flexDirection": "row",
              "gap": { "value": 12, "unit": "px" }
            },
            ".slot": {
              "flexGrow": 1,
              "height":   { "value": 80, "unit": "px" },
              "backgroundColor": "#3B4FE0",
              "borderRadius":    { "value": 8, "unit": "px" }
            }
          },
          "breakpoints": [
            {
              "conditions": [
                { "type": "feature", "name": "width", "operator": ">=", "value": 768, "unit": "px" }
              ],
              "nodes": {},
              "style": {
                "#middle": { "display": "none" }
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
                "children": ["Drag past 768px to hide the middle slot"]
              },
              {
                "type": "div",
                "props": { "id": "row" },
                "children": [
                  { "type": "div", "props": { "id": "left",   "className": ["slot"] } },
                  { "type": "div", "props": { "id": "middle", "className": ["slot"] } },
                  { "type": "div", "props": { "id": "right",  "className": ["slot"] } }
                ]
              }
            ]
          }
        }
        """#
    )

    // MARK: - object-fit gallery (PR #26)

    /// Four 140×140 frames in a row, each rendering the SAME 3:2 source
    /// image with a different `object-fit` mode. Picks up the `nil → fill`
    /// CSS-default fix (Concern 1 from the PR review): the rightmost
    /// frame intentionally omits `objectFit` so authors can confirm it
    /// matches `fill`, not the prior intrinsic-size behaviour.
    static let objectFitGallery = JoyDOMSample(
        id: "object-fit-gallery",
        label: "Image · object-fit modes side-by-side",
        json: #"""
        {
          "version": 1,
          "style": {
            "#root": {
              "flexDirection": "column",
              "gap":     { "value": 16, "unit": "px" },
              "padding": { "value": 16, "unit": "px" }
            },
            "#row": {
              "flexDirection": "row",
              "gap": { "value": 12, "unit": "px" },
              "alignItems": "flex-start"
            },
            ".cell": {
              "flexDirection": "column",
              "gap": { "value": 6, "unit": "px" },
              "alignItems": "center"
            },
            ".frame": {
              "width":  { "value": 140, "unit": "px" },
              "height": { "value": 140, "unit": "px" },
              "backgroundColor": "#EEF1F6",
              "borderWidth":  { "value": 1, "unit": "px" },
              "borderColor":  "#C8CFD9",
              "overflow":     "hidden"
            },
            ".pic": {
              "width":  { "value": 100, "unit": "%" },
              "height": { "value": 100, "unit": "%" }
            },
            "#imgFill":    { "objectFit": "fill" },
            "#imgContain": { "objectFit": "contain" },
            "#imgCover":   { "objectFit": "cover" },
            "#imgNone":    { "objectFit": "none" },
            ".caption": {
              "fontSize":   { "value": 12, "unit": "px" },
              "color":      "#475066",
              "textAlign":  "center"
            }
          },
          "breakpoints": [],
          "layout": {
            "type": "div",
            "props": { "id": "root" },
            "children": [
              {
                "type": "p",
                "props": { "id": "title" },
                "children": ["object-fit modes (source is 3:2 inside a 1:1 frame)"]
              },
              {
                "type": "div",
                "props": { "id": "row" },
                "children": [
                  { "type": "div", "props": { "className": ["cell"] }, "children": [
                    { "type": "div", "props": { "className": ["frame"] }, "children": [
                      { "type": "img", "props": { "id": "imgFill", "className": ["pic"],
                        "src": "https://picsum.photos/seed/joydom-fit/600/400" } }
                    ]},
                    { "type": "p", "props": { "className": ["caption"] }, "children": ["fill"] }
                  ]},
                  { "type": "div", "props": { "className": ["cell"] }, "children": [
                    { "type": "div", "props": { "className": ["frame"] }, "children": [
                      { "type": "img", "props": { "id": "imgContain", "className": ["pic"],
                        "src": "https://picsum.photos/seed/joydom-fit/600/400" } }
                    ]},
                    { "type": "p", "props": { "className": ["caption"] }, "children": ["contain"] }
                  ]},
                  { "type": "div", "props": { "className": ["cell"] }, "children": [
                    { "type": "div", "props": { "className": ["frame"] }, "children": [
                      { "type": "img", "props": { "id": "imgCover", "className": ["pic"],
                        "src": "https://picsum.photos/seed/joydom-fit/600/400" } }
                    ]},
                    { "type": "p", "props": { "className": ["caption"] }, "children": ["cover"] }
                  ]},
                  { "type": "div", "props": { "className": ["cell"] }, "children": [
                    { "type": "div", "props": { "className": ["frame"] }, "children": [
                      { "type": "img", "props": { "id": "imgNone", "className": ["pic"],
                        "src": "https://picsum.photos/seed/joydom-fit/600/400" } }
                    ]},
                    { "type": "p", "props": { "className": ["caption"] }, "children": ["none"] }
                  ]}
                ]
              },
              {
                "type": "p",
                "props": { "id": "footer" },
                "children": ["Right-most: no objectFit set → CSS default fill (post PR #26 fix)"]
              }
            ]
          }
        }
        """#
    )

    // MARK: - object-position 3×3 grid (PR #26)

    /// 3×3 grid of `object-fit: cover` frames, each with a different
    /// `object-position` so authors see how cropping shifts. The source
    /// is wider than the frame so all 9 positions produce visibly
    /// different crops.
    static let objectPositionGrid = JoyDOMSample(
        id: "object-position-grid",
        label: "Image · object-position 3×3 grid",
        json: #"""
        {
          "version": 1,
          "style": {
            "#root": {
              "flexDirection": "column",
              "gap":     { "value": 12, "unit": "px" },
              "padding": { "value": 16, "unit": "px" }
            },
            ".row": {
              "flexDirection": "row",
              "gap": { "value": 8, "unit": "px" }
            },
            ".cell": {
              "width":  { "value": 110, "unit": "px" },
              "height": { "value": 80,  "unit": "px" },
              "overflow": "hidden",
              "borderWidth": { "value": 1, "unit": "px" },
              "borderColor": "#C8CFD9"
            },
            ".pic": {
              "width":  { "value": 100, "unit": "%" },
              "height": { "value": 100, "unit": "%" },
              "objectFit": "cover"
            },
            "#tl": { "objectPosition": { "horizontal": "left",   "vertical": "top"    } },
            "#tc": { "objectPosition": { "horizontal": "center", "vertical": "top"    } },
            "#tr": { "objectPosition": { "horizontal": "right",  "vertical": "top"    } },
            "#ml": { "objectPosition": { "horizontal": "left",   "vertical": "center" } },
            "#mc": { "objectPosition": { "horizontal": "center", "vertical": "center" } },
            "#mr": { "objectPosition": { "horizontal": "right",  "vertical": "center" } },
            "#bl": { "objectPosition": { "horizontal": "left",   "vertical": "bottom" } },
            "#bc": { "objectPosition": { "horizontal": "center", "vertical": "bottom" } },
            "#br": { "objectPosition": { "horizontal": "right",  "vertical": "bottom" } }
          },
          "breakpoints": [],
          "layout": {
            "type": "div",
            "props": { "id": "root" },
            "children": [
              { "type": "p", "props": {}, "children": ["object-position: 9 alignments × cover"] },
              { "type": "div", "props": { "className": ["row"] }, "children": [
                { "type": "div", "props": { "className": ["cell"] }, "children": [
                  { "type": "img", "props": { "id": "tl", "className": ["pic"],
                    "src": "https://picsum.photos/seed/joydom-pos/600/400" } } ]},
                { "type": "div", "props": { "className": ["cell"] }, "children": [
                  { "type": "img", "props": { "id": "tc", "className": ["pic"],
                    "src": "https://picsum.photos/seed/joydom-pos/600/400" } } ]},
                { "type": "div", "props": { "className": ["cell"] }, "children": [
                  { "type": "img", "props": { "id": "tr", "className": ["pic"],
                    "src": "https://picsum.photos/seed/joydom-pos/600/400" } } ]}
              ]},
              { "type": "div", "props": { "className": ["row"] }, "children": [
                { "type": "div", "props": { "className": ["cell"] }, "children": [
                  { "type": "img", "props": { "id": "ml", "className": ["pic"],
                    "src": "https://picsum.photos/seed/joydom-pos/600/400" } } ]},
                { "type": "div", "props": { "className": ["cell"] }, "children": [
                  { "type": "img", "props": { "id": "mc", "className": ["pic"],
                    "src": "https://picsum.photos/seed/joydom-pos/600/400" } } ]},
                { "type": "div", "props": { "className": ["cell"] }, "children": [
                  { "type": "img", "props": { "id": "mr", "className": ["pic"],
                    "src": "https://picsum.photos/seed/joydom-pos/600/400" } } ]}
              ]},
              { "type": "div", "props": { "className": ["row"] }, "children": [
                { "type": "div", "props": { "className": ["cell"] }, "children": [
                  { "type": "img", "props": { "id": "bl", "className": ["pic"],
                    "src": "https://picsum.photos/seed/joydom-pos/600/400" } } ]},
                { "type": "div", "props": { "className": ["cell"] }, "children": [
                  { "type": "img", "props": { "id": "bc", "className": ["pic"],
                    "src": "https://picsum.photos/seed/joydom-pos/600/400" } } ]},
                { "type": "div", "props": { "className": ["cell"] }, "children": [
                  { "type": "img", "props": { "id": "br", "className": ["pic"],
                    "src": "https://picsum.photos/seed/joydom-pos/600/400" } } ]}
              ]}
            ]
          }
        }
        """#
    )

    // MARK: - responsive hero (PR #26)

    /// Single hero image whose `object-fit` flips between viewports via a
    /// breakpoint — `cover` at narrow widths (full-bleed crop), `contain`
    /// at `>=768px` (letterboxed). Drag the viewport slider across 768px
    /// to see the live re-fit. Validates that the new field cascades
    /// through breakpoint overrides exactly like any other Style field.
    static let responsiveHero = JoyDOMSample(
        id: "responsive-hero",
        label: "Image · object-fit changes at breakpoint",
        json: #"""
        {
          "version": 1,
          "style": {
            "#root": {
              "flexDirection": "column",
              "gap":     { "value": 12, "unit": "px" },
              "padding": { "value": 16, "unit": "px" }
            },
            "#hint": {
              "fontSize": { "value": 13, "unit": "px" },
              "color":    "#475066"
            },
            "#frame": {
              "height":          { "value": 200, "unit": "px" },
              "width":           { "value": 100, "unit": "%"  },
              "backgroundColor": "#EEF1F6",
              "borderWidth":     { "value": 1, "unit": "px" },
              "borderColor":     "#C8CFD9",
              "overflow":        "hidden"
            },
            "#hero": {
              "width":  { "value": 100, "unit": "%" },
              "height": { "value": 100, "unit": "%" },
              "objectFit": "cover"
            }
          },
          "breakpoints": [
            {
              "conditions": [
                { "type": "feature", "name": "width", "operator": ">=", "value": 768, "unit": "px" }
              ],
              "nodes": {},
              "style": {
                "#hero": { "objectFit": "contain" }
              }
            }
          ],
          "layout": {
            "type": "div",
            "props": { "id": "root" },
            "children": [
              { "type": "p", "props": { "id": "hint" },
                "children": ["<768px: cover · ≥768px: contain"] },
              { "type": "div", "props": { "id": "frame" }, "children": [
                { "type": "img", "props": { "id": "hero",
                  "src": "https://picsum.photos/seed/joydom-hero/1200/600" } }
              ]}
            ]
          }
        }
        """#
    )
}
