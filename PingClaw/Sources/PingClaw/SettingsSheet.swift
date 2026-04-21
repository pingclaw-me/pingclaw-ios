import SwiftUI
#if os(iOS)
import UIKit
#endif

struct SettingsSheet: View {
    @Bindable var locationManager: LocationManager
    var storage: StorageService
    @Environment(\.dismiss) private var dismiss

    @State private var selectedMode: UpdateMode = .adaptive
    @State private var showSignOutConfirm = false
    @State private var showDeleteConfirm = false
    @State private var showPrivacy = false
    @State private var showTerms = false
    @State private var showPairingCode = false
    @State private var showServerUrl = false
    @State private var chatGPTURL: String?

    var body: some View {
        ZStack {
            Color.paper.ignoresSafeArea()

            ScrollView {
                VStack(alignment: .leading, spacing: 0) {
                    // Back link
                    BackLink(title: "Home") { dismiss() }
                        .padding(.horizontal, Spacing.screenH)
                        .padding(.top, 6)
                        .padding(.bottom, 20)

                    // Title
                    Text("Settings")
                        .font(Typography.display(34))
                        .foregroundStyle(Color.ink)
                        .padding(.horizontal, Spacing.screenH)
                        .padding(.bottom, 6)

                    // Subtitle
                    Text("Signed in via \(storage.serverUrl.replacingOccurrences(of: "https://", with: ""))")
                        .font(Typography.mono(12))
                        .foregroundStyle(Color.inkFaint)
                        .padding(.horizontal, Spacing.screenH)
                        .padding(.bottom, 26)

                    // UPDATE MODE
                    SectionLabel(title: "Update mode")
                        .padding(.horizontal, Spacing.screenH)

                    SettingsGroup {
                        ForEach(Array(UpdateMode.allCases.enumerated()), id: \.element) { index, mode in
                            updateModeRow(mode: mode, isSelected: selectedMode == mode)
                            if index < UpdateMode.allCases.count - 1 {
                                RowDivider()
                            }
                        }
                    }
                    .padding(.horizontal, Spacing.screenH)

                    // INTEGRATIONS
                    SectionLabel(title: "Integrations")
                        .padding(.horizontal, Spacing.screenH)

                    SettingsGroup {
                        if let chatGPTURL, let url = URL(string: chatGPTURL) {
                            SettingsRow(
                                title: "Open PingClaw GPT",
                                subtitle: "One-tap setup for ChatGPT. After installing, open the GPT from ChatGPT as usual.",
                                trailing: .external
                            ) {
                                #if os(iOS)
                                UIApplication.shared.open(url)
                                #endif
                            }
                            RowDivider()
                        }
                        SettingsRow(
                            title: "Open dashboard on this phone",
                            subtitle: "Mint API keys and configure MCP clients, webhooks, or OpenClaw. Signs in automatically.",
                            trailing: .external
                        ) {
                            openDashboard()
                        }
                        RowDivider()
                        SettingsRow(
                            title: "Get a sign-in code for a computer",
                            subtitle: "Use the dashboard on your laptop. Generates an 8-character code.",
                            trailing: .chevron
                        ) {
                            showPairingCode = true
                        }
                    }
                    .padding(.horizontal, Spacing.screenH)

                    // ACCOUNT & DATA
                    SectionLabel(title: "Account & data")
                        .padding(.horizontal, Spacing.screenH)

                    SettingsGroup {
                        SettingsRow(
                            title: "Privacy settings",
                            subtitle: "Review app privacy details and system permissions.",
                            trailing: .chevron
                        ) {
                            showPrivacy = true
                        }
                        RowDivider()
                        SettingsRow(
                            title: "Terms of service",
                            subtitle: "Review the terms and conditions of use.",
                            trailing: .chevron
                        ) {
                            showTerms = true
                        }
                        RowDivider()
                        SettingsRow(
                            title: "Sign out",
                            subtitle: "Clears your pairing token from this device.",
                            style: .caution
                        ) {
                            showSignOutConfirm = true
                        }
                        RowDivider()
                        SettingsRow(
                            title: "Delete all data",
                            subtitle: "Permanently delete your account and all stored data.",
                            style: .destructive
                        ) {
                            showDeleteConfirm = true
                        }
                    }
                    .padding(.horizontal, Spacing.screenH)

                    // ADVANCED
                    SectionLabel(title: "Advanced")
                        .padding(.horizontal, Spacing.screenH)

                    SettingsGroup {
                        SettingsRow(
                            title: "Server URL",
                            subtitle: storage.serverUrl.replacingOccurrences(of: "https://", with: ""),
                            trailing: .chevron
                        ) {
                            showServerUrl = true
                        }
                    }
                    .padding(.horizontal, Spacing.screenH)

                    Spacer(minLength: 40)
                }
            }
        }
        .navigationDestination(isPresented: $showPairingCode) {
            PairingCodeView(storage: storage)
                .navigationBarHidden(true)
        }
        .navigationDestination(isPresented: $showServerUrl) {
            ServerURLView(storage: storage)
                .navigationBarHidden(true)
        }
        #if os(iOS)
        .sheet(isPresented: $showPrivacy) {
            if let url = URL(string: "\(storage.serverUrl)/privacypolicy?embedded=1") {
                SafariView(url: url).ignoresSafeArea()
            }
        }
        .sheet(isPresented: $showTerms) {
            if let url = URL(string: "\(storage.serverUrl)/termsofservice?embedded=1") {
                SafariView(url: url).ignoresSafeArea()
            }
        }
        #endif
        .alert("Sign Out?", isPresented: $showSignOutConfirm) {
            Button("Sign Out", role: .destructive) {
                locationManager.stopTracking()
                storage.clearAll()
                dismiss()
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("This will clear your credentials from this device. You can sign in again at any time.")
        }
        .alert("Delete All Data?", isPresented: $showDeleteConfirm) {
            Button("Delete", role: .destructive) { performDelete() }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("This will permanently delete your account and all data from the server. This cannot be undone.")
        }
        .onAppear {
            selectedMode = storage.updateMode
        }
        .task {
            await fetchConfig()
        }
    }

    // MARK: - Update mode row

    private func updateModeRow(mode: UpdateMode, isSelected: Bool) -> some View {
        SettingsRow(
            title: mode.label,
            subtitle: mode.settingsDescription,
            trailing: isSelected ? .check : .none
        ) {
            selectedMode = mode
            locationManager.changeMode(mode)
        }
    }

    // MARK: - Actions

    private func openDashboard() {
        let apiService = APIService(storage: storage)
        Task {
            do {
                let code = try await apiService.requestWebCode()
                let baseURL = storage.serverUrl.trimmingCharacters(in: CharacterSet(charactersIn: "/"))
                if let url = URL(string: "\(baseURL)?webcode=\(code)") {
                    #if os(iOS)
                    await UIApplication.shared.open(url)
                    #endif
                }
            } catch {}
        }
    }

    private func performDelete() {
        let apiService = APIService(storage: storage)
        Task {
            do {
                try await apiService.deleteAccount()
            } catch {
                #if DEBUG
                print("[PingClaw] delete failed (clearing local state): \(error)")
                #endif
            }
            locationManager.stopTracking()
            storage.clearAll()
            dismiss()
        }
    }

    private func fetchConfig() async {
        guard let url = URL(string: "\(storage.serverUrl)/pingclaw/config") else { return }
        do {
            let (data, _) = try await URLSession.shared.data(from: url)
            if let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
               let integrations = json["integrations"] as? [String: Any],
               let chatgpt = integrations["chatgpt"] as? [String: Any],
               let gptURL = chatgpt["url"] as? String,
               !gptURL.isEmpty {
                chatGPTURL = gptURL
            }
        } catch {}
    }
}

// MARK: - Server URL settings screen

struct ServerURLView: View {
    var storage: StorageService
    @Environment(\.dismiss) private var dismiss
    @State private var serverUrl = ""

    var body: some View {
        ZStack {
            Color.paper.ignoresSafeArea()

            VStack(alignment: .leading, spacing: 0) {
                BackLink(title: "Settings") { dismiss() }
                    .padding(.horizontal, Spacing.screenH)
                    .padding(.top, 6)
                    .padding(.bottom, 22)

                Text("Server URL")
                    .font(Typography.display(28))
                    .foregroundStyle(Color.ink)
                    .padding(.horizontal, Spacing.screenH)
                    .padding(.bottom, 10)

                Text("Set the server URL if you are running your own pingclaw server. Leave as the default for the hosted service.")
                    .font(Typography.caption())
                    .foregroundStyle(Color.inkSoft)
                    .padding(.horizontal, Spacing.screenH)
                    .padding(.bottom, 28)

                FieldInput(
                    label: "Server URL",
                    text: $serverUrl,
                    placeholder: "https://pingclaw.me",
                    hint: "Default: https://pingclaw.me"
                )
                .padding(.horizontal, Spacing.screenH)
                .onChange(of: serverUrl) { _, newValue in
                    storage.serverUrl = newValue
                }

                Spacer()
            }
        }
        .onAppear {
            serverUrl = storage.serverUrl
        }
    }
}
