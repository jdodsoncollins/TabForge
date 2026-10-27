import SwiftUI
import KeyboardCore

@main
struct ScriptKeyboardApp: App {
    @State private var preferences: PreferencesStore
    @State private var tipStore = TipStore()
    init() {
        if ProcessInfo.processInfo.arguments.contains("--uitesting") {
            UserDefaults.standard.removeObject(forKey: "playground.draft")
        }
        _preferences = State(initialValue: PreferencesStore(local: nil))
    }
    var body: some Scene {
        WindowGroup {
            AppRootView()
                .environment(preferences)
                .environment(tipStore)
                .tint(Color(uiColor: ScriptTheme.accent))
                .task { tipStore.startTransactionListener() }
        }
    }
}

private enum AppTab: Hashable { case playground, layouts, settings }

struct AppRootView: View {
    @Environment(PreferencesStore.self) private var preferences
    @Environment(\.scenePhase) private var scenePhase
    @State private var tab = AppTab.playground
    var body: some View {
        TabView(selection: $tab) {
            Tab("Playground", systemImage: "chevron.left.forwardslash.chevron.right", value: .playground) {
                NavigationStack { PlaygroundView(openSettings: { tab = .settings }) }
            }
            Tab("Layouts", systemImage: "keyboard", value: .layouts) {
                NavigationStack { LayoutsView() }
            }
            Tab("Settings", systemImage: "slider.horizontal.3", value: .settings) {
                NavigationStack { SettingsView() }
            }
        }
        .onOpenURL { url in
            if url.scheme == "tabforge", url.host == "settings" { tab = .settings }
        }
        .onChange(of: scenePhase) { _, phase in if phase == .active { preferences.refresh() } }
    }
}
