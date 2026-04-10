import SwiftUI
import FlexLayout

// MARK: - Recursive CSS Renderer
//
// KEY RULE: .flexItem() (which uses .layoutValue()) MUST be applied to the
// DIRECT child of FlexLayout, not inside a nested View struct's body.
// FlexLayout reads layout values only from its immediate Subviews entries.

let previewColors: [Color] = [
    .red, .orange, .yellow, .green, .teal,
    .blue, .indigo, .purple, .pink, .mint, .cyan, .brown
]

// MARK: - CSSRendererView

/// Renders a `ParsedCSS` tree — potentially nested — as a live `FlexBox`.
struct CSSRendererView: View {
    let css:          ParsedCSS
    let colorOffset:  Int
    let fallbackCount: Int

    var body: some View {
        let items = css.items.isEmpty
            ? (0..<fallbackCount).map { i in ParsedItem(selector: "item \(i + 1)") }
            : css.items

        FlexBox(
            direction:      css.container.direction,
            wrap:           css.container.wrap,
            justifyContent: css.container.justifyContent,
            alignItems:     css.container.alignItems,
            alignContent:   css.container.alignContent,
            gap:            css.container.gap,
            rowGap:         css.container.rowGap,
            columnGap:      css.container.columnGap,
            padding:        css.container.padding,
            overflow:       css.container.overflow
        ) {
            ForEach(Array(items.enumerated()), id: \.offset) { idx, item in
                let color = previewColors[(colorOffset + idx) % previewColors.count]

                // ✅ .flexItem() applied HERE — direct child of FlexBox.
                // All spec properties threaded through to the layout engine.
                CSSItemView(
                    item:          item,
                    color:         color,
                    colorOffset:   colorOffset + idx + 1,
                    fallbackCount: fallbackCount
                )
                .flexItem(
                    grow:      item.grow,
                    shrink:    item.shrink,
                    basis:     item.basis,
                    alignSelf: item.alignSelf,
                    order:     item.order,
                    width:     item.width,
                    height:    item.height,
                    overflow:  item.overflow,
                    zIndex:    item.zIndex,
                    position:  item.position,
                    top:       item.top,
                    bottom:    item.bottom,
                    leading:   item.leading,
                    trailing:  item.trailing,
                    display:   item.display
                )
                // SwiftUI's native z-index for render-tree ordering
                .zIndex(Double(item.zIndex))
            }
        }
    }
}

// MARK: - CSSItemView

/// Renders a single flex item — a leaf chip or a nested container.
/// Does NOT apply .flexItem() internally — CSSRendererView does that.
struct CSSItemView: View {
    let item:          ParsedItem
    let color:         Color
    let colorOffset:   Int
    let fallbackCount: Int

    var body: some View {
        coreContent
            .flexOverflow(item.overflow)
    }

    @ViewBuilder
    private var coreContent: some View {
        if let child = item.childCSS {
            // Nested flex container
            CSSRendererView(
                css:           child,
                colorOffset:   colorOffset,
                fallbackCount: fallbackCount
            )
            .padding(6)
            .background(color.opacity(0.12))
            .clipShape(RoundedRectangle(cornerRadius: 8))
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .strokeBorder(color.opacity(0.5), lineWidth: 1.5)
            )
        } else {
            // Leaf chip — display mode (block/inline) is handled by the layout engine
            FlexChip(label: item.label, color: color)
        }
    }
}

// MARK: - FlexChip

/// A coloured chip that fills whatever space FlexLayout allocates.
struct FlexChip: View {
    let label: String
    let color: Color

    var body: some View {
        Text(label)
            .font(.system(size: 11, weight: .semibold))
            .lineLimit(3)
            .multilineTextAlignment(.center)
            .foregroundStyle(.white)
            .padding(.horizontal, 10)
            .padding(.vertical, 8)
            // maxWidth/maxHeight: .infinity → accept whatever size FlexLayout proposes.
            .frame(minWidth: 56, maxWidth: .infinity, minHeight: 40, maxHeight: .infinity)
            .background(color.gradient)
            .clipShape(RoundedRectangle(cornerRadius: 8))
    }
}
