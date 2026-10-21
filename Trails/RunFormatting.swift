import Foundation

enum RunFormatting {
    static func distance(_ meters: Double) -> String {
        let number = NumberFormatter()
        number.locale = Locale(identifier: "sv_SE")
        number.numberStyle = .decimal
        if meters >= 1_000 {
            number.minimumFractionDigits = 2
            number.maximumFractionDigits = 2
            let value = number.string(from: NSNumber(value: meters / 1_000)) ?? String(format: "%.2f", meters / 1_000)
            return "\(value) km"
        }
        number.minimumFractionDigits = 0
        number.maximumFractionDigits = 0
        let value = number.string(from: NSNumber(value: meters)) ?? String(format: "%.0f", meters)
        return "\(value) m"
    }

    static func duration(_ interval: TimeInterval) -> String {
        let total = max(0, Int(interval.rounded()))
        let hours = total / 3_600
        let minutes = (total % 3_600) / 60
        let seconds = total % 60
        if hours > 0 {
            return String(format: "%d:%02d:%02d", hours, minutes, seconds)
        }
        return String(format: "%d:%02d", minutes, seconds)
    }

    static func dateTime(_ date: Date) -> String {
        formatter(dateStyle: .medium, timeStyle: .short).string(from: date)
    }

    static func date(_ date: Date) -> String {
        formatter(dateStyle: .medium, timeStyle: .none).string(from: date)
    }

    private static func formatter(dateStyle: DateFormatter.Style, timeStyle: DateFormatter.Style) -> DateFormatter {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "sv_SE")
        formatter.timeZone = TimeZone(identifier: "Europe/Stockholm")
        formatter.dateStyle = dateStyle
        formatter.timeStyle = timeStyle
        return formatter
    }
}

enum PhotoWindow {
    static func contains(_ date: Date, start: Date, end: Date) -> Bool {
        (min(start, end)...max(start, end)).contains(date)
    }
}
