import SwiftUI

struct TerminalTheme {
    let backgroundColor: Color
    let foregroundColor: Color
    let accentColor: Color
    let errorColor: Color
    let successColor: Color
    let warningColor: Color
    let commentColor: Color
    let keywordColor: Color
    let stringColor: Color
    let numberColor: Color
    
    static let nuxDark = TerminalTheme(
        backgroundColor: Color(red: 0.08, green: 0.08, blue: 0.08),
        foregroundColor: Color(red: 0.95, green: 0.95, blue: 0.95),
        accentColor: Color(red: 0.0, green: 0.8, blue: 0.4),
        errorColor: Color(red: 1.0, green: 0.3, blue: 0.3),
        successColor: Color(red: 0.0, green: 0.8, blue: 0.4),
        warningColor: Color(red: 1.0, green: 0.8, blue: 0.0),
        commentColor: Color(red: 0.5, green: 0.5, blue: 0.5),
        keywordColor: Color(red: 0.8, green: 0.4, blue: 1.0),
        stringColor: Color(red: 0.4, green: 0.8, blue: 1.0),
        numberColor: Color(red: 1.0, green: 0.6, blue: 0.4)
    )
    
    static let classic = TerminalTheme(
        backgroundColor: .black,
        foregroundColor: .white,
        accentColor: .green,
        errorColor: .red,
        successColor: .green,
        warningColor: .yellow,
        commentColor: .gray,
        keywordColor: .blue,
        stringColor: .cyan,
        numberColor: .yellow
    )
    
    static let cyberpunk = TerminalTheme(
        backgroundColor: Color(red: 0.05, green: 0.02, blue: 0.1),
        foregroundColor: Color(red: 0.9, green: 0.95, blue: 1.0),
        accentColor: Color(red: 0.0, green: 1.0, blue: 0.8),
        errorColor: Color(red: 1.0, green: 0.2, blue: 0.6),
        successColor: Color(red: 0.0, green: 1.0, blue: 0.8),
        warningColor: Color(red: 1.0, green: 0.8, blue: 0.0),
        commentColor: Color(red: 0.4, green: 0.4, blue: 0.6),
        keywordColor: Color(red: 1.0, green: 0.4, blue: 0.8),
        stringColor: Color(red: 0.4, green: 0.8, blue: 1.0),
        numberColor: Color(red: 1.0, green: 0.6, blue: 0.2)
    )
    
    static let dracula = TerminalTheme(
        backgroundColor: Color(red: 0.16, green: 0.16, blue: 0.21),
        foregroundColor: Color(red: 0.93, green: 0.93, blue: 0.95),
        accentColor: Color(red: 0.8, green: 0.47, blue: 0.95),
        errorColor: Color(red: 1.0, green: 0.35, blue: 0.35),
        successColor: Color(red: 0.47, green: 0.95, blue: 0.47),
        warningColor: Color(red: 1.0, green: 0.8, blue: 0.0),
        commentColor: Color(red: 0.5, green: 0.5, blue: 0.6),
        keywordColor: Color(red: 0.8, green: 0.47, blue: 0.95),
        stringColor: Color(red: 0.47, green: 0.95, blue: 0.47),
        numberColor: Color(red: 0.95, green: 0.47, blue: 0.47)
    )
    
    static let nord = TerminalTheme(
        backgroundColor: Color(red: 0.13, green: 0.16, blue: 0.22),
        foregroundColor: Color(red: 0.88, green: 0.91, blue: 0.95),
        accentColor: Color(red: 0.47, green: 0.76, blue: 0.95),
        errorColor: Color(red: 0.95, green: 0.47, blue: 0.47),
        successColor: Color(red: 0.47, green: 0.95, blue: 0.47),
        warningColor: Color(red: 0.95, green: 0.76, blue: 0.47),
        commentColor: Color(red: 0.47, green: 0.47, blue: 0.47),
        keywordColor: Color(red: 0.76, green: 0.47, blue: 0.95),
        stringColor: Color(red: 0.47, green: 0.95, blue: 0.76),
        numberColor: Color(red: 0.95, green: 0.76, blue: 0.47)
    )
    
    static let solarized = TerminalTheme(
        backgroundColor: Color(red: 0.0, green: 0.17, blue: 0.21),
        foregroundColor: Color(red: 0.52, green: 0.6, blue: 0.54),
        accentColor: Color(red: 0.0, green: 0.6, blue: 0.53),
        errorColor: Color(red: 0.86, green: 0.2, blue: 0.18),
        successColor: Color(red: 0.0, green: 0.6, blue: 0.53),
        warningColor: Color(red: 0.8, green: 0.29, blue: 0.09),
        commentColor: Color(red: 0.35, green: 0.43, blue: 0.45),
        keywordColor: Color(red: 0.15, green: 0.55, blue: 0.82),
        stringColor: Color(red: 0.0, green: 0.6, blue: 0.53),
        numberColor: Color(red: 0.8, green: 0.29, blue: 0.09)
    )
    
    static let tokyoNight = TerminalTheme(
        backgroundColor: Color(red: 0.06, green: 0.06, blue: 0.12),
        foregroundColor: Color(red: 0.85, green: 0.87, blue: 0.9),
        accentColor: Color(red: 0.47, green: 0.76, blue: 0.95),
        errorColor: Color(red: 0.95, green: 0.47, blue: 0.47),
        successColor: Color(red: 0.47, green: 0.95, blue: 0.47),
        warningColor: Color(red: 0.95, green: 0.76, blue: 0.47),
        commentColor: Color(red: 0.35, green: 0.35, blue: 0.45),
        keywordColor: Color(red: 0.76, green: 0.47, blue: 0.95),
        stringColor: Color(red: 0.47, green: 0.95, blue: 0.76),
        numberColor: Color(red: 0.95, green: 0.76, blue: 0.47)
    )
    
    static let gruvbox = TerminalTheme(
        backgroundColor: Color(red: 0.14, green: 0.12, blue: 0.08),
        foregroundColor: Color(red: 0.84, green: 0.77, blue: 0.66),
        accentColor: Color(red: 0.69, green: 0.54, blue: 0.0),
        errorColor: Color(red: 0.8, green: 0.25, blue: 0.25),
        successColor: Color(red: 0.54, green: 0.69, blue: 0.0),
        warningColor: Color(red: 0.69, green: 0.54, blue: 0.0),
        commentColor: Color(red: 0.46, green: 0.42, blue: 0.35),
        keywordColor: Color(red: 0.8, green: 0.25, blue: 0.25),
        stringColor: Color(red: 0.54, green: 0.69, blue: 0.0),
        numberColor: Color(red: 0.69, green: 0.54, blue: 0.0)
    )
}

class ThemeManager: ObservableObject {
    @Published var currentTheme: TerminalTheme = .nuxDark
    private let themeDefaultsKey = "SelectedThemeName"
    
    init() {
        // Load persisted theme if available
        if let saved = UserDefaults.standard.string(forKey: themeDefaultsKey) {
            setThemeByName(saved)
        }
    }
    
    func setTheme(_ theme: TerminalTheme) {
        currentTheme = theme
    }
    
    // Convenience: select and persist by human-readable name
    func setThemeByName(_ name: String) {
        switch name {
        case "nux Dark": currentTheme = .nuxDark
        case "Classic": currentTheme = .classic
        case "Cyberpunk": currentTheme = .cyberpunk
        case "Dracula": currentTheme = .dracula
        case "Nord": currentTheme = .nord
        case "Solarized": currentTheme = .solarized
        case "Tokyo Night": currentTheme = .tokyoNight
        case "Gruvbox": currentTheme = .gruvbox
        default: currentTheme = .nuxDark
        }
        UserDefaults.standard.set(name, forKey: themeDefaultsKey)
    }
    
    func getSavedThemeName() -> String {
        UserDefaults.standard.string(forKey: themeDefaultsKey) ?? "nux Dark"
    }
    
    // MARK: - Agent Highlight Color (Theme-aware)
    // Returns a highly contrasting color to use for Agent mode UI that avoids
    // clashing with the theme's existing accent/warning palette.
    func agentColor() -> Color {
        // Candidate palette
        let gold = Color(red: 0.95, green: 0.75, blue: 0.10)   // preferred for dark themes
        let cyan = Color(red: 0.00, green: 0.85, blue: 0.90)   // preferred for light/cool themes
        let magenta = Color(red: 0.95, green: 0.35, blue: 0.85) // fallback pop

        // Detect theme hue tendencies
        let accent = currentTheme.accentColor
        let warning = currentTheme.warningColor
        let accentHue = approximateHue(for: accent)
        let warningHue = approximateHue(for: warning)
        // Rough hue buckets in [0,1]
        func isYellowish(_ h: CGFloat) -> Bool { angularDistance(h, 0.125) < 0.08 }

        let themeYellowish = isYellowish(accentHue) || isYellowish(warningHue)

        // Background luminance to decide dark vs light theme bias
        let bg = currentTheme.backgroundColor
        let bgLum = relativeLuminance(bg)

        // Compute contrasts once
        let goldContrast = contrastRatio(gold, bg)
        let cyanContrast = contrastRatio(cyan, bg)
        let magentaContrast = contrastRatio(magenta, bg)

        // Heuristic:
        // - Prefer GOLD on dark themes when not already yellow-ish and contrast is decent
        // - Prefer CYAN on light themes or when theme already leans yellow
        // - Otherwise pick the highest-contrast of the three
        if bgLum < 0.25 { // dark theme
            if !themeYellowish && goldContrast >= 3.0 { return gold }
            // Fall back to highest contrast
            let best = max(goldContrast, cyanContrast, magentaContrast)
            if best == goldContrast { return gold }
            if best == cyanContrast { return cyan }
            return magenta
        } else { // lighter theme
            if !themeYellowish && cyanContrast >= 3.5 { return cyan }
            let best = max(goldContrast, cyanContrast, magentaContrast)
            if best == cyanContrast { return cyan }
            if best == goldContrast { return gold }
            return magenta
        }
    }
    
    // MARK: - Color Utilities (approximate; sufficient for theme picking)
    private func components(for color: Color) -> (r: CGFloat, g: CGFloat, b: CGFloat) {
        #if os(macOS)
        let ns = NSColor(color)
        let conv = ns.usingColorSpace(.extendedSRGB) ?? ns
        return (conv.redComponent, conv.greenComponent, conv.blueComponent)
        #else
        let ui = UIColor(color)
        var r: CGFloat = 0, g: CGFloat = 0, b: CGFloat = 0, a: CGFloat = 0
        ui.getRed(&r, &g, &b, &a)
        return (r, g, b)
        #endif
    }
    
    private func approximateHue(for color: Color) -> CGFloat {
        let c = components(for: color)
        let maxV = max(c.r, max(c.g, c.b))
        let minV = min(c.r, min(c.g, c.b))
        let delta = maxV - minV
        if delta == 0 { return 0 }
        var h: CGFloat
        if maxV == c.r {
            h = (c.g - c.b) / delta
        } else if maxV == c.g {
            h = 2 + (c.b - c.r) / delta
        } else {
            h = 4 + (c.r - c.g) / delta
        }
        h /= 6
        if h < 0 { h += 1 }
        return h
    }
    
    private func relativeLuminance(_ color: Color) -> CGFloat {
        let c = components(for: color)
        func adjust(_ v: CGFloat) -> CGFloat {
            return (v <= 0.03928) ? (v / 12.92) : pow((v + 0.055) / 1.055, 2.4)
        }
        let r = adjust(c.r), g = adjust(c.g), b = adjust(c.b)
        return 0.2126*r + 0.7152*g + 0.0722*b
        }
    
    private func contrastRatio(_ a: Color, _ b: Color) -> CGFloat {
        let L1 = relativeLuminance(a)
        let L2 = relativeLuminance(b)
        let (maxL, minL) = (max(L1, L2), min(L1, L2))
        return (maxL + 0.05) / (minL + 0.05)
    }
    
    private func angularDistance(_ a: CGFloat, _ b: CGFloat) -> CGFloat {
        let diff = abs(a - b)
        return min(diff, 1 - diff)
    }
}
