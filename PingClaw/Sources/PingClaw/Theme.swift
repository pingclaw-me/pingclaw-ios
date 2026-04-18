import CoreText
import SwiftUI
#if os(iOS)
import UIKit
#endif

// PingClaw — Adaptive color palette supporting light and dark mode.
// Dark values match the web style guide CSS variables.
// Light values are designed for WCAG contrast on white backgrounds.

private func adaptive(light: (CGFloat, CGFloat, CGFloat), dark: (CGFloat, CGFloat, CGFloat)) -> Color {
    #if os(iOS)
    Color(UIColor { traits in
        let (r, g, b) = traits.userInterfaceStyle == .dark ? dark : light
        return UIColor(red: r/255, green: g/255, blue: b/255, alpha: 1)
    })
    #else
    Color(red: dark.0/255, green: dark.1/255, blue: dark.2/255)
    #endif
}

extension Color {
    // Backgrounds
    static let pcBg       = adaptive(light: (242, 247, 246), dark: (8, 14, 12))       // #f2f7f6 / #080e0c
    static let pcSurface  = adaptive(light: (255, 255, 255), dark: (15, 26, 24))      // #ffffff / #0f1a18
    static let pcSurface2 = adaptive(light: (232, 240, 238), dark: (22, 40, 36))      // #e8f0ee / #162824
    static let pcSurface3 = adaptive(light: (220, 230, 228), dark: (30, 53, 48))      // #dce6e4 / #1e3530

    // Borders
    static let pcBorder   = adaptive(light: (200, 216, 212), dark: (26, 46, 42))      // #c8d8d4 / #1a2e2a
    static let pcBorder2  = adaptive(light: (176, 196, 190), dark: (36, 62, 56))      // #b0c4be / #243e38

    // Accent — teal (darkened in light mode for contrast on white)
    static let pcAccent   = adaptive(light: (0, 158, 130), dark: (0, 194, 160))       // #009e82 / #00c2a0
    static let pcAccent2  = adaptive(light: (0, 122, 102), dark: (0, 133, 110))       // #007a66 / #00856e
    static let pcAccent3  = adaptive(light: (224, 245, 240), dark: (0, 96, 79))       // #e0f5f0 / #00604f
    static let pcAccentBg = adaptive(light: (232, 248, 244), dark: (7, 26, 22))       // #e8f8f4 / #071a16

    // Text
    static let pcText     = adaptive(light: (10, 30, 26), dark: (192, 240, 232))      // #0a1e1a / #c0f0e8
    static let pcText2    = adaptive(light: (61, 92, 84), dark: (122, 184, 172))      // #3d5c54 / #7ab8ac
    static let pcText3    = adaptive(light: (107, 143, 134), dark: (61, 110, 102))    // #6b8f86 / #3d6e66
    static let pcText4    = adaptive(light: (155, 181, 174), dark: (32, 72, 64))      // #9bb5ae / #204840

    // Semantic
    static let pcWarning  = adaptive(light: (158, 122, 0), dark: (200, 154, 26))      // #9e7a00 / #c89a1a
    static let pcError    = adaptive(light: (184, 48, 48), dark: (200, 64, 64))       // #b83030 / #c84040
    static let pcErrorBg  = adaptive(light: (253, 234, 234), dark: (26, 8, 8))        // #fdeaea / #1a0808
}

// Register Syne (bundled OFL font) once at app startup so SwiftUI
// `Font.custom("Syne-ExtraBold", ...)` resolves on iOS. SwiftPM resources
// don't auto-populate UIAppFonts, so we register at runtime.
enum PingClawFonts {
    static let register: Void = {
        guard let url = Bundle.module.url(
            forResource: "Syne-VF",
            withExtension: "ttf",
            subdirectory: "Fonts"
        ) else {
            return
        }
        var error: Unmanaged<CFError>?
        CTFontManagerRegisterFontsForURL(url as CFURL, .process, &error)
    }()
}

// Two-tone wordmark — "Ping" in primary text, "Claw" in accent teal,
// always on a single line. Uses Syne ExtraBold (bundled). The dot on
// the "i" in "Ping" pulses with the accent glow from the app icon.
// When `animated` is true (default) the dot cycles through a soft
// breathing glow.
struct PingClawWordmark: View {
    var size: CGFloat = 28
    var animated: Bool = true

    var body: some View {
        HStack(spacing: 0) {
            pingText
            Text("Claw").foregroundStyle(Color.pcAccent)
        }
        .font(.custom("Syne-ExtraBold", size: size))
    }

    /// "Ping" with the "i" dot replaced by an animated glow square.
    /// The dotless-i trick: render "P" + "ı" (U+0131, Turkish dotless i)
    /// + "ng" so the font draws no dot, then overlay our own.
    private var pingText: some View {
        HStack(spacing: 0) {
            Text("P\u{0131}")
                .foregroundStyle(Color.pcText)
                .overlay(alignment: .topTrailing) {
                    PingDot(size: size, animated: animated)
                }
            Text("ng")
                .foregroundStyle(Color.pcText)
        }
    }
}

/// The pulsing dot that replaces the "i" tittle in "Ping".
private struct PingDot: View {
    let size: CGFloat
    let animated: Bool
    @State private var phase: CGFloat = 0

    // Glow colours sampled from the app icon's crosshair.
    private let glowBright = Color(red: 0/255, green: 240/255, blue: 200/255) // bright cyan
    private let glowDim    = Color(red: 0/255, green: 160/255, blue: 130/255) // dimmer teal

    private var dotSize: CGFloat { size * 0.16 }

    // Vertical offset: place the dot where a Syne ExtraBold tittle sits.
    private var yOffset: CGFloat { size * 0.08 }
    // Pull left to center over the stem of ı.
    private var xOffset: CGFloat { size * 0.19 }

    var body: some View {
        Rectangle()
            .fill(currentColor)
            .frame(width: dotSize, height: dotSize)
            .shadow(color: currentColor.opacity(glowOpacity), radius: dotSize * 0.8)
            .offset(x: -xOffset, y: yOffset)
            .onAppear {
                guard animated else { return }
                withAnimation(.easeInOut(duration: 2.0).repeatForever(autoreverses: true)) {
                    phase = 1
                }
            }
    }

    private var currentColor: Color {
        animated ? interpolated : glowBright
    }

    private var glowOpacity: Double {
        animated ? 0.5 + 0.4 * Double(phase) : 0.7
    }

    private var interpolated: Color {
        let t = Double(phase)
        return Color(
            red:   lerp(0/255, 0/255, t),
            green: lerp(160/255, 240/255, t),
            blue:  lerp(130/255, 200/255, t)
        )
    }

    private func lerp(_ a: Double, _ b: Double, _ t: Double) -> Double {
        a + (b - a) * t
    }
}
