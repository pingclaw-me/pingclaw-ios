import SwiftUI
import UIKit

struct ContentView: View {
    @Bindable var locationManager: LocationManager
    var storage: StorageService
    @State private var showSettings = false
    @State private var tick = 0
    @State private var timer: Timer?
    @State private var shareCooldown = false
    @State private var isSignedIn = false

    var body: some View {
        NavigationStack {
            ZStack {
                Color.paper.ignoresSafeArea()

                if isSignedIn {
                    homeView
                } else {
                    SignInView(storage: storage) {
                        isSignedIn = true
                        locationManager.startTracking()
                    }
                }
            }
            .navigationDestination(isPresented: $showSettings) {
                SettingsSheet(locationManager: locationManager, storage: storage)
                    .navigationBarHidden(true)
            }
        }
        .onAppear {
            isSignedIn = storage.getPairingToken() != nil
            startTimer()
        }
        .onDisappear { stopTimer() }
    }

    // MARK: - Home (signed in)

    private var homeView: some View {
        ScrollView {
            VStack(spacing: 0) {
                // Header — Settings link top-right
                HStack {
                    Spacer()
                    Button { showSettings = true } label: {
                        Text("Settings")
                            .font(Typography.body(15, weight: .medium))
                            .foregroundStyle(Color.rust)
                    }
                    .accessibilityLabel("Settings")
                    .accessibilityHint("Opens settings")
                }
                .padding(.horizontal, Spacing.screenH)
                .padding(.top, 6)

                // Wordmark
                VStack(spacing: 14) {
                    WordmarkView(size: .large)
                    tagline
                }
                .padding(.top, 16)
                .padding(.bottom, 40)

                // Location Sharing card
                locationSharingCard
                    .padding(.horizontal, Spacing.screenH)

                // Meta pair + share button (when tracking)
                if locationManager.isTracking {
                    HStack(spacing: 10) {
                        MetaBox(label: "Last update", value: formatTimeAgo(locationManager.lastUpdateTime))
                        MetaBox(label: "Accuracy", value: formatAccuracy(locationManager.lastAccuracyMetres))
                    }
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(.horizontal, Spacing.screenH)
                    .padding(.top, 14)

                }

                Spacer(minLength: 40)

                // Share button + helper line pinned to bottom
                if locationManager.isTracking {
                    SecondaryButton(title: shareCooldown ? "Sent" : "Share location now") {
                        handleShareNow()
                    }
                    .disabled(shareCooldown)
                    .padding(.horizontal, Spacing.screenH)

                    HStack(spacing: 0) {
                        Text("\u{25CF} ")
                            .font(Typography.caption(11))
                            .foregroundStyle(Color.moss)
                        Text("Coordinates only  \u{00B7}  24-hour TTL  \u{00B7}  no history")
                            .font(Typography.caption(11))
                            .foregroundStyle(Color.inkFaint)
                    }
                    .padding(.top, 10)
                    .padding(.bottom, 24)
                }
            }
        }
    }

    // MARK: - Tagline

    private var tagline: some View {
        HStack(spacing: 0) {
            Text("LOCATION CONTEXT FOR ")
                .foregroundStyle(Color.inkFaint)
            Text("ANY")
                .foregroundStyle(Color.rust)
            Text(" AI AGENT")
                .foregroundStyle(Color.inkFaint)
        }
        .font(Typography.monoSmall(9))
        .tracking(2.5)
    }

    // MARK: - Location sharing card

    private var locationSharingCard: some View {
        Button {
            handleToggle(!locationManager.isTracking)
        } label: {
            HStack(alignment: .top, spacing: 14) {
                VStack(alignment: .leading, spacing: 3) {
                    Text("Location Sharing")
                        .font(Typography.title(22))
                        .foregroundStyle(Color.ink)
                    Text(locationManager.isTracking
                         ? "Tap to pause sharing from this device."
                         : "Tap to start sharing from this device.")
                        .font(Typography.caption())
                        .foregroundStyle(Color.inkSoft)
                }
                Spacer()
                PillView(isOn: locationManager.isTracking)
            }
            .padding(Spacing.cardPadH)
            .background(Color.paperWarm)
            .clipShape(RoundedRectangle(cornerRadius: Spacing.cardRadius))
            .overlay(
                RoundedRectangle(cornerRadius: Spacing.cardRadius)
                    .stroke(Color.rule, lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Location Sharing")
        .accessibilityValue(locationManager.isTracking ? "On" : "Off")
        .accessibilityHint(locationManager.isTracking
            ? "Double-tap to pause sharing"
            : "Double-tap to start sharing")
    }

    // MARK: - Actions

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

    private func handleShareNow() {
        guard !shareCooldown else { return }
        locationManager.requestImmediatePing()
        UIImpactFeedbackGenerator(style: .medium).impactOccurred()
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
    }

    // MARK: - Timer

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

    // MARK: - Formatting

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
        return "\u{00B1} \(Int(metres))m"
    }
}
