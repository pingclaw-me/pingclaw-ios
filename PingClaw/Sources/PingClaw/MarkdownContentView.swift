import SwiftUI

/// Fetches raw markdown from the server and renders it natively.
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
                        // Render markdown lines as styled text
                        MarkdownBody(markdown: markdown)
                            .padding(.horizontal, Spacing.screenH)
                    }

                    Spacer(minLength: 40)
                }
            }
        }
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

/// Simple markdown renderer — handles ##, ###, paragraphs, and bullet lists.
private struct MarkdownBody: View {
    let markdown: String

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            ForEach(Array(blocks.enumerated()), id: \.offset) { _, block in
                blockView(block)
            }
        }
    }

    private enum Block {
        case heading2(String)
        case heading3(String)
        case paragraph(String)
        case bullet(String)
    }

    private var blocks: [Block] {
        var result: [Block] = []
        for line in markdown.components(separatedBy: "\n") {
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            if trimmed.isEmpty {
                continue
            } else if trimmed.hasPrefix("## ") {
                result.append(.heading2(String(trimmed.dropFirst(3))))
            } else if trimmed.hasPrefix("### ") {
                result.append(.heading3(String(trimmed.dropFirst(4))))
            } else if trimmed.hasPrefix("- ") {
                result.append(.bullet(String(trimmed.dropFirst(2))))
            } else {
                // Append to last paragraph or create new
                if case .paragraph(let existing) = result.last {
                    result[result.count - 1] = .paragraph(existing + " " + trimmed)
                } else {
                    result.append(.paragraph(trimmed))
                }
            }
        }
        return result
    }

    @ViewBuilder
    private func blockView(_ block: Block) -> some View {
        switch block {
        case .heading2(let text):
            Text(text)
                .font(Typography.title(20))
                .foregroundStyle(Color.ink)
                .padding(.top, 20)
                .padding(.bottom, 8)
        case .heading3(let text):
            Text(text)
                .font(Typography.rowTitle())
                .foregroundStyle(Color.ink)
                .padding(.top, 14)
                .padding(.bottom, 6)
        case .paragraph(let text):
            Text(text)
                .font(Typography.caption())
                .foregroundStyle(Color.inkSoft)
                .lineSpacing(4)
                .padding(.bottom, 12)
        case .bullet(let text):
            HStack(alignment: .top, spacing: 8) {
                Text("\u{2022}")
                    .font(Typography.caption())
                    .foregroundStyle(Color.inkFaint)
                Text(text)
                    .font(Typography.caption())
                    .foregroundStyle(Color.inkSoft)
                    .lineSpacing(3)
            }
            .padding(.bottom, 4)
        }
    }
}
