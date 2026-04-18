# PingClaw Branding Guide

## Name

**PingClaw** — always one word, capital P and capital C. Never "Ping Claw", "pingclaw", or "PINGCLAW".

Tagline: **Location context for AI**

## Logo & Wordmark

- **App icon**: Grid/crosshair motif on dark background with teal accent border and glowing center square. 1024x1024 PNG, no pre-applied rounded corners (iOS applies its own mask).
- **Hero image**: Icon + wordmark + tagline side by side, used on the website landing page and iOS splash screen. File: `Hero.png`.
- **Wordmark image**: Wordmark + tagline without icon, used in website nav bars and iOS main screen. File: `Wordmark.png`.
- **Animated wordmark (iOS)**: The "i" dot in "Ping" is replaced with a small square that pulses between dim teal (`#00a082`) and bright cyan (`#00f0c8`) on a 2-second breathing cycle. Uses `PingClawWordmark` SwiftUI view with Syne ExtraBold font.

## Colors

All colors are shared between the iOS app (`Theme.swift`) and the website (`style.css` CSS variables).

### Backgrounds

| Name | Hex | CSS Variable | Swift |
|------|-----|-------------|-------|
| Background | `#080e0c` | `--pc-bg` | `Color.pcBg` |
| Surface | `#0f1a18` | `--pc-surface` | `Color.pcSurface` |
| Surface 2 | `#162824` | `--pc-surface-2` | `Color.pcSurface2` |
| Surface 3 | `#1e3530` | `--pc-surface-3` | `Color.pcSurface3` |

### Borders

| Name | Hex | CSS Variable | Swift |
|------|-----|-------------|-------|
| Border | `#1a2e2a` | `--pc-border` | `Color.pcBorder` |
| Border 2 | `#243e38` | `--pc-border-2` | `Color.pcBorder2` |

### Accent (Teal)

| Name | Hex | CSS Variable | Swift |
|------|-----|-------------|-------|
| Accent | `#00c2a0` | `--pc-accent` | `Color.pcAccent` |
| Accent 2 | `#00856e` | `--pc-accent-2` | `Color.pcAccent2` |
| Accent 3 | `#00604f` | `--pc-accent-3` | `Color.pcAccent3` |
| Accent Background | `#071a16` | `--pc-accent-bg` | `Color.pcAccentBg` |

### Text

| Name | Hex | CSS Variable | Swift |
|------|-----|-------------|-------|
| Text (primary) | `#c0f0e8` | `--pc-text` | `Color.pcText` |
| Text 2 (secondary) | `#7ab8ac` | `--pc-text-2` | `Color.pcText2` |
| Text 3 (muted) | `#3d6e66` | `--pc-text-3` | `Color.pcText3` |
| Text 4 (faintest) | `#204840` | `--pc-text-4` | `Color.pcText4` |

### Semantic

| Name | Hex | CSS Variable | Swift |
|------|-----|-------------|-------|
| Success | `#00c2a0` | `--pc-success` | (same as accent) |
| Warning | `#c89a1a` | `--pc-warning` | `Color.pcWarning` |
| Error | `#c84040` | `--pc-error` | `Color.pcError` |
| Error Background | `#1a0808` | `--pc-error-bg` | `Color.pcErrorBg` |

### Glow (animated dot)

| Name | Hex | Usage |
|------|-----|-------|
| Glow Bright | `#00f0c8` | Animated dot peak |
| Glow Dim | `#00a082` | Animated dot trough |

## Typography

### Web

| Role | Font Family | CSS Variable |
|------|-------------|-------------|
| Display / Headings | Syne (400, 600, 800) | `--pc-font-display` |
| Body | DM Sans (300, 400, 500) | `--pc-font-body` |
| Monospace | IBM Plex Mono (400, 500) | `--pc-font-mono` |

### Web Type Scale

| Token | Size | CSS Variable |
|-------|------|-------------|
| Hero | `clamp(64px, 10vw, 112px)` | `--pc-type-hero` |
| H1 | `clamp(36px, 5.2vw, 56px)` | `--pc-type-h1` |
| H2 | `clamp(28px, 3.8vw, 40px)` | `--pc-type-h2` |
| H3 | `22px` | `--pc-type-h3` |
| Large | `20px` | `--pc-type-lg` |
| Base | `17px` | `--pc-type-base` |
| Small | `14px` | `--pc-type-sm` |
| XS | `12px` | `--pc-type-xs` |
| Mono | `14px` | `--pc-type-mono` |

### iOS

All fonts use **Dynamic Type** semantic text styles so they scale with the user's system text size preference.

| Usage | Text Style | Notes |
|-------|-----------|-------|
| Page titles | `.title3` | Rounded design, heavy/bold weight |
| Card titles | `.title3` | Rounded design, bold weight |
| Row titles | `.body` | Rounded design, semibold weight |
| Body text | `.body` | Default weight |
| Descriptions | `.footnote` | Secondary color |
| Captions / labels | `.caption` / `.caption2` | Muted color, sometimes tracked |
| Monospaced values | `.callout` | Monospaced design |
| Web code display | `.title` | Monospaced design, bold weight |
| Wordmark | Syne ExtraBold (custom) | Fixed size, not Dynamic Type |

**Font file**: `Syne-VF.ttf` (variable font, weight axis 400-800). OFL-licensed by Bonjour Monde. Registered at runtime via `CTFontManagerRegisterFontsForURL`.

## Spacing

### iOS

| Context | Value |
|---------|-------|
| Horizontal page padding | 24pt |
| Vertical gap between cards | 16pt |
| Card internal padding | 16-20pt |
| Section header top padding | 28pt |
| Section header bottom padding | 10pt |

### Web

| Token | Value | CSS Variable |
|-------|-------|-------------|
| Border radius (small) | 4px | `--pc-radius-sm` |
| Border radius (medium) | 8px | `--pc-radius-md` |
| Border radius (large) | 12px | `--pc-radius-lg` |
| Border radius (XL) | 16px | `--pc-radius-xl` |
| Border radius (full/pill) | 9999px | `--pc-radius-full` |

## Animation

### Web

| Token | Duration | CSS Variable |
|-------|----------|-------------|
| Fast | 100ms | `--pc-duration-fast` |
| Base | 150ms | `--pc-duration-base` |
| Slow | 250ms | `--pc-duration-slow` |
| Reveal | 600ms | `--pc-duration-reveal` |

Easing: `ease` (default), `cubic-bezier(0.0, 0.0, 0.2, 1)` (ease-out).

### iOS

| Animation | Duration | Easing |
|-----------|----------|--------|
| Wordmark dot pulse | 2.0s | ease-in-out, repeats forever |
| Splash fade-out | 0.4s | ease-out |
| Share cooldown toggle | 0.2s | ease-in-out |

## Appearance Modes

The current implementation forces dark mode. A light theme is defined below for future use when the app and website respect the system appearance preference.

### Light Theme Colors

Designed to preserve the teal identity on light backgrounds. Text and background luminance are inverted; accents are darkened slightly for WCAG contrast on white.

#### Backgrounds (Light)

| Name | Dark Hex | Light Hex | Notes |
|------|----------|-----------|-------|
| Background | `#080e0c` | `#f2f7f6` | Cool off-white with teal undertone |
| Surface | `#0f1a18` | `#ffffff` | Pure white cards |
| Surface 2 | `#162824` | `#e8f0ee` | Subtle teal tint for grouped sections |
| Surface 3 | `#1e3530` | `#dce6e4` | Slightly darker grouping |

#### Borders (Light)

| Name | Dark Hex | Light Hex | Notes |
|------|----------|-----------|-------|
| Border | `#1a2e2a` | `#c8d8d4` | Soft teal-gray |
| Border 2 | `#243e38` | `#b0c4be` | Slightly darker for emphasis |

#### Accent (Light)

| Name | Dark Hex | Light Hex | Notes |
|------|----------|-----------|-------|
| Accent | `#00c2a0` | `#009e82` | Darkened for 4.5:1 contrast on white |
| Accent 2 | `#00856e` | `#007a66` | Hover / pressed states |
| Accent 3 | `#00604f` | `#e0f5f0` | Light teal fill for buttons on light bg |
| Accent Background | `#071a16` | `#e8f8f4` | Tinted background for ON pill, etc. |

#### Text (Light)

| Name | Dark Hex | Light Hex | Notes |
|------|----------|-----------|-------|
| Text (primary) | `#c0f0e8` | `#0a1e1a` | Near-black with teal undertone |
| Text 2 (secondary) | `#7ab8ac` | `#3d5c54` | Medium dark for descriptions |
| Text 3 (muted) | `#3d6e66` | `#6b8f86` | Labels, captions |
| Text 4 (faintest) | `#204840` | `#9bb5ae` | Placeholders, disabled text |

#### Semantic (Light)

| Name | Dark Hex | Light Hex | Notes |
|------|----------|-----------|-------|
| Success | `#00c2a0` | `#009e82` | Same as accent (light) |
| Warning | `#c89a1a` | `#9e7a00` | Darkened for contrast on white |
| Warning Background | `#1a1400` | `#fdf6e0` | Light warm tint |
| Error | `#c84040` | `#b83030` | Darkened for contrast |
| Error Background | `#1a0808` | `#fdeaea` | Light red tint |

#### Glow / Animated Dot (Light)

| Name | Dark Hex | Light Hex | Notes |
|------|----------|-----------|-------|
| Glow Bright | `#00f0c8` | `#009e82` | Solid accent (no glow needed on light) |
| Glow Dim | `#00a082` | `#40c0a8` | Softer mid-teal |

### Sign-In Buttons (Light)

- **Sign in with Apple**: `.black` style (dark button on light background).
- **Sign in with Google**: Dark background (`#1a1a1a`), white text, to match Apple button contrast.

### Wordmark (Light)

The branded wordmark images (`Hero.png`, `Wordmark.png`) are designed for dark backgrounds and will need light-mode variants with dark text. The animated `PingClawWordmark` SwiftUI view should swap `Color.pcText` to the light-mode primary text color automatically when colors are defined as adaptive.

### CSS Implementation

On the web, define light-mode overrides using `prefers-color-scheme`:

```css
@media (prefers-color-scheme: light) {
  :root {
    --pc-bg:        #f2f7f6;
    --pc-surface:   #ffffff;
    --pc-surface-2: #e8f0ee;
    --pc-surface-3: #dce6e4;
    --pc-border:    #c8d8d4;
    --pc-border-2:  #b0c4be;
    --pc-accent:    #009e82;
    --pc-accent-2:  #007a66;
    --pc-accent-3:  #e0f5f0;
    --pc-accent-bg: #e8f8f4;
    --pc-text:      #0a1e1a;
    --pc-text-2:    #3d5c54;
    --pc-text-3:    #6b8f86;
    --pc-text-4:    #9bb5ae;
    --pc-success:   #009e82;
    --pc-warning:   #9e7a00;
    --pc-warning-bg:#fdf6e0;
    --pc-error:     #b83030;
    --pc-error-bg:  #fdeaea;
  }
}
```

### Swift Implementation

In `Theme.swift`, define each color with light/dark adaptive values:

```swift
// Example: replace static Color with adaptive init
static let pcBg = Color(light: Color(hex: 0xf2f7f6), dark: Color(hex: 0x080e0c))
```

Or use a `Color(UIColor { traits in })` initializer:

```swift
static let pcBg = Color(UIColor { traits in
    traits.userInterfaceStyle == .dark
        ? UIColor(red: 8/255, green: 14/255, blue: 12/255, alpha: 1)
        : UIColor(red: 242/255, green: 247/255, blue: 246/255, alpha: 1)
})
```

Remove `.preferredColorScheme(.dark)` from all views and `UIUserInterfaceStyle: Dark` from Info.plist to let the system choose.

## Sign-In Buttons

- **Sign in with Apple**: Native `SignInWithAppleButton`, `.white` style, 50pt height, 8pt corner radius.
- **Sign in with Google**: Custom styled button matching Apple button — white background, black text, Google "G" logo (colored SVG on web, bold text on iOS), 50pt height, 8pt corner radius.

## Assets

| File | Location | Usage |
|------|----------|-------|
| `AppIcon.png` | iOS root | 1024x1024 app icon |
| `Hero.png` | iOS Resources, web `/hero.png` | Splash screen, website landing |
| `Wordmark.png` | iOS Resources, web `/wordmark.png` | Main screen, website nav bars |
| `icon.png` | web `/icon.png` | Favicon, web meta tags |
| `Syne-VF.ttf` | iOS Resources/Fonts | Wordmark font |
