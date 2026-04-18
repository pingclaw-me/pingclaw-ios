import SwiftUI

struct ContentView: View {
    @Bindable var locationManager: LocationManager
    var storage: StorageService
    @State private var showSettings = false
    @State private var tick = 0
    @State private var timer: Timer?
    @State private var shareCooldown = false
    @State private var isSignedIn = false
    #if DEBUG
    @State private var serverUrl = ""
    #endif

    var body: some View {
        ZStack {
            Color.pcBg.ignoresSafeArea()

            VStack(alignment: .leading, spacing: 0) {
                // Header — settings button on the right (only when signed in)
                if isSignedIn {
                    HStack {
                        Spacer()
                        Button { showSettings = true } label: {
                            Text("Settings")
                                .font(.body)
                                .foregroundStyle(Color.pcText2)
                        }
                        .accessibilityLabel("Settings")
                        .accessibilityHint("Opens pairing token, update mode, and account settings")
                    }
                    .padding(.horizontal, 24)
                    .padding(.top, 12)
                }

                // Wordmark (includes tagline)
                if let url = Bundle.module.url(forResource: "Wordmark", withExtension: "png"),
                   let data = try? Data(contentsOf: url),
                   let uiImage = UIImage(data: data) {
                    Image(uiImage: uiImage)
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .frame(maxWidth: 280)
                        .frame(maxWidth: .infinity)
                        .padding(.horizontal, 24)
                        .padding(.vertical, 32)
                        .accessibilityLabel("PingClaw — Location context for AI")
                        .accessibilityAddTraits(.isHeader)
                }

                // Sign-in card — shown when no pairing token exists.
                if !isSignedIn {
                    SignInView(storage: storage) {
                        isSignedIn = true
                        locationManager.startTracking()
                    }
                    .padding(.top, 32)
                }

                // Location Sharing card — shown once signed in.
                if isSignedIn {
                Button {
                    handleToggle(!locationManager.isTracking)
                } label: {
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Text("Location Sharing")
                                .font(.system(.title3, design: .rounded, weight: .bold))
                                .foregroundStyle(Color.pcText)
                            Spacer()
                            statusPill(on: locationManager.isTracking)
                        }

                        Text(locationManager.isTracking
                             ? "Tap to pause sharing from this device."
                             : "Tap to start sharing from this device.")
                            .font(.subheadline)
                            .foregroundStyle(Color.pcText2)
                    }
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Location Sharing")
                .accessibilityValue(locationManager.isTracking ? "On" : "Off")
                .accessibilityHint(locationManager.isTracking
                    ? "Double-tap to pause sharing"
                    : "Double-tap to start sharing")
                .padding(20)
                .background(
                    RoundedRectangle(cornerRadius: 12)
                        .fill(Color.pcSurface)
                        .overlay(
                            RoundedRectangle(cornerRadius: 12)
                                .stroke(Color.pcBorder, lineWidth: 1)
                        )
                )
                .padding(.horizontal, 24)
                .padding(.top, 16)

                // Status cards + share button
                if locationManager.isTracking {
                    HStack(spacing: 12) {
                        statCard(title: "Last update", value: formatTimeAgo(locationManager.lastUpdateTime))
                        statCard(title: "Accuracy", value: formatAccuracy(locationManager.lastAccuracyMetres))
                    }
                    .padding(.horizontal, 24)
                    .padding(.top, 16)

                    Button {
                        guard !shareCooldown else { return }
                        locationManager.requestImmediatePing()
                        withAnimation(.easeInOut(duration: 0.2)) {
                            shareCooldown = true
                        }
                        Task {
                            try? await Task.sleep(nanoseconds: 5_000_000_000)
                            await MainActor.run {
                                withAnimation(.easeInOut(duration: 0.2)) {
                                    shareCooldown = false
                                }
                            }
                        }
                    } label: {
                        HStack(spacing: 8) {
                            if shareCooldown {
                                Image(systemName: "checkmark.circle.fill")
                            }
                            Text(shareCooldown ? "Sent" : "Share Current Location Now")
                        }
                        .font(.body.weight(.medium))
                        .foregroundStyle(shareCooldown ? Color.pcText2 : Color.pcText)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                        .background(
                            RoundedRectangle(cornerRadius: 8)
                                .fill(shareCooldown ? Color.pcSurface : Color.pcAccent3)
                                .overlay(
                                    RoundedRectangle(cornerRadius: 8)
                                        .stroke(shareCooldown ? Color.pcBorder2 : Color.pcAccent2, lineWidth: 1)
                                )
                        )
                    }
                    .buttonStyle(.plain)
                    .disabled(shareCooldown)
                    .accessibilityLabel(shareCooldown ? "Location sent" : "Share current location now")
                    .accessibilityHint(shareCooldown ? "Waiting before you can send again" : "Sends your current location to your agent immediately")
                    .padding(.horizontal, 24)
                    .padding(.top, 16)
                }
                } // end "if storage.getPairingToken() != nil"

                Spacer()

                #if DEBUG
                VStack(alignment: .leading, spacing: 8) {
                    Text("SERVER URL")
                        .font(.caption2.weight(.semibold))
                        .tracking(1.4)
                        .foregroundStyle(Color.pcText3)
                    TextField("Server URL", text: $serverUrl)
                        .autocorrectionDisabled()
                        .textInputAutocapitalization(.never)
                        .keyboardType(.URL)
                        .font(.system(.caption, design: .monospaced))
                        .foregroundStyle(Color.pcText)
                        .padding(10)
                        .background(
                            RoundedRectangle(cornerRadius: 8)
                                .fill(Color.pcSurface)
                                .overlay(RoundedRectangle(cornerRadius: 8).stroke(Color.pcBorder, lineWidth: 1))
                        )
                        .onChange(of: serverUrl) { _, newValue in
                            storage.serverUrl = newValue
                        }
                        .onAppear { serverUrl = storage.serverUrl }
                }
                .padding(.horizontal, 24)
                .padding(.bottom, 16)
                #endif
            }
        }
        .preferredColorScheme(.dark)
        .sheet(isPresented: $showSettings, onDismiss: {
            isSignedIn = storage.getPairingToken() != nil
        }) {
            SettingsSheet(locationManager: locationManager, storage: storage)
        }
        .onAppear {
            isSignedIn = storage.getPairingToken() != nil
            startTimer()
        }
        .onDisappear { stopTimer() }
    }

    private func statusPill(on: Bool) -> some View {
        HStack(spacing: 6) {
            if on {
                Circle()
                    .fill(Color.pcAccent)
                    .frame(width: 6, height: 6)
                    .accessibilityHidden(true)
            }
            Text(on ? "ON" : "OFF")
                .font(.system(.caption2, design: .monospaced, weight: .medium))
                .tracking(0.8)
                .foregroundStyle(on ? Color.pcAccent : Color.pcText3)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
        .background(
            Capsule()
                .fill(on ? Color.pcAccentBg : Color.pcSurface2)
                .overlay(
                    Capsule()
                        .stroke(on ? Color.pcAccent3 : Color.pcBorder2, lineWidth: 1)
                )
        )
        .accessibilityHidden(true)
    }

    private func statCard(title: String, value: String) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title.uppercased())
                .font(.caption2.weight(.medium))
                .tracking(1.4)
                .foregroundStyle(Color.pcText3)
            Text(value)
                .font(.system(.callout, design: .monospaced, weight: .medium))
                .foregroundStyle(Color.pcText)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color.pcSurface)
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(Color.pcBorder, lineWidth: 1)
                )
        )
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(title): \(value)")
    }

    private func handleToggle(_ value: Bool) {
        if value {
            guard storage.getPairingToken() != nil else {
                showSettings = true
                return
            }
            locationManager.startTracking()
        } else {
            locationManager.stopTracking()
        }
    }

    private func startTimer() {
        timer = Timer.scheduledTimer(withTimeInterval: 5, repeats: true) { _ in
            Task { @MainActor in
                tick += 1
                if isSignedIn && storage.getPairingToken() == nil {
                    isSignedIn = false
                }
            }
        }
    }

    private func stopTimer() {
        timer?.invalidate()
        timer = nil
    }

    private func formatTimeAgo(_ date: Date?) -> String {
        let _ = tick
        guard let date else { return "--" }
        let seconds = Int(Date().timeIntervalSince(date))
        if seconds < 10 { return "Just now" }
        if seconds < 60 { return "\(seconds)s ago" }
        if seconds < 3600 { return "\(seconds / 60)m ago" }
        if seconds < 86400 { return "\(seconds / 3600)h ago" }
        return "\(seconds / 86400)d ago"
    }

    private func formatAccuracy(_ metres: Double) -> String {
        if metres <= 0 { return "--" }
        return "± \(Int(metres))m"
    }
}
