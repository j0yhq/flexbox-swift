import SwiftUI
import FlexLayout

// MARK: - CSS Playground with live preview
// Paste CSS, edit it, see the result instantly in Xcode Preview.

struct FlexPlayground: View {
    @State private var cssText: String = sampleCSS
    @State private var parsed: ParsedCSS = CSSParser.parse(sampleCSS)

    var body: some View {
        HSplitView {
            CSSEditor(cssText: $cssText, parsed: $parsed)
            CSSPreview(parsed: parsed)
        }
        .frame(minWidth: 800, minHeight: 500)
    }
}

// MARK: - Left: CSS Editor

private struct CSSEditor: View {
    @Binding var cssText: String
    @Binding var parsed: ParsedCSS

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Toolbar
            HStack {
                Text("CSS Editor").font(.headline)
                Spacer()
                Button("Copy") {
                    NSPasteboard.general.clearContents()
                    NSPasteboard.general.setString(cssText, forType: .string)
                }
                .buttonStyle(.bordered).controlSize(.small)
                Button("Paste") {
                    if let str = NSPasteboard.general.string(forType: .string) {
                        cssText = str
                        parsed = CSSParser.parse(str)
                    }
                }
                .buttonStyle(.bordered).controlSize(.small)
            }
            .padding(.horizontal, 12).padding(.vertical, 8)

            Divider()

            // Snippet buttons
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 6) {
                    ForEach(snippets, id: \.0) { name, css in
                        Button(name) {
                            cssText = css
                            parsed = CSSParser.parse(css)
                        }
                        .buttonStyle(.bordered).controlSize(.mini)
                    }
                }
                .padding(.horizontal, 12).padding(.vertical, 6)
            }

            Divider()

            // Text editor
            TextEditor(text: $cssText)
                .font(.system(.body, design: .monospaced))
                .padding(8)
                .onChange(of: cssText) { newValue in
                    parsed = CSSParser.parse(newValue)
                }
        }
        .frame(minWidth: 300, maxWidth: 380)
    }
}

// MARK: - Right: Live Preview

private struct CSSPreview: View {
    let parsed: ParsedCSS

    var body: some View {
        GeometryReader { geo in
            ScrollView([.horizontal, .vertical]) {
                let w = max(200, geo.size.width - 40)
                let h = max(200, geo.size.height - 40)

                CSSRendererView(css: parsed, colorOffset: 0, fallbackCount: 4)
                    .frame(minWidth: w, maxWidth: w, minHeight: h, maxHeight: h)
                    .padding(16)
                    .background(Color(white: 0.95))
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .strokeBorder(Color.gray.opacity(0.2))
                    )
                    .padding(20)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

// MARK: - Sample CSS snippets

private let snippets: [(String, String)] = [
    ("Dashboard", sampleCSS),
    ("Navbar", """
    .navbar { display:flex; justify-content:space-between; align-items:center; gap:8px; padding:0 16px; height:56px; }
    .navbar > .logo { flex:0 0 100px; }
    .navbar > .search { flex:1; height:32px; }
    .navbar > .avatar { flex:0 0 36px; height:36px; }
    """),
    ("Holy Grail", """
    .page { display:flex; flex-direction:column; }
    .page > .header { flex:0 0 48px; display:flex; align-items:center; padding:0 16px; gap:8px; }
    .page > .header > .logo { flex:0 0 80px; }
    .page > .header > .title { flex:1; }
    .page > .body { display:flex; flex:1; gap:12px; }
    .page > .body > .sidebar { flex:0 0 160px; }
    .page > .body > .main { flex:1; }
    .page > .body > .aside { flex:0 0 120px; }
    .page > .footer { flex:0 0 32px; }
    """),
    ("Card Grid", """
    .grid { display:flex; flex-wrap:wrap; gap:12px; padding:16px; }
    .grid > .card { display:flex; flex-direction:column; flex:0 0 140px; gap:4px; }
    .card > .image { flex:0 0 100px; }
    .card > .title { flex:0 0 20px; }
    .card > .price { flex:0 0 20px; }
    """),
    ("Kanban", """
    .board { display:flex; gap:12px; align-items:stretch; }
    .board > .col-todo { display:flex; flex-direction:column; gap:8px; flex:1; }
    .board > .col-todo > .header { flex:0 0 32px; }
    .board > .col-todo > .card { flex:0 0 60px; }
    .board > .col-progress { display:flex; flex-direction:column; gap:8px; flex:1; }
    .board > .col-progress > .header { flex:0 0 32px; }
    .board > .col-progress > .card { flex:0 0 60px; }
    .board > .col-done { display:flex; flex-direction:column; gap:8px; flex:1; }
    .board > .col-done > .header { flex:0 0 32px; }
    .board > .col-done > .card { flex:0 0 60px; }
    """),
]

private let sampleCSS = """
.dashboard { display:flex; flex-direction:column; gap:12px; }

.dashboard > .header {
  display:flex; align-items:center; gap:10px;
  flex:0 0 48px;
}
.dashboard > .header > .logo { flex:0 0 100px; }
.dashboard > .header > .search { flex:1; }
.dashboard > .header > .avatar { flex:0 0 36px; height:36px; }

.dashboard > .metrics {
  display:flex; gap:10px; flex:0 0 80px;
}
.dashboard > .metrics > .card { display:flex; flex-direction:column; gap:4px; flex:1; padding:12px; }
.card > .label { flex:0 0 16px; }
.card > .value { flex:1; }

.dashboard > .panels {
  display:flex; gap:12px; flex:1;
}
.dashboard > .panels > .chart { flex:2; }
.dashboard > .panels > .activity { display:flex; flex-direction:column; gap:4px; flex:1; }
.activity > .title { flex:0 0 24px; }
.activity > .row { display:flex; align-items:center; gap:8px; flex:0 0 32px; --repeat:5; }
.row > .icon { flex:0 0 24px; height:24px; }
.row > .label { flex:1; }
.row > .amount { flex:0 0 48px; }
"""

// MARK: - Previews

#Preview("CSS Playground") {
    FlexPlayground()
}
