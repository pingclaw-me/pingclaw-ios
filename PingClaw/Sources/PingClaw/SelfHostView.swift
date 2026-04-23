import SwiftUI

/// Self-hosted server connection screen. Lets the user enter a server
/// URL and pairing token to connect without Apple/Google sign-in.
struct SelfHostView: View {
    var storage: StorageService
    var onSignedIn: () -> Void
    @Environment(\.dismiss) private var dismiss

    @State private var serverUrl = ""
    @State private var pairingToken = ""
    @State private var isConnecting = false
    @State private var errorMessage: String?
    @State private var verified = false

    var body: some View {
        ZStack {
            Color.paper.ignoresSafeArea()

            VStack(alignment: .leading, spacing: 0) {
                BackLink(title: "Sign in") { dismiss() }
                    .padding(.horizontal, Spacing.screenH)
                    .padding(.top, 6)
                    .padding(.bottom, 22)

                Text("Connect to your\nown server.")
                    .font(Typography.display(28))
                    .foregroundStyle(Color.ink)
                    .padding(.horizontal, Spacing.screenH)
                    .padding(.bottom, 10)

                (Text("Running ")
                    .foregroundColor(Color.inkSoft)
                 + Text("pingclaw-server --local")
                    .foregroundColor(Color.ink)
                    .font(Typography.mono(12))
                 + Text("? Paste the URL and pairing token it printed on first run.")
                    .foregroundColor(Color.inkSoft))
                .font(Typography.caption())
                .lineSpacing(3)
                .padding(.horizontal, Spacing.screenH)
                .padding(.bottom, 28)

                // Fields
                FieldInput(
                    label: "Server URL",
                    text: $serverUrl,
                    placeholder: "https://pingclaw.home.arpa",
                    hint: "Reachable from your phone — Tailscale, local network, or public."
                )
                .padding(.horizontal, Spacing.screenH)
                .padding(.bottom, 18)

                FieldInput(
                    label: "Pairing token",
                    text: $pairingToken,
                    placeholder: "pt_...",
                    hint: "Printed once when you start the server with --local."
                )
                .padding(.horizontal, Spacing.screenH)
                .padding(.bottom, 18)

                // Verification result
                if verified {
                    HStack(spacing: 8) {
                        Circle()
                            .fill(Color.moss)
                            .frame(width: 6, height: 6)
                        Text("Connection verified")
                            .font(Typography.mono(12))
                            .foregroundStyle(Color.moss)
                    }
                    .padding(.horizontal, 14)
                    .padding(.vertical, 10)
                    .background(Color.moss.opacity(0.08))
                    .clipShape(RoundedRectangle(cornerRadius: 10))
                    .overlay(
                        RoundedRectangle(cornerRadius: 10)
                            .stroke(Color.moss.opacity(0.2), lineWidth: 1)
                    )
                    .padding(.horizontal, Spacing.screenH)
                    .padding(.bottom, 18)
                }

                // Error
                if let errorMessage {
                    Text(errorMessage)
                        .font(Typography.caption(12))
                        .foregroundStyle(Color.red)
                        .padding(.horizontal, Spacing.screenH)
                        .padding(.bottom, 12)
                }

                Spacer()

                // Actions
                VStack(spacing: 4) {
                    if !verified {
                        PrimaryButton(
                            title: isConnecting ? "Connecting..." : "Pair this device",
                            action: connect,
                            disabled: isConnecting || serverUrl.isEmpty || pairingToken.isEmpty
                        )
                    }
                    GhostButton(title: "\u{2190} Back to sign-in options") {
                        dismiss()
                    }
                }
                .padding(.horizontal, Spacing.screenH)
                .padding(.bottom, 24)
            }
        }
    }

    private func connect() {
        let url = serverUrl.trimmingCharacters(in: .whitespacesAndNewlines)
            .trimmingCharacters(in: CharacterSet(charactersIn: "/"))
        let token = pairingToken.trimmingCharacters(in: .whitespacesAndNewlines)

        guard !url.isEmpty else {
            errorMessage = "Enter your server URL."
            return
        }
        guard !token.isEmpty else {
            errorMessage = "Enter your pairing token."
            return
        }

        isConnecting = true
        errorMessage = nil
        verified = false
        storage.serverUrl = url

        Task {
            do {
                var request = URLRequest(url: URL(string: "\(url)/pingclaw/location")!)
                request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
                let (_, response) = try await URLSession.shared.data(for: request)
                let status = (response as? HTTPURLResponse)?.statusCode ?? 0

                if status == 401 {
                    errorMessage = "Invalid pairing token."
                    isConnecting = false
                    return
                }
                if status != 200 {
                    errorMessage = "Server returned \(status)."
                    isConnecting = false
                    return
                }

                verified = true
                isConnecting = false

                guard storage.savePairingToken(token) else {
                    errorMessage = "Could not save the token."
                    return
                }

                // Brief pause so the user sees "Connection verified"
                try? await Task.sleep(nanoseconds: 1_200_000_000)
                onSignedIn()
            } catch {
                errorMessage = "Could not reach server: \(error.localizedDescription)"
                isConnecting = false
            }
        }
    }
}
