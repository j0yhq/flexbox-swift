# FlexLayout

[![CI](https://github.com/joyfill/flex-layout/actions/workflows/ci.yml/badge.svg)](https://github.com/joyfill/flex-layout/actions/workflows/ci.yml)
[![Swift 5.9+](https://img.shields.io/badge/Swift-5.9%2B-orange.svg)](https://swift.org)
[![Platforms](https://img.shields.io/badge/platforms-iOS%2016%20%7C%20macOS%2013%20%7C%20tvOS%2016%20%7C%20watchOS%209-lightgrey.svg)](https://developer.apple.com/swift/)
[![License: MIT](https://img.shields.io/badge/License-MIT-blue.svg)](LICENSE)
[![SPM](https://img.shields.io/badge/SwiftPM-compatible-brightgreen.svg)](https://swift.org/package-manager/)

A full-featured CSS Flexbox layout engine for SwiftUI — every major flex property, spec-compliant algorithm, independently unit-testable.

---

## Features

- **Complete CSS parity** — `flex-direction`, `flex-wrap`, `justify-content`, `align-items`, `align-content`, `align-self`, `flex-grow`, `flex-shrink`, `flex-basis`, `gap`, `row-gap`, `column-gap`, `padding`, `overflow`, `position: absolute`, `z-index`, `order`, `width`, `height`
- **SwiftUI native** — conforms to the `Layout` protocol; works with `AnyLayout` switching, animations, and all SwiftUI modifiers
- **Testable pure engine** — `FlexEngine` is decoupled from SwiftUI so every layout phase can be asserted in plain `XCTest` without a view hierarchy
- **DocC API reference** — full documentation with code examples, a Getting Started guide, and a CSS property reference
- **103 passing tests** — geometry tests, CSS parser tests, and algorithm unit tests

---

## Requirements

| Platform | Minimum version |
|----------|----------------|
| iOS      | 16.0           |
| macOS    | 13.0           |
| tvOS     | 16.0           |
| watchOS  | 9.0            |

---

## Installation

### Swift Package Manager

Add the package in Xcode via **File → Add Package Dependencies** and enter:

```
https://github.com/joyfill/flex-layout
```

Or add it to your `Package.swift`:

```swift
dependencies: [
    .package(url: "https://github.com/joyfill/flex-layout.git", from: "1.0.0"),
],
targets: [
    .target(name: "MyApp", dependencies: ["FlexLayout"]),
]
```

---

## Quick start

```swift
import SwiftUI
import FlexLayout

struct ContentView: View {
    var body: some View {
        // Three equal-width columns (CSS "flex: 1" pattern)
        FlexBox(direction: .row, gap: 12) {
            Text("Column A").flexItem(flex: 1)
            Text("Column B").flexItem(flex: 1)
            Text("Column C").flexItem(flex: 1)
        }
    }
}
```

---

## Usage

### Container

Use `FlexBox` as the main entry point. Every parameter mirrors its CSS counterpart:

```swift
FlexBox(
    direction:      .row,           // flex-direction
    wrap:           .wrap,          // flex-wrap
    justifyContent: .spaceBetween,  // justify-content
    alignItems:     .center,        // align-items
    gap:            16,             // gap
    padding:        EdgeInsets(top: 20, leading: 20, bottom: 20, trailing: 20),
    overflow:       .auto           // overflow
) {
    // child views
}
```

### Items

Apply per-item flex properties with `.flexItem(...)`:

```swift
// Grow to fill remaining space
Text("Title").flexItem(grow: 1)

// Fixed-width sidebar that never shrinks
SidebarView().flexItem(basis: .points(240), shrink: 0)

// Override cross-axis alignment
Image(systemName: "star").flexItem(alignSelf: .flexEnd)

// Absolutely positioned badge (removed from flex flow)
Text("NEW").flexItem(position: .absolute, top: 4, trailing: 4)
```

### Common patterns

#### Navigation bar

```swift
FlexBox(direction: .row, alignItems: .center, padding: EdgeInsets(top: 12, leading: 16, bottom: 12, trailing: 16)) {
    Text("Logo").font(.headline)
    Color.clear.flexItem(grow: 1)  // spacer
    Button("Sign in") { }
}
```

#### Wrapping card grid

```swift
FlexBox(wrap: .wrap, justifyContent: .flexStart, gap: 16) {
    ForEach(items) { item in
        CardView(item: item)
            .flexItem(basis: .points(160), grow: 1, shrink: 0)
    }
}
```

#### Sidebar + content

```swift
FlexBox(direction: .row) {
    SidebarView().flexItem(basis: .points(240), shrink: 0)
    ContentView().flexItem(grow: 1)
}
```

#### Responsive `AnyLayout` switch

```swift
let layout: AnyLayout = isCompact
    ? AnyLayout(FlexLayout(.init(direction: .column, gap: 8)))
    : AnyLayout(FlexLayout(.init(direction: .row,    gap: 16)))

layout { ... }
```

---

## CSS property reference

| CSS Property | Swift API |
|---|---|
| `flex-direction: row` | `FlexBox(direction: .row)` |
| `flex-wrap: wrap` | `FlexBox(wrap: .wrap)` |
| `justify-content: space-between` | `FlexBox(justifyContent: .spaceBetween)` |
| `align-items: center` | `FlexBox(alignItems: .center)` |
| `align-content: flex-start` | `FlexBox(alignContent: .flexStart)` |
| `gap: 16px` | `FlexBox(gap: 16)` |
| `row-gap: 24px` | `FlexBox(rowGap: 24)` |
| `column-gap: 8px` | `FlexBox(columnGap: 8)` |
| `padding: 20px` | `FlexBox(padding: EdgeInsets(...))` |
| `overflow: auto` | `FlexBox(overflow: .auto)` |
| `flex: 1` | `.flexItem(flex: 1)` |
| `flex-grow: 2` | `.flexItem(grow: 2)` |
| `flex-shrink: 0` | `.flexItem(shrink: 0)` |
| `flex-basis: 160px` | `.flexItem(basis: .points(160))` |
| `flex-basis: 50%` | `.flexItem(basis: .fraction(0.5))` |
| `align-self: flex-end` | `.flexItem(alignSelf: .flexEnd)` |
| `order: -1` | `.flexItem(order: -1)` |
| `width: 50%` | `.flexItem(width: .fraction(0.5))` |
| `height: 80px` | `.flexItem(height: .points(80))` |
| `position: absolute` | `.flexItem(position: .absolute, top: 0, trailing: 0)` |
| `z-index: 10` | `.flexItem(zIndex: 10)` |

Full reference: [CSS Property Reference](Sources/FlexLayout/FlexLayout.docc/Articles/CSSPropertyReference.md)

---

## Testing layouts

`FlexEngine` is fully decoupled from SwiftUI. Write geometry tests with exact `CGRect` assertions — no host app or view hierarchy needed:

```swift
import XCTest
@testable import FlexLayout

class ColumnLayoutTests: XCTestCase {
    func testThreeEqualColumns() {
        let solution = FlexEngine.solve(
            config: .init(direction: .row),
            inputs: [
                .fixed(width: 0, height: 50, grow: 1),
                .fixed(width: 0, height: 50, grow: 1),
                .fixed(width: 0, height: 50, grow: 1),
            ],
            proposal: ProposedViewSize(width: 300, height: 100)
        )

        XCTAssertEqual(solution.frames[0].width,  100, accuracy: 0.5)
        XCTAssertEqual(solution.frames[1].minX,   100, accuracy: 0.5)
        XCTAssertEqual(solution.frames[2].minX,   200, accuracy: 0.5)
    }
}
```

---

## Documentation

Generate and preview the full API reference locally:

```bash
# 1. Emit the symbol graph
swift build --target FlexLayout \
  -Xswiftc -emit-symbol-graph \
  -Xswiftc -emit-symbol-graph-dir \
  -Xswiftc /tmp/flex-symbols

# 2. Launch the DocC preview server
xcrun docc preview Sources/FlexLayout/FlexLayout.docc \
  --fallback-display-name FlexLayout \
  --fallback-bundle-identifier com.joyfill.FlexLayout \
  --fallback-bundle-version 1.0.0 \
  --additional-symbol-graph-dir /tmp/flex-symbols \
  --port 8080

# 3. Open http://localhost:8080/documentation/flexlayout
```

---

## Architecture

```
FlexBox (View)
  └── FlexLayout (Layout protocol — SwiftUI adapter)
        └── FlexEngine (pure algorithm — no SwiftUI dependency)
              ├── FlexItemInput    (per-item inputs with measure closure)
              ├── ComputedFlexLine (per-line resolved data)
              └── FlexSolution     (final frames + proposals)
```

The algorithm follows the CSS Flexbox spec §9 in 10 annotated phases. See [`FlexEngine.swift`](Sources/FlexLayout/FlexEngine.swift) for the full implementation.

---

## Samples

The [`Samples/`](Samples/) directory contains 12 real-world CSS layouts that can be rendered directly through the CSS parser:

| File | Layout |
|---|---|
| `01-navbar.css` | Navigation bar with spacer |
| `02-sidebar-layout.css` | Fixed sidebar + fluid content |
| `03-card-grid.css` | Wrapping card grid |
| `04-holy-grail.css` | Holy grail (header, sidebar, main, sidebar, footer) |
| `05-dashboard.css` | Analytics dashboard |
| `06-absolute-positioning.css` | Badges and overlays |
| `07-chat-ui.css` | Chat message list |
| `08-pricing-table.css` | Pricing cards |
| `09-media-feed.css` | Media feed |
| `10-ecommerce-product.css` | Product detail page |
| `11-settings-page.css` | Settings list |
| `12-overflow-scroll.css` | Horizontal scrolling tabs |

---

## Contributing

Contributions are welcome! Please read [CONTRIBUTING.md](CONTRIBUTING.md) before opening a PR.

---

## License

[MIT](LICENSE) © 2026 Joyfill
