import SwiftUI
import FlexLayout
import UniformTypeIdentifiers

// MARK: - CSS Paste Demo

// MARK: - Canvas width presets

private struct CanvasPreset: Identifiable {
    let id = UUID()
    let label: String
    let icon:  String
    let width: CGFloat?   // nil = fill available
}

private let canvasPresets: [CanvasPreset] = [
    CanvasPreset(label: "Full",  icon: "arrow.left.and.right",          width: nil),
    CanvasPreset(label: "1280",  icon: "desktopcomputer",               width: 1280),
    CanvasPreset(label: "1024",  icon: "laptopcomputer",                width: 1024),
    CanvasPreset(label: "768",   icon: "ipad.landscape",                width: 768),
    CanvasPreset(label: "375",   icon: "iphone",                        width: 375),
]

struct CSSPasteDemo: View {

    @State private var cssText:      String      = initialCSSText
    @State private var parsed:       ParsedCSS   = CSSParser.parse(initialCSSText)
    @State private var itemCount:    Int         = 4
    @State private var showErrors                = false
    @State private var selectedPreset: Int       = 0   // index into canvasPresets
    @State private var customWidth:  String      = ""
    @State private var showProps:    Bool        = true
    @State private var capturedImage: NSImage?   = nil
    @State private var showSavePanel: Bool       = false

    // Resolved canvas width: nil = fill, or a fixed CGFloat
    private var canvasWidth: CGFloat? {
        if !customWidth.isEmpty, let n = Double(customWidth), n > 0 {
            return CGFloat(n)
        }
        return canvasPresets[selectedPreset].width
    }

    private var pickerSnippets: [(String, String)] {
        fileCSSSnippets.isEmpty ? cssSnippets : fileCSSSnippets
    }

    private var activeViewportWidth: CGFloat {
        canvasWidth ?? max(200, measuredCanvasWidth - 48)
    }

    var body: some View {
        HSplitView {
            editorPane
            rightPane
        }
        .onAppear { reparseCSS() }
        .onChange(of: selectedPreset) { _ in reparseCSS() }
        .onChange(of: customWidth) { _ in reparseCSS() }
        .onChange(of: measuredCanvasWidth) { _ in reparseCSS() }
    }

    // MARK: - Left: editor pane

    private var editorPane: some View {
        VStack(alignment: .leading, spacing: 0) {
            editorHeader
            Divider()
            TextEditor(text: $cssText)
                .font(.system(.body, design: .monospaced))
                .padding(10)
                .onChange(of: cssText) { _ in reparseCSS() }
            Divider()
            editorFooter
        }
        .frame(minWidth: 220, maxWidth: 360)
    }

    private var editorHeader: some View {
        HStack {
            Image(systemName: "doc.text").foregroundStyle(.secondary)
            Text("Paste CSS").font(.headline)
            Spacer()
            Button("Clear") { cssText = "" }
                .buttonStyle(.plain).foregroundStyle(.red).font(.caption)
        }
        .padding(.horizontal, 14).padding(.vertical, 10)
        .background(Color(nsColor: .controlBackgroundColor))
    }

    private var editorFooter: some View {
        HStack(spacing: 8) {
            Text(fileCSSSnippets.isEmpty ? "Snippets:" : "Samples:")
                .font(.caption).foregroundStyle(.secondary)
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 6) {
                    ForEach(pickerSnippets, id: \.0) { name, css in
                        Button(name) { applyCSS(css) }
                            .buttonStyle(.bordered).controlSize(.small)
                    }
                }
            }
            Spacer()
            warningsButton
        }
        .padding(.horizontal, 14).padding(.vertical, 8)
        .background(Color(nsColor: .controlBackgroundColor))
    }

    @ViewBuilder
    private var warningsButton: some View {
        if !parsed.errors.isEmpty {
            Button {
                showErrors.toggle()
            } label: {
                Label("\(parsed.errors.count) warning\(parsed.errors.count == 1 ? "" : "s")",
                      systemImage: "exclamationmark.triangle")
                    .font(.caption).foregroundStyle(.orange)
            }
            .buttonStyle(.plain)
            .popover(isPresented: $showErrors) {
                VStack(alignment: .leading, spacing: 6) {
                    ForEach(parsed.errors, id: \.self) { e in
                        Label(e, systemImage: "exclamationmark.triangle").font(.caption)
                    }
                }
                .padding(14).frame(minWidth: 280)
            }
        }
    }

    // MARK: - Right: VSplitView (canvas top, props bottom)

    private var rightPane: some View {
        VSplitView {
            canvasPane
            if showProps { propsPane }
        }
        .frame(minWidth: 420)
        .background(Color(nsColor: .windowBackgroundColor))
    }

    // MARK: - Canvas pane (fills all available vertical space)

    private var canvasPane: some View {
        VStack(spacing: 0) {
            canvasToolbar
            Divider()
            canvasContent
        }
        .frame(minHeight: 300)
    }

    private var canvasToolbar: some View {
        HStack(spacing: 10) {
            Image(systemName: "eye").foregroundStyle(.secondary)
            Text("Live Preview").font(.headline)
            Spacer()

            // Viewport width presets
            HStack(spacing: 4) {
                ForEach(canvasPresets.indices, id: \.self) { i in
                    let p = canvasPresets[i]
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

            // Custom width input
            HStack(spacing: 4) {
                TextField("px", text: $customWidth)
                    .frame(width: 52)
                    .textFieldStyle(.roundedBorder)
                    .font(.system(size: 12, design: .monospaced))
                Text("px").font(.caption).foregroundStyle(.secondary)
            }

            Divider().frame(height: 18)

            // Toggle props panel
            Button {
                withAnimation(.easeInOut(duration: 0.18)) { showProps.toggle() }
            } label: {
                Image(systemName: showProps ? "sidebar.bottom" : "sidebar.bottom")
                    .symbolVariant(showProps ? .fill : .none)
                    .font(.system(size: 13))
            }
            .buttonStyle(.plain)
            .foregroundStyle(showProps ? Color.accentColor : Color.secondary)
            .help(showProps ? "Hide properties panel" : "Show properties panel")

            // Capture screenshot button
            Button {
                captureRenderedImage()
            } label: {
                Label("Capture", systemImage: "camera")
                    .font(.system(size: 12))
            }
            .buttonStyle(.plain)
            .foregroundStyle(.secondary)
            .help("Save screenshot of rendered layout")

            warningsButton
        }
        .padding(.horizontal, 16).padding(.vertical, 8)
        .background(Color(nsColor: .controlBackgroundColor))
    }

    @State private var measuredCanvasWidth: CGFloat = 600

    private var canvasContent: some View {
        // Use GeometryReader to capture actual available width for "Full" mode.
        // ScrollView proposes infinity, so we measure the container first.
        GeometryReader { geo in
            ScrollView([.horizontal, .vertical]) {
                Group {
                    if cssText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                        emptyPreviewPlaceholder
                    } else {
                        let effectiveWidth = canvasWidth ?? max(200, geo.size.width - 48)
                        let effectiveHeight = max(300, geo.size.height - 80)
                        VStack(alignment: .leading, spacing: 8) {
                            HStack(spacing: 4) {
                                Image(systemName: "arrow.left.and.right")
                                    .font(.system(size: 9))
                                Text("\(Int(effectiveWidth)) × \(Int(effectiveHeight)) px canvas")
                                    .font(.system(size: 10, design: .monospaced))
                            }
                            .foregroundStyle(.secondary)

                            CSSRendererView(css: parsed, colorOffset: 0, fallbackCount: itemCount)
                                .frame(
                                    minWidth:  effectiveWidth,
                                    maxWidth:  effectiveWidth,
                                    minHeight: effectiveHeight,
                                    maxHeight: effectiveHeight
                                )
                                .padding(20)
                                .background(Color(white: 0.95))
                                .clipShape(RoundedRectangle(cornerRadius: 12))
                                .overlay(
                                    RoundedRectangle(cornerRadius: 12)
                                        .strokeBorder(Color.gray.opacity(0.2))
                                )
                                .shadow(color: .black.opacity(0.06), radius: 6, y: 2)

                            if parsed.items.isEmpty {
                                HStack {
                                    Text("No item rules — showing \(itemCount) generic items")
                                        .font(.caption).foregroundStyle(.secondary)
                                    Spacer()
                                    Stepper("", value: $itemCount, in: 1...12).labelsHidden()
                                }
                            }
                        }
                        .frame(alignment: .topLeading)
                    }
                }
                .padding(24)
            }
            .onAppear { measuredCanvasWidth = geo.size.width }
            .onChange(of: geo.size.width) { newWidth in
                measuredCanvasWidth = newWidth
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private func reparseCSS() {
        parsed = CSSParser.parse(cssText, viewportWidth: activeViewportWidth)
    }

    private func applyCSS(_ css: String) {
        cssText = css
        parsed = CSSParser.parse(css, viewportWidth: activeViewportWidth)
    }

    private var emptyPreviewPlaceholder: some View {
        RoundedRectangle(cornerRadius: 12)
            .fill(Color(white: 0.95))
            .frame(maxWidth: .infinity, minHeight: 200)
            .overlay(
                VStack(spacing: 8) {
                    Image(systemName: "doc.text").font(.largeTitle).foregroundStyle(.tertiary)
                    Text("Paste CSS on the left").foregroundStyle(.secondary)
                }
            )
    }

    // MARK: - Screenshot capture

    @MainActor private func captureRenderedImage() {
        let renderedView = CSSRendererView(css: parsed, colorOffset: 0, fallbackCount: itemCount)
            .frame(
                width:     canvasWidth ?? 800,
                height:    nil
            )
            .padding(20)
            .background(Color(white: 0.95))

        let renderer = ImageRenderer(content: renderedView)
        renderer.scale = 2.0  // Retina

        guard let nsImage = renderer.nsImage else { return }

        let panel = NSSavePanel()
        panel.allowedContentTypes = [.png]
        panel.nameFieldStringValue = "flex-layout-capture.png"
        panel.begin { response in
            guard response == .OK, let url = panel.url else { return }
            if let tiff = nsImage.tiffRepresentation,
               let rep = NSBitmapImageRep(data: tiff),
               let png = rep.representation(using: .png, properties: [:]) {
                try? png.write(to: url)
            }
        }
    }

    // MARK: - Props pane (bottom panel, collapsible)

    private var propsPane: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                propsSection
                if !parsed.errors.isEmpty { errorsSection }
            }
            .padding(16)
        }
        .frame(minHeight: 180, maxHeight: 340)
        .background(Color(nsColor: .windowBackgroundColor))
    }

    // MARK: - Parsed properties

    private var propsSection: some View {
        GroupBox {
            VStack(alignment: .leading, spacing: 0) {
                CSSPropsTable(parsed: parsed)
            }
            .padding(4)
        } label: {
            Label("Parsed Properties", systemImage: "list.bullet.rectangle")
        }
    }

    // MARK: - Errors

    private var errorsSection: some View {
        GroupBox {
            VStack(alignment: .leading, spacing: 4) {
                ForEach(parsed.errors, id: \.self) { e in
                    Label(e, systemImage: "exclamationmark.triangle.fill")
                        .foregroundStyle(.orange).font(.caption)
                }
            }.padding(4)
        } label: {
            Label("Warnings", systemImage: "exclamationmark.triangle").foregroundStyle(.orange)
        }
    }
}

// MARK: - Parsed Properties Table (separate struct to keep body simple)

struct CSSPropsTable: View {
    let parsed: ParsedCSS

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            sectionLabel("Container")
            PropRow(label: "flex-direction",  value: parsed.container.direction.description)
            PropRow(label: "flex-wrap",       value: parsed.container.wrap.description)
            PropRow(label: "justify-content", value: parsed.container.justifyContent.description)
            PropRow(label: "align-items",     value: parsed.container.alignItems.description)
            PropRow(label: "align-content",   value: parsed.container.alignContent.description)
            if parsed.container.gap > 0 || parsed.container.rowGap != nil || parsed.container.columnGap != nil {
                PropRow(label: "gap", value: gapText)
            }
            let p = parsed.container.padding
            if p.top != 0 || p.bottom != 0 || p.leading != 0 || p.trailing != 0 {
                PropRow(label: "padding", value: paddingText(p))
            }
            if !parsed.items.isEmpty {
                Divider().padding(.vertical, 6)
                sectionLabel("Items  (\(parsed.items.count) rules)")
                ForEach(Array(parsed.items.enumerated()), id: \.offset) { idx, item in
                    ItemSummaryRow(item: item,
                                   color: previewColors[idx % previewColors.count],
                                   depth: 0)
                }
            }
        }
    }

    private var gapText: String {
        let c = parsed.container
        if let rg = c.rowGap, let cg = c.columnGap { return "row \(Int(rg))pt · col \(Int(cg))pt" }
        if let rg = c.rowGap    { return "row \(Int(rg))pt" }
        if let cg = c.columnGap { return "col \(Int(cg))pt" }
        return "\(Int(c.gap))pt"
    }

    private func paddingText(_ p: EdgeInsets) -> String {
        if p.top == p.bottom && p.leading == p.trailing && p.top == p.leading {
            return "\(Int(p.top))pt"
        }
        if p.top == p.bottom && p.leading == p.trailing {
            return "TB:\(Int(p.top))pt LR:\(Int(p.leading))pt"
        }
        return "T:\(Int(p.top)) R:\(Int(p.trailing)) B:\(Int(p.bottom)) L:\(Int(p.leading))"
    }

    private func sectionLabel(_ text: String) -> some View {
        Text(text)
            .font(.caption.weight(.semibold)).foregroundStyle(.secondary)
            .textCase(.uppercase).padding(.bottom, 4)
    }
}

// MARK: - Item summary row (recursive for nested containers)

struct ItemSummaryRow: View {
    let item:  ParsedItem
    let color: Color
    let depth: Int

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            headerRow
            if let child = item.childCSS {
                childrenRows(child)
            }
        }
        .padding(.vertical, 2)
    }

    private var headerRow: some View {
        HStack(spacing: 6) {
            if depth > 0 {
                Color.clear.frame(width: CGFloat(depth) * 14)
                Image(systemName: "arrow.turn.down.right")
                    .font(.system(size: 9)).foregroundStyle(.secondary)
            }
            RoundedRectangle(cornerRadius: 3).fill(color).frame(width: 10, height: 10)
            Text(item.label).font(.system(.caption, design: .monospaced))
            if item.isNestedContainer {
                Text("container")
                    .font(.system(size: 9, weight: .semibold))
                    .foregroundStyle(.white)
                    .padding(.horizontal, 4).padding(.vertical, 1)
                    .background(Color.blue.opacity(0.75))
                    .clipShape(RoundedRectangle(cornerRadius: 3))
            }
            Spacer()
            Text(itemSummary).font(.system(size: 10, design: .monospaced)).foregroundStyle(.secondary)
        }
    }

    private func childrenRows(_ child: ParsedCSS) -> some View {
        HStack(alignment: .top, spacing: 6) {
            Color.clear.frame(width: CGFloat(depth + 1) * 14)
            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 4) {
                    Image(systemName: "square.grid.2x2")
                        .font(.system(size: 9)).foregroundStyle(.secondary)
                    Text("\(child.container.direction.description) · \(child.container.justifyContent.description)")
                        .font(.system(size: 10, design: .monospaced)).foregroundStyle(.secondary)
                }
                ForEach(Array(child.items.enumerated()), id: \.offset) { ci, childItem in
                    ItemSummaryRow(item: childItem,
                                   color: previewColors[(ci + 1) % previewColors.count],
                                   depth: depth + 1)
                }
            }
        }
    }

    private var itemSummary: String {
        var parts: [String] = []
        if item.grow   != 0 { parts.append("grow:\(fmt(item.grow))") }
        if item.shrink != 1 { parts.append("shrink:\(fmt(item.shrink))") }
        switch item.basis {
        case .auto:            break
        case .points(let n):   parts.append("basis:\(Int(n))pt")
        case .fraction(let f): parts.append("basis:\(Int(f * 100))%")
        }
        if item.alignSelf != .auto { parts.append("align:\(item.alignSelf.description)") }
        if item.order != 0         { parts.append("order:\(item.order)") }
        // New spec properties
        switch item.width {
        case .points(let n):   parts.append("w:\(Int(n))pt")
        case .fraction(let f): parts.append("w:\(Int(f * 100))%")
        case .minContent:      parts.append("w:min-content")
        case .auto: break
        }
        switch item.height {
        case .points(let n):   parts.append("h:\(Int(n))pt")
        case .fraction(let f): parts.append("h:\(Int(f * 100))%")
        case .minContent:      parts.append("h:min-content")
        case .auto: break
        }
        if item.position == .absolute { parts.append("pos:absolute") }
        if item.overflow != .visible  { parts.append("overflow:\(item.overflow.label)") }
        if item.zIndex   != 0         { parts.append("z:\(item.zIndex)") }
        if item.display  != .flex     { parts.append("display:\(item.display.label)") }
        return parts.isEmpty ? "defaults" : parts.joined(separator: " · ")
    }

    private func fmt(_ n: CGFloat) -> String {
        n.truncatingRemainder(dividingBy: 1) == 0 ? "\(Int(n))" : String(format: "%.1f", n)
    }
}

// MARK: - Display helpers for new enum types

extension FlexOverflow {
    var label: String {
        switch self {
        case .visible: return "visible"
        case .hidden:  return "hidden"
        case .clip:    return "clip"
        case .scroll:  return "scroll"
        case .auto:    return "auto"
        }
    }
}

extension FlexDisplay {
    var label: String {
        switch self {
        case .flex:    return "flex"
        case .block:   return "block"
        case .inline:  return "inline"
        }
    }
}

// MARK: - CSS Snippets

private func locateSamplesDirectory() -> URL? {
    let fileManager = FileManager.default
    let candidateDirectories: [URL] = [
        URL(fileURLWithPath: fileManager.currentDirectoryPath)
            .appendingPathComponent("Samples", isDirectory: true),
        URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .appendingPathComponent("Samples", isDirectory: true),
    ]

    for directory in candidateDirectories {
        var isDirectory: ObjCBool = false
        if fileManager.fileExists(atPath: directory.path, isDirectory: &isDirectory),
           isDirectory.boolValue {
            return directory
        }
    }

    return nil
}

private func sampleTitle(from fileName: String) -> String {
    let stem = URL(fileURLWithPath: fileName).deletingPathExtension().lastPathComponent
    let components = stem.split(separator: "-", maxSplits: 1).map(String.init)

    if components.count == 2, Int(components[0]) != nil {
        let label = components[1]
            .split(separator: "-")
            .map { String($0).capitalized }
            .joined(separator: " ")
        return "\(components[0]) · \(label)"
    }

    return stem
        .split(separator: "-")
        .map { String($0).capitalized }
        .joined(separator: " ")
}

private let fileCSSSnippets: [(String, String)] = {
    guard let samplesDirectory = locateSamplesDirectory() else { return [] }

    let fileManager = FileManager.default
    guard let files = try? fileManager.contentsOfDirectory(
        at: samplesDirectory,
        includingPropertiesForKeys: nil,
        options: [.skipsHiddenFiles]
    ) else {
        return []
    }

    let cssFiles = files
        .filter { $0.pathExtension.lowercased() == "css" }
        .sorted { $0.lastPathComponent < $1.lastPathComponent }

    return cssFiles.compactMap { fileURL in
        guard let css = try? String(contentsOf: fileURL, encoding: .utf8) else { return nil }
        return (sampleTitle(from: fileURL.lastPathComponent), css)
    }
}()

private let initialCSSText = fileCSSSnippets.first?.1 ?? defaultCSS

private let defaultCSS = """
/* 3-level App Shell: App → Sidebar+Main → Workspace → Editor+Inspector */

.app {
  display: flex;
  flex-direction: row;
  align-items: stretch;
}

.app > .sidebar {
  display: flex;
  flex-direction: column;
  gap: 6px;
  flex: 0 0 180px;
}
.app > .sidebar > .brand   { flex: 0 0 48px; }
.app > .sidebar > .nav     { flex: 1; }
.app > .sidebar > .profile { flex: 0 0 52px; }

.app > .main {
  display: flex;
  flex-direction: column;
  flex: 1;
}
.app > .main > .toolbar { flex: 0 0 40px; }
.app > .main > .workspace {
  display: flex;
  flex-direction: row;
  gap: 8px;
  flex: 1;
}
.app > .main > .workspace > .editor    { flex: 1; }
.app > .main > .workspace > .inspector { flex: 0 0 220px; }
.app > .main > .statusbar { flex: 0 0 22px; }
"""

let cssSnippets: [(String, String)] = [

    // ── Simple layouts ──────────────────────────────────────────────────────

    ("Nav Bar", """
.navbar {
  display: flex;
  justify-content: space-between;
  align-items: center;
  gap: 8px;
}
.navbar > .logo  { flex: 0 0 80px; }
.navbar > .links { flex: 1; }
.navbar > .cta   { flex: 0 0 90px; }
"""),

    ("Card Grid", """
.grid {
  display: flex;
  flex-wrap: wrap;
  gap: 16px;
  align-items: flex-start;
}
.grid > .card {
  flex-shrink: 0;
  flex-basis: 140px;
}
"""),

    ("Holy Grail", """
.layout {
  display: flex;
  align-items: stretch;
}
.layout > .left  { flex: 0 0 120px; }
.layout > .main  { flex: 1; }
.layout > .right { flex: 0 0 100px; }
"""),

    ("Centered", """
.hero {
  display: flex;
  flex-direction: column;
  justify-content: center;
  align-items: center;
  gap: 20px;
}
"""),

    // ── 2-level nesting ─────────────────────────────────────────────────────

    ("Sidebar+Content", """
/* 2-level: row → sidebar(col) + main(col) */
.layout {
  display: flex;
  flex-direction: row;
  gap: 12px;
  align-items: stretch;
}
.layout > .sidebar {
  display: flex;
  flex-direction: column;
  gap: 8px;
  flex: 0 0 160px;
}
.layout > .sidebar > .nav-header { flex: 0 0 40px; }
.layout > .sidebar > .nav-body   { flex: 1; }
.layout > .sidebar > .nav-footer { flex: 0 0 36px; }
.layout > .main { flex: 1; }
"""),

    // ── 3-level nesting ─────────────────────────────────────────────────────

    ("App Shell", """
/* 3-level: App → Sidebar+Main → Content+Inspector */
.app {
  display: flex;
  flex-direction: row;
  align-items: stretch;
}
.app > .sidebar {
  display: flex;
  flex-direction: column;
  gap: 6px;
  flex: 0 0 180px;
}
.app > .sidebar > .brand    { flex: 0 0 48px; }
.app > .sidebar > .nav      { flex: 1; }
.app > .sidebar > .profile  { flex: 0 0 52px; }
.app > .main {
  display: flex;
  flex-direction: column;
  gap: 0px;
  flex: 1;
}
.app > .main > .toolbar { flex: 0 0 40px; }
.app > .main > .workspace {
  display: flex;
  flex-direction: row;
  gap: 8px;
  flex: 1;
}
.app > .main > .workspace > .editor    { flex: 1; }
.app > .main > .workspace > .inspector { flex: 0 0 220px; }
.app > .main > .statusbar { flex: 0 0 22px; }
"""),

    ("Dashboard", """
/* 3-level: Dashboard → Header+Body → Metrics+Sidebar */
.dashboard {
  display: flex;
  flex-direction: column;
  gap: 12px;
}
.dashboard > .header {
  display: flex;
  flex-direction: row;
  align-items: center;
  gap: 10px;
  flex: 0 0 56px;
}
.dashboard > .header > .logo    { flex: 0 0 100px; }
.dashboard > .header > .search  { flex: 1; }
.dashboard > .header > .actions { flex: 0 0 80px; }
.dashboard > .body {
  display: flex;
  flex-direction: row;
  gap: 14px;
  flex: 1;
  align-items: stretch;
}
.dashboard > .body > .metrics {
  display: flex;
  flex-direction: column;
  gap: 10px;
  flex: 1;
}
.dashboard > .body > .metrics > .kpi-row {
  display: flex;
  flex-direction: row;
  gap: 10px;
  flex-wrap: wrap;
  flex: 0 0 80px;
}
.dashboard > .body > .metrics > .kpi-row > .kpi    { flex: 1; }
.dashboard > .body > .metrics > .chart              { flex: 1; }
.dashboard > .body > .activity {
  display: flex;
  flex-direction: column;
  gap: 6px;
  flex: 0 0 200px;
}
.dashboard > .body > .activity > .activity-header { flex: 0 0 28px; }
.dashboard > .body > .activity > .feed            { flex: 1; }
.dashboard > .body > .activity > .load-more       { flex: 0 0 32px; }
"""),

    ("IDE Layout", """
/* 3-level: IDE → Toolbar+Workspace → Files+Editor(tabs/code/terminal)+Panel */
.ide {
  display: flex;
  flex-direction: column;
}
.ide > .toolbar {
  display: flex;
  flex-direction: row;
  align-items: center;
  gap: 6px;
  flex: 0 0 40px;
}
.ide > .toolbar > .run    { flex: 0 0 56px; }
.ide > .toolbar > .debug  { flex: 0 0 56px; }
.ide > .toolbar > .spacer { flex: 1; }
.ide > .toolbar > .search { flex: 0 0 180px; }
.ide > .workspace {
  display: flex;
  flex-direction: row;
  flex: 1;
  gap: 0px;
}
.ide > .workspace > .files {
  display: flex;
  flex-direction: column;
  flex: 0 0 160px;
  gap: 2px;
}
.ide > .workspace > .files > .folder { flex: 0 0 22px; }
.ide > .workspace > .files > .file   { flex: 0 0 22px; }
.ide > .workspace > .editor {
  display: flex;
  flex-direction: column;
  flex: 1;
}
.ide > .workspace > .editor > .tabs     { flex: 0 0 30px; }
.ide > .workspace > .editor > .code     { flex: 1; }
.ide > .workspace > .editor > .terminal { flex: 0 0 120px; }
.ide > .workspace > .panel { flex: 0 0 200px; }
"""),

    ("Kanban Board", """
/* 3-level: Board → Columns → Header+Cards */
.board {
  display: flex;
  flex-direction: row;
  gap: 12px;
  align-items: stretch;
}
.board > .col-todo {
  display: flex;
  flex-direction: column;
  gap: 8px;
  flex: 1;
}
.board > .col-todo > .col-header { flex: 0 0 36px; }
.board > .col-todo > .card       { flex: 0 0 64px; }
.board > .col-inprogress {
  display: flex;
  flex-direction: column;
  gap: 8px;
  flex: 1;
}
.board > .col-inprogress > .col-header { flex: 0 0 36px; }
.board > .col-inprogress > .card       { flex: 0 0 64px; }
.board > .col-done {
  display: flex;
  flex-direction: column;
  gap: 8px;
  flex: 1;
}
.board > .col-done > .col-header { flex: 0 0 36px; }
.board > .col-done > .card       { flex: 0 0 64px; }
"""),

    ("Social Feed", """
/* 3-level: Feed → Posts → Avatar+Content+Actions */
.feed {
  display: flex;
  flex-direction: column;
  gap: 10px;
}
.feed > .post {
  display: flex;
  flex-direction: column;
  gap: 6px;
  flex: 0 0 auto;
}
.feed > .post > .post-header {
  display: flex;
  flex-direction: row;
  align-items: center;
  gap: 8px;
  flex: 0 0 40px;
}
.feed > .post > .post-header > .avatar { flex: 0 0 36px; }
.feed > .post > .post-header > .meta   { flex: 1; }
.feed > .post > .post-header > .time   { flex: 0 0 50px; }
.feed > .post > .body    { flex: 0 0 60px; }
.feed > .post > .actions {
  display: flex;
  flex-direction: row;
  gap: 10px;
  flex: 0 0 32px;
}
.feed > .post > .actions > .like    { flex: 0 0 48px; }
.feed > .post > .actions > .comment { flex: 0 0 64px; }
.feed > .post > .actions > .share   { flex: 0 0 48px; }
.feed > .post > .actions > .spacer  { flex: 1; }
.feed > .post > .actions > .more    { flex: 0 0 32px; }
"""),

    // ── New spec properties demo ─────────────────────────────────────────────

    ("Absolute + Z-Index", """
/* Demonstrates: padding, width, height, overflow, z-index, position: absolute */
.card {
  display: flex;
  flex-direction: row;
  align-items: center;
  gap: 10px;
  padding: 16px;
  overflow: hidden;
}

/* In-flow items */
.card > .avatar {
  flex: 0 0 48px;
  height: 48px;
}
.card > .content { flex: 1; }
.card > .badge {
  flex: 0 0 56px;
  height: 28px;
  z-index: 2;
}

/* Out-of-flow: absolutely positioned overlay */
.card > .ribbon {
  position: absolute;
  top: 0px;
  right: 0px;
  width: 60px;
  height: 20px;
  z-index: 10;
}
"""),

    ("Padding Demo", """
/* Padding on containers at every nesting level */
.page {
  display: flex;
  flex-direction: column;
  gap: 12px;
  padding: 20px;
}
.page > .header {
  display: flex;
  flex-direction: row;
  align-items: center;
  gap: 8px;
  padding: 8px 16px;
  flex: 0 0 52px;
}
.page > .header > .logo  { flex: 0 0 80px; }
.page > .header > .title { flex: 1; }
.page > .header > .btn   { flex: 0 0 64px; }
.page > .body {
  display: flex;
  flex-direction: row;
  gap: 12px;
  padding: 0px 8px;
  flex: 1;
}
.page > .body > .sidebar { flex: 0 0 140px; }
.page > .body > .main    { flex: 1; }
"""),

    ("Width + Height", """
/* Explicit width/height constraints override flex-basis auto */
.grid {
  display: flex;
  flex-direction: row;
  flex-wrap: wrap;
  gap: 10px;
  align-items: flex-start;
}
.grid > .card-sm {
  width: 80px;
  height: 60px;
}
.grid > .card-md {
  width: 140px;
  height: 80px;
}
.grid > .card-lg {
  width: 200px;
  height: 100px;
}
.grid > .card-pct {
  width: 45%;
  height: 70px;
}
"""),
]
