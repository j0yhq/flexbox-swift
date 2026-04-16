# ``FlexLayout``

A CSS Flexbox layout engine for SwiftUI — all major flex properties, fully spec-compliant, with a pure-Swift algorithm that is independently testable.

## Overview

`FlexLayout` lets you build complex, responsive UIs using the CSS Flexbox model you already know. Every major CSS flex property is supported: `flex-direction`, `flex-wrap`, `justify-content`, `align-items`, `align-content`, `align-self`, `flex-grow`, `flex-shrink`, `flex-basis`, `gap`, `row-gap`, `column-gap`, `padding`, `overflow`, `position: absolute`, `z-index`, `order`, `width`, and `height`.

### Getting started

The primary API is ``FlexBox`` — a `@ViewBuilder` view that mirrors the CSS container:

```swift
import SwiftUI
import FlexLayout

struct ContentView: View {
    var body: some View {
        // Three equal-width columns
        FlexBox(direction: .row, gap: 12) {
            Text("Column A").flexItem(flex: 1)
            Text("Column B").flexItem(flex: 1)
            Text("Column C").flexItem(flex: 1)
        }
    }
}
```

Apply per-item properties with `.flexItem(...)`:

```swift
FlexBox(direction: .row, alignItems: .center) {
    Image(systemName: "star")
    Text("Title").flexItem(grow: 1)          // fill remaining space
    Text("Badge")
        .flexItem(position: .absolute,        // removed from flow
                  top: 4, trailing: 4)
}
```

### Architecture

```
FlexBox (View)
  └── FlexLayout (Layout protocol)
        └── FlexEngine (pure algorithm — fully unit-testable)
              ├── FlexItemInput    (per-item inputs)
              ├── ComputedFlexLine (per-line results)
              └── FlexSolution     (final frames)
```

`FlexEngine` is decoupled from SwiftUI so every algorithm phase — grow, shrink,
justify-content, align-content, absolute positioning — can be exercised in plain
`XCTest` without a view hierarchy.

## Topics

### Articles

- <doc:GettingStarted>
- <doc:CSSPropertyReference>

### Essential views

- ``FlexBox``
- ``FlexLayout``

### Container properties

- ``FlexContainerConfig``
- ``FlexDirection``
- ``FlexWrap``
- ``JustifyContent``
- ``AlignItems``
- ``AlignContent``
- ``FlexOverflow``

### Item properties

- ``FlexBasis``
- ``AlignSelf``
- ``FlexSize``
- ``FlexPosition``
- ``FlexDisplay``

### View modifiers

- ``FlexItemModifier``
- ``FlexOverflowModifier``

### Layout value keys

- ``FlexGrowKey``
- ``FlexShrinkKey``
- ``FlexBasisKey``
- ``AlignSelfKey``
- ``FlexOrderKey``
- ``FlexWidthKey``
- ``FlexHeightKey``
- ``FlexOverflowKey``
- ``FlexZIndexKey``
- ``FlexPositionKey``
- ``FlexTopKey``
- ``FlexBottomKey``
- ``FlexLeadingKey``
- ``FlexTrailingKey``
- ``FlexDisplayKey``

### Pure algorithm (advanced / testing)

- ``FlexEngine``
- ``FlexItemInput``
- ``FlexSolution``
