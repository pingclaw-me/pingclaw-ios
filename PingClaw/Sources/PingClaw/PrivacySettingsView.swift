import CoreLocation
import SwiftUI

/// Combined privacy screen: fetches the privacy policy markdown from the
/// server and appends the local iOS location permission status below it.
struct PrivacySettingsView: View {
    let serverUrl: String
    @Environment(\.dismiss) private var dismiss

    @State private var markdown: String?
    @State private var loading = true

    var body: some View {
        ZStack {
            Color.paper.ignoresSafeArea()

            ScrollView {
                VStack(alignment: .leading, spacing: 0) {
                    BackLink(title: "Settings") { dismiss() }
                        .padding(.horizontal, Spacing.screenH)
                        .padding(.top, 6)
                        .padding(.bottom, 22)

                    Text("Privacy")
                        .font(Typography.display(28))
                        .foregroundStyle(Color.ink)
                        .padding(.horizontal, Spacing.screenH)
                        .padding(.bottom, 20)

                    // Local permissions section
                    permissionsSection
                        .padding(.horizontal, Spacing.screenH)

                    if loading {
                        ProgressView()
                            .tint(Color.rust)
                            .frame(maxWidth: .infinity)
                            .padding(.top, 40)
                    } else if let markdown {
                        MarkdownBodyView(markdown: markdown)
                            .padding(.horizontal, Spacing.screenH)
                            .padding(.top, 24)
                    }

                    Spacer(minLength: 40)
                }
            }
        }
        .tint(Color.rust)
        .task { await fetchContent() }
    }

    // MARK: - Permissions

    private var permissionsSection: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text("System permissions")
                .font(Typography.title(20))
                .foregroundStyle(Color.ink)
                .padding(.bottom, 10)

            VStack(spacing: 0) {
                permRow(
                    label: "Location — While Using",
                    granted: locationStatus == .authorizedWhenInUse || locationStatus == .authorizedAlways
                )
                dottedDivider
                permRow(
                    label: "Location — Always",
                    granted: locationStatus == .authorizedAlways
                )
                dottedDivider
                permRow(
                    label: "Precise location",
                    granted: CLLocationManager().accuracyAuthorization == .fullAccuracy
                )
            }
            .padding(.horizontal, 18)
            .padding(.vertical, 16)
            .background(Color.paperWarm)
            .clipShape(RoundedRectangle(cornerRadius: 14))
            .overlay(
                RoundedRectangle(cornerRadius: 14)
                    .stroke(Color.rule, lineWidth: 1)
            )

            #if os(iOS)
            Button {
                if let url = URL(string: UIApplication.openSettingsURLString) {
                    UIApplication.shared.open(url)
                }
            } label: {
                Text("Change in iOS Settings")
                    .font(Typography.caption(11))
                    .foregroundStyle(Color.rust)
            }
            .padding(.top, 8)
            #endif
        }
    }

    private var locationStatus: CLAuthorizationStatus {
        CLLocationManager().authorizationStatus
    }

    private func permRow(label: String, granted: Bool) -> some View {
        HStack {
            Text(label)
                .font(Typography.caption())
                .foregroundStyle(Color.ink)
            Spacer()
            Text(granted ? "Granted" : "Not granted")
                .font(Typography.mono(11))
                .tracking(0.8)
                .foregroundStyle(granted ? Color.moss : Color.inkFaint)
        }
        .padding(.vertical, 9)
    }

    private var dottedDivider: some View {
        Rectangle()
            .stroke(style: StrokeStyle(lineWidth: 1, dash: [4, 4]))
            .foregroundStyle(Color.rule)
            .frame(height: 1)
    }

    // MARK: - Fetch

    private func fetchContent() async {
        let baseURL = serverUrl.trimmingCharacters(in: CharacterSet(charactersIn: "/"))
        guard let url = URL(string: "\(baseURL)/pingclaw/content/privacy") else {
            loading = false
            return
        }
        do {
            let (data, _) = try await URLSession.shared.data(from: url)
            markdown = String(data: data, encoding: .utf8) ?? ""
        } catch {}
        loading = false
    }
}

// MARK: - Shared markdown renderer

/// Renders markdown with support for ## headings, ### subheadings,
/// - bullets, **bold**, [links](url), and paragraphs.
struct MarkdownBodyView: View {
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
            if trimmed.isEmpty { continue }
            if trimmed.hasPrefix("## ") {
                result.append(.heading2(String(trimmed.dropFirst(3))))
            } else if trimmed.hasPrefix("### ") {
                result.append(.heading3(String(trimmed.dropFirst(4))))
            } else if trimmed.hasPrefix("- ") {
                result.append(.bullet(String(trimmed.dropFirst(2))))
            } else {
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
            renderInlineText(text)
                .font(Typography.caption())
                .foregroundStyle(Color.inkSoft)
                .lineSpacing(4)
                .padding(.bottom, 12)
        case .bullet(let text):
            HStack(alignment: .top, spacing: 8) {
                Text("\u{2022}")
                    .font(Typography.caption())
                    .foregroundStyle(Color.inkFaint)
                renderInlineText(text)
                    .font(Typography.caption())
                    .foregroundStyle(Color.inkSoft)
                    .lineSpacing(3)
            }
            .padding(.bottom, 4)
        }
    }

    /// Parses inline markdown: **bold** and [text](url) links.
    private func renderInlineText(_ text: String) -> Text {
        var result = Text("")
        var remaining = text[...]

        while !remaining.isEmpty {
            // Look for the next special pattern
            if let boldRange = remaining.range(of: "**") {
                // Text before the bold
                let before = remaining[remaining.startIndex..<boldRange.lowerBound]
                result = result + parseLinks(String(before))

                // Find closing **
                let afterBold = remaining[boldRange.upperBound...]
                if let closeRange = afterBold.range(of: "**") {
                    let boldText = String(afterBold[afterBold.startIndex..<closeRange.lowerBound])
                    result = result + parseLinks(boldText).bold()
                    remaining = afterBold[closeRange.upperBound...]
                } else {
                    // No closing ** — treat as literal
                    result = result + parseLinks(String(remaining))
                    remaining = remaining[remaining.endIndex...]
                }
            } else {
                // No more bold — parse links in the rest
                result = result + parseLinks(String(remaining))
                remaining = remaining[remaining.endIndex...]
            }
        }
        return result
    }

    /// Parses [text](url) links into tappable Text views.
    private func parseLinks(_ text: String) -> Text {
        var result = Text("")
        var remaining = text[...]

        while !remaining.isEmpty {
            // Find [
            guard let openBracket = remaining.firstIndex(of: "[") else {
                result = result + Text(String(remaining))
                break
            }

            // Text before the link
            let before = remaining[remaining.startIndex..<openBracket]
            if !before.isEmpty {
                result = result + Text(String(before))
            }

            // Find ](url)
            let afterOpen = remaining[remaining.index(after: openBracket)...]
            guard let closeBracket = afterOpen.firstIndex(of: "]"),
                  let openParen = afterOpen.index(closeBracket, offsetBy: 1, limitedBy: afterOpen.endIndex),
                  afterOpen[openParen] == "(",
                  let closeParen = afterOpen[afterOpen.index(after: openParen)...].firstIndex(of: ")") else {
                // Not a valid link — output the [ and continue
                result = result + Text("[")
                remaining = remaining[remaining.index(after: openBracket)...]
                continue
            }

            let linkText = String(afterOpen[afterOpen.startIndex..<closeBracket])
            let linkURL = String(afterOpen[afterOpen.index(after: openParen)..<closeParen])

            // Render as tappable link if it's a valid URL
            if let url = URL(string: linkURL) {
                result = result + Text(.init("[\(linkText)](\(url.absoluteString))"))
            } else {
                result = result + Text(linkText)
            }

            remaining = afterOpen[afterOpen.index(after: closeParen)...]
        }
        return result
    }
}
