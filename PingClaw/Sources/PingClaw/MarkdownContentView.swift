import SwiftUI

/// Fetches raw markdown from the server and renders it as a full-screen
/// push with a back link. Used for terms of service.
struct MarkdownContentView: View {
    let title: String
    let endpoint: String
    let serverUrl: String
    @Environment(\.dismiss) private var dismiss

    @State private var markdown: String?
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
                        .padding(.bottom, 20)

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
            markdown = String(data: data, encoding: .utf8) ?? ""
            loading = false
        } catch {
            self.error = "Could not load content."
            loading = false
        }
    }
}
