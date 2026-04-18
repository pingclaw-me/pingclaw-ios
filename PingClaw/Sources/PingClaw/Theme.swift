import CoreText
import SwiftUI

// PingClaw — Signal palette, mirroring the web style guide.
// Hex values converted from the canonical CSS variables in
// pingclaw_style_guide.md (section 2 "Colour").

extension Color {
    // Backgrounds
    static let pcBg        = Color(red: 8/255,   green: 14/255,  blue: 12/255)   // #080e0c
    static let pcSurface   = Color(red: 15/255,  green: 26/255,  blue: 24/255)   // #0f1a18
    static let pcSurface2  = Color(red: 22/255,  green: 40/255,  blue: 36/255)   // #162824
    static let pcSurface3  = Color(red: 30/255,  green: 53/255,  blue: 48/255)   // #1e3530

    // Borders
    static let pcBorder    = Color(red: 26/255,  green: 46/255,  blue: 42/255)   // #1a2e2a
    static let pcBorder2   = Color(red: 36/255,  green: 62/255,  blue: 56/255)   // #243e38

    // Accent — teal
    static let pcAccent    = Color(red: 0/255,   green: 194/255, blue: 160/255)  // #00c2a0
    static let pcAccent2   = Color(red: 0/255,   green: 133/255, blue: 110/255)  // #00856e
    static let pcAccent3   = Color(red: 0/255,   green: 96/255,  blue: 79/255)   // #00604f
    static let pcAccentBg  = Color(red: 7/255,   green: 26/255,  blue: 22/255)   // #071a16

    // Text
    static let pcText      = Color(red: 192/255, green: 240/255, blue: 232/255)  // #c0f0e8
    static let pcText2     = Color(red: 122/255, green: 184/255, blue: 172/255)  // #7ab8ac
    static let pcText3     = Color(red: 61/255,  green: 110/255, blue: 102/255)  // #3d6e66
    static let pcText4     = Color(red: 32/255,  green: 72/255,  blue: 64/255)   // #204840

    // Semantic
    static let pcWarning   = Color(red: 200/255, green: 154/255, blue: 26/255)   // #c89a1a
    static let pcError     = Color(red: 200/255, green: 64/255,  blue: 64/255)   // #c84040
    static let pcErrorBg   = Color(red: 26/255,  green: 8/255,   blue: 8/255)    // #1a0808
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

    /// "Ping" with the "i" dot replaced by an animated glow circle.
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
        // Blend between dim and bright based on phase.
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
