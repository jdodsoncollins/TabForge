import SwiftUI
import KeyboardCore

struct LayoutsView: View {
    @Environment(PreferencesStore.self) private var preferences
    @Environment(\.verticalSizeClass) private var verticalSizeClass
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @State private var output = "Try a few keys…"
    @State private var previewHeight: CGFloat?
    var body: some View {
        GeometryReader { geometry in
            let width = max(0, geometry.size.width - 24)
            let layout = preferences.settings.showNavigationRow && width >= 650
                ? KeyboardLayout.tabletop : KeyboardLayout.resolve(width: width)
            // The host area, rather than the short embedded preview, determines
            // height pressure. This avoids a compact preview forcing itself on.
            let compactHeight = KeyboardHeightPolicy.resolve(
                mode: preferences.settings.heightMode,
                availableHeight: Double(geometry.size.height),
                compactVertical: verticalSizeClass == .compact,
                tabletop: false
            )
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    VStack(alignment: .leading, spacing: 10) {
                        Text("The right keys.\nFor the space you have.")
                            .font(.system(.title, weight: .bold))
                        Text("A familiar phone keyboard gains more keys on Duo and iPad, and gives screen space back when the app window is short.")
                            .font(.body).foregroundStyle(.secondary)
                    }.padding(.horizontal, 20)

                    VStack(alignment: .leading, spacing: 0) {
                        let titleLayout = dynamicTypeSize.isAccessibilitySize
                            ? AnyLayout(VStackLayout(alignment: .leading, spacing: 8))
                            : AnyLayout(HStackLayout(spacing: 8))
                        titleLayout {
                            Label("Keyboard preview", systemImage: "keyboard").font(.subheadline).fontWeight(.semibold)
                            if !dynamicTypeSize.isAccessibilitySize { Spacer() }
                            Text(compactHeight ? "Compact height" : layout.rawValue)
                                .font(.system(.caption, design: .monospaced)).foregroundStyle(Color(uiColor: ScriptTheme.accent))
                        }.padding(16)
                        Text(output.isEmpty ? "Try a few keys…" : output)
                            .font(.system(.body, design: .monospaced))
                            .frame(maxWidth: .infinity, minHeight: 54, alignment: .leading)
                            .lineLimit(3).padding(.horizontal, 16).padding(.bottom, 12)
                        KeyboardDemo(preferences: preferences, output: $output, availableHostSize: geometry.size, onHeightChange: updatePreviewHeight)
                            .frame(height: previewHeight ?? demoHeight(layout, compactHeight: compactHeight))
                    }
                    .background(Color(uiColor: .secondarySystemGroupedBackground))
                    .clipShape(.rect(cornerRadius: 16))
                    .padding(.horizontal, 12)

                    VStack(spacing: 0) {
                        layoutRow("Compact height", symbol: "rectangle.compress.vertical", detail: "Four typing rows keep the app visible in landscape and short windows. Fn opens navigation, modifiers, symbols, indentation, and settings at the same height.", active: compactHeight)
                        Divider().padding(.leading, 56)
                        layoutRow("Phone", symbol: "iphone", detail: "Familiar QWERTY, dedicated bracket row, Tab, and quick indent controls.", active: !compactHeight && layout == .compact)
                        Divider().padding(.leading, 56)
                        layoutRow("Wide phone", symbol: "iphone.gen3", detail: "A number row, equals and underscore, plus cursor arrows on wider phone displays.", active: !compactHeight && layout == .widePhone)
                        Divider().padding(.leading, 56)
                        layoutRow("Expanded", symbol: "rectangle.split.2x1", detail: "A number row, more punctuation, and visible cursor arrows when there’s room.", active: !compactHeight && layout == .expanded)
                        Divider().padding(.leading, 56)
                        layoutRow("Studio", symbol: "ipad.landscape", detail: "The widest operator row with additional symbols and a spacious typing area.", active: !compactHeight && layout == .studio)
                        Divider().padding(.leading, 56)
                        layoutRow("Tabletop / full", symbol: "laptopcomputer", detail: "A dedicated editing row with Escape, Home, End, and additional terminal navigation. Enable it on wide layouts, or use horizontal tabletop geometry.", active: !compactHeight && layout == .tabletop)
                    }
                    .background(Color(uiColor: .secondarySystemGroupedBackground), in: .rect(cornerRadius: 16))
                    .padding(.horizontal, 20)

                    Label("Built around available space", systemImage: "arrow.up.left.and.arrow.down.right")
                        .font(.headline).padding(.horizontal, 20)
                    Text("Key capacity follows usable width, while keyboard height follows the app’s available height. Landscape phones, closed Duo landscape, and short iPad multitasking windows use compact height automatically. Open Duo and larger iPad windows retain their extra rows. On iOS 27.1, keys avoid fold and camera regions. A horizontal fold requests the full lower panel for tabletop typing; iOS and the host app determine the final area.")
                        .foregroundStyle(.secondary).padding(.horizontal, 20)
                    Text("Choose Automatic, Compact, or Full in keyboard height settings. Drag the space bar to move the cursor. Double-tap Shift for Caps Lock. Short-press the gear for quick settings; in compact height, open Fn first.")
                        .font(.footnote).foregroundStyle(.secondary).padding(.horizontal, 20)
                }.padding(.vertical, 20).padding(.bottom, 24)
            }
            .background(Color(uiColor: .systemGroupedBackground))
        }
        .navigationTitle("Layouts")
    }
    private func demoHeight(_ layout: KeyboardLayout, compactHeight: Bool) -> CGFloat {
        if compactHeight { return 4 * (44 + 4) + 8 }
        let count = layout == .tabletop ? 7 : layout != .compact || preferences.settings.showNumberRow ? 6 : 5
        return 44 + CGFloat(count) * CGFloat(preferences.settings.keySize.height + 6) + 8
    }
    private func updatePreviewHeight(_ height: CGFloat) {
        guard height.isFinite, height > 0 else { return }
        DispatchQueue.main.async {
            if previewHeight == nil || abs((previewHeight ?? 0) - height) > 0.5 { previewHeight = height }
        }
    }
    private func layoutRow(_ title: String, symbol: String, detail: String, active: Bool) -> some View {
        HStack(alignment: .top, spacing: 16) {
            // Decorative symbols keep a stable footprint while adjacent text
            // follows Dynamic Type, so a scaled glyph cannot overlap its title.
            Image(systemName: symbol).font(.system(size: 22)).frame(width: 24).foregroundStyle(active ? Color(uiColor: ScriptTheme.accent) : .secondary)
                .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: 5) {
                let titleLayout = dynamicTypeSize.isAccessibilitySize
                    ? AnyLayout(VStackLayout(alignment: .leading, spacing: 5))
                    : AnyLayout(HStackLayout(spacing: 8))
                titleLayout {
                    Text(title).font(.headline)
                    if active { Text("CURRENT").font(.system(.caption2, design: .monospaced).weight(.bold)).foregroundStyle(Color(uiColor: ScriptTheme.accent)) }
                }
                Text(detail).font(.subheadline).foregroundStyle(.secondary)
            }
        }.padding(16).frame(maxWidth: .infinity, alignment: .leading)
    }
}

@MainActor
private final class DemoDocument: TextDocument {
    let memory = MemoryDocument()
    var changed: ((String) -> Void)?
    var before: String? { memory.before }
    var after: String? { memory.after }
    var selectedText: String? { memory.selectedText }
    var hasCompleteContext: Bool { memory.hasCompleteContext }
    func insert(_ text: String) { memory.insert(text); changed?(memory.text) }
    func deleteBackward() { memory.deleteBackward(); changed?(memory.text) }
    func move(by offset: Int) { memory.move(by: offset) }
    func deleteSurroundingText(before prefix: String, after suffix: String) -> Bool {
        let deleted = memory.deleteSurroundingText(before: prefix, after: suffix)
        if deleted { changed?(memory.text) }
        return deleted
    }
}

private struct KeyboardDemo: UIViewRepresentable {
    let preferences: PreferencesStore
    @Binding var output: String
    let availableHostSize: CGSize
    var onHeightChange: (CGFloat) -> Void
    func makeUIView(context: Context) -> CodingKeyboardView {
        let document = DemoDocument()
        document.changed = { output = $0 }
        let view = CodingKeyboardView(document: document, preferences: preferences)
        view.isPreview = true
        view.availableHostSize = availableHostSize
        view.onHeightChange = onHeightChange
        view.onOpenSettings = { [weak view] in view?.showStatus("Open the Settings tab below") }
        view.onNextKeyboard = { [weak view] in view?.showStatus("Use the globe in a text field") }
        return view
    }
    func updateUIView(_ view: CodingKeyboardView, context: Context) {
        view.availableHostSize = availableHostSize
        view.onHeightChange = onHeightChange
        view.applySettings()
    }
}
