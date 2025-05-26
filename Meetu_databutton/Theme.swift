//
//  Theme.swift
//  Meetu_databutton
//
//  Created by Marina Amorim on 25.5.2025.
//


import SwiftUI

struct Theme {
    // MARK: - Light Mode Colors
    struct Light {
        static let primaryForeground = Color(hue: 0.0, saturation: 0.0, brightness: 0.98)
        static let secondary = Color(hue: 75/360, saturation: 0.55, brightness: 0.74) // #c2cf5a
        static let secondaryForeground = Color(hue: 240/360, saturation: 0.059, brightness: 0.10)
        static let accent = Color(hue: 43/360, saturation: 0.45, brightness: 0.63) // #cba65f
        static let accentForeground = secondaryForeground

        static let background = Color.white
        static let foreground = Color(hue: 240/360, saturation: 0.10, brightness: 0.039)

        static let card = background
        static let cardForeground = foreground

        static let popover = background
        static let popoverForeground = foreground

        static let muted = Color(hue: 210/360, saturation: 0.20, brightness: 0.96) // #f1f5f9
        static let mutedForeground = Color(hue: 240/360, saturation: 0.038, brightness: 0.461)

        static let destructive = Color(hue: 0.0, saturation: 0.842, brightness: 0.602)
        static let destructiveForeground = Color(hue: 0.0, saturation: 0.0, brightness: 0.98)

        static let border = Color(hue: 240/360, saturation: 0.059, brightness: 0.90)
        static let input = border
        static let ring = Color(hue: 93/360, saturation: 0.45, brightness: 0.34)

        // Chart colors
        static let chart1 = Color(hue: 12/360, saturation: 0.76, brightness: 0.61)
        static let chart2 = Color(hue: 173/360, saturation: 0.58, brightness: 0.39)
        static let chart3 = Color(hue: 197/360, saturation: 0.37, brightness: 0.24)
        static let chart4 = Color(hue: 43/360, saturation: 0.74, brightness: 0.66)
        static let chart5 = Color(hue: 27/360, saturation: 0.87, brightness: 0.67)
    }

    // MARK: - Dark Mode Colors
    struct Dark {
        static let background = Color(hue: 240/360, saturation: 0.10, brightness: 0.039)
        static let foreground = Color(hue: 0.0, saturation: 0.0, brightness: 0.98)

        static let card = background
        static let cardForeground = foreground

        static let popover = background
        static let popoverForeground = foreground

        static let primary = foreground
        static let primaryForeground = Color(hue: 240/360, saturation: 0.059, brightness: 0.10)

        static let secondary = Color(hue: 240/360, saturation: 0.037, brightness: 0.159)
        static let secondaryForeground = foreground

        static let muted = secondary
        static let mutedForeground = Color(hue: 240/360, saturation: 0.05, brightness: 0.649)

        static let accent = secondary
        static let accentForeground = foreground

        static let destructive = Color(hue: 0.0, saturation: 0.628, brightness: 0.306)
        static let destructiveForeground = foreground

        static let border = secondary
        static let input = secondary
        static let ring = Color(hue: 240/360, saturation: 0.049, brightness: 0.839)

        // Chart colors
        static let chart1 = Color(hue: 220/360, saturation: 0.70, brightness: 0.50)
        static let chart2 = Color(hue: 160/360, saturation: 0.60, brightness: 0.45)
        static let chart3 = Color(hue: 30/360, saturation: 0.80, brightness: 0.55)
        static let chart4 = Color(hue: 280/360, saturation: 0.65, brightness: 0.60)
        static let chart5 = Color(hue: 340/360, saturation: 0.75, brightness: 0.55)
    }
}
