import SwiftUI

/// Fetches markdown + last_updated from the server API and renders
/// as a full-screen push with back link and date subtitle.
struct MarkdownContentView: View {
    let title: String
    let endpoint: String
    let serverUrl: String
    @Environment(\.dismiss) private var dismiss

    @State private var markdown: String?
    @State private var lastUpdated: String?
    @State private var loading = true
    @State private var error: String?

    var body: some View {
        ZStack {
            Color.paper.ignoresSafeArea()

            ScrollView {
                VStack(alignment: .leading, spacing: 0) {
                    BackLink(title: "Settings") { dismiss() }
                        .padding(.horizontal, Spacing.screenH)
                        .padding(.top, 6)
                        .padding(.bottom, 22)

                    Text(title)
                        .font(Typography.display(28))
                        .foregroundStyle(Color.ink)
                        .padding(.horizontal, Spacing.screenH)
                        .padding(.bottom, 4)

                    if let lastUpdated {
                        Text("Last updated: \(lastUpdated)")
                            .font(Typography.caption(12))
                            .foregroundStyle(Color.inkFaint)
                            .padding(.horizontal, Spacing.screenH)
                            .padding(.bottom, 20)
                    } else {
                        Spacer().frame(height: 16)
                    }

                    if loading {
                        ProgressView()
                            .tint(Color.rust)
                            .frame(maxWidth: .infinity)
                            .padding(.top, 40)
                    } else if let error {
                        Text(error)
                            .font(Typography.caption())
                            .foregroundStyle(Color.red)
                            .padding(.horizontal, Spacing.screenH)
                    } else if let markdown {
                        MarkdownBodyView(markdown: markdown)
                            .padding(.horizontal, Spacing.screenH)
                    }

                    Spacer(minLength: 40)
                }
            }
        }
        .tint(Color.rust)
        .task {
            await fetchContent()
        }
    }

    private func fetchContent() async {
        let baseURL = serverUrl.trimmingCharacters(in: CharacterSet(charactersIn: "/"))
        guard let url = URL(string: "\(baseURL)/pingclaw/content/\(endpoint)") else {
            error = "Invalid URL"
            loading = false
            return
        }
        do {
            let (data, _) = try await URLSession.shared.data(from: url)
            if let json = try JSONSerialization.jsonObject(with: data) as? [String: String] {
                markdown = json["content"]
                lastUpdated = json["last_updated"]
            }
            loading = false
        } catch {
            self.error = "Could not load content."
            loading = false
        }
    }
}
