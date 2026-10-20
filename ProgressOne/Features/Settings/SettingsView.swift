import SwiftUI
import ProgressCore

struct SettingsView: View {
    @Environment(AuthStore.self) private var auth
    @Environment(SyncCoordinator.self) private var sync
    @Environment(PreferencesStore.self) private var preferences
    @Environment(AppLock.self) private var appLock
    @State private var showingAccount = false
    @State private var confirmingSignOut = false

    var body: some View {
        @Bindable var preferences = preferences

        Form {
            Section("Account and sync") {
                if auth.mode == .signedIn {
                    LabeledContent("Signed in as", value: auth.session?.email ?? "Unknown")
                    LabeledContent("Server", value: auth.config?.url.host ?? "")
                    NavigationLink("Sync status") { SyncStatusView() }
                    Button("Sign out", role: .destructive) { confirmingSignOut = true }
                } else {
                    Text("Using this device only. Sign in to sync with your other device.")
                        .foregroundStyle(.secondary)
                    Button("Sign in to sync") { showingAccount = true }
                }
            }

            Section {
                Toggle("Lock with \(appLock.biometryName)", isOn: $preferences.appLockEnabled)
            } header: {
                Text("Privacy")
            } footer: {
                Text("Asks for \(appLock.biometryName) when you open the app.")
            }

            Section("Region") {
                Picker("Time zone", selection: $preferences.regional.timeZoneIdentifier) {
                    ForEach(TimeZone.knownTimeZoneIdentifiers, id: \.self) { Text($0).tag($0) }
                }
                Picker("Currency", selection: $preferences.regional.currencyCode) {
                    ForEach(PreferencesStore.currencies, id: \.self) { Text($0).tag($0) }
                }
                Picker("Week starts on", selection: $preferences.regional.firstWeekday) {
                    let names = Calendar(identifier: .gregorian).weekdaySymbols
                    ForEach(1...7, id: \.self) { day in Text(names[day - 1]).tag(day) }
                }
            }

            Section("About") {
                LabeledContent("Version", value: Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "–")
                LabeledContent("Build stage", value: "Step 1: foundation")
            }
        }
        .formStyle(.grouped)
        .navigationTitle("Settings")
        .sheet(isPresented: $showingAccount) { AccountSetupView() }
        .confirmationDialog("Sign out?", isPresented: $confirmingSignOut) {
            Button("Sign out", role: .destructive) { auth.signOut() }
        } message: {
            Text("Your data stays on this device. Changes made while signed out are sent the next time you sign in with the same account.")
        }
    }
}
