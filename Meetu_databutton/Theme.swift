import SwiftUI

struct Theme {
    // MARK: - Brand Green
    private static let brandHue: Double = 145/360  // vibrant green
    private static let brandSaturation: Double = 0.65
    private static let brandBrightness: Double = 0.55

    // MARK: - Light Mode Colors
    struct Light {
        static let primary = Color(hue: brandHue, saturation: brandSaturation, brightness: brandBrightness)
        static let primaryForeground = Color.white

        static let secondary = Color(hue: 150/360, saturation: 0.35, brightness: 0.80) // Soft mint
        static let secondaryForeground = Color(hue: 240/360, saturation: 0.05, brightness: 0.10)

        static let accent = Color(hue: 180/360, saturation: 0.70, brightness: 0.60) // Aqua
        static let accentForeground = Color.white

        static let background = Color.white
        static let foreground = Color(hue: 240/360, saturation: 0.08, brightness: 0.10) // Very dark blue/almost black

        static let card = background // Default card is white
        static let cardForeground = foreground

        static let popover = background
        static let popoverForeground = foreground

        static let muted = Color(hue: 145/360, saturation: 0.10, brightness: 0.95) // Very light, brand-aligned mint
        static let mutedForeground = Color(hue: 240/360, saturation: 0.05, brightness: 0.45) // Medium-dark grey-blue

        static let destructive = Color(hue: 0.0, saturation: 0.80, brightness: 0.70)
        static let destructiveForeground = Color.white

        static let border = Color(hue: 145/360, saturation: 0.30, brightness: 0.85)
        static let input = border
        static let ring = Color(hue: brandHue, saturation: brandSaturation, brightness: 0.35)

        // Chart colors: vibrant and youthful
        static let chart1 = Color(hue: 120/360, saturation: 0.80, brightness: 0.65) // lime green
        static let chart2 = Color(hue: 180/360, saturation: 0.70, brightness: 0.60) // aqua
        static let chart3 = Color(hue: 210/360, saturation: 0.60, brightness: 0.55) // sky blue
        static let chart4 = Color(hue: 330/360, saturation: 0.65, brightness: 0.70) // magenta
        static let chart5 = Color(hue: 280/360, saturation: 0.60, brightness: 0.65) // violet

        // MARK: - Category Card Backgrounds (Light) - REVISED
        static let sportsCardBackground = Color(hue: 210/360, saturation: 0.25, brightness: 0.95)   // Very light sky blue
        static let diningCardBackground = Color(hue: 20/360, saturation: 0.30, brightness: 0.96)    // Very light soft coral/peach
        static let hikingCardBackground = Color(hue: 145/360, saturation: 0.20, brightness: 0.95)   // Very light mint (theme-aligned)
        static let gamingCardBackground = Color(hue: 280/360, saturation: 0.20, brightness: 0.95)   // Very light violet (chart-aligned)
        static let moviesCardBackground = Color(hue: 220/360, saturation: 0.10, brightness: 0.96)   // Very light cool grey/blue
        static let travelCardBackground = Color(hue: 180/360, saturation: 0.25, brightness: 0.95)   // Very light aqua (theme-aligned)
        static let musicCardBackground = Color(hue: 330/360, saturation: 0.25, brightness: 0.96)    // Very light pink/magenta (chart-aligned)
        static let cookingCardBackground = Color(hue: 40/360, saturation: 0.15, brightness: 0.96)   // Very light warm beige
        
        static let defaultCardBackground = Self.card // Fallback to default card (white)
    }

    // MARK: - Dark Mode Colors
    struct Dark {
        static let primary = Color(hue: brandHue, saturation: brandSaturation, brightness: brandBrightness)
        static let primaryForeground = Color.black // Used with the primary color background

        static let background = Color(hue: 240/360, saturation: 0.10, brightness: 0.05) // Very dark blue
        static let foreground = Color(hue: 0.0, saturation: 0.0, brightness: 0.95)     // Almost white

        static let card = background // Default card is very dark blue
        static let cardForeground = foreground

        static let popover = background
        static let popoverForeground = foreground

        static let secondary = Color(hue: 150/360, saturation: 0.30, brightness: 0.30) // Dark Mint
        static let secondaryForeground = foreground

        static let muted = Color(hue: 240/360, saturation: 0.05, brightness: 0.20)     // Dark grey-blue
        static let mutedForeground = Color(hue: 0.0, saturation: 0.0, brightness: 0.60) // Light grey

        static let accent = Color(hue: 180/360, saturation: 0.55, brightness: 0.55)     // Aqua
        static let accentForeground = foreground

        static let destructive = Color(hue: 0.0, saturation: 0.70, brightness: 0.50)
        static let destructiveForeground = Color.white

        static let border = Color(hue: brandHue, saturation: 0.50, brightness: 0.30)
        static let input = border
        static let ring = Color(hue: brandHue, saturation: 0.65, brightness: 0.45)

        // Chart colors: same palette but darker
        static let chart1 = Color(hue: 120/360, saturation: 0.80, brightness: 0.45)
        static let chart2 = Color(hue: 180/360, saturation: 0.70, brightness: 0.40)
        static let chart3 = Color(hue: 210/360, saturation: 0.60, brightness: 0.35)
        static let chart4 = Color(hue: 330/360, saturation: 0.65, brightness: 0.50)
        static let chart5 = Color(hue: 280/360, saturation: 0.60, brightness: 0.50)

        // MARK: - Category Card Backgrounds (Dark) - REVISED
        static let sportsCardBackground = Color(hue: 210/360, saturation: 0.40, brightness: 0.20)   // Darker, desaturated sky blue
        static let diningCardBackground = Color(hue: 20/360, saturation: 0.40, brightness: 0.18)    // Darker, muted terracotta/peach
        static let hikingCardBackground = Color(hue: 145/360, saturation: 0.35, brightness: 0.15)   // Darker mint/green (theme-aligned)
        static let gamingCardBackground = Color(hue: 280/360, saturation: 0.35, brightness: 0.18)   // Darker violet (chart-aligned)
        static let moviesCardBackground = Color(hue: 220/360, saturation: 0.20, brightness: 0.12)   // Dark cool grey/blue (slightly distinct from main bg)
        static let travelCardBackground = Color(hue: 180/360, saturation: 0.40, brightness: 0.18)   // Darker aqua (theme-aligned)
        static let musicCardBackground = Color(hue: 330/360, saturation: 0.40, brightness: 0.20)    // Darker pink/magenta (chart-aligned)
        static let cookingCardBackground = Color(hue: 40/360, saturation: 0.25, brightness: 0.15)   // Dark warm brown/beige
        
        static let defaultCardBackground = Self.card // Fallback to default card (very dark blue)
    }
}
