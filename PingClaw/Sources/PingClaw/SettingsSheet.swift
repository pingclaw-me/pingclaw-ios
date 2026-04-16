import SwiftUI
#if os(iOS)
import UIKit
#endif

struct SettingsSheet: View {
    @Bindable var locationManager: LocationManager
    var storage: StorageService
    @Environment(\.dismiss) private var dismiss

    @State private var tokenInput = ""
    @State private var isEditingToken = false
    @State private var savedMessage: String?
    @State private var serverUrl = ""
    @State private var testStatus: String?
    @State private var testLoading = false
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
                        Spacer()
                        Button { dismiss() } label: {
                            Text("Done")
                                .font(.system(size: 16, weight: .medium))
                                .foregroundStyle(Color.pcAccent)
                        }
                    }
                    .padding(.horizontal, 24)
                    .padding(.top, 20)
                    .padding(.bottom, 28)

                    // PAIRING TOKEN
                    sectionHeader("Pairing token")

                    VStack(alignment: .leading, spacing: 0) {
                        if isEditingToken || storage.getPairingToken() == nil {
                            VStack(alignment: .leading, spacing: 12) {
                                TextField("Paste token from pingclaw.me", text: $tokenInput)
                                    .autocorrectionDisabled()
                                    .textInputAutocapitalization(.never)
                                    .font(.system(size: 15))
                                    .foregroundStyle(Color.pcText)
                                    .padding(12)
                                    .background(
                                        RoundedRectangle(cornerRadius: 8)
                                            .fill(Color.pcSurface2)
                                            .overlay(
                                                RoundedRectangle(cornerRadius: 8)
                                                    .stroke(Color.pcBorder2, lineWidth: 1)
                                            )
                                    )

                                Button { saveToken() } label: {
                                    Text("Save Token")
                                        .font(.system(size: 15, weight: .medium))
                                        .foregroundStyle(Color.pcText)
                                        .frame(maxWidth: .infinity)
                                        .padding(.vertical, 12)
                                        .background(
                                            RoundedRectangle(cornerRadius: 8)
                                                .fill(Color.pcAccent3)
                                                .overlay(
                                                    RoundedRectangle(cornerRadius: 8)
                                                        .stroke(Color.pcAccent2, lineWidth: 1)
                                                )
                                        )
                                }
                                .disabled(tokenInput.trimmingCharacters(in: .whitespaces).isEmpty)

                                if let savedMessage {
                                    Text(savedMessage)
                                        .font(.system(size: 14))
                                        .foregroundStyle(Color.pcAccent)
                                }
                            }
                            .padding(16)
                        } else {
                            let token = storage.getPairingToken() ?? ""
                            HStack {
                                VStack(alignment: .leading, spacing: 4) {
                                    Text("Pairing Token")
                                        .font(.system(size: 17, weight: .semibold, design: .rounded))
                                        .foregroundStyle(Color.pcText)
                                    Text("Used to pair this phone with your PingClaw account.")
                                        .font(.system(size: 14))
                                        .foregroundStyle(Color.pcText2)
                                }
                                Spacer()
                                Text("••••\(token.suffix(4))")
                                    .font(.system(size: 14, design: .monospaced))
                                    .foregroundStyle(Color.pcText2)
                            }
                            .padding(16)

                            Divider().overlay(Color.pcBorder)

                            Button {
                                isEditingToken = true
                                tokenInput = ""
                            } label: {
                                Text("Change Token")
                                    .font(.system(size: 15, weight: .medium))
                                    .foregroundStyle(Color.pcAccent)
                                    .frame(maxWidth: .infinity, alignment: .leading)
                                    .padding(16)
                            }
                        }
                    }
                    .background(
                        RoundedRectangle(cornerRadius: 12)
                            .fill(Color.pcSurface)
                            .overlay(RoundedRectangle(cornerRadius: 12).stroke(Color.pcBorder, lineWidth: 1))
                    )
                    .padding(.horizontal, 24)

                    // UPDATE MODE
                    sectionHeader("Update mode")

                    VStack(spacing: 0) {
                        ForEach(Array(UpdateMode.allCases.enumerated()), id: \.element) { index, mode in
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
                                    if selectedMode == mode {
                                        Image(systemName: "checkmark")
                                            .font(.system(size: 16, weight: .semibold))
                                            .foregroundStyle(Color.pcAccent)
                                    }
                                }
                                .padding(16)
                            }

                            if index < UpdateMode.allCases.count - 1 {
                                Divider().overlay(Color.pcBorder).padding(.leading, 16)
                            }
                        }
                    }
                    .background(
                        RoundedRectangle(cornerRadius: 12)
                            .fill(Color.pcSurface)
                            .overlay(RoundedRectangle(cornerRadius: 12).stroke(Color.pcBorder, lineWidth: 1))
                    )
                    .padding(.horizontal, 24)

                    #if DEBUG
                    // SERVER URL (debug only)
                    sectionHeader("Server URL")

                    VStack(spacing: 0) {
                        TextField("Server URL", text: $serverUrl)
                            .autocorrectionDisabled()
                            .textInputAutocapitalization(.never)
                            .keyboardType(.URL)
                            .font(.system(size: 15))
                            .foregroundStyle(Color.pcText)
                            .padding(14)
                            .onChange(of: serverUrl) { _, newValue in
                                storage.serverUrl = newValue
                            }

                        Divider().overlay(Color.pcBorder)

                        Button {
                            sendTest()
                        } label: {
                            HStack {
                                Text("Send test update")
                                    .font(.system(size: 15, weight: .medium))
                                    .foregroundStyle(Color.pcAccent)
                                Spacer()
                                if testLoading {
                                    ProgressView().tint(Color.pcAccent)
                                }
                            }
                            .padding(14)
                        }
                        .disabled(testLoading)

                        if let testStatus {
                            Text(testStatus)
                                .font(.system(size: 14))
                                .foregroundStyle(testStatus.hasPrefix("\u{2713}") ? Color.pcAccent : Color.pcError)
                                .padding(.horizontal, 14)
                                .padding(.bottom, 12)
                        }
                    }
                    .background(
                        RoundedRectangle(cornerRadius: 12)
                            .fill(Color.pcSurface)
                            .overlay(RoundedRectangle(cornerRadius: 12).stroke(Color.pcBorder, lineWidth: 1))
                    )
                    .padding(.horizontal, 24)
                    #endif

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
            serverUrl = storage.serverUrl
            selectedMode = storage.updateMode
            isEditingToken = storage.getPairingToken() == nil
        }
    }

    private func performDelete() {
        let apiService = APIService(storage: storage)
        Task {
            do {
                try await apiService.deleteAccount()
                locationManager.stopTracking()
                storage.clearAll()
                dismiss()
            } catch {
                deleteError = "Failed to delete: \(error.localizedDescription)"
            }
        }
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

    private func saveToken() {
        let trimmed = tokenInput.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else { return }
        if storage.savePairingToken(trimmed) {
            isEditingToken = false
            tokenInput = ""
            savedMessage = "Saved \u{2713}"
            Task {
                try? await Task.sleep(nanoseconds: 1_500_000_000)
                savedMessage = nil
            }
        }
    }

    private func sendTest() {
        testLoading = true
        testStatus = nil
        let apiService = APIService(storage: storage)
        Task {
            do {
                try await apiService.sendTestUpdate()
                testStatus = "\u{2713} Sent"
            } catch {
                testStatus = "\u{2717} Failed: \(error.localizedDescription)"
            }
            testLoading = false
            Task {
                try? await Task.sleep(nanoseconds: 3_000_000_000)
                testStatus = nil
            }
        }
    }
}
