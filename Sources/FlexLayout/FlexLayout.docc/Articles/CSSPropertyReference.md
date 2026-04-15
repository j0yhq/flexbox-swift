# CSS Property Reference

Complete mapping of every CSS Flexbox property to its `FlexLayout` Swift equivalent.

## Container properties

Set on ``FlexBox`` or ``FlexContainerConfig``.

### flex-direction

Controls the main axis direction.

| CSS value          | Swift                         |
|--------------------|-------------------------------|
| `row` (default)    | `.direction(.row)`            |
| `row-reverse`      | `.direction(.rowReverse)`     |
| `column`           | `.direction(.column)`         |
| `column-reverse`   | `.direction(.columnReverse)`  |

```swift
FlexBox(direction: .column, gap: 8) {
    Text("Top")
    Text("Middle")
    Text("Bottom")
}
```

### flex-wrap

Controls whether items wrap onto multiple lines.

| CSS value          | Swift                      |
|--------------------|----------------------------|
| `nowrap` (default) | `.wrap(.nowrap)`           |
| `wrap`             | `.wrap(.wrap)`             |
| `wrap-reverse`     | `.wrap(.wrapReverse)`      |

```swift
// Wrapping photo grid
FlexBox(wrap: .wrap, gap: 4) {
    ForEach(photos) { photo in
        PhotoThumb(photo)
            .flexItem(width: .points(80), height: .points(80))
    }
}
```

### justify-content

Distributes free space along the **main** axis.

| CSS value                        | Swift                              |
|----------------------------------|------------------------------------|
| `flex-start` (default)           | `.justifyContent(.flexStart)`      |
| `flex-end`                       | `.justifyContent(.flexEnd)`        |
| `center`                         | `.justifyContent(.center)`         |
| `space-between`                  | `.justifyContent(.spaceBetween)`   |
| `space-around`                   | `.justifyContent(.spaceAround)`    |
| `space-evenly`                   | `.justifyContent(.spaceEvenly)`    |

```swift
// Logo | spacer | actions
FlexBox(direction: .row, justifyContent: .spaceBetween) {
    LogoView()
    ActionsView()
}
```

### align-items

Aligns items on the **cross** axis within a single line.

| CSS value         | Swift                       |
|-------------------|-----------------------------|
| `stretch` (default)| `.alignItems(.stretch)`    |
| `flex-start`      | `.alignItems(.flexStart)`   |
| `flex-end`        | `.alignItems(.flexEnd)`     |
| `center`          | `.alignItems(.center)`      |
| `baseline`        | `.alignItems(.baseline)`    |

```swift
// Vertically center icon and label
FlexBox(direction: .row, alignItems: .center, gap: 8) {
    Image(systemName: "star.fill")
    Text("Favourites")
}
```

### align-content

Distributes flex **lines** on the cross axis (multi-line only).

| CSS value              | Swift                          |
|------------------------|--------------------------------|
| `stretch` (default)    | `.alignContent(.stretch)`      |
| `flex-start`           | `.alignContent(.flexStart)`    |
| `flex-end`             | `.alignContent(.flexEnd)`      |
| `center`               | `.alignContent(.center)`       |
| `space-between`        | `.alignContent(.spaceBetween)` |
| `space-around`         | `.alignContent(.spaceAround)`  |
| `space-evenly`         | `.alignContent(.spaceEvenly)`  |

```swift
FlexBox(wrap: .wrap, alignContent: .center, gap: 8) {
    // Lines are grouped in the centre of the container's cross axis
}
```

### gap / row-gap / column-gap

Adds gutters between items and/or lines.

| CSS              | Swift                        | Description                   |
|------------------|------------------------------|-------------------------------|
| `gap: 16px`      | `gap: 16`                    | Both axes                     |
| `row-gap: 24px`  | `rowGap: 24`                 | Between lines (cross axis)    |
| `column-gap: 8px`| `columnGap: 8`               | Between items (main axis)     |

```swift
FlexBox(wrap: .wrap, gap: 16, rowGap: 24) {
    // 16 pt between items, 24 pt between lines
}
```

### padding

Inner spacing between the container boundary and its children.

```swift
let pad = EdgeInsets(top: 20, leading: 16, bottom: 20, trailing: 16)
FlexBox(padding: pad) { ... }
```

### overflow

How content that overflows the container is rendered.

| CSS value         | Swift                   | Behaviour                           |
|-------------------|-------------------------|-------------------------------------|
| `visible` (default)| `.overflow(.visible)`  | Content draws outside bounds        |
| `hidden`          | `.overflow(.hidden)`    | Clipped, no scroll                  |
| `clip`            | `.overflow(.clip)`      | Same as hidden (CSS parity)         |
| `scroll`          | `.overflow(.scroll)`    | Always shows scroll bars            |
| `auto`            | `.overflow(.auto)`      | Scroll only when content overflows  |

```swift
// Horizontal scrolling row
FlexBox(direction: .row, wrap: .nowrap, overflow: .auto) {
    ForEach(items) { ItemView($0).flexItem(shrink: 0) }
}
```

---

## Item properties

Apply to child views of a ``FlexBox`` using `.flexItem(...)`.

### flex-grow

```swift
// Fill all available space
Text("Content").flexItem(grow: 1)

// Share space 2:1 between two items
LeftView().flexItem(grow: 2)
RightView().flexItem(grow: 1)
```

### flex-shrink

```swift
// Never shrink (sidebar)
SidebarView().flexItem(shrink: 0)

// Shrink proportionally (default: 1)
ContentView().flexItem(shrink: 1)
```

### flex-basis

Sets the initial main-axis size before grow/shrink runs.

```swift
CardView().flexItem(basis: .points(200))        // fixed 200 pt
CardView().flexItem(basis: .fraction(0.33))     // 33 % of container
CardView().flexItem(basis: .auto)               // intrinsic size (default)
```

### flex (shorthand)

`flex: n` = `grow: n, shrink: 1, basis: .points(0)`

```swift
// Three equal-width columns
Text("A").flexItem(flex: 1)
Text("B").flexItem(flex: 1)
Text("C").flexItem(flex: 1)
```

### align-self

Overrides the container's `align-items` for a single item.

```swift
FlexBox(direction: .row, alignItems: .stretch) {
    Text("Normal")
    Text("Centered").flexItem(alignSelf: .center)
    Text("Bottom").flexItem(alignSelf: .flexEnd)
}
```

### order

Changes the visual order without changing source order.

```swift
// Source: [A, B, C] → Visual: [B, C, A]
Text("A").flexItem(order: 3)
Text("B").flexItem(order: 1)
Text("C").flexItem(order: 2)
```

### width / height

Explicit size overrides (take precedence over intrinsic measurement).

```swift
Text("Label").flexItem(width: .points(120))         // fixed 120 pt
ColumnView().flexItem(width: .fraction(0.5))        // 50 % of container
Text("Compact").flexItem(width: .minContent)        // min intrinsic width
ChartView().flexItem(height: .points(200))          // fixed 200 pt height
```

### position: absolute

Removes the item from the flex flow. Position is relative to the flex container.

```swift
FlexBox(direction: .row) {
    Text("In flow A")
    Text("In flow B")

    // Overlay: top-right corner
    BadgeView()
        .flexItem(position: .absolute, top: 0, trailing: 0)

    // Stretch between leading=20 and trailing=20
    OverlayBanner()
        .flexItem(position: .absolute, top: 8, leading: 20, trailing: 20)
}
```

### z-index

```swift
// Stack three overlapping circles; later items appear on top
ForEach(Array(colors.enumerated()), id: \.offset) { i, color in
    Circle().fill(color)
        .flexItem(zIndex: i, position: .absolute, leading: CGFloat(i * 20))
}
```

### overflow (item-level)

```swift
// Clip one item without affecting its siblings
LongTextView()
    .flexItem(overflow: .hidden)

// Or use the shorthand modifier:
LongTextView()
    .flexOverflow(.hidden)
```

---

## Quick-reference card

```swift
FlexBox(
    direction:      .row,          // flex-direction
    wrap:           .wrap,         // flex-wrap
    justifyContent: .spaceBetween, // justify-content
    alignItems:     .center,       // align-items
    alignContent:   .flexStart,    // align-content (multi-line)
    gap:            12,            // gap (both axes)
    rowGap:         20,            // row-gap (lines only)
    columnGap:      8,             // column-gap (items only)
    padding:        .init(top: 16, leading: 16, bottom: 16, trailing: 16),
    overflow:       .auto          // overflow
) {
    SidebarView()
        .flexItem(
            grow:      0,             // flex-grow
            shrink:    0,             // flex-shrink
            basis:     .points(240),  // flex-basis
            alignSelf: .flexStart,    // align-self
            order:     0,             // order
            width:     .auto,         // width
            height:    .auto,         // height
            overflow:  .visible,      // overflow (item)
            zIndex:    0,             // z-index
            position:  .relative      // position
        )

    ContentView()
        .flexItem(grow: 1)

    BadgeView()
        .flexItem(
            zIndex:   10,            // z-index
            position: .absolute,     // position: absolute
            top:      8,             // top
            trailing: 8              // right
        )
}
```
