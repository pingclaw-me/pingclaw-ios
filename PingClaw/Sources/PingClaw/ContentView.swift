import SwiftUI

struct ContentView: View {
    @Bindable var locationManager: LocationManager
    var storage: StorageService
    @State private var showSettings = false
    @State private var tick = 0
    @State private var timer: Timer?
    @State private var shareCooldown = false

    var body: some View {
        ZStack {
            Color.pcBg.ignoresSafeArea()

            VStack(alignment: .leading, spacing: 0) {
                // Header — settings button on the right
                HStack {
                    Spacer()
                    Button { showSettings = true } label: {
                        Text("Settings")
                            .font(.system(size: 16, weight: .medium))
                            .foregroundStyle(Color.pcText2)
                    }
                }
                .padding(.horizontal, 24)
                .padding(.top, 12)

                // Wordmark + tagline
                PingClawWordmark(size: 56, stacked: true)
                    .padding(.horizontal, 24)
                    .padding(.top, 24)

                Text("Location context for AI")
                    .font(.system(size: 16))
                    .foregroundStyle(Color.pcText2)
                    .padding(.horizontal, 24)
                    .padding(.top, 8)

                // Location Sharing card — entire card is tappable
                Button {
                    handleToggle(!locationManager.isTracking)
                } label: {
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Text("Location Sharing")
                                .font(.system(size: 22, weight: .bold, design: .rounded))
                                .foregroundStyle(Color.pcText)
                            Spacer()
                            statusPill(on: locationManager.isTracking)
                        }

                        Text(locationManager.isTracking
                             ? "Tap to pause sharing from this device."
                             : "Tap to start sharing from this device.")
                            .font(.system(size: 15))
                            .foregroundStyle(Color.pcText2)
                    }
                }
                .buttonStyle(.plain)
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
                .padding(.top, 32)

                // Status cards
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
                        .font(.system(size: 16, weight: .medium))
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
                    .padding(.horizontal, 24)
                    .padding(.top, 12)
                }

                Spacer()
            }
        }
        .preferredColorScheme(.dark)
        .sheet(isPresented: $showSettings) {
            SettingsSheet(locationManager: locationManager, storage: storage)
        }
        .onAppear { startTimer() }
        .onDisappear { stopTimer() }
    }

    private func statusPill(on: Bool) -> some View {
        HStack(spacing: 6) {
            if on {
                Circle()
                    .fill(Color.pcAccent)
                    .frame(width: 6, height: 6)
            }
            Text(on ? "ON" : "OFF")
                .font(.system(size: 13, weight: .medium, design: .monospaced))
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
    }

    private func statCard(title: String, value: String) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title.uppercased())
                .font(.system(size: 11, weight: .medium))
                .tracking(1.4)
                .foregroundStyle(Color.pcText3)
            Text(value)
                .font(.system(size: 17, weight: .medium, design: .monospaced))
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
