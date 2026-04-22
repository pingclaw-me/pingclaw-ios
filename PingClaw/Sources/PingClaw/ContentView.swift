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

    // Integration state (fetched from server)
    @State private var hasApiKey = false
    @State private var hasWebhook = false
    @State private var hasOpenClaw = false
    @State private var chatGPTURL: String?

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
        .task {
            if storage.getPairingToken() != nil {
                await fetchIntegrationStatus()
            }
        }
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

                // Meta pair (when tracking)
                if locationManager.isTracking {
                    HStack(spacing: 10) {
                        // Last Update with refresh icon
                        lastUpdateBox
                        MetaBox(label: "Accuracy", value: formatAccuracy(locationManager.lastAccuracyMetres))
                    }
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(.horizontal, Spacing.screenH)
                    .padding(.top, 14)

                    // Integrations section
                    if hasIntegrations {
                        integrationsSection
                            .padding(.horizontal, Spacing.screenH)
                            .padding(.top, 28)
                    }
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

    // MARK: - Last Update box with refresh icon

    private var lastUpdateBox: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text("LAST UPDATE")
                    .font(Typography.monoSmall(9))
                    .tracking(1.5)
                    .foregroundStyle(Color.inkFaint)
                Spacer()
                Button {
                    handleShareNow()
                } label: {
                    Image(systemName: "arrow.clockwise")
                        .font(.system(size: 11, weight: .medium))
                        .foregroundStyle(Color.inkFaint)
                        .frame(width: 20, height: 20)
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Refresh location")
            }
            Text(formatTimeAgo(locationManager.lastUpdateTime))
                .font(Typography.mono(18))
                .foregroundStyle(Color.ink)
                .tracking(-0.2)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
        .padding(.horizontal, 16)
        .padding(.vertical, 14)
        .background(Color.paperWarm)
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(Color.rule, lineWidth: 1)
        )
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

    // MARK: - Integrations section

    private var hasIntegrations: Bool {
        hasApiKey || hasWebhook || hasOpenClaw || chatGPTURL != nil
    }

    private var activeCount: Int {
        var count = 0
        if chatGPTURL != nil { count += 1 }
        if hasApiKey { count += 1 }
        if hasWebhook { count += 1 }
        if hasOpenClaw { count += 1 }
        return count
    }

    private var integrationsSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            // Header
            HStack {
                Text("\u{00A7} INTEGRATIONS \u{00B7} \(activeCount) ACTIVE")
                    .font(Typography.monoSmall(9))
                    .tracking(2)
                    .foregroundStyle(Color.rust)
                Spacer()
                Button {
                    openDashboard()
                } label: {
                    Text("Manage \u{203A}")
                        .font(Typography.caption(12))
                        .foregroundStyle(Color.inkFaint)
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, 2)

            // Cards
            if chatGPTURL != nil {
                integrationCard(
                    name: "ChatGPT",
                    mode: "GPT \u{00B7} Pull",
                    status: "Configured",
                    isLive: true
                )
            }
            if hasApiKey {
                integrationCard(
                    name: "MCP agents",
                    mode: "MCP \u{00B7} Pull",
                    status: "API key active",
                    isLive: true
                )
            }
            if hasWebhook {
                integrationCard(
                    name: "Webhook",
                    mode: "Push",
                    status: "Configured",
                    isLive: false
                )
            }
            if hasOpenClaw {
                integrationCard(
                    name: "OpenClaw gateway",
                    mode: "Push \u{00B7} Native",
                    status: "Configured",
                    isLive: false
                )
            }
        }
    }

    private func integrationCard(name: String, mode: String, status: String, isLive: Bool) -> some View {
        HStack(spacing: 12) {
            // Status dot
            Circle()
                .fill(isLive ? Color.moss : Color.inkGhost)
                .frame(width: 8, height: 8)

            // Body
            VStack(alignment: .leading, spacing: 2) {
                HStack {
                    Text(name)
                        .font(Typography.rowTitle(14))
                        .foregroundStyle(Color.ink)
                    Spacer()
                    Text(mode)
                        .font(Typography.monoSmall(9))
                        .tracking(1)
                        .foregroundStyle(Color.inkFaint)
                }
                Text(status)
                    .font(Typography.mono(10))
                    .foregroundStyle(isLive ? Color.moss : Color.inkFaint)
            }

            Text("\u{203A}")
                .font(.custom("Fraunces", size: 15))
                .foregroundStyle(Color.inkGhost)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
        .background(Color.paperWarm)
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(Color.rule, lineWidth: 1)
        )
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

    private func openDashboard() {
        let apiService = APIService(storage: storage)
        Task {
            do {
                let code = try await apiService.requestWebCode()
                let baseURL = storage.serverUrl.trimmingCharacters(in: CharacterSet(charactersIn: "/"))
                if let url = URL(string: "\(baseURL)?webcode=\(code)") {
                    await UIApplication.shared.open(url)
                }
            } catch {}
        }
    }

    // MARK: - Fetch integration status

    private func fetchIntegrationStatus() async {
        let baseURL = storage.serverUrl.trimmingCharacters(in: CharacterSet(charactersIn: "/"))
        guard let token = storage.getPairingToken() else { return }

        // Fetch /pingclaw/auth/me for has_api_key
        if let url = URL(string: "\(baseURL)/pingclaw/auth/me") {
            var request = URLRequest(url: url)
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
            if let (data, _) = try? await URLSession.shared.data(for: request),
               let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] {
                hasApiKey = json["has_api_key"] as? Bool ?? false
            }
        }

        // Fetch /pingclaw/webhook
        if let url = URL(string: "\(baseURL)/pingclaw/webhook") {
            var request = URLRequest(url: url)
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
            if let (data, _) = try? await URLSession.shared.data(for: request),
               let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] {
                hasWebhook = json["url"] != nil && !(json["url"] is NSNull)
            }
        }

        // Fetch /pingclaw/webhook/openclaw
        if let url = URL(string: "\(baseURL)/pingclaw/webhook/openclaw") {
            var request = URLRequest(url: url)
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
            if let (data, _) = try? await URLSession.shared.data(for: request),
               let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] {
                let dest = json["destination"] as? [String: Any]
                hasOpenClaw = dest != nil
            }
        }

        // Fetch /pingclaw/config for ChatGPT URL
        if let url = URL(string: "\(baseURL)/pingclaw/config") {
            if let (data, _) = try? await URLSession.shared.data(from: url),
               let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
               let integrations = json["integrations"] as? [String: Any],
               let chatgpt = integrations["chatgpt"] as? [String: Any],
               let gptURL = chatgpt["url"] as? String,
               !gptURL.isEmpty {
                chatGPTURL = gptURL
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
