import SwiftUI

enum TrailTheme {
    static let accent = Color(red: 0.18, green: 0.42, blue: 0.31)
    static let clay = Color(red: 0.77, green: 0.42, blue: 0.23)
    static let water = Color(red: 0.20, green: 0.40, blue: 0.55)

    static func routeColor(at index: Int) -> Color {
        let palette = [accent, clay, water, Color(red: 0.45, green: 0.36, blue: 0.55)]
        return palette[index % palette.count]
    }
}
