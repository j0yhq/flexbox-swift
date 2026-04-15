# Getting Started with FlexLayout

Build your first flex layout in five minutes.

## Installation

### Swift Package Manager

Add the package to your `Package.swift`:

```swift
dependencies: [
    .package(url: "https://github.com/joyfill/flex-layout.git", from: "1.0.0"),
],
targets: [
    .target(name: "MyApp", dependencies: ["FlexLayout"]),
]
```

Or in Xcode: **File → Add Packages** and paste the repository URL.

## Basic concepts

`FlexLayout` maps one-to-one to CSS Flexbox. If you know CSS, you already know the API.

| CSS                        | Swift                                                    |
|----------------------------|----------------------------------------------------------|
| `flex-direction: row`      | `FlexBox(direction: .row)`                               |
| `flex-wrap: wrap`          | `FlexBox(wrap: .wrap)`                                   |
| `justify-content: center`  | `FlexBox(justifyContent: .center)`                       |
| `align-items: stretch`     | `FlexBox(alignItems: .stretch)`                          |
| `gap: 12px`                | `FlexBox(gap: 12)`                                       |
| `flex: 1`                  | `.flexItem(flex: 1)`                                     |
| `flex-grow: 1`             | `.flexItem(grow: 1)`                                     |
| `flex-shrink: 0`           | `.flexItem(shrink: 0)`                                   |
| `flex-basis: 160px`        | `.flexItem(basis: .points(160))`                         |
| `align-self: flex-end`     | `.flexItem(alignSelf: .flexEnd)`                         |
| `order: -1`                | `.flexItem(order: -1)`                                   |
| `width: 50%`               | `.flexItem(width: .fraction(0.5))`                       |
| `position: absolute`       | `.flexItem(position: .absolute, top: 0, trailing: 0)`    |
| `z-index: 10`              | `.flexItem(zIndex: 10)`                                  |
| `overflow: hidden`         | `FlexBox(overflow: .hidden)` or `.flexOverflow(.hidden)` |

## Your first FlexBox

```swift
import SwiftUI
import FlexLayout

struct NavBar: View {
    var body: some View {
        FlexBox(
            direction:      .row,
            alignItems:     .center,
            justifyContent: .spaceBetween,
            padding:        EdgeInsets(top: 12, leading: 16, bottom: 12, trailing: 16)
        ) {
            Text("🌟 MyApp")
                .font(.headline)

            // This spacer grows to push the button to the right
            Color.clear.flexItem(grow: 1)

            Button("Sign in") { }
        }
        .background(Color(.systemBackground))
        .shadow(radius: 2)
    }
}
```

## Card grid

A wrapping grid where cards have a minimum width of 160 pt:

```swift
struct CardGrid: View {
    let items: [Item]

    var body: some View {
        FlexBox(
            wrap:           .wrap,
            justifyContent: .flexStart,
            alignContent:   .flexStart,
            gap:            16,
            padding:        EdgeInsets(top: 16, leading: 16, bottom: 16, trailing: 16)
        ) {
            ForEach(items) { item in
                CardView(item: item)
                    .flexItem(basis: .points(160), grow: 1, shrink: 0)
            }
        }
    }
}
```

## Sidebar + content

```swift
struct SidebarLayout: View {
    var body: some View {
        FlexBox(direction: .row) {
            SidebarView()
                .flexItem(basis: .points(240), shrink: 0)  // fixed-width sidebar

            Divider()

            ContentView()
                .flexItem(grow: 1)                          // fill remaining space
        }
    }
}
```

## Absolute positioning

Remove an item from the flex flow and pin it to the container's corner:

```swift
FlexBox(direction: .row, alignItems: .center, gap: 8) {
    Image(systemName: "envelope")
    Text("Inbox")

    // Badge floats over the icon, not in the flex flow
    Text("3")
        .font(.caption2.bold())
        .padding(4)
        .background(Color.red)
        .clipShape(Circle())
        .flexItem(position: .absolute, top: -4, leading: 12)
}
```

## Overflow and scrolling

```swift
// Horizontal scrolling chip bar
FlexBox(direction: .row, wrap: .nowrap, gap: 8, overflow: .scroll) {
    ForEach(tags) { tag in
        Text(tag.name)
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .background(Capsule().fill(Color.accentColor.opacity(0.15)))
    }
}
```

## Z-index layering

```swift
FlexBox(direction: .row, gap: -20) {  // negative gap for overlap
    ForEach(Array(avatars.enumerated()), id: \.offset) { i, avatar in
        AvatarView(avatar)
            .flexItem(zIndex: i)  // later avatars stack on top
    }
}
```

## Using `FlexLayout` directly

For `AnyLayout` switching or custom `Layout` compositions, use `FlexLayout` directly:

```swift
struct AdaptiveStack: View {
    @Environment(\.horizontalSizeClass) var sizeClass

    var body: some View {
        let layout: AnyLayout = (sizeClass == .compact)
            ? AnyLayout(FlexLayout(.init(direction: .column, gap: 8)))
            : AnyLayout(FlexLayout(.init(direction: .row,    gap: 16)))

        layout {
            FeatureView()
            FeatureView()
            FeatureView()
        }
    }
}
```

## Testing layouts without SwiftUI

`FlexEngine` is fully decoupled from SwiftUI. Use it in plain `XCTest` to assert
exact pixel positions:

```swift
import XCTest
@testable import FlexLayout

class MyLayoutTests: XCTestCase {
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
