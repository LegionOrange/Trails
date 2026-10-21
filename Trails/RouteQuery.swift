import Foundation

struct RouteFilter: Equatable {
    var markedOnly = false
    var selectedOnly = false
    var usesDateRange = false
    var startDate = Date()
    var endDate = Date()
    var usesDistanceRange = false
    var minimumKilometers = 0.0
    var maximumKilometers = 40.0

    func allows(_ run: RunWorkout, isMarked: Bool, isChosen: Bool, calendar: Calendar = .current) -> Bool {
        if markedOnly && !isMarked { return false }
        if selectedOnly && !isChosen { return false }
        if usesDateRange && !dateInterval(calendar: calendar).contains(run.startDate) { return false }
        if usesDistanceRange {
            let kilometers = run.distanceMeters / 1_000
            let lower = min(minimumKilometers, maximumKilometers)
            let upper = max(minimumKilometers, maximumKilometers)
            if kilometers < lower || kilometers > upper { return false }
        }
        return true
    }

    private func dateInterval(calendar: Calendar) -> ClosedRange<Date> {
        let startDay = calendar.startOfDay(for: min(startDate, endDate))
        let endDay = calendar.startOfDay(for: max(startDate, endDate))
        let end = calendar.date(byAdding: DateComponents(day: 1, second: -1), to: endDay) ?? endDay
        return startDay...end
    }
}

struct RouteStatistics: Equatable {
    var count: Int
    var totalDistanceMeters: Double
    var totalDuration: TimeInterval

    var averageDistanceMeters: Double {
        guard count > 0 else { return 0 }
        return totalDistanceMeters / Double(count)
    }

    var averagePaceSecondsPerKilometer: Double? {
        guard totalDistanceMeters >= 1 else { return nil }
        return totalDuration / (totalDistanceMeters / 1_000)
    }

    static func summarize(_ runs: [RunWorkout]) -> RouteStatistics {
        RouteStatistics(
            count: runs.count,
            totalDistanceMeters: runs.reduce(0) { $0 + $1.distanceMeters },
            totalDuration: runs.reduce(0) { $0 + $1.duration }
        )
    }
}

extension RunFormatting {
    static func pace(_ secondsPerKilometer: Double) -> String {
        let total = max(0, Int(secondsPerKilometer.rounded()))
        let minutes = total / 60
        let seconds = total % 60
        return String(format: "%d:%02d /km", minutes, seconds)
    }
}
