# CSSLayout — Design & Implementation Plan

**Status:** Draft v1
**Owner:** @VishnuBishnoi
**Target:** Layer 3 of the Joyfill Native UI Platform
**Depends on:** `flexbox-swift` (FlexLayout)

---

## 1. Vision

Build a **server-driven native UI platform** in which a backend can ship a CSS payload + component manifest and have it render as a native SwiftUI (and later Jetpack Compose / Web) UI — **layout-identical across platforms** (visual styling is owned by the component factories, not the CSS layer), no app update required.

`CSSLayout` is **Layer 3** of that stack: the layer that turns CSS + component IDs into a live SwiftUI view tree, backed by the FlexLayout engine we already built.

```
┌─────────────────────────────────────────────────────────┐
│  L4 — Application                                       │
│       Registers component library, handles events,      │
│       fetches CSS/schema from server.                   │
├─────────────────────────────────────────────────────────┤
│  L3 — CSSLayout  ← this document                        │
│       CSS parser · style tree · component registry ·    │
│       event bus · placeholder slots · async loading.    │
├─────────────────────────────────────────────────────────┤
│  L2 — FlexLayout (flexbox-swift)                        │
│       Pure-Swift flexbox algorithm + Layout protocol.   │
├─────────────────────────────────────────────────────────┤
│  L1 — SwiftUI / Native renderers                        │
│       iOS · macOS · visionOS · watchOS.                 │
└─────────────────────────────────────────────────────────┘
```

---

## 2. Goals & Non-Goals

### Goals

- **G1.** Parse standard CSS (subset — see §4.1) and produce a valid FlexLayout render tree.
- **G2.** The **same CSS string** must render with pixel-equivalent **flex layout behavior** on web (Chrome/Safari flexbox) and native (FlexLayout). Visual styling is out of scope — see §4.1.
- **G3.** Components are **registered by type** at app startup and **instantiated by instance-ID** per screen.
- **G4.** A **SwiftUI-native event API** with bubbling, serialization, and server round-trip support.
- **G5.** Robust against **malformed / incomplete CSS** from untrusted servers — never crash, always render something.
- **G6.** **Unknown IDs** render a debuggable placeholder; **registered-but-unused** components are silently skipped.
- **G7.** Support **full nesting** (`#form > #row > #field`, descendant combinators, specificity).
- **G8.** **Hot-swap** CSS at runtime without losing bound state.

### Non-Goals (for v1)

- **Any CSS outside the flexbox subset in §4.1.** No `grid`, `float`, `table`, pseudo-elements, animations, transforms.
- **Visual / typography properties** (`background-*`, `border-*`, `color`, `font-*`, `box-shadow`, `opacity`, `transition`, …). These belong to a separate styling layer on top of CSSLayout.
- **`margin`, `min-*`, `max-*` sizing** until corresponding APIs land in `FlexLayout` first.
- **`@media` and other at-rules.** Breakpoint handling is a separate concern.
- Custom CSS extensions / preprocessor syntax (SCSS, Less).
- Design-time authoring tools (inspector, live-edit).
- Cross-platform rendering (Android/Web). Reserved for future layers.
- Accessibility tree customization via CSS (uses SwiftUI defaults).

---

## 3. Primary Use Cases

1. **Server-driven forms.** Backend controls form field order, layout, required state. Client ships once.
2. **A/B experimentation.** Try two layouts without app releases.
3. **Per-tenant theming.** Multi-brand apps (Joyfill clients) render customized flows.
4. **Live dashboards.** Config-driven screens that change per-role/per-state.
5. **Future — fully-dynamic apps.** Foundation layer for entire app surfaces driven by JSON + CSS.

---

## 4. Detailed Design

### 4.1 CSS Subset (v1 scope)

The CSS subset supported is **exactly the set of properties that map to `FlexLayout`'s public API**. CSSLayout is a thin parser + resolver that produces a FlexLayout tree; it does **not** own any layout math or visual styling of its own. Anything not in the table below is intentionally deferred — visual styling (`background-color`, `border-radius`, `color`, `font-*`, `box-shadow`, …), `margin`, and `min-*` / `max-*` sizing belong to a separate layer built on top of CSSLayout.

**Selectors**

| Selector | Example | v1 |
|---|---|---|
| ID | `#submit` | Yes |
| Class | `.primary` | Yes |
| Element (component type) | `button`, `text-input` | Yes |
| Child combinator | `#form > #row` | Yes |
| Descendant combinator | `#form #field` | Yes |
| Grouping | `#a, #b` | Yes |
| Attribute | `[data-role="primary"]` | No |
| Pseudo | `:hover`, `::before` | No |

**Supported properties** (exactly what `FlexLayout` exposes)

| Group | Properties | FlexLayout mapping |
|---|---|---|
| Flex container | `flex-direction`, `flex-wrap`, `justify-content`, `align-items`, `align-content`, `gap`, `row-gap`, `column-gap`, `padding` / `padding-*`, `overflow` | `FlexContainerConfig` |
| Flex item | `flex`, `flex-grow`, `flex-shrink`, `flex-basis`, `align-self`, `order`, `width`, `height`, `overflow` | `.flexItem(...)` |
| Positioning (item) | `position: relative \| absolute`, `top`, `right`, `bottom`, `left`, `z-index` | `.flexItem(position:…, top:…, …)` |
| `display` | `flex`, `block`, `inline` (parity only — flex items are blockified per CSS spec) | `FlexDisplayKey` |

**Explicitly out of scope for v1** (intentionally not parsed; see behavior table below)

- `margin`, `margin-*`
- `min-width`, `min-height`, `max-width`, `max-height`
- Visibility: `display: none`, `visibility`, `opacity`
- Visual: `background-color`, `border-radius`, `border`, `color`, `box-shadow`, `font-*`, `transition`, `transform`, filters, animations
- Layout modes other than flex: `grid`, `float`, `table`, `block` formatting contexts
- Pseudo-elements / pseudo-classes: `:hover`, `::before`, `::after`, etc.
- `@media` and other at-rules

These require either adding new APIs to `FlexLayout` (for `margin`, `min-*`, `max-*`) or a separate styling layer built on top of CSSLayout (for visual properties). Do not implement them inside CSSLayout.

**Behavior when CSS contains unsupported properties**

| Input | Behavior |
|---|---|
| `margin: 8px`, `margin-left: 4px`, … | Warn in debug via diagnostic channel; ignore in release |
| `min-width: 100px`, `max-height: 200px`, … | Warn in debug; ignore. *(Until a corresponding `FlexLayout` API exists.)* |
| `background`, `color`, `border-radius`, `font-size`, … | Warn in debug; ignore. Not a layout concern. |
| `display: none`, `visibility: hidden`, `opacity: …` | Warn in debug; ignore. Hide components in app code instead. |
| `@media (...)`, `@supports`, `@keyframes`, … | Warn in debug; ignore. |
| Unknown / typo'd property | Warn in debug; ignore. |

CSSLayout **never crashes** on out-of-scope CSS — it parses, logs, and drops.

**Units**

`px`, `%`, `auto`, unitless (for flex values). `em`, `rem`, `vw`, `vh`, `ch`, `fr` deferred.

**Cascade & Specificity**

Standard CSS specificity: `(inline, ids, classes+attrs+pseudo-classes, elements)`. Last-wins on tie. **No inheritance** — there are no inheritable layout properties in the supported subset.

---

### 4.2 Component Model — two-level identity

Two distinct identities, each owned by a different party:

| Identity | Owner | Example | Lifetime |
|---|---|---|---|
| **Component type** | App developer | `text-input`, `submit-button` | App install |
| **Instance ID** | Server / CSS | `#first-name`, `#total` | Per screen |

**App-level registration (once at launch):**

```swift
CSSComponentRegistry.shared
    .register("text-input") { props, events in
        TextField(
            props.string("placeholder") ?? "",
            text: events.binding("value")
        )
        .onSubmit { events.emit("submit") }
    }
    .register("button") { props, events in
        Button(props.string("label") ?? "") {
            events.emit("tap")
        }
    }
    .register("image") { props, _ in
        AsyncImage(url: props.url("src"))
    }
    .register("checkbox") { props, events in
        Toggle(
            props.string("label") ?? "",
            isOn: events.binding("checked")
        )
    }
```

> **Note.** Visual styling of the rendered component (background, border, colors, fonts, shadows, etc.) is **owned by the component factory**, not by CSSLayout. CSSLayout only positions and sizes components via FlexLayout. This keeps the CSS layer pure and allows components to use any SwiftUI modifier (`.background`, `.foregroundStyle`, `.font`, …) without a translation layer.

**Per-screen schema (from server):**

```json
{
  "css": "#form { display:flex; flex-direction:column; gap:16px; padding:16px; } #submit { align-self:flex-end; }",
  "components": {
    "name":   { "type": "text-input", "props": { "placeholder": "Full name", "binding": "user.name" } },
    "email":  { "type": "text-input", "props": { "placeholder": "Email",     "binding": "user.email" } },
    "submit": { "type": "button",     "props": { "label": "Continue" } }
  }
}
```

---

### 4.3 Public API Surface

**Basic — fully server-driven:**

```swift
struct CheckoutScreen: View {
    @State private var payload: CSSPayload?

    var body: some View {
        Group {
            if let payload {
                CSSLayout(payload: payload)
                    .onEvent("submit") { event in
                        Task { payload = await api.submit(event.data) }
                    }
            } else {
                ProgressView()
            }
        }
        .task { payload = await api.fetchScreen("checkout") }
    }
}
```

**With local component overrides:**

```swift
CSSLayout(css: serverCSS, schema: serverSchema) {
    // Override or add components locally — wins over registry
    Component("custom-header") {
        MyBrandedHeader(title: "Checkout")
    }
    Component("cart-items") {
        CartItemsView(items: cart.items)
            .onCSSEvent("remove") { event in
                cart.remove(id: event.data["id"])
            }
    }
}
.onEvent("*") { event in                     // catch-all, for analytics
    analytics.track(event)
}
.onEvent("back") { _ in dismiss() }
.placeholder { id in                          // unknown-ID renderer
    PlaceholderBox(id: id)
}
```

**Pure-local (no server, CSS bundled):**

```swift
CSSLayout(css: """
    #root { display:flex; flex-direction:column; gap:12px; padding:16px; }
    #title { }
    #row { display:flex; flex-direction:row; gap:8px; }
    #ok { flex:1; }
    #cancel { flex:1; }
""") {
    Component("title")  { Text("Delete item?").font(.headline) }
    Component("ok")     { Button("OK")     { confirm() } }
    Component("cancel") { Button("Cancel") { dismiss() } }
}
```

---

### 4.4 Event System

> **Orthogonal to layout.** Events are a wiring concern, not a CSS concern. CSSLayout provides this machinery so apps don't have to re-invent it, but none of this affects the flexbox-only CSS subset.

Three requirements: **emission, bubbling, serialization**.

```swift
struct CSSEvent {
    let id:         String              // originating component instance-ID
    let name:       String              // "tap", "change", "submit", …
    let data:       [String: AnyCodable]
    let timestamp:  Date
    var propagates: Bool = true          // set false to stop bubbling
}
```

**Emission from within a component:**

```swift
.register("button") { props, events in
    Button(props.string("label") ?? "") {
        events.emit("tap", data: ["id": props.string("id")])
    }
}
```

**Handlers — three scopes:**

```swift
// 1. Local — attached to a specific instance
Component("submit") { ... }
    .onCSSEvent("tap") { event in … }

// 2. Root — catches bubbled events by name
CSSLayout(payload: p)
    .onEvent("tap") { event in … }

// 3. Catch-all — every event that bubbles to root
CSSLayout(payload: p)
    .onEvent("*") { event in … }
```

**Server round-trip pattern:**

```swift
CSSLayout(payload: $payload.value)
    .onEvent("*") { event in
        let next = try await api.post("/events", event)
        payload = next     // new CSS/schema, re-renders
    }
```

---

### 4.5 Placeholder & Missing-Component Policy

| Situation | Behaviour |
|---|---|
| CSS references `#avatar`, no schema entry, no inline `Component` | Render `placeholder` view; in debug show `#avatar` label |
| Schema entry references type `"x-card"`, type not registered | Render placeholder with `type` label in debug |
| Component `#footer` registered but not in CSS | Skip silently (not rendered) |
| CSS layout property unknown (e.g. `grid-area`) | Warn in debug, ignore in release |
| CSS selector cannot be resolved | Warn in debug, drop the rule |

Placeholder is **configurable** per-layout via `.placeholder { id in … }`. Default in debug: grey rounded rect with the ID printed; in release: invisible zero-size view.

---

### 4.6 State & Binding Model

> **Orthogonal to layout.** Like events (§4.4), the state/binding model is part of the CSSLayout runtime but has no interaction with the flexbox CSS subset.

The hardest problem in server-driven UI: **state continuity across CSS hot-swap**.

**Principles:**
1. Form values live in a `FormState` store keyed by the `binding` path from the schema (e.g. `user.name`).
2. New CSS payloads **preserve bound values** unless the binding path disappears.
3. Components that don't declare a `binding` prop are stateless (new render = fresh view).
4. `FormState` is injected via `@EnvironmentObject`, allowing the app to read/write.

```swift
@StateObject var form = FormState()

CSSLayout(payload: payload)
    .environmentObject(form)
    .onEvent("submit") { _ in
        Task { try await api.submit(form.snapshot()) }
    }
```

---

### 4.7 Architecture (data-flow)

```
Server response
    │
    ▼
┌───────────────┐    ┌────────────────┐
│  CSSPayload   │    │  Registry      │
│  { css,       │    │  [type →       │
│    schema }   │    │   factory]     │
└──────┬────────┘    └────────┬───────┘
       │                      │
       ▼                      │
  CSSParser                   │
       │                      │
       ▼                      │
  [Rule]  ──── cascade ──►  StyleTree (hierarchical, computed styles)
                                │
                                ▼
                       ComponentResolver
                       (for each style-tree node:
                         ├─ schema lookup → type + props
                         ├─ registry lookup → factory
                         └─ build SwiftUI view)
                                │
                                ▼
                          FlexBox tree
                          (wrapping each resolved view
                           with .flexItem(...) based on
                           computed style)
                                │
                                ▼
                          SwiftUI render
                                │
                                ▼
                    Events bubble up via EventBus
                                │
                                ▼
                         App-level handlers
```

---

## 5. Package Structure

New package in the same repo (monorepo) or separate?

**Decision: separate module within the same repo.**

```
flexbox-swift/
├── Sources/
│   ├── FlexLayout/          ← existing (unchanged)
│   └── CSSLayout/           ← new
│       ├── Parser/
│       │   ├── Tokenizer.swift
│       │   ├── Parser.swift
│       │   └── Selector.swift
│       ├── Cascade/
│       │   ├── Specificity.swift
│       │   └── StyleResolver.swift
│       ├── Model/
│       │   ├── ComputedStyle.swift
│       │   ├── StyleNode.swift
│       │   └── CSSPayload.swift
│       ├── Registry/
│       │   ├── ComponentRegistry.swift
│       │   └── ComponentFactory.swift
│       ├── Events/
│       │   ├── CSSEvent.swift
│       │   └── EventBus.swift
│       ├── Views/
│       │   ├── CSSLayout.swift         ← main View
│       │   ├── Component.swift         ← result-builder element
│       │   └── Placeholder.swift
│       └── CSSLayout.docc/
└── Tests/
    ├── FlexLayoutTests/      ← existing
    └── CSSLayoutTests/       ← new
        ├── ParserTests.swift
        ├── CascadeTests.swift
        ├── ResolverTests.swift
        ├── EventTests.swift
        └── IntegrationTests.swift
```

`Package.swift` exposes both as products; `CSSLayout` depends on `FlexLayout`.

---

## 6. Phased Delivery

### Phase 1 — Foundations (MVP, target ~3 weeks)

**Scope:**
- CSS tokenizer + parser for ID, class, element selectors (no combinators).
- Flex + box-model properties only.
- Flat component tree (one container, all instances as siblings).
- `CSSLayout` view with result-builder `Component { }` injection.
- `CSSComponentRegistry.shared` type-based registration.
- Basic event emission + `.onEvent` root handler.
- Debug placeholder for unknown IDs.
- 100+ unit tests for parser/cascade.

**Exit criteria:** Render a 10-field form from CSS + schema, submit event fires, all tests pass, zero warnings.

---

### Phase 2 — Full selector support & events (target ~2 weeks)

- Full selector grammar: `>`, descendant, grouping.
- Specificity algorithm (exact spec).
- Hierarchical style tree (nested containers auto-created from selectors).
- Event bubbling + `propagates = false`.
- `onEvent("*")` catch-all.
- `display: none` & `visibility: hidden`.

**Exit criteria:** Hand-authored CSS with 3-level nesting renders identically to Chrome.

---

### Phase 3 — Server-driven flows (target ~3 weeks)

- `CSSPayload` fetching, caching, versioning.
- `FormState` environment object, `binding` prop support.
- State-preserving CSS hot-swap.
- Server round-trip example in DemoApp.
- Schema JSON-Schema for validation.

**Exit criteria:** DemoApp with 3 server-driven screens, swap payloads at runtime without state loss.

> **Note.** `@media` breakpoints are *not* in v1. They're deferred to a future phase (or a separate responsive layer) because they fall outside the flexbox-property-only scope.

---

### Phase 4 — Production hardening (ongoing)

- Perf: parse cache, style-tree diffing on CSS hot-swap.
- Error reporting: structured parse warnings for server teams.
- Accessibility: map CSS roles to SwiftUI accessibility modifiers.
- Telemetry hooks for unresolved selectors / missing components.
- Fuzz testing the parser.

---

### Out of scope for CSSLayout (future separate layer)

Visual styling (`background-color`, `border-*`, `color`, `font-*`, `box-shadow`, `opacity`, `transition`, …) and `margin` / `min-*` / `max-*` sizing are intentionally **not** planned within CSSLayout. They belong to:

- **`FlexLayout`** — `margin`, `min-*`, `max-*` must land as public APIs on `FlexLayout` first (tracked as prerequisite issues, not part of this plan).
- **A future styling layer** (e.g. `CSSStyling`) — owns visual CSS properties. Sits above CSSLayout; CSSLayout stays layout-pure.

---

## 7. Key Technical Decisions (finalized)

| # | Decision | Rationale |
|---|---|---|
| D1 | **Write our own CSS parser** (not LibCSS/WebKit) | Swift-native, no C interop, scoped to our subset. Pure-Swift keeps CI simple and matches FlexLayout. |
| D2 | **Pixel-parity with Chrome flexbox** is a hard requirement | Forces disciplined CSS subset, enables cross-platform story. |
| D3 | **Two-level identity**: type (registered) + instance (CSS) | Enables server-driven wiring while keeping components reusable. |
| D4 | **Components bundled with events** in registry factory | Keeps factory self-contained, encapsulated, testable. |
| D5 | **Event bubbling with root catch-all** | Standard web mental model, enables analytics/server proxy easily. |
| D6 | **`FormState` env-object for bindings** | Solves the hot-swap state-continuity problem cleanly. |
| D7 | **Placeholder is opt-in configurable** | Debug defaults useful, release defaults invisible. |
| D8 | **Monorepo with separate module** | Shared CI, shared DocC theme, `CSSLayout` depends on `FlexLayout`. |
| D9 | **iOS 16 / macOS 13 minimum** | Matches FlexLayout's Layout-protocol requirement. |
| D10 | **Flexbox-only CSS subset** — no `grid`, `float`, pseudo-elements, and **no visual / typography properties** (`background`, `border`, `color`, `font`, `shadow`, `opacity`, `transition`). No `margin` / `min-*` / `max-*` until FlexLayout exposes them. | CSSLayout is a CSS→FlexLayout bridge, nothing more. Visual styling belongs to a separate layer built on top. |

---

## 8. Open Questions

Still to resolve before Phase 1 kickoff:

1. **Naming.** `CSSLayout` / `SwiftCSS` / `NativeCSS` / `FlexCSS` / `JoyCSS`? Consider trademark/SEO.
2. **CSS unit inheritance.** Do we support `em`/`rem` for root-relative sizing in v1, or defer?
3. **Selector performance.** For 100+ rules × 100+ nodes, do we need a rule-tree optimization (like Servo's)?
4. **State round-trip.** When the server sends new CSS, should it be able to also push **new state values** (not just schema)?
5. **Error channel.** Structured warnings → who consumes them? Console only, or an `onDiagnostic` closure?
6. **Schema alternative.** Some teams may prefer **inline data attributes** (`[data-type="button"]`) in CSS instead of a separate JSON schema. Support both?

---

## 9. Risks & Mitigations

| Risk | Likelihood | Impact | Mitigation |
|---|---|---|---|
| CSS parser doesn't match Chrome | Med | High | Visual-diff test suite against Chrome-rendered fixtures |
| Registry becomes a god-object | Med | Med | Keep factories pure; registry is just a `[String: Factory]` |
| State loss on CSS hot-swap | High | High | `FormState` binding-path model + diff-preserving renderer |
| Server payloads bloat app memory | Low | Med | Parse cache with LRU + schema version hash |
| Event-bubbling loops | Low | High | Compile-time max depth + runtime cycle detection |
| iOS minimum locks out users | Med | Low | Already set by FlexLayout dependency; no new constraint |

---

## 10. Comparison with Prior Art

| Tool | How it differs from CSSLayout |
|---|---|
| **React Native** | JS runtime, StyleSheet object (not CSS). Not cross-web-fidelity by default. |
| **Flutter** | Own rendering engine, non-native, own style system (no CSS). |
| **Shopify's SDUI** | Custom DSL, not CSS; vertical integration with their stack. |
| **Airbnb Lona** | Component spec, not runtime CSS. |
| **Microsoft Adaptive Cards** | Schema-only; no CSS; limited layout primitives. |
| **iOS SwiftUI** | Swift-native; not dynamic/server-driven. |
| **Apple DocC / Tutorials** | Layout DSL but read-only, no events. |

CSSLayout's unique angle: **real CSS as the contract**, pure Swift, events built in, served from a backend, cross-platform by design.

---

## 11. Next Actions

1. Ratify naming and open questions (§8) — 1 week.
2. Spike: prototype CSS tokenizer + parse 10-rule test file covering **only** the §4.1 supported properties — 3 days.
3. Spike: prototype `CSSLayout` view rendering 3 hardcoded components via FlexLayout — 3 days.
4. Commit to Phase 1 scope, create project board, kick off.

### Prerequisite work in `flexbox-swift` (not part of CSSLayout)

None blocking v1 — the §4.1 subset maps 1:1 to current FlexLayout APIs. If `margin`, `min-*`, or `max-*` become required later, they must be added to `FlexLayout`'s public API first (as separate PRs to `flexbox-swift`) before CSSLayout parses them.

---

**Document revision history**

| Version | Date | Notes |
|---|---|---|
| Draft v1   | 2026-04-17 | Initial finalized plan based on brainstorm session. |
| Draft v1.1 | 2026-04-17 | Tightened scope to flexbox-only: removed visual / typography / `margin` / `min-*` / `max-*` / `@media` from the CSS subset. CSSLayout is now strictly a CSS→FlexLayout bridge. Visual styling moved to a future separate layer. |
