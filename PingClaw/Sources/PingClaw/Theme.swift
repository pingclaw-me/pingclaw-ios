import CoreText
import SwiftUI
#if os(iOS)
import UIKit
#endif

// MARK: - Color palette

// Adaptive colors that resolve to light/dark automatically.
// Values match the design mockup CSS variables exactly.

private func adaptive(light: UInt32, dark: UInt32) -> Color {
    #if os(iOS)
    Color(UIColor { traits in
        let hex = traits.userInterfaceStyle == .dark ? dark : light
        return UIColor(
            red: CGFloat((hex >> 16) & 0xFF) / 255,
            green: CGFloat((hex >> 8) & 0xFF) / 255,
            blue: CGFloat(hex & 0xFF) / 255,
            alpha: 1
        )
    })
    #else
    let hex = dark
    return Color(
        red: Double((hex >> 16) & 0xFF) / 255,
        green: Double((hex >> 8) & 0xFF) / 255,
        blue: Double(hex & 0xFF) / 255
    )
    #endif
}

extension Color {
    // Backgrounds
    static let paper     = adaptive(light: 0xFAF8F4, dark: 0x0E0D0B)
    static let paperWarm = adaptive(light: 0xF3EFE6, dark: 0x1A1815)
    static let paperDeep = adaptive(light: 0xEAE4D4, dark: 0x232019)

    // Text
    static let ink       = adaptive(light: 0x161513, dark: 0xEDE7D9)
    static let inkSoft   = adaptive(light: 0x3B3936, dark: 0xB8B0A0)
    static let inkFaint  = adaptive(light: 0x84817B, dark: 0x6B665D)
    static let inkGhost  = adaptive(light: 0xBAB5AA, dark: 0x48453F)

    // Borders
    static let rule      = adaptive(light: 0xE5DFD2, dark: 0x2A2825)

    // Accent
    static let rust      = adaptive(light: 0xB8472C, dark: 0xE8704F)
    static let rustSoft  = adaptive(light: 0xD96C52, dark: 0xF08A6B)

    // Semantic
    static let moss      = adaptive(light: 0x5A6B3E, dark: 0x9BB072)
    static let amber     = adaptive(light: 0xB87D2C, dark: 0xD89A4C)
    static let red       = adaptive(light: 0xC23B2C, dark: 0xE06859)

    // Legacy aliases (keep temporarily while migrating views)
    static let pcBg      = paper
    static let pcSurface = paperWarm
    static let pcBorder  = rule
    static let pcAccent  = rust
    static let pcText    = ink
    static let pcText2   = inkSoft
    static let pcText3   = inkFaint
    static let pcWarning = amber
    static let pcError   = red
}

// MARK: - Font registration

/// Registers bundled fonts (Fraunces, Inter Tight, JetBrains Mono)
/// at runtime. SwiftPM resources don't auto-populate UIAppFonts.
enum PingClawFonts {
    static let register: Void = {
        let fonts = ["Fraunces-VF", "InterTight-VF", "JetBrainsMono-VF"]
        for name in fonts {
            guard let url = Bundle.module.url(
                forResource: name, withExtension: "ttf", subdirectory: "Fonts"
            ) else { continue }
            var error: Unmanaged<CFError>?
            CTFontManagerRegisterFontsForURL(url as CFURL, .process, &error)
        }
    }()
}

// MARK: - Typography

/// Reusable text style builders. All sizes are in points.
enum Typography {
    // Display — Fraunces serif
    static func display(_ size: CGFloat = 34, weight: Font.Weight = .medium) -> Font {
        .custom("Fraunces", size: size).weight(weight)
    }

    // Title — Fraunces serif
    static func title(_ size: CGFloat = 22, weight: Font.Weight = .medium) -> Font {
        .custom("Fraunces", size: size).weight(weight)
    }

    // Row title — Fraunces serif, slightly smaller
    static func rowTitle(_ size: CGFloat = 16, weight: Font.Weight = .medium) -> Font {
        .custom("Fraunces", size: size).weight(weight)
    }

    // Body — Inter Tight sans-serif
    static func body(_ size: CGFloat = 15, weight: Font.Weight = .regular) -> Font {
        .custom("InterTight", size: size).weight(weight)
    }

    // Caption — Inter Tight
    static func caption(_ size: CGFloat = 13) -> Font {
        .custom("InterTight", size: size)
    }

    // Monospace — JetBrains Mono
    static func mono(_ size: CGFloat = 14, weight: Font.Weight = .medium) -> Font {
        .custom("JetBrainsMono", size: size).weight(weight)
    }

    // Small mono — labels, tags, eyebrows
    static func monoSmall(_ size: CGFloat = 10) -> Font {
        .custom("JetBrainsMono", size: size).weight(.medium)
    }
}

// MARK: - Spacing

enum Spacing {
    static let screenH: CGFloat = 18
    static let cardPadH: CGFloat = 20
    static let cardPadV: CGFloat = 20
    static let cardRadius: CGFloat = 16
    static let buttonRadius: CGFloat = 13
    static let inputRadius: CGFloat = 12
    static let rowPadH: CGFloat = 18
    static let rowPadV: CGFloat = 14
}

// MARK: - Wordmark

struct WordmarkView: View {
    enum Size { case large, medium, small }
    var size: Size = .large

    @Environment(\.colorScheme) private var colorScheme

    private var textSize: CGFloat {
        switch size {
        case .large: 44
        case .medium: 28
        case .small: 20
        }
    }

    private var pinSize: CGFloat {
        switch size {
        case .large: 18
        case .medium: 12
        case .small: 9
        }
    }

    private var haloSize: CGFloat {
        switch size {
        case .large: 32
        case .medium: 22
        case .small: 16
        }
    }

    private var gap: CGFloat {
        switch size {
        case .large: 16
        case .medium: 11
        case .small: 9
        }
    }

    private var haloOpacity: Double {
        colorScheme == .dark ? 0.28 : 0.18
    }

    var body: some View {
        HStack(spacing: gap) {
            ZStack {
                Circle()
                    .fill(Color.rust.opacity(haloOpacity))
                    .frame(width: haloSize, height: haloSize)
                Circle()
                    .fill(Color.rust)
                    .frame(width: pinSize, height: pinSize)
            }
            Text("pingclaw")
                .font(.custom("Fraunces", size: textSize))
                .fontWeight(.medium)
                .foregroundStyle(Color.ink)
                .tracking(-0.025 * textSize)
        }
    }
}

// MARK: - Section label

/// Rust monospace caps label with a trailing horizontal rule.
struct SectionLabel: View {
    let title: String

    var body: some View {
        HStack(spacing: 10) {
            Text(title.uppercased())
                .font(Typography.monoSmall())
                .tracking(2)
                .foregroundStyle(Color.rust)
            Rectangle()
                .fill(Color.rule)
                .frame(height: 1)
        }
        .padding(.top, 22)
        .padding(.bottom, 10)
        .padding(.leading, 4)
    }
}

// MARK: - Settings group (card container)

struct SettingsGroup<Content: View>: View {
    @ViewBuilder var content: () -> Content

    var body: some View {
        VStack(spacing: 0) {
            content()
        }
        .background(Color.paperWarm)
        .clipShape(RoundedRectangle(cornerRadius: Spacing.cardRadius))
        .overlay(
            RoundedRectangle(cornerRadius: Spacing.cardRadius)
                .stroke(Color.rule, lineWidth: 1)
        )
    }
}

// MARK: - Settings row

struct SettingsRow: View {
    let title: String
    var subtitle: String = ""
    var style: RowStyle = .default
    var trailing: TrailingType = .none
    var action: () -> Void = {}

    enum RowStyle { case `default`, caution, destructive }
    enum TrailingType { case none, chevron, external, check }

    private var titleColor: Color {
        switch style {
        case .default: .ink
        case .caution: .amber
        case .destructive: .red
        }
    }

    var body: some View {
        Button(action: action) {
            HStack(alignment: .top, spacing: 14) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(Typography.rowTitle())
                        .foregroundStyle(titleColor)
                    if !subtitle.isEmpty {
                        Text(subtitle)
                            .font(Typography.caption(12))
                            .foregroundStyle(Color.inkSoft)
                            .lineSpacing(2)
                    }
                }
                Spacer()
                trailingView
            }
            .padding(.horizontal, Spacing.rowPadH)
            .padding(.vertical, Spacing.rowPadV)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    @ViewBuilder
    private var trailingView: some View {
        switch trailing {
        case .none:
            EmptyView()
        case .chevron:
            Text("\u{203A}")
                .font(.custom("Fraunces", size: 18))
                .foregroundStyle(Color.inkGhost)
                .padding(.top, 2)
        case .external:
            Text("\u{2197}")
                .font(.system(size: 15))
                .foregroundStyle(Color.inkGhost)
                .padding(.top, 2)
        case .check:
            Image(systemName: "checkmark")
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(Color.rust)
                .padding(.top, 4)
        }
    }
}

// MARK: - Row divider

struct RowDivider: View {
    var body: some View {
        Rectangle()
            .fill(Color.rule)
            .frame(height: 1)
    }
}

// MARK: - On pill

struct PillView: View {
    @State private var pulse = false

    var body: some View {
        HStack(spacing: 6) {
            Circle()
                .fill(Color.rust)
                .frame(width: 6, height: 6)
                .opacity(pulse ? 0.5 : 1.0)
                .animation(.easeInOut(duration: 2).repeatForever(autoreverses: true), value: pulse)
            Text("ON")
                .font(Typography.monoSmall())
                .tracking(1)
                .foregroundStyle(Color.rust)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
        .background(Color.paper)
        .overlay(
            Capsule().stroke(Color.rust, lineWidth: 1)
        )
        .clipShape(Capsule())
        .onAppear { pulse = true }
    }
}

// MARK: - Meta box

struct MetaBox: View {
    let label: String
    let value: String
    var small: Bool = false

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(label.uppercased())
                .font(Typography.monoSmall(9))
                .tracking(1.5)
                .foregroundStyle(Color.inkFaint)
            Text(value)
                .font(Typography.mono(small ? 15 : 18))
                .foregroundStyle(Color.ink)
                .tracking(-0.2)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 16)
        .padding(.vertical, 14)
        .background(Color.paperWarm)
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(Color.rule, lineWidth: 1)
        )
    }
}

// MARK: - Primary button

struct PrimaryButton: View {
    let title: String
    var action: () -> Void = {}
    var disabled: Bool = false

    var body: some View {
        Button(action: action) {
            Text(title)
                .font(Typography.body(15, weight: .medium))
                .tracking(0.15)
                .foregroundStyle(Color.paper)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 16)
                .background(disabled ? Color.inkGhost : Color.ink)
                .clipShape(RoundedRectangle(cornerRadius: Spacing.buttonRadius))
        }
        .disabled(disabled)
        .buttonStyle(.plain)
    }
}

// MARK: - Secondary button

struct SecondaryButton: View {
    let title: String
    var action: () -> Void = {}

    var body: some View {
        Button(action: action) {
            Text(title)
                .font(Typography.body(15, weight: .medium))
                .foregroundStyle(Color.ink)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 16)
                .background(Color.clear)
                .clipShape(RoundedRectangle(cornerRadius: Spacing.buttonRadius))
                .overlay(
                    RoundedRectangle(cornerRadius: Spacing.buttonRadius)
                        .stroke(Color.rule, lineWidth: 1)
                )
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Ghost button

struct GhostButton: View {
    let title: String
    var action: () -> Void = {}

    var body: some View {
        Button(action: action) {
            Text(title)
                .font(Typography.body(14, weight: .medium))
                .foregroundStyle(Color.inkSoft)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 16)
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Tag

struct TagView: View {
    let text: String
    var style: TagStyle = .moss

    enum TagStyle { case moss, amber }

    private var color: Color {
        switch style {
        case .moss: .moss
        case .amber: .amber
        }
    }

    var body: some View {
        Text(text.uppercased())
            .font(Typography.monoSmall(9))
            .tracking(1.5)
            .foregroundStyle(color)
            .padding(.horizontal, 8)
            .padding(.vertical, 3)
            .background(color.opacity(0.08))
            .clipShape(RoundedRectangle(cornerRadius: 3))
            .overlay(
                RoundedRectangle(cornerRadius: 3)
                    .stroke(color.opacity(0.2), lineWidth: 1)
            )
    }
}

// MARK: - Field input

struct FieldInput: View {
    let label: String
    @Binding var text: String
    var placeholder: String = ""
    var hint: String = ""

    var body: some View {
        VStack(alignment: .leading, spacing: 7) {
            Text(label.uppercased())
                .font(Typography.monoSmall())
                .tracking(1.5)
                .foregroundStyle(Color.inkFaint)

            TextField(placeholder, text: $text)
                .font(Typography.mono(13))
                .foregroundStyle(Color.ink)
                .autocorrectionDisabled()
                .textInputAutocapitalization(.never)
                .keyboardType(.URL)
                .padding(.horizontal, 16)
                .padding(.vertical, 13)
                .background(Color.paperWarm)
                .clipShape(RoundedRectangle(cornerRadius: Spacing.inputRadius))
                .overlay(
                    RoundedRectangle(cornerRadius: Spacing.inputRadius)
                        .stroke(Color.rule, lineWidth: 1)
                )

            if !hint.isEmpty {
                Text(hint)
                    .font(Typography.caption(11))
                    .foregroundStyle(Color.inkFaint)
                    .lineSpacing(2)
            }
        }
    }
}

// MARK: - Back link

struct BackLink: View {
    let title: String
    var action: () -> Void = {}

    var body: some View {
        Button(action: action) {
            HStack(spacing: 2) {
                Text("\u{2039}")
                Text(title)
            }
            .font(Typography.body(15, weight: .medium))
            .foregroundStyle(Color.rust)
        }
        .buttonStyle(.plain)
    }
}
