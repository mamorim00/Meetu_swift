// In Color.swift

import SwiftUI

extension Color {
    // Helper to choose between light and dark theme colors (already provided by you)
    private static func themed(light: Color, dark: Color, for scheme: ColorScheme) -> Color {
        switch scheme {
        case .dark:
            return dark
        default:
            return light
        }
    }

    // MARK: - App Generic Colors from Theme (existing)
    static func appBackground(for scheme: ColorScheme) -> Color { themed(light: Theme.Light.background, dark: Theme.Dark.background, for: scheme) }
    static func appForeground(for scheme: ColorScheme) -> Color { themed(light: Theme.Light.foreground, dark: Theme.Dark.foreground, for: scheme) }
    
    // ... (other existing color functions like appDestructive, appPrimary, etc.) ...

    // MODIFIED: appCardBackground to handle categories
    static func appCardBackground(for category: String, scheme: ColorScheme) -> Color {
        switch category.lowercased() { // Use lowercased for case-insensitive matching
        case "sports":
            return themed(light: Theme.Light.sportsCardBackground, dark: Theme.Dark.sportsCardBackground, for: scheme)
        case "dining":
            return themed(light: Theme.Light.diningCardBackground, dark: Theme.Dark.diningCardBackground, for: scheme)
        case "hiking":
            return themed(light: Theme.Light.hikingCardBackground, dark: Theme.Dark.hikingCardBackground, for: scheme)
        case "gaming":
            return themed(light: Theme.Light.gamingCardBackground, dark: Theme.Dark.gamingCardBackground, for: scheme)
        case "movies":
            return themed(light: Theme.Light.moviesCardBackground, dark: Theme.Dark.moviesCardBackground, for: scheme)
        case "travel":
            return themed(light: Theme.Light.travelCardBackground, dark: Theme.Dark.travelCardBackground, for: scheme)
        case "music":
            return themed(light: Theme.Light.musicCardBackground, dark: Theme.Dark.musicCardBackground, for: scheme)
        case "cooking":
            return themed(light: Theme.Light.cookingCardBackground, dark: Theme.Dark.cookingCardBackground, for: scheme)
        default:
            // Fallback to a generic card background if the category doesn't match
            // or if you want a default for categories not explicitly listed.
            // Ensure Theme.Light.card/defaultCardBackground and Theme.Dark.card/defaultCardBackground are defined.
            return themed(light: Theme.Light.defaultCardBackground, dark: Theme.Dark.defaultCardBackground, for: scheme)
        }
    }

    // Ensure you still have these or similar if needed for other contexts,
    // or if the new appCardBackground is the sole source for card backgrounds.
    // static func appCardBackground(for scheme: ColorScheme) -> Color { themed(light: Theme.Light.card, dark: Theme.Dark.card, for: scheme) } // This is now replaced by the above.

    static func appCardForeground(for scheme: ColorScheme) -> Color { themed(light: Theme.Light.cardForeground, dark: Theme.Dark.cardForeground, for: scheme) }
    static func appDestructive(for scheme: ColorScheme) -> Color { themed(light: Theme.Light.destructive, dark: Theme.Dark.destructive, for: scheme) }
    static func appDestructiveForeground(for scheme: ColorScheme) -> Color { themed(light: Theme.Light.destructiveForeground, dark: Theme.Dark.destructiveForeground, for: scheme) }

    static func appPrimary(for scheme: ColorScheme) -> Color { themed(light: Theme.Light.primaryForeground, dark: Theme.Dark.primary, for: scheme) }
    static func appPrimaryForeground(for scheme: ColorScheme) -> Color { themed(light: Theme.Light.secondaryForeground, dark: Theme.Dark.primaryForeground, for: scheme) }

    static func appSecondary(for scheme: ColorScheme) -> Color { themed(light: Theme.Light.secondary, dark: Theme.Dark.secondary, for: scheme) }
    static func appSecondaryForeground(for scheme: ColorScheme) -> Color { themed(light: Theme.Light.secondaryForeground, dark: Theme.Dark.secondaryForeground, for: scheme) }

    static func appAccent(for scheme: ColorScheme) -> Color { themed(light: Theme.Light.accent, dark: Theme.Dark.accent, for: scheme) }
    static func appAccentForeground(for scheme: ColorScheme) -> Color { themed(light: Theme.Light.accentForeground, dark: Theme.Dark.accentForeground, for: scheme) }

    static func appMuted(for scheme: ColorScheme) -> Color { themed(light: Theme.Light.muted, dark: Theme.Dark.muted, for: scheme) }
    static func appMutedForeground(for scheme: ColorScheme) -> Color { themed(light: Theme.Light.mutedForeground, dark: Theme.Dark.mutedForeground, for: scheme) }

    static func appBorder(for scheme: ColorScheme) -> Color { themed(light: Theme.Light.border, dark: Theme.Dark.border, for: scheme) }
    static func appInputBackground(for scheme: ColorScheme) -> Color { themed(light: Theme.Light.input, dark: Theme.Dark.input, for: scheme) }
    static func appInputPlaceholder(for scheme: ColorScheme) -> Color { themed(light: Color.gray.opacity(0.7), dark: Color.gray.opacity(0.7), for: scheme) }

    // MARK: - Chat Specific Colors from Theme (existing)
    static func chatHeaderBackground(for scheme: ColorScheme) -> Color { themed(light: Theme.Light.card, dark: Theme.Dark.card, for: scheme) }
    static func chatInputBarBackground(for scheme: ColorScheme) -> Color { themed(light: Theme.Light.background, dark: Theme.Dark.background, for: scheme) }

    static func myMessageBackground(for scheme: ColorScheme) -> Color { appAccent(for: scheme) }
    static func myMessageForeground(for scheme: ColorScheme) -> Color { appAccentForeground(for: scheme) }

    static func otherMessageBackground(for scheme: ColorScheme) -> Color { themed(light: Theme.Light.muted, dark: Theme.Dark.muted, for: scheme) }
    static func otherMessageForeground(for scheme: ColorScheme) -> Color { appForeground(for: scheme) }

    static func avatarBackground(for scheme: ColorScheme) -> Color { appSecondary(for: scheme) }
    static func avatarForeground(for scheme: ColorScheme) -> Color { appSecondaryForeground(for: scheme) }
}
