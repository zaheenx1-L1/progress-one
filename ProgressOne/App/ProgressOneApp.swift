import SwiftUI
import SwiftData

@main
struct ProgressOneApp: App {
    @State private var environment = AppEnvironment()

    var body: some Scene {
        WindowGroup {
            RootView()
                .withAppEnvironment(environment)
        }
        #if os(macOS)
        .defaultSize(width: 1200, height: 780)
        .commands {
            CommandGroup(replacing: .newItem) {
                Button("New Task") { environment.quickAddRequested = true }
                    .keyboardShortcut("n")
            }
            CommandMenu("Sync") {
                Button("Sync Now") { Task { await environment.sync.syncNow() } }
                    .keyboardShortcut("r", modifiers: [.command, .shift])
            }
        }
        #endif

        #if os(macOS)
        Settings {
            NavigationStack { SettingsView() }
                .withAppEnvironment(environment)
                .frame(minWidth: 520, minHeight: 560)
        }
        #endif
    }
}

extension View {
    func withAppEnvironment(_ environment: AppEnvironment) -> some View {
        self
            .environment(environment)
            .environment(environment.auth)
            .environment(environment.sync)
            .environment(environment.preferences)
            .environment(environment.appLock)
            .modelContainer(environment.container)
    }
}
