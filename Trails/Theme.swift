import SwiftUI

enum TrailTheme {
    static let accent = Color(red: 0.98, green: 0.48, blue: 0.16)
    static let routeCore = Color(red: 1.0, green: 0.74, blue: 0.30)
    static let routeGlow = Color(red: 1.0, green: 0.38, blue: 0.04)
    static let clay = accent
    static let water = Color(red: 0.20, green: 0.40, blue: 0.55)

    static func routeColor(at index: Int) -> Color {
        let palette = [routeCore, accent, routeGlow, Color(red: 1.0, green: 0.86, blue: 0.55)]
        return palette[index % palette.count]
    }
}
