import SwiftUI

struct PairingCodeView: View {
    var storage: StorageService
    @Environment(\.dismiss) private var dismiss

    @State private var code: String?
    @State private var loading = false
    @State private var codeCopied = false
    @State private var expirySeconds = 300 // 5 minutes
    @State private var timer: Timer?

    var body: some View {
        ZStack {
            Color.paper.ignoresSafeArea()

            VStack(alignment: .leading, spacing: 0) {
                BackLink(title: "Settings") { dismiss() }
                    .padding(.horizontal, Spacing.screenH)
                    .padding(.top, 6)
                    .padding(.bottom, 28)

                Text("Sign in on\nyour computer.")
                    .font(Typography.display(28))
                    .foregroundStyle(Color.ink)
                    .padding(.horizontal, Spacing.screenH)
                    .padding(.bottom, 10)

                (Text("Go to ")
                    .foregroundColor(Color.inkSoft)
                 + Text("pingclaw.me")
                    .foregroundColor(Color.ink)
                    .font(Typography.mono(12))
                 + Text(" in a browser, click sign in, and enter this code.")
                    .foregroundColor(Color.inkSoft))
                .font(Typography.caption())
                .lineSpacing(3)
                .padding(.horizontal, Spacing.screenH)
                .padding(.bottom, 28)

                // Code card
                if let code {
                    codeCard(code)
                        .padding(.horizontal, Spacing.screenH)
                        .padding(.bottom, 20)
                } else {
                    VStack(spacing: 16) {
                        if loading {
                            ProgressView()
                                .tint(Color.rust)
                        }
                        PrimaryButton(title: "Generate code") {
                            generateCode()
                        }
                        .disabled(loading)
                    }
                    .padding(.horizontal, Spacing.screenH)
                    .padding(.bottom, 20)
                }

                // Steps
                VStack(alignment: .leading, spacing: 14) {
                    stepRow(number: 1, text: "Open pingclaw.me on your computer.")
                    stepRow(number: 2, text: "Click \"Sign in\" and choose \"I have a code\".")
                    stepRow(number: 3, text: "Enter the 8 characters above.")
                }
                .padding(.horizontal, Spacing.screenH)

                Spacer()

                // Regenerate
                if code != nil {
                    VStack(spacing: 0) {
                        Rectangle().fill(Color.rule).frame(height: 1)
                        Button { generateCode() } label: {
                            Text("Regenerate code")
                                .font(Typography.body(13, weight: .medium))
                                .foregroundStyle(Color.rust)
                                .padding(.vertical, 20)
                        }
                    }
                    .frame(maxWidth: .infinity)
                }
            }
        }
        .onAppear { generateCode() }
        .onDisappear { timer?.invalidate() }
    }

    // MARK: - Code card

    private func codeCard(_ code: String) -> some View {
        VStack(spacing: 14) {
            // Split code with middle dot: "K7QP · 4M3X"
            let half = code.count / 2
            let left = String(code.prefix(half))
            let right = String(code.suffix(code.count - half))

            Button {
                #if os(iOS)
                UIPasteboard.general.string = code
                #endif
                codeCopied = true
                Task {
                    try? await Task.sleep(nanoseconds: 2_000_000_000)
                    codeCopied = false
                }
            } label: {
                HStack(spacing: 0) {
                    Text(left)
                    Text(" \u{00B7} ")
                        .foregroundStyle(Color.inkGhost)
                    Text(right)
                }
                .font(Typography.mono(36))
                .tracking(4)
                .foregroundStyle(Color.ink)
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Pairing code: \(code)")
            .accessibilityHint("Tap to copy")

            // Expiry
            VStack(spacing: 0) {
                Rectangle()
                    .stroke(style: StrokeStyle(lineWidth: 1, dash: [4, 4]))
                    .foregroundStyle(Color.rule)
                    .frame(height: 1)
                    .padding(.bottom, 12)

                HStack(spacing: 8) {
                    Text(codeCopied ? "Copied!" : "Expires in \(formatExpiry())")
                        .font(Typography.monoSmall())
                        .tracking(1.3)
                        .foregroundStyle(codeCopied ? Color.rust : Color.inkFaint)

                    // Progress bar
                    GeometryReader { geo in
                        ZStack(alignment: .leading) {
                            RoundedRectangle(cornerRadius: 2)
                                .fill(Color.rule)
                            RoundedRectangle(cornerRadius: 2)
                                .fill(Color.rust)
                                .frame(width: geo.size.width * CGFloat(expirySeconds) / 300.0)
                        }
                    }
                    .frame(width: 80, height: 3)
                }
            }
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 28)
        .background(Color.paperWarm)
        .clipShape(RoundedRectangle(cornerRadius: 14))
        .overlay(
            RoundedRectangle(cornerRadius: 14)
                .stroke(Color.ink, lineWidth: 1)
        )
    }

    // MARK: - Step row

    private func stepRow(number: Int, text: String) -> some View {
        HStack(alignment: .top, spacing: 10) {
            Text("\(number)")
                .font(Typography.monoSmall(11))
                .foregroundStyle(Color.rust)
                .frame(width: 22, height: 22)
                .overlay(
                    Circle().stroke(Color.rule, lineWidth: 1)
                )
                .background(Color.paper)
                .clipShape(Circle())

            Text(text)
                .font(Typography.caption(12.5))
                .foregroundStyle(Color.inkSoft)
                .lineSpacing(3)
        }
    }

    // MARK: - Actions

    private func generateCode() {
        loading = true
        let apiService = APIService(storage: storage)
        Task {
            do {
                let newCode = try await apiService.requestWebCode()
                code = newCode
                loading = false
                expirySeconds = 300
                startExpiryTimer()
            } catch {
                loading = false
            }
        }
    }

    private func startExpiryTimer() {
        timer?.invalidate()
        timer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { _ in
            Task { @MainActor in
                if expirySeconds > 0 {
                    expirySeconds -= 1
                } else {
                    code = nil
                    timer?.invalidate()
                }
            }
        }
    }

    private func formatExpiry() -> String {
        let m = expirySeconds / 60
        let s = expirySeconds % 60
        return String(format: "%d:%02d", m, s)
    }
}
