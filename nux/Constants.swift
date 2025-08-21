import Foundation
import SwiftUI

// MARK: - Autocomplete Configuration
struct AutocompleteConstants {
    // Popup Display
    static let maxVisibleItems = 4
    static let itemHeight: CGFloat = 24
    static let popupCornerRadius: CGFloat = 8
    static let itemCornerRadius: CGFloat = 3
    
    // Spacing and Padding
    static let popupVerticalPadding: CGFloat = 4
    static let itemHorizontalPadding: CGFloat = 8
    static let itemVerticalPadding: CGFloat = 4
    static let iconSpacing: CGFloat = 8
    static let popupItemSpacing: CGFloat = 8
    
    // Control Bar Positioning
    static let popupTopPadding: CGFloat = 80
    static let popupBottomGap: CGFloat = 60
    static let popupShadowPadding: CGFloat = 8
    
    // Visual Elements
    static let selectionIndicatorSize: CGFloat = 5
    static let iconSize: CGFloat = 10
    static let iconFrameWidth: CGFloat = 14
    static let maxCompletionWidth: CGFloat = 180
    
    // Typography
    static let completionFontSize: CGFloat = 13
    static let typeBadgeFontSize: CGFloat = 8
    static let detailsFontSize: CGFloat = 12
    static let scrollIndicatorFontSize: CGFloat = 8
    
    // Type Badge
    static let typeBadgeHorizontalPadding: CGFloat = 3
    static let typeBadgeVerticalPadding: CGFloat = 1
    static let typeBadgeCornerRadius: CGFloat = 2
    
    // Details Box
    static let detailsBoxHorizontalPadding: CGFloat = 8
    static let detailsBoxVerticalPadding: CGFloat = 4
    static let detailsBoxCornerRadius: CGFloat = 6
    
    // Shadows and Effects
    static let popupShadowRadius: CGFloat = 12
    static let popupShadowOffset: CGFloat = 4
    static let detailsShadowRadius: CGFloat = 6
    static let detailsShadowOffset: CGFloat = 2
    
    // Opacity Values
    static let backgroundOpacity: Double = 0.98
    static let detailsBackgroundOpacity: Double = 0.95
    static let shadowOpacity: Double = 0.5
    static let detailsShadowOpacity: Double = 0.3
    static let selectionBackgroundOpacity: Double = 0.15
    static let iconInactiveOpacity: Double = 0.6
    static let textInactiveOpacity: Double = 0.8
    static let typeBadgeBackgroundOpacity: Double = 0.1
    static let typeBadgeTextOpacity: Double = 0.4
    static let borderOpacity: Double = 0.3
    static let detailsBorderOpacity: Double = 0.5
    static let scrollIndicatorOpacity: Double = 0.4
    
    // Animation
    static let animationDuration: Double = 0.2
    
    // Scroll Indicators
    static let scrollIndicatorTopPadding: CGFloat = 2
    static let scrollIndicatorBottomPadding: CGFloat = 2
    static let upScrollThreshold = 1 // Show up arrow when selectedIndex > this
    static let downScrollThreshold = 2 // Show down arrow when selectedIndex < count - this
}

// MARK: - Terminal Configuration
struct TerminalConstants {
    // Command History
    static let maxHistoryItems = 100
    
    // Prompt Calculation
    static let promptSpacing: CGFloat = 12
    static let horizontalPadding: CGFloat = 16
    static let monospacedFontSize: CGFloat = 17
}

// MARK: - Theme Configuration
struct ThemeConstants {
    // Color Opacity Levels
    static let primaryOpacity: Double = 1.0
    static let secondaryOpacity: Double = 0.9
    static let tertiaryOpacity: Double = 0.6
    static let quaternaryOpacity: Double = 0.4
    static let backgroundOpacity: Double = 0.1
}
