---
name: Bug report
about: Something isn't laying out correctly
title: '[Bug] '
labels: bug
assignees: ''
---

## Describe the bug

A clear description of what is wrong.

## Minimal reproduction

Provide the smallest `FlexEngine.solve` call (or `FlexBox` snippet) that reproduces the issue:

```swift
let solution = FlexEngine.solve(
    config: .init(/* ... */),
    inputs: [
        .fixed(width: ..., height: ...),
    ],
    proposal: ProposedViewSize(width: ..., height: ...)
)
// solution.frames[0] == ???
```

## Expected behaviour

What frames / layout you expect.

## Actual behaviour

What frames / layout you actually get.

## Environment

- FlexLayout version:
- iOS / macOS version:
- Xcode version:
- Swift version:

## Additional context

Any other context, screenshots, or CSS equivalent that shows the correct behaviour.
