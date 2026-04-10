import SwiftUI

// MARK: - Responsive Preview Container
// Reusable viewport toolbar + resizable canvas for any sample view.
// Shows the same width presets bar as CSS → Preview (Full, 1280, 1024, 768, 375).

private struct ResponsivePreviewWidthKey: EnvironmentKey {
    static let defaultValue: CGFloat = 0
}

extension EnvironmentValues {
    var responsivePreviewWidth: CGFloat {
        get { self[ResponsivePreviewWidthKey.self] }
        set { self[ResponsivePreviewWidthKey.self] = newValue }
    }
}

struct ResponsivePreview<Content: View>: View {
    let content: Content

    init(@ViewBuilder content: () -> Content) {
        self.content = content()
    }

    @State private var selectedPreset: Int = 0
    @State private var customWidth: String = ""

    private var canvasWidth: CGFloat? {
        if !customWidth.isEmpty, let n = Double(customWidth), n > 0 {
            return CGFloat(n)
        }
        return presets[selectedPreset].width
    }

    var body: some View {
        VStack(spacing: 0) {
            toolbar
            Divider()
            canvas
        }
    }

    // MARK: - Toolbar

    private var toolbar: some View {
        HStack(spacing: 10) {
            Image(systemName: "eye").foregroundStyle(.secondary)
            Text("Live Preview").font(.headline)
            Spacer()

            // Width presets
            HStack(spacing: 4) {
                ForEach(presets.indices, id: \.self) { i in
                    let p = presets[i]
                    Button {
                        selectedPreset = i
                        customWidth = ""
                    } label: {
                        VStack(spacing: 2) {
                            Image(systemName: p.icon).font(.system(size: 11))
                            Text(p.label).font(.system(size: 9))
                        }
                        .frame(width: 44, height: 34)
                    }
                    .buttonStyle(.plain)
                    .background(
                        RoundedRectangle(cornerRadius: 6)
                            .fill(selectedPreset == i && customWidth.isEmpty
                                  ? Color.accentColor.opacity(0.15)
                                  : Color.clear)
                    )
                    .foregroundStyle(selectedPreset == i && customWidth.isEmpty
                                     ? Color.accentColor : Color.secondary)
                }
            }
            .padding(3)
            .background(Color(nsColor: .controlBackgroundColor), in: RoundedRectangle(cornerRadius: 8))

            // Custom width
            HStack(spacing: 4) {
                TextField("px", text: $customWidth)
                    .frame(width: 52)
                    .textFieldStyle(.roundedBorder)
                    .font(.system(size: 12, design: .monospaced))
                Text("px").font(.caption).foregroundStyle(.secondary)
            }
        }
        .padding(.horizontal, 16).padding(.vertical, 8)
        .background(Color(nsColor: .controlBackgroundColor))
    }

    // MARK: - Canvas

    private var canvas: some View {
        GeometryReader { geo in
            let effectiveWidth = canvasWidth ?? geo.size.width
            ScrollView(.vertical, showsIndicators: true) {
                content
                    .environment(\.responsivePreviewWidth, effectiveWidth)
                    .frame(minWidth: effectiveWidth, maxWidth: effectiveWidth)
            }
            .frame(maxWidth: .infinity, alignment: .center)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(nsColor: .windowBackgroundColor))
    }
}

// MARK: - Presets data

private struct Preset {
    let label: String
    let icon:  String
    let width: CGFloat?
}

private let presets: [Preset] = [
    Preset(label: "Full",  icon: "arrow.left.and.right", width: nil),
    Preset(label: "1280",  icon: "desktopcomputer",      width: 1280),
    Preset(label: "1024",  icon: "laptopcomputer",       width: 1024),
    Preset(label: "768",   icon: "ipad.landscape",       width: 768),
    Preset(label: "375",   icon: "iphone",               width: 375),
]
