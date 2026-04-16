# Contributing to FlexLayout

Thank you for your interest in contributing! This document explains how to get started.

## Development setup

```bash
git clone https://github.com/joyfill/flex-layout.git
cd flex-layout
swift build
swift test
```

All 103 tests should pass before you open a PR.

## Project structure

```
Sources/FlexLayout/
├── FlexEngine.swift       Pure flex algorithm — no SwiftUI dependency
├── FlexLayout.swift       SwiftUI Layout adapter
├── FlexTypes.swift        Public enums and FlexContainerConfig
├── FlexModifiers.swift    .flexItem(...) and .flexOverflow(...) view extensions
├── FlexLayoutKeys.swift   LayoutValueKey declarations
├── FlexView.swift         FlexBox convenience view
└── FlexLayout.docc/       DocC documentation catalog

Tests/
├── FlexLayoutTests/
│   ├── FlexGeometryTests.swift   63 geometry tests via FlexEngine.solve
│   └── FlexLayoutTests.swift     7 algorithm unit tests
└── FlexDemoAppTests/
    └── CSSParserTests.swift      33 CSS parser tests
```

## Guidelines

### Adding a new CSS property

1. Add the enum case or field to `FlexTypes.swift`
2. Add the `LayoutValueKey` to `FlexLayoutKeys.swift`
3. Add the parameter to `FlexItemModifier` and `View.flexItem(...)` in `FlexModifiers.swift`
4. Read the key in `FlexLayout.makeInputs(from:)` and pass it through `FlexItemInput`
5. Implement the behaviour in `FlexEngine` (or `FlexLayout` if SwiftUI-specific)
6. Add geometry tests in `FlexGeometryTests.swift`
7. Add parser tests in `CSSParserTests.swift` if applicable
8. Update the DocC articles

### Writing tests

Geometry tests use `FlexEngine.solve` directly — no SwiftUI needed:

```swift
func testMyFeature() {
    let frames = FlexEngine.solve(
        config: .init(/* your config */),
        inputs: [.fixed(width: 100, height: 50), ...],
        proposal: ProposedViewSize(width: 300, height: 200)
    ).frames

    XCTAssertEqual(frames[0].minX, 0,   accuracy: 0.5)
    XCTAssertEqual(frames[0].width, 100, accuracy: 0.5)
}
```

Use `accuracy: 0.5` for all `CGFloat` assertions to handle sub-point rounding.

### Code style

- Match the existing Swift style (4-space indent, aligned colons in declarations)
- Every public type and method needs a DocC doc-comment with at least one code example
- Keep `FlexEngine` free of SwiftUI imports — it must remain pure Swift

### Running the demo app

```bash
open FlexLayoutDemo.xcworkspace
```

Select the `FlexDemoApp` scheme and run on any iOS 16+ simulator.

## Submitting a PR

1. Fork the repo and create a branch: `git checkout -b feat/my-feature`
2. Make your changes with tests
3. Confirm `swift test` passes: 103+ tests, 0 failures
4. Open a PR against `main` — fill in the PR template

## Reporting bugs

Use the [bug report template](.github/ISSUE_TEMPLATE/bug_report.md). Include:
- iOS / macOS version
- Minimal reproduction case (ideally a `FlexEngine.solve` call)
- Expected vs actual frame values
