import SwiftUI
#if os(iOS)
import UIKit
#endif

struct SettingsSheet: View {
    @Bindable var locationManager: LocationManager
    var storage: StorageService
    @Environment(\.dismiss) private var dismiss

    @State private var webCodeLoading = false
    @State private var webCode: String?
    @State private var selectedMode: UpdateMode = .adaptive
    @State private var showDeleteConfirm = false
    @State private var deleteError: String?
    @State private var showPrivacyPolicy = false

    var body: some View {
        ZStack {
            Color.pcBg.ignoresSafeArea()

            ScrollView {
                VStack(alignment: .leading, spacing: 0) {
                    // Header
                    HStack {
                        Text("Settings")
                            .font(.system(size: 22, weight: .heavy, design: .rounded))
                            .foregroundStyle(Color.pcText)
                            .accessibilityAddTraits(.isHeader)
                        Spacer()
                        Button { dismiss() } label: {
                            Text("Done")
                                .font(.system(size: 16, weight: .medium))
                                .foregroundStyle(Color.pcAccent)
                        }
                        .accessibilityLabel("Done")
                        .accessibilityHint("Closes settings")
                    }
                    .padding(.horizontal, 24)
                    .padding(.top, 20)
                    .padding(.bottom, 28)

                    // WEB LOGIN CODE
                    if storage.getPairingToken() != nil {
                        sectionHeader("Web dashboard")

                        VStack(spacing: 0) {
                            // Open Dashboard
                            Button {
                                openDashboard()
                            } label: {
                                HStack {
                                    VStack(alignment: .leading, spacing: 4) {
                                        Text("Open Dashboard")
                                            .font(.system(size: 17, weight: .semibold, design: .rounded))
                                            .foregroundStyle(Color.pcText)
                                        Text("Opens the web dashboard in your browser, automatically signed in.")
                                            .font(.system(size: 14))
                                            .foregroundStyle(Color.pcText2)
                                            .multilineTextAlignment(.leading)
                                    }
                                    Spacer()
                                    if webCodeLoading {
                                        ProgressView().tint(Color.pcAccent)
                                    }
                                }
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .padding(16)
                            }
                            .disabled(webCodeLoading)
                            .accessibilityLabel("Open Dashboard")
                            .accessibilityHint("Opens the web dashboard in Safari, automatically signed in")

                            Divider().overlay(Color.pcBorder).padding(.leading, 16)

                            // Generate sign-in code
                            if let webCode {
                                VStack(alignment: .leading, spacing: 4) {
                                    Text("Sign-in code:")
                                        .font(.system(size: 14))
                                        .foregroundStyle(Color.pcText2)
                                    Text(webCode)
                                        .font(.system(size: 28, weight: .bold, design: .monospaced))
                                        .foregroundStyle(Color.pcAccent)
                                        .tracking(4)
                                        .accessibilityLabel("Web login code: \(webCode)")
                                    Text("Enter this code on any browser. Expires in 5 minutes.")
                                        .font(.system(size: 12))
                                        .foregroundStyle(Color.pcText3)
                                }
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .padding(16)
                            } else {
                                Button {
                                    generateWebCode()
                                } label: {
                                    VStack(alignment: .leading, spacing: 4) {
                                        Text("Generate Sign-In Code")
                                            .font(.system(size: 17, weight: .semibold, design: .rounded))
                                            .foregroundStyle(Color.pcText)
                                        Text("Creates a code you can type into any browser to sign in.")
                                            .font(.system(size: 14))
                                            .foregroundStyle(Color.pcText2)
                                            .multilineTextAlignment(.leading)
                                    }
                                    .frame(maxWidth: .infinity, alignment: .leading)
                                    .padding(16)
                                }
                                .disabled(webCodeLoading)
                                .accessibilityLabel("Generate Sign-In Code")
                                .accessibilityHint("Creates a code you can type into any browser to sign in to the dashboard")
                            }
                        }
                        .background(
                            RoundedRectangle(cornerRadius: 12)
                                .fill(Color.pcSurface)
                                .overlay(RoundedRectangle(cornerRadius: 12).stroke(Color.pcBorder, lineWidth: 1))
                        )
                        .padding(.horizontal, 24)
                    } // end web dashboard section

                    // UPDATE MODE
                    sectionHeader("Update mode")

                    VStack(spacing: 0) {
                        ForEach(Array(UpdateMode.allCases.enumerated()), id: \.element) { index, mode in
                            updateModeRow(mode: mode, isSelected: selectedMode == mode, isLast: index == UpdateMode.allCases.count - 1)
                        }
                    }
                    .background(
                        RoundedRectangle(cornerRadius: 12)
                            .fill(Color.pcSurface)
                            .overlay(RoundedRectangle(cornerRadius: 12).stroke(Color.pcBorder, lineWidth: 1))
                    )
                    .padding(.horizontal, 24)


                    // ACCOUNT & DATA
                    sectionHeader("Account & data")

                    VStack(spacing: 0) {
                        // Privacy Settings
                        Button {
                            showPrivacyPolicy = true
                        } label: {
                            VStack(alignment: .leading, spacing: 4) {
                                Text("Privacy Settings")
                                    .font(.system(size: 17, weight: .semibold, design: .rounded))
                                    .foregroundStyle(Color.pcText)
                                Text("Review app privacy details and system permissions.")
                                    .font(.system(size: 14))
                                    .foregroundStyle(Color.pcText2)
                                    .multilineTextAlignment(.leading)
                            }
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(16)
                        }
                        .accessibilityLabel("Privacy Settings")
                        .accessibilityHint("Opens the privacy policy in a browser")

                        Divider().overlay(Color.pcBorder).padding(.leading, 16)

                        // Sign out (local only — clears keychain token)
                        Button {
                            locationManager.stopTracking()
                            storage.clearAll()
                            dismiss()
                        } label: {
                            VStack(alignment: .leading, spacing: 4) {
                                Text("Sign Out")
                                    .font(.system(size: 17, weight: .semibold, design: .rounded))
                                    .foregroundStyle(Color.pcWarning)
                                Text("Clears your pairing token from this device. Your server account is not deleted.")
                                    .font(.system(size: 14))
                                    .foregroundStyle(Color.pcText2)
                                    .multilineTextAlignment(.leading)
                            }
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(16)
                        }
                        .accessibilityLabel("Sign Out")
                        .accessibilityHint("Clears your local credentials and returns to the sign-in screen")

                        Divider().overlay(Color.pcBorder).padding(.leading, 16)

                        // Delete All Data
                        Button {
                            showDeleteConfirm = true
                        } label: {
                            VStack(alignment: .leading, spacing: 4) {
                                Text("Delete All Data")
                                    .font(.system(size: 17, weight: .semibold, design: .rounded))
                                    .foregroundStyle(Color.pcError)
                                Text("Permanently delete your account and all stored data.")
                                    .font(.system(size: 14))
                                    .foregroundStyle(Color.pcText2)
                                    .multilineTextAlignment(.leading)
                            }
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(16)
                        }
                        .accessibilityLabel("Delete All Data")
                        .accessibilityHint("Permanently deletes your account and all stored data. This cannot be undone.")
                    }
                    .background(
                        RoundedRectangle(cornerRadius: 12)
                            .fill(Color.pcSurface)
                            .overlay(RoundedRectangle(cornerRadius: 12).stroke(Color.pcBorder, lineWidth: 1))
                    )
                    .padding(.horizontal, 24)

                    Spacer(minLength: 40)
                }
            }
        }
        .preferredColorScheme(.dark)
        #if os(iOS)
        .sheet(isPresented: $showPrivacyPolicy) {
            if let url = URL(string: "\(storage.serverUrl)/privacypolicy") {
                SafariView(url: url)
                    .ignoresSafeArea()
            }
        }
        #endif
        .alert("Delete All Data?", isPresented: $showDeleteConfirm) {
            Button("Delete", role: .destructive) { performDelete() }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("This will permanently delete your account and all data from the server. This cannot be undone.")
        }
        .alert("Error", isPresented: .init(
            get: { deleteError != nil },
            set: { if !$0 { deleteError = nil } }
        )) {
            Button("OK") { deleteError = nil }
        } message: {
            Text(deleteError ?? "")
        }
        .onAppear {
            selectedMode = storage.updateMode
            // (token paste UI removed — sign-in now happens via social auth)
        }
    }

    private func performDelete() {
        let apiService = APIService(storage: storage)
        Task {
            do {
                try await apiService.deleteAccount()
            } catch {
                // Server delete may fail if the token is stale or the
                // account no longer exists. That's OK — clear local
                // state anyway so the user can re-sign-in.
                slog("delete server call failed (clearing local state anyway): \(error)")
            }
            locationManager.stopTracking()
            storage.clearAll()
            dismiss()
        }
    }

    private func slog(_ msg: String) {
        // Lightweight debug log — not for production logging.
        #if DEBUG
        print("[PingClaw] \(msg)")
        #endif
    }

    private func sectionHeader(_ title: String) -> some View {
        Text(title.uppercased())
            .font(.system(size: 12, weight: .semibold))
            .tracking(1.5)
            .foregroundStyle(Color.pcAccent)
            .padding(.horizontal, 24)
            .padding(.top, 28)
            .padding(.bottom, 10)
    }

    @ViewBuilder
    private func updateModeRow(mode: UpdateMode, isSelected: Bool, isLast: Bool) -> some View {
        Button {
            selectedMode = mode
            locationManager.changeMode(mode)
        } label: {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(mode.label)
                        .font(.system(size: 17, weight: .semibold, design: .rounded))
                        .foregroundStyle(Color.pcText)
                    Text(mode.settingsDescription)
                        .font(.system(size: 14))
                        .foregroundStyle(Color.pcText2)
                }
                Spacer()
                if isSelected {
                    Image(systemName: "checkmark")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundStyle(Color.pcAccent)
                        .accessibilityHidden(true)
                }
            }
            .padding(16)
        }
        .accessibilityLabel(mode.label)
        .accessibilityValue(isSelected ? "Selected" : "")
        .accessibilityHint(mode.settingsDescription)

        if !isLast {
            Divider().overlay(Color.pcBorder).padding(.leading, 16)
        }
    }

    private func generateWebCode() {
        webCodeLoading = true
        let apiService = APIService(storage: storage)
        Task {
            do {
                let code = try await apiService.requestWebCode()
                webCode = code
                webCodeLoading = false
                // Auto-clear after 5 minutes (matches server TTL).
                Task {
                    try? await Task.sleep(nanoseconds: 5 * 60 * 1_000_000_000)
                    webCode = nil
                }
            } catch {
                webCodeLoading = false
            }
        }
    }

    private func openDashboard() {
        webCodeLoading = true
        let apiService = APIService(storage: storage)
        Task {
            do {
                let code = try await apiService.requestWebCode()
                webCodeLoading = false
                // Open Safari with the code in the URL — the website JS
                // auto-submits it and lands directly on the dashboard.
                let baseURL = storage.serverUrl.trimmingCharacters(in: CharacterSet(charactersIn: "/"))
                if let url = URL(string: "\(baseURL)?webcode=\(code)") {
                    #if os(iOS)
                    await UIApplication.shared.open(url)
                    #endif
                }
            } catch {
                webCodeLoading = false
            }
        }
    }

}
