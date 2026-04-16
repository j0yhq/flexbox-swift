# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [1.0.0] - 2026-04-16

### Added

#### Core library
- Full CSS Flexbox layout engine via SwiftUI's `Layout` protocol
- `FlexBox` — `@ViewBuilder` view with all container properties as labelled parameters
- `FlexLayout` — low-level `Layout` conformance for `AnyLayout` and custom compositions
- `FlexEngine` — pure-Swift algorithm fully decoupled from SwiftUI (testable without a view hierarchy)

#### Supported CSS properties
- **Container:** `flex-direction` (all 4), `flex-wrap` (all 3), `justify-content` (all 6), `align-items` (5), `align-content` (7 inc. stretch redistribution), `gap`, `row-gap`, `column-gap`, `padding`, `overflow` (visible/hidden/clip/scroll/auto)
- **Items:** `flex-grow`, `flex-shrink`, `flex-basis` (auto/points/fraction/min-content), `align-self` (6), `order`, `width` (auto/points/fraction/min-content), `height`, `position: absolute`, `z-index` (with DOM-order tie-breaking), `display` (blockification)
- **Shorthand:** `flex: n` via `.flexItem(flex:)` → grow: n, shrink: 1, basis: 0

#### Testing
- `FlexGeometryTests` — 63 geometry tests asserting exact `CGRect` frames via `FlexEngine.solve`
- `CSSParserTests` — 33 CSS string parser tests including all-values coverage and invalid-value fallbacks
- `FlexLayoutTests` — 7 algorithm unit tests (gap axis, align-self resolution, single-line cross rule)
- 103 tests total, 0 failures

#### Documentation
- DocC catalog with module overview, Getting Started guide, and full CSS Property Reference
- Inline doc-comments on every public type and method with code examples
- CSS ↔ Swift property mapping tables
- Algorithm phase annotations in `FlexEngine.swift` matching CSS spec §9

#### Samples
- 12 real-world CSS layout samples in `Samples/` (navbar, sidebar, card grid, holy grail, dashboard, and more)

#### CI
- GitHub Actions workflow running `swift test` on every PR and push to `main`
- macOS 14 runner, Swift 5.9
