import SwiftUI
import ProgressCore

struct WelcomeView: View {
    @Environment(AuthStore.self) private var auth
    @State private var showingAccount = false

    var body: some View {
        VStack(spacing: 24) {
            Spacer()
            Image(systemName: "point.topleft.down.to.point.bottomright.curvepath")
                .font(.system(size: 56))
                .foregroundStyle(.tint)
            VStack(spacing: 8) {
                Text("PROGRESS ONE").font(.largeTitle.bold())
                Text("One Life. One System. Continuous Growth.")
                    .foregroundStyle(.secondary)
            }
            VStack(alignment: .leading, spacing: 12) {
                Label("Your tasks and workspaces on iPhone and Mac", systemImage: "laptopcomputer.and.iphone")
                Label("Works offline, syncs when you're back online", systemImage: "icloud.and.arrow.up")
                Label("Your data stays private to your account", systemImage: "lock.shield")
            }
            .frame(maxWidth: 420, alignment: .leading)
            Spacer()
            VStack(spacing: 12) {
                Button {
                    showingAccount = true
                } label: {
                    Text("Sign in to sync").frame(maxWidth: 360)
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)

                Button("Use on this device only for now") {
                    auth.useOnThisDeviceOnly()
                }
                .controlSize(.large)
            }
            .padding(.bottom, 32)
        }
        .padding()
        .sheet(isPresented: $showingAccount) {
            AccountSetupView()
        }
    }
}

/// Supabase project details plus email sign-in or sign-up.
struct AccountSetupView: View {
    @Environment(AuthStore.self) private var auth
    @Environment(SyncCoordinator.self) private var sync
    @Environment(\.dismiss) private var dismiss

    @State private var urlText = ""
    @State private var anonKey = ""
    @State private var email = ""
    @State private var password = ""
    @State private var creatingAccount = false
    @State private var working = false
    @State private var message: String?

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField("Project URL, e.g. abcd1234.supabase.co", text: $urlText)
                        .autocorrectionDisabled()
                        #if os(iOS)
                        .textInputAutocapitalization(.never)
                        .keyboardType(.URL)
                        #endif
                    TextField("anon public key", text: $anonKey, axis: .vertical)
                        .lineLimit(1...4)
                        .autocorrectionDisabled()
                        #if os(iOS)
                        .textInputAutocapitalization(.never)
                        #endif
                } header: {
                    Text("Your Supabase project")
                } footer: {
                    Text("In Supabase, open Project Settings → API and copy the Project URL and the anon public key. Use the same values on your iPhone and your Mac.")
                }

                Section {
                    Picker("", selection: $creatingAccount) {
                        Text("Sign in").tag(false)
                        Text("Create account").tag(true)
                    }
                    .pickerStyle(.segmented)
                    .labelsHidden()
                    TextField("Email", text: $email)
                        .autocorrectionDisabled()
                        #if os(iOS)
                        .textContentType(.emailAddress)
                        .textInputAutocapitalization(.never)
                        .keyboardType(.emailAddress)
                        #endif
                    SecureField("Password (at least 8 characters)", text: $password)
                        #if os(iOS)
                        .textContentType(creatingAccount ? .newPassword : .password)
                        #endif
                } header: {
                    Text("Your account")
                } footer: {
                    Text("Create the account once, on either device. Then sign in with the same email on the other device.")
                }

                if let message {
                    Section {
                        Text(message).foregroundStyle(.orange)
                    }
                }
            }
            .formStyle(.grouped)
            .navigationTitle("Sign in to sync")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    if working {
                        ProgressView()
                    } else {
                        Button(creatingAccount ? "Create" : "Sign In") { Task { await submit() } }
                            .disabled(urlText.isEmpty || anonKey.isEmpty || email.isEmpty || password.count < 8)
                    }
                }
            }
            .onAppear {
                if let config = auth.config {
                    urlText = config.url.absoluteString
                    anonKey = config.anonKey
                }
            }
        }
        #if os(macOS)
        .frame(minWidth: 480, minHeight: 520)
        #endif
    }

    private func submit() async {
        message = nil
        guard auth.saveConfig(urlText: urlText, anonKey: anonKey) else {
            message = "That project URL or key doesn't look right. Copy both again from Supabase."
            return
        }
        working = true
        defer { working = false }
        do {
            if creatingAccount {
                let signedIn = try await auth.signUp(email: email, password: password)
                guard signedIn else {
                    message = "Check your email and tap the confirmation link, then come back and choose Sign in."
                    creatingAccount = false
                    return
                }
            } else {
                try await auth.signIn(email: email, password: password)
            }
            sync.requestSync(after: .milliseconds(100))
            dismiss()
        } catch AuthError.invalidCredentials(let text) {
            message = text
        } catch AuthError.offline {
            message = "Couldn't reach Supabase. Check your internet connection and the project URL."
        } catch AuthError.server(let text) {
            message = text
        } catch {
            message = error.localizedDescription
        }
    }
}
